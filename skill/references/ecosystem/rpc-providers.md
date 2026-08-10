---
title: Sei RPC Endpoints — Public, Community, and Paid
description: Curated list of EVM and Cosmos RPC endpoints for Sei mainnet (pacific-1) and testnet (atlantic-2). Free community providers, paid SaaS providers, rate limits, and selection guidance.
---

# Sei RPC Endpoints

Public, community, and paid RPC endpoints for Sei. Use this as the source of truth when wiring an RPC URL into a dApp, indexer, script, or wallet config.

> The canonical, **always-current** list lives at https://docs.sei.io/learn/rpc-providers. The table below is for quick lookup; defer to docs.sei.io for any production decision.

## Quick decision: which provider?

| Use case | Recommended | Why |
|---|---|---|
| **Local dev / hackathon** | Sei Foundation public endpoint | Zero setup; rate-limited but generous |
| **Production frontend (low volume)** | Sei Foundation public + fallback to community | Free; spread load across multiple |
| **Production frontend (high volume)** | Paid (Alchemy, QuickNode, dRPC) | SLA, dedicated capacity, archive |
| **Indexer / heavy backend** | Self-hosted node OR paid archive | Full event history, no rate limit |
| **Server-side scripts** | Sei Foundation public + community fallback | Free + diversified |
| **Production with strict SLA** | Multiple paid providers (failover) | Single-provider outage shouldn't kill you |

## Mainnet (pacific-1) — Chain ID 1329

### Sei Foundation (official)

| Endpoint | Type | Notes |
|---|---|---|
| `https://evm-rpc.sei-apis.com` | EVM JSON-RPC | Primary EVM endpoint |
| `https://rpc.sei-apis.com` | Cosmos Tendermint RPC | Native Cosmos RPC |
| `https://rest.sei-apis.com` | Cosmos REST/LCD | Cosmos SDK REST |
| `grpcs://grpc.sei-apis.com:443` | Cosmos gRPC | High-performance native |

### Community (free)

| Provider | EVM RPC | Cosmos RPC |
|---|---|---|
| **Polkachu** | (varies) | https://sei-rpc.polkachu.com |
| **Lavender.Five Nodes** | (varies) | https://sei-rpc.lavenderfive.com |
| **Brochain** | (varies) | https://sei-rpc.brocha.in |
| **Stingray** | (varies) | https://rpc-sei.stingray.plus |
| **kjnodes** | (varies) | https://sei.rpc.kjnodes.com |
| **Allnodes** | (varies) | https://sei-rpc.publicnode.com:443 |
| **1RPC** | https://1rpc.io/sei (verify) | https://1rpc.io/sei-rpc |

> Verify via https://chainlist.org/chain/1329 and https://www.comparenodes.com/protocols/sei/ before relying on a community endpoint.

### Paid / SaaS

| Provider | Tier | Notes |
|---|---|---|
| **QuickNode** | Free + paid | Archive nodes, high RPS |
| **dRPC** | Free + paid ($10/mo+) | Multi-chain pool |
| **Alchemy** | Free + paid | Wide chain support; Sei via custom RPC |
| **Ankr** | Free + paid | Public + premium |
| **RHINO Stake** | Enterprise | Validator + RPC infra |
| **GetBlock** | Free + paid | API-key-based |

## Testnet (atlantic-2) — Chain ID 1328

| Endpoint | Type | Notes |
|---|---|---|
| `https://evm-rpc-testnet.sei-apis.com` | EVM JSON-RPC | Foundation primary |
| `https://rpc-testnet.sei-apis.com` | Cosmos Tendermint RPC | Foundation primary |
| `https://rest-testnet.sei-apis.com` | Cosmos REST/LCD | Foundation primary |

Testnet faucet: https://atlantic-2.app.sei.io/faucet (link via [networks.md](../networks.md)).

## Selection checklist

Before wiring an endpoint into production:

- [ ] Confirm it's the right network (testnet vs mainnet — chain IDs 1328 vs 1329).
- [ ] Confirm protocol (EVM JSON-RPC vs Cosmos Tendermint vs gRPC). They are different APIs.
- [ ] Test rate limits with a representative load: `for i in {1..50}; do curl ...; done`.
- [ ] Test from your production region; latency varies.
- [ ] Test archive features if you need historical state (`eth_getBalance` with old block).
- [ ] Plan for failover: at least two providers, ideally three for production.

## Failover with viem

```ts
import { createPublicClient, fallback, http } from "viem";

const client = createPublicClient({
  chain: { id: 1329, /* ... */ },
  transport: fallback([
    http("https://evm-rpc.sei-apis.com"),
    http("https://1rpc.io/sei"),
    http("https://your-paid-provider.example/sei"),
  ], { rank: true }),
});
```

`rank: true` periodically benchmarks endpoints and routes to the fastest.

## Failover with ethers v6

