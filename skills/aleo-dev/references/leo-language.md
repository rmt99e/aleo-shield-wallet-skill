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

// constructor, imports, structs, records, mappings, functions, transitions here
```

---

## Constructor (Leo 3.1.0+)

Every program must have a constructor. It runs once at deployment time and
controls the upgrade policy.

```leo
program my_program.aleo;

// Immutable program — no upgrades allowed
@noupgrade
async constructor() {}

// Admin-controlled upgrades
@admin(address="aleo1admin_address_here")
async constructor() {}

// Custom upgrade logic (developer writes logic in constructor body)
@custom
async constructor() {
    if self.edition > 0u16 {
        // Upgrade-specific checks (e.g., timelock)
    }
}
```

### Constructor Metadata

Available inside the constructor and transitions:

| Field | Type | Description |
|-------|------|-------------|
| `self.edition` | `u16` | Version counter, starts at 0, auto-increments on upgrade |
| `self.program_owner` | `address` | The deployer's address |
| `self.checksum` | `[u8; 32]` | Hash of compiled bytecode |

See `references/upgradability.md` for full upgrade annotation details.

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

### Optional Types (v3.3.0+)

Any type can be made optional with `?`:

```leo
let b_some: bool? = true;
let b_none: bool? = none;

// Unwrap (panics if none)
let val: bool = b_some.unwrap();

// Unwrap with default
let val2: bool = b_none.unwrap_or(false);

// Arrays of optionals
let arr: [u16?; 2] = [1u16, none];

// Optional structs
let point: Point? = Point { x: 8u32, y: 41u32 };
let empty: Point? = none;
```

**Restrictions:** `address` and `signature` types cannot be optional. Structs
containing those types also cannot be optional.

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

### Storage Variables and Vectors (v3.3.0+)

```leo
// Singleton on-chain value
storage counter: u64;

// Dynamic on-chain list
storage items: [TokenInfo];
```

Storage variables are syntactic sugar — the compiler rewrites them into mappings
under the hood. They are only usable in `async` functions/blocks.

```leo
// Storage variable operations (async context only)
let val: u64? = counter;           // read (returns optional)
let val2: u64 = counter.unwrap();  // unwrap
let val3: u64 = counter.unwrap_or(0u64);  // unwrap with default
counter = 42u64;                   // write
counter = none;                    // clear

// Storage vector operations (async context only)
let length: u32 = items.len();
let item: TokenInfo? = items.get(0u32);     // get by index (optional)
items.set(0u32, new_item);                  // set by index
items.push(new_item);                       // append
items.pop();                                // remove last
items.swap_remove(2u32);                    // swap with last and remove
items.clear();                              // remove all
```

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

### Async Blocks (Inline Finalize — v3.1.0+)

Instead of a separate `async function`, you can write finalize logic inline:

```leo
async transition mint(receiver: address, amount: u64) -> Future {
    return async {
        let current: u64 = balances.get_or_use(receiver, 0u64);
        balances.set(receiver, current + amount);
    };
}
```

This is equivalent to a named finalize function but more concise for simple cases.

### Context Variables

Available in transitions and constructors:

| Variable | Type | Description |
|----------|------|-------------|
| `self.caller` | `address` | Address of the caller (program or user) |
| `self.signer` | `address` | Address of the transaction signer (always the original user) |
| `self.address` | `address` | This program's own address |
| `self.edition` | `u16` | Program version counter |
| `self.program_owner` | `address` | Program deployer's address |
| `self.checksum` | `[u8; 32]` | Program bytecode hash |
| `block.height` | `u32` | Current block height (finalize/async only) |
| `block.timestamp` | `i64` | Current block timestamp (finalize/async only) |

**`self.caller` vs `self.signer`:** In a direct call, both are the user. In a
cross-program call, `self.caller` is the calling *program*, while `self.signer`
is still the original user who signed the transaction.

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
- **Unsigned subtraction in the "unused" branch can still underflow and panic**
  (e.g., `a >= b ? a - b : 0u64` panics if `b > a` even though the "else" is selected)
- Performance cost is the sum of both branches
- Side effects in both branches will occur

See `references/security.md` and `references/common-errors.md` for workarounds.

---

## Loops

```leo
// Bounded for loop (bounds must be compile-time constants)
for i: u32 in 0u32..10u32 {
    // ...
}
```

Leo only supports bounded loops with compile-time-known bounds. There are no
while loops, dynamic iteration, or recursion (direct or indirect). If you
need variable-length processing, design around fixed-size arrays with sentinel
values.

Empty ranges (`0u32..0u32`) are valid as of v3.4.0.

---

## Arrays

```leo
// Fixed-size arrays
let arr: [u64; 4] = [1u64, 2u64, 3u64, 4u64];
let val: u64 = arr[2];  // index access
```

Arrays must have compile-time-known sizes. There are no dynamic arrays or
vectors in Leo (use storage vectors for on-chain dynamic lists).

Empty arrays (`[u8; 0] = []`) are valid as of v3.4.0.

---

## Const Generics (v3.3.0+)

```leo
struct Matrix::[N: u32, M: u32] {
    data: [field; N * M],
}

