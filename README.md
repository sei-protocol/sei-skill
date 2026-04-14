# Sei Development Skill for Claude Code

A comprehensive Claude Code skill for building on the Sei Network — covering EVM contracts, precompiles, pointer contracts, frontend, wallets, oracles, indexers, node operations, and migration from other chains.

## Overview

This skill provides Claude Code with deep knowledge of the Sei development ecosystem:

- **EVM Contracts**: Foundry + Hardhat setup, deployment, verification, fork testing
- **Precompiles**: All 11 Sei precompiles (Staking, Governance, Bank, Addr, Oracle, IBC, Pointer, P256, etc.)
- **Pointer Contracts**: Cross-VM asset bridging between EVM and Cosmos
- **Frontend**: Wagmi + Viem (React), Ethers.js v6, `@sei-js/evm`, `@sei-js/sei-global-wallet`
- **Oracles**: Chainlink, Pyth (+ VRF), API3, RedStone, native oracle precompile
- **Indexers**: The Graph, Goldsky, Dune Analytics, Moralis, Goldrush
- **Bridging**: IBC, LayerZero OFT, ThirdWeb Bridge
- **AI Tooling**: Sei MCP Server, Cambrian Agent Kit
- **Node Operations**: Full node setup, state sync, SeiDB configuration
- **Migration**: From Ethereum/other EVMs and from Solana

## Installation

### Quick Install

```bash
npx skills add sei-dev
```

### Manual Install

```bash
git clone https://github.com/sei-protocol/sei-dev-skill
cd sei-dev-skill
./install.sh
```

## Skill Structure

```
skill/
├── SKILL.md                              # Main skill definition
└── references/
    ├── architecture.md                   # Twin Turbo, OCC, SeiDB, Sei Giga
    ├── networks.md                       # Chain IDs, RPC URLs, explorers, faucet
    ├── addresses-wallets.md              # Dual address system, wallets, HD paths
    ├── tokens.md                         # SEI denominations, ERC standards, TokenFactory
    ├── frontend.md                       # Ethers.js, Viem, Wagmi, @sei-js SDK
    ├── ibc-bridging.md                   # IBC, LayerZero, ThirdWeb bridge
    ├── oracles.md                        # Chainlink, Pyth, API3, RedStone, VRF
    ├── indexers.md                       # The Graph, Dune, Goldsky, Moralis, Goldrush
    ├── node-operations.md                # Node setup, sync, snapshots, seictl
    ├── validators.md                     # Key management, HSM, jailing, monitoring
    ├── staking-governance.md             # Delegation, unbonding, proposals
    ├── ai-tooling.md                     # Sei MCP Server, Cambrian Agent Kit
    ├── common-errors.md                  # Error → cause → solution
    ├── security.md                       # Sei-specific + standard Solidity checklist
    ├── resources.md                      # Curated reference links
    ├── evm/
    │   ├── overview.md                   # Sei vs Ethereum: opcodes, gas, finality
    │   ├── hardhat.md                    # Hardhat config, deployment, verification
    │   ├── foundry.md                    # Foundry config, forge/cast, verification
    │   ├── testing.md                    # Unit, fork, parallelization-aware testing
    │   └── best-practices.md             # Parallelization patterns, SSTORE, gas
    ├── precompiles/
    │   ├── overview.md                   # Full address table, @sei-js/evm setup
    │   ├── staking-distribution.md       # 0x1005 + 0x1007
    │   ├── governance.md                 # 0x1006, proposals, voting
    │   ├── json-p256.md                  # 0x1003 + 0x1011
    │   └── cosmwasm-bridge.md            # Addr, Bank, CW, IBC, Pointer, PointerView
    ├── pointers/
    │   ├── overview.md                   # Cross-VM asset bridging + registration
    │   └── token-factory.md              # Creating native denoms + pointer workflow
    └── migration/
        ├── from-ethereum.md              # Chain comparison, gotchas, frontend updates
        └── from-solana.md                # Concept mapping, toolchain translation
```

## Usage

Once installed, Claude Code automatically uses this skill when you ask about Sei development. Example prompts:

### Smart Contracts
```
"Deploy a Solidity contract on Sei testnet"
"Why is SSTORE so expensive on Sei testnet?"
"Set up Foundry for Sei"
"Fork test with the Sei testnet"
```

### Precompiles and Cross-VM
```
"How do I stake SEI from a Solidity contract?"
"Use the governance precompile to vote on a proposal"
"Create a pointer contract for my ERC20 token"
"How does the dual address system work?"
```

### Frontend
```
"Set up Wagmi with Sei mainnet and testnet"
"How do I use Sei Global Wallet for social login?"
"Why do I need gasPrice instead of maxFeePerGas on Sei?"
"Display both EVM and Cosmos addresses for a user"
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

### Infrastructure
```
"Set up a Sei full node with state sync"
"How do I create and register a validator?"
"Submit a governance proposal via CLI"
"Set up the Sei MCP server in Claude Code"
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
- [sei-docs](https://github.com/sei-protocol/sei-docs) — official documentation
- [seid](https://github.com/sei-protocol/seid) — CLI tooling

## Contributing

1. Fork and clone the repository
2. Update the relevant reference file in `skill/references/`
3. If adding a new file, add a link to `skill/SKILL.md` under "Reference Files"
4. Run `./install.sh` to test locally
5. Run `cd tests && npm install && npm test` to verify skill triggers correctly
6. Open a pull request

## License

MIT — see [LICENSE](LICENSE)
