# Provable SDK Reference

JavaScript/TypeScript SDK for building Aleo web applications.

- NPM: `@provablehq/sdk` (latest: **0.9.18**)
- WASM: `@provablehq/wasm` (^0.9.18)
- Docs: https://docs.leo-lang.org/sdk/typescript/overview
- Source: https://github.com/ProvableHQ/sdk (branch: `mainnet`)
- Latest release: check https://github.com/ProvableHQ/sdk/releases

---

## Quick Install

```bash
npm install @provablehq/sdk
# or
yarn add @provablehq/sdk
# or
pnpm add @provablehq/sdk
```

### Network-Specific Imports

The SDK provides network-specific entry points for tree-shaking and correct
network configuration:

```typescript
// Mainnet
import { Account, ProgramManager } from "@provablehq/sdk/mainnet.js";

// Testnet
import { Account, ProgramManager } from "@provablehq/sdk/testnet.js";

// Node.js (re-exports everything plus adds LocalFileKeyStore)
import { Account, ProgramManager, LocalFileKeyStore } from "@provablehq/sdk/node.js";

// Generic (you must configure the network manually)
import { Account, ProgramManager } from "@provablehq/sdk";
```

**Prefer network-specific imports** — they set the correct network parameters
automatically and produce smaller bundles.

`initializeWasm()` is exported directly from `@provablehq/sdk` (not only from
`@provablehq/wasm`).

### WASM Packages

The SDK depends on network-specific WASM packages:

```bash
# These are installed automatically as dependencies of @provablehq/sdk
# but can also be installed directly for advanced use:
npm install @provablehq/wasm-mainnet
npm install @provablehq/wasm-testnet
```

---

## Scaffolding a New Project

The fastest way to start:

```bash
npm create leo-app@latest
```

This scaffolds a React + TypeScript project with the SDK preconfigured.
Template options include vanilla React and React + wallet adapter examples.

---

## Account Management

```typescript
import { Account } from "@provablehq/sdk";

// Generate a new account
const account = new Account();
console.log(account.address().to_string());   // aleo1...
console.log(account.privateKey().to_string()); // APrivateKey1...
console.log(account.viewKey().to_string());    // AViewKey1...

// Restore from private key
const restored = new Account({ privateKey: "APrivateKey1..." });

// Sign a message
const signature = account.sign(new TextEncoder().encode("message"));
const valid = account.verify(new TextEncoder().encode("message"), signature);

// Encrypted account storage
const encrypted = account.encryptAccount("password");
const restoredFromCipher = Account.fromCiphertext(encrypted, "password");

// Validate address
Account.isValidAddress("aleo1...");

// Generate record view key
const rvk = account.generateRecordViewKey();
```

Never log or transmit private keys. Use environment variables or secure
storage — never hardcode them.

---

## Address Utilities

```typescript
import { Address } from "@provablehq/sdk";

// Validate an address
const isValid = Address.isValidAddress("aleo1abc...");

// Get the address of a deployed program
const programAddr = Address.fromProgramId("my_program.aleo");
```

---

## Program Manager

`ProgramManager` is the main class for executing and deploying programs.

```typescript
import { ProgramManager, AleoNetworkClient, NetworkRecordProvider } from "@provablehq/sdk";

const networkClient = new AleoNetworkClient("https://api.explorer.provable.com/v1");
const keyProvider = new AleoKeyProvider();
await keyProvider.fetchKeys("my_program.aleo", "main");

const recordProvider = new NetworkRecordProvider(account, networkClient);

const programManager = new ProgramManager(
    "https://api.explorer.provable.com/v1",
    keyProvider,
    recordProvider
);
// Constructor: ProgramManager(host?, keyProvider?, recordProvider?, networkClientOptions?)
programManager.setAccount(account);
```

### Execute a transition

```typescript
// execute(programName, functionName, priorityFee, privateFee, inputs, ...)
const txId = await programManager.execute(
    "my_program.aleo",       // programName
    "mint_private",          // functionName
    0.02,                    // priorityFee in credits — always estimate first
    false,                   // privateFee: true = use a private record for fee
    ["aleo1abc...", "100u64"] // inputs
);
console.log("Transaction ID:", txId);
```

### Run locally (no fees, no broadcast)

```typescript
// run(programName, functionName, inputs, ...)
const result = await programManager.run(
    "my_program.aleo",
    "mint_private",
    ["aleo1abc...", "100u64"]
);
```

### Deploy a program

```typescript
// deploy(program, priorityFee, privateFee, ...)
const txId = await programManager.deploy("program source string", 0.5, false);
```

### Upgrade a program (v0.9.13+)

```typescript
const txId = await programManager.buildUpgradeTransaction(
    "updated program source string",
    0.5,   // fee
    false  // privateFee
);
```

### Estimate fees

```typescript
const fee = await programManager.estimateExecutionFee(
    account,
    program,
    "transition_name",
    inputs,
    url
);
```

