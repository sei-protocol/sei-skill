---
title: Sei Developer Resources
description: Curated reference links for Sei development — official docs, tools, explorers, faucets, GitHub repos, community channels, and ecosystem protocols.
---

# Sei Developer Resources

## Official Documentation

| Resource | URL |
|---|---|
| Developer Docs | https://docs.sei.io |
| Sei Labs | https://seilabs.io |
| Sei Website | https://sei.io |
| Sei Blog | https://blog.sei.io |
| Ecosystem Contracts | https://docs.sei.io/evm/ecosystem-contracts |

## Source Code

| Repo | Description |
|---|---|
| sei-chain | Core Cosmos SDK chain + OCC engine: https://github.com/sei-protocol/sei-chain |
| sei-js | JavaScript/TypeScript SDK: https://github.com/sei-protocol/sei-js |
| sei-docs | Documentation source: https://github.com/sei-protocol/sei-docs |

## Networks and RPC

| Network | Chain ID | EVM RPC | Cosmos RPC |
|---|---|---|---|
| Mainnet (pacific-1) | 1329 | https://evm-rpc.sei-apis.com | https://rpc.sei-apis.com |
| Testnet (atlantic-2) | 1328 | https://evm-rpc-testnet.sei-apis.com | https://rpc-testnet.sei-apis.com |

Additional RPC providers: https://docs.sei.io/learn/rpc-providers

## Explorers

| Explorer | URL |
|---|---|
| Seitrace (primary) | https://seitrace.com |
| Seiscan | https://seiscan.app |
| Mintscan | https://www.mintscan.io/sei |

## Faucets

| Network | Faucet |
|---|---|
| Testnet (atlantic-2) | https://atlantic-2.app.sei.io/faucet |
| Testnet Discord | https://discord.gg/sei |

## Developer Tools

### Smart Contract Development

| Tool | URL |
|---|---|
| Foundry | https://book.getfoundry.sh |
| Hardhat | https://hardhat.org |
| OpenZeppelin Contracts | https://github.com/OpenZeppelin/openzeppelin-contracts |
| Seitrace (block explorer + verification) | https://seitrace.com |

### Frontend

| Tool | URL |
|---|---|
| @sei-js/evm (chain config + precompile ABIs) | https://www.npmjs.com/package/@sei-js/evm |
| @sei-js/sei-global-wallet | https://www.npmjs.com/package/@sei-js/sei-global-wallet |
| @sei-js/create-sei (scaffolding) | https://www.npmjs.com/package/@sei-js/create-sei |
| Wagmi | https://wagmi.sh |
| Viem | https://viem.sh |
| Ethers.js | https://docs.ethers.org/v6 |
| RainbowKit | https://www.rainbowkit.com |

### AI / Agents

| Tool | URL |
|---|---|
| Sei MCP Server | `npx @sei-js/mcp-server` — https://www.npmjs.com/package/@sei-js/mcp-server |
| Cambrian Agent Kit | https://www.npmjs.com/package/@cambrian/sei-agent-kit |

## Oracles

| Oracle | Docs |
|---|---|
| Pyth Network | https://docs.pyth.network |
| Chainlink | https://docs.chain.link/data-feeds/price-feeds/addresses |
| API3 | https://market.api3.org |
| RedStone | https://docs.redstone.finance |

## Bridges and Interoperability

| Bridge | Docs |
|---|---|
| IBC channels | https://seitrace.com (Relayers tab) or https://www.mintscan.io/sei/relayers |
| LayerZero | https://layerzero.network |
| ThirdWeb Bridge | https://portal.thirdweb.com/connect/blockchain-api |

## Indexers

| Indexer | URL |
|---|---|
| The Graph | https://thegraph.com |
| Goldsky | https://goldsky.com |
| Dune Analytics (Sei dataset) | https://dune.com |
| Moralis | https://moralis.io |
| Goldrush (Covalent) | https://goldrush.dev |

## Wallets

| Wallet | URL |
|---|---|
| Sei Global Wallet (social login) | https://docs.sei.io/evm/sei-global-wallet |
| Compass Wallet | https://compasswallet.io |
| MetaMask | https://metamask.io |
| Ledger + Sei | https://docs.sei.io/learn/ledger-setup |

## Governance and Staking

| Resource | URL |
|---|---|
| Sei App (stake, vote) | https://app.sei.io/stake |
| Sei App (governance) | https://app.sei.io/governance |
| Active governance proposals | `seid q gov proposals --status voting_period` |

## Node Operations

| Resource | URL |
|---|---|
| Polkachu snapshots | https://polkachu.com/tendermint_snapshots/sei |
| NodeJumper | https://nodejumper.io/sei |
| State sync (testnet) | https://rpc-testnet.sei-apis.com |

## Community and Support

| Channel | URL |
|---|---|
| Discord | https://discord.gg/sei |
| Telegram (Tech Chat) | https://t.me/+KZdhZ1eE-G01NmZk |
| X / Twitter | https://x.com/SeiNetwork |
| Developer Forum | https://forum.sei.io |

## Sei Architecture

| Resource | Description |
|---|---|
| Twin Turbo Consensus | https://docs.sei.io/learn/twin-turbo-consensus |
| OCC Parallelization | https://docs.sei.io/learn/parallelization-engine |
| SeiDB | https://docs.sei.io/learn/seidb |
| Sei Giga Specs | https://docs.sei.io/learn/sei-giga-specs |
| SIP-3 (CosmWasm deprecation) | https://docs.sei.io/learn/sip-03-migration |

## Sei-Specific Contract Addresses

| Contract | Mainnet | Testnet |
|---|---|---|
| Bank precompile | `0x0000000000000000000000000000000000001001` | same |
| Addr precompile | `0x0000000000000000000000000000000000001004` | same |
| Staking precompile | `0x0000000000000000000000000000000000001005` | same |
| Governance precompile | `0x0000000000000000000000000000000000001006` | same |
| Oracle precompile | `0x0000000000000000000000000000000000001008` | same |
| IBC precompile | `0x0000000000000000000000000000000000001009` | same |
| Multicall3 | `0xcA11bde05977b3631167028862bE2a173976CA11` | same |
| Permit2 | `0xB952578f3520EE8Ea45b7914994dcf4702cEe578` | same |
| USDC | `0xe15fC38F6D8c56aF07bbCBe3BAf5708A2Bf42392` | `0x4fCF1784B31630811181f670Aea7A7bEF803eaED` |

Full precompile table: [`precompiles/overview.md`](./precompiles/overview.md)
