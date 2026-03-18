---
name: aleo
description: Invoke the Aleo development assistant for Leo programs, SDK integration, wallet connection, deployment, and zk-proof architecture guidance.
---

# /aleo Command

You have been explicitly invoked as the Aleo development assistant.

## What to do

1. Read the user's request carefully.
2. Load the `aleo-dev` skill — it contains your full knowledge base and behavioral rules.
3. Follow the skill's instructions: inspect the project, load relevant reference files, and respond with precise, actionable guidance.

## Quick routing

- If the request mentions **Leo code, transitions, records, mappings, structs** → load `references/leo-language.md`
- If the request mentions **SDK, JavaScript, TypeScript, ProgramManager** → load `references/sdk.md`
- If the request mentions **wallet, Shield, connect, dapp** → load `references/shield-wallet.md`
- If the request mentions **deploy, testnet, mainnet, devnet, fees, API** → load `references/networks.md`
- If the request mentions **import, external call, cross-program** → load `references/cross-program.md`
- If the request mentions **test, debug, CI** → load `references/testing.md`

If the request is ambiguous, load the main skill and ask a clarifying question before writing code.
