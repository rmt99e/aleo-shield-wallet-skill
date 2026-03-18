# Aleo Security Reference

ZK programs have unique vulnerability classes beyond traditional smart contract risks.
This reference covers Aleo-specific security concerns and a review checklist.

---

## ZK-Specific Vulnerabilities

### CRITICAL: Records Sent to Program Addresses Are Lost Forever

Programs do not have private keys. If a record is transferred to a program's
address (rather than consumed as a transition input), **it is permanently
unrecoverable**. No one can decrypt or spend it.

```leo
// CATASTROPHIC — tokens are lost forever
transition bad_deposit(token: Token) -> Token {
    return Token { owner: self.address, amount: token.amount };
    // self.address is the PROGRAM's address — no one holds its private key
}

// CORRECT — use a mapping to track deposits, keep records owned by users
async transition deposit(token: Token) -> Future {
    return finalize_deposit(token.owner, token.amount);
}

async function finalize_deposit(depositor: address, amount: u64) {
    let bal: u64 = deposits.get_or_use(depositor, 0u64);
    deposits.set(depositor, bal + amount);
}
```

This is the **single most dangerous footgun** in Aleo development. The protocol
will happily create a record owned by a program address — it just can never
be spent.

### CRITICAL: Program Name Front-Running

Program names are first-come-first-served on Aleo. An attacker watching
your testnet deployments can deploy a malicious program with your intended
mainnet name before you do.

**Mitigation:**
- Deploy your program name to mainnet early (even a placeholder)
- Don't reveal your mainnet program name on testnet — use different names
- Consider longer names (cheaper to deploy and harder to guess)

### 1. Information Leakage via Public Outputs

Even in "private" programs, public outputs, mapping updates, and transaction
metadata can leak information.

```leo
// BAD — leaks the exact transfer amount publicly
async transition transfer(token: Token, to: address, amount: u64) -> (Token, Future) {
    let change: Token = Token { owner: token.owner, amount: token.amount - amount };
    return (change, finalize_transfer(to, amount));  // amount visible in finalize
}

// BETTER — only update a mapping with hashed/committed values
async transition transfer(token: Token, to: address, amount: u64) -> (Token, Future) {
    let commitment: field = BHP256::commit_to_field(amount, rand_field);
    let change: Token = Token { owner: token.owner, amount: token.amount - amount };
    return (change, finalize_transfer(commitment));
}
```

**Audit for:** Any value passed to finalize is public. Review every finalize parameter.

### 2. Record Front-Running

When a user submits a transaction that consumes a record, the nullifier becomes
visible in the mempool. An attacker watching the mempool could:
- Submit a competing transaction consuming the same record (double-spend race)
- Infer transaction patterns from nullifier timing

**Mitigation:**
- Use private fee records to reduce metadata exposure
- Design programs so front-running doesn't create economic advantage
- Consider commit-reveal patterns for sensitive operations

### 3. Mapping Race Conditions

Mappings are updated in finalize, which runs on validators. Multiple transactions
can target the same mapping key in the same block.

```leo
// VULNERABLE — race condition on counter
async function finalize_bid(bidder: address, amount: u64) {
    let count: u64 = bid_count.get_or_use(0u8, 0u64);
    bid_count.set(0u8, count + 1u64);  // two txs in same block get same count
}

// SAFER — use bidder-specific keys
async function finalize_bid(bidder: address, amount: u64) {
    assert(!bids.contains(bidder));  // one bid per address
    bids.set(bidder, amount);
}
```

### 4. Overflow and Underflow

Leo unsigned integers wrap on overflow in transitions but may cause assertion
failures in finalize.

```leo
// BAD — overflow wraps silently in transition
transition add_amounts(a: u64, b: u64) -> u64 {
    return a + b;  // wraps if a + b > u64::MAX
}

// GOOD — explicit overflow check
transition add_amounts(a: u64, b: u64) -> u64 {
    assert(a <= 18446744073709551615u64 - b);  // u64::MAX - b
    return a + b;
}
```

In finalize, overflow causes the entire transaction to fail (revert), which
can be used as a DoS vector.

### 5. Missing Caller Verification

Forgetting to use `self.caller` for authorization is the most common Aleo bug.

```leo
// BAD — caller passed as parameter (forgeable in cross-program calls)
async transition admin_action(caller: address) -> Future {
    assert_eq(caller, ADMIN);
    return finalize_admin_action();
}

// GOOD — use self.caller (unforgeable)
async transition admin_action() -> Future {
    assert_eq(self.caller, ADMIN);
    return finalize_admin_action();
}
```

**Critical:** In cross-program calls, `self.caller` is the calling *program's*
address, not the original user. Design authorization chains carefully.

### 6. Record Ownership Bypass

Records enforce ownership automatically, but programs can accidentally
create records owned by the wrong address.

```leo
// BAD — attacker can mint tokens to themselves
transition mint(recipient: address, amount: u64) -> Token {
    return Token { owner: recipient, amount };  // no access control
}

// GOOD — restrict minting
transition mint(recipient: address, amount: u64) -> Token {
    assert_eq(self.caller, ADMIN);
    return Token { owner: recipient, amount };
}
```

