---
title: Frontend Development on Sei
description: Build dApps on Sei using Ethers.js, Viem, Wagmi, and the @sei-js SDK. Covers provider setup, wallet connection, contract interaction, and Sei-specific patterns.
---

# Frontend Development on Sei

## Library Decision Matrix

| Library | Best for | Pros | Cons |
|---|---|---|---|
| **Wagmi + Viem** | React dApps | Hooks, auto-refresh, type-safe, EIP-6963 | React-only, opinionated |
| **Ethers.js v6** | Node.js scripts, non-React frontends | Battle-tested, simple API, all-in-one | Larger bundle |
| **Viem** | Custom React/non-React, low-level control | Lightweight, modular, excellent TypeScript | More boilerplate |

**Default recommendation**: Wagmi + Viem for React; Ethers.js v6 for scripts and non-React environments.

## Quick Setup

```bash
# Wagmi + Viem (React)
npm install wagmi viem @tanstack/react-query @sei-js/evm

# Ethers.js (any)
npm install ethers @sei-js/evm

# Sei Global Wallet (optional — add to any stack)
npm install @sei-js/sei-global-wallet
```

## Wagmi Setup (React)

```typescript
// src/wagmi.config.ts
import { createConfig, http } from 'wagmi';
import { seiTestnet, seiMainnet } from '@sei-js/evm';
import { injected, metaMask } from 'wagmi/connectors';

export const config = createConfig({
  chains: [seiTestnet, seiMainnet],
  transports: {
    [seiTestnet.id]: http('https://evm-rpc-testnet.sei-apis.com'),
    [seiMainnet.id]: http('https://evm-rpc.sei-apis.com'),
  },
  connectors: [
    injected(),      // MetaMask, Rabby, and any EIP-6963 wallet (incl. Sei Global Wallet)
    metaMask(),
  ],
});
```

```tsx
// src/App.tsx
import { WagmiProvider } from 'wagmi';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { config } from './wagmi.config';

const queryClient = new QueryClient();

export function App() {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <YourDApp />
      </QueryClientProvider>
    </WagmiProvider>
  );
}
```

```tsx
// Using Wagmi hooks
import { useConnect, useAccount, useBalance, useWriteContract, useReadContract } from 'wagmi';
import { parseEther } from 'viem';
import { seiTestnet } from '@sei-js/evm';

function WalletButton() {
  const { connect, connectors } = useConnect();
  const { address, isConnected } = useAccount();

  if (isConnected) return <p>Connected: {address}</p>;

  return (
    <button onClick={() => connect({ connector: connectors[0], chainId: seiTestnet.id })}>
      Connect Wallet
    </button>
  );
}

function TokenBalance({ contractAddress }: { contractAddress: `0x${string}` }) {
  const { address } = useAccount();
  const { data: balance } = useReadContract({
    address: contractAddress,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: [address!],
  });

  return <p>Balance: {balance?.toString()}</p>;
}
```

## Ethers.js v6 Setup

```typescript
import { ethers } from 'ethers';

// Browser (wallet extension)
const provider = new ethers.BrowserProvider(window.ethereum);
await provider.send("eth_requestAccounts", []);
const signer = await provider.getSigner();
console.log("Connected:", await signer.getAddress());

// Node.js script (private key)
const provider = new ethers.JsonRpcProvider('https://evm-rpc-testnet.sei-apis.com');
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

// Read contract
const contract = new ethers.Contract(contractAddress, abi, provider);
const balance = await contract.balanceOf(userAddress);

// Write transaction — use gasPrice (not EIP-1559 fields)
const tx = await contract.connect(signer).transfer(recipient, amount, {
  gasPrice: ethers.parseUnits("10", "gwei"),  // minimum 10 gwei
});
const receipt = await tx.wait(1);  // 1 confirmation = finality on Sei
```

## Sei Global Wallet Integration

```typescript
// Sei Global Wallet supports social logins (Google, Apple, Twitter, Telegram)
// EIP-6963 compliant — detected automatically by Wagmi's injected() connector
// No special code needed if using Wagmi — just add `injected()` to connectors

// For manual integration:
import '@sei-js/sei-global-wallet'; // side-effect import — registers the wallet provider

// Provider is now available via standard EIP-6963 discovery
// or window.ethereum fallback
```

