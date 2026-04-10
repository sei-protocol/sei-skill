---
title: Staking and Distribution Precompiles
description: Delegate, undelegate, and claim staking rewards from EVM contracts using Sei's Staking (0x1005) and Distribution (0x1007) precompiles.
---

# Staking and Distribution Precompiles

## Addresses

| Precompile | Address |
|---|---|
| Staking | `0x0000000000000000000000000000000000001005` |
| Distribution | `0x0000000000000000000000000000000000001007` |

## Staking Precompile Functions

### Core Transaction Functions

```solidity
// Delegate SEI to a validator (value = amount in wei)
function delegate(string memory validatorAddress) external payable returns (bool);

// Undelegate from validator (amount in usei: 1 SEI = 1,000,000 usei)
function undelegate(string memory validatorAddress, uint256 amount) external returns (bool);

// Redelegate from one validator to another (amount in usei)
function redelegate(
    string memory srcValidatorAddress,
    string memory dstValidatorAddress,
    uint256 amount
) external returns (bool);
```

### Query Functions

```solidity
// Get all validators with a given status and optional pagination
struct Validator { string operatorAddress; /* ... */ }
function validators(string memory status, uint32 pageLimit, string memory pageKey)
    external view returns (Validator[] memory);

// Get a delegator's delegations
struct DelegationResponse { /* delegatorAddress, validatorAddress, shares, balance */ }
function delegatorDelegations(address delegatorAddress, uint32 pageLimit, string memory pageKey)
    external view returns (DelegationResponse[] memory);

// Get a specific delegation
function delegation(address delegatorAddress, string memory validatorAddress)
    external view returns (uint256 shares, Coin memory balance);

// Get unbonding delegations
function delegatorUnbondingDelegations(address delegatorAddress, uint32 pageLimit, string memory pageKey)
    external view returns (UnbondingDelegation[] memory);
```

### Events

```solidity
event Delegate(address indexed delegator, string validator, uint256 amount);
event Undelegate(address indexed delegator, string validator, uint256 amount);
event Redelegate(address indexed delegator, string srcValidator, string dstValidator, uint256 amount);
```

## Distribution Precompile Functions

```solidity
// Withdraw delegator reward from a validator
function withdrawDelegatorReward(
    address delegatorAddress,
    string memory validatorAddress
) external returns (bool);

// Withdraw validator commission (for validator operators)
function withdrawValidatorCommission(string memory validatorAddress) external returns (bool);
```

## ethers.js Examples

### Setup

```typescript
import { ethers } from 'ethers';
import {
  STAKING_PRECOMPILE_ADDRESS,
  STAKING_PRECOMPILE_ABI,
  DISTRIBUTION_PRECOMPILE_ADDRESS,
  DISTRIBUTION_PRECOMPILE_ABI,
} from '@sei-js/evm';

const provider = new ethers.BrowserProvider(window.ethereum);
const signer = await provider.getSigner();

const staking = new ethers.Contract(STAKING_PRECOMPILE_ADDRESS, STAKING_PRECOMPILE_ABI, signer);
const distribution = new ethers.Contract(DISTRIBUTION_PRECOMPILE_ADDRESS, DISTRIBUTION_PRECOMPILE_ABI, signer);
```

### Delegate SEI

```typescript
// delegate takes msg.value as the amount — pass SEI as value parameter
const validator = "seivaloper1...";
const amount = ethers.parseEther("10"); // 10 SEI

const tx = await staking.delegate(validator, { value: amount });
await tx.wait(1);
console.log("Delegated 10 SEI to", validator);
```

### Undelegate SEI

```typescript
// undelegate takes amount in usei (6 decimals, NOT 18)
const usei = 10_000_000n; // 10 SEI = 10,000,000 usei
const tx = await staking.undelegate(validator, usei);
await tx.wait(1);
// Unbonding period: 21 days
```

> **Precision note:** `delegate` uses `msg.value` (18 decimal wei); `undelegate` and `redelegate` take amounts in usei (6 decimals). This asymmetry is intentional — match the precompile signature exactly.

### Query Delegation

```typescript
const [shares, balance] = await staking.delegation(
  await signer.getAddress(),
  validator
);
console.log("Shares:", shares.toString());
console.log("Balance:", ethers.formatEther(balance.amount), "SEI");
```

### Claim Rewards

```typescript
const tx = await distribution.withdrawDelegatorReward(
  await signer.getAddress(),
  validator
);
await tx.wait(1);
console.log("Rewards claimed");
```

### List Validators

```typescript
const validators = await staking.validators("BONDED", 20, "");
for (const v of validators) {
  console.log(v.operatorAddress);
}
```

## Solidity Integration — Liquid Staking Contract

```solidity
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IStaking {
    function delegate(string memory validatorAddress) external payable returns (bool);
    function undelegate(string memory validatorAddress, uint256 amount) external returns (bool);
}

interface IDistribution {
    function withdrawDelegatorReward(
        address delegatorAddress,
        string memory validatorAddress
    ) external returns (bool);
}

contract LiquidStakingVault is ERC20 {
    address constant STAKING = 0x0000000000000000000000000000000000001005;
    address constant DISTRIBUTION = 0x0000000000000000000000000000000000001007;

    string public validatorAddress;

    constructor(string memory _validator) ERC20("Liquid SEI", "lstSEI") {
        validatorAddress = _validator;
    }

    // Stake SEI and receive lstSEI shares
    function deposit() external payable {
        require(msg.value > 0, "Must send SEI");
        bool success = IStaking(STAKING).delegate{value: msg.value}(validatorAddress);
        require(success, "Delegation failed");
        _mint(msg.sender, msg.value);  // 1:1 initial minting
    }

    // Compound rewards by claiming and re-delegating
    function compound() external {
        IDistribution(DISTRIBUTION).withdrawDelegatorReward(address(this), validatorAddress);
        uint256 rewards = address(this).balance;
        if (rewards > 0) {
            IStaking(STAKING).delegate{value: rewards}(validatorAddress);
        }
    }

    receive() external payable {}
}
```

## Key Notes

- **Unbonding period**: 21 days — users cannot access undelegated tokens during this period
- **Slashing**: validators can be slashed for downtime or double-signing; delegators share in slashing proportionally
- **Rewards**: rewards accrue each block; claim anytime via Distribution precompile
- **Validator addresses**: use `seivaloper1...` bech32 format for all validator address parameters
- **Amount precision**: `delegate` → wei (1e18); `undelegate`/`redelegate` → usei (1e6)
