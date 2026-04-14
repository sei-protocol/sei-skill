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
| SSTORE gas cost | Testnet: 72,000 / Mainnet: 20,000 (governance-adjustable) | 20,000 (fixed) |
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
| Blob opcodes | Not supported | Supported (post-Cancun) | No EIP-4844 blob transactions on Sei |

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
// - Testnet (atlantic-2): 72,000 gas per cold write (governance proposal #240)
// - Mainnet (pacific-1): 20,000 gas (standard EVM; governance-adjustable)
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
- Block hash encoding differs from Ethereum — BLOCKHASH returns Tendermint header hash, not Ethereum keccak header hash

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
- ✅ Audit SSTORE usage — testnet charges 72k gas per write; mainnet is 20k (governance-adjustable); restructure if needed
- ✅ Do not assume COINBASE is the validator/proposer
- ✅ Remove blob-related code (EIP-4844 not supported)
- ✅ Size gasLimit with buffer (OCC can slightly vary estimates vs single-threaded chains)