Always estimate before executing — hardcoding fees leads to failed transactions.

---

## Querying the Network

```typescript
const client = new AleoNetworkClient("https://api.explorer.provable.com/v1");

// Get latest block
const block = await client.getLatestBlock();

// Get a program's source
const source = await client.getProgram("credits.aleo");

// Get a mapping value
const value = await client.getProgramMappingValue("token.aleo", "balances", "aleo1abc...");

// Get transaction
const tx = await client.getTransaction("at1...");

// Find unspent records (requires view key)
const records = await client.findUnspentRecords("my_program.aleo", "Token", account, undefined, undefined, []);

// Wait for transaction confirmation
const confirmedTx = await client.waitForTransactionConfirmation(txId);
```

---

## Record Decryption

```typescript
import { RecordCiphertext, ViewKey } from "@provablehq/sdk";

const viewKey = ViewKey.from_string("AViewKey1...");
const ciphertext = RecordCiphertext.fromString("record1...");

if (ciphertext.isOwner(viewKey)) {
    const plaintext = ciphertext.decrypt(viewKey);
    console.log(plaintext.toString());
}
```

---

## RecordScanner (v0.9.16+)

```typescript
import { RecordScanner } from "@provablehq/sdk";

const scanner = new RecordScanner(account, "https://api.explorer.provable.com/v1");

// Register for record scanning
await scanner.register();

// Find records for a program
const records = await scanner.findRecords("my_program.aleo", "Token");

// Find credits records
const creditsRecord = await scanner.findCreditsRecord(0.1);  // minimum 0.1 credits
const creditsRecords = await scanner.findCreditsRecords(1.0); // multiple records totaling 1.0
```

---

## Transfers (credits.aleo)

```typescript
// Public transfer
await programManager.transfer(
    1.0,          // amount in credits
    "aleo1dest...",
    "transfer_public",
    0.01          // fee
);

// Private transfer (consumes a record, produces a new record)
await programManager.transfer(
    1.0,
    "aleo1dest...",
    "transfer_private",
    0.01,
    undefined,   // amount record (auto-selected if undefined)
    undefined    // fee record
);
```

Transfer types: `transfer_public`, `transfer_private`,
`transfer_public_to_private`, `transfer_private_to_public`.

---

## Key Provider

Proving keys for programs can be fetched from the network or cached locally.

```typescript
import { AleoKeyProvider, AleoKeyProviderParams } from "@provablehq/sdk";

const keyProvider = new AleoKeyProvider();
keyProvider.useCache(true);  // cache keys in memory after first fetch

// Fetch keys for a specific program + function
await keyProvider.fetchKeys("credits.aleo", "transfer_public");
```

For custom programs deployed on-chain, keys are fetched automatically by
`ProgramManager` when needed.

### KeyStore / LocalFileKeyStore (v0.9.17+)

```typescript
import { AleoKeyProvider } from "@provablehq/sdk";
// Or for Node.js with persistent file-based caching:
import { LocalFileKeyStore } from "@provablehq/sdk/node.js";

const keyStore = new LocalFileKeyStore();  // stores keys in .aleo directory
const keyProvider = new AleoKeyProvider();
keyProvider.useCache(true);

// KeyStore interface: getProvingKey(), getVerifyingKey(), setKeys(), has(), delete(), clear()
```

### OfflineKeyProvider

For air-gapped or offline scenarios where network access is unavailable, use
`OfflineKeyProvider`. It loads keys from local storage without any network
calls, suitable for signing and proving on isolated machines.

---

## Hash Function Primitives

The SDK exposes hash functions that mirror Leo's in-circuit hash operations:

```typescript
import { BHP256, Poseidon2 } from "@provablehq/sdk";
// Available: BHP256, BHP512, BHP768, BHP1024, Poseidon2, Poseidon4, Poseidon8
```

---

## Wasm Module (browser-side)

For raw cryptographic operations in the browser:

```typescript
import { Aleo } from "@provablehq/wasm";

await Aleo.initializeWasm();  // must be called once before using wasm primitives

const privateKey = Aleo.PrivateKey.new_random();
const address = privateKey.to_address();
```

The Wasm module is the underlying engine. `@provablehq/sdk` wraps it with
higher-level abstractions — prefer the SDK unless you need raw crypto ops.

---

## Node.js vs Browser

| Feature | Browser | Node.js |
|---------|---------|---------|
| Account management | Yes | Yes |
| Record decryption | Yes | Yes |
| Network queries | Yes | Yes |
| Proof generation / program execution | Yes | Yes |
| Program deployment | Yes | Yes |

The SDK's `node.ts` entry point (`@provablehq/sdk/node.js`) re-exports
everything from the main SDK and adds `LocalFileKeyStore` for persistent
file-based key caching. Proof generation is fully supported in Node.js.

---

