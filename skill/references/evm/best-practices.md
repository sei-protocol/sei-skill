---
title: EVM Best Practices for Sei
description: Parallelization-friendly contract design, SSTORE optimization, zeroing stale state, and gas efficiency patterns specific to Sei EVM.
---

# EVM Best Practices for Sei

## Core Principles

Sei executes non-conflicting transactions in parallel. Your contract design directly affects how many transactions can run simultaneously — and therefore the gas efficiency of the entire block.

1. **Minimize shared writes** — the scheduler can parallelize transactions that don't write to the same storage key
2. **Partition state by user/asset/id** — independent users should write to independent keys
3. **Prefer pull over push** — let users claim funds; don't mass-push in loops
4. **Batch in memory, write once** — compute intermediate values in memory, commit minimal final writes
5. **SSTORE costs 72,000 gas** — every unnecessary write is expensive; measure with `forge test --gas-report`

## Storage Design Patterns

### Partition state by key (enables parallelism)

```solidity
// GOOD: disjoint keys per user + id — concurrent users don't conflict
mapping(address => mapping(uint256 => Position)) public positions;

function updatePosition(uint256 id, int256 delta) external {
    Position storage p = positions[msg.sender][id];
    int256 newQty = p.qty + delta;  // compute in memory
    p.qty = newQty;                 // one write, isolated per user
}
```

```solidity
// BAD: single global counter — every transaction conflicts
uint256 public totalVolume;   // ← every swap writes here → all swaps serialize

function swap(uint256 amount) external {
    totalVolume += amount;   // 72k gas + serializes all swap transactions
    // ...
}

// BETTER: omit hot globals; compute aggregates off-chain from events
event Swap(address indexed user, uint256 amount);

function swap(uint256 amount) external {
    // no global write
    emit Swap(msg.sender, amount);  // indexers sum off-chain
}
```

### Pull payments (avoids multi-user write loops)

```solidity
// BAD: loop writes to many keys — one tx blocks on each write
function distributeRewards(address[] calldata users, uint256[] calldata amounts) external {
    for (uint i = 0; i < users.length; i++) {
        (bool ok,) = users[i].call{value: amounts[i]}("");  // also a reentrancy risk
    }
}

// GOOD: users pull their own rewards — each write is isolated to one key
mapping(address => uint256) public accrued;

function accrue(address user, uint256 amount) internal {
    accrued[user] += amount;  // isolated per user
}

function withdraw() external {
    uint256 due = accrued[msg.sender];
    accrued[msg.sender] = 0;     // single isolated write
    (bool ok,) = msg.sender.call{value: due}("");
    require(ok, "TRANSFER_FAILED");
}
```

### Avoid storage writes in loops

```solidity
// BAD: 10 writes = 720,000 gas (10 × 72k)
function batchUpdate(address[] calldata users, uint256[] calldata scores) external {
    for (uint i = 0; i < users.length; i++) {
        playerScores[users[i]] = scores[i];  // 72k each
    }
}

// BETTER: emit events for off-chain tracking; only write final state
// Or: use merkle proofs and let users update their own slot (pull pattern)
```

## SSTORE Gas Awareness

SSTORE on Sei costs **72,000 gas** (governance-adjustable, vs 20,000 on Ethereum).

**Budget impact:**
- A simple 3-slot write transaction: 3 × 72k = 216k gas just for storage
- Block gas limit is 12.5M — a write-heavy transaction uses a large fraction of a block

**Strategies:**
- Compute in memory; write only the final aggregate
- Cache `storage` reads in `memory` variables inside functions
- Use `bytes32` slots that pack multiple values (reduce slot count)
- Question whether every on-chain variable actually needs to be on-chain

```solidity
// Cache storage reads in memory
function complexCalc(uint256 id) external {
    // BAD: repeated storage reads
    if (data[id].value > 0 && data[id].timestamp < block.timestamp) {
        data[id].value = data[id].value * 2;  // 3 reads, 1 write
    }

    // GOOD: cache in memory
    Record memory r = data[id];               // 1 read
    if (r.value > 0 && r.timestamp < block.timestamp) {
        data[id].value = r.value * 2;         // 1 write
    }
}
```

## Zeroing Stale State (Gas Refund)

Setting a storage slot from non-zero → zero earns a **4,800 gas refund** per slot. On Sei, where state growth matters for node performance, zeroing stale state is a good practice.

### Simple deletes

```solidity
delete myUint;      // → 0
delete myBool;      // → false
delete myAddress;   // → address(0)
delete fixedArray;  // zeros all elements
```

### Batched clearing for dynamic arrays

```solidity
uint256[] public queue;

// Call repeatedly with batchSize chunks to avoid gas limit
function batchClear(uint256 batchSize) external {
    uint256 toClear = batchSize < queue.length ? batchSize : queue.length;
    for (uint256 i = 0; i < toClear; i++) {
        queue.pop();   // 4,800 gas refund per pop
    }
}
```

### Clearing mappings (requires a key index)

```solidity
// Maintain index when writing (costs ~2 extra SSTOREs per new key)
mapping(address => uint256) public balances;
address[] public holders;

function setBalance(address user, uint256 amount) external {
    if (balances[user] == 0 && amount > 0) holders.push(user);
    balances[user] = amount;
}

// Batch clear later using the index
function batchClearBalances(uint256 start, uint256 end) external {
    for (uint256 i = start; i < end; i++) {
        delete balances[holders[i]];  // 4,800 gas refund each
    }
}
```

## General Solidity Gas Efficiency

```solidity
// ✅ Use external (not public) for externally called functions
function transfer(address to, uint256 amount) external { ... }

// ✅ Pack variables (uses 1 slot instead of 3)
struct PackedData {
    uint128 value;    // 16 bytes
    uint64 timestamp; // 8 bytes
    bool active;      // 1 byte
    // total = 25 bytes, fits in 1 slot
}

// ✅ Cache array length in loops
uint256 length = arr.length;
for (uint256 i = 0; i < length; i++) { ... }

// ✅ Use unchecked for safe arithmetic
unchecked { counter += 1; }  // saves ~20 gas per increment

// ✅ bytes32 vs string for fixed identifiers
bytes32 name = "MyToken";   // cheaper than string memory

// ✅ Prefer memory over storage for temporaries
function calc(uint256 id) external view returns (uint256) {
    uint256 cached = data[id]; // one read, memory thereafter
    return cached * 2;
}
```

## Use Precompiles for Supported Operations

Sei precompiles are highly optimized native contracts — cheaper and more reliable than equivalent Solidity:

| Operation | Precompile | Address |
|---|---|---|
| JSON parsing | JSON | `0x1003` |
| P-256 signature verify | P256 | `0x1011` |
| Stake/unstake SEI | Staking | `0x1005` |
| Claim rewards | Distribution | `0x1007` |
| On-chain governance vote | Governance | `0x1006` |
| Oracle price feed | Oracle | `0x1008` |
| Address conversion | Addr | `0x1004` |
| Native token send | Bank | `0x1001` |

See [precompiles/overview.md](../precompiles/overview.md) for usage examples.

## Parallelization Audit Checklist

Before deploying a new contract:

- [ ] No hot global writes that all users touch in every transaction
- [ ] State partitioned by user address or unique ID where possible
- [ ] Payment flows use pull (withdraw) not push (distribute loop)
- [ ] Loops don't write to storage unless the batch size is bounded and small
- [ ] `forge test --gas-report` shows no unexpectedly expensive operations
- [ ] SSTORE count per critical path is minimized
- [ ] Events emitted for data that can be indexed off-chain
