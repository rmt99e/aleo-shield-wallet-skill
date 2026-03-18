# Debugging Reference

Tools and strategies for debugging Leo programs on Aleo.

---

## `leo debug` — Interactive Debugger

Leo includes a built-in debugger REPL for stepping through program execution.

```bash
# Start the debugger for a transition
leo debug <transition_name> <inputs>

# Example
leo debug mint_private aleo1abc... 100u64
```

### REPL Commands

| Command | Short | Description |
|---------|-------|-------------|
| `step` | `s` | Step to the next instruction |
| `next` | `n` | Step over (skip into function calls) |
| `continue` | `c` | Run until next breakpoint or end |
| `break <line>` | `b` | Set a breakpoint at a line number |
| `print <var>` | `p` | Print the current value of a variable |
| `backtrace` | `bt` | Show the call stack |
| `list` | `l` | Show source code around current position |
| `quit` | `q` | Exit the debugger |
| `help` | `h` | Show available commands |

### TUI Mode

For a richer visual experience:

```bash
leo debug --tui <transition_name> <inputs>
```

TUI mode shows source code, variables, and call stack in a split-pane terminal UI.

---

## Cheatcodes

Cheatcodes are special functions available only in debug/test mode that let you
inspect and manipulate program state.

### `CheatCode::print_mapping()`

Print the current contents of a mapping during debugging:

```leo
// In a test or debug session
CheatCode::print_mapping(balances);
// Output: { aleo1abc... => 100u64, aleo1def... => 200u64 }
```

### `CheatCode::set_block_height()`

Set the simulated block height for testing time-dependent logic:

```leo
// Simulate being at block 1000
CheatCode::set_block_height(1000u32);
```

Useful for testing timelock patterns, vesting schedules, or any logic that
depends on `block.height`.

---

## Debugging Imported Programs

When your program imports another program and something fails:

1. **Isolate the import** — test the imported program independently first:
   ```bash
   leo debug <imported_transition> <args> --path ./path/to/imported/program
   ```

2. **Check deployment status** — the imported program must be deployed:
   ```bash
   leo query program imported_program.aleo --network testnet
   ```

3. **Verify interface compatibility** — ensure your import matches the deployed
   version's transition signatures

4. **Future chain debugging** — if a cross-program future fails, the error
   usually originates in the called program's finalize. Debug that program's
   finalize block directly.

---

## Six Debugging Strategies

### 1. Binary Search Isolation

When a complex transition fails, comment out half the logic and narrow down:

```leo
transition complex_action(/* ... */) -> Token {
    // Step 1: Does this part work?
    let intermediate: u64 = compute_a(input);

    // Step 2: Comment out the rest, return early
    return Token { owner: self.caller, amount: intermediate };

    // Step 3: Uncomment progressively until you find the failure
    // let result: u64 = compute_b(intermediate);
    // ...
}
```

### 2. Type Annotation Debugging

When you get a type error, add explicit type annotations to every variable:

```leo
// If this fails with a type error:
let result = a + b;

// Add explicit types to find the mismatch:
let result: u64 = (a as u64) + (b as u64);
```

### 3. Finalize Logging via Mappings

Since you can't print from finalize, use a debug mapping:

```leo
mapping debug_log: u8 => field;

async function finalize_action(/* ... */) {
    // Log intermediate values for inspection
    debug_log.set(0u8, intermediate_value);
    debug_log.set(1u8, another_value);

    // ... actual logic ...
}
```

Then query the debug mapping after execution:
```bash
leo query mapping my_program.aleo debug_log 0u8 --network testnet
```

Remove debug mappings before production deployment.

### 4. Minimal Reproduction

Create the smallest possible program that reproduces the error:

```leo
program debug_repro.aleo;

@noupgrade
async constructor() {}

// Paste only the failing logic here
transition repro() -> u64 {
    // ...minimal code that triggers the error...
    return 0u64;
}
```

### 5. Input Simplification

Start with the simplest possible inputs and add complexity:

```bash
# Start simple
leo run my_transition 0u64

# Add complexity
leo run my_transition 100u64

# Add full inputs
leo run my_transition 100u64 aleo1abc...
```

### 6. Constraint Count Analysis

If proving is slow or fails, check the constraint count:

```bash
leo build --json-output 2>&1 | grep constraints
```

High constraint counts (> 100,000) indicate complex circuits. Consider:
- Simplifying logic
- Moving computation off-chain (pass as input, verify in-circuit)
- Splitting into multiple transitions

---

## Common Debugging Scenarios

### "It builds but fails at execution"

The program compiles (type-correct) but constraints aren't satisfied at runtime.
- Check all `assert` / `assert_eq` statements with your specific inputs
- Use `leo debug` to step through and find which assertion fails

### "Finalize keeps failing on-chain"

The transition succeeds locally but finalize fails on validators.
- Mapping state on-chain differs from your local assumptions
- Query current mapping values before executing
- Use `get_or_use` instead of `get` to handle missing keys

### "Proving takes forever"

Circuit is too large.
- Check constraint count
- Look for unnecessary nested loops
- Consider splitting into multiple transitions
- Move non-critical computation off-chain

### "Works on devnet, fails on testnet"

- Different program state (mappings have different values)
- Different imported program versions
- Network congestion causing timeouts
- Fee estimation difference
