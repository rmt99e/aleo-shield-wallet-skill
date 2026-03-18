# Hyperlane Cross-Chain Messaging Reference

Hyperlane is a permissionless interoperability protocol enabling Aleo programs
to send and receive messages to/from any Hyperlane-connected chain (Ethereum,
Cosmos, Solana, etc.). The Aleo implementation is production-ready (v1.0.0).

- Repo: https://github.com/hyperlane-xyz/hyperlane-aleo
- Docs: https://docs.hyperlane.xyz/
- License: Apache 2.0

> **Note:** Code examples in this file are illustrative patterns based on
> Hyperlane's architecture. For exact syntax and struct definitions, refer
> to the source code in the repo above.

---

## Architecture Overview

```
Origin Chain (e.g. Ethereum)          Aleo
┌─────────────────────┐     ┌─────────────────────────────────────┐
│                     │     │  dispatch_proxy.aleo                │
│  Mailbox.sol        │     │    ├── mailbox.aleo                 │
│    dispatch() ──────┼──▶──┼──  │    ├── dispatch()              │
│    process() ◀──────┼──◀──┼──  │    └── process()              │
│                     │     │    ├── hook_manager.aleo            │
│  ISM.sol            │     │    │    ├── MerkleTreeHook          │
│  IGP.sol            │     │    │    ├── IGP (gas payments)      │
│                     │     │    │    └── NoopHook                │
│                     │     │    └── ism_manager.aleo             │
│                     │     │         ├── MultisigIsm             │
│                     │     │         ├── DomainRoutingIsm        │
│                     │     │         └── NoopIsm                 │
│                     │     │                                     │
│                     │     │  Warp Routes (Token Bridges)        │
│                     │     │    ├── hyp_native.aleo    (credits) │
│                     │     │    ├── hyp_collateral.aleo (lock)   │
│                     │     │    └── hyp_synthetic.aleo (mint)    │
│                     │     │                                     │
│                     │     │  token_registry.aleo (token std)    │
│                     │     │  validator_announce.aleo            │
└─────────────────────┘     └─────────────────────────────────────┘
         ▲                              ▲
         └──── Relayer observes ────────┘
               & relays messages
```

### Message Flow

**Sending from Aleo (dispatch):**
1. Your app calls `dispatch_proxy.aleo/dispatch()` with destination domain, recipient, and message body
2. dispatch_proxy calls `mailbox.aleo/dispatch()` to create the message
3. dispatch_proxy calls `hook_manager.aleo/post_dispatch()` for the default hook (MerkleTree) and required hook (IGP)
4. All three futures are awaited atomically in finalize
5. A relayer picks up the message and delivers it to the destination chain

**Receiving on Aleo (process):**
1. A relayer calls `mailbox.aleo/process()` with the message and proof
2. mailbox queries `ism_manager.aleo` to verify the message (e.g., multisig threshold check)
3. Upon verification, mailbox delivers the message to the recipient application

---

## The Nine Programs

| Program | Purpose | Key Patterns |
|---------|---------|--------------|
| `mailbox.aleo` | Central message hub — dispatch and process | Singleton state, nonce tracking, registered apps |
| `hook_manager.aleo` | Post-dispatch hooks (Merkle tree, IGP, noop) | On-chain Merkle tree, gas payment calculation |
| `ism_manager.aleo` | Security verification (multisig, routing, noop) | ECDSA verification, Keccak256, domain routing |
| `dispatch_proxy.aleo` | Coordinates multi-program dispatch | Multi-future composition (3+ futures) |
| `validator_announce.aleo` | Validators publish storage locations | ECDSA recovery, replay protection |
| `hyp_native.aleo` | Bridge native Aleo credits | Lock/unlock credits.aleo, decimal scaling |
| `hyp_collateral.aleo` | Bridge existing tokens (lock/release) | Token registry integration, escrow |
| `hyp_synthetic.aleo` | Bridge wrapped tokens (mint/burn) | Synthetic token creation, cross-chain minting |
| `token_registry.aleo` | Full token standard | Public/private transfers, allowances, auth hooks |

---

## Aleo-Specific Architectural Adaptations

The Aleo implementation differs from EVM Hyperlane in several important ways:

### 1. Unverified State Pattern

Aleo transitions cannot read mappings. The caller must pass current on-chain
state as "unverified" arguments, and the finalize function validates them:

```leo
// The transition receives state it cannot verify
async transition process(
    message: Message,
    unverified_mailbox_state: MailboxState,  // caller claims this is current state
    unverified_ism: IsmType,                  // caller claims this ISM is configured
    message_length: u8,
) -> Future {
    // Transition logic uses the unverified values...
    return finalize_process(unverified_mailbox_state, unverified_ism, /* ... */);
}

async function finalize_process(
    unverified_state: MailboxState,
    unverified_ism: IsmType,
    // ...
) {
    // Verify against actual on-chain state
    let actual_state: MailboxState = mailbox_state.get(true);
    assert_eq(unverified_state, actual_state);  // reject if stale/wrong
    // Proceed with verified state...
}
```

This is critical for any complex Aleo app. See `references/leo-language.md`
for the general pattern.

### 2. Static Dispatch Proxy

AVM has no dynamic dispatch (no `address.call(data)` equivalent). The
dispatch_proxy hardcodes calls to mailbox and hook_manager:

