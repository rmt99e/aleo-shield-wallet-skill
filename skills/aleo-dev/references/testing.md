# Testing Leo Programs Reference

Strategies for testing Aleo programs at every stage: local development,
proof verification, and integration testing.

---

## Testing Pyramid for Aleo

```
                    ┌──────────────┐
                    │  On-chain    │  Deploy to testnet, verify with explorer
                    │  (testnet)   │
                   ─┼──────────────┼─
                   │   Proof Test   │  `leo execute` — full zk-proof
                  ─┼────────────────┼─
                 │   Built-in Test   │  `leo test` — test functions (v3.5.0+)
                ─┼──────────────────┼─
               │    Local Run        │  `leo run` — fast, no proof
              ─┼────────────────────┼─
             │      Build Check      │  `leo build` — type checking
            ─┴──────────────────────┴─
```

Start from the bottom; only move up when the lower level passes.

---

## Level 0: Built-in Tests (`leo test`) — v3.5.0+

Leo has a built-in test runner. Annotate functions as tests and run them
with `leo test` (shortcut: `leo t`):

```bash
# Run all tests
leo test

# Run tests matching a name
leo test transfer

# Run a specific test
leo test test_mint_private
```

**What `leo test` does:**
- Compiles with test discovery enabled
- Runs each test function in isolation against a simulated ledger
- Reports pass/fail for each test
- Supports `should_fail` annotation for expected-failure tests

**Use for:** Unit testing transition logic, assertion checks, and expected
failure cases. This is the fastest feedback loop after `leo build`.

Tests run in isolation — each test gets its own clean ledger state.

**Note on `self.caller`:** In `leo test`, all test functions execute from the
same default address. This means you cannot easily test multi-party scenarios
(e.g., different callers) in a single test. Workarounds:
- Use `--private-key` flag with different keys for separate `leo run`/`leo execute` calls
- Test admin checks by running with a non-admin key and expecting failure
- For complex multi-party tests, use a local devnet with multiple accounts

---

## Level 1: Build Check

```bash
leo build
```

Catches:
- Type mismatches
- Undeclared variables
- Invalid record/struct fields
- Mapping operations outside finalize
- Import errors
- Program ID mismatches

Run `leo build` after every code change. It's fast (< 1 second for most programs).

---

## Level 2: Local Run (`leo run`)

```bash
# Run a transition locally — no proof, no network, fast feedback
leo run mint_private aleo1abc...  100u64

# Run with multiple outputs
leo run transfer_private "{
  owner: aleo1sender...,
  amount: 500u64,
  _nonce: 0group.public
}" aleo1recipient... 200u64
```

**What `leo run` does:**
- Executes the transition logic
- Checks assertions
- Prints output values
- Does NOT generate a zk-proof (fast — milliseconds)
- Does NOT execute finalize logic

**Use for:** Rapid iteration on transition logic, testing input/output shapes.

### Testing finalize locally

