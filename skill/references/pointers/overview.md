---
title: Pointer Contracts
description: How Sei's pointer contract system bridges EVM and Cosmos token standards — registration, types, and cross-VM interoperability patterns.
---

# Pointer Contracts

## What Problem They Solve

EVM wallets (MetaMask, Rabby) can only see ERC20/ERC721 tokens. Cosmos wallets (Compass, Keplr) can only see native and CW20/CW721 tokens. Without pointer contracts, the same underlying asset would be invisible to half of Sei's users.

**Pointer contracts make a single token visible in both ecosystems.**

When an ERC20 token has a registered pointer, it gets a corresponding CW20 interface on the Cosmos side. When a native Sei token has a registered pointer, it gets an ERC20 address that MetaMask can display and interact with.

## One Pointer Per Contract

Each smart contract is limited to **one** associated pointer contract. This:
- Prevents conflicts (no two ERC20s claiming to represent the same CW20)
- Provides authenticity — the registered pointer is the canonical bridge
- Is enforced on-chain — attempting to register a second pointer will fail

## Pointer Types

| From | To | Pointer Type |
|---|---|---|
| CW20 contract | ERC20 pointer | `CW20` |
| CW721 contract | ERC721 pointer | `CW721` |
| Native denom (e.g., factory/...) | ERC20 pointer | `NATIVE` |
| ERC20 contract | CW20 pointer | `ERC20` |
| ERC721 contract | CW721 pointer | `ERC721` |

## Registering Pointers via CLI

```bash
# Register an ERC20 pointer for a CW20 contract
seid tx evm register-evm-pointer CW20 <CW20_CONTRACT_ADDRESS> \
  --from <KEY_NAME> \
  --chain-id atlantic-2 \
  --node https://rpc-testnet.sei-apis.com \
  --fees 40000usei

# Register an ERC721 pointer for a CW721 contract
seid tx evm register-evm-pointer CW721 <CW721_CONTRACT_ADDRESS> \
  --from <KEY_NAME> \
  --chain-id atlantic-2 \
  --node https://rpc-testnet.sei-apis.com \
  --fees 40000usei

# Register an ERC20 pointer for a native denom (e.g., factory/sei1.../mytoken)
seid tx evm register-evm-pointer NATIVE <DENOM> \
  --from <KEY_NAME> \
  --chain-id atlantic-2 \
  --node https://rpc-testnet.sei-apis.com \
  --fees 40000usei

# Register a CW20 pointer for an ERC20 contract
seid tx evm register-cosmos-pointer ERC20 <ERC20_ADDRESS> \
  --from <KEY_NAME> \
  --chain-id atlantic-2 \
  --node https://rpc-testnet.sei-apis.com \
  --fees 40000usei
```

## Registering Pointers via Solidity

For programmatic registration (e.g., in a factory contract):

```solidity
pragma solidity ^0.8.28;

interface IPointer {
    function registerNativePointer(string memory denom)
        external payable returns (address pointer);
    function registerCW20Pointer(string memory cwAddr)
        external payable returns (address pointer);
    function registerCW721Pointer(string memory cwAddr)
        external payable returns (address pointer);
}

contract TokenFactory {
    address constant POINTER = 0x000000000000000000000000000000000000100B;

    function createTokenWithPointer(string memory denom) external payable {
        // Register ERC20 pointer for an existing native denom
        address pointerAddr = IPointer(POINTER).registerNativePointer{value: msg.value}(denom);
        emit PointerCreated(denom, pointerAddr);
    }

    event PointerCreated(string denom, address pointer);
}
```

## Querying Existing Pointers

### Via CLI

```bash
# Query if a CW20 has a pointer
seid q evm pointer CW20 <CW20_CONTRACT_ADDRESS> \
  --node https://rpc-testnet.sei-apis.com

# Query if a native denom has an ERC20 pointer
seid q evm pointer NATIVE <DENOM> \
  --node https://rpc-testnet.sei-apis.com

# Query if an ERC20 has a CW20 pointer
seid q evm pointer ERC20 <ERC20_ADDRESS> \
  --node https://rpc-testnet.sei-apis.com
```

### Via PointerView Precompile

```typescript
import { POINTERVIEW_PRECOMPILE_ADDRESS, POINTERVIEW_PRECOMPILE_ABI } from '@sei-js/evm';

const pointerView = new ethers.Contract(
  POINTERVIEW_PRECOMPILE_ADDRESS,
  POINTERVIEW_PRECOMPILE_ABI,
  provider
);

// Check if a native denom has an ERC20 pointer
const [pointerAddress, version, exists] = await pointerView.getNativePointer("usei");
if (exists) {
  console.log("USEI is accessible as ERC20 at:", pointerAddress);
} else {
  console.log("No ERC20 pointer registered for usei");
}

// Check if a CW20 has an ERC20 pointer
const [cwPointer, cwVersion, cwExists] = await pointerView.getCW20Pointer("sei1cw20contract...");
```

## How Pointer Contracts Work in Practice

When a user with MetaMask sends an ERC20 pointer token to someone:

1. User calls `transfer()` on the ERC20 pointer contract (standard ERC20)
2. The pointer contract translates this into a native token transfer on the Cosmos side
3. The recipient's Cosmos wallet balance updates
4. Both wallets see the same total supply — no minting occurs

When a user with Compass (Cosmos) sends a CW20 pointer token to an EVM address:

1. User calls `execute` on the CW20 pointer contract (standard CW20)
2. The pointer contract translates to an EVM token transfer
3. The EVM wallet balance updates

**The underlying token is the same** — the pointer is just a translation layer, not a bridge that locks/mints.

## Important Notes

- **One pointer per contract** — you cannot register two ERC20 pointers for the same CW20
- **Pointer is canonical** — the registered pointer is the official EVM interface; users should not use unregistered wrappers
- **Registration fee** — there is a small protocol fee in SEI to prevent spam
- **CosmWasm deprecated** — per SIP-3, CW20/CW721 token creation is deprecated; prefer creating native denoms via TokenFactory and registering ERC20 pointers for them
