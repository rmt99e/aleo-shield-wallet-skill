# Leo Language Reference

Quick reference for writing correct, idiomatic Leo programs on Aleo.

- Official docs: https://docs.leo-lang.org/leo
- Leo Playground: https://play.leo-lang.org
- Latest stable: **v3.5.0** (March 2025) — check https://github.com/ProvableHQ/leo/releases
- Install: `cargo install leo-lang` or use the install script

---

## Program Structure

Every Leo program compiles to an Aleo program. The file is `src/main.leo` and
the program identity lives in `program.json`:

```json
{
  "program": "my_program.aleo",
  "version": "0.0.0",
  "description": "",
  "license": "MIT"
}
```

The program ID (`my_program.aleo`) must be globally unique on-chain. Names
≥ 10 characters have lower deployment fees.

```leo
program my_program.aleo;

// imports, structs, records, mappings, functions, transitions here
```

---

## Types

### Primitive types
| Type | Notes |
|------|-------|
| `u8`, `u16`, `u32`, `u64`, `u128` | Unsigned integers |
| `i8`, `i16`, `i32`, `i64`, `i128` | Signed integers |
| `field` | Base field element |
| `group` | Elliptic curve group element |
| `scalar` | Scalar field element |
| `bool` | Boolean |
| `address` | Aleo address (`aleo1...`) |
| `signature` | Cryptographic signature (v3.5.0+) |
| `string` | String literal |

All integer literals need a type suffix: `100u64`, `0i32`, `true`.

### Unit and Tuple Types

```leo
// Unit type (void return)
transition do_something() -> () { ... }

// Tuples
let pair: (u64, address) = (100u64, aleo1abc...);
```

### Structs (public composite types)
```leo
struct Point {
    x: i64,
    y: i64,
}
```
Structs are **not** encrypted. Avoid putting sensitive data in struct fields
that end up in public outputs.

### Structs as Mapping Keys

Structs can be used as composite mapping keys:

```leo
struct StampKey {
    content_hash: field,
    creator: address,
}

mapping user_entries: StampKey => u64;
```

This is useful when you need multi-dimensional lookups (e.g., per-user
per-item state). The struct is hashed to produce the mapping key on-chain.

### Records (private encrypted types)
```leo
record Token {
    owner: address,   // required field — controls who can spend this record
    amount: u64,
    // any additional fields
}
```
Records are the primary privacy primitive. They are stored on-chain as
ciphertexts decryptable only by the `owner` using their view key.

**Rules:**
- Every record must have an `owner: address` field
- Records can only be consumed (spent) in a transition by the owner
- Records cannot be read in `async function` (finalize) — only mappings can
- A transition that produces a record does not need finalize
- `owner` is a reserved field name — it cannot be used for other purposes
- `record` is a reserved keyword — do not use it as a variable or type name

---

## Mappings

```leo
mapping balances: address => u64;
mapping token_data: field => TokenInfo;
```

Mappings are **public** persistent key-value stores maintained by validators.
Anyone can read them via the Provable API. Never put private data in a mapping.

### Accessing mappings (finalize only)

```leo
// Read with default if missing
let bal: u64 = balances.get_or_use(addr, 0u64);

// Read — panics if key missing
let bal: u64 = balances.get(addr);

// Write
balances.set(addr, new_val);

// Remove
balances.remove(addr);

// Check existence
let exists: bool = balances.contains(addr);
```

All mapping operations are only valid inside `async function` (finalize).
They cannot appear in transitions.

### Storage Variables and Vectors (v3.5.0+)

```leo
// Singleton on-chain value
storage counter: u64;

// Dynamic on-chain list
storage items: [TokenInfo];
```

Storage variables provide simpler alternatives to single-key mapping patterns.

### External Storage Access (v3.5.0+)

Programs can read mappings and storage from other deployed programs:

```leo
// Read another program's storage variable
let counter: u32? = token.aleo/counter;

// Read another program's mapping
let balance: u32? = token.aleo/balance.get(0);
```

The `?` suffix indicates the value may not exist (optional type).

---

## Transitions

