---
title: Sei Precompiles Overview
description: All Sei precompile addresses, ABI setup with @sei-js/evm, and quick interaction patterns.
---

# Sei Precompiles Overview

Precompiles are fixed-address contracts deployed by the Sei protocol that expose native chain logic to EVM applications. They behave like regular contracts from Solidity/ethers.js perspective but execute privileged native code efficiently.

## Complete Address Reference

| Precompile | Address | Purpose |
|---|---|---|
| Bank | `0x0000000000000000000000000000000000001001` | Native token sends from EVM contracts |
| CosmWasm | `0x0000000000000000000000000000000000001002` | Execute CosmWasm contracts from EVM (legacy) |
| JSON | `0x0000000000000000000000000000000000001003` | On-chain JSON parsing |
| Addr | `0x0000000000000000000000000000000000001004` | Address conversion + association |
| Staking | `0x0000000000000000000000000000000000001005` | Delegate/undelegate/redelegate SEI |
| Governance | `0x0000000000000000000000000000000000001006` | Vote, submit proposals, deposit |
| Distribution | `0x0000000000000000000000000000000000001007` | Claim staking rewards |
| Oracle | `0x0000000000000000000000000000000000001008` | On-chain price feed data |
| IBC | `0x0000000000000000000000000000000000001009` | IBC transfers from EVM (legacy) |
| PointerView | `0x000000000000000000000000000000000000100A` | Query pointer registrations |
| Pointer | `0x000000000000000000000000000000000000100B` | Register pointer contracts |

> Note: CosmWasm, Bank (for CW use), and IBC precompiles are marked legacy because CosmWasm is deprecated per SIP-3. They remain functional for existing integrations.

## Setup: @sei-js/evm

The `@sei-js/evm` package provides pre-built ABIs and address constants for all Sei precompiles:

```bash
npm install @sei-js/evm
```

```typescript
import {
  STAKING_PRECOMPILE_ADDRESS,
  STAKING_PRECOMPILE_ABI,
  GOVERNANCE_PRECOMPILE_ADDRESS,
  GOVERNANCE_PRECOMPILE_ABI,
  DISTRIBUTION_PRECOMPILE_ADDRESS,
  DISTRIBUTION_PRECOMPILE_ABI,
  ORACLE_PRECOMPILE_ADDRESS,
  ORACLE_PRECOMPILE_ABI,
  JSON_PRECOMPILE_ADDRESS,
  JSON_PRECOMPILE_ABI,
  ADDR_PRECOMPILE_ADDRESS,
  ADDR_PRECOMPILE_ABI,
  BANK_PRECOMPILE_ADDRESS,
  BANK_PRECOMPILE_ABI,
  POINTER_PRECOMPILE_ADDRESS,
  POINTER_PRECOMPILE_ABI,
  POINTERVIEW_PRECOMPILE_ADDRESS,
  POINTERVIEW_PRECOMPILE_ABI,
} from '@sei-js/evm';
```

## Quick Interaction Pattern (ethers.js v6)

```typescript
import { ethers } from 'ethers';
import { STAKING_PRECOMPILE_ADDRESS, STAKING_PRECOMPILE_ABI } from '@sei-js/evm';

// Setup provider + signer (e.g., from MetaMask)
const provider = new ethers.BrowserProvider(window.ethereum);
const signer = await provider.getSigner();

// Instantiate any precompile as a regular contract
const staking = new ethers.Contract(
  STAKING_PRECOMPILE_ADDRESS,
  STAKING_PRECOMPILE_ABI,
  signer
);

// Call precompile functions
const validators = await staking.validators("BONDED", 10, "");
```

## Quick Interaction Pattern (Viem)

```typescript
import { createWalletClient, custom, getContract } from 'viem';
import { seiTestnet } from '@sei-js/evm';
import { STAKING_PRECOMPILE_ADDRESS, STAKING_PRECOMPILE_ABI } from '@sei-js/evm';

const walletClient = createWalletClient({
  chain: seiTestnet,
  transport: custom(window.ethereum),
});

const staking = getContract({
  address: STAKING_PRECOMPILE_ADDRESS,
  abi: STAKING_PRECOMPILE_ABI,
  client: walletClient,
});
```

## Quick Interaction Pattern (Solidity)

```solidity
// In your contract — call precompiles at their fixed addresses
pragma solidity ^0.8.28;

interface IStaking {
    function delegate(string memory validatorAddress) external payable returns (bool);
}

interface IDistribution {
    function withdrawDelegatorReward(
        address delegatorAddress,
        string memory validatorAddress
    ) external returns (bool);
}

contract LiquidStaking {
    address constant STAKING = 0x0000000000000000000000000000000000001005;
    address constant DISTRIBUTION = 0x0000000000000000000000000000000000001007;

    function stakeAndClaimRewards(string memory validator) external payable {
        // Delegate
        IStaking(STAKING).delegate{value: msg.value}(validator);

        // Claim pending rewards
        IDistribution(DISTRIBUTION).withdrawDelegatorReward(address(this), validator);
    }
}
```

## Reference for Each Precompile

- **Staking + Distribution:** [staking-distribution.md](staking-distribution.md)
- **Governance:** [governance.md](governance.md)
- **JSON + P256:** [json-p256.md](json-p256.md)
- **Addr, Bank, CosmWasm, IBC, Pointer, PointerView:** [cosmwasm-bridge.md](cosmwasm-bridge.md)
- **Oracle:** See [oracles.md](../oracles.md#native-oracle-precompile)

## Important Notes

1. **Amounts in wei (18 decimals)** — `1 SEI = 1e18 wei`; always convert amounts accordingly
2. **Precompiles are only available on Sei** — unit tests without fork testing will fail when calling precompile addresses; use `--fork-url` in Foundry or `forking` in Hardhat
3. **Events are emitted** — all precompiles emit events for indexing; use `eth_getLogs` or The Graph
4. **No approval needed** — precompiles don't use ERC20 approve patterns; value is passed as `msg.value` (payable) or directly as parameters
