---
title: Sei Precompiles Overview
description: All Sei precompile addresses, ABI setup with @sei-js/precompiles, and quick interaction patterns.
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
| Oracle | `0x0000000000000000000000000000000000001008` | ❌ Retired (shut off July 2026) — queries revert; use a third-party oracle |
| IBC | `0x0000000000000000000000000000000000001009` | **Do not use** — IBC is disabled in both directions; `transfer` cannot succeed |
| PointerView | `0x000000000000000000000000000000000000100A` | Query pointer registrations |
| Pointer | `0x000000000000000000000000000000000000100B` | Register pointer contracts |
| Solo | `0x000000000000000000000000000000000000100C` | Claim/migrate legacy CW20 and CW721 tokens to EVM |
| Auth | `0x000000000000000000000000000000000000100D` | Query accounts, account numbers, auth params (v6.7+) |
| Authz | `0x000000000000000000000000000000000000100E` | Query authz grants (v6.7+) |
| Evidence | `0x000000000000000000000000000000000000100F` | Query submitted evidence (v6.7+) |
| P256Verify | `0x0000000000000000000000000000000000001011` | Verify P-256 (secp256r1) signatures on-chain |
| Mint | `0x0000000000000000000000000000000000001012` | Query mint params and minter state (v6.7+) |
| Params | `0x0000000000000000000000000000000000001013` | Query any module param by subspace/key (v6.7+) |
| Slashing | `0x0000000000000000000000000000000000001014` | Query signing info/params; `unjail` transactions for validator operators (v6.7+) |
| Upgrade | `0x0000000000000000000000000000000000001015` | Query upgrade plans and module versions (v6.7+) |

> The v6.7 query precompiles (Auth through Upgrade) are documented in [auth-authz-and-query-precompiles.md](auth-authz-and-query-precompiles.md). Slashing is not purely read-only: it also has `unjail()`, `unjailWithAuthorization`, and grant/revoke methods. `0x0000000000000000000000000000000000001010` is unassigned — v6.7 removed the feegrant module, so there is no Feegrant precompile.

> Note: CosmWasm, CosmWasm bridge (Bank, IBC), and Solo precompiles are marked legacy because CosmWasm is deprecated per SIP-3. Bank and the pointer precompiles remain functional for existing integrations. **The IBC precompile does not** — IBC is closed in both directions (Props 116/120 inbound, 121 outbound), so its `transfer` reverts.

## Setup: @sei-js/precompiles

The `@sei-js/precompiles` package provides pre-built ABIs and address constants for all Sei precompiles:

```bash
npm install @sei-js/precompiles
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
  ADDRESS_PRECOMPILE_ADDRESS,
  ADDRESS_PRECOMPILE_ABI,
  BANK_PRECOMPILE_ADDRESS,
  BANK_PRECOMPILE_ABI,
  POINTER_PRECOMPILE_ADDRESS,
  POINTER_PRECOMPILE_ABI,
  POINTERVIEW_PRECOMPILE_ADDRESS,
  POINTERVIEW_PRECOMPILE_ABI,
} from '@sei-js/precompiles';
```

## Quick Interaction Pattern (ethers.js v6)

```typescript
import { ethers } from 'ethers';
import { STAKING_PRECOMPILE_ADDRESS, STAKING_PRECOMPILE_ABI } from '@sei-js/precompiles';

// Setup provider + signer (e.g., from MetaMask)
const provider = new ethers.BrowserProvider(window.ethereum);
const signer = await provider.getSigner();

// Instantiate any precompile as a regular contract
const staking = new ethers.Contract(
  STAKING_PRECOMPILE_ADDRESS,
  STAKING_PRECOMPILE_ABI,
  signer
);

// Call precompile functions (status is a Cosmos BondStatus name; "0x" = first page)
const { validators, nextKey } = await staking.validators("BOND_STATUS_BONDED", "0x");
```

## Quick Interaction Pattern (Viem)

```typescript
import { createWalletClient, custom, getContract } from 'viem';
import { seiTestnet } from 'viem/chains';
import { STAKING_PRECOMPILE_ADDRESS, STAKING_PRECOMPILE_ABI } from '@sei-js/precompiles';

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
    function withdrawDelegationRewards(string memory validator) external returns (bool);
}

contract LiquidStaking {
    address constant STAKING = 0x0000000000000000000000000000000000001005;
    address constant DISTRIBUTION = 0x0000000000000000000000000000000000001007;

    function stakeAndClaimRewards(string memory validator) external payable {
        // Delegate (msg.value must be a whole number of usei: a multiple of 1e12 wei)
        IStaking(STAKING).delegate{value: msg.value}(validator);

        // Claim this contract's pending rewards from that validator
        IDistribution(DISTRIBUTION).withdrawDelegationRewards(validator);
    }
}
```