## @sei-js/evm Utilities

```typescript
import {
  // Chain definitions (viem-compatible)
  seiMainnet,
  seiTestnet,

  // Precompile addresses + ABIs
  STAKING_PRECOMPILE_ADDRESS,
  STAKING_PRECOMPILE_ABI,
  GOVERNANCE_PRECOMPILE_ADDRESS,
  GOVERNANCE_PRECOMPILE_ABI,
  ADDR_PRECOMPILE_ADDRESS,
  ADDR_PRECOMPILE_ABI,
  // ... all other precompiles

  // Utility functions
  parseSeiAddress,    // validate sei1... addresses
  parseEvmAddress,    // validate 0x... addresses
} from '@sei-js/evm';
```

## @sei-js/create-sei (Project Scaffolding)

```bash
# Create a new Sei dApp from template
npx @sei-js/create-sei my-sei-app

# Interactive prompts: choose React/Next.js, Wagmi/Ethers, TypeScript
# Includes pre-configured Sei network settings
```

## Sei-Specific Frontend Patterns

### Fast Finality — No Multi-Confirmation UX Needed

```typescript
// Standard Ethereum pattern (unnecessary on Sei):
await tx.wait(12); // "safe" — 12 blocks = ~144 seconds on Ethereum

// Sei pattern:
await tx.wait(1);  // 1 block = ~400ms — instant finality, fully safe
// No "waiting for confirmation..." spinners needed — show success after wait(1)
```

### No "Safe" / "Finalized" Block Tags

```typescript
// Ethereum: different commitment levels
// Sei: all the same — use "latest"
const block = await provider.getBlock("latest");   // correct
// const block = await provider.getBlock("safe");   // same as latest on Sei
// const block = await provider.getBlock("finalized"); // same as latest on Sei
```

### Display Both Address Formats

```tsx
import { ADDR_PRECOMPILE_ADDRESS, ADDR_PRECOMPILE_ABI } from '@sei-js/evm';

function AddressDisplay({ evmAddress }: { evmAddress: string }) {
  const { data: seiAddress } = useReadContract({
    address: ADDR_PRECOMPILE_ADDRESS,
    abi: ADDR_PRECOMPILE_ABI,
    functionName: 'getSeiAddr',
    args: [evmAddress as `0x${string}`],
  });

  return (
    <div>
      <p>EVM: {evmAddress}</p>
      {seiAddress && <p>Cosmos: {seiAddress}</p>}
    </div>
  );
}
```

### Transaction Submission with gasPrice

```typescript
// Frontend: always use gasPrice (legacy), not EIP-1559 fields
const { writeContractAsync } = useWriteContract();

const txHash = await writeContractAsync({
  address: contractAddress,
  abi: contractAbi,
  functionName: 'myFunction',
  args: [arg1, arg2],
  gas: 200_000n,
  gasPrice: parseUnits("10", "gwei"),  // minimum 10 gwei
  chainId: 1328,  // always specify chainId to prevent wrong-network submissions
});
```

## Querying EVM and Cosmos State Together

```typescript
// A user's SEI balance can change from both EVM and Cosmos transactions.
// Always fetch from RPC for accurate current state:
const evmBalance = await provider.getBalance(address); // in wei

// For native denoms (IBC tokens, factory tokens):
const bank = new ethers.Contract(BANK_PRECOMPILE_ADDRESS, BANK_PRECOMPILE_ABI, provider);
const ibcBalance = await bank.balance("sei1abc...", "ibc/...");
```

## RainbowKit / ConnectKit Integration

```typescript
// RainbowKit works with Sei via Wagmi
import { RainbowKitProvider, getDefaultConfig } from '@rainbow-me/rainbowkit';
import { seiTestnet, seiMainnet } from '@sei-js/evm';

const config = getDefaultConfig({
  appName: 'My Sei App',
  projectId: 'YOUR_WALLETCONNECT_PROJECT_ID',
  chains: [seiTestnet, seiMainnet],
});
```
