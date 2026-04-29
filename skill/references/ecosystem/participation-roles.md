---
title: Sei Ecosystem Participation Roles
description: How to participate in the Sei ecosystem as a validator, RPC provider, indexer operator, oracle relayer, IBC relayer, or grant recipient. Pointers into deeper references for each role.
---

# Sei Ecosystem Participation Roles

Beyond building dApps, the Sei ecosystem has operational roles that earn revenue or influence: validators, RPC providers, indexer operators, oracle relayers, IBC relayers, and grants/builder programs. This page is a router — most roles have dedicated reference files; this is the index.

## Quick decision: which role?

| Role | Capital required | Technical bar | Revenue model |
|---|---|---|---|
| **Validator** | Self-bond + delegation TVL | High (uptime, HSM, ops) | Block rewards + commission on delegators |
| **RPC provider** | Hardware (high-spec node) | Medium-high | Paid endpoints, infrastructure SLAs |
| **Indexer operator** | Hardware (DB + node) | Medium | Per-query / subscription fees |
| **Oracle relayer** | Operational | Medium | Off-chain operator role; revenue depends on the oracle network |
| **IBC relayer** | Infrastructure + transaction fees on both chains | Medium | Optional fee-routing or altruistic |
| **Grants / Builder program** | Building a dApp | Varies | One-time or milestone-based grant |

## Validator

Run a Sei validator: produce blocks, earn block rewards + commission from delegators, hold consensus voting power proportional to bonded stake.

**Hardware**: enterprise-grade — high-CPU, NVMe SSD, redundant network. SeiDB and the OCC scheduler benefit from many cores and fast disks.

**Operational**: uptime monitoring, slashing avoidance (downtime + double-sign), secure key management (HSM strongly recommended), governance participation.

**Economic**: self-bond + delegation; commission rate is your competitive lever.

→ Full operational guide: [validators.md](../validators.md)
→ Node setup: [node-operations.md](../node-operations.md)

Apply for validator slot info via:
- https://docs.sei.io/node/validator-operations
- Sei validator Discord channels (links via [resources.md](../resources.md))

## RPC provider

Run public or paid RPC endpoints for Sei mainnet/testnet. Users (dApps, indexers, wallets) hit your endpoint to read chain state and submit transactions.

**Tiers**:
1. **Community/free** — altruistic public endpoint; volume-throttled; valuable for testnet and decentralization.
2. **Paid SaaS** — dedicated tenants, archive nodes, SLA guarantees (QuickNode, Alchemy, dRPC, etc.).
3. **Enterprise / private** — operated for a single dApp or institutional customer.

**Hardware**: full or archive node; archive nodes for historical state/trace queries are 5-10× the disk of a pruned full node.

**Software**: standard `seid` binary; tune RPC config for higher concurrent connection limits than a validator node.

→ Setup: [node-operations.md](../node-operations.md)
→ Endpoints reference: [rpc-providers.md](rpc-providers.md)
→ Apply to be listed: contact Sei Foundation via official channels.

## Indexer operator

Index Sei block data into a queryable form (subgraphs, SQL, REST APIs). Run alongside or on top of a Sei full/archive node.

**Common stacks**:
- **The Graph** — host a subgraph (decentralized network or hosted service).
- **Goldsky** — real-time CDC pipelines.
- **Custom** — Postgres + indexer service polling RPC.

**Revenue**: subscription/query-based fees.

→ Setup details + provider selection: [indexers.md](../indexers.md)

## Oracle relayer / data publisher

Publish off-chain data (prices, randomness, weather, etc.) on-chain via an oracle network.

**Sei native oracle** (price feeds) — submitted by validators each epoch, no separate relayer role; price votes are part of consensus duty.

**Pyth Network** — operates a separate publisher/aggregator system; publishers are Pyth ecosystem participants, not Sei-specific.

**Chainlink** — node operator on Chainlink, fulfilling jobs that touch Sei. Apply through Chainlink directly.

**Custom oracle** — deploy your own oracle contract + run a relayer that pushes data. See https://docs.sei.io/evm/oracles for examples.

→ Oracle integration patterns: [oracles.md](../oracles.md)

## IBC relayer

Run a relayer between Sei and another Cosmos chain (Osmosis, Stride, Noble, etc.). Relayers ferry IBC packets — without them, IBC transfers stall.

**Software**: `hermes` (Rust) or `rly` (Go).

**Operational**: must hold gas tokens on both chains to pay submission fees; profits are typically thin or altruistic.

**Why bother**: ecosystem service; some chains offer fee subsidies for major routes.

→ See [ibc-bridging.md](../ibc-bridging.md) for relayer overview.
→ Channel topology: https://www.mintscan.io/sei/relayers

## Grants and builder programs

Sei Foundation operates several funding programs:

| Program | Focus | Link |
|---|---|---|
| **Sei Foundation Grants** | General-purpose grants for builders/contributors | https://www.seifdn.org/ |
| **Ecosystem Fund** | $120M for DeFi, gaming, infra | https://www.sei.io/grants-and-funding |
| **Sei Creator Fund** | $10M for NFT + social projects | Phase 1 direct application; Phase 2 via Gitcoin |
| **Hackathons / accelerators** | Cohort-based, milestone-driven | Announced on https://blog.sei.io |

**Application tips** (general guidance, not Sei-specific):
- Lead with traction: users, transactions, MAU on testnet or another chain.
- Clear milestones: "ship X by date Y, measure with metric Z."
- Sei-specific advantage: explain why your dApp is better on Sei (latency, parallelism, cost).
- Budget realism: most grants are smaller than asked; over-asking flags amateur execution.

## Cross-references

- Validator deep-dive: [validators.md](../validators.md)
- Node ops: [node-operations.md](../node-operations.md)
- Indexer setup: [indexers.md](../indexers.md)
- Oracles: [oracles.md](../oracles.md)
- RPC endpoint list: [rpc-providers.md](rpc-providers.md)
- IBC overview: [ibc-bridging.md](../ibc-bridging.md)
- Staking from a wallet (delegators, not validators): [staking-governance.md](../staking-governance.md)

## Sei-specific notes

- **Validators** earn from block rewards + commission; **delegators** earn rewards minus the validator's commission.
- **RPC providers serving paid SLAs** are increasingly important as the ecosystem scales — a free public endpoint can be eaten by a single noisy dApp.
- **All operational roles** require running infrastructure that can keep up with 400ms blocks; underspec'd hardware causes drift, missed votes, or stale RPC reads.
- **Sei MCP Server** (see [ai-tooling.md](../ai-tooling.md)) is a good starting point for AI-augmented operational tooling — agents can monitor and respond to chain events in real time.