## Web Worker Pattern

Proof generation is CPU-intensive and blocks the main thread. Always offload
to a web worker in production:

```typescript
// worker.ts
import { ProgramManager } from "@provablehq/sdk";

self.onmessage = async (event) => {
    const { programName, functionName, inputs, fee } = event.data;
    const pm = new ProgramManager(/* ... */);
    try {
        const result = await pm.execute({ programName, functionName, inputs, fee });
        self.postMessage({ success: true, txId: result });
    } catch (err) {
        self.postMessage({ success: false, error: err.message });
    }
};

// main.ts
const worker = new Worker(new URL("./worker.ts", import.meta.url));
worker.postMessage({ programName: "my_program.aleo", functionName: "mint", inputs: [...], fee: 0.02 });
worker.onmessage = (event) => {
    if (event.data.success) console.log("TX:", event.data.txId);
};
```

This prevents the UI from freezing during proof generation (which can take
10-60 seconds depending on circuit complexity).

---

## Common Mistakes

**Wrong network URL:** Confirm the endpoint against `references/networks.md`.
Testnet and mainnet have different base URLs.

**Fee too low:** Use `estimateExecutionFee` before every transaction.

**Record already consumed:** Each record can only be spent once. After a
transition, the input records are nullified. Keep track of unspent records.

**Wasm not initialized:** Call `Aleo.initializeWasm()` before any wasm
operations in browser code.

**Missing await:** Almost every SDK call is async. Missing `await` leads to
silent failures.

**BigInt handling for field elements:** Aleo's field modulus is
`8444461749428370424248824938781546531375899335154063827935233455917409239040`.
When converting hashes or large numbers to field elements in JavaScript, use
`BigInt` — standard `Number` loses precision above 2^53. Always validate that
your value is less than the field modulus before submitting.

**Splitting large values into u128 pairs:** Leo's largest integer is `u128`.
To pass a 256-bit hash to a program, split it into `hash_high: u128` and
`hash_low: u128`, then reconstruct in-circuit:
```leo
inline reconstruct(high: u128, low: u128) -> field {
    return (high as field) * 340282366920938463463374607431768211456field + (low as field);
}
```
The magic number is 2^128 as a field literal.

**Main thread proof generation:** Always use a web worker for proof generation
in browser apps. See the Web Worker Pattern section above.

---

## Delegated Proving Service

For mobile, low-power, or serverless environments where local proof generation
is impractical, the SDK supports delegating proof generation to a remote service.

```typescript
import { ProgramManager, AleoNetworkClient } from "@provablehq/sdk/mainnet.js";

const pm = new ProgramManager("https://api.explorer.provable.com/v1");
pm.setAccount(account);

// Build a proving request
const provingRequest = await pm.provingRequest(
    "my_program.aleo",
    "mint_private",
    ["aleo1abc...", "100u64"],
    0.02
);

// Submit via network client
const networkClient = new AleoNetworkClient("https://api.explorer.provable.com/v1");
const txId = await networkClient.submitProvingRequest(provingRequest);
```

### When to Use Delegated Proving

| Scenario | Use Delegated Proving? |
|----------|----------------------|
| Mobile browser | Yes — limited CPU/memory |
| Desktop browser | No — local proving is fine |
| Server backend | No — use `leo execute` CLI |
| Serverless/edge function | Yes — execution time limits |
| Low-power IoT device | Yes — insufficient resources |

**Privacy note:** Delegated proving uses encrypted inputs. The proving service
generates the proof without access to your private data. However, you are
trusting the service's availability — it's not a privacy risk but an
availability dependency.

---

## Bundler Configuration

The SDK uses WebAssembly and SharedArrayBuffer, which require specific bundler
configuration.

### Vite

```typescript
// vite.config.ts
import { defineConfig } from "vite";

export default defineConfig({
    server: {
        headers: {
            "Cross-Origin-Opener-Policy": "same-origin",
            "Cross-Origin-Embedder-Policy": "require-corp",
        },
    },
    optimizeDeps: {
        exclude: ["@provablehq/sdk", "@provablehq/wasm-mainnet"],
    },
});
```

### Webpack

```javascript
// webpack.config.js
module.exports = {
    resolve: {
        fallback: {
            crypto: require.resolve("crypto-browserify"),
            stream: require.resolve("stream-browserify"),
            buffer: require.resolve("buffer/"),
        },
    },
    experiments: {
        asyncWebAssembly: true,
    },
    devServer: {
        headers: {
            "Cross-Origin-Opener-Policy": "same-origin",
            "Cross-Origin-Embedder-Policy": "require-corp",
        },
    },
};
```

### Required HTTP Headers

For SharedArrayBuffer support (required for WASM multi-threading), your
server must return these headers:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

Without these headers, you'll get `SharedArrayBuffer is not defined` errors.
See `references/common-errors.md` for more WASM troubleshooting.
