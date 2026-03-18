# Ecosystem Patterns Reference

Real-world patterns from production Aleo applications. These go beyond basic
tutorials — they represent how teams actually build on Aleo.

> **Note:** Code examples are illustrative patterns inspired by these projects,
> not literal source code. Refer to each project's repo for exact syntax.

---

## NFT Pattern (ARC-721 / ARC-722)

The Aleo NFT standard supports private ownership with optional public visibility.

### Core NFT Record

```leo
record NFT {
    owner: address,
    data: TokenId,
    edition: scalar,    // random blinding factor for re-obfuscation
}

struct TokenId {
    collection: field,  // hash of collection name
    item: field,        // unique item identifier within collection
}
```

### Edition Scalar (Re-obfuscation)

The `edition` scalar is key to Aleo NFT privacy. On each transfer, a new
edition is generated, creating a new public commitment:

```leo
mapping nft_commits: field => bool;  // tracks all valid NFT commitments

transition transfer_private(nft: NFT, to: address) -> NFT {
    let new_edition: scalar = ChaCha::rand_scalar();
    let new_nft: NFT = NFT {
        owner: to,
        data: nft.data,
        edition: new_edition,
    };
    return new_nft;
}
```

**Why this matters:** Without re-obfuscation, observers could track an NFT
across transfers by watching the same commitment. The edition scalar ensures
each transfer produces a completely new public identifier.

### NFT Commitment

```leo
// Create a unique identifier for an NFT
inline commit_nft(token_id: TokenId, edition: scalar) -> field {
    return BHP256::commit_to_field(token_id, edition);
}
```

### Public ↔ Private Conversion

```leo
mapping nft_owners: field => address;  // public ownership registry

// Make NFT public (reveal ownership)
async transition transfer_private_to_public(
    nft: NFT,
    to: address,
) -> Future {
    let commitment: field = commit_nft(nft.data, nft.edition);
    return finalize_to_public(commitment, to);
}

async function finalize_to_public(commitment: field, owner: address) {
    nft_owners.set(commitment, owner);
}

// Make NFT private again
async transition transfer_public_to_private(
    token_id: TokenId,
    edition: scalar,
) -> (NFT, Future) {
    let nft: NFT = NFT {
        owner: self.caller,
        data: token_id,
        edition: ChaCha::rand_scalar(),  // new edition for privacy
    };
    let commitment: field = commit_nft(token_id, edition);
    return (nft, finalize_to_private(commitment, self.caller));
}

async function finalize_to_private(commitment: field, caller: address) {
    let owner: address = nft_owners.get(commitment);
    assert_eq(owner, caller);
    nft_owners.remove(commitment);
}
```

---

## RFQ DEX Pattern

Arcane Finance demonstrated that **Request-for-Quote (RFQ) is preferred over
AMM for privacy-preserving exchanges** on Aleo. AMMs cannot fully utilize
private records because liquidity pools require public state.

### How It Works

1. **Off-chain:** Market makers post signed quotes (price, amount, expiry)
2. **On-chain:** Taker submits the quote + maker's signature to a transition
3. **Atomic swap:** The transition verifies the signature and executes the swap
   via future chaining

### Quote Structure

```leo
struct Quote {
    maker: address,
    token_in: field,     // program ID hash of input token
    token_out: field,    // program ID hash of output token
    amount_in: u64,
    amount_out: u64,
    nonce: field,        // unique per quote, prevents replay
    expiry: u32,         // block height deadline
}

mapping executed_nonces: field => bool;  // replay prevention
```

### Atomic Swap Execution

```leo
async transition fill_quote(
    quote: Quote,
    sig: signature,  // maker's signature over the quote
) -> Future {
    // Verify maker signed this quote
    let quote_hash: field = BHP256::hash_to_field(quote);
    assert(sig.verify(quote.maker, quote_hash));

    // Execute both sides of the swap via cross-program calls
    let f1: Future = token_a.aleo/transfer_public(
        self.caller, quote.maker, quote.amount_in
    );
    let f2: Future = token_b.aleo/transfer_public(
        quote.maker, self.caller, quote.amount_out
    );

    return finalize_fill(f1, f2, quote.nonce, quote.expiry);
}

async function finalize_fill(
    f1: Future, f2: Future,
    nonce: field, expiry: u32,
) {
    f1.await();
    f2.await();
    // Replay prevention
    assert(!executed_nonces.contains(nonce));
    executed_nonces.set(nonce, true);
    // Expiry check
    assert(block.height <= expiry);
}
```

