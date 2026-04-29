---
title: Sei-Specific Gas Optimization
description: Gas optimization rules of thumb that differ from mainnet Ethereum — SSTORE cost variance (72k testnet / 20k mainnet), 50 gwei minimum, 12.5M block limit, calldata vs storage trade-offs at 400ms blocks, and patterns that exploit instant finality.
---

# Sei-Specific Gas Optimization

Most Solidity gas advice transfers from Ethereum directly. This file covers only the Sei deltas that change priorities.

## Cheat sheet: what's different on Sei

| Parameter | Ethereum mainnet | Sei mainnet (`pacific-1`) | Sei testnet (`atlantic-2`) |
|---|---|---|---|
| Block time | ~12s | **400ms** | 400ms |
| Block gas limit | 30M | **12.5M** | 12.5M |
| Min gas price | dynamic (EIP-1559) | **50 gwei (fixed)** | 50 gwei |
| Cold SSTORE | 22,100 gas | 22,100 gas | 22,100 gas |
| Warm SSTORE (zero→nonzero) | 20,000 gas | 20,000 gas | **72,000 gas** |
| EIP-1559 base fee burn | yes | **no — all to validators** | no |
| `PREVRANDAO` | RANDAO output | **block-time-derived (NOT random)** | NOT random |
| `COINBASE` | block proposer | **fee collector address** | fee collector |

## Rule 1: SSTORE costs differ between testnet and mainnet

