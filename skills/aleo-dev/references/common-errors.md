# Common Errors Reference

Detailed error examples with BAD/GOOD code pairs. For a quick summary table,
see `references/leo-language.md`.

---

## Error Code Prefixes

| Prefix | Category |
|--------|----------|
| `EPAR` | Parser errors — syntax issues |
| `AST` | Abstract syntax tree — structural issues |
| `CMP` | Compiler — type checking, constraint generation |
| `CLI` | Command-line interface errors |

---

## Compiler Errors

### Type Mismatch

```leo
// BAD
transition add(a: u64, b: u32) -> u64 {
    return a + b;  // Error: type mismatch — cannot add u64 and u32
}

// GOOD
transition add(a: u64, b: u32) -> u64 {
    return a + (b as u64);  // explicit cast
}
```

### Missing Type Suffix on Literals

```leo
// BAD
transition example() -> u64 {
    return 100;  // Error: cannot infer type of integer literal
}

// GOOD
transition example() -> u64 {
    return 100u64;
}
```

### Record in Finalize

```leo
// BAD — records cannot appear in finalize
async function finalize_action(token: Token) {
    // Error: record type cannot appear in finalize
}

// GOOD — pass individual fields instead
async function finalize_action(owner: address, amount: u64) {
    balances.set(owner, amount);
}
```

### Mapping Operation Outside Finalize

```leo
// BAD
transition check_balance(addr: address) -> u64 {
    return balances.get(addr);  // Error: mapping operation outside of finalize
}

// GOOD — mapping ops only in async function
async transition check_balance(addr: address) -> Future {
    return finalize_check(addr);
}

async function finalize_check(addr: address) {
    let bal: u64 = balances.get_or_use(addr, 0u64);
    // ...
}
```

### Program ID Mismatch

```leo
// BAD — program.json says "my_token.aleo" but source says:
program my_tokens.aleo;  // Error: program ID mismatch

// GOOD — names must match exactly
program my_token.aleo;   // matches program.json
```

### Reserved Keyword as Variable

```leo
// BAD
transition example(record: u64) -> u64 {  // Error: 'record' is reserved
    return record;
}

// GOOD
transition example(amount: u64) -> u64 {
    return amount;
}
```

### Loop Bound Not Constant

```leo
// BAD
transition sum(n: u32) -> u64 {
    let total: u64 = 0u64;
    for i: u32 in 0u32..n {  // Error: loop bound must be a constant
        total += 1u64;
    }
    return total;
}

// GOOD — use compile-time constant
transition sum() -> u64 {
    let total: u64 = 0u64;
    for i: u32 in 0u32..10u32 {
        total += 1u64;
    }
    return total;
}
```

### Inline Function Called Externally

```leo
// BAD — inline functions are internal only
inline helper() -> u64 {
    return 42u64;
}
// Cannot call helper() from outside the program

// GOOD — use a transition for external access
transition get_value() -> u64 {
    return helper();  // call inline from within a transition
}
```

### Import Not Found

```leo
// BAD — imported program not deployed on target network
import nonexistent_program.aleo;
// Error: import not found

// GOOD — verify deployment first
// $ leo query program token.aleo --network testnet
import token.aleo;
```

### Missing Return Value

```leo
// BAD
transition compute(a: u64, b: u64) -> u64 {
    let result: u64 = a + b;
    // Error: missing return statement
}

// GOOD
transition compute(a: u64, b: u64) -> u64 {
    let result: u64 = a + b;
    return result;
}
```

### Duplicate Record Field

```leo
// BAD
record Token {
    owner: address,
    owner: address,  // Error: duplicate field name
    amount: u64,
}

// GOOD
record Token {
    owner: address,
    amount: u64,
}
```

### Multiple Returns of Same Record Type

```leo
// BAD — ambiguous output records
transition split(token: Token) -> (Token, Token) {
    // May trigger: transition has multiple returns of the same record type
    // Ensure each output is clearly constructed
}
```

### Self.caller in Finalize

```leo
// BAD — self.caller not available in finalize
async function finalize_action() {
    let caller: address = self.caller;  // Error: self.caller not in scope
}

// GOOD — pass self.caller from the transition
async transition action() -> Future {
    return finalize_action(self.caller);
}

async function finalize_action(caller: address) {
    // use caller parameter
}
```