### 7. Finalize Failure DoS

If a finalize block fails (assertion, overflow, missing key), the entire
transaction is reverted but the user still pays the base fee. An attacker
can craft inputs that pass the transition but fail in finalize, wasting
the victim's fees.

```leo
// VULNERABLE — attacker can cause finalize failure for others
async function finalize_action(key: field) {
    let val: u64 = data.get(key);  // panics if key doesn't exist
}

// SAFER — handle missing keys gracefully
async function finalize_action(key: field) {
    let val: u64 = data.get_or_use(key, 0u64);
}
```

**Design principle:** Finalize blocks should be as robust as possible. Use
`get_or_use` instead of `get`, validate arithmetic bounds, and consider all
possible input combinations.

### 8. Ternary Evaluates Both Branches

In ZK circuits, **both branches of a ternary or if-else are always evaluated**.
This can cause unexpected panics even when the "safe" branch would be selected.

```leo
// BAD — underflow panic even when amount <= balance
transition withdraw(balance: u64, amount: u64) -> u64 {
    return amount <= balance ? balance - amount : 0u64;
    // If amount > balance, (balance - amount) STILL executes and underflows
}

// GOOD — use signed integers as intermediaries
transition withdraw(balance: u64, amount: u64) -> u64 {
    let diff: i128 = (balance as i128) - (amount as i128);
    return diff >= 0i128 ? (diff as u64) : 0u64;
}

// ALSO GOOD — check first, then compute
transition withdraw(balance: u64, amount: u64) -> u64 {
    assert(amount <= balance);
    return balance - amount;
}
```

### 9. Field Type Modular Arithmetic

Unlike integer types (where overflow causes proof failure), `field` operations
use **modular arithmetic silently**. This can mask logical bugs.

```leo
// DANGEROUS — field wraps around without error
transition field_math() -> field {
    let a: field = 0field;
    let b: field = 1field;
    let result: field = a - b;  // Does NOT fail — wraps to field modulus - 1
    return result;
}

// Integer equivalent would fail:
// let a: u64 = 0u64;
// let b: u64 = 1u64;
// let result: u64 = a - b;  // FAILS — underflow
```

**Rule:** Use integer types when you need overflow/underflow detection. Only use
`field` when you intentionally want modular arithmetic (cryptographic operations,
hash computations).

### 10. Transaction Pattern Analysis

Even with private records, on-chain metadata reveals:
- **Transaction timing** — when transactions are submitted
- **Program interaction graph** — which programs are called together
- **Fee amounts** — can correlate with transaction complexity
- **Nullifier patterns** — when records are consumed

**Mitigation:**
- Batch transactions to obscure timing
- Use consistent fee amounts where possible
- Consider adding dummy transactions or delays for high-privacy applications
- Use private fee records (`privateFee: true`) to hide fee source

---

## Security Review Checklist

### Authorization
- [ ] All admin/privileged transitions use `self.caller`, never a parameter
- [ ] Cross-program call chains preserve correct authorization (caller is the program, not the user)
- [ ] Initialize/constructor can only run once (prevent re-initialization)
- [ ] Record minting is access-controlled

### State Management
- [ ] Finalize blocks use `get_or_use` not `get` (unless key is guaranteed to exist)
- [ ] No race conditions on shared mapping keys
- [ ] Counters and balances are protected against overflow
- [ ] First-write-wins patterns use `assert(!mapping.contains(key))` before `set`

### Privacy
- [ ] No sensitive values passed to finalize (all finalize params are public)
- [ ] Record fields don't leak information through public outputs
- [ ] Transaction patterns don't reveal user behavior
- [ ] Fee payment method matches privacy requirements

### Arithmetic
- [ ] Integer overflow is handled in both transitions and finalize
- [ ] Division by zero is impossible (validate denominators)
- [ ] Type casting (`as`) doesn't truncate significant bits
- [ ] Field element operations stay within the field modulus

### Program Limits
- [ ] Loop bounds are reasonable (large loops = expensive proofs)
- [ ] Import chains are shallow (each level adds proving time)
- [ ] Program size is within deployment limits

### Deployment
- [ ] Constructor uses appropriate upgrade annotation
- [ ] Admin keys are stored securely (not in code)
- [ ] Program has been tested on testnet before mainnet
- [ ] Dependencies are deployed and verified on target network
- [ ] Program name is final (cannot rename after deployment)

---

## Common Attack Vectors

| Attack | Target | Mitigation |
|--------|--------|------------|
| Front-running | Record consumption | Commit-reveal, private fees |
| Griefing | Finalize failure | Robust finalize, `get_or_use` |
| Replay | Signatures/proofs | Nonce mapping, `used_nonces` |
| Privilege escalation | Admin transitions | `self.caller` checks |
| Information extraction | Public outputs | Minimize finalize params |
| Double-spend race | Record UTXO | Protocol handles this; design for idempotency |
| Overflow exploit | Arithmetic | Bounds checking, `assert` before ops |
| Sybil | Voting/governance | Stake-weighted, rate-limited |
