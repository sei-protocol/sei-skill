---
title: EVM on Sei — Key Differences from Ethereum
description: How Sei's EVM differs from Ethereum — opcodes, gas model, finality, state storage, and what these mean for Solidity development.
---

# EVM on Sei — Key Differences from Ethereum

## Comparison Table

| Feature | Sei EVM | Ethereum |
|---|---|---|
| Block time | ~400ms | ~12s |
| Gas per second | ~100 MegaGas/s | ~5 MegaGas/s |
| Finality | Instant (1 block) | Multiple levels (safe, justified, finalized) |
| EVM version | Pectra (without blobs) | Fusaka |
| Parallelized execution | Yes (OCC) | No |
| Gas limit (block) | 12.5M | 60M |
| Per-Tx gas cap | 12.5M (block limit) | ~16.7M (EIP-7825) |
| Byte size limit | 21MB | None |
| State storage | AVL-tree (global root) | Merkle Patricia Trie (per-account root) |
| SSTORE gas cost | 72,000 gas on both mainnet & testnet (governance-adjustable) | 20,000 (fixed) |
| Address system | Dual (sei1... bech32 + 0x... EVM) | Single (0x...) |
| Fee burn | No — all fees to validators | Yes (EIP-1559 base fee burn) |
| Pending state | None | Yes (proposer-execute-then-broadcast) |
| CosmWasm | Deprecated (SIP-3) | N/A |

## Opcode Differences

| Opcode | Sei Behavior | Ethereum Behavior | Notes |
|---|---|---|---|
| `PREVRANDAO` | Value derived from block time | RANDAO mix (EIP-4399) | **NOT random** — use oracle VRF |
| `DIFFICULTY` | Alias of PREVRANDAO | Alias of PREVRANDAO | Same as above |
| `COINBASE` | Always the global fee collector address | Block proposer (miner) address | Do not assume it's the validator |
| `BASEFEE` | Returns base fee; no burn | Returns base fee; portion burned | Legacy txs must specify ≥ 50 gwei |
| `BLOCKHASH` | Hash of Tendermint header | Keccak of Ethereum block header | Different encoding; usable for recent blocks |
| `GASLIMIT` | 12,500,000 | 60,000,000 | Block gas limit |
| `TIMESTAMP` | Tendermint block time | Proposer-chosen block time | Do not use as randomness source |
| Blob opcodes | Not supported | Supported (post-Cancun) | No EIP-4844 blob transactions on Sei. `eth_blobBaseFee` is exposed but returns JSON-RPC error code -32000, `"blobs not supported on this chain"` (not -32601 method-not-found) |

## Key Developer Rules

### Finality
```javascript
// Instant finality — 1 confirmation is sufficient
const receipt = await txResponse.wait(1);

// All commitment levels are the same on Sei:
// "latest" == "safe" == "finalized"
// Never do: provider.getBlock("finalized") — unnecessary on Sei
```

### Gas and Fees
```javascript
// Use gasPrice (legacy tx), NOT EIP-1559 fields
const tx = {
  to: recipient,
  value: parseEther("1.0"),
  gasPrice: parseUnits("50", "gwei"),   // minimum 50 gwei
  gasLimit: 200_000n,                   // add buffer — OCC can slightly vary estimates
};

// Do NOT use maxFeePerGas / maxPriorityFeePerGas
// Do NOT expect base fee burn in fee models
```

### SSTORE and Storage Writes
```solidity
// SSTORE costs differ by network:
// - Both mainnet & testnet: 72,000 gas per cold write (pacific-1 Proposal #109; testnet same value, no separate proposal)

// Always verify with `forge test --gas-report` against your target network.

// BAD: 10 writes = potentially expensive in either case
for (uint i = 0; i < 10; i++) {
    scores[users[i]] = newScores[i]; // minimize writes regardless
}

// BETTER: batch reads into memory, compute, write once
uint[] memory newScores = computeNewScores(users);
for (uint i = 0; i < newScores.length; i++) {
    scores[users[i]] = newScores[i]; // still writes each, but minimize unnecessary ones
}
```

### No Randomness from PREVRANDAO
```solidity
// NEVER use for randomness:
uint256 rand = uint256(block.prevrandao); // derived from block time, predictable

// ALWAYS use an oracle VRF:
// - Pyth Network VRF
// - Chainlink VRF
// See oracles.md for integration examples
```

### Non-EVM Transaction Effects on EVM State
```javascript
// SEI balance can change from both EVM and Cosmos-side transactions.
// If your indexer only watches EVM events, it may miss Cosmos bank sends.
// Always fetch current balance from RPC rather than tracking diffs from events only.
const balance = await provider.getBalance(address); // always accurate
```

