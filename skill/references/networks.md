---
title: Sei Networks & Endpoints
description: Network information for Sei mainnet and testnet — chain IDs, RPC endpoints, explorers, faucet, and wallet configuration.
---

# Sei Networks & Endpoints

## Network Quick Reference

| Property | Mainnet (pacific-1) | Testnet (atlantic-2) |
|---|---|---|
| Cosmos Chain ID | `pacific-1` | `atlantic-2` |
| EVM Chain ID | `1329` | `1328` |
| EVM RPC | `https://evm-rpc.sei-apis.com` | `https://evm-rpc-testnet.sei-apis.com` |
| Cosmos RPC | `https://rpc.sei-apis.com` | `https://rpc-testnet.sei-apis.com` |
| REST/LCD | `https://rest.sei-apis.com` | `https://rest-testnet.sei-apis.com` |
| gRPC | `https://grpc.sei-apis.com` | `https://grpc-testnet.sei-apis.com` |
| WebSocket (EVM) | `wss://evm-ws.sei-apis.com` | `wss://evm-ws-testnet.sei-apis.com` |
| Explorer | https://seitrace.com | https://seitrace.com/?chain=atlantic-2 |
| Faucet | N/A | https://atlantic-2.app.jellyfish.finance/faucet |

> **Default: always use testnet** unless the user explicitly requests mainnet.

## RPC Provider Ecosystem

Multiple third-party providers offer Sei RPC access with additional features (rate limits, websockets, archive access):

- **sei-apis.com** — official endpoints above
- **Alchemy** — enterprise-grade, EVM archive access
- **QuickNode** — EVM + Cosmos, WebSocket support
- **Ankr** — public free tier available
- **DRPC** — decentralized routing

For production dApps, use a provider account rather than the public endpoints.

## Chain IDs Reference

```javascript
// Viem chain definitions — use @sei-js/evm for pre-built definitions
import { seiMainnet, seiTestnet } from '@sei-js/evm';

// Or define manually:
const seiTestnet = {
  id: 1328,
  name: 'Sei Testnet',
  network: 'atlantic-2',
  nativeCurrency: { name: 'SEI', symbol: 'SEI', decimals: 18 },
  rpcUrls: {
    default: { http: ['https://evm-rpc-testnet.sei-apis.com'] },
  },
  blockExplorers: {
    default: { name: 'Seitrace', url: 'https://seitrace.com/?chain=atlantic-2' },
  },
};

const seiMainnet = {
  id: 1329,
  name: 'Sei',
  network: 'pacific-1',
  nativeCurrency: { name: 'SEI', symbol: 'SEI', decimals: 18 },
  rpcUrls: {
    default: { http: ['https://evm-rpc.sei-apis.com'] },
  },
  blockExplorers: {
    default: { name: 'Seitrace', url: 'https://seitrace.com' },
  },
};
```

## Add Sei to MetaMask / Rabby

To manually add Sei to MetaMask:

1. Open MetaMask → Add Network → Add a network manually
2. Fill in:
   - **Network name**: Sei (or Sei Testnet)
   - **New RPC URL**: `https://evm-rpc.sei-apis.com` (or testnet URL)
   - **Chain ID**: `1329` (or `1328`)
   - **Currency symbol**: `SEI`
   - **Block explorer URL**: `https://seitrace.com`

## `seid` CLI Network Flags

```bash
# Cosmos-side queries/transactions
seid query bank balances sei1... \
  --node https://rpc.sei-apis.com \
  --chain-id pacific-1

# Testnet
seid tx bank send <from> <to> 1000000usei \
  --node https://rpc-testnet.sei-apis.com \
  --chain-id atlantic-2 \
  --fees 2000usei

# EVM RPC queries via seid
seid q evm params --node https://rpc.sei-apis.com
```

## Testnet Faucet

Get testnet SEI for development:

```bash
# Via Jellyfish Finance faucet UI
# https://atlantic-2.app.jellyfish.finance/faucet
# Connect wallet or enter EVM address — receive test SEI within seconds
```

## Gas Configuration

```bash
# Minimum gas price for legacy (type-0) transactions: 10 gwei
# Use gasPrice, NOT maxFeePerGas/maxPriorityFeePerGas

# Example with ethers.js v6
const tx = await signer.sendTransaction({
  to: recipient,
  value: parseEther("1.0"),
  gasPrice: parseUnits("10", "gwei"),  // minimum; set higher under load
});
```

## Block Explorer — Seitrace

- Mainnet: https://seitrace.com
- Testnet: https://seitrace.com/?chain=atlantic-2

Features: EVM transaction tracing, contract verification, token holders, internal transactions, Cosmos/EVM dual view per address.

Contract verification via Seitrace is required before most DeFi integrations will list your token/protocol.
