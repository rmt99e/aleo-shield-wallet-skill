// Example: First-Write-Wins Registry
// Demonstrates the immutable registry pattern with composite keys,
// timestamp tracking, and content-addressed storage.
//
// Use case: registering hashes, names, attestations, or any data
// that should be written once and never overwritten.

program example_registry_v1.aleo;

// ─── Constructor ────────────────────────────────────────────────────

@noupgrade
async constructor() {}

// ─── Types ──────────────────────────────────────────────────────────

struct RegistryEntry {
    content_hash: field,     // hash of the registered content
    creator: address,        // who registered it
    timestamp_high: u128,    // unix timestamp split into u128 halves
    timestamp_low: u128,     // (for 256-bit precision if needed)
}

// Composite key: enables per-creator lookups
struct RegistryKey {
    content_hash: field,
    creator: address,
}

// ─── Mappings ───────────────────────────────────────────────────────

// Primary registry: content_hash → entry (first-write-wins)
mapping entries: field => RegistryEntry;

// Per-creator index: (hash, creator) → exists
mapping creator_index: RegistryKey => bool;

// Counter for total entries
mapping entry_count: u8 => u64;

// ─── Inline Helpers ─────────────────────────────────────────────────

// Reconstruct a field element from two u128 halves
// Use when passing 256-bit hashes from JavaScript
inline reconstruct_field(high: u128, low: u128) -> field {
    return (high as field) * 340282366920938463463374607431768211456field + (low as field);
}

// ─── Register ───────────────────────────────────────────────────────
// Register a content hash. Fails if already registered (first-write-wins).

async transition register(
    content_hash_high: u128,
    content_hash_low: u128,
    timestamp_high: u128,
    timestamp_low: u128,
) -> Future {
    // Reconstruct hash in-circuit (proven correct by ZK proof)
    let content_hash: field = reconstruct_field(content_hash_high, content_hash_low);

    return finalize_register(
        content_hash,
        self.caller,
        timestamp_high,
        timestamp_low,
    );
}

async function finalize_register(
    content_hash: field,
    creator: address,
    timestamp_high: u128,
    timestamp_low: u128,
) {
    // First-write-wins: reject if already registered
    assert(!entries.contains(content_hash));

    let entry: RegistryEntry = RegistryEntry {
        content_hash,
        creator,
        timestamp_high,
        timestamp_low,
    };

    entries.set(content_hash, entry);

    // Update creator index
    let key: RegistryKey = RegistryKey {
        content_hash,
        creator,
    };
    creator_index.set(key, true);

    // Increment counter
    let count: u64 = entry_count.get_or_use(0u8, 0u64);
    entry_count.set(0u8, count + 1u64);
}

// ─── Verify ─────────────────────────────────────────────────────────
// Public verification: check if a hash is registered by a specific creator.
// This is a read-only check — query the mapping via API instead of
// executing this transition (saves fees).
//
// Use this transition only if you need an on-chain proof of verification.

async transition verify(
    content_hash_high: u128,
    content_hash_low: u128,
    expected_creator: address,
) -> Future {
    let content_hash: field = reconstruct_field(content_hash_high, content_hash_low);
    return finalize_verify(content_hash, expected_creator);
}

async function finalize_verify(
    content_hash: field,
    expected_creator: address,
) {
    let entry: RegistryEntry = entries.get(content_hash);
    assert_eq(entry.creator, expected_creator);
}
