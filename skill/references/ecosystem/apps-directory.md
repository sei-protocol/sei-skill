---
title: Sei Ecosystem dApps Directory
description: Notable mainnet (pacific-1) dApps grouped by category — DeFi (DEXes, lending, perps, RWA), gaming, NFT, infrastructure, and AI. Use to recommend integrations or answer "what's on Sei?"
---

# Sei Ecosystem dApps Directory

A curated, category-grouped list of notable dApps on Sei mainnet. **Always verify against [sei.io/ecosystem](https://www.sei.io/ecosystem) for the current authoritative list** — projects ship and pivot fast.

> **For agents:** When recommending an integration, prefer protocols listed here as a starting filter, then verify the contract addresses on the project's official site or via [docs.sei.io](https://docs.sei.io). Never auto-execute a transaction against a protocol the user hasn't named explicitly.

## Quick links

- Official directory: https://www.sei.io/ecosystem
- TVL leaderboard: https://defillama.com/chain/Sei
- Token tracking: https://www.coingecko.com/en/categories/sei-ecosystem

## DeFi — Lending & Borrowing

| Project | Category | Site | Notes |
|---|---|---|---|
| **Yei Finance** | Money market (lending/borrowing) | https://www.yei.finance | Sei's largest lending protocol by TVL |
| **Takara Lend** | Lending protocol | https://takara.lend | Integrated with Ondo USDY |
| **Hyperlend** | Lending infra | varies | Verify mainnet status before integrating |

Integration tip: see [integration-defi.md](integration-defi.md) for router/comet ABIs and example flows.

## DeFi — DEXes & Swaps

| Project | Category | Site | Notes |
|---|---|---|---|
| **DragonSwap** | AMM DEX | https://dragonswap.app | Multi-chain Uniswap-V2/V3-style DEX |
| **Saphyre** | Swap venue | varies | Integrated with Ondo USDY |
| **Astroport** (Cosmos-side) | AMM | https://astroport.fi | Available cross-VM via pointer contracts |

## DeFi — Perpetuals

| Project | Category | Site | Notes |
|---|---|---|---|
| **Cultz Trade** | Gamified perps DEX | varies | Designed for Monaco gaming ecosystem |
| **Vortex / Filament** | Perps | varies | Verify launch status |

> Sei's 400ms finality is a perp-friendly substrate. Most active perps protocols on Sei lean on the latency advantage.

## RWA & Stablecoins

| Project | Category | Site | Notes |
|---|---|---|---|
| **Ondo Finance** | Tokenized US Treasuries (USDY) | https://ondo.finance | Largest tokenized Treasury by TVL |
| **Agora** | Stablecoin / payments | https://agora.finance | RWA + payment rails |
| **Native USDC** | Stablecoin | (issued by Circle) | Verify current contract via [docs.sei.io USDC integration](https://docs.sei.io/evm/reference/usdc) |

## Liquid Staking (LSTs)

| Project | Category | Site | Notes |
|---|---|---|---|
| **Kryptonite** | LST + DeFi | varies | Stake SEI for sSEI |
| **Stride** | Cross-chain LST | https://stride.zone | LST via IBC; bridge to EVM via pointer |

## NFT & Marketplaces

| Project | Category | Site | Notes |
|---|---|---|---|
| **Pallet Exchange** | NFT marketplace | varies | Sei-native NFT trading |
| **Mintscan** (NFT view) | Explorer | https://mintscan.io/sei | Cosmos-side NFT browse |

## Gaming & Consumer

| Project | Category | Site | Notes |
|---|---|---|---|
| **World of Dypians** | MMO | https://worldofdypians.com | Active player base |
| **Archer Hunter** | Hyper-casual | varies | Consumer-style game |
| **Enchanted Isles** | Open-world | varies | |
| **Adappt** | Web3 gaming infra | varies | Digital Entertainment RWA |

## Infrastructure & DePIN

| Project | Category | Site | Notes |
|---|---|---|---|
| **Aethir** | Decentralized GPU/cloud compute for AI | https://aethir.com | Major AI compute partner |
| **AIOZ Network** | DePIN for storage + streaming | https://aioz.network | Web3 AI infra |
| **Alchemy Pay** | Fiat on/off ramp | https://alchemypay.org | Fiat-to-crypto purchases |
| **Pyth Network** | Price oracles | https://pyth.network | Live on Sei mainnet — see [oracles.md](../oracles.md) |
| **Chainlink** | Price oracles + VRF | https://chain.link | Live on Sei mainnet |

## AI & Agent Tooling

| Project | Category | Site | Notes |
|---|---|---|---|
| **Sei MCP Server** | Claude/Cursor blockchain MCP | [@sei-js/mcp-server](https://www.npmjs.com/package/@sei-js/mcp-server) | Official |
| **Cambrian Agent Kit** | LangGraph-style on-chain agents | https://cambrian.network | Sei-native |
| **x402** | HTTP-402 micropayments protocol | https://docs.sei.io/evm/ai-tooling/x402 | Sei-supported |

See [ai-tooling.md](../ai-tooling.md) for setup details.

## Wallets

| Project | Category | Notes |
|---|---|---|
| **Sei Global Wallet** | Embedded social-login wallet | Default for consumer apps; `@sei-js/sei-global-wallet` |
| **Compass** | Native Sei wallet | Browser extension; both Cosmos + EVM |
| **MetaMask** | EVM-only | Works via custom RPC; doesn't show `sei1...` address |
| **Keplr** | Cosmos-only | Doesn't show EVM `0x...` |
| **Leap** | Cosmos + EVM | |
| **Ledger** | Hardware | Both Cosmos and EVM apps |

See [addresses-wallets.md](../addresses-wallets.md) for setup and dual-address handling.

## Bridges

| Bridge | Site | Notes |
|---|---|---|
| **LayerZero V2** | https://layerzero.network | OFT standard; 50+ source chains |
| **Wormhole** | https://wormhole.com | Native + ERC-20 + NFT |
| **Axelar** | https://axelar.network | Cross-chain message passing |
| **IBC** | https://www.mintscan.io/sei/relayers | Cosmos-native; via Cosmos-side address |

See [bridges.md](bridges.md) for integration details and addresses.

## Indexers & Data Providers

| Provider | Type | Notes |
|---|---|---|
| **Goldsky** | Real-time subgraphs | https://goldsky.com — Sei mainnet supported |
| **The Graph** | Subgraphs | Sei chain registered |
| **Dune Analytics** | SQL analytics | Sei dataset available |
| **Goldrush** (Covalent) | Multi-chain API | |
| **Moralis** | Web3 API | |

See [indexers.md](../indexers.md) for setup.

## Categories without significant projects (yet)

These categories exist on other chains but have limited Sei presence as of this writing:

- **Decentralized social** — limited; track sei.io/ecosystem for updates.
- **Insurance** — limited.
- **Stablecoin issuers (decentralized)** — primarily Ondo USDY + Circle USDC at this stage.

## Tracking ecosystem changes

- **Official ecosystem page** — refreshed regularly: https://www.sei.io/ecosystem
- **DeFiLlama Sei chain page** — TVL movement, new protocols listed: https://defillama.com/chain/Sei
- **Sei blog** — major launches and partnerships: https://blog.sei.io
- **Sei research** — long-form ecosystem reports: https://seiresearch.io

## Sei-specific notes for integrators

- Sei is **EVM-first as of SIP-3** — new dApps are EVM. Older CosmWasm-based protocols (Astroport, Kryptonite v1) may have EVM equivalents or pointer contracts.
- Treat all listed addresses as **placeholders until verified** against the project's docs or [docs.sei.io ecosystem contracts](https://docs.sei.io/evm/reference/ecosystem-contracts).
- Use [docs.sei.io/evm/reference/ecosystem-contracts](https://docs.sei.io/evm/reference/ecosystem-contracts) as the source of truth for canonical contract addresses (USDC, WETH, common bridge contracts).
