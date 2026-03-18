# aleo-dev.skill

A [Claude Code plugin](https://docs.anthropic.com/en/docs/claude-code) for Aleo blockchain development. Provides expert assistance for building private applications with Leo programs, the Provable SDK, Shield wallet, and zk-proof architecture.

## What it does

When installed, Claude Code automatically activates this skill when you're working on Aleo projects. It provides:

- **Leo language guidance** — correct syntax, records, mappings, transitions, finalize blocks, constructors, and common compiler errors
- **Program upgradability** — upgrade annotations (`@admin`, `@noupgrade`, `@custom`, `@checksum`), constructors, versioned naming fallback
- **SDK integration** — `@provablehq/sdk` usage, network-specific imports, delegated proving, bundler configuration
- **Shield wallet** — full React integration pattern with `aleo-dev-toolkit`, connect buttons, transaction execution, record fetching
- **Deployment** — mainnet/testnet/devnet configuration, fee estimation, `--broadcast` flag, private key management
- **Cross-program calls** — imports, future chaining, atomic composability, external storage access
- **Testing & debugging** — local run/execute workflow, `leo debug` REPL, CI integration, debugging strategies
- **Security** — ZK-specific vulnerabilities, security review checklist, common attack vectors
- **Privacy patterns** — records vs mappings decision framework, hybrid token, sealed-bid, private voting patterns
- **Architectural patterns** — custodial server, first-write-wins registry, privacy-preserving auth

## Install

**One-line install:**
```bash
curl -fsSL https://raw.githubusercontent.com/rmt99e/aleo-dev.skill/main/install.sh | bash
```

**Manual install:**
```bash
git clone https://github.com/rmt99e/aleo-dev.skill.git
claude plugin add ./aleo-dev.skill
```

**Direct path:**
```bash
claude plugin add /path/to/aleo-dev.skill
```

## Usage

The skill activates automatically when you work on Aleo projects. You can also invoke it explicitly:

```
/aleo scaffold a token program with private transfers
/aleo connect my React app to Shield wallet
/aleo deploy to testnet
```

## Structure

```
aleo-dev.skill/
├── .claude-plugin/
│   └── plugin.json              # Plugin manifest
├── commands/
│   └── aleo.md                  # /aleo slash command
├── install.sh                   # One-line installer
└── skills/
    └── aleo-dev/
        ├── SKILL.md             # Main skill definition
        ├── references/
        │   ├── leo-language.md  # Leo syntax & patterns
        │   ├── sdk.md           # Provable SDK reference
        │   ├── shield-wallet.md # Shield wallet integration
        │   ├── networks.md      # Network config & APIs
        │   ├── cross-program.md # Cross-program calls
        │   ├── testing.md       # Testing strategies
        │   ├── upgradability.md # Program upgrades & constructors
        │   ├── security.md      # ZK security & review checklist
        │   ├── privacy-patterns.md  # Privacy design patterns
        │   ├── common-errors.md # Detailed error examples
        │   ├── debugging.md     # leo debug & debugging strategies
        │   ├── resources.md     # Links, tools & community
        │   ├── ecosystem-patterns.md  # NFT, DEX, staking patterns
        │   └── hyperlane.md     # Cross-chain messaging via Hyperlane
        └── examples/
            ├── token.leo        # Token with private/public transfers
            ├── registry.leo     # First-write-wins registry
            └── multisig.leo     # Multi-signature approval
```

## License

MIT
