---
title: OCC-Aware Contract Design
description: How Sei's Optimistic Concurrency Control (OCC) parallel scheduler interacts with Solidity storage. Patterns to avoid hot keys, isolate per-user state, and structure DEXes/AMMs/lending without serializing.
---

# OCC-Aware Contract Design

Sei runs non-conflicting transactions in parallel using Optimistic Concurrency Control (OCC). Contracts that share storage keys across many users serialize back to single-threaded execution, throwing away Sei's primary throughput advantage. This page is the design playbook for writing contracts that *stay parallel*.

## Mental model

OCC works in two phases per block:

1. **Optimistic execution** — workers run transactions in parallel, each tracking its own read/write set.
2. **Conflict check + commit** — if two transactions wrote the same storage key, one of them is **re-executed sequentially**.

A contract is "OCC-friendly" when its read/write sets across concurrent transactions don't overlap. Overlap = re-execution = wasted gas and lost parallelism.

## Three rules

1. **Partition writes by user/asset/id.** Disjoint keys = parallel-safe.
2. **Don't write to global counters/aggregators.** Aggregate off-chain via events.
3. **Isolate hot updates from cold metadata.** Don't pack a per-user balance with a global stat in the same slot.

## The hot-key trap

This pattern looks innocent and serializes everything:

```solidity
// BAD — every swap conflicts on totalVolume
contract DEX {
    uint256 public totalVolume;
    mapping(address => uint256) public balances;

    function swap(uint256 amount) external {
        balances[msg.sender] -= amount;     // isolated per user — fine
        totalVolume += amount;              // GLOBAL — every swap touches this slot
    }
}
```

Two users swapping at the same time both read+write `totalVolume`, the OCC scheduler detects the conflict, and one of them is re-executed sequentially. Repeat across thousands of users and effective TPS = 1.

The fix:

```solidity
// GOOD — global aggregation moved off-chain
contract DEX {
    mapping(address => uint256) public balances;
    event Swap(address indexed user, uint256 amount);

    function swap(uint256 amount) external {
        balances[msg.sender] -= amount;
        emit Swap(msg.sender, amount);
        // indexer sums Swap events to compute totalVolume
    }
}
```

If you absolutely need on-chain global state, **shard it**:

```solidity
// ACCEPTABLE — bucketed counter; conflicts only within a bucket
mapping(uint256 => uint256) private volumeBuckets;

function swap(uint256 amount) external {
    uint256 bucket = uint256(uint160(msg.sender)) & 0xFF; // 256 buckets
    volumeBuckets[bucket] += amount;
}

function totalVolume() external view returns (uint256 sum) {
    for (uint256 i = 0; i < 256; i++) sum += volumeBuckets[i];
}
```

Now 256 users hit 256 distinct slots. Conflicts only occur when two senders hash to the same bucket, which is rare under uniform load.

## Per-user state pattern (preferred default)

```solidity
mapping(address => mapping(uint256 => Position)) private positions;
//      ^ user      ^ position id    ^ struct

function open(uint256 id, int256 qty) external {
    positions[msg.sender][id].qty = qty;
}
```

User A writing to `positions[A][1]` and user B writing to `positions[B][1]` are completely disjoint slots. Maximum parallelism.

## AMM pools and shared liquidity

A constant-product AMM has an unavoidable shared resource: the pool reserves. Two users swapping in the same pool *will* conflict on the reserve slots. You cannot fully parallelize a single pool.

Options:

1. **Accept the conflict for small pools.** A few txs/sec serializing is fine.
2. **Concentrated liquidity / tick-based.** Uniswap-V3-style designs partition liquidity by tick range. Swaps that don't cross the same tick can parallelize.
3. **Multi-pool design.** Split a single market into many small pools (different fee tiers, different LP cohorts) — load distributes across pools.
4. **Order book on isolated price levels.** A central limit order book where each price level is its own slot can parallelize when buyers and sellers don't cross at the same price.

## Lending markets

Single-pool lending (one big shared utilization variable) serializes badly. Per-user accounting is fine; the shared reserves and interest index are the bottleneck.

