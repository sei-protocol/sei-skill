---
title: Performance & Load Testing on Sei
description: How to load-test contracts on Sei testnet, mirror sei-chain's loadtest harness for parallel-execution stress testing, and measure throughput against the 12.5M gas-per-block budget at 400ms blocks.
---

# Performance & Load Testing on Sei

Sei's value proposition is throughput — 400ms blocks, parallel execution via OCC, 12.5M gas budget per block. Contracts that look fine in unit tests can serialize at scale if storage layout fights the scheduler. Load test before mainnet.

## What to measure

| Metric | Target | Why |
|---|---|---|
| **TPS sustained** | as high as the workload allows | Validates parallelism actually kicks in |
| **Gas/tx** | minimize | Throughput is gas-bound (12.5M/block) |
| **Conflict rate** | < 5% under normal load | High conflict = workload serializes |
| **p99 inclusion latency** | ~1-2 blocks (400-800ms) | Confirms no mempool backlog |
| **State growth** | bounded | SeiDB compacts, but unbounded growth still hurts node ops |

## Throughput math

```
max_tps = block_gas_limit / avg_gas_per_tx / block_time_seconds
        = 12_500_000 / 100_000 / 0.4
        ≈ 312 tps  (single-tx-type workload at 100k gas each)
```

Parallelization can multiply effective throughput by 5-10× **if** transactions don't conflict on storage. Conflict serializes them back to sequential.

## Local fork-based load test (Foundry)

Quickest signal: stress-test against a forked testnet locally. No real funds, fast iteration.

```bash
# Start anvil forking Sei testnet
anvil --fork-url https://evm-rpc-testnet.sei-apis.com --chain-id 1328
```

Then a Forge script that fires N concurrent calls:

```solidity
// script/Loadtest.s.sol
pragma solidity ^0.8.28;
import "forge-std/Script.sol";

contract Loadtest is Script {
    function run() external {
        address target = vm.envAddress("TARGET");
        uint256 n = vm.envUint("N"); // e.g., 1000

        vm.startBroadcast();
        for (uint256 i = 0; i < n; i++) {
            // Each iteration uses a different sender → tests parallel paths
            (bool ok,) = target.call(abi.encodeWithSignature("doWork(uint256)", i));
            require(ok, "call failed");
        }
        vm.stopBroadcast();
    }
}
```

Run:

```bash
TARGET=0x... N=1000 forge script script/Loadtest.s.sol --rpc-url http://localhost:8545 --broadcast
```

This won't measure parallelism (anvil is sequential) but it surfaces gas regressions, reverts, and obvious bottlenecks.

## Real parallelism test on testnet

To actually exercise OCC, send concurrent txs from many different accounts:

```ts
// loadtest.ts
import { createPublicClient, createWalletClient, http } from "viem";
import { mnemonicToAccount } from "viem/accounts";

const NUM_WORKERS = 50;
const TXS_PER_WORKER = 20;
const RPC = "https://evm-rpc-testnet.sei-apis.com";

async function worker(workerIdx: number) {
  const account = mnemonicToAccount(process.env.MNEMONIC!, { path: `m/44'/60'/0'/0/${workerIdx}` });
  const wallet = createWalletClient({ account, transport: http(RPC) });
  for (let i = 0; i < TXS_PER_WORKER; i++) {
    await wallet.sendTransaction({
      to: process.env.TARGET as `0x${string}`,
      data: `0x12345678${i.toString(16).padStart(64, "0")}`,
      gasPrice: 50_000_000_000n,
    });
  }
}