## Scoped Authorizations (v6.7+)

Since the v6.7 upgrade ([sei-chain#3893](https://github.com/sei-protocol/sei-chain/pull/3893), [sei-chain#3846](https://github.com/sei-protocol/sei-chain/pull/3846)), the Staking, Distribution, Governance, and Slashing precompiles let an account (the **granter**) authorize another EVM account (the **grantee**) to perform a narrow set of actions on its behalf — e.g. a bot that compounds rewards or votes for a DAO treasury. They are thin wrappers over native Cosmos `authz` grants:

1. The granter calls a `grant*Authorization(grantee, …, expiration)` method. `expiration` is Unix seconds and must be after the current block time.
2. The grantee calls the matching `*WithAuthorization(…)` method, naming the granter. The precompile runs the message for the granter through authz `MsgExec`, so it fails without an unexpired grant.
3. The granter calls `revoke*Authorization(grantee)` to remove the grant; it reverts with `authorization not found` if nothing was granted.

| Precompile | Grant (called by granter) | Covers | Grantee calls |
|---|---|---|---|
| Staking `0x1005` | `grantStakingAuthorization(grantee, allowedValidators, maxTokens, expiration)` | Delegate, undelegate, redelegate — only to validators in `allowedValidators` (for redelegation, the destination), each action with its own `maxTokens` (usei) budget that shrinks as it is used | `delegateWithAuthorization`, `undelegateWithAuthorization`, `redelegateWithAuthorization` |
| Distribution `0x1007` | `grantWithdrawAuthorization(grantee, expiration)` | Withdrawing delegation rewards and validator commission | `withdrawDelegationRewardsWithAuthorization`, `withdrawValidatorCommissionWithAuthorization` |
| Governance `0x1006` | `grantVoteAuthorization(grantee, expiration)` / `grantProposalAuthorization(grantee, expiration)` | `MsgVote` only (not weighted votes) / `MsgSubmitProposal` only (not deposits) | `voteWithAuthorization`, `submitProposalWithAuthorization` |
| Slashing `0x1014` | `grantUnjailAuthorization(grantee, expiration)` | `MsgUnjail` | `unjailWithAuthorization` |

Rules for all of them:

- Granter, grantee, and the account acted for must be associated EVM addresses; the zero address is rejected.
- All are non-payable except `delegateWithAuthorization` and `submitProposalWithAuthorization`: their `msg.value`, sent by the grantee, funds the delegation or initial deposit made for the granter (whole usei only).
- Withdrawn rewards and commission go to the granter's withdraw address, never to the grantee.
- Like the precompiles' other transaction methods, they cannot be called via `delegatecall` or `staticcall`.
- The grants are ordinary authz grants: inspect them with the Authz precompile (`0x100E`) or `seid q authz grants <granter-sei1-address> <grantee-sei1-address>`.

Method signatures are on each precompile's page: [staking-distribution.md](staking-distribution.md), [governance.md](governance.md), [auth-authz-and-query-precompiles.md](auth-authz-and-query-precompiles.md) (Slashing).

## Reference for Each Precompile

- **Staking + Distribution:** [staking-distribution.md](staking-distribution.md)
- **Governance:** [governance.md](governance.md)
- **JSON + P256:** [json-p256.md](json-p256.md)
- **Auth, Authz, Evidence, Mint, Params, Slashing, Upgrade:** [auth-authz-and-query-precompiles.md](auth-authz-and-query-precompiles.md)
- **Addr, Bank, CosmWasm, IBC, Pointer, PointerView:** [cosmwasm-bridge.md](cosmwasm-bridge.md)
- **Oracle:** See [oracles.md](../ecosystem/oracles.md#native-oracle-precompile)

## Important Notes

1. **Units differ by parameter** — `msg.value` is wei (`1 SEI = 1e18 wei`). The staking, governance, and CosmWasm payable methods require a whole number of usei (a multiple of `1e12` wei) and revert otherwise; Bank `sendNative` accepts any wei amount. Some `uint256` amount parameters are usei (`1 SEI = 1e6 usei`), e.g. staking `undelegate`/`redelegate`. Check each method's page
2. **Precompiles are only available on Sei** — unit tests without fork testing will fail when calling precompile addresses; use `--fork-url` in Foundry or `forking` in Hardhat
3. **Events are emitted** — all precompiles emit events for indexing; use `eth_getLogs` or The Graph
4. **No approval needed** — precompiles don't use ERC20 approve patterns; value is passed as `msg.value` (payable) or directly as parameters
