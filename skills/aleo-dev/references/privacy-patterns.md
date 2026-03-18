# Privacy Patterns Reference

Design patterns for building privacy-preserving applications on Aleo.
Use this reference when choosing between records, mappings, and hybrid approaches.

---

## Core Decision Framework

Every piece of state in an Aleo program must be stored as either a **record**
(private) or a **mapping** (public). The choice has fundamental implications:

| | Records (Private) | Mappings (Public) |
|---|---|---|
| **Visibility** | Only owner can see contents | Anyone can read via API |
| **Access** | Consumed/produced in transitions | Read/written in finalize |
| **Persistence** | UTXO model — consumed on use | Persistent key-value store |
| **Composability** | Hard to compose across programs | Easy to read cross-program |
| **Proving cost** | Lower (no finalize needed) | Higher (finalize execution) |
| **Indexing** | Requires view key scanning | Directly queryable |

**Rule of thumb:** Use records when the data owner is the only one who needs it.
Use mappings when the data must be globally visible or verifiable. Use both
(hybrid) when you need private ownership with public accountability.

---

## Pattern: Private Token

All balances are records. No public state. Maximum privacy.

```leo
record Token {
    owner: address,
    amount: u64,
}

transition transfer(token: Token, to: address, amount: u64) -> (Token, Token) {
    assert(token.amount >= amount);
    let change: Token = Token { owner: token.owner, amount: token.amount - amount };
    let payment: Token = Token { owner: to, amount };
    return (change, payment);
}
```

**Pros:** No public state, no finalize, fast proving, maximum privacy.
**Cons:** No public balance queries, hard to integrate with DeFi, UTXO management complexity.
**Use when:** Privacy is the top priority (e.g., payments, private credentials).

---

## Pattern: Private Voting

Voters cast private ballots; only the final tally is public.

```leo
record Ballot {
    owner: address,
    proposal_id: field,
}

mapping vote_count: field => u64;       // proposal_id => count
mapping has_ballot: address => bool;    // prevent double-issue

// Issue ballot (admin only)
async transition issue_ballot(voter: address, proposal_id: field) -> (Ballot, Future) {
    assert_eq(self.caller, ADMIN);
    let ballot: Ballot = Ballot { owner: voter, proposal_id };
    return (ballot, finalize_issue(voter));
}

async function finalize_issue(voter: address) {
    assert(!has_ballot.contains(voter));
    has_ballot.set(voter, true);
}

// Cast vote (consumes ballot — prevents double voting)
async transition vote(ballot: Ballot) -> Future {
    return finalize_vote(ballot.proposal_id);
}

async function finalize_vote(proposal_id: field) {
    let count: u64 = vote_count.get_or_use(proposal_id, 0u64);
    vote_count.set(proposal_id, count + 1u64);
}
```

**Key insight:** The ballot record is consumed when voting, which prevents double
voting. The voter's identity is never revealed — only the vote count increments.

---

## Pattern: Sealed-Bid Auction

Bidders submit encrypted bids; bids are revealed after the auction closes.

```leo
record SealedBid {
    owner: address,
    auction_id: field,
    amount: u64,
    salt: field,         // random blinding factor
}

mapping bid_commitments: field => field;  // commitment_key => commitment
mapping auction_state: field => u8;       // 0=open, 1=reveal, 2=settled

// Phase 1: Submit sealed bid (private record + public commitment)
async transition submit_bid(
    auction_id: field,
    amount: u64,
    salt: field,
) -> (SealedBid, Future) {
    let bid: SealedBid = SealedBid {
        owner: self.caller,
        auction_id,
        amount,
        salt,
    };
    let commitment: field = BHP256::commit_to_field(amount, salt);
    let commitment_key: field = BHP256::hash_to_field(self.caller);
    return (bid, finalize_submit(auction_id, commitment_key, commitment));
}

async function finalize_submit(auction_id: field, key: field, commitment: field) {
    let state: u8 = auction_state.get_or_use(auction_id, 0u8);
    assert_eq(state, 0u8);  // auction must be open
    bid_commitments.set(key, commitment);
}

// Phase 2: Reveal bid (consumes sealed bid, publishes amount)
async transition reveal_bid(bid: SealedBid) -> Future {
    let commitment: field = BHP256::commit_to_field(bid.amount, bid.salt);
    let commitment_key: field = BHP256::hash_to_field(bid.owner);
    return finalize_reveal(bid.auction_id, commitment_key, commitment, bid.amount);
}

async function finalize_reveal(
    auction_id: field,
    key: field,
    commitment: field,
    amount: u64,
) {
    let state: u8 = auction_state.get_or_use(auction_id, 0u8);
    assert_eq(state, 1u8);  // must be in reveal phase
    let stored: field = bid_commitments.get(key);
    assert_eq(stored, commitment);  // commitment must match
    // Record the revealed bid amount...
}
```