### Unused Variable Warning

```leo
// WARNING — unused variable
transition example() -> u64 {
    let unused: u64 = 42u64;  // Warning: unused variable
    return 0u64;
}

// GOOD — prefix with underscore to suppress
transition example() -> u64 {
    let _unused: u64 = 42u64;
    return 0u64;
}
```

### Struct Used as Mapping Key Without All Fields

```leo
// BAD — all fields must be populated
struct Key {
    id: field,
    owner: address,
}

async function finalize_example() {
    let key: Key = Key { id: 1field };  // Error: missing field 'owner'
}

// GOOD
async function finalize_example() {
    let key: Key = Key { id: 1field, owner: aleo1abc... };
}
```

### Missing Constructor (Leo 3.1.0+)

```leo
// BAD — no constructor
program my_program.aleo;

transition hello() -> u64 {
    return 42u64;
}
// Error: program must have a constructor

// GOOD
program my_program.aleo;

@noupgrade
constructor {}

transition hello() -> u64 {
    return 42u64;
}
```

---

## Deployment Errors

### Fee Too Low

```
Error: transaction fee is insufficient
```

**Fix:** Use `leo deploy --estimate-fee --network <network>` first, then deploy
with at least that amount.

### Program Already Deployed

```
Error: program 'my_program.aleo' already exists on-chain
```

**Fix:** Choose a different program name. Programs cannot be overwritten (unless
the deployed program has upgrade annotations).

### Name Too Short (High Cost)

Short program names (< 10 characters) incur a namespace premium. This isn't an
error but an unexpected cost. Budget accordingly or use longer names.

### Import Not Deployed

```
Error: imported program 'token.aleo' not found on network
```

**Fix:** Deploy dependencies first, bottom-up. Verify with:
```bash
leo query program token.aleo --network testnet
```

---

## WASM / SDK Errors

### SharedArrayBuffer Not Available

```
Error: SharedArrayBuffer is not defined
```

**Fix:** Set the correct HTTP headers for cross-origin isolation:
```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

For Vite:
```typescript
// vite.config.ts
export default defineConfig({
    server: {
        headers: {
            "Cross-Origin-Opener-Policy": "same-origin",
            "Cross-Origin-Embedder-Policy": "require-corp",
        },
    },
});
```

### Module Not Found (@provablehq/sdk)

```
Error: Cannot find module '@provablehq/sdk'
```

**Fix:** Install the SDK and WASM packages:
```bash
npm install @provablehq/sdk
```

For network-specific imports:
```typescript
import { Account } from "@provablehq/sdk/mainnet.js";
// or
import { Account } from "@provablehq/sdk/testnet.js";
```

### ESM Import Issues

```
Error: require() of ES Module not supported
```

**Fix:** The SDK is ESM-only. Ensure your project uses ESM:
- Set `"type": "module"` in `package.json`
- Use `import` syntax, not `require`
- If using TypeScript, set `"module": "ESNext"` in tsconfig

### Web Worker Import Error

```
Error: Failed to construct 'Worker': Module scripts are not supported
```

**Fix:** Use the `type: "module"` option:
```typescript
const worker = new Worker(new URL("./worker.ts", import.meta.url), {
    type: "module",
});
```

---

## Runtime Errors

### Proof Verification Failed

```
Error: proof verification failed
```

**Cause:** Inputs don't satisfy the program's constraints (assertions failed).
**Fix:** Check that all `assert` / `assert_eq` conditions are met with your inputs.

### Record Already Spent

```
Error: record has already been consumed
```

**Cause:** Attempting to use a record that was already spent in a previous transaction.
**Fix:** Fetch fresh unspent records. Each record can only be used once (UTXO model).

### Finalize Failed

```
Error: finalize execution failed
```

**Cause:** An assertion in the finalize block failed, or arithmetic overflowed.
**Fix:** Check mapping key existence (`get` vs `get_or_use`), arithmetic bounds,
and assertion conditions.

### Transaction Rejected by Network

```
Error: transaction rejected
```

**Cause:** Fee too low, program not deployed, or network congestion.
**Fix:** Re-estimate fees, verify program deployment, retry with higher priority fee.
