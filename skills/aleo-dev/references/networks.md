# Aleo Networks Reference

Aleo operates across three environments. Always confirm which network you're
targeting before writing CLI commands, API calls, or deployment scripts.

---

## Network Summary

| Network | Purpose | Faucet | Real funds |
|---------|---------|--------|------------|
| Mainnet | Production | None | Yes |
| Testnet | Pre-production testing | Yes | No |
| Local devnet | Local development | N/A (genesis) | No |

---

## Mainnet

**API endpoint (Provable):**
```
https://api.explorer.provable.com/v1
```

**Block explorers:**
- Provable Explorer: https://explorer.provable.com
- Aleoscan: https://aleoscan.io

**Use for:** Deploying production programs, real credits, real transactions.
**Never:** Hardcode mainnet private keys in code or scripts.

---

## Testnet

**API endpoint (Provable):**
```
https://api.explorer.provable.com/v1/testnet
```
or equivalently:
```
https://testnet.explorer.provable.com/v1
```

**Block explorers:**
- Provable Explorer: https://testnet.explorer.provable.com
- Aleoscan: https://testnet.aleoscan.io

**Faucet:**
- https://faucet.aleo.org — request testnet credits by address
- Credits from faucet are public (in a mapping). For testing private record
  flows, use `transfer_public_to_private` after receiving faucet funds.

**Use for:** All development and integration testing before mainnet deployment.

---

## Local Devnet (snarkOS)

Run a local network for fast iteration without needing testnet funds or
waiting for block confirmations.

### Setup

```bash
# Install snarkOS (check current install instructions at repo)
# https://github.com/ProvableHQ/snarkOS

# Start a local devnet (3-node by default)
snarkos devnet
```

Or use the Leo toolchain shortcut:
```bash
leo execute <transition> <args> --local
```

**Local API endpoint:**
```
http://localhost:3030
```

**Pre-funded development accounts:** snarkOS devnet starts with genesis
accounts that hold credits. Check the devnet startup output for private keys.

**Use for:** Rapid iteration, testing finalize logic, integration tests in CI.

---

## Leo CLI Network Flags

```bash
# Testnet
leo deploy --network testnet --private-key $ALEO_PRIVATE_KEY
leo execute mint_private "aleo1abc..." "100u64" --network testnet --private-key $ALEO_PRIVATE_KEY

# Mainnet
leo deploy --network mainnet --private-key $ALEO_PRIVATE_KEY

# Check if program is deployed
leo query program my_program.aleo --network testnet
leo query program my_program.aleo --network mainnet

# Read a mapping value
leo query mapping my_program.aleo balances aleo1abc... --network testnet

# Estimate deployment fee
leo deploy --estimate-fee --network testnet

# Execute and broadcast in one step (non-interactive)
leo execute mint_private "aleo1abc..." "100u64" --network testnet --private-key $ALEO_PRIVATE_KEY --broadcast --yes

# Point to a Leo project in a different directory
leo execute mint_private "aleo1abc..." "100u64" --path ./contracts --network testnet --private-key $ALEO_PRIVATE_KEY --broadcast --yes
```

---

## Provable API (REST)

Base URL:
- Mainnet: `https://api.explorer.provable.com/v1`
- Testnet: `https://api.explorer.provable.com/v1/testnet`

Full API docs: https://docs.explorer.provable.com/docs/api/v2/intro

### Common endpoints

```bash
# Latest block height
GET /block/height/latest

# Program source
GET /program/{program_id}

# Mapping value
GET /program/{program_id}/mapping/{mapping_name}/{key}

# Transaction
GET /transaction/{transaction_id}

# Unspent records (requires view key)
GET /program/{program_id}/records/unspent?viewkey={view_key}

# Account balance (mapping lookup on credits.aleo)
GET /program/credits.aleo/mapping/account/{address}
```

Example with curl:
```bash
curl "https://api.explorer.provable.com/v1/testnet/program/credits.aleo/mapping/account/aleo1abc..."
```

---

