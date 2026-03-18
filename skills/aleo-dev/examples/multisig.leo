// Example: Multi-Signature Approval Pattern
// Demonstrates a simple 2-of-3 multisig using mappings.
//
// Pattern: an action requires approval from N of M authorized signers
// before it can be executed. Approvals are tracked in public mappings.
//
// This is a simplified example. Production multisig should include
// nonces, expiry, and action-specific data hashing.

program example_multisig_v1.aleo;

// ─── Constants ──────────────────────────────────────────────────────
// In production, make these configurable via an initialization transition.

// Threshold: number of approvals needed
// Hardcoded here for simplicity — 2 of 3

// ─── Types ──────────────────────────────────────────────────────────

struct Approval {
    action_id: field,    // unique identifier for the proposed action
    signer: address,     // who approved
}

// ─── Mappings ───────────────────────────────────────────────────────

// Authorized signers (address → true if authorized)
mapping signers: address => bool;

// Number of signers registered
mapping signer_count: u8 => u8;

// Approval tracking: (action_id, signer_index) → approved
// We use a field key derived from action_id + signer address
mapping approvals: field => bool;

// Approval count per action
mapping approval_count: field => u8;

// Whether an action has been executed
mapping executed: field => bool;

// Whether the multisig has been initialized
mapping initialized: u8 => bool;

// ─── Initialize ─────────────────────────────────────────────────────
// Set up the 3 authorized signers. Can only be called once.

async transition initialize(
    signer1: address,
    signer2: address,
    signer3: address,
) -> Future {
    return finalize_initialize(signer1, signer2, signer3);
}

async function finalize_initialize(
    signer1: address,
    signer2: address,
    signer3: address,
) {
    // Prevent re-initialization
    assert(!initialized.contains(0u8));
    initialized.set(0u8, true);

    signers.set(signer1, true);
    signers.set(signer2, true);
    signers.set(signer3, true);
    signer_count.set(0u8, 3u8);
}

// ─── Approve ────────────────────────────────────────────────────────
// A signer approves an action. Each signer can only approve once per action.

async transition approve(action_id: field) -> Future {
    return finalize_approve(action_id, self.caller);
}

async function finalize_approve(action_id: field, caller: address) {
    // Verify caller is an authorized signer
    assert(signers.get_or_use(caller, false));

    // Verify action hasn't already been executed
    assert(!executed.get_or_use(action_id, false));

    // Create a unique key for this (action, signer) pair
    let approval_key: field = BHP256::hash_to_field(
        Approval { action_id, signer: caller }
    );

    // Prevent double-approval
    assert(!approvals.get_or_use(approval_key, false));
    approvals.set(approval_key, true);

    // Increment approval count
    let count: u8 = approval_count.get_or_use(action_id, 0u8);
    approval_count.set(action_id, count + 1u8);
}

// ─── Execute ────────────────────────────────────────────────────────
// Execute an action once threshold is met. Anyone can call this
// (the threshold check is the authorization).

async transition execute(action_id: field) -> Future {
    return finalize_execute(action_id);
}

async function finalize_execute(action_id: field) {
    // Check threshold (2 of 3)
    let count: u8 = approval_count.get_or_use(action_id, 0u8);
    assert(count >= 2u8);

    // Prevent double execution
    assert(!executed.get_or_use(action_id, false));
    executed.set(action_id, true);

    // In a real implementation, this is where you'd trigger the actual
    // action (e.g., call another program's transition via external call).
    // The action_id would encode what to do.
}