```leo
// dispatch_proxy coordinates 3 cross-program calls
async transition dispatch(/* ... */) -> Future {
    let f1: Future = mailbox.aleo/dispatch(/* ... */);
    let f2: Future = hook_manager.aleo/post_dispatch(/* default hook */);
    let f3: Future = hook_manager.aleo/post_dispatch(/* required hook */);
    return finalize_dispatch(f1, f2, f3);
}

async function finalize_dispatch(f1: Future, f2: Future, f3: Future) {
    f1.await();
    f2.await();
    f3.await();
}
```

### 3. Message Length Parameter

AVM cannot determine variable-length data sizes at runtime. `process()`
requires an explicit `message_length` parameter. The mailbox uses 18
conditional branches in `dynamic_message_id()` to handle messages from
77 to 333 bytes.

### 4. Reduced Message Size

Maximum message body is 256 bytes (`[u128; 16]`) due to AVM constraints,
versus arbitrary length on EVM.

---

## Warp Routes (Token Bridges)

Warp Routes are the token bridge layer. Three variants cover all use cases:

### Native Credits Bridge (`hyp_native.aleo`)

Bridges Aleo's native credits to other chains:

```
Send:  User's credits → locked in hyp_native → message dispatched → minted on destination
Receive: Message arrives → hyp_native unlocks credits → sent to recipient
```

### Collateral Bridge (`hyp_collateral.aleo`)

Bridges existing tokens (from token_registry.aleo):

```
Send:  User's tokens → escrowed in hyp_collateral → message dispatched → minted on destination
Receive: Message arrives → hyp_collateral releases tokens → sent to recipient
```

### Synthetic Bridge (`hyp_synthetic.aleo`)

Creates wrapped (synthetic) tokens on Aleo representing assets from other chains:

```
Send:  User's synthetic tokens → burned → message dispatched → unlocked on origin
Receive: Message arrives → synthetic tokens minted → sent to recipient
```

### Decimal Scaling

Warp routes handle decimal differences between chains using inline scaling
functions. For example, Ethereum uses 18 decimals while Aleo uses 6 for
credits. `convert_outgoing_amount()` and `convert_ingoing_amount()` handle
the conversion with overflow protection.

---

## Building a Hyperlane-Connected App

### Registering Your Application

Before your program can receive messages, register it with the mailbox:

```leo
import mailbox.aleo;

// Your app must implement a handle() transition that the mailbox calls
async transition handle(
    origin: u32,           // source chain domain ID
    sender: [u8; 32],     // sender address (32 bytes, padded)
    body: [u128; 16],     // message body (up to 256 bytes)
    message_length: u8,
) -> Future {
    // Process the incoming cross-chain message
    // Decode body based on your protocol's format
    return finalize_handle(origin, sender, body);
}
```

### Dispatching a Message

```leo
import dispatch_proxy.aleo;

async transition send_cross_chain(
    destination_domain: u32,    // e.g., 1 for Ethereum
    recipient: [u8; 32],        // recipient address on destination
    message_body: [u128; 16],   // your encoded message
    // ... unverified state parameters
) -> Future {
    let f: Future = dispatch_proxy.aleo/dispatch(
        destination_domain,
        recipient,
        message_body,
        // ... hook metadata, unverified state
    );
    return finalize_send(f);
}

async function finalize_send(f: Future) {
    f.await();
}
```

### Router Pattern

Warp routes use a "router" pattern — each deployment knows its counterpart
addresses on other chains:

```leo
mapping remote_routers: u32 => [u8; 32];      // domain_id => remote address
mapping remote_router_iter: u32 => u32;         // index => domain_id (for enumeration)
mapping remote_router_length: bool => u32;      // true => count

async transition enroll_remote_router(
    domain: u32,
    router: [u8; 32],
) -> Future {
    assert_eq(self.caller, OWNER);
    return finalize_enroll(domain, router);
}
```

---

## Ethereum Interop Patterns

### EthAddress Type

```leo
struct EthAddress {
    bytes: [u8; 20],
}
```

### Keccak256 Hashing

Used for Ethereum-compatible message digests:

```leo
let digest: [u8; 32] = Keccak256::hash_to_bytes(message_data);
```

### Ethereum Signed Message Verification

```leo
// Implements "\x19Ethereum Signed Message:\n32" prefix
inline to_eth_signed_message_hash(digest: [u8; 32]) -> [u8; 32] {
    // Prepend Ethereum signing prefix, then hash again
    return Keccak256::hash_to_bytes(/* prefixed data */);
}
```

### ECDSA Signature Verification

The ism_manager and validator_announce use Leo's built-in signature
verification for checking Ethereum validator signatures.

### Endianness Conversion

Cross-chain protocols use big-endian; Aleo uses little-endian:

```leo
inline convert_endianness(input: [u8; 32]) -> [u8; 32] {
    // Reverse byte order for cross-chain compatibility
    return [
        input[31], input[30], input[29], /* ... */ input[1], input[0]
    ];
}
```

---

## Key Patterns Demonstrated

These patterns from Hyperlane are useful for any complex Aleo application:

1. **Unverified State** — Pass on-chain state as transition args, verify in finalize
2. **Iterator Mappings** — Parallel index mapping for enumerating mapping entries
3. **Singleton State** — `mapping state: bool => T` keyed by `true`
4. **Multi-Future Composition** — Chain 3+ cross-program calls atomically
5. **Decimal Scaling** — Handle different precision between systems
6. **Router Enrollment** — Manage known counterpart addresses across chains

See `references/leo-language.md` for the general versions of these patterns.