### State Storage (AVL vs MPT)
- Sei uses a single global AVL-tree state root — there are no per-account state roots
- `eth_getProof` (EIP-1186) is **not supported** since v6.7.0 ([sei-chain#3926](https://github.com/sei-protocol/sei-chain/pull/3926)): it returns JSON-RPC error `-32000` `eth_getProof is not supported yet; please reach out to the Sei Labs if you need this endpoint`. Don't build light-client or storage-proof flows on it.
- Block hash encoding differs from Ethereum — BLOCKHASH returns Tendermint header hash, not Ethereum keccak header hash

## JSON-RPC Method Availability

### Explicitly Unsupported JSON-RPC Methods

These methods are **registered** on Sei's EVM RPC but return JSON-RPC error code `-32000` with a clear message instead of `-32601` method-not-found. Clients get a stable, documented failure rather than a missing-method error.

| Method | `error.message` |
|---|---|
| `eth_blobBaseFee` | `blobs not supported on this chain` |
| `eth_getProof` | `eth_getProof is not supported yet; please reach out to the Sei Labs if you need this endpoint` (since v6.7.0) |
| `eth_syncing` | `eth_syncing is not supported on Sei EVM RPC` |
| `eth_newPendingTransactionFilter` | `eth_newPendingTransactionFilter is not supported on Sei EVM RPC` |
| `debug_getRawBlock` | `debug_getRawBlock is not supported on Sei EVM RPC` |
| `debug_getRawHeader` | `debug_getRawHeader is not supported on Sei EVM RPC` |
| `debug_getRawReceipts` | `debug_getRawReceipts is not supported on Sei EVM RPC` |
| `debug_getRawTransaction` | `debug_getRawTransaction is not supported on Sei EVM RPC` |

- `eth_syncing` — Sei's consensus model differs from Ethereum's sync semantics; do not rely on this method (Ethereum returns `false` or a sync object).
- `eth_newPendingTransactionFilter` — Sei has instant finality and does not expose Ethereum-style pending tx filters on this RPC.
- `debug_getRaw*` — raw RLP block/header/receipt/tx payloads are not served on this surface.

### `debug_trace*` Tracer Allowlist Gating

Since v6.7.0 ([sei-chain#3718](https://github.com/sei-protocol/sei-chain/pull/3718)), unlike upstream geth (which accepts any registered tracer, including request-supplied JavaScript, by default), Sei **gates** caller-supplied `TraceConfig.Tracer` values on `debug_traceCall`, `debug_traceTransaction`, `debug_traceBlockByNumber`, `debug_traceBlockByHash`, and `debug_traceTransactionProfile`. Validation runs before any tracer is constructed; when `Tracer` is omitted the default struct logger is always available.

Two `[evm]` fields in `app.toml` control this:

- `trace_allowed_tracers` — the native geth tracer names callers may request. Default:
  ```toml
  [evm]
  trace_allowed_tracers = ["callTracer", "prestateTracer", "flatCallTracer", "4byteTracer", "noopTracer", "muxTracer"]
  ```
  Only native tracer names are accepted here (validated native-only at startup); set to `[]` to disable all named tracers. A non-native/typo'd name fails node startup.
- `trace_allow_js_tracers` — default `false`. Must be explicitly set to `true` to permit request-supplied JavaScript tracer source in `TraceConfig.Tracer`. This executes untrusted code in-process; keep disabled on public RPC nodes. Enabling it does **not** widen `trace_allowed_tracers` — native tracer names must still be listed there to be usable.

**Behavior:**
- A tracer name not in `trace_allowed_tracers` is rejected (`... is not allowed; JavaScript tracers are disabled and only native tracers listed in evm.trace_allowed_tracers may be used`).
- With `trace_allow_js_tracers = false`, any JS tracer source is rejected.
- A padded native name (e.g. `" callTracer"`) is trimmed before validation/resolution; nested names inside `muxTracer` config must not have leading/trailing whitespace and are rejected if padded.
- `muxTracer` nested tracer names (in `TracerConfig`) are validated recursively against the same allowlist, with a bounded nesting depth of **16** (exceeding it errors with `muxTracer nesting depth exceeds maximum of 16`).

The `trace_bake_tracers` config (block-baking tracers) is held to the same native-only rule and validated at startup.

Example allowlist-rejection response:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32000,
    "message": "debug tracer \"myCustomJS\" is not allowed; JavaScript tracers are disabled and only native tracers listed in evm.trace_allowed_tracers may be used"
  }
}
```



### Legacy `sei_*` JSON-RPC Methods (three remain; `sei2_*` removed)

As of sei-chain v6.7.0 the legacy Sei JSON-RPC surface (EVM HTTP endpoint only — not WebSocket, and not the Cosmos REST API on port 1317) is down to three deprecated helper methods:

- `sei_getSeiAddress` — EVM address → `sei1...` address
- `sei_getEVMAddress` — `sei1...` address → EVM address
- `sei_getCosmosTx` — EVM tx hash → Cosmos tx hash

Everything else is **gone**, not just disabled:

- The whole `sei2_*` namespace (block getters that included bank transfers) was removed ([sei-chain#3912](https://github.com/sei-protocol/sei-chain/pull/3912)). Calls return the standard `-32601` `the method sei2_... does not exist/is not available`.
- All other `sei_*` methods — block, receipt, and transaction-count getters and their `*ExcludeTraceFail` variants, filters and logs, `sei_getTransactionReceipt`, `sei_sign`, and `sei_associate` — were removed ([sei-chain#3924](https://github.com/sei-protocol/sei-chain/pull/3924), [#3927](https://github.com/sei-protocol/sei-chain/pull/3927), [#3945](https://github.com/sei-protocol/sei-chain/pull/3945)). The `sei_traceBlockBy*ExcludeTraceFail` endpoints were already removed in v6.6.0.

Use the standard `eth_*` / `debug_*` methods instead (e.g. `eth_getBlockByNumber`, `eth_getBlockReceipts`, `eth_getTransactionReceipt`, `eth_getLogs`, `debug_traceBlockByNumber`). To associate addresses, use the Addr precompile or send any transaction (see [addresses-wallets.md](../addresses-wallets.md)).

**Gating by allowlist.** The three remaining methods are served only if listed in `[evm] enabled_legacy_sei_apis` in `app.toml` (also settable via the AppOptions key `evm.enabled_legacy_sei_apis`). `seid init` / `DefaultConfig` lists all three, and names are matched case-insensitively. Other names in the list are ignored — they cannot bring a removed method back.

**Behavior over HTTP (all responses are HTTP 200):**

- **Any other `sei_*` name** — a removed method, a typo, or one of the three left out of the allowlist — is rejected by the gate (it fails closed) with JSON-RPC code `-32601`, `error.data` `"legacy_sei_deprecated"`, and a message saying the method is not enabled on this node. The message suggests adding the method to `enabled_legacy_sei_apis`, but that only works for the three remaining methods.
- **Allowed** calls pass through to the handler **unchanged** (JSON body is not mutated); the response may also set the HTTP header `Sei-Legacy-RPC-Deprecation`.

Example response for a removed method:

```json
{
  "jsonrpc": "2.0",
  "id": 42,
  "error": {
    "code": -32601,
    "message": "sei_sign is not enabled on this node. The sei_* JSON-RPC surface is deprecated, scheduled for removal, and should not be used for new integrations - ...",
    "data": "legacy_sei_deprecated"
  }
}
```

Default `app.toml`:

```toml
[evm]
enabled_legacy_sei_apis = [
  "sei_getSeiAddress",
  "sei_getEVMAddress",
  "sei_getCosmosTx",
]
```

## What Works Unchanged

- All Solidity syntax and version up to 0.8.x
- OpenZeppelin contracts (ERC20, ERC721, ERC1155, UUPS, Transparent Proxy, AccessControl, etc.)
- ABI encoding/decoding
- Standard JSON-RPC methods (`eth_call`, `eth_getLogs`, `eth_getTransactionReceipt`, etc.)
- Hardhat, Foundry, Truffle, Remix — all standard EVM tooling
- Contract addresses are deterministic (same `CREATE` and `CREATE2` behavior)
- `SELFDESTRUCT` — present but behavior may vary; prefer a soft-close pattern

## Migration Checklist (from another EVM chain)

- ✅ Redeploy to testnet first; most contracts need no changes
- ✅ Remove EIP-1559 fee UI; use single `gasPrice` input
- ✅ Remove "safe"/"finalized" confirmation logic; treat all confirmed blocks as final
- ✅ Replace PREVRANDAO/DIFFICULTY randomness with oracle VRF
- ✅ Audit SSTORE usage — both networks charge 72k gas per write (governance-adjustable); restructure if needed
- ✅ Do not assume COINBASE is the validator/proposer
- ✅ Remove blob-related code (EIP-4844 not supported)
- ✅ Size gasLimit with buffer (OCC can slightly vary estimates vs single-threaded chains)