Testnet (atlantic-2) charges **72,000 gas per zero→nonzero SSTORE** (governance proposal #240). Mainnet (pacific-1) charges 20,000. Both are governance-adjustable; verify against your target network before assuming.

**Implication:** a contract that costs 200k gas/tx on mainnet can cost 600k on testnet. Don't size your gas budget from testnet-only measurements.

```bash
# Run gas reports against both
forge test --gas-report --fork-url https://evm-rpc.sei-apis.com         # mainnet
forge test --gas-report --fork-url https://evm-rpc-testnet.sei-apis.com # testnet
```

The diff between the two gas reports is exactly the SSTORE cost delta × number of writes.

### Practical optimizations

- **Pack tight when first writing** — first write is the expensive one; subsequent writes to a warm slot are cheap.
- **Avoid setting then unsetting** — clearing a slot back to zero refunds gas (capped on Sei as on EIP-3529 Ethereum), but the round-trip rarely beats not writing at all.
- **Use `transient` storage (EIP-1153)** for cross-call temporaries that don't need persistence — no SSTORE cost. Sei supports `tload`/`tstore` opcodes.

## Rule 2: 50 gwei minimum, no EIP-1559

Setting `gasPrice` below 50 gwei results in mempool eviction, not slow inclusion.

```ts
// Viem
await wallet.sendTransaction({
  to: target,
  data: "0x...",
  gasPrice: 50_000_000_000n,   // 50 gwei legacy, NOT maxFeePerGas
});
```

```solidity
// Foundry deploy script
vm.txGasPrice(50 gwei);
```

`maxFeePerGas` / `maxPriorityFeePerGas` are accepted but priority-fee mechanics don't apply (no base fee burn, no priority fee market). Use legacy `gasPrice`.

## Rule 3: 12.5M block gas limit — design accordingly

Single-tx gas limit is bounded by the block limit (a tx can't exceed it). Design hot paths under ~5M gas to leave headroom for other transactions in the block. Long migration scripts that consume 15M+ gas on Ethereum need to be **split into multiple transactions** on Sei.

```solidity
// BAD on Sei — single tx exceeds block limit if N is large
function migrateAll(address[] calldata users) external {
    for (uint256 i = 0; i < users.length; i++) { /* heavy work */ }
}

// GOOD — pageable migration
function migrateBatch(address[] calldata users, uint256 start, uint256 count) external {
    for (uint256 i = start; i < start + count; i++) { /* heavy work */ }
}
```

## Rule 4: Calldata vs storage trade-offs at 400ms blocks

Because blocks are 30× faster than Ethereum, the cost of "I'll just send another tx" is dramatically lower. Some patterns flip:

| Pattern | Ethereum (12s blocks) | Sei (400ms blocks) |
|---|---|---|
| Cache result on-chain to avoid recompute | often worth the SSTORE | usually NOT worth it; recompute or send a follow-up tx |
| Batch many ops into one tx | reduces overhead, saves user clicks | still helpful for UX but less of a gas win |
| Optimistic UI w/o await | risky (12s feedback loop) | natural — confirmation in 400ms |

If a value is read often and changes rarely, cache it. If it's read rarely and changes per-tx, recompute it.

## Rule 5: Use `calldata` not `memory` for read-only inputs

(Same as Ethereum, just emphasized because it stays a high-impact micro-optimization.)

```solidity
// 30-50% cheaper for large inputs
function process(uint256[] calldata data) external { /* ... */ }

// Avoid unless you mutate the input
function process(uint256[] memory data) external { /* ... */ }
```

## Rule 6: Avoid PREVRANDAO and timestamp-based randomness

`block.prevrandao` on Sei returns a block-time-derived value, **not** RANDAO output. Using it for randomness is a security bug. Use Pyth VRF or Chainlink VRF — see [oracles.md](../oracles.md).

## Rule 7: COINBASE is the fee collector, not the proposer

Don't use `block.coinbase` to identify the block proposer. It returns the global fee collector address. If you need the validator that signed a block, query consensus state via the `JSON` precompile or off-chain — see [precompiles/json-p256.md](../precompiles/json-p256.md).

## Rule 8: Gas-grief patterns from Ethereum stay applicable

These are not Sei-specific but matter equally:

- Use `unchecked { ++i; }` in loops where overflow is impossible.
- Short-circuit boolean checks (`require(cheapCheck && expensiveCheck, ...)`).
- Avoid string error messages — use custom errors (Solidity 0.8.4+).
- Cache `array.length` outside loops if you read it many times.
- Prefer `external` over `public` for functions never called internally.

## Sei-specific micro-pattern: pull-and-zero

Because mainnet warm SSTORE is 20k (not 72k like testnet), the classic "withdraw and zero" pattern is cheap:

```solidity
function withdraw() external {
    uint256 due = accrued[msg.sender];   // SLOAD
    accrued[msg.sender] = 0;             // SSTORE warm — cheap
    payable(msg.sender).sendValue(due);
}
```

On testnet, that single SSTORE costs 72k. Worth knowing if you load-test on testnet — your real-world (mainnet) cost is much lower.

## Multicall on Sei

`Multicall3` is deployed on both Sei networks at the standard address `0xcA11bde05977b3631167028862bE2a173976CA11`. Use for client-side batching of view calls.

```ts
import { multicall } from "viem/actions";

const results = await multicall(client, {
  contracts: [
    { address: token, abi: ERC20_ABI, functionName: "balanceOf", args: [user] },
    { address: token, abi: ERC20_ABI, functionName: "symbol" },
  ],
});
```

## Profiling workflow

1. `forge test --gas-report` → identify hot functions.
2. `forge snapshot --diff` → catch regressions in CI.
3. Fork-test against testnet to surface real-world cost: `forge test --fork-url https://evm-rpc-testnet.sei-apis.com --gas-report`.
4. Cross-check against mainnet: same flag, mainnet RPC.
5. Load-test the suspect functions ([performance-testing.md](performance-testing.md)).

## When to stop optimizing

400ms finality and a 12.5M gas budget mean you have *plenty* of throughput headroom for most workloads. Don't sacrifice readability for marginal gas wins below 1k gas/tx. Spend optimization budget on:

1. Removing hot global writes (parallelism > raw gas).
2. Lazy aggregation (events > on-chain counters).
3. Pull-payment patterns (per-user isolation > batch push).

The first three solve throughput problems no amount of `unchecked` blocks will.
