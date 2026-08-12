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
- `eth_getProof` (EIP-1186) returns proofs against the global state root, not per-account roots
  - Storage keys must be **valid hex-encoded** values (e.g. `0x0000000000000000000000000000000000000000000000000000000000000001`). Malformed/non-hex keys are rejected with an error (`invalid storage key ...`) — they are no longer silently interpreted as raw bytes.
  - A single request is capped at **1024 storage keys** (`MaxStorageKeysPerProof`); exceeding this returns an error (`too many storage keys: got N, max 1024`).
- Block hash encoding differs from Ethereum — BLOCKHASH returns Tendermint header hash, not Ethereum keccak header hash

## What Works Unchanged


### Explicitly Unsupported JSON-RPC Methods

These methods are **registered** on Sei's EVM RPC but return JSON-RPC error code `-32000` with a clear message instead of `-32601` method-not-found. Clients get a stable, documented failure rather than a missing-method error.

| Method | `error.message` |
|---|---|
| `eth_blobBaseFee` | `blobs not supported on this chain` |
| `eth_syncing` | `eth_syncing is not supported on Sei EVM RPC` |
| `eth_newPendingTransactionFilter` | `eth_newPendingTransactionFilter is not supported on Sei EVM RPC` |
| `debug_getRawBlock` | `debug_getRawBlock is not supported on Sei EVM RPC` |
| `debug_getRawHeader` | `debug_getRawHeader is not supported on Sei EVM RPC` |
| `debug_getRawReceipts` | `debug_getRawReceipts is not supported on Sei EVM RPC` |
| `debug_getRawTransaction` | `debug_getRawTransaction is not supported on Sei EVM RPC` |

- `eth_syncing` — Sei's consensus model differs from Ethereum's sync semantics; do not rely on this method (Ethereum returns `false` or a sync object).
- `eth_newPendingTransactionFilter` — Sei has instant finality and does not expose Ethereum-style pending tx filters on this RPC.
- `debug_getRaw*` — raw RLP block/header/receipt/tx payloads are not served on this surface.



### Deprecated `sei_*` / `sei2_*` JSON-RPC Namespaces

The `sei_*` and `sei2_*` JSON-RPC surfaces (EVM HTTP endpoint only — not the Cosmos REST API on port 1317) are **deprecated and scheduled for removal**. Do not build new integrations on them; migrate to standard `eth_*` / `debug_*` methods and documented replacements.

**Gating by allowlist.** Which gated `sei_*` / `sei2_*` methods a node serves is controlled by `[evm] enabled_legacy_sei_apis` in `app.toml` (also settable via the AppOptions/CLI flag `evm.enabled_legacy_sei_apis`). Both prefixes share the same allowlist.

- **Default allowlist** (from `seid init` / `DefaultConfig`) enables only the three address/Cosmos helpers: `sei_getSeiAddress`, `sei_getEVMAddress`, `sei_getCosmosTx`. All other gated methods appear commented out in the generated template and must be explicitly enabled.
- Names are matched **case-insensitively** against the canonical method names.

**Behavior of gated calls (all responses are HTTP 200):**

- **Disabled** (method not in the allowlist, or an unrecognized `sei_*` / `sei2_*` name — the gate fails closed): returns a JSON-RPC `error` object with code `-32601`, a message explaining the method is not enabled and deprecated, and `error.data` set to the string `"legacy_sei_deprecated"`.
- **Allowed**: the call passes through to the handler **unchanged** (JSON body is not mutated); the response additionally sets the optional HTTP header `Sei-Legacy-RPC-Deprecation` signaling deprecation.

Example disabled-method response:

```json
{
  "jsonrpc": "2.0",
  "id": 42,
  "error": {
    "code": -32601,
    "message": "sei_sign is not enabled on this node. The sei_* and sei2_* JSON-RPC surfaces are deprecated...",
    "data": "legacy_sei_deprecated"
  }
}
```

Example `app.toml` to enable an additional gated method:

```toml
[evm]
enabled_legacy_sei_apis = [
  "sei_getSeiAddress",
  "sei_getEVMAddress",
  "sei_getCosmosTx",
  "sei_getBlockByNumber",
]
```

### `sei2_*` Block Namespace

The `sei2` namespace exposes the same **block** JSON-RPC shape as `sei` blocks, but with **bank transfers included** in the block payloads (HTTP only). There are seven `sei2_*` methods — block, block receipts, and transaction-count getters plus `*ExcludeTraceFail` variants — and **no** `sei2` transaction or filter API. They are gated by the same `enabled_legacy_sei_apis` allowlist (and are commented out by default).

- `sei2_getBlockByHash`
- `sei2_getBlockByHashExcludeTraceFail`
- `sei2_getBlockByNumber`
- `sei2_getBlockByNumberExcludeTraceFail`
- `sei2_getBlockReceipts`
- `sei2_getBlockTransactionCountByHash`
- `sei2_getBlockTransactionCountByNumber`


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