```ts
import { JsonRpcProvider, FallbackProvider } from "ethers";

const provider = new FallbackProvider([
  { provider: new JsonRpcProvider("https://evm-rpc.sei-apis.com"), priority: 1 },
  { provider: new JsonRpcProvider("https://1rpc.io/sei"), priority: 2 },
], 1329);
```

## Self-hosted (recommended for serious backends)

For indexers, high-volume APIs, or anyone who can't tolerate third-party rate limits, run your own Sei node. See [node-operations.md](node-operations.md) for setup, snapshot sync, and configuration.

## RPC method coverage

Standard Ethereum JSON-RPC methods supported on Sei EVM:
- `eth_call`, `eth_getTransactionReceipt`, `eth_getLogs`, `eth_getBalance`, `eth_blockNumber`, etc.
- `eth_sendRawTransaction` — submit signed transactions.
- `eth_estimateGas`, `eth_gasPrice` — note Sei's 50 gwei minimum.

Sei-specific methods (varies by provider, check before relying):
- `sei_getEVMAddress` / `sei_getSeiAddress` / `sei_getCosmosTx` — the **three default-enabled** legacy helpers (dual-address + Cosmos tx lookup).
- `debug_traceTransaction` — trace support depends on provider; archive providers have it.

> **Legacy `sei_*` / `sei2_*` are gated and deprecated.** As of the `[evm].enabled_legacy_sei_apis` config (`evm.enabled_legacy_sei_apis` flag/env in `app.toml`), most `sei_*` and all `sei2_*` JSON-RPC methods are **gated behind an allowlist** and **default to disabled**. Only the three helpers above (`sei_getSeiAddress`, `sei_getEVMAddress`, `sei_getCosmosTx`) are enabled out of the box on a `seid init` node. Any other `sei_*`/`sei2_*` method not explicitly listed returns a JSON-RPC error `code: -32601` with `data: "legacy_sei_deprecated"` (HTTP 200) — and unknown `sei_*` names fail closed. **Do not assume `sei_*`/`sei2_*` methods are available on a given endpoint.** All of them are deprecated and scheduled for removal; migrate to `eth_*` / `debug_*` equivalents. Successful allowlisted responses may carry an `Sei-Legacy-RPC-Deprecation` HTTP header as a deprecation signal. (The `sei2_*` namespace mirrors `sei_*` block payloads but includes bank transfers; HTTP only, no `sei2` transaction or filter API.) Note: the `sei_traceBlockByNumberExcludeTraceFail` and `sei_traceBlockByHashExcludeTraceFail` endpoints have been **removed** — use `debug_traceBlockByNumber` and `debug_traceBlockByHash` instead. They are no longer valid entries in `enabled_legacy_sei_apis`.

Methods that may **not** be supported on every endpoint:
- `eth_subscribe` (WebSockets) — provider-dependent; Sei Foundation supports WS at `wss://evm-ws.sei-apis.com` (verify).
- `debug_*` and `trace_*` — typically only on archive nodes / paid tiers.

## Rate limits — typical (verify per provider)

| Provider | Free RPS | Paid RPS |
|---|---|---|
| Sei Foundation | unspecified, throttled | n/a |
| 1RPC | ~100 RPS | n/a (free only) |
| QuickNode | 25 RPS (free) | 1500+ (paid) |
| dRPC | shared pool | tier-based |

> RPS limits change frequently; benchmark against your actual load before launch.

## WebSocket endpoints

For event subscriptions:

| Network | WSS endpoint |
|---|---|
| Mainnet | `wss://evm-ws.sei-apis.com` (verify) |
| Testnet | `wss://evm-ws-testnet.sei-apis.com` (verify) |

Most paid providers offer WSS on their dedicated tier. Don't rely on a single WSS — connections can drop; reconnect with exponential backoff.

## Indexer-friendly archive RPC

For backfilling subgraphs or doing historical analytics, you need archive RPC (full state at any past block). Free public endpoints typically don't support this; use a paid archive provider or self-host.

Self-hosting archive: see [node-operations.md](node-operations.md). Disk requirements are 5-10× a pruned full node.

## Sei-specific notes

- **Always set `gasPrice ≥ 50 gwei`** in calls submitted via these endpoints; under-priced txs will be rejected by the RPC or evicted from mempool.
- **Cosmos and EVM RPCs are separate.** A `sei1...`-targeted operation needs the Cosmos Tendermint RPC (`rpc.sei-apis.com`); a `0x...`-targeted call needs the EVM RPC (`evm-rpc.sei-apis.com`).
- **Block tags**: `latest`, `pending`, `earliest` are supported; `safe` and `finalized` are not (Sei has instant finality, so `latest` is functionally equivalent to `finalized`).


