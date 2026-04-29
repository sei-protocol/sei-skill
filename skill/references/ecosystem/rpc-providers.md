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

Testnet faucet: https://docs.sei.io/learn/faucet (link via [networks.md](../networks.md)).

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
- `sei_getEVMAddress` / `sei_getSeiAddress` — dual-address lookup.
- `debug_traceTransaction` — trace support depends on provider; archive providers have it.

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
- **Endpoint freshness**: Sei is a fast-moving project — verify endpoints monthly against [docs.sei.io/learn/rpc-providers](https://docs.sei.io/learn/rpc-providers).
- For agent-driven RPC usage, see [rpc-agent-skills.md](rpc-agent-skills.md) for the canonical 17 RPC skills, retry/backoff patterns, and response-shape expectations.