`leo run` does NOT execute finalize blocks. To test finalize logic:
1. Reason about the finalize inputs (they come from the transition's return)
2. Use `leo execute` (Level 3) which runs finalize in simulation
3. Or deploy to local devnet for full end-to-end testing

---

## Level 3: Local Execute (`leo execute`)

```bash
# Generate a real zk-proof locally
leo execute mint_private aleo1abc... 100u64
```

**What `leo execute` does:**
- Generates a full zk-proof (slow — 10-60 seconds)
- Simulates finalize execution
- Validates all constraints
- Prints the transaction object

**Use for:** Verifying that your program compiles to valid circuits and that
inputs satisfy all constraints.

### Testing assertion failures

```bash
# This should fail if amount > sender's balance
leo execute transfer_private "{
  owner: aleo1sender...,
  amount: 100u64,
  _nonce: 0group.public
}" aleo1recipient... 200u64

# Expected: constraint violation error
```

Test both success and failure cases. Verify that invalid inputs are rejected.

---

## Level 4: Testnet Deployment & Execution

```bash
# Deploy
leo deploy --network testnet --private-key $ALEO_PRIVATE_KEY --broadcast

# Execute on testnet
leo execute mint_private aleo1abc... 100u64 \
    --network testnet \
    --private-key $ALEO_PRIVATE_KEY \
    --broadcast --yes

# Verify the transaction
leo query transaction <tx_id> --network testnet

# Check mapping state after finalize
leo query mapping my_program.aleo balances aleo1abc... --network testnet
```

**Use for:** Full integration testing, verifying finalize logic on-chain,
testing with real network conditions.

---

## Record Input Format

When passing records as inputs to `leo run` or `leo execute`, use this format:

```
"{
  owner: aleo1address...,
  field_name: value,
  _nonce: 0group.public
}"
```

**Notes:**
- The `_nonce` field is required — use `0group.public` for testing
- Wrap the entire record in double quotes on the command line
- Use the exact field names from your record definition
- Type suffixes are required: `100u64`, `true`, `aleo1...`

---

## Testing Patterns

### Happy Path Testing

Test each transition with valid inputs:

```bash
# 1. Mint a token
leo run mint_private aleo1owner... 1000u64

# 2. Transfer part of it
leo run transfer_private "{
  owner: aleo1owner...,
  amount: 1000u64,
  _nonce: 0group.public
}" aleo1recipient... 300u64

# Expected: two output records (change: 700, recipient: 300)
```

### Edge Case Testing

```bash
# Zero amount
leo run transfer_private "{...}" aleo1recipient... 0u64

# Exact balance (no change)
leo run transfer_private "{
  owner: aleo1owner...,
  amount: 100u64,
  _nonce: 0group.public
}" aleo1recipient... 100u64

# Overflow attempt
leo run mint_private aleo1owner... 18446744073709551615u64  # u64::MAX
```

### Authorization Testing

```bash
# Test that admin-only transitions reject non-admin callers
# (This requires executing from a non-admin key)
leo execute admin_action --private-key $NON_ADMIN_KEY
# Expected: assertion failure
```

---

## Debugging Workflow

When something fails:

### 1. Read the error message
Leo errors are precise. Don't skip them.

### 1b. Use `leo debug` for interactive debugging
```bash
leo debug <transition> <inputs>
# or with TUI mode:
leo debug --tui <transition> <inputs>
```
Step through execution, inspect variables, and set breakpoints. See
`references/debugging.md` for full debugger reference.

### 2. Isolate the problem
```bash
# Does it build?
leo build

# Does it run (logic only)?
leo run <transition> <args>

# Does it execute (with proof)?
leo execute <transition> <args>
```

### 3. Simplify inputs
Start with the simplest possible inputs and add complexity.

### 4. Check types
The most common error is a type mismatch. Verify every literal has the
correct suffix (`u64`, `field`, `group`, etc.).

### 5. Check finalize separately
If `leo execute` passes but on-chain execution fails, the issue is in
finalize. Check:
- Mapping key existence (`get` vs `get_or_use`)
- Arithmetic overflow
- Assertion conditions

---

## CI Integration

### GitHub Actions Example

```yaml
name: Leo CI
on: [push, pull_request]

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Leo
        run: |
          curl -L https://raw.githubusercontent.com/ProvableHQ/leo/mainnet/install.sh | bash
          echo "$HOME/.leo/bin" >> $GITHUB_PATH

      - name: Build
        run: leo build

      - name: Run built-in tests
        run: leo test

      - name: Run manual test cases
        run: |
          leo run mint_private aleo1test... 100u64
          leo run transfer_private "{owner: aleo1test..., amount: 100u64, _nonce: 0group.public}" aleo1other... 50u64

      # Optional: full proof generation (slow, use sparingly)
      # - name: Execute with proof
      #   run: leo execute mint_private aleo1test... 100u64
```

### Tips for CI:
- Always run `leo build` — it's fast and catches most issues
- Use `leo run` for logic tests — fast enough for every PR
- Reserve `leo execute` for release branches — proof generation is slow
- Cache the Leo installation between runs
- Don't deploy from CI without manual approval gates

---

## Local Devnet Testing

For full end-to-end testing with finalize:

```bash
# Terminal 1: Start local devnet
snarkos devnet

# Terminal 2: Deploy and test
leo deploy --network local --private-key <devnet_key> --broadcast
leo execute mint_private aleo1abc... 100u64 --network local --private-key <devnet_key> --broadcast --yes

# Check mapping state
curl http://localhost:3030/program/my_program.aleo/mapping/balances/aleo1abc...
```

The local devnet provides instant block confirmations, making it ideal for
testing finalize logic without waiting for testnet block times.

---

## Test Data Management

### Generating test addresses

```bash
# Use the SDK or Leo to generate throwaway accounts
# In a Node.js script:
import { Account } from "@provablehq/sdk";
const account = new Account();
console.log(account.address().to_string());
console.log(account.privateKey().to_string());
```

### Consistent test data

Create a `test_inputs.sh` script at your project root:

```bash
#!/bin/bash
# Test addresses (throwaway — never use on mainnet)
export TEST_ADDR_1="aleo1..."
export TEST_ADDR_2="aleo1..."
export TEST_KEY_1="APrivateKey1..."

# Common test cases
leo run mint_private $TEST_ADDR_1 100u64
leo run transfer_private "{owner: $TEST_ADDR_1, amount: 100u64, _nonce: 0group.public}" $TEST_ADDR_2 50u64
```
