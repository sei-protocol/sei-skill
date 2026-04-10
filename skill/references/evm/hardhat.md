---
title: Hardhat for Sei
description: Setting up Hardhat for Sei EVM development — configuration, deployment, testing, and contract verification.
---

# Hardhat for Sei

## When to Use Hardhat

Use Hardhat when:
- Your team has an existing JavaScript/TypeScript toolchain
- You need OpenZeppelin Hardhat plugins (upgrades, defender)
- You prefer Mocha/Chai test syntax
- You want tight npm ecosystem integration

Use Foundry instead when you want faster test execution, native fuzz testing, or a Rust-first toolchain.

## Quick Setup

```bash
mkdir sei-hardhat-project && cd sei-hardhat-project
npm init -y
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox @openzeppelin/contracts dotenv
npx hardhat --init
# Select: Hardhat3, TypeScript project with Mocha and Ethers.js
```

## hardhat.config.ts for Sei

```typescript
import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import 'dotenv/config';

const PRIVATE_KEY = process.env.PRIVATE_KEY!;

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.28',
    settings: {
      optimizer: { enabled: true, runs: 200 },
    },
  },
  networks: {
    seiTestnet: {
      url: 'https://evm-rpc-testnet.sei-apis.com',
      accounts: [PRIVATE_KEY],
      chainId: 1328,
    },
    seiMainnet: {
      url: 'https://evm-rpc.sei-apis.com',
      accounts: [PRIVATE_KEY],
      chainId: 1329,
    },
    // Local testing
    hardhat: {
      chainId: 31337,
    },
  },
  etherscan: {
    apiKey: {
      seiTestnet: 'placeholder', // Seitrace doesn't require API key
      seiMainnet: 'placeholder',
    },
    customChains: [
      {
        network: 'seiTestnet',
        chainId: 1328,
        urls: {
          apiURL: 'https://seitrace.com/api?chain=atlantic-2',
          browserURL: 'https://seitrace.com/?chain=atlantic-2',
        },
      },
      {
        network: 'seiMainnet',
        chainId: 1329,
        urls: {
          apiURL: 'https://seitrace.com/api',
          browserURL: 'https://seitrace.com',
        },
      },
    ],
  },
};

export default config;
```

## .env Setup

```bash
# .env (add to .gitignore!)
PRIVATE_KEY=0xYourPrivateKeyHere
```

## Deployment Scripts

### Using Hardhat Ignition (recommended for Hardhat 3)

```typescript
// ignition/modules/MyToken.ts
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("MyToken", (m) => {
  const token = m.contract("MyERC20Token", ["My Token", "MTK"]);
  return { token };
});
```

```bash
npx hardhat ignition deploy ignition/modules/MyToken.ts --network seiTestnet
```

### Using a plain deploy script

```typescript
// scripts/deploy.ts
import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with:", deployer.address);

  const MyToken = await ethers.getContractFactory("MyERC20Token");
  const token = await MyToken.deploy("My Token", "MTK");
  await token.waitForDeployment();

  console.log("Deployed to:", await token.getAddress());
}

main().catch(console.error);
```

```bash
npx hardhat run scripts/deploy.ts --network seiTestnet
```

## Writing Tests

```typescript
// test/MyToken.ts
import { expect } from "chai";
import { ethers } from "hardhat";

describe("MyERC20Token", () => {
  it("should mint tokens on deploy", async () => {
    const [owner, user] = await ethers.getSigners();
    const Token = await ethers.getContractFactory("MyERC20Token");
    const token = await Token.deploy("My Token", "MTK");

    const balance = await token.balanceOf(owner.address);
    expect(balance).to.equal(ethers.parseEther("1000000"));
  });
});
```

```bash
npx hardhat test
```

## Fork Testing Against Sei Testnet

```typescript
// hardhat.config.ts — add fork config
networks: {
  hardhat: {
    forking: {
      url: 'https://evm-rpc-testnet.sei-apis.com',
      // blockNumber: 12345678,  // optional pin
    },
    chainId: 1328,  // match testnet chain ID for precompile addresses
  },
}
```

```bash
npx hardhat test  # runs against forked testnet state
```

This is required when testing contracts that interact with Sei precompiles — precompile addresses (`0x1005`, `0x1006`, etc.) only exist on the actual Sei network.

## Contract Verification on Seitrace

```bash
# After deployment, verify source:
npx hardhat verify --network seiTestnet <CONTRACT_ADDRESS> "Constructor" "Args"

# Example for ERC20:
npx hardhat verify --network seiTestnet 0x1234...abcd "My Token" "MTK"
```

## Gas Configuration for Sei

```typescript
// In scripts: use gasPrice, not EIP-1559 fields
const tx = await contract.someFunction({
  gasPrice: ethers.parseUnits("10", "gwei"),  // minimum 10 gwei
  gasLimit: 300_000n,  // add buffer for OCC
});
await tx.wait(1);  // 1 confirmation = finality on Sei
```

## OpenZeppelin Contracts

```solidity
// Contracts work unchanged on Sei
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// UUPS upgradeable pattern
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
```

```bash
# Install OpenZeppelin upgrades plugin
npm install --save-dev @openzeppelin/hardhat-upgrades
```

## Common Issues

**`insufficient funds for gas`** — testnet faucet: https://atlantic-2.app.jellyfish.finance/faucet

**`nonce too low`** — Sei's fast block times mean nonces can conflict when sending many txs quickly; use a nonce manager or sequential sends with `await tx.wait(1)` between each

**Test hangs** — if tests run against local hardhat network without forking, precompile calls will revert; use fork testing for precompile interactions