## Fee Guidelines

Fees are paid in Aleo credits. Values here are approximate — always use
`leo deploy --estimate-fee` or `ProgramManager.estimateExecutionFee`.

| Operation | Approximate fee |
|-----------|----------------|
| Simple transition | 0.01 – 0.05 credits |
| Transition with finalize | 0.02 – 0.1 credits |
| Program deployment (short name < 10 chars) | Higher — avoid short names |
| Program deployment (name ≥ 10 chars) | Lower |

Fees vary with proof size and network congestion. Never hardcode fee amounts
in production code.

> **Real-world deployment costs:** A non-trivial program (multiple transitions,
> records, mappings, inline functions) can cost 2–5 credits to deploy. Costs
> scale with circuit complexity (number of constraints), program size, and
> namespace length. Short program names (< 10 chars) incur a significant
> namespace premium — budget accordingly.

---

## Securing Private Keys in Scripts

```bash
# Good — use environment variable
export ALEO_PRIVATE_KEY="APrivateKey1..."
leo deploy --private-key $ALEO_PRIVATE_KEY --network testnet

# Good — use a .env file (never commit it)
# .env
ALEO_PRIVATE_KEY=APrivateKey1...

# Bad — hardcoded in script
leo deploy --private-key APrivateKey1... --network mainnet
```

Always add `.env` to `.gitignore`. Never commit private keys.

---

## Network Configuration in SDK

```typescript
import { AleoNetworkClient } from "@provablehq/sdk";

// Mainnet
const mainnetClient = new AleoNetworkClient(
    "https://api.explorer.provable.com/v1"
);

// Testnet
const testnetClient = new AleoNetworkClient(
    "https://api.explorer.provable.com/v1/testnet"
);

// Local devnet
const localClient = new AleoNetworkClient(
    "http://localhost:3030"
);
```

---

## Checking Network Status

Before deploying or executing:
1. Confirm the program exists (or doesn't, for fresh deploys):
   ```bash
   leo query program <program_id> --network <network>
   ```
2. Confirm your account has sufficient credits:
   ```bash
   leo query mapping credits.aleo account <your_address> --network <network>
   ```
3. Estimate fees:
   ```bash
   leo deploy --estimate-fee --network <network>
   ```

---

## Running Leo from a Server Backend

For server-side applications (Node.js, Python, etc.), spawn `leo execute` as
a child process rather than using the browser SDK:

```bash
leo execute <transition> <inputs> \
    --path /path/to/leo/project \
    --network testnet \
    --private-key $ALEO_PRIVATE_KEY \
    --broadcast \
    --yes
```

Key flags:
- `--path` — required if your working directory isn't the Leo project root
- `--broadcast` — submits the transaction to the network after proving
- `--yes` — non-interactive mode, skips confirmation prompts
- `--private-key` — pass via environment variable, never hardcode

The transaction ID is printed to stdout on success. Parse the CLI output to
extract it. Handle failures by checking the exit code and stderr.

This pattern works in any backend language that can spawn processes. It
sidesteps the SDK's browser-only limitation for proof generation.

### Node.js Example

```typescript
import { execFile } from "child_process";
import { promisify } from "util";

const execFileAsync = promisify(execFile);

async function executeTransition(
    transition: string,
    inputs: string[],
    projectPath: string,
    network: "testnet" | "mainnet" = "testnet"
): Promise<string> {
    const args = [
        "execute", transition, ...inputs,
        "--path", projectPath,
        "--network", network,
        "--private-key", process.env.ALEO_PRIVATE_KEY!,
        "--broadcast", "--yes"
    ];

    const { stdout, stderr } = await execFileAsync("leo", args, {
        timeout: 300_000  // 5 minute timeout for proof generation
    });

    if (stderr) console.warn("Leo stderr:", stderr);

    // Extract transaction ID from stdout
    const txMatch = stdout.match(/at1[a-z0-9]+/);
    if (!txMatch) throw new Error("No transaction ID in output");
    return txMatch[0];
}
```
