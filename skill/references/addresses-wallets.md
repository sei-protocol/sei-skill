---
title: Addresses and Wallets on Sei
description: The dual address system (sei1... bech32 + 0x... EVM), how association works, HD derivation paths, and wallet integrations.
---

# Addresses and Wallets on Sei

## The Dual Address System

Every Sei account has one public key that generates **two addresses**:

- **EVM address**: `0x...` (20 bytes, same format as Ethereum)
- **Cosmos address**: `sei1...` (bech32, same as other Cosmos chains)

These are two views of the same account. `0x1234...abcd` and `sei1xyz...` controlled by the same private key represent the **same account**. Funds sent to either address land in the same account — after the addresses are associated.

## Before vs After Association

| State | EVM → CW transfer | CW → EVM transfer | Same balance? |
|---|---|---|---|
| **Not associated** | Not possible | Not possible | No — separate balances |
| **Associated** | Works | Works | Yes — unified |

Until a user submits any transaction, the chain doesn't know the public key behind an address, so it can't prove the two addresses are the same account.

## Association Methods

| Method | Security Risk | How |
|---|---|---|
| Broadcast any transaction | **Low** | Automatic — any on-chain tx reveals the public key |
| Signed message (off-chain) | Medium | Sign a message in wallet, submit via Addr precompile |
| Public key direct | Medium | Submit public key hex via `associatePubKey()` |
| Private key | High | Never recommended |
| Gasless (`sei_associate`) | Low | Special RPC method — no gas needed |

**Recommended**: the easiest way to associate is to simply make any transaction (buy testnet SEI from faucet, send to yourself, etc.). The association happens automatically on first on-chain activity.

### Gasless Association (`sei_associate`)

Users can associate without paying gas via a special JSON-RPC method:

```javascript
// Gasless association — sign with EVM wallet, no gas needed
const result = await provider.send("sei_associate", [{
  // Parameters include signature over a custom message
  // See sei-docs/evm/precompiles/cosmwasm-precompiles/addr.mdx for full spec
}]);
```

### Programmatic Association in Solidity

```solidity
interface IAddr {
    function associate(
        string memory v,
        string memory r,
        string memory s,
        string memory customMessage
    ) external returns (address evmAddr, string memory seiAddr);
}

contract AssociationHelper {
    address constant ADDR = 0x0000000000000000000000000000000000001004;

    function associateUser(string memory v, string memory r, string memory s) external {
        IAddr(ADDR).associate(v, r, s, "");
    }
}
```

## Address Derivation

Both addresses derive from the same ECDSA public key:

```
Public Key (uncompressed 65 bytes)
       │
       ├── keccak256(pubkey[1:]) → last 20 bytes → 0x... EVM address
       │
       └── sha256(pubkey) → ripemd160 → bech32 encode → sei1... address
```

```typescript
// Convert between formats using @sei-js/evm or the Addr precompile
import { ADDR_PRECOMPILE_ADDRESS, ADDR_PRECOMPILE_ABI } from '@sei-js/evm';

const addr = new ethers.Contract(ADDR_PRECOMPILE_ADDRESS, ADDR_PRECOMPILE_ABI, provider);

// EVM address → bech32
const seiAddr = await addr.getSeiAddr("0x1234...abcd");

// bech32 → EVM address
const evmAddr = await addr.getEvmAddr("sei1abc...");
```

## HD Derivation Paths

| Use case | Coin type | HD path | Compatible with |
|---|---|---|---|
| EVM wallets (MetaMask) | 60 | `m/44'/60'/0'/0/x` | MetaMask, Rabby, Ledger (EVM app) |
| Cosmos wallets | 118 | `m/44'/118'/0'/0/x` | Compass, Keplr, Ledger (Cosmos app) |

> **Mnemonic interop**: if a user's mnemonic was created in MetaMask (coin type 60), their EVM and Cosmos addresses are linked correctly. If created in a Cosmos wallet (coin type 118), the derivation is different — the EVM address MetaMask generates from the same mnemonic will be different.

## Wallet Integrations

### Sei Global Wallet (Recommended for dApps)

```typescript
import { SeiGlobalWallet } from '@sei-js/sei-global-wallet';

// No installation needed — injected via browser extension or dApp SDK
// Supports: Google, Apple, Twitter, Telegram social login + EVM wallets
// EIP-6963 compliant — detected by Wagmi/RainbowKit automatically

// Usage with Wagmi (auto-detects via EIP-6963)
import { useConnect } from 'wagmi';
const { connect, connectors } = useConnect();
```

### MetaMask / Rabby / Standard EVM Wallets

```typescript
// Standard ethers.js / Viem connection — works unchanged on Sei
const provider = new ethers.BrowserProvider(window.ethereum);
await provider.send("eth_requestAccounts", []);
const signer = await provider.getSigner();
```

### Compass Wallet

Compass is Sei's native wallet — supports both EVM and Cosmos operations natively with the same UI. Available at compass.sei.io.

### Ledger Hardware Wallet

- **EVM operations**: use Ledger with Ethereum app, connected via MetaMask
- **Cosmos operations**: use Ledger with Cosmos app or Sei app
- Both paths use the same underlying private key on the device

```typescript
// Ledger with ethers.js via MetaMask extension
const provider = new ethers.BrowserProvider(window.ethereum);
// MetaMask handles Ledger communication transparently
```

### WalletConnect

Standard WalletConnect v2 works with Sei — use `seiMainnet` or `seiTestnet` chain definitions from `@sei-js/evm`.

## Address Validation

```typescript
// Validate EVM address
function isEVMAddress(addr: string): boolean {
  return /^0x[0-9a-fA-F]{40}$/.test(addr);
}

// Validate Sei bech32 address
function isSeiAddress(addr: string): boolean {
  return /^sei1[a-z0-9]{38,}$/.test(addr);
}

// Before a cross-VM transfer, always check association
const evmAddr = await addr.getEvmAddr(seiAddress);
if (evmAddr === ethers.ZeroAddress) {
  throw new Error("Address not yet associated — recipient must make a transaction first");
}
```

## Key Points for dApp Builders

1. **Show both address formats** — your UI should display both `0x...` and `sei1...` when a user connects, as they may receive tokens from either ecosystem
2. **Check association before cross-VM transfers** — query the Addr precompile; warn users if unassociated
3. **Token balances may come from non-EVM sources** — Cosmos bank sends won't appear in EVM event logs; use `provider.getBalance()` not just event tracking
4. **Default to EVM address** for all EVM contract interactions; use bech32 only when calling Cosmos-side operations (staking, governance, seid CLI)
