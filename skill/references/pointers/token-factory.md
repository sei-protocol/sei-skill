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


## Query Denoms Created by a Creator

List every denom created by a given creator address:

```bash
seid q tokenfactory denoms-from-creator <CREATOR_ADDRESS> \
  --node https://rpc-testnet.sei-apis.com \
  --output json | jq -r ".denoms"
```

### Pagination (as of v6.6.0)

The `denoms-from-creator` query now supports standard pagination flags. Previously it returned all denoms for a creator unbounded; the gRPC/REST query now paginates by default.

| Flag | Purpose |
| --- | --- |
| `--limit` | Max number of denoms per page |
| `--offset` | Number of denoms to skip |
| `--page` | Page number (1-based; combines with `--limit`) |
| `--page-key` | Base64 next-key from a previous response's `pagination.next_key` |
| `--count-total` | Include total count in `pagination.total` |

```bash
# First page of 100 denoms, with total count
seid q tokenfactory denoms-from-creator <CREATOR_ADDRESS> \
  --limit 100 --count-total \
  --node https://rpc-testnet.sei-apis.com \
  --output json

# Next page using the returned next key
seid q tokenfactory denoms-from-creator <CREATOR_ADDRESS> \
  --page-key <NEXT_KEY> --limit 100 \
  --node https://rpc-testnet.sei-apis.com \
  --output json
```

### gRPC / REST

The `DenomsFromCreator` gRPC/REST query accepts a `pagination` field (`PageRequest`) in the request and returns a `pagination` field (`PageResponse`) alongside `denoms` in the response. The REST endpoint also accepts standard `pagination.*` query parameters (e.g. `pagination.limit`, `pagination.offset`, `pagination.key`, `pagination.count_total`).

<!-- Note: the CosmWasm/wasm binding path returns ALL denoms for a creator unbounded (gas metering bounds cost), so wasm queries are not affected by the default page cap. -->


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
- **No IBC route**: IBC is closed on Sei in both directions, so TokenFactory denoms cannot leave the chain over IBC. They are still native bank denoms and move freely *within* Sei, in Cosmos wallets and through their ERC-20 pointers.
- **Supply tracking**: total supply lives in the Cosmos bank module; the ERC20 pointer reflects this same supply