Transitions are the callable interface of a program.

```leo
// Basic transition — private inputs, private output (record)
transition transfer_private(
    sender_token: Token,
    recipient: address,
    amount: u64,
) -> (Token, Token) {
    // verify sender owns the token (implicit — owner field checked by runtime)
    assert(sender_token.amount >= amount);

    let recipient_token: Token = Token {
        owner: recipient,
        amount,
    };
    let change: Token = Token {
        owner: sender_token.owner,
        amount: sender_token.amount - amount,
    };
    return (change, recipient_token);
}
```

### Async transitions (with finalize)

Use when you need to update a mapping.

```leo
async transition transfer_public(
    to: address,
    amount: u64,
) -> Future {
    return finalize_transfer_public(self.caller, to, amount);
}

async function finalize_transfer_public(
    from: address,
    to: address,
    amount: u64,
) {
    let from_bal: u64 = balances.get_or_use(from, 0u64);
    assert(from_bal >= amount);
    balances.set(from, from_bal - amount);

    let to_bal: u64 = balances.get_or_use(to, 0u64);
    balances.set(to, to_bal + amount);
}
```

`self.caller` gives you the address of the caller (verified by the proof).
It's the correct way to authenticate — don't pass `caller` as an input.

---

## Functions (helper functions)

```leo
// Regular helper — not directly callable externally
function compute_fee(amount: u64) -> u64 {
    return amount / 100u64;
}
```

Call with `compute_fee(my_amount)` inside a transition or other function.

---

## Inline Functions

```leo
// Inline — expanded into the calling transition's circuit at compile time
inline compute_hash(high: u128, low: u128) -> field {
    return (high as field) * 340282366920938463463374607431768211456field + (low as field);
}
```

`inline` functions differ from regular `function`:
- They are inlined into the calling circuit (no separate function call overhead)
- Use for small, performance-critical helpers that should be proven in-circuit
- Cannot be called externally
- Useful for field derivation, key composition, and other cryptographic helpers

The `as` keyword casts between types inside the circuit — the proof covers
the cast, so validators don't need to trust the caller's arithmetic.

---

## Imports

```leo
import credits.aleo;   // standard Aleo credits program

// Then use:
credits.aleo/transfer_public(to, amount);
```

For multi-file projects, Leo supports local imports:
```leo
import token_utils.leo;
```

See `references/cross-program.md` for detailed cross-program call patterns.

---

## Visibility in Outputs

Transition outputs can be:
```leo
transition example() -> (u64, u64) {
    return (value_1, value_2);          // both private by default
}

// Explicitly public output:
transition example() -> (u64, u64.public) {
    return (private_val, public_val);
}
```

Public outputs appear in the transaction body and are visible to everyone.
Private outputs are encrypted.

---

## Hashing

Leo provides built-in hash functions:

```leo
// BHP256 hash — commonly used for mapping keys
let hash: field = BHP256::hash_to_field(value);

// Poseidon hash — ZK-friendly, efficient in circuits
let hash: field = Poseidon2::hash_to_field(value);
let hash: field = Poseidon4::hash_to_field(value);
let hash: field = Poseidon8::hash_to_field(value);

// Hash a struct
let key_hash: field = BHP256::hash_to_field(my_struct);

// Commit (hash with randomness — useful for hiding values)
let commitment: field = BHP256::commit_to_field(value, randomness);
```

Use Poseidon for in-circuit hashing (cheaper constraints). Use BHP for
general-purpose hashing.

---

## Conditional Logic

```leo
// Ternary (preferred for simple cases)
let result: u64 = condition ? value_a : value_b;

// If-else
if condition {
    // ...
} else {
    // ...
}
```

**Important:** In ZK circuits, both branches are always evaluated. The condition
only selects which result is used. This means:
- Both branches must be valid (no division by zero in either branch)
- Performance cost is the sum of both branches
- Side effects in both branches will occur

---

## Loops

```leo
// Bounded for loop (bounds must be compile-time constants)
for i: u32 in 0u32..10u32 {
    // ...
}
```

