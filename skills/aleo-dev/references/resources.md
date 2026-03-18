# Aleo Developer Resources

Links, repos, tools, and community resources for Aleo development.

---

## Official Documentation

- **Leo Language Docs:** https://docs.leo-lang.org/leo
- **SDK Docs:** https://docs.leo-lang.org/sdk/typescript/overview
- **API Docs:** https://docs.explorer.provable.com/docs/api/v2/intro
- **Aleo Developer Docs:** https://developer.aleo.org
- **Wallet Adapter Docs:** https://aleo-dev-toolkit-documentation.vercel.app/docs/wallet-adapter
- **Upgradability Guide:** https://docs.leo-lang.org/guides/upgradability
- **Leo Syntax Cheatsheet:** https://docs.leo-lang.org/language/cheatsheet

---

## Core Repositories

| Repo | Description |
|------|-------------|
| [ProvableHQ/leo](https://github.com/ProvableHQ/leo) | Leo compiler and CLI |
| [ProvableHQ/snarkVM](https://github.com/ProvableHQ/snarkVM) | Zero-knowledge virtual machine |
| [ProvableHQ/snarkOS](https://github.com/ProvableHQ/snarkOS) | Aleo node implementation |
| [ProvableHQ/sdk](https://github.com/ProvableHQ/sdk) | TypeScript/JavaScript SDK |
| [ProvableHQ/aleo-dev-toolkit](https://github.com/ProvableHQ/aleo-dev-toolkit) | Wallet adapter, hooks, React integration |
| [ProvableHQ/leo-examples](https://github.com/ProvableHQ/leo-examples) | Official example programs |

---

## Developer Tools

| Tool | URL | Description |
|------|-----|-------------|
| Leo Playground | https://play.leo-lang.org | Browser-based Leo editor and executor |
| Provable Explorer | https://explorer.provable.com | Block explorer, program viewer, mapping reader |
| Aleoscan | https://aleoscan.io | Alternative block explorer |
| Provable Tools | https://tools.provable.com | Faucet, account generator, transaction builder |
| create-leo-app | `npm create leo-app@latest` | Project scaffolding CLI |

---

## IDE Support

| Editor | Extension | Features |
|--------|-----------|----------|
| VS Code | [Leo for VS Code](https://marketplace.visualstudio.com/items?itemName=aleohq.leo-extension) | Syntax highlighting, error diagnostics, snippets |
| IntelliJ | [Leo IntelliJ Plugin](https://plugins.jetbrains.com/plugin/19890-leo) | Syntax highlighting, basic completion |
| Sublime Text | Leo Sublime Package | Syntax highlighting |

The VS Code extension is the most actively maintained and feature-rich.

---

## Example Programs

| Program | Description | Key Patterns |
|---------|-------------|--------------|
| `token.leo` | Token with private/public transfers | Records, mappings, shield/unshield |
| `auction.leo` | Sealed-bid auction | Commit-reveal, phased execution |
| `vote.leo` | Private voting | Ballot records, tally mapping |
| `tictactoe.leo` | On-chain game | Turn-based state machine |
| `lottery.leo` | Random lottery | Randomness, fairness |
| `nft.leo` | Non-fungible token | Unique records, ownership |

Find these at https://github.com/ProvableHQ/leo-examples

---

## Network Endpoints

| Network | API Endpoint |
|---------|-------------|
| Mainnet | `https://api.explorer.provable.com/v1` |
| Testnet | `https://api.explorer.provable.com/v1/testnet` |
| Local devnet | `http://localhost:3030` |

---

## Faucet

- **Testnet faucet:** https://faucet.aleo.org
- Credits arrive as public balance in `credits.aleo/account` mapping
- Use `transfer_public_to_private` to convert to private records for testing

---

## Community

- **Discord:** https://discord.gg/aleo
- **Twitter/X:** https://twitter.com/AleoHQ
- **Forum:** https://community.aleo.org
- **GitHub Discussions:** https://github.com/ProvableHQ/leo/discussions

---

## Notable Ecosystem Projects

| Project | Category | Description |
|---------|----------|-------------|
| [Arcane Finance](https://arcane.finance) | DEX | Privacy-centric RFQ + AMM exchange |
| [Pondo](https://pondo.xyz) | Liquid Staking | Stake ALEO, receive pALEO; largest TVL on Aleo |
| [IZAR Protocol](https://izar.xyz) | Bridge | Privacy-preserving Ethereum ↔ Aleo bridge |
| [zPass](https://zpass.io) | Identity | Privacy-preserving identity verification SDK |
| Paxos USAD | Stablecoin | Private stablecoin on Aleo |
| Circle USDC | Stablecoin | Confidential USDC via xReserve |

---

## Wallet Downloads

| Wallet | URL | Status |
|--------|-----|--------|
| Shield (recommended) | https://shield.aleo.org | Primary, Provable-built |
| Fox Wallet | https://foxwallet.com | Third-party |
| Puzzle Wallet | https://puzzle.online | Third-party |
| Leo Wallet | https://leo.app | Third-party |
| Soter Wallet | https://sotertech.io | Third-party |
