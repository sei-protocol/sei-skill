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
// Delegate SEI to a validator (value = amount in wei; must be a whole number of usei,
// i.e. a multiple of 1e12 wei, or the call reverts)
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
// Validators with a given status: "BOND_STATUS_BONDED", "BOND_STATUS_UNBONDING",
// "BOND_STATUS_UNBONDED", or "" for all (any other string, e.g. "BONDED", reverts).
// Cursor pagination: pass nextKey from the previous response; empty bytes for the first page.
struct Validator { string operatorAddress; bytes consensusPubkey; bool jailed; int32 status; string tokens; /* ... */ }
struct ValidatorsResponse { Validator[] validators; bytes nextKey; }
function validators(string memory status, bytes memory nextKey)
    external view returns (ValidatorsResponse memory response);

// A delegator's delegations (paginated)
struct DelegationsResponse { Delegation[] delegations; bytes nextKey; }
function delegatorDelegations(address delegator, bytes memory nextKey)
    external view returns (DelegationsResponse memory response);

// A specific delegation
struct Balance { uint256 amount; string denom; }   // amount in usei
struct DelegationDetails { string delegator_address; uint256 shares; uint256 decimals; string validator_address; }
struct Delegation { Balance balance; DelegationDetails delegation; }
function delegation(address delegator, string memory valAddress)
    external view returns (Delegation memory delegation);

// A delegator's unbonding delegations (paginated)
struct UnbondingDelegationEntry { int64 creationHeight; int64 completionTime; string initialBalance; string balance; }
struct UnbondingDelegation { string delegatorAddress; string validatorAddress; UnbondingDelegationEntry[] entries; }
struct UnbondingDelegationsResponse { UnbondingDelegation[] unbondingDelegations; bytes nextKey; }
function delegatorUnbondingDelegations(address delegator, bytes memory nextKey)
    external view returns (UnbondingDelegationsResponse memory response);
```

### Authorization Functions (v6.7+)

Let a grantee stake on the caller's behalf. See "Scoped Authorizations" in [overview.md](overview.md) for how grants work.

```solidity
// Called by the delegator (granter). Creates delegate, undelegate, and redelegate grants for
// `grantee`, limited to `allowedValidators` (seivaloper1..., at least one) and each capped at
// `maxTokens` usei (must be > 0). `expiration` is Unix seconds, after the current block time.
function grantStakingAuthorization(
    address grantee,
    string[] memory allowedValidators,
    uint256 maxTokens,
    int64 expiration
) external returns (bool success);

// Called by the delegator: remove all three grants
function revokeStakingAuthorization(address grantee) external returns (bool success);

// Called by the grantee. msg.value (from the grantee, whole usei) is delegated for `delegator`.
function delegateWithAuthorization(address delegator, string memory valAddress)
    external payable returns (bool success);

// Called by the grantee. `amount` in usei.
function undelegateWithAuthorization(address delegator, string memory valAddress, uint256 amount)
    external returns (bool success);
function redelegateWithAuthorization(
    address delegator,
    string memory srcAddress,
    string memory dstAddress,
    uint256 amount
) external returns (bool success);
```

The full interface (also `validator`, `validatorDelegations`, `unbondingDelegation`, `redelegations`, `historicalInfo`, `pool`, `params`, `createValidator`, `editValidator`) is in sei-chain at `precompiles/staking/Staking.sol`.

### Events

```solidity
event Delegate(address indexed delegator, string validator, uint256 amount);
event Undelegate(address indexed delegator, string validator, uint256 amount);
event Redelegate(address indexed delegator, string srcValidator, string dstValidator, uint256 amount);
```

## Distribution Precompile Functions

All transaction methods act for the caller (its associated Sei address); rewards and commission are paid to the caller's withdraw address.

```solidity
// Withdraw the caller's rewards from one validator
function withdrawDelegationRewards(string memory validator) external returns (bool success);

// Withdraw the caller's rewards from several validators in one call
function withdrawMultipleDelegationRewards(string[] memory validators) external returns (bool success);

// Withdraw the caller's validator commission (the caller must be the validator operator)
function withdrawValidatorCommission() external returns (bool success);

// Set the address the caller's rewards are paid to
function setWithdrawAddress(address withdrawAddr) external returns (bool success);

// All pending rewards of a delegator: per validator, plus the total
struct Reward { Coin[] coins; string validator_address; }
struct Rewards { Reward[] rewards; Coin[] total; }
function rewards(address delegatorAddress) external view returns (Rewards memory rewards);
```

There is no `withdrawDelegatorReward(address, string)` method — a call with that signature reverts.

### Distribution Authorization Functions (v6.7+)

```solidity
// Called by the delegator/operator (granter): let `grantee` withdraw its delegation rewards
// and validator commission until `expiration` (Unix seconds)
function grantWithdrawAuthorization(address grantee, int64 expiration) external returns (bool success);
function revokeWithdrawAuthorization(address grantee) external returns (bool success);