**Key insight:** The quote is signed off-chain (no gas), verified on-chain
(trustless). Private record transfers can be substituted for the public
transfers above for full privacy.

---

## Liquid Staking Pattern

Pondo (largest TVL on Aleo) demonstrates the liquid staking architecture:

### Core Concept

```
User deposits ALEO → Protocol mints pALEO (derivative token)
Protocol delegates ALEO → Multiple validators
Rewards accrue → pALEO/ALEO ratio increases
User burns pALEO → Receives ALEO + rewards
```

### Multi-Delegator Architecture

```leo
// Distribute across multiple delegators for decentralization
mapping delegator_balances: address => u64;  // 5 delegator addresses
mapping total_staked: u8 => u64;
mapping exchange_rate: u8 => u64;  // pALEO per ALEO (scaled by 1e6)

async transition stake(amount: u64) -> (StakingToken, Future) {
    let rate: u64 = /* fetch exchange rate */;
    let pALEO_amount: u64 = amount * 1000000u64 / rate;
    let token: StakingToken = StakingToken {
        owner: self.caller,
        amount: pALEO_amount,
    };
    return (token, finalize_stake(amount));
}
```

### Oracle-Based Rebalancing

The protocol periodically rebalances across validators based on oracle data
(validator performance, uptime, commission rates). This runs as an admin
transition with governance checks.

---

## Multi-Token Pattern (ERC-1155 Style)

For programs managing multiple token types (used by bridges, gaming, DeFi):

```leo
struct TokenKey {
    token_id: field,
    owner: address,
}

mapping balances: TokenKey => u64;
mapping token_metadata: field => TokenInfo;

struct TokenInfo {
    name_hash: field,
    total_supply: u64,
    decimals: u8,
}

async transition transfer(
    token_id: field,
    to: address,
    amount: u64,
) -> Future {
    return finalize_transfer(token_id, self.caller, to, amount);
}

async function finalize_transfer(
    token_id: field,
    from: address,
    to: address,
    amount: u64,
) {
    let from_key: TokenKey = TokenKey { token_id, owner: from };
    let to_key: TokenKey = TokenKey { token_id, owner: to };

    let from_bal: u64 = balances.get(from_key);
    assert(from_bal >= amount);
    balances.set(from_key, from_bal - amount);

    let to_bal: u64 = balances.get_or_use(to_key, 0u64);
    balances.set(to_key, to_bal + amount);
}
```

---

## Dependency Edition Pinning

When your program imports an upgradable dependency, you can pin to a specific
edition to protect against breaking changes:

```leo
import token.aleo;

async transition safe_transfer(to: address, amount: u64) -> Future {
    let f: Future = token.aleo/transfer_public(self.caller, to, amount);
    return finalize_safe_transfer(f);
}

async function finalize_safe_transfer(f: Future) {
    // Pin to a known-good edition of the dependency
    let edition: u16 = token.aleo/self.edition;
    assert(edition <= 3u16);  // reject if dependency upgraded beyond v3
    f.await();
}
```

This ensures your program won't silently execute against a newer (potentially
incompatible) version of a dependency.

---

## Notable Ecosystem Projects

| Project | Category | Key Pattern |
|---------|----------|-------------|
| Arcane Finance | DEX | RFQ model, Schnorr signature verification |
| Pondo | Liquid Staking | Multi-delegator, oracle rebalancing, derivative token |
| Hyperlane | Cross-Chain | 9-program messaging stack, warp routes, Ethereum interop |
| IZAR Protocol | Bridge | Three-program architecture (protocol + token + proxy) |
| zPass | Identity | Privacy-preserving credentials, age verification |
| Paxos USAD | Stablecoin | Private stablecoin on Aleo |
| Circle USDC | Stablecoin | Confidential USDC (xReserve) |

---

## Design Considerations for Production

1. **RFQ over AMM** for exchanges — AMMs require public liquidity pools which
   defeat Aleo's privacy advantages
2. **Multi-delegator for staking** — distributing across validators improves
   decentralization and reduces slashing risk
3. **Edition pinning for dependencies** — protects against unexpected behavior
   from upgradable imported programs
4. **Re-obfuscation for NFTs** — new edition scalar on every transfer prevents
   on-chain tracking
5. **Nonce mappings for replay prevention** — critical for any protocol
   accepting off-chain signatures
6. **Struct keys for multi-dimensional mappings** — combine token_id + owner
   into a struct key instead of nested mappings (which don't exist in Leo)
