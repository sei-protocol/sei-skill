---
title: Sei Official Websites Map
description: Map of sei.io and docs.sei.io content — which page lives at which URL — so an agent can route a user to the right official resource instead of guessing.
---

# Sei Official Websites Map

Where to send a user when they ask about Sei. Two primary properties:

- **https://www.sei.io** — marketing, ecosystem, media, institutional, blog, research.
- **https://docs.sei.io** — technical documentation (developer, node operator, validator).

Plus secondary properties: https://blog.sei.io (blog), https://seiresearch.io (research), https://www.seifdn.org (Foundation), https://dashboard.sei.io (chain dashboard), https://seiscan.io (block explorer).

## sei.io top-level navigation

| Path | Section | Use when... |
|---|---|---|
| `/` | Home | Marketing landing |
| `/developers` | Developers | Quick links to docs, GitHub, dev tools |
| `/ecosystem` | Ecosystem | dApps directory, partners, integrations |
| `/media` | Media / Press | Brand kit, logo download, press kit |
| `/institutions` | Institutions | Institutional staking, custody, enterprise |
| `/grants-and-funding` | Grants | Foundation grant programs, ecosystem fund |
| `/blog` (redirects to blog.sei.io) | Blog | Announcements, partnerships, ecosystem updates |
| `/brand` (or `/media`) | Brand | Logo, colors, typography (verify path) |

External linked from sei.io:
- https://blog.sei.io — official blog
- https://seiresearch.io — research portal
- https://www.seifdn.org — Sei Foundation
- https://dashboard.sei.io — chain dashboard
- https://seiscan.io — primary block explorer

## docs.sei.io structure

Four top-level sections.

### `/learn` — concepts and protocol fundamentals
- About Sei, User Quickstart, Chain Info, Token Standards, Gas, Account Linking
- Architecture: Twin Turbo Consensus, Parallelization Engine (OCC), SeiDB
- Network Tools: Wallets, **RPC Providers** (`/learn/rpc-providers`), Block Explorers, Faucet, Indexers, Oracles
- Governance: Overview, Proposals, Staking
- Interoperability: EVM ↔ CosmWasm, Pointer Contracts
- **Sei Giga Upgrade**: Overview, Technical Specs, Developer Guide
- Resources: Hardware Wallets, Ledger Setup, **Brand Kit** (`/learn/general-brand-kit`)
- **SIP-03 Migration** (CosmWasm → EVM-only)

### `/evm` — EVM development (largest section)
- Essentials: Network Info, Ethereum Divergence, Migration Guides
- seid CLI: Installation, Querying, Transactions, Changelog
- Frontend: Sei Global Wallet, Building Frontends, In-App Swaps
- Smart Contracts: Hardhat, Foundry, **Contract Verification**, Wizard, Solidity Resources, Best Practices, Debugging, Tracing
- **Precompiles**: nested directory — CosmWasm, Distribution, Governance, Staking, Oracle, JSON, P256, Address, Bank, IBC, PointerView
- sei-js Library (`/evm/sei-js`) — SDK docs
- Indexer Providers: Dune, GoldRush, Goldsky, Moralis, The Graph
- Wallet Integrations: Particle, Pimlico, Thirdweb
- Bridging: LayerZero V2, Thirdweb
- Oracles & VRF: API3, Chainlink, Pyth, RedStone, Pyth VRF
- AI Tooling: Cambrian Agent Kit, **MCP Server**, Agentic Wallets, x402 Protocol
- Reference: RPC, Tokens, **Ecosystem Contracts** (`/evm/reference/ecosystem-contracts`), Networks, USDC Integration, Ledger Setup

### `/cosmos-sdk` — Cosmos-side development
- **Status**: deprecated per SIP-03 — migrate to EVM-only
- Minimal new content; legacy reference only

### `/node` — Node operators and validators
- Node Operations: Overview, Seictl Setup, **StateSync**, **Snapshot Sync**, Node Types, Troubleshooting, API Configuration, Validator Operations
- Advanced: Configuration & Monitoring, RocksDB Backend, Technical Reference

## Common "where do I go for X" answers

| User asks... | Send them to... |
|---|---|
| "What is Sei?" | https://www.sei.io |
| "Show me dApps on Sei" | https://www.sei.io/ecosystem |
| "I want to apply for a grant" | https://www.sei.io/grants-and-funding |
| "I need the Sei logo" | https://docs.sei.io/learn/general-brand-kit (or sei.io/media) |
| "How do I deploy a contract on Sei?" | https://docs.sei.io/evm/smart-contracts |
| "What's the Sei testnet faucet?" | https://atlantic-2.app.sei.io/faucet |
| "Which RPC endpoints can I use?" | https://docs.sei.io/learn/rpc-providers |
| "How do I run a Sei node?" | https://docs.sei.io/node |
| "How do precompiles work?" | https://docs.sei.io/evm/precompiles |
| "How do I bridge to Sei?" | https://docs.sei.io/evm/bridging |
| "Where's the Sei blog?" | https://blog.sei.io |
| "Where's research?" | https://seiresearch.io |
| "Where do I track Sei chain stats?" | https://dashboard.sei.io |
| "Block explorer?" | https://seiscan.io |

## Sei docs build/repo

- **Repository**: https://github.com/sei-protocol/sei-docs (despite the `-old` suffix used by some tooling, this is the live source)
- **Framework**: Nextra (Next.js)
- **Build tool**: Bun
- **Format**: `.mdx` (Markdown + JSX) under `/content/`
- **Nav config**: `_meta.js` files at each directory level
- **Style guide**: `/STYLE_GUIDE.mdx` in the repo

For contributing to the docs, see [docs-contributing.md](docs-contributing.md).

## Machine-readable site maps

- **Sitemap (XML)**: https://docs.sei.io/sitemap.xml (index) → https://docs.sei.io/sitemap-0.xml (URLs)
- **LLM nav guide**: https://docs.sei.io/llms.txt — a structured plain-text index of all main sections, child pages, and core specs (chain IDs, RPC endpoints). Useful for agents that need to ground their answers.

> When an agent is asked to answer a Sei question, fetching `https://docs.sei.io/llms.txt` first is a fast way to confirm current section names and URLs without crawling.

## Search

docs.sei.io has on-site search powered by Pagefind. For programmatic search, use site search via Google with `site:docs.sei.io <query>` or fetch `llms.txt` for the structured nav.

## Sei-specific notes

- The `sei-docs-old` repo name on GitHub is misleading — that **is** the current docs source despite the suffix.
- Older content was in `/cosmos-sdk` — that section is now deprecated per SIP-03; new contributions should go to `/evm` or `/learn`.
- Fast-changing pages (RPC providers, ecosystem contracts) — re-fetch when you need a current address rather than relying on a memory of last week's content.
- Routes change occasionally; if a path 404s, check the sitemap.