Patterns that work:

- **Per-asset isolated markets** (Compound v3 / Aave v3 isolation mode) — load splits across markets.
- **Lazy interest accrual** — instead of writing to a global `cumulativeInterest` on every action, store last-accrued timestamp per user and compute lazily on next interaction.
- **Streaming events** — emit `Borrow`, `Repay`, `Liquidate` events; let indexers compute global utilization.

## Reentrancy guards and global locks

The classic OpenZeppelin `ReentrancyGuard` uses a single storage slot:

```solidity
// BAD on Sei — every guarded call writes to the same slot
modifier nonReentrant() {
    require(_status != _ENTERED, "REENTRANT");
    _status = _ENTERED;          // every call writes this
    _;
    _status = _NOT_ENTERED;      // every call writes this again
}
```

Two users calling guarded functions concurrently always conflict. On Ethereum it's invisible (single-threaded anyway); on Sei it serializes.

Per-user reentrancy state:

```solidity
mapping(address => bool) private _entered;

modifier nonReentrant() {
    require(!_entered[msg.sender], "REENTRANT");
    _entered[msg.sender] = true;
    _;
    _entered[msg.sender] = false;
}
```

Caveat: this protects against a user reentering *themselves*, which is the typical attack. Cross-user reentrancy is a different risk; if your function holds invariants across users, you may still need a global guard — and accept the conflict cost.

## Storage layout: separate hot from cold

```solidity
// BAD — packs hot per-user balance with cold global stats
struct UserAndStats {
    uint128 balance;       // hot: written every action
    uint128 lifetimeFees;  // cold: rarely read, never read by other users
}
mapping(address => UserAndStats) public data;
```

Even though slot is per-user, packing combines two semantically-different fields. Use separate mappings:

```solidity
// GOOD — independent slots, each can be optimized for its access pattern
mapping(address => uint256) public balance;       // hot
mapping(address => uint256) public lifetimeFees;  // cold
```

## Pull payments over push

```solidity
// BAD — writes to N user slots in one tx; serializes any other user touching the same slots
function distributeRewards(address[] calldata users, uint256[] calldata amounts) external {
    for (uint256 i = 0; i < users.length; i++) {
        accrued[users[i]] += amounts[i];
    }
}

// GOOD — each user pulls their own; one slot per tx, fully parallel across users
mapping(address => uint256) public accrued;

function withdraw() external {
    uint256 due = accrued[msg.sender];
    accrued[msg.sender] = 0;
    payable(msg.sender).sendValue(due);
}
```

## Detecting conflicts in tests

There's no first-class "conflict count" exposed by Foundry, but you can simulate the scheduler:

1. Deploy to testnet.
2. Send N concurrent txs from N distinct EOAs ([performance-testing.md](performance-testing.md)).
3. Inspect block-level execution metadata via `debug_traceBlockByNumber` (if your RPC provider supports it).
4. Compare `gas_used / theoretical_serial_gas` — values near 1.0 indicate full serialization (high conflict).

Or use a Dune query to compute observed parallelism from your contract's transactions over a load period — see [indexers.md](../ecosystem/indexers.md).

## Quick checklist

Before deploying to mainnet, audit for:

- [ ] No `public` or `internal` global counters that every action mutates.
- [ ] User state lives in `mapping(address => ...)` or deeper nesting.
- [ ] Reentrancy guards are per-user where possible.
- [ ] Aggregations (TVL, total volume, total supply) computed off-chain or sharded.
- [ ] AMM/lending shared resources isolated to small markets/pools.
- [ ] Hot fields (balances) not packed with cold fields (stats) in the same slot.

## Sei-specific notes

- The 12.5M gas-per-block limit means parallelism gains compound: if you fit 5× more useful transactions into the budget, you serve 5× more users per second.
- OCC re-execution **does** consume gas — conflicts aren't free even when they resolve correctly.
- Cross-VM calls (EVM → CosmWasm via precompile bridge) introduce serialization points; design accordingly.
- The same patterns that help on Sei *also* help on Ethereum (lower gas, cleaner code) — they're never a downside.
