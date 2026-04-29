# Sei Skill for Claude Code

A comprehensive Claude Code skill for the Sei Network, covering three domains: **dev** (smart contracts and tooling), **website** (frontend stack and Sei site awareness), and **ecosystem** (apps, integrations, participation roles).

## Overview

This skill provides Claude Code with deep knowledge of the Sei ecosystem across three domains:

### Dev — smart contracts and tooling
- **EVM Contracts**: Foundry + Hardhat setup, deployment, fork testing
- **Precompiles**: All 11 Sei precompiles (Staking, Governance, Bank, Addr, Oracle, IBC, Pointer, P256, etc.)
- **Pointer Contracts**: Cross-VM asset bridging between EVM and Cosmos
- **Verification**: Seitrace verification flows for Foundry and Hardhat
- **Performance**: Load testing, OCC-aware design, Sei-specific gas optimization
- **Account abstraction (ERC-4337)**: Pimlico, Particle, smart-account flows
- **Upgradeability**: UUPS, Transparent, Beacon, Diamond
- **Migration**: From Ethereum/other EVMs and from Solana

### Website — frontend stack and site awareness
- **Frontend stack**: Wagmi + Viem default, Ethers.js v6 alternative, RainbowKit
- **Wallets**: Sei Global Wallet, MetaMask, Compass, Ledger; EIP-6963 detection
- **Dual-address UX**: surfacing `sei1...` ↔ `0x...` cleanly
- **sei.io / docs.sei.io map**: pointing users to the right page
- **Docs contribution**: Nextra MDX, `_meta.js`, build flow
- **Brand assets**: logos, media kit, press contacts

### Ecosystem — apps, integration, participation
- **dApps directory**: DEX, lending, perps, RWA, NFT, gaming, infra
- **DeFi integrations**: DragonSwap, Yei, Takara, Saphyre, Pyth oracles, USDC
- **Bridges**: LayerZero V2 (OFT), Wormhole, Axelar, IBC, CCTP, ThirdWeb
- **RPC endpoints**: public, community, paid SaaS providers with failover patterns
- **Oracles**: Chainlink, Pyth (+ VRF), API3, RedStone, native oracle precompile
- **Indexers**: The Graph, Goldsky, Dune Analytics, Moralis, Goldrush
- **Participation roles**: validator, RPC provider, indexer operator, oracle relayer, IBC relayer
- **Grants**: Sei Foundation Grants, Ecosystem Fund, Creator Fund
- **AI Tooling**: Sei MCP Server, Cambrian Agent Kit, x402

## Installation

### Quick Install

```bash
npx skills add sei
```

### Manual Install

```bash
git clone https://github.com/sei-protocol/sei-skill
cd sei-skill
./install.sh
```

> **Upgrading from `sei-dev`?** This skill was renamed from `sei-dev` to `sei` to reflect its broader scope (now covering website, ecosystem, and dev). Remove the old install at `~/.claude/skills/sei-dev` before installing the new version.

## Skill Structure

```
skill/
├── SKILL.md                              # Main skill definition (3-domain index)
└── references/
    ├── architecture.md                   # Twin Turbo, OCC, SeiDB, Sei Giga
    ├── networks.md                       # Chain IDs, RPC URLs, explorers, faucet
    ├── addresses-wallets.md              # Dual address system, wallets, HD paths
    ├── tokens.md                         # SEI denominations, ERC standards, TokenFactory
    ├── ibc-bridging.md                   # IBC, LayerZero, ThirdWeb bridge
    ├── oracles.md                        # Chainlink, Pyth, API3, RedStone, VRF
    ├── indexers.md                       # The Graph, Dune, Goldsky, Moralis, Goldrush
    ├── node-operations.md                # Node setup, sync, snapshots, seictl
    ├── validators.md                     # Key management, HSM, jailing, monitoring
    ├── staking-governance.md             # Delegation, unbonding, proposals
    ├── ai-tooling.md                     # Sei MCP Server, Cambrian Agent Kit
    ├── rpc-agent-skills.md               # 17 canonical RPC skills, retry, response shapes
    ├── common-errors.md                  # Error → cause → solution
    ├── security.md                       # Sei-specific + standard Solidity checklist
    ├── resources.md                      # Curated reference links
    ├── dev/                              # ── Domain: Dev ─────────────────────────
    │   ├── contract-verification.md      # Seitrace verification (Foundry + Hardhat)
    │   ├── performance-testing.md        # Load testing, OCC scheduler benchmarking
    │   ├── occ-aware-design.md           # Parallelization-friendly storage layouts
    │   ├── gas-optimization-sei.md       # SSTORE costs, calldata, multicall
    │   ├── account-abstraction.md        # ERC-4337 with Pimlico, Particle
    │   └── upgradeability.md             # UUPS, Transparent, Beacon, Diamond
    ├── evm/                              # EVM smart contracts
    │   ├── overview.md
    │   ├── hardhat.md
    │   ├── foundry.md
    │   ├── testing.md
    │   └── best-practices.md
    ├── precompiles/                      # Sei precompiles
    │   ├── overview.md
    │   ├── staking-distribution.md
    │   ├── governance.md
    │   ├── json-p256.md
    │   └── cosmwasm-bridge.md
    ├── pointers/                         # Cross-VM bridging
    │   ├── overview.md
    │   └── token-factory.md
    ├── migration/                        # Migration guides
    │   ├── from-ethereum.md
    │   └── from-solana.md
    ├── website/                          # ── Domain: Website ────────────────────
    │   ├── frontend-stack.md             # Wagmi/Viem, sei-js, EIP-6963, dual-address UX
    │   ├── sites-map.md                  # sei.io / docs.sei.io page index
    │   ├── docs-contributing.md          # Nextra + MDX contribution guide
    │   └── branding-media.md             # Brand kit, logos, press
    └── ecosystem/                        # ── Domain: Ecosystem ──────────────────
        ├── apps-directory.md             # dApps grouped by category
        ├── integration-defi.md           # DEX/lending integration patterns
        ├── bridges.md                    # LayerZero, Wormhole, Axelar, IBC, CCTP
        ├── rpc-providers.md              # Public + paid RPC endpoints
        └── participation-roles.md        # Validator, RPC, indexer, oracle, grants
```

