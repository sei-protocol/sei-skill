---
title: CosmWasm Bridge Precompiles
description: Addr, Bank, CosmWasm, IBC, Pointer, and PointerView precompiles for cross-VM interaction between the EVM and Cosmos layer on Sei. Legacy/compatibility focused — CosmWasm is deprecated per SIP-3.
---

# CosmWasm Bridge Precompiles

> **Deprecation notice**: CosmWasm is deprecated per SIP-3 (governance proposal 99 on mainnet). These precompiles remain functional for existing integrations and legacy support, but new projects should use EVM-only with pointer contracts for cross-VM asset representation.

## Address Summary

| Precompile | Address | Purpose |
|---|---|---|
| Bank | `0x0000000000000000000000000000000000001001` | Send native tokens from EVM contracts |
| CosmWasm | `0x0000000000000000000000000000000000001002` | Execute CW contracts from EVM |
| Addr | `0x0000000000000000000000000000000000001004` | Address conversion + account association |
| IBC | `0x0000000000000000000000000000000000001009` | Initiate IBC transfers from EVM |
| Pointer | `0x000000000000000000000000000000000000100B` | Register pointer contracts |
| PointerView | `0x000000000000000000000000000000000000100A` | Query pointer registrations |

---

## Addr Precompile (`0x1004`)

Most commonly used — converts between bech32 and EVM addresses, and associates the two.

### Functions

```solidity
// Get the EVM (0x) address for a bech32 sei1... address
function getEvmAddr(string memory seiAddr) external view returns (address evmAddr);

// Get the bech32 address for a 0x... EVM address
function getSeiAddr(address evmAddr) external view returns (string memory seiAddr);

// Associate bech32 and 0x addresses (requires signed message — see docs)
function associate(
    string memory v,
    string memory r,
    string memory s,
    string memory customMessage
) external returns (address evmAddr, string memory seiAddr);

// Associate via public key
function associatePubKey(string memory pubKeyHex)
    external returns (address evmAddr, string memory seiAddr);
```

### ethers.js Example

```typescript
import { ethers } from 'ethers';
import { ADDR_PRECOMPILE_ADDRESS, ADDR_PRECOMPILE_ABI } from '@sei-js/evm';

const addr = new ethers.Contract(ADDR_PRECOMPILE_ADDRESS, ADDR_PRECOMPILE_ABI, provider);

// Check if an EVM address has an associated sei1... address
const seiAddress = await addr.getSeiAddr("0x1234...");
console.log("Sei address:", seiAddress); // "sei1..." or empty if not associated

// Check if a sei1... address has an EVM address
const evmAddress = await addr.getEvmAddr("sei1abc...");
console.log("EVM address:", evmAddress);
```

### Why address association matters

Every account has both a `sei1...` bech32 address and a `0x...` EVM address derived from the same public key. However, the mapping is only stored on-chain after the user *associates* them. Before association:

- EVM wallets cannot receive native Cosmos tokens sent to the `sei1...` address
- Cosmos wallets cannot receive ERC20 tokens sent to the `0x...` address

The easiest way to associate: simply send a transaction from either address — the chain will automatically link them on first on-chain activity.

---

## Bank Precompile (`0x1001`)

Send native Cosmos tokens (SEI, IBC tokens, factory tokens) from an EVM contract.

### Functions

```solidity
// Send native tokens to a bech32 address
function send(string memory toAddress, Coin[] memory amount) external returns (bool);

// Send native SEI (msg.value) to a bech32 address
function sendNative(string memory toAddress) external payable returns (bool);

// Query balance of a native denom
function balance(string memory accountAddress, string memory denom)
    external view returns (uint256);

// Query all balances for an address
function all_balances(string memory accountAddress)
    external view returns (Coin[] memory);
```

```solidity
struct Coin {
    uint256 amount;
    string denom;
}
```

### Example

```solidity
pragma solidity ^0.8.28;

interface IBank {
    struct Coin { uint256 amount; string denom; }
    function sendNative(string memory toAddress) external payable returns (bool);
    function balance(string memory account, string memory denom) external view returns (uint256);
}

contract Distributor {
    address constant BANK = 0x0000000000000000000000000000000000001001;

    // Send native SEI to a Cosmos address from contract
    function sendToCosmosUser(string memory recipient) external payable {
        IBank(BANK).sendNative{value: msg.value}(recipient);
    }

    // Query how much USDC a Cosmos address holds
    function getUSDCBalance(string memory account) external view returns (uint256) {
        string memory usdcDenom = "ibc/..."; // IBC denom for USDC
        return IBank(BANK).balance(account, usdcDenom);
    }
}
```

---

## CosmWasm Precompile (`0x1002`) — Legacy

Execute CosmWasm smart contracts from EVM. Use for integrating with legacy CW contracts while migrating to EVM.

```solidity
interface ICosmWasm {
    // Execute a CW contract
    function execute(
        string memory contractAddress,
        bytes memory msg,
        bytes memory coins
    ) external payable returns (bytes memory);

    // Query a CW contract (read-only)
    function query(
        string memory contractAddress,
        bytes memory req
    ) external view returns (bytes memory);

    // Instantiate a new CW contract
    function instantiate(
        uint64 codeID,
        string memory admin,
        bytes memory msg,
        string memory label,
        bytes memory coins
    ) external payable returns (string memory contractAddress, bytes memory data);
}
```

---

## IBC Precompile (`0x1009`) — Legacy

Initiate IBC transfers from EVM contracts.

```solidity
interface IIBC {
    function transfer(
        string memory toAddress,
        string memory port,
        string memory channel,
        string memory denom,
        uint256 amount,
        uint64 revisionNumber,
        uint64 revisionHeight,
        uint64 timeoutTimestamp,
        string memory memo
    ) external payable returns (uint64 sequence);
}
```

---

## Pointer Precompile (`0x100B`)

Register pointer contracts to bridge EVM ↔ Cosmos tokens. See [pointers/overview.md](../pointers/overview.md) for the full workflow.

```solidity
interface IPointer {
    // Create an ERC20 pointer for a CW20 contract
    function registerCW20Pointer(string memory cwAddr) external payable returns (address pointer);

    // Create an ERC721 pointer for a CW721 contract
    function registerCW721Pointer(string memory cwAddr) external payable returns (address pointer);

    // Create an ERC20 pointer for a native Cosmos denom
    function registerNativePointer(string memory denom) external payable returns (address pointer);

    // Create a CW20 pointer for an ERC20 contract
    function registerERC20CW20Pointer(address erc20Addr) external payable returns (string memory pointer);

    // Create a CW721 pointer for an ERC721 contract
    function registerERC721CW721Pointer(address erc721Addr) external payable returns (string memory pointer);
}
```

---

## PointerView Precompile (`0x100A`)

Query whether a pointer exists and what it points to.

```solidity
interface IPointerView {
    // Get EVM pointer address for a CW20 contract
    function getCW20Pointer(string memory cwAddr) external view returns (address pointer, uint16 version, bool exists);

    // Get EVM pointer address for a CW721 contract
    function getCW721Pointer(string memory cwAddr) external view returns (address pointer, uint16 version, bool exists);

    // Get EVM pointer address for a native denom
    function getNativePointer(string memory denom) external view returns (address pointer, uint16 version, bool exists);
}
```

### ethers.js Example

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
  console.log("USEI ERC20 pointer:", pointerAddress);
}
```
