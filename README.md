# aleo-dev.skill

A [Claude Code plugin](https://docs.anthropic.com/en/docs/claude-code) for Aleo blockchain development. Provides expert assistance for building private applications with Leo programs, the Provable SDK, Shield wallet, and zk-proof architecture.

## What it does

When installed, Claude Code automatically activates this skill when you're working on Aleo projects. It provides:

- **Leo language guidance** — correct syntax, records, mappings, transitions, finalize blocks, and common compiler errors
- **SDK integration** — `@provablehq/sdk` usage, account management, program execution, fee estimation
- **Shield wallet** — full React integration pattern with `aleo-dev-toolkit`, connect buttons, transaction execution
- **Deployment** — mainnet/testnet/devnet configuration, fee estimation, private key management
- **Cross-program calls** — imports, future chaining, atomic composability
- **Testing** — local run/execute workflow, CI integration, debugging strategies
- **Architectural patterns** — custodial server, first-write-wins registry, privacy-preserving auth, program versioning

## Install

```bash
claude plugin add /path/to/aleo-dev.skill
```

Or clone and install:

```bash
git clone https://github.com/rmt99e/aleo-dev.skill.git
claude plugin add ./aleo-dev.skill
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
└── skills/
    └── aleo-dev/
        ├── SKILL.md             # Main skill definition
        ├── references/
        │   ├── leo-language.md  # Leo syntax & patterns
        │   ├── sdk.md           # Provable SDK reference
        │   ├── shield-wallet.md # Shield wallet integration
        │   ├── networks.md      # Network config & APIs
        │   ├── cross-program.md # Cross-program calls
        │   └── testing.md       # Testing strategies
        └── examples/
            ├── token.leo        # Token with private/public transfers
            ├── registry.leo     # First-write-wins registry
            └── multisig.leo     # Multi-signature approval
```

## License

MIT
