# Program Upgradability Reference

Aleo programs support controlled upgrades via upgrade annotations and constructors.
This was introduced in Leo 3.1.0. Programs deployed before 3.1.0 are immutable and
cannot be retrofitted for upgradability.

---

## Constructors

Every Leo program must have a `constructor`. The constructor runs once at deployment
time and sets initial program metadata.

```leo
program my_token.aleo {

    @admin(address="aleo1admin...")
    async constructor() {
        // Runs once at deployment
        // self.edition starts at 0 and auto-increments on each upgrade
    }

    // ... transitions, mappings, etc.
}
```

> **Note:** As of Leo 3.1.0+, programs use block syntax (`program name.aleo { ... }`)
> and the constructor is `async constructor()`.

### Constructor Metadata

Inside the constructor (and transitions), the following metadata is available:

| Field | Type | Description |
|-------|------|-------------|
| `self.edition` | `u16` | Auto-incrementing version counter, starts at 0, increments on each upgrade |
| `self.program_owner` | `address` | The address that deployed (and can upgrade) the program |
| `self.checksum` | `[u8; 32]` | Hash of the program's compiled bytecode |

```leo
async constructor() {
    // Access metadata
    let edition: u16 = self.edition;
    let owner: address = self.program_owner;
    let checksum: [u8; 32] = self.checksum;
}
```

---

## Upgrade Annotations

Annotations on the `constructor` control the upgrade policy:

### `@noupgrade`

The program is permanently immutable. No upgrades are possible after deployment.

```leo
@noupgrade
async constructor() {
    // This program can never be changed
}
```

Use this for programs that must be trustlessly immutable (e.g., core token contracts).

### `@admin(address="...")`

Only the specified address can upgrade the program.

```leo
@admin(address="aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq9yrgmn")
async constructor() {
    // Only the admin address can deploy upgrades
}
```

This is the most common upgrade pattern. The admin address controls when and how
the program is upgraded.

### `@checksum(mapping="...", key="...")`

Delegates the upgrade decision to a mapping value. A DAO or governance program
writes the approved checksum into a mapping, and this annotation checks it.

```leo
@checksum(mapping="basic_voting.aleo/approved_checksum", key="true")
async constructor() {
    // Upgrade only proceeds if the governance program has approved this checksum
}
```

Use this for governance-gated upgrades where a separate voting program controls
which program versions are approved.

### `@custom`

The developer writes full custom upgrade logic directly in the constructor.

```leo
@custom
async constructor() {
    // Custom upgrade logic runs here
    if self.edition > 0u16 {
        // This is an upgrade (not initial deployment)
        assert(block.height >= 1300u32);  // timelock example
    }
}
```

This is the most flexible option — you can implement any upgrade governance model
directly in the constructor body.

---

## What Can Change Across Upgrades

| Element | Can Change? | Notes |
|---------|------------|-------|
| Existing transition signatures | No | Cannot modify or delete |
| Existing record types | No | Existing records must remain valid |
| Existing struct types | No | Used in mappings and cross-program calls |
| Existing mapping declarations | No | Existing mapping data must remain accessible |
| Internal transition logic | Yes | The core purpose of upgrades |
| Inline/function helpers | Yes | Internal implementation details |
| Constructor body | Yes | Runs again on each upgrade |
| **New** transitions | Yes | Can add new callable functions |
| **New** structs/records | Yes | Can add new types |
| **New** mappings | Yes | Can add new public state |

**Key rule:** You can *add* new components but cannot *modify or delete* existing ones.
Existing transition signatures, types, and mappings are frozen. This protects programs
that depend on yours.

---

## Upgrade Patterns

### Admin-Controlled Upgrade

The simplest pattern. One address controls upgrades.

```leo
@admin(address="aleo1admin_address_here")
async constructor() {
    // Admin can push updates at any time
}
```

**When to use:** Early-stage projects, centralized teams, rapid iteration.
**Risk:** Single point of failure — if the admin key is compromised, so is the program.

### Time-Locked Upgrade

Combine `@custom` with a timelock to give users time to react before an upgrade takes effect.

```leo
mapping pending_upgrade: u8 => field;      // checksum of pending upgrade
mapping upgrade_timestamp: u8 => u64;      // when the upgrade was proposed

@custom
async constructor() {}

async transition propose_upgrade(new_checksum: field) -> Future {
    assert_eq(self.caller, ADMIN);
    return finalize_propose(new_checksum, block.height);
}

async function finalize_propose(checksum: field, height: u64) {
    pending_upgrade.set(0u8, checksum);
    upgrade_timestamp.set(0u8, height);
}

async transition execute_upgrade() -> Future {
    return finalize_execute_upgrade(block.height);
}

async function finalize_execute_upgrade(current_height: u64) {
    let proposed_at: u64 = upgrade_timestamp.get(0u8);
    assert(current_height >= proposed_at + 1000u64);  // ~1000 block delay
}
```

### Governance-Gated Upgrade

Require community votes before an upgrade can proceed. See `@custom` example above.

### Admin Transfer

Transfer upgrade authority to a new address or to a DAO:

```leo
mapping admin: u8 => address;

async transition transfer_admin(new_admin: address) -> Future {
    return finalize_transfer_admin(self.caller, new_admin);
}

async function finalize_transfer_admin(caller: address, new_admin: address) {
    let current_admin: address = admin.get(0u8);
    assert_eq(caller, current_admin);
    admin.set(0u8, new_admin);
}
```

---

## Fallback: Versioned Program Names

For programs deployed before Leo 3.1.0 (no constructor, no upgrade annotations),
or when you explicitly want immutable deployments, use versioned naming:

1. Deploy `my_program_v1.aleo`, then `my_program_v2.aleo`, etc.
2. On the backend/frontend, cascade lookups across versions (newest first)
3. Old program data remains accessible — nothing is deleted on-chain
4. Plan your program naming early; short names (< 10 chars) cost significantly
   more to deploy

This is still a valid strategy and may be preferred when you want each version
to be independently immutable and auditable.

---

## Pre-3.1.0 Programs

Programs deployed before Leo 3.1.0:
- Have no constructor
- Cannot be upgraded
- Are permanently immutable
- Must use versioned naming for iteration

There is no migration path to add upgrade support to an already-deployed program.
If you need upgradability, you must deploy a new program with a constructor.

---

## Best Practices

1. **Always include a constructor** — even if you use `@noupgrade`, the constructor
   is required for deployment
2. **Start with `@admin`** for early development, consider `@custom` for production
3. **Document your upgrade policy** — users and auditors need to know who can
   upgrade and under what conditions
4. **Test upgrades on testnet** — deploy v1, upgrade to v2, verify state continuity
5. **Never lose the admin key** — if using `@admin`, losing the key means no more upgrades
6. **Consider timelocks for production** — gives users time to exit before changes take effect
