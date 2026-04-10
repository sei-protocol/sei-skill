---
title: TokenFactory and Native Token Creation
description: Create native Cosmos denoms with the TokenFactory module, mint/burn supply, and register an ERC20 pointer for MetaMask visibility.
---

# TokenFactory and Native Token Creation

## What is TokenFactory?

TokenFactory is a Cosmos SDK module that allows any account to create a new native token (denom) on Sei. Unlike ERC20 tokens (which are smart contracts), TokenFactory tokens are native Cosmos assets — they can be used directly with `bank` send, IBC, and staking.

## Native Denom Format

Tokens created via TokenFactory have a predictable denom format:

```
factory/<creator_address>/<subdenom>
```

For example:
```
factory/sei1abc...xyz/MYTOKEN
```

The `creator_address` is the bech32 address that called `create-denom`. This acts as a namespace — only that address can mint or burn the token by default.

## Create a New Token

```bash
# Create a new denom under your address namespace
seid tx tokenfactory create-denom MYTOKEN \
  --from <YOUR_KEY> \
  --chain-id atlantic-2 \
  --node https://rpc-testnet.sei-apis.com \
  --fees 20000usei

# This creates: factory/sei1abc.../MYTOKEN
```

## Mint Tokens

```bash
# Mint 1,000,000 tokens (specify full denom)
seid tx tokenfactory mint 1000000factory/sei1abc.../MYTOKEN \
  --from <YOUR_KEY> \
  --chain-id atlantic-2 \
  --node https://rpc-testnet.sei-apis.com \
  --fees 20000usei

# Mint to a specific address
seid tx tokenfactory mint-to <RECIPIENT_ADDRESS> 1000000factory/sei1abc.../MYTOKEN \
  --from <YOUR_KEY> \
  --chain-id atlantic-2 \
  --node https://rpc-testnet.sei-apis.com \
  --fees 20000usei
```

## Burn Tokens

```bash
# Burn tokens (caller must hold the tokens)
seid tx tokenfactory burn 500000factory/sei1abc.../MYTOKEN \
  --from <YOUR_KEY> \
  --chain-id atlantic-2 \
  --node https://rpc-testnet.sei-apis.com \
  --fees 20000usei
```

## Admin Operations

```bash
# Change the admin address (transfer token management)
seid tx tokenfactory change-admin factory/sei1abc.../MYTOKEN <NEW_ADMIN_ADDRESS> \
  --from <YOUR_KEY> \
  --chain-id atlantic-2 \
  --node https://rpc-testnet.sei-apis.com \
  --fees 20000usei

# Set denom metadata (name, symbol, description, decimals)
seid tx bank set-denom-metadata \
  --denom factory/sei1abc.../MYTOKEN \
  --name "My Token" \
  --symbol "MTK" \
  --decimals 6 \
  --from <YOUR_KEY> \
  --fees 20000usei
```

## Register an ERC20 Pointer (Make Token Visible in MetaMask)

After creating your native token, register an ERC20 pointer so EVM wallets can see and interact with it:

```bash
seid tx evm register-evm-pointer NATIVE factory/sei1abc.../MYTOKEN \
  --from <YOUR_KEY> \
  --chain-id atlantic-2 \
  --node https://rpc-testnet.sei-apis.com \
  --fees 40000usei
```

This creates an ERC20 contract at a deterministic address that MetaMask and other EVM wallets recognize. Users can:
- View the token balance in MetaMask
- Send/receive via standard ERC20 `transfer()`
- Use in any ERC20-compatible DeFi protocol

## Query Pointer Address

```bash
# Get the ERC20 pointer address for your native token
seid q evm pointer NATIVE factory/sei1abc.../MYTOKEN \
  --node https://rpc-testnet.sei-apis.com
```

Or via the PointerView precompile:
```typescript
const [pointerAddress, version, exists] = await pointerView.getNativePointer(
  "factory/sei1abc.../MYTOKEN"
);
console.log("ERC20 pointer at:", pointerAddress);
```

## Complete Token Launch Workflow

```bash
# Step 1: Create the denom
seid tx tokenfactory create-denom MYTOKEN \
  --from my-key --chain-id atlantic-2 --fees 20000usei

# Step 2: Mint initial supply
seid tx tokenfactory mint 1000000000000factory/sei1.../MYTOKEN \
  --from my-key --chain-id atlantic-2 --fees 20000usei

# Step 3: Register ERC20 pointer
seid tx evm register-evm-pointer NATIVE factory/sei1.../MYTOKEN \
  --from my-key --chain-id atlantic-2 --fees 40000usei

# Step 4: Verify pointer exists
seid q evm pointer NATIVE factory/sei1.../MYTOKEN

# Token is now usable in:
# - Cosmos wallets via factory/sei1.../MYTOKEN denom
# - EVM wallets via the ERC20 pointer address
# - IBC transfers as a native asset
# - DeFi protocols that accept ERC20
```

## Minting via EVM Contract

If you want a Solidity contract to control minting, use the Bank precompile:

```solidity
pragma solidity ^0.8.28;

interface IBank {
    struct Coin { uint256 amount; string denom; }
    function send(string memory toAddress, Coin[] memory amount) external returns (bool);
}

// NOTE: Minting itself still requires the admin Cosmos account (seid tx tokenfactory mint)
// Bank precompile can SEND existing tokens, not mint new ones
// For programmatic minting from EVM, you'd need a CosmWasm contract as the admin
// (but CW is deprecated — consider using an ERC20 with custom mint logic instead)
```

## Key Notes

- **Decimals**: native denoms don't have enforced decimals — you define them in metadata and must be consistent in your frontend
- **ERC20 pointer decimals**: the ERC20 pointer uses the decimals you set in denom metadata; default is 0 if not set — always set decimals before registering the pointer
- **Admin = creator by default**: the address that runs `create-denom` is the admin; transfer admin to a multisig or smart contract for production
- **IBC-native**: TokenFactory tokens can be sent via IBC immediately without any extra setup, unlike ERC20 tokens
- **Supply tracking**: total supply lives in the Cosmos bank module; the ERC20 pointer reflects this same supply
