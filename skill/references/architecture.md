---
title: Sei Architecture
description: Core architecture of Sei Network — Twin Turbo Consensus, OCC parallel execution engine, SeiDB storage, and the Sei Giga roadmap.
---

# Sei Architecture

## Overview

Sei is a high-performance EVM-compatible blockchain that achieves ~400ms block times, instant finality, and ~100 MegaGas/s throughput through three tightly integrated components:

1. **Twin Turbo Consensus** — optimized Tendermint BFT with pipelined execution
2. **Parallelization Engine (OCC)** — Optimistic Concurrency Control for concurrent transaction processing
3. **SeiDB** — purpose-built storage layer with MVCC + LSM-tree hybrid architecture

These are not independent optimizations — they form an integrated pipeline that feeds consensus into parallel execution into high-throughput storage.

## Twin Turbo Consensus

### What it is

Twin Turbo is a suite of optimizations to the standard Tendermint BFT consensus algorithm targeting ~400ms block finality. It does NOT replace Tendermint — it accelerates it.

### Key mechanisms

**Pipelined pre-consensus preparation:**
- While block `H-1` is being finalized, validators begin collecting and analyzing transactions for block `H`
- Concurrent transaction decoding (`DecodeTransactionsConcurrently`)
- Dependency estimation (`GenerateEstimatedWritesets`) ahead of proposal
- State prefetching from SeiDB

**Overlapping consensus + execution:**
- When a validator receives a block proposal, BFT voting (prevote/precommit) runs *in parallel* with transaction execution
- Transactions execute optimistically using buffered state (`CacheMultiStore`)
- When 2/3+ precommits arrive, the execution work is already largely complete

**Aggressive timeout tuning:**
- `UnsafeProposeTimeoutOverride`, `UnsafeCommitTimeoutOverride` enforce much shorter round durations
- Faster gossip propagation for consensus messages

### Developer implications

```javascript
// Instant finality — one block confirmation is sufficient
const receipt = await txResponse.wait(1); // returns in ~400ms

// No need for "safe" or "finalized" tag — all blocks are final
// Deterministic finality: ~2 blocks (~800ms)
```

```solidity
// 1 block ≈ 400ms — useful for time-based contract logic
contract HighFrequencyOracle {
    uint256 public constant UPDATE_FREQUENCY = 5; // 5 blocks ≈ 2 seconds

    function updatePrice(uint256 price) external {
        require(block.number >= lastUpdateBlock + UPDATE_FREQUENCY, "Too frequent");
        // ...
        lastUpdateBlock = block.number;
    }

    function isPriceFresh() external view returns (bool) {
        return block.number - lastUpdateBlock < 25; // 25 blocks ≈ 10 seconds
    }
}
```

## Parallelization Engine (OCC)

### What it is

Optimistic Concurrency Control (OCC) allows multiple transactions to execute concurrently based on *estimated* state access patterns. Conflicts are detected after execution and resolved by re-executing conflicting transactions sequentially.

### Execution pipeline

1. **Preprocessing** — decode transactions, classify types, validate ante handlers
2. **Dependency estimation** — predict read/write sets for each transaction
   - Simple transfers: precise (known accounts, known slots)
   - Complex contracts: heuristic estimates (contract address, function selector, storage layout)
3. **Worker pool assignment** — schedule non-conflicting transactions to goroutines
4. **Buffered execution** — each worker writes to an isolated state buffer
5. **Conflict detection** — compare actual vs estimated read/write sets after execution:
   - Read-After-Write (RAW): Tx B reads what Tx A wrote
   - Write-After-Write (WAW): two Txs write the same slot
6. **Resolution** — conflicting transactions re-executed sequentially in deterministic order
7. **Fallback** — if conflicts are excessive, entire block falls back to sequential processing

### Throughput benchmarks (from sei-docs)

| Transaction Type | Sequential TPS | Parallel TPS | Improvement |
|---|---|---|---|
| Simple Transfers | 3,000 | 15,000+ | 5x |
| ERC-20 Transfers | 2,200 | 9,500+ | 4.3x |
| DEX Swaps | 800 | 2,800+ | 3.5x |
| Complex Contracts | 500 | 1,500+ | 3x |

### What this means for contract authors

Sei's OCC is automatic — unlike Solana, you do NOT declare write locks. But your contract design still affects throughput:

- **Good**: `mapping(address => mapping(uint256 => Position))` — each user's storage is independent
- **Bad**: `uint256 public totalVolume` updated by every swap — one global write blocks all concurrent swaps
- **Good**: event-based accounting where possible; aggregate off-chain or lazily
- See [evm/best-practices.md](evm/best-practices.md) for patterns

## SeiDB

### What it is

SeiDB is Sei's custom storage layer, designed to support high-throughput parallel execution. It replaces the standard IAVL tree used in most Cosmos chains for EVM state storage.

### Architecture

**Multi-level EVM cache system:**
- Hot slot cache — frequently accessed storage slots in memory
- Account state cache — account balances, nonces, code hashes
- Execution context cache — per-block working state during parallel execution

**Dual storage backend:**
- State Commit (SC) layer — IAVL-based for Merkle proof generation and consensus
- State Store (SS) layer — flat key-value store (RocksDB/PebbleDB) for fast EVM reads

**MVCC (Multi-Version Concurrency Control):**
- Multiple versions of state coexist during parallel execution
- Each transaction reads a snapshot of state; writes go to isolated buffers
- Committed only after conflict resolution

**LSM-tree management:**
- Log-structured merge-tree for write-efficient storage
- Asynchronous commit decouples block execution from disk write latency

### Key developer implication

SeiDB's asynchronous commit means that during high load, state reads can see very recently committed data. There is no meaningful "pending" window — but always account for the fact that non-EVM transactions (Cosmos bank sends, governance) can modify EVM-accessible state.

## Sei Giga (Roadmap)

### Current (v5.x)

The current network combines Twin Turbo + OCC + SeiDB to achieve:
- ~400ms block times
- ~100 MegaGas/s throughput
- Instant finality
- EVM Pectra compatibility (without blobs)

### Upcoming Sei Giga

Sei Giga introduces architectural changes targeting **5 gigagas/s** throughput:

| Component | Current | Sei Giga |
|---|---|---|
| Consensus | Tendermint BFT (Twin Turbo) | Autobahn (multi-lane, multi-proposer) |
| Block production | Single proposer | Multiple concurrent proposers |
| Execution | OCC parallel | Asynchronous decoupled execution |
| Storage tiers | Dual (SC + SS) | Hot/Warm/Cold tiered storage |

**Autobahn consensus** — multiple proposers submit transaction "lanes" simultaneously; a "cut" aggregates them into a block. Reduces latency by parallelizing block production itself.

**Asynchronous execution** — consensus and execution become fully decoupled; execution can span multiple "slots" and commit lazily.

> **Developer note**: The EVM API (addresses, opcodes, JSON-RPC) remains unchanged through the Giga upgrade. Application code written today will work on Giga without modification.
