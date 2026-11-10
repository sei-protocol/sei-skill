# Query precompiles (Auth, Authz, Evidence, Mint, Params, Slashing, Upgrade)

Seven precompiles that expose Cosmos module queries to EVM contracts. They are new in the v6.7 upgrade (sei-chain v6.7.0, [sei-chain#3767](https://github.com/sei-protocol/sei-chain/pull/3767)) and live on both mainnet (pacific-1) and testnet (atlantic-2). Every method on this page is a `view` except Slashing's four transaction methods.

- Views run on a branched context (`ctx.CacheContext()`) whose writes are discarded, so queriers with side effects (e.g. auth `nextAccountNumber` increments a counter) stay read-only.
- Sending non-zero `value` to any method reverts.
- Methods taking an `address` require that address to be associated with a Sei address, or the call reverts. The zero address is rejected (`invalid addr`).
- All use dynamic gas.
- The canonical Solidity interfaces are in sei-chain at `precompiles/<module>/<Module>.sol` (e.g. `precompiles/slashing/Slashing.sol`).

> **There is no Feegrant precompile.** v6.7 removed the feegrant module ([sei-chain#3958](https://github.com/sei-protocol/sei-chain/pull/3958)). Nothing is registered at `0x0000000000000000000000000000000000001010`; calls to it return empty data, so a typed call fails to decode.

## Auth — `0x000000000000000000000000000000000000100D`

Interface `IAuth`. Methods:

- `account(address addr)` → `Account{string accountAddress, uint64 accountNumber, uint64 sequence}` — reverts with `account not found` if the associated account does not exist.
- `accounts(bytes pageKey)` → `AccountsResponse{Account[] accounts, bytes nextKey}` — paginated; pass empty bytes for the first page.
- `params()` → `AuthParams{uint64 maxMemoCharacters, uint64 txSigLimit, uint64 txSizeCostPerByte, uint64 sigVerifyCostEd25519, uint64 sigVerifyCostSecp256k1, bool disableSeqnoCheck}`.
- `nextAccountNumber()` → `uint64 count` — view; does not increment the persisted counter.

## Authz — `0x000000000000000000000000000000000000100E`

Interface `IAuthz`. Read-only queries over native authz grants, including the scoped grants that the staking, distribution, gov, and slashing precompiles create with their `grant*Authorization` methods. Authorization fields are returned as JSON-encoded `bytes`. Methods:

- `grants(address granter, address grantee, string msgTypeUrl, bytes pageKey)` → `GrantsResponse{Grant[] grants, bytes nextKey}` where `Grant{bytes authorization, int64 expiration}`. Empty `msgTypeUrl` means no filter; `expiration` is Unix seconds.
- `granterGrants(address granter, bytes pageKey)` → `GrantAuthorizationsResponse{GrantAuthorization[] grants, bytes nextKey}` where `GrantAuthorization{string granter, string grantee, bytes authorization, int64 expiration}`.
- `granteeGrants(address grantee, bytes pageKey)` → same `GrantAuthorizationsResponse`.

## Evidence — `0x000000000000000000000000000000000000100F`

Interface `IEvidence`. Evidence entries are JSON-encoded `bytes`. Methods:

- `evidence(bytes evidenceHash)` → `bytes` — JSON of the evidence with the given hash; reverts if not found.
- `allEvidence(bytes pageKey)` → `AllEvidenceResponse{bytes[] evidenceList, bytes nextKey}` — each entry JSON-encoded.

## Mint — `0x0000000000000000000000000000000000001012`

Interface `IMint`. Methods:

- `params()` → `MintParams{string mintDenom, ScheduledTokenRelease[] tokenReleaseSchedule}` where `ScheduledTokenRelease{string startDate, string endDate, uint64 tokenReleaseAmount}`.
- `minter()` → `Minter{string startDate, string endDate, string denom, uint64 totalMintAmount, uint64 remainingMintAmount, uint64 lastMintAmount, string lastMintDate, uint64 lastMintHeight}`.

## Params — `0x0000000000000000000000000000000000001013`

Interface `IParams`. Method:

- `params(string subspace, string key)` → `string value` — the JSON-encoded parameter value. Reverts for unknown or empty subspace. Example: `params("staking", "MaxValidators")` returns the JSON-encoded uint32.

## Slashing — `0x0000000000000000000000000000000000001014`

Interface `ISlashing`. Time fields are Unix seconds. Unlike the other precompiles on this page, Slashing has four state-mutating transaction methods ([sei-chain#3825](https://github.com/sei-protocol/sei-chain/pull/3825), [sei-chain#3893](https://github.com/sei-protocol/sei-chain/pull/3893)).

Transaction methods. All are non-payable and **cannot** be invoked via `delegatecall` (reverts `cannot delegatecall slashing`) or `staticcall` (reverts `cannot call slashing precompile from staticcall`):

- `unjail()` → `bool success` — unjails the validator whose operator address is the caller's associated Sei address. Reverts if the caller has no associated Sei address or that address is not a validator operator (the slashing module's `MsgUnjail` runs with `sdk.ValAddress(seiAddr)`).
- `grantUnjailAuthorization(address grantee, int64 expiration)` → `bool success` — lets `grantee` unjail the caller's validator until `expiration` (Unix seconds; must be after the current block time). Creates a native authz grant for `MsgUnjail`.
- `unjailWithAuthorization(address validatorOperator)` → `bool success` — called by a grantee to unjail `validatorOperator`'s validator using that grant. Reverts if no unexpired grant exists.
- `revokeUnjailAuthorization(address grantee)` → `bool success` — removes the grant; reverts with `authorization not found` if there is none.

Query methods (all `view`, no state mutation):

- `params()` → `SlashingParams{int64 signedBlocksWindow, string minSignedPerWindow, uint64 downtimeJailDuration, string slashFractionDoubleSign, string slashFractionDowntime}`.
- `signingInfo(string consAddress)` → `SigningInfo{string validatorAddress, int64 startHeight, int64 indexOffset, int64 jailedUntil, bool tombstoned, int64 missedBlocksCounter}` — reverts for unknown or invalid bech32 consensus address.
- `signingInfos(bytes pageKey)` → `SigningInfosResponse{SigningInfo[] signingInfos, bytes nextKey}`.

## Upgrade — `0x0000000000000000000000000000000000001015`

Interface `IUpgrade`. Methods:

- `currentPlan()` → `Plan{string name, int64 height, string info}` — returns a zero-valued plan when none is scheduled.
- `appliedPlan(string name)` → `int64 height` — block height the named upgrade was applied, `0` if never applied (no error).
- `upgradedConsensusState(int64 lastHeight)` → `bytes consensusState` — empty bytes if none stored (no error).
- `moduleVersions(string moduleName)` → `ModuleVersion[]{string name, uint64 version}` — empty `moduleName` returns all modules; a specific name returns one entry and reverts if the module is unknown.

## Example (ethers.js v6)

These methods are new in v6.7, so the example uses human-readable ABI fragments rather than a packaged ABI that may predate them:

```js
import { ethers } from "ethers";

const provider = new ethers.JsonRpcProvider("https://evm-rpc-testnet.sei-apis.com");

const auth = new ethers.Contract(
  "0x000000000000000000000000000000000000100D",
  ["function account(address addr) view returns (tuple(string accountAddress, uint64 accountNumber, uint64 sequence) account)"],
  provider
);
const account = await auth.account("0xYourAssociatedEvmAddress");
console.log(account.accountAddress, account.accountNumber.toString());

const slashing = new ethers.Contract(
  "0x0000000000000000000000000000000000001014",
  ["function params() view returns (tuple(int64 signedBlocksWindow, string minSignedPerWindow, uint64 downtimeJailDuration, string slashFractionDoubleSign, string slashFractionDowntime) params)"],
  provider
);
const p = await slashing.params();
console.log(p.signedBlocksWindow.toString(), p.slashFractionDowntime);
```

## Notes

- Paginated methods take a `bytes pageKey` (empty bytes for the first page) and return a `bytes nextKey` (empty when the final page is reached).
- Fields typed as `bytes` holding authorizations or evidence are JSON encodings of the underlying protobuf `Any`, produced by `codec.MarshalAsJSON`; decode them as JSON (look for the `@type` field), not ABI.
