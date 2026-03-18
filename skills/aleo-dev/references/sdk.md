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

> **Note:** The SDK uses WebAssembly. In Node.js, program execution is limited;
> full proof generation runs in the browser. Account management and data
> handling work in both environments.

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
```

Never log or transmit private keys. Use environment variables or secure
storage — never hardcode them.

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
const value = await client.getMappingValue("token.aleo", "balances", "aleo1abc...");

// Get transaction
const tx = await client.getTransaction("at1...");

// Get unspent records (requires view key)
const records = await client.getUnspentRecords("my_program.aleo", "Token", account, undefined, undefined, []);
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
| Proof generation / program execution | Yes | No (use browser) |
| Program deployment | Yes | No |

For server-side applications that need to trigger transactions, the pattern
is: generate and sign in the browser, broadcast from anywhere.

> **Important:** The table above applies to the `@provablehq/sdk` JavaScript
> library only. Server-side applications can generate proofs and deploy programs
> by spawning the `leo` CLI as a child process (see `references/networks.md`
> for the pattern). This is how most production backends work — the SDK
> limitation does not mean Node.js backends can't submit transactions.

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

**Confusing SDK limitation with platform limitation:** The SDK can't generate
proofs in Node.js, but the `leo` CLI can. For server backends, spawn
`leo execute --broadcast --yes` as a child process.

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