await Promise.all(Array.from({ length: NUM_WORKERS }, (_, i) => worker(i)));
```

Each worker uses a distinct EOA, so OCC can parallelize their nonces. Fund 50+ accounts via the testnet faucet (loop a small script).

## Measuring conflict rate

After the test, query block traces and count how many transactions reverted from OCC conflict re-execution. Sei exposes execution metadata via debug RPC. The crude heuristic:

- Sample N blocks during the test window.
- For each block, ratio of `(actual_gas_used / theoretical_serial_gas)`.
- A ratio > 0.6 means most txs are conflicting; < 0.3 means good parallelism.

Use a community indexer (Goldsky, Dune) to aggregate this — see [indexers.md](../ecosystem/indexers.md).

## sei-chain loadtest harness

The official `sei-chain/loadtest` directory contains tools the Sei team uses for protocol-level benchmarking. It's not packaged for end users, but the patterns are educational:

- **`evm_loadtest`** — multi-worker EVM tx blast that mirrors the worker pattern above.
- **`occ_tests`** — unit tests for the OCC scheduler with synthetic conflict patterns.

Source: https://github.com/sei-protocol/sei-chain/tree/main/loadtest

You don't need to fork it. Build your own loadtest in TypeScript with viem (above) — same shape, easier to iterate.


### EVM-only executor load harness (`evmonly-loadtest`)

sei-chain v6.7.0 added a standalone harness at `giga/evmonly/cmd/evmonly-loadtest` that feeds synthetic blocks directly into the EVM-only executor with mock state and receipt sinks — no Cosmos SDK, mempool, RPC, or chain persistence. It isolates executor/OCC throughput from block production, so it's the most direct way to see how a workload behaves under parallel execution.

Basic bounded run:

```bash
go run ./giga/evmonly/cmd/evmonly-loadtest --blocks=1000 --txs-per-block=1000
```

The synthetic workload defaults to local EVM chain ID `1337` (override with `--chain-id`). `--blocks` is required and must be greater than `0`; the harness prebuilds every block before the measured phase.

Three workloads, selected with `--workload` (default `transfer`):

- `transfer` — pure EVM legacy transfer transactions. Recipients are unique by default (optimistic no-overlap). Pass `--recipient-conflict-rate=<0..1>` to pair that fraction of each block onto shared recipients, `--recipient=0x...` to force one recipient, or `--same-sender` to use one sender with sequential nonces per block.
- `erc20-transfer` — ERC20 transfer calls using sei-load's compiled contract runtime.
- `snapshot-revert` — a contract-call workload that exercises nested StateDB snapshot/revert behavior (`--snapshot-revert-contract`, `--snapshot-revert-helper`).

The three OCC scenarios map to conflict-free (unique senders/recipients), hot-recipient (`--recipient=0x...`), and same-sender nonce chain (`--same-sender`). Zero gas settings keep the conflict-free case focused on no-overlap:

```bash
go run ./giga/evmonly/cmd/evmonly-loadtest \
  --blocks=400 --txs-per-block=5000 \
  --gas-price-wei=0 --min-gas-price-wei=0 \
  --recipient-conflict-rate=0.10
```

Non-zero fees make every tx update the coinbase balance — a real intra-block conflict.

Useful tuning flags: `--workers` (parallel executors, default `1`), `--executor-workers` (OCC workers per executor, default `min(12, GOMAXPROCS)`), `--prepare-workers`, `--parse-workers`, `--builders`, `--queue-size` (default `64`). Result handling: `--result-sink=discard|file`, with `--persist-dir`, `--persist-sync`, `--persist-buffer-size`, `--persist-queue-size` for the file sink. Profiling: `--cpu-profile`, `--heap-profile`, `--trace-profile`.

Observability: unless `--metrics-addr=` is empty, an HTTP server listens on `--metrics-addr` (default `127.0.0.1:9698`) exposing Prometheus metrics at `/metrics` and a `/healthz` endpoint. `--report-interval` (default `5s`) also prints throughput to stdout. Metrics include block input/preparation/finishing throughput, finished/successful/failed tx per second, gas per second, total OCC rerun attempts, queue depths, and result-sink stats. `sink_enqueue_wait` is the primary backpressure signal — a non-zero value means executor workers waited for async sink queue capacity.


## Common bottlenecks discovered by load testing

| Symptom | Likely cause | Fix |
|---|---|---|
| TPS ceiling far below theoretical | Single hot storage slot | Partition state per user/asset/id (see [evm/best-practices.md](../evm/best-practices.md)) |
| Many txs revert under load | Reentrancy guard global counter | Use per-user reentrancy state or remove guard if the function is naturally idempotent |
| Long-tail p99 latency | Mempool fill from low gas price | Use ≥ 50 gwei (Sei minimum) |
| Gas usage spikes mid-test | Storage growth (cold→warm transitions) | Pre-warm state in test setup, or accept the cost |
| Tests pass on testnet, fail on mainnet | SSTORE costs 72k on both networks | Run gas-report on both targets; budget for the higher cost |

## Gas profiling

```bash
forge test --gas-report --fork-url https://evm-rpc-testnet.sei-apis.com
forge test --gas-report --fork-url https://evm-rpc.sei-apis.com
```

Diff the two reports — anything that changes is a function whose cost depends on Sei's per-network params (typically SSTORE-heavy paths).

## Continuous benchmarking

For a serious project, wire load tests into CI:
- Nightly job runs the testnet loadtest against a deployed staging contract.
- Snapshot TPS, gas/tx, conflict rate.
- Alert on regressions > 20%.

## Sei-specific notes

- **Min gas price 50 gwei** — undercutting causes mempool eviction, not just slow inclusion.
- **400ms blocks** mean retries are cheap; no need for elaborate exponential backoff in clients.
- **No EIP-1559** — use legacy `gasPrice`; `maxFeePerGas` is ignored or rejected.
- **OCC re-execution** — a "failed" tx may actually have been successfully re-executed in a later batch; check final receipt status, not intermediate logs.