// Called by the grantee. Funds go to the granter's withdraw address, not to the grantee.
function withdrawDelegationRewardsWithAuthorization(address delegator, string memory validator)
    external returns (bool success);
function withdrawValidatorCommissionWithAuthorization(address validatorOperator)
    external returns (bool success);
```


### Distribution Query Functions

The Distribution precompile (`0x1007`) exposes read-only view methods for inspecting rewards, commission, slashes, and module state (added in the v6.7 upgrade, [sei-chain#3767](https://github.com/sei-protocol/sei-chain/pull/3767)). Validator addresses use the `seivaloper1...` bech32 format; delegator addresses are passed as EVM `address` (must be associated with a Sei address).

```solidity
struct Coin {
    uint256 amount;
    uint256 decimals;
    string denom;
}

struct DistributionParams {
    string communityTax;        // decimal string
    string baseProposerReward;  // decimal string
    string bonusProposerReward; // decimal string
    bool withdrawAddrEnabled;
}

struct Slash {
    uint64 validatorPeriod;
    string fraction; // decimal string
}

// Distribution module parameters
function params() external view returns (DistributionParams memory params);

// Outstanding (un-withdrawn) rewards of a validator and all its delegations
function validatorOutstandingRewards(string memory validatorAddress)
    external view returns (Coin[] memory rewards);

// Accumulated commission of a validator
function validatorCommission(string memory validatorAddress)
    external view returns (Coin[] memory commission);

// Slash events of a validator within a height range (cursor-based pagination)
function validatorSlashes(
    string memory validatorAddress,
    uint64 startingHeight,
    uint64 endingHeight,
    bytes memory pageKey
) external view returns (Slash[] memory slashes, bytes memory nextKey);

// Pending rewards of a single delegation
function delegationRewards(address delegatorAddress, string memory validatorAddress)
    external view returns (Coin[] memory rewards);

// Validators a delegator is delegating to
function delegatorValidators(address delegatorAddress)
    external view returns (string[] memory validators);

// Withdraw address of a delegator (bech32)
function delegatorWithdrawAddress(address delegatorAddress)
    external view returns (string memory withdrawAddress);

// Coins held by the community pool
function communityPool() external view returns (Coin[] memory pool);
```

> **Note:** These are `view` methods — do not send `value`; a non-zero value reverts. They run on a branched context internally, so the reward queriers' period-increment side effects are discarded and never mutate state.

## ethers.js Examples

### Setup

```typescript
import { ethers } from 'ethers';
import {
  STAKING_PRECOMPILE_ADDRESS,
  STAKING_PRECOMPILE_ABI,
  DISTRIBUTION_PRECOMPILE_ADDRESS,
  DISTRIBUTION_PRECOMPILE_ABI,
} from '@sei-js/precompiles';

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
const { balance, delegation } = await staking.delegation(
  await signer.getAddress(),
  validator
);
console.log("Shares:", delegation.shares.toString(), `(${delegation.decimals} decimals)`);
console.log("Balance:", ethers.formatUnits(balance.amount, 6), "SEI"); // balance.amount is usei
```

### Claim Rewards

```typescript
// Acts for the caller; rewards go to the caller's withdraw address
const tx = await distribution.withdrawDelegationRewards(validator);
await tx.wait(1);
console.log("Rewards claimed");
```

### List Validators

```typescript
const { validators, nextKey } = await staking.validators("BOND_STATUS_BONDED", "0x"); // "0x" = first page
for (const v of validators) {
  console.log(v.operatorAddress);
}
// Pass nextKey back in to fetch the next page; it is "0x" after the last page
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
    function withdrawDelegationRewards(string memory validator) external returns (bool);
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
        require(msg.value % 1e12 == 0, "Whole usei only"); // delegate rejects sub-usei wei
        bool success = IStaking(STAKING).delegate{value: msg.value}(validatorAddress);
        require(success, "Delegation failed");
        _mint(msg.sender, msg.value);  // 1:1 initial minting
    }

    // Compound rewards by claiming and re-delegating
    function compound() external {
        // Rewards are paid to this contract's withdraw address (itself by default)
        IDistribution(DISTRIBUTION).withdrawDelegationRewards(validatorAddress);
        uint256 rewards = address(this).balance - (address(this).balance % 1e12);
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
- **Amount precision**: `delegate` → wei (1e18), and `msg.value` must be a multiple of 1e12 wei (whole usei) or the call reverts; `undelegate`/`redelegate` → usei (1e6); `delegation().balance.amount` is usei
