---
title: CosmWasm Bridge Precompiles
description: Addr, Bank, CosmWasm, Pointer, and PointerView precompiles for cross-VM interaction between the EVM and Cosmos layer on Sei. Legacy/compatibility focused — CosmWasm is deprecated per SIP-3. The IBC precompile is unusable: IBC is closed in both directions.
---

# CosmWasm Bridge Precompiles

> **Deprecation notice**: CosmWasm is deprecated per SIP-3 (initiated by mainnet [Proposal #99](https://www.mintscan.io/sei/proposals/99); new uploads/instantiation disabled by mainnet #115 / atlantic-2 testnet #246). These precompiles remain functional for existing integrations and legacy support, but new projects should use EVM-only with pointer contracts for cross-VM asset representation. **Exception: the IBC precompile (`0x1009`) is not functional** — IBC is closed in both directions (Props 116/120 inbound, [121](https://seistream.app/proposals/121) outbound), so its `transfer` reverts.

## Address Summary

| Precompile | Address | Purpose |
|---|---|---|
| Bank | `0x0000000000000000000000000000000000001001` | Send native tokens from EVM contracts |
| CosmWasm | `0x0000000000000000000000000000000000001002` | Execute CW contracts from EVM |
| Addr | `0x0000000000000000000000000000000000001004` | Address conversion + account association |
| IBC | `0x0000000000000000000000000000000000001009` | **Do not use** — IBC closed both directions; `transfer` reverts |
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
import { ADDRESS_PRECOMPILE_ADDRESS, ADDRESS_PRECOMPILE_ABI } from '@sei-js/precompiles';

const addr = new ethers.Contract(ADDRESS_PRECOMPILE_ADDRESS, ADDRESS_PRECOMPILE_ABI, provider);

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
        string memory usdcDenom = "ibc/..."; // legacy IBC denom, still held and transferable within Sei
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

## IBC Precompile (`0x1009`) — do not use

**This precompile cannot perform a transfer.** IBC is closed on Sei in both directions — inbound by Props 116/120, outbound by [Proposal 121](https://seistream.app/proposals/121) (2026-07-31). Both entrypoints (`transfer` and `transferWithDefaultTimeout`) call the transfer keeper, which now rejects the message, so both revert regardless of arguments.

Do not include it in new contracts. Existing contracts that call it will revert on that path and need an alternative route — see [../ecosystem/bridges.md](../ecosystem/bridges.md) for the EVM bridges.

To move native SEI, factory tokens, or existing `ibc/...` denoms between the EVM and Cosmos layers *within* Sei, use the Bank precompile (`0x1001`) and pointer contracts above; those still work. Full context in [../ecosystem/ibc-bridging.md](../ecosystem/ibc-bridging.md).

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
import { POINTERVIEW_PRECOMPILE_ADDRESS, POINTERVIEW_PRECOMPILE_ABI } from '@sei-js/precompiles';

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