## Usage

Once installed, Claude Code automatically uses this skill when you ask about Sei development. Example prompts:

### Dev — Smart Contracts
```
"Deploy a Solidity contract on Sei testnet"
"Why is SSTORE so expensive on Sei testnet?"
"Set up Foundry for Sei"
"How do I verify my contract on Seitrace?"
"Load test my contract against the OCC scheduler"
"Optimize gas for my Sei contract"
"Use ERC-4337 account abstraction on Sei"
"Make my contract upgradeable with UUPS proxy"
```

### Dev — Precompiles and Cross-VM
```
"How do I stake SEI from a Solidity contract?"
"Use the governance precompile to vote on a proposal"
"Create a pointer contract for my ERC20 token"
"How does the dual address system work?"
```

### Website — Frontend and Site Awareness
```
"Set up Wagmi with Sei mainnet and testnet"
"How do I use Sei Global Wallet for social login?"
"Why do I need gasPrice instead of maxFeePerGas on Sei?"
"Display both EVM and Cosmos addresses for a user"
"Where on docs.sei.io is the precompile reference?"
"How do I contribute a page to docs.sei.io?"
"Where is the Sei brand kit?"
```

### Ecosystem — Apps, Integration, Participation
```
"What dApps are live on Sei mainnet?"
"How do I integrate with a Sei DEX?"
"What bridges work with Sei?"
"What are good RPC endpoints for Sei?"
"How do I become a Sei validator?"
"Apply for a Sei Foundation grant"
"Set up a Sei full node with state sync"
"How do I create and register a validator?"
"Submit a governance proposal via CLI"
"Set up the Sei MCP server in Claude Code"
```

### Architecture
```
"Explain Twin Turbo Consensus"
"How does OCC parallel execution work?"
"What is SeiDB?"
"Tell me about Sei Giga"
```

### Migration
```
"I'm migrating my Ethereum dApp to Sei — what do I need to change?"
"Coming from Solana — how do programs map to Solidity contracts?"
"What are the differences between Sei and Ethereum?"
```

## Stack Decisions

| Layer | Default | Alternative |
|---|---|---|
| Smart contracts | **Foundry** | Hardhat |
| Frontend | **Wagmi + Viem** (React) | Ethers.js v6 |
| Wallet | **Sei Global Wallet** + MetaMask | Compass, Ledger |
| Chain config | **@sei-js/evm** | Manual RPC config |
| Randomness | **Pyth VRF** | Chainlink VRF |
| Oracles | **Native precompile** (free) → Pyth (pull) → Chainlink (push) | — |
| Indexers | **The Graph** (custom queries) / **Goldsky** (real-time) | Dune (analytics) |

## Key Technical Facts

Every answer from this skill applies these Sei-specific facts:

1. 400ms block time, **instant finality** → use `tx.wait(1)`
2. **SSTORE gas varies by network**: testnet (atlantic-2) = 72,000 gas; mainnet (pacific-1) = 20,000 gas (governance-adjustable)
3. **Use `gasPrice`** (legacy) — Sei does not support EIP-1559 `maxFeePerGas`
4. **Minimum gas price: 50 gwei**
5. **Block gas limit: 12.5 M** per block
6. `PREVRANDAO` is NOT random — use Pyth VRF or Chainlink VRF
7. `COINBASE` = global fee collector, not block proposer
8. No base fee burn — all fees to validators
9. **Dual address system**: `sei1...` + `0x...` from the same key
10. **CosmWasm deprecated** per SIP-3 — use EVM for new contracts
11. Chain IDs: Mainnet `pacific-1`/`1329`, Testnet `atlantic-2`/`1328`
12. No `safe`/`finalized` block tags — use `latest`

## Relationship to Sei Docs

This skill complements [docs.sei.io](https://docs.sei.io). The official docs are authoritative for the latest protocol changes. This skill is optimized for AI coding assistant consumption — structured for progressive disclosure, with code-first examples and decision trees rather than narrative prose.

## Content Sources

Built from:
- [sei-chain](https://github.com/sei-protocol/sei-chain) — core protocol
- [sei-docs](https://github.com/sei-protocol/sei-docs) — official documentation (Nextra + MDX)
- [seid](https://github.com/sei-protocol/seid) — CLI tooling
- [sei.io](https://www.sei.io) — ecosystem directory and brand assets
- [docs.sei.io/llms.txt](https://docs.sei.io/llms.txt) — LLM-friendly site nav

## Contributing

1. Fork and clone the repository
2. Update the relevant reference file in `skill/references/`
3. If adding a new file, add a link to `skill/SKILL.md` under "Reference Files"
4. Run `./install.sh` to test locally
5. Run `cd tests && npm install && npm test` to verify skill triggers correctly
6. Open a pull request

## License

MIT — see [LICENSE](LICENSE)