let m = Matrix::[2, 2] { data: [0field, 1field, 2field, 3field] };

inline sum_first_n::[N: u32](arr: [u64; N]) -> u64 {
    let total: u64 = 0u64;
    for i: u32 in 0u32..N {
        total += arr[i];
    }
    return total;
}
```

Const generics allow parameterizing structs and functions by compile-time
constants. Useful for fixed-size data structures with configurable dimensions.

---

## Advanced Mapping Patterns

### Unverified State Pattern

Transitions cannot read mappings. For complex logic that depends on current
on-chain state, the caller passes the state as arguments and finalize verifies it:

```leo
struct AppState {
    admin: address,
    paused: bool,
    nonce: u64,
}

mapping app_state: bool => AppState;

// Transition receives "unverified" state from the caller
async transition execute_action(
    unverified_state: AppState,  // caller claims this is current state
    action_data: field,
) -> Future {
    // Use unverified_state for transition logic (e.g., check not paused)
    assert(!unverified_state.paused);
    return finalize_execute(unverified_state, action_data);
}

async function finalize_execute(unverified: AppState, action_data: field) {
    // Verify against actual on-chain state
    let actual: AppState = app_state.get(true);
    assert_eq(unverified, actual);  // reject if stale or wrong

    // Proceed with verified state...
}
```

**This is the fundamental pattern for any Aleo app with complex state logic.**
It's used extensively in production (e.g., Hyperlane's cross-chain messaging).
The caller (typically your frontend) queries the mapping via API first, then
passes it as a transition argument.

### Singleton State Pattern

For single-value state (program config, global counters), use a mapping keyed
by `true`:

```leo
mapping config: bool => Config;

async function finalize_init(cfg: Config) {
    config.set(true, cfg);  // single value, keyed by `true`
}

async function finalize_read() {
    let cfg: Config = config.get(true);
}
```

This is cleaner than the `u8 => T` keyed by `0u8` pattern and clearly
communicates singleton intent.

### Iterator Mapping Pattern

Aleo mappings cannot be enumerated. To list all entries, maintain a parallel
index mapping:

```leo
mapping routers: u32 => address;          // domain_id => address
mapping router_index: u32 => u32;         // sequential_index => domain_id
mapping router_count: bool => u32;        // true => total count

async function finalize_add_router(domain: u32, addr: address) {
    assert(!routers.contains(domain));
    routers.set(domain, addr);

    // Maintain the index for enumeration
    let count: u32 = router_count.get_or_use(true, 0u32);
    router_index.set(count, domain);
    router_count.set(true, count + 1u32);
}
```

Off-chain code can then enumerate all entries by reading indices 0..count.
This adds storage overhead but enables listing — essential for UIs and
relayers that need to discover all entries.

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

## Common Compiler Errors (Quick Reference)

| Error | Likely Cause |
|-------|-------------|
| `type mismatch` | Integer type suffix wrong — check `u64` vs `u32` etc. |
| `cannot find variable` | Typo, wrong scope, or forgot to return a value |
| `record type cannot appear in finalize` | You tried to use a record in `async function` |
| `mapping operation outside of finalize` | `get`/`set`/`contains` called in a transition |
| `program ID mismatch` | `program.json` name doesn't match `program X.aleo;` in `main.leo` |
| `missing constructor` | All programs require a constructor (Leo 3.1.0+) |

For detailed BAD/GOOD code examples, error code prefixes, deployment errors,
WASM/SDK errors, and runtime errors, see `references/common-errors.md`.

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
leo upgrade                        # upgrade a deployed program (requires upgrade annotation)
leo query program <id>             # check if program is deployed
leo query mapping <prog> <map> <key>  # read a mapping value
leo debug <transition> <args>      # interactive debugger (v3.5.0+)
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
