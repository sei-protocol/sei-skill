# Sei Skill

A comprehensive AI skill for the Sei Network, covering three domains: **contracts** (smart contracts and tooling), **frontend** (UI stack and Sei site awareness), and **ecosystem** (apps, integrations, participation roles).

## Overview

This skill provides AI coding assistants with deep knowledge of the Sei ecosystem across three domains:

### Contracts — smart contracts and tooling
- **EVM Contracts**: Foundry + Hardhat setup, deployment, fork testing
- **Precompiles**: All 11 Sei precompiles (Staking, Governance, Bank, Addr, Oracle, IBC, Pointer, P256, etc.)
- **Pointer Contracts**: Cross-VM asset bridging between EVM and Cosmos
- **Verification**: Seitrace verification flows for Foundry and Hardhat
- **Performance**: Load testing, OCC-aware design, Sei-specific gas optimization
- **Account abstraction (ERC-4337)**: Pimlico, Particle, smart-account flows
- **Upgradeability**: UUPS, Transparent, Beacon, Diamond
- **Migration**: From Ethereum/other EVMs and from Solana

### Frontend — UI stack and site awareness
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

The skill ships in four flavours. **Running `./install.sh` with no arguments installs the full skill** — the recommended default that covers all three domains.

### Quick Install (full skill)

```bash
npx skills add sei
```

### Manual Install (full skill — default)

```bash
git clone https://github.com/sei-protocol/sei-skill
cd sei-skill
./install.sh
```

That installs the full skill to `~/.claude/skills/sei`. No flags needed.

### Variants

Install one of the focused variants when you only need a subset of Sei's coverage. The full reference tree ships with every install — variants only swap the entry-point `SKILL.md` to scope the skill's description, operating procedure, and progressive-disclosure links to one domain.

| Variant | Skill name | Install path | Best for |
|---|---|---|---|
| **full** (default) | `sei` | `~/.claude/skills/sei` | Comprehensive coverage; one skill triggers across all three domains |
| `contracts` / `sei-contracts` | `sei-contracts` | `~/.claude/skills/sei-contracts` | Smart-contract teams — skips frontend/ecosystem trigger surface |
| `frontend` / `sei-frontend` | `sei-frontend` | `~/.claude/skills/sei-frontend` | Frontend / UI teams (incl. Sei web-property awareness) |
| `ecosystem` / `sei-ecosystem` | `sei-ecosystem` | `~/.claude/skills/sei-ecosystem` | Integration / infra / participation focus |

```bash
./install.sh                                   # full (default)
./install.sh --variant contracts               # contracts-only — short alias
./install.sh --name sei-contracts              # contracts-only — by skill name
./install.sh --variant frontend                # frontend-only
./install.sh --variant ecosystem               # ecosystem-only
./install.sh --variant contracts --project     # contracts variant in current project's .claude/
./install.sh --path /tmp/sei-test              # custom path (overrides naming)
```

Both `--variant` and `--name` accept either the short alias (`contracts`, `frontend`, `ecosystem`) or the actual skill name (`sei-contracts`, `sei-frontend`, `sei-ecosystem`). The two flags are interchangeable.

You can install several variants simultaneously — they have distinct `name:` fields and live under different install paths.

> **Upgrading from `sei-dev` (the old single-skill name)?** This skill was renamed `sei-dev` → `sei` to reflect its broader scope. The dev-focused variant is now `sei-contracts` (formerly `sei-dev`) and the UI-focused variant is `sei-frontend` (formerly `sei-website`). Install the `full` skill for broader coverage, or pick one of the variants. Remove `~/.claude/skills/sei-dev` before installing if you previously had the legacy version.

## Skill Structure

References are organised into three domain folders (`contracts/`, `frontend/`, `ecosystem/`) plus a small set of cross-cutting foundational files at the references root.