**Key insight:** The commitment (hash with salt) is public but reveals nothing.
Only during the reveal phase does the amount become visible.

---

## Pattern: Hybrid Token

Private records for transfers, public mapping for DeFi composability.

```leo
record Token {
    owner: address,
    amount: u64,
}

mapping public_balances: address => u64;

// Private transfer (record-to-record)
transition transfer_private(token: Token, to: address, amount: u64) -> (Token, Token) {
    assert(token.amount >= amount);
    return (
        Token { owner: token.owner, amount: token.amount - amount },
        Token { owner: to, amount },
    );
}

// Shield: public → private
async transition shield(amount: u64) -> (Token, Future) {
    let token: Token = Token { owner: self.caller, amount };
    return (token, finalize_shield(self.caller, amount));
}

async function finalize_shield(addr: address, amount: u64) {
    let bal: u64 = public_balances.get_or_use(addr, 0u64);
    assert(bal >= amount);
    public_balances.set(addr, bal - amount);
}

// Unshield: private → public
async transition unshield(token: Token) -> Future {
    return finalize_unshield(token.owner, token.amount);
}

async function finalize_unshield(addr: address, amount: u64) {
    let bal: u64 = public_balances.get_or_use(addr, 0u64);
    public_balances.set(addr, bal + amount);
}
```

**This is the most common pattern** — used by the official credits.aleo program.
Users choose their privacy level per transaction.

---

## Pattern: Privacy-Preserving Public Storage

Store data publicly but hash the keys so observers can't enumerate users.

```leo
// Instead of:
mapping balances: address => u64;  // anyone can see all balances

// Use hashed keys:
mapping balances: field => u64;    // keys are hashed addresses

inline hash_key(addr: address, salt: field) -> field {
    return BHP256::hash_to_field(addr);
}

async transition deposit(amount: u64, salt: field) -> Future {
    let key: field = hash_key(self.caller, salt);
    return finalize_deposit(key, amount);
}

async function finalize_deposit(key: field, amount: u64) {
    let bal: u64 = balances.get_or_use(key, 0u64);
    balances.set(key, bal + amount);
}
```

**Limitation:** This is obscurity, not cryptographic privacy. Anyone who knows
the address can compute the hash and look up the balance. But it prevents casual
enumeration of all participants.

---

## Pattern: Multi-Program Privacy

Split sensitive operations across multiple programs to isolate information.

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  auth_v1.aleo   │    │  logic_v1.aleo   │    │  settle_v1.aleo │
│                 │    │                  │    │                 │
│ • Issue access  │───▶│ • Process action │───▶│ • Update state  │
│   records       │    │ • No public      │    │ • Minimal       │
│ • Verify        │    │   outputs        │    │   public data   │
│   identity      │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

By splitting logic across programs:
- Each program sees only what it needs
- Cross-program calls are atomic (all succeed or all fail)
- Observers see program interactions but not internal data flow

---

## Design Guidelines

1. **Start with the privacy requirement** — ask "who needs to see this data?"
   before choosing records vs mappings
2. **Minimize finalize parameters** — every value passed to finalize is public
3. **Use commitments for deferred reveals** — hash(value, salt) now, reveal later
4. **Records for user-owned state, mappings for global state** — this is the
   natural split
5. **Consider the UTXO management burden** — records require client-side tracking;
   mappings are simpler for developers
6. **Private fees reduce metadata** — use `privateFee: true` in the SDK when
   privacy matters
7. **Test privacy claims** — check testnet explorer after executing. If you can
   see a value you expected to be private, fix the design
8. **Hybrid is usually the answer** — very few real applications are fully private
   or fully public
