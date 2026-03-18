# Cross-Program Calls Reference

Aleo programs can call transitions in other deployed programs. This enables
composability — building complex applications from smaller, reusable programs.

---

## Basic External Call

To call another program, import it and call its transitions:

```leo
program my_app.aleo;

import credits.aleo;

// Transfer credits from caller to this program's logic
async transition pay(amount: u64) -> Future {
    let f: Future = credits.aleo/transfer_public(self.caller, aleo1recipient..., amount);
    return finalize_pay(f);
}

async function finalize_pay(f: Future) {
    f.await();  // ensure the credits transfer finalized
    // ... additional finalize logic
}
```

### Key rules:
1. The called program **must already be deployed** on the target network
2. Import syntax: `import <program_id>;`
3. Call syntax: `<program_id>/<transition_name>(args)`
4. If the called transition is `async`, it returns a `Future` that must be
   awaited in your finalize block

---

## Future Chaining

When calling async transitions from other programs, you receive `Future`
objects that must be resolved in finalize:

```leo
program orchestrator.aleo;

import token_a.aleo;
import token_b.aleo;

async transition swap(amount_a: u64, amount_b: u64) -> Future {
    // Call two external programs
    let f1: Future = token_a.aleo/transfer_public(self.caller, self.address, amount_a);
    let f2: Future = token_b.aleo/transfer_public(self.address, self.caller, amount_b);
    return finalize_swap(f1, f2);
}

async function finalize_swap(f1: Future, f2: Future) {
    f1.await();  // token_a transfer must succeed
    f2.await();  // token_b transfer must succeed
    // If either fails, the entire transaction reverts
}
```

**Important:** If any awaited future fails, the entire transaction fails
atomically. This gives you composable atomic operations.

---

## Deployment Order

Programs must be deployed bottom-up:

1. Deploy `token_a.aleo` first
2. Deploy `token_b.aleo` next
3. Deploy `orchestrator.aleo` last (it imports the others)

If you try to deploy a program that imports an undeployed program, the
deployment will fail. Check with:
```bash
leo query program token_a.aleo --network testnet
```

---

## Passing Records Across Programs

Records from one program can be consumed by another if:
- The record type is defined in the called program
- The caller owns the record
- The transition accepts the record as an input

```leo
program marketplace.aleo;

import nft_v1.aleo;

// Accept an NFT record defined in nft_v1.aleo
transition list_nft(nft: nft_v1.aleo/NFT, price: u64) -> Future {
    // The NFT record is consumed (spent)
    return finalize_list(nft.owner, price);
}
```

---

## Self-Referencing

Use `self.address` to refer to the program's own address (useful for
escrow patterns):

```leo
program escrow.aleo;

import credits.aleo;

// Lock credits into the escrow program
async transition deposit(amount: u64) -> Future {
    // Transfer credits from caller to this program
    let f: Future = credits.aleo/transfer_public(self.caller, self.address, amount);
    return finalize_deposit(f, self.caller, amount);
}

async function finalize_deposit(f: Future, depositor: address, amount: u64) {
    f.await();
    let current: u64 = deposits.get_or_use(depositor, 0u64);
    deposits.set(depositor, current + amount);
}
```

`self.address` is the deterministic address of the program itself. It can
hold public credit balances and participate in transfers.

---

## Architecture Patterns

### Hub-and-Spoke

One orchestrator program calls multiple specialized programs:

```
orchestrator.aleo
├── imports token.aleo
├── imports registry.aleo
└── imports credits.aleo
```

Good for: Coordinating multi-step workflows (swap, stake, vote).

### Layered

Programs build on each other in layers:

```
app_v2.aleo → imports app_v1.aleo → imports credits.aleo
```

Good for: Program versioning where v2 reads v1 mappings.

### Shared State via Mappings

Since mappings are public and readable by anyone (via API), one program can
write state and another program's frontend can read it — no import needed.
Cross-program reads only need an import when done in finalize.

---

## External Storage Access (v3.5.0+)

As of Leo v3.5.0, programs can read mappings and storage from other deployed
programs directly — without needing a cross-program call:

```leo
program reader.aleo;

import token.aleo;

transition check_balance(user: address) -> u64 {
    // Read another program's mapping — returns optional type
    let balance: u32? = token.aleo/balance.get(user);
    // Handle the optional
    let result: u32 = balance.unwrap_or(0u32);
    return result;
}
```

This is useful for read-only access. For write operations (updating another
program's state), you still need a full cross-program call.

---

## Limitations

- **No dynamic dispatch:** You must know at compile time which program you're
  calling. There's no equivalent of Solidity's `address.call(data)`.
- **No re-entrancy:** Aleo's execution model prevents re-entrancy by design.
  A called program cannot call back into the calling program in the same
  transaction.
- **Circular imports are forbidden:** If A imports B, B cannot import A.
- **Record types are program-scoped:** You can't create a record of another
  program's type — only consume or produce records defined in your own program
  (or pass through records defined in imported programs).
- **Import depth:** Keep import chains shallow. Each additional level adds
  circuit complexity and proving time.