```
skill/
├── SKILL.md                              # Main skill definition (3-domain index)
├── SKILL-CONTRACTS.md                    # Contracts variant entry point
├── SKILL-FRONTEND.md                     # Frontend variant entry point
├── SKILL-ECOSYSTEM.md                    # Ecosystem variant entry point
└── references/
    ├── architecture.md                   # Twin Turbo, OCC, SeiDB, Sei Giga
    ├── networks.md                       # Chain IDs, RPC URLs, explorers, faucet
    ├── addresses-wallets.md              # Dual address system, wallets, HD paths
    ├── resources.md                      # Curated reference links
    │
    ├── contracts/                        # ── Domain: Contracts ──────────────────
    │   ├── contract-verification.md      # Seitrace verification (Foundry + Hardhat)
    │   ├── performance-testing.md        # Load testing, OCC scheduler benchmarking
    │   ├── occ-aware-design.md           # Parallelization-friendly storage layouts
    │   ├── gas-optimization-sei.md       # SSTORE costs, calldata, multicall
    │   ├── account-abstraction.md        # ERC-4337 with Pimlico, Particle
    │   ├── upgradeability.md             # UUPS, Transparent, Beacon, Diamond
    │   ├── tokens.md                     # SEI denominations, ERC standards, TokenFactory
    │   ├── security.md                   # Sei-specific + standard Solidity checklist
    │   └── common-errors.md              # Error → cause → solution
    │
    ├── evm/                              # EVM smart contracts (contracts-domain)
    │   ├── overview.md
    │   ├── hardhat.md
    │   ├── foundry.md
    │   ├── testing.md
    │   └── best-practices.md
    │
    ├── precompiles/                      # Sei precompiles (contracts-domain)
    │   ├── overview.md
    │   ├── staking-distribution.md
    │   ├── governance.md
    │   ├── json-p256.md
    │   └── cosmwasm-bridge.md
    │
    ├── pointers/                         # Cross-VM bridging (contracts-domain)
    │   ├── overview.md
    │   └── token-factory.md
    │
    ├── migration/                        # Migration guides (contracts-domain)
    │   ├── from-ethereum.md
    │   └── from-solana.md
    │
    ├── frontend/                         # ── Domain: Frontend ───────────────────
    │   ├── frontend-stack.md             # Wagmi/Viem, sei-js, EIP-6963, dual-address UX
    │   ├── sites-map.md                  # sei.io / docs.sei.io page index
    │   ├── docs-contributing.md          # Nextra + MDX contribution guide
    │   └── branding-media.md             # Brand kit, logos, press
    │
    └── ecosystem/                        # ── Domain: Ecosystem ──────────────────
        ├── apps-directory.md             # dApps grouped by category
        ├── integration-defi.md           # DEX/lending integration patterns
        ├── bridges.md                    # LayerZero, Wormhole, Axelar, IBC, CCTP
        ├── ibc-bridging.md               # IBC + legacy bridging deep dive
        ├── rpc-providers.md              # Public + paid RPC endpoints
        ├── rpc-agent-skills.md           # 17 canonical RPC skills, retry, response shapes
        ├── oracles.md                    # Chainlink, Pyth, API3, RedStone, VRF
        ├── indexers.md                   # The Graph, Dune, Goldsky, Moralis, Goldrush
        ├── node-operations.md            # Node setup, sync, snapshots, seictl
        ├── validators.md                 # Key management, HSM, jailing, monitoring
        ├── staking-governance.md         # Delegation, unbonding, proposals
        ├── ai-tooling.md                 # Sei MCP Server, Cambrian Agent Kit
        └── participation-roles.md        # Validator, RPC, indexer, oracle, grants
```

## Usage

Once installed, your AI assistant automatically uses this skill when you ask about Sei development. Example prompts:

### Contracts — Smart Contracts
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

### Contracts — Precompiles and Cross-VM
```
"How do I stake SEI from a Solidity contract?"
"Use the governance precompile to vote on a proposal"
"Create a pointer contract for my ERC20 token"
"How does the dual address system work?"
```

### Frontend — UI and Site Awareness
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
5. Run the trigger tests to verify skill triggers correctly:
   ```bash
   cd tests && npm install
   ANTHROPIC_API_KEY=your_key npm test
   ```
6. Open a pull request

## License

MIT — see [LICENSE](LICENSE)
