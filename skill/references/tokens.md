---
title: Tokens on Sei
description: SEI denominations, ERC20/ERC721/ERC1155 on Sei, CW20/CW721 legacy status, TokenFactory native tokens, and token standards overview.
---

# Tokens on Sei

## SEI Denomination Reference

| Unit | Value | Usage |
|---|---|---|
| 1 SEI | 1,000,000 usei | Standard display unit |
| 1 usei | 0.000001 SEI | Cosmos-side fees, unbonding amounts |
| 1 asei | 10^-18 SEI | EVM wei (msg.value) |
| 1 wei | 10^-18 SEI | EVM standard (same as asei) |

```typescript
// Convert SEI to wei (EVM)
const amount = ethers.parseEther("1.0"); // 1 SEI = 1e18 wei

// Convert SEI to usei (Cosmos / CLI)
const usei = 1_000_000; // 1 SEI = 1,000,000 usei
```

## ERC Token Standards on Sei

Sei's EVM fully supports the standard token interfaces — existing OpenZeppelin contracts work unchanged:

### ERC20 (Fungible Tokens)

```solidity
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SeiToken is ERC20, ERC20Burnable, Ownable {
    constructor() ERC20("Sei Token", "STK") Ownable(msg.sender) {
        _mint(msg.sender, 1_000_000 * 10**decimals());
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
```

**SSTORE note**: ERC20 `transfer()` writes to 2 storage slots (sender and recipient balances). On testnet (atlantic-2) this costs 144,000 gas in storage alone (2 × 72,000); on mainnet (pacific-1) it costs 40,000 gas (2 × 20,000). Always verify gas costs against your target network.

### ERC721 (NFTs)

```solidity
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract SeiNFT is ERC721URIStorage {
    uint256 private _tokenIds;

    constructor() ERC721("Sei NFT", "SNFT") {}

    function mint(address recipient, string memory tokenURI) external returns (uint256) {
        _tokenIds++;
        _mint(recipient, _tokenIds);
        _setTokenURI(_tokenIds, tokenURI);
        return _tokenIds;
    }
}
```

### ERC1155 (Multi-Token)

```solidity
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract SeiGameItems is ERC1155 {
    constructor() ERC1155("https://api.example.com/metadata/{id}.json") {
        _mint(msg.sender, 0, 100, ""); // mint 100 of token ID 0
    }
}
```

## USDC on Sei

USDC (Circle) is available on both testnet and mainnet:

| Network | Address |
|---|---|
| Mainnet | `0xe15fC38F6D8c56aF07bbCBe3BAf5708A2Bf42392` |
| Testnet (atlantic-2) | `0x4fCF1784B31630811181f670Aea7A7bEF803eaED` |

USDC on Sei is a native ERC20 — no pointer or bridging step needed.

## CW20 / CW721 — Legacy Status

> **Per SIP-3 (governance proposal 99)**: CosmWasm is deprecated on Sei. CW20 and CW721 are no longer the recommended token standards for new projects.

### Migration Path

| Legacy | Recommended |
|---|---|
| CW20 token | ERC20 token + optional pointer |
| CW721 NFT | ERC721 NFT + optional pointer |
| Native denom | Native denom + ERC20 pointer (TokenFactory) |

For existing CW20/CW721 tokens: register an ERC20/ERC721 pointer to make them accessible in EVM wallets while migrating. See [pointers/overview.md](pointers/overview.md).

## Native Denoms

Native tokens (not smart contracts) that live in the Cosmos bank module:

| Token | Denom | Notes |
|---|---|---|
| SEI | `usei` | Gas token, staking |
| IBC USDC | `ibc/...` | Via IBC from noble, etc. |
| Factory tokens | `factory/<addr>/<subdenom>` | Created via TokenFactory |

## Token Visibility by Wallet Type

| Token type | EVM wallets (MetaMask) | Cosmos wallets (Compass) |
|---|---|---|
| ERC20 | ✅ Native | ✅ Via CW20 pointer (if registered) |
| ERC721 | ✅ Native | ✅ Via CW721 pointer (if registered) |
| Native denom | ✅ Via ERC20 pointer (if registered) | ✅ Native |
| CW20 (legacy) | ✅ Via ERC20 pointer (if registered) | ✅ Native |
| CW721 (legacy) | ✅ Via ERC721 pointer (if registered) | ✅ Native |

## Token Metadata Best Practices

```solidity
// Always set name, symbol, and decimals
// Decimals should be 18 for most ERC20s (wei-compatible)
// Use 6 if you want usei-compatible amounts

contract MyToken is ERC20 {
    constructor() ERC20("My Sei Token", "MST") {
        // decimals() defaults to 18 — override if needed:
        // function decimals() public pure override returns (uint8) { return 6; }
    }
}
```

For native TokenFactory tokens:
```bash
# Set metadata before registering ERC20 pointer
seid tx bank set-denom-metadata \
  --denom factory/sei1.../MYTOKEN \
  --name "My Token" --symbol "MTK" --decimals 6 \
  --from my-key --fees 20000usei
```

## Checking Token Balances

```typescript
// ERC20 balance
const balance = await token.balanceOf(userAddress);

// Native SEI balance (wei)
const seiBalance = await provider.getBalance(userAddress);

// Query native denom balance via Bank precompile
import { BANK_PRECOMPILE_ADDRESS, BANK_PRECOMPILE_ABI } from '@sei-js/evm';
const bank = new ethers.Contract(BANK_PRECOMPILE_ADDRESS, BANK_PRECOMPILE_ABI, provider);
const useiBalance = await bank.balance("sei1abc...", "usei");
```
