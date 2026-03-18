// Example: Private Token Program
// Demonstrates records, mappings, private/public transfers, and finalize.
//
// This is a reference implementation — adapt field names, access control,
// and transition signatures for your use case.

program example_token_v1.aleo;

// ─── Constructor ────────────────────────────────────────────────────
// Required for all programs (Leo 3.1.0+). @admin allows the deployer
// to upgrade the program later.

@admin(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq9yrgmn)
constructor {}

// ─── Records (private state) ────────────────────────────────────────

record Token {
    owner: address,
    amount: u64,
}

// ─── Mappings (public state) ────────────────────────────────────────

mapping public_balances: address => u64;
mapping total_supply: u8 => u64;  // single-key pattern: key 0u8 holds total

// ─── Private Mint ───────────────────────────────────────────────────
// Produces a private record. No on-chain state change.
// In production, gate this with an admin check.

transition mint_private(recipient: address, amount: u64) -> Token {
    // TODO: add access control (e.g., assert_eq(self.caller, ADMIN))
    return Token {
        owner: recipient,
        amount,
    };
}

// ─── Public Mint ────────────────────────────────────────────────────
// Updates public mapping. Anyone can see the balance.

async transition mint_public(to: address, amount: u64) -> Future {
    return finalize_mint_public(to, amount);
}

async function finalize_mint_public(to: address, amount: u64) {
    let current: u64 = public_balances.get_or_use(to, 0u64);
    public_balances.set(to, current + amount);

    // Track total supply
    let supply: u64 = total_supply.get_or_use(0u8, 0u64);
    total_supply.set(0u8, supply + amount);
}

// ─── Private Transfer ───────────────────────────────────────────────
// Consumes sender's record, produces two new records (change + recipient).

transition transfer_private(
    sender_token: Token,
    recipient: address,
    amount: u64,
) -> (Token, Token) {
    assert(sender_token.amount >= amount);

    let change: Token = Token {
        owner: sender_token.owner,
        amount: sender_token.amount - amount,
    };
    let recipient_token: Token = Token {
        owner: recipient,
        amount,
    };
    return (change, recipient_token);
}

// ─── Public Transfer ────────────────────────────────────────────────
// Moves balance between public mapping entries.

async transition transfer_public(to: address, amount: u64) -> Future {
    return finalize_transfer_public(self.caller, to, amount);
}

async function finalize_transfer_public(
    from: address,
    to: address,
    amount: u64,
) {
    let from_bal: u64 = public_balances.get_or_use(from, 0u64);
    assert(from_bal >= amount);
    public_balances.set(from, from_bal - amount);

    let to_bal: u64 = public_balances.get_or_use(to, 0u64);
    public_balances.set(to, to_bal + amount);
}

// ─── Public → Private (Shield) ──────────────────────────────────────
// Converts public balance to a private record.

async transition shield(amount: u64) -> (Token, Future) {
    let token: Token = Token {
        owner: self.caller,
        amount,
    };
    let f: Future = finalize_shield(self.caller, amount);
    return (token, f);
}

async function finalize_shield(owner: address, amount: u64) {
    let bal: u64 = public_balances.get_or_use(owner, 0u64);
    assert(bal >= amount);
    public_balances.set(owner, bal - amount);
}

// ─── Private → Public (Unshield) ────────────────────────────────────
// Converts a private record back to public balance.

async transition unshield(token: Token, amount: u64) -> (Token, Future) {
    assert(token.amount >= amount);
    let change: Token = Token {
        owner: token.owner,
        amount: token.amount - amount,
    };
    let f: Future = finalize_unshield(token.owner, amount);
    return (change, f);
}

async function finalize_unshield(owner: address, amount: u64) {
    let bal: u64 = public_balances.get_or_use(owner, 0u64);
    public_balances.set(owner, bal + amount);
}