Leo only supports bounded loops with compile-time-known bounds. There are no
while loops or dynamic iteration. If you need variable-length processing,
design around fixed-size arrays with sentinel values.

Empty ranges (`0u32..0u32`) are valid as of v3.4.0.

---

## Arrays

```leo
// Fixed-size arrays
let arr: [u64; 4] = [1u64, 2u64, 3u64, 4u64];
let val: u64 = arr[2];  // index access
```

Arrays must have compile-time-known sizes. There are no dynamic arrays or
vectors in Leo.

---

## Security Patterns

**Ownership check for records:** Enforced automatically by the protocol — only
the address in `record.owner` can spend the record as a transition input. You
don't write an explicit check; it's guaranteed.

**Authorization via self.caller:**
```leo
// Good — use self.caller for authenticated action
async transition admin_action() -> Future {
    assert_eq(self.caller, ADMIN_ADDRESS);
    return finalize_admin_action(self.caller);
}

// Bad — passing caller as parameter is forgeable from other programs
async transition admin_action(caller: address) -> Future { ... }
```

**Overflow protection:** Leo arithmetic wraps on overflow for unsigned types
in transitions. In finalize, use `checked` arithmetic or validate inputs:
```leo
let new_bal: u64 = old_bal.add_wrapped(amount);  // explicit wrap
// or
assert(old_bal <= u64::MAX - amount);             // check before add
```

**Never put secrets in mappings.** Mappings are fully public. A secret stored
in a mapping is immediately visible to anyone watching the chain.

**Replay protection:** If your program accepts a signature or proof-of-knowledge,
include a nonce (stored in a mapping) to prevent replay:
```leo
mapping used_nonces: field => bool;

async function finalize_action(nonce: field) {
    assert(!used_nonces.contains(nonce));
    used_nonces.set(nonce, true);
}
```

---

## Common Compiler Errors

| Error | Likely Cause |
|-------|-------------|
| `type mismatch` | Integer type suffix wrong — check `u64` vs `u32` etc. |
| `cannot find variable` | Typo, wrong scope, or forgot to return a value |
| `record type cannot appear in finalize` | You tried to use a record in `async function` |
| `mapping operation outside of finalize` | `get`/`set`/`contains` called in a transition |
| `transition has multiple returns of the same record type` | Leo needs distinct types or explicit tagging |
| `program ID mismatch` | `program.json` name doesn't match `program X.aleo;` in `main.leo` |
| `reserved keyword` | Used `owner`, `record`, or `self` as a variable/field name outside their intended context |
| `inline function cannot be called externally` | `inline` functions are only callable from transitions or other functions |
| `import not found` | The imported program isn't deployed or the import path is wrong |
| `loop bound must be a constant` | For-loop bounds must be compile-time literals, not variables |

---

## Leo CLI Quick Reference

```bash
leo build                          # compile, check types (shortcut: leo b)
leo run <transition> <args>        # execute locally, no proof (shortcut: leo r)
leo execute <transition> <args>    # execute with proof generation
leo execute <transition> <args> --broadcast --yes  # execute and submit to network
leo execute <transition> <args> --path ./contracts  # point to Leo project directory
leo test                           # run test functions (shortcut: leo t)
leo test <name>                    # run tests matching name
leo deploy                         # deploy to configured network
leo deploy --estimate-fee          # estimate deployment cost without deploying
leo query program <id>             # check if program is deployed
leo query mapping <prog> <map> <key>  # read a mapping value
leo fmt                            # auto-format .leo files (v3.5.0+)
leo abi                            # extract ABI from compiled program (v3.5.0+)
leo devnode                        # start a local dev node (v3.5.0+)
leo clean                          # remove build artifacts
leo --help                         # full command reference
leo <cmd> --json-output            # structured JSON output (v3.5.0+)
```

Always run `leo build` before `leo execute` or `leo deploy`.

---

## Leo.toml

```toml
[program]
name = "my_program"
version = "0.0.0"
description = ""
license = "MIT"

[dependencies]
# example local dependency
# credits = { path = "../credits" }
```

Check this file to confirm the program name and any dependency setup before
making assumptions about imports.