- **`eth_getBlockByNumber` for future / non-existent numeric heights returns `result: null`** (per the Ethereum JSON-RPC spec), not a JSON-RPC error. Earlier builds returned error `-32000` (e.g. `requested height 1000 is not yet available; safe latest is 128`); current builds map a numeric block number above the node's safe latest watermark to `null`. Handle a `null` block result rather than expecting an error for out-of-range numeric heights.


- **`eth_getTransactionByBlockHashAndIndex` and `eth_getTransactionByBlockNumberAndIndex` return `result: null` for an out-of-range index** (as of v6.5, sei-chain [#3367](https://github.com/sei-protocol/sei-chain/pull/3367)). Earlier builds could error or return unexpected data when the transaction index exceeded the number of transactions in the block; current builds return `null`. Handle a `null` result rather than expecting an error when probing indices at or beyond the block's transaction count.
- **`eth_getProof` now works across more node/store configurations.** Proof lookup unwraps additional KVStore wrappers (cachekv, Giga cache, tracekv, and prefix stores) to reach any proof-capable queryable store, so it succeeds beyond just classic IAVL nodes. Older builds returned error `-32000 "cannot find EVM IAVL store"` on non-IAVL backends; current builds resolve any proof-capable queryable KV store (classic IAVL, store/v2 memiavl, etc.).
- **`eth_getProof` storage keys must be hex-encoded, and are capped at 1024 per request.** Each storage key in the `storageKeys` array must be a valid hex string (e.g. `"0x0000...0001"`); it is decoded and left-padded to 32 bytes. Raw byte-string keys are no longer accepted — a non-hex key returns an `invalid storage key "<key>": ...` error. Requests with more than `MaxStorageKeysPerProof` (1024) keys are rejected with `too many storage keys: got <n>, max 1024`. Example: `eth_getProof(address, ["0x0000000000000000000000000000000000000000000000000000000000000001"], blockTag)`.


## Cosmos pagination hard caps (`PageRequest`)

Cosmos REST/LCD (`rest.sei-apis.com`), gRPC (`grpc.sei-apis.com`), and Tendermint-RPC-backed queries that accept a `PageRequest` (`pagination.limit`, `pagination.offset`, `pagination.key`, `pagination.count_total`, `pagination.reverse`) now enforce **hard caps**. Requests that exceed them fail with a gRPC `InvalidArgument` error (HTTP 400 over REST) — they are *not* silently clamped.

| Cap | Value | Field | Error on exceed |
|---|---|---|---|
| `MaxLimit` | **1000** (per page) | `pagination.limit` | `limit <n> exceeds maximum allowed limit 1000` |
| `MaxOffset` | **10000** | `pagination.offset` | `offset <n> exceeds maximum allowed offset 10000` |
| `MaxScanLimit` | **10000** | (internal store-scan cap) | `scanned more than 10000 entries ...; use key-based pagination instead` |

Key behavior changes (breaking):

- **`limit` is capped at 1000 per page.** Previously `MaxLimit` was effectively unbounded (`math.MaxUint64`). A `pagination.limit` above 1000 is now **rejected**, not truncated. To retrieve a full dataset, page through it with `pagination.key` set to the previous response's `next_key`, using `limit=1000` each request — do not ask for everything in one call.
- **`offset` is capped at 10000.** Deep offset-based paging is no longer possible; switch to key-based (cursor) pagination via `pagination.key` for anything beyond the first ~10k records.
- **Offset-based (lazy) pagination caps its store scan.** For sparse filters or `count_total`, the query walks at most `MaxScanLimit` (10000) entries past the page start/end. Exceeding this returns `InvalidArgument` and the `next_key` may be `nil` even when more results exist. Use **key-based pagination** for reliable traversal of sparse or large datasets.
- **`count_total` is no longer auto-enabled.** Previously, omitting `limit` (or `limit=0`) implicitly counted all records and populated `pagination.total`. Now `total` is **`0` unless you explicitly set `pagination.count_total=true`**. Code that relied on a populated `total` from a default/empty page request will now read `0` — add `count_total=true` (and expect the scan cost + `MaxScanLimit` cap it incurs).

Example — REST query paging by key at the max page size, explicitly counting totals:

```bash
curl "https://rest.sei-apis.com/cosmos/bank/v1beta1/supply?pagination.limit=1000&pagination.count_total=true"
# follow next_key from the response for subsequent pages:
curl "https://rest.sei-apis.com/cosmos/bank/v1beta1/supply?pagination.limit=1000&pagination.key=<base64 next_key>"
```

> A bare request like `.../supply` (no `count_total`) returns at most `DefaultLimit` (100) records with `total: 0` — set `pagination.count_total=true` if you actually need the count.
- **Endpoint freshness**: Sei is a fast-moving project — verify endpoints monthly against [docs.sei.io/learn/rpc-providers](https://docs.sei.io/learn/rpc-providers).
- For agent-driven RPC usage, see [rpc-agent-skills.md](rpc-agent-skills.md) for the canonical 17 RPC skills, retry/backoff patterns, and response-shape expectations.
