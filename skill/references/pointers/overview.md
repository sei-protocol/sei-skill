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
| CW1155 contract | ERC1155 pointer | `CW1155` |
| Native denom (e.g., factory/...) | ERC20 pointer | `NATIVE` |

> **EVM pointer creation is retired.** The EVM pointer precompile (`0x…100b`) is retired and EVM pointer creation is now disabled. Any transaction that previously created a pointer now reverts with `pointer precompile is retired; EVM pointer creation is disabled`. None of the directions in this table can be registered any more — in either direction. Pointers (and CW wrappers) registered before the retirement remain live and readable: their registry entries, versions, and queries are unchanged, and `AssociateContractAddress` still gives them an EVM address.

> **ERC→CW pointers are also retired.** ERC20/721/1155 tokens could once be given a CosmWasm wrapper (CW20/CW721/CW1155) via `MsgRegisterPointer`. That handler now always returns `ErrRegisterPointerDeprecated`, and the wrapper wasm is no longer shipped.

## Registering Pointers — Removed

Pointer registration is no longer possible. The following have all been removed:

- The `seid tx evm register-evm-pointer CW20|CW721|CW1155|NATIVE <addr>` CLI command.
- The `seid tx evm call-precompile pointer addNativePointer <name>` CLI path.
- The `seid tx evm add-cw-erc20-pointer ...` governance-proposal CLI command.
- All pointer-related governance proposal types (`AddERCNativePointer`, `AddERCCW20/721/1155Pointer`, `AddCWERC20/721/1155Pointer`, `AddERCNativePointerProposalV2`) — submission and execution both refuse with `pointer governance proposals are deprecated`.
- The pointer precompile creation methods (`addNativePointer`, `addCW20Pointer`, `addCW721Pointer`, `addCW1155Pointer`) at `0x…100b` — the address stays registered with its ABI so the selectors still decode, but every call reverts with `pointer precompile is retired; EVM pointer creation is disabled`.
- The built-in pointer Solidity contract sources (`CW20ERC20Pointer`, `CW721ERC721Pointer`, `CW1155ERC1155Pointer`, `NativeSeiTokensERC20`) and their precompile interfaces.

There is no supported way to create a new pointer of any kind. Do not call the removed CLI commands or the precompile `add*` methods — they will fail. Only querying existing pointers (below) still works.

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
import { POINTERVIEW_PRECOMPILE_ADDRESS, POINTERVIEW_PRECOMPILE_ABI } from '@sei-js/precompiles';

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
