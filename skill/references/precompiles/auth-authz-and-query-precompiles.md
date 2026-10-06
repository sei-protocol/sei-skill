# Query precompiles (Auth, Authz, Evidence, Feegrant, Mint, Params, Slashing, Upgrade)

Eight view-only precompiles that expose Cosmos module queries to EVM contracts. All are registered in the fail-fast precompile address list and in `GetCustomPrecompiles`. All methods are `view` (no state mutation): `IsTransaction` returns `false` for every method. Each precompile branches the context (`ctx.CacheContext()`) before running a view and discards the writes, so queriers with side effects (e.g. auth `nextAccountNumber` increments a counter) stay read-only. Sending non-zero `value` to any method reverts (`ValidateNonPayable`). Methods taking an `address` require the address to be associated with a Sei address, or the call reverts.

All use dynamic gas (`pcommon.NewDynamicGasPrecompile`). First shipped at version `v6.6`.

## Auth — `0x000000000000000000000000000000000000100D`

Interface `IAuth`. Methods:

- `account(address addr)` → `Account{string accountAddress, uint64 accountNumber, uint64 sequence}` — reverts with `account not found` if the associated account does not exist.
- `accounts(bytes pageKey)` → `AccountsResponse{Account[] accounts, bytes nextKey}` — paginated; pass empty bytes for the first page.
- `params()` → `AuthParams{uint64 maxMemoCharacters, uint64 txSigLimit, uint64 txSizeCostPerByte, uint64 sigVerifyCostEd25519, uint64 sigVerifyCostSecp256k1, bool disableSeqnoCheck}`.
- `nextAccountNumber()` → `uint64 count` — view; does not increment the persisted counter.

## Authz — `0x000000000000000000000000000000000000100E`

Interface `IAuthz`. Authorization fields are returned as JSON-encoded `bytes`. Methods:

- `grants(address granter, address grantee, string msgTypeUrl, bytes pageKey)` → `GrantsResponse{Grant[] grants, bytes nextKey}` where `Grant{bytes authorization, int64 expiration}`. Empty `msgTypeUrl` means no filter; `expiration` is Unix seconds.
- `granterGrants(address granter, bytes pageKey)` → `GrantAuthorizationsResponse{GrantAuthorization[] grants, bytes nextKey}` where `GrantAuthorization{string granter, string grantee, bytes authorization, int64 expiration}`.
- `granteeGrants(address grantee, bytes pageKey)` → same `GrantAuthorizationsResponse`.

## Evidence — `0x000000000000000000000000000000000000100F`

Interface `IEvidence`. Evidence entries are JSON-encoded `bytes`. Methods:

- `evidence(bytes evidenceHash)` → `bytes` — JSON of the evidence with the given hash; reverts if not found.
- `allEvidence(bytes pageKey)` → `AllEvidenceResponse{bytes[] evidenceList, bytes nextKey}` — each entry JSON-encoded.

## Feegrant — `0x0000000000000000000000000000000000001010`

Interface `IFeegrant`. The `allowance` field of each grant is JSON-encoded `bytes`. Methods:

- `allowance(address granter, address grantee)` → `Grant{string granter, string grantee, bytes allowance}` — reverts with `no allowance found` if none exists.
- `allowances(address grantee, bytes pageKey)` → `AllowancesResponse{Grant[] allowances, bytes nextKey}`.
- `allowancesByGranter(address granter, bytes pageKey)` → same `AllowancesResponse`.

## Mint — `0x0000000000000000000000000000000000001012`

Interface `IMint`. Methods:

- `params()` → `MintParams{string mintDenom, ScheduledTokenRelease[] tokenReleaseSchedule}` where `ScheduledTokenRelease{string startDate, string endDate, uint64 tokenReleaseAmount}`.
- `minter()` → `Minter{string startDate, string endDate, string denom, uint64 totalMintAmount, uint64 remainingMintAmount, uint64 lastMintAmount, string lastMintDate, uint64 lastMintHeight}`.

## Params — `0x0000000000000000000000000000000000001013`

Interface `IParams`. Method:

- `params(string subspace, string key)` → `string value` — the JSON-encoded parameter value. Reverts for unknown or empty subspace. Example: `params("staking", "MaxValidators")` returns the JSON-encoded uint32.

## Slashing — `0x0000000000000000000000000000000000001014`

Interface `ISlashing`. Time fields are Unix seconds. Methods:

- `params()` → `SlashingParams{int64 signedBlocksWindow, string minSignedPerWindow, uint64 downtimeJailDuration, string slashFractionDoubleSign, string slashFractionDowntime}`.
- `signingInfo(string consAddress)` → `SigningInfo{string validatorAddress, int64 startHeight, int64 indexOffset, int64 jailedUntil, bool tombstoned, int64 missedBlocksCounter}` — reverts for unknown or invalid bech32 consensus address.
- `signingInfos(bytes pageKey)` → `SigningInfosResponse{SigningInfo[] signingInfos, bytes nextKey}`.

## Upgrade — `0x0000000000000000000000000000000000001015`

Interface `IUpgrade`. Methods:

- `currentPlan()` → `Plan{string name, int64 height, string info}` — returns a zero-valued plan when none is scheduled.
- `appliedPlan(string name)` → `int64 height` — block height the named upgrade was applied, `0` if never applied (no error).
- `upgradedConsensusState(int64 lastHeight)` → `bytes consensusState` — empty bytes if none stored (no error).
- `moduleVersions(string moduleName)` → `ModuleVersion[]{string name, uint64 version}` — empty `moduleName` returns all modules; a specific name returns one entry and reverts if the module is unknown.

## Example (ethers.js)

```js
const auth = new ethers.Contract(
  "0x000000000000000000000000000000000000100D",
  IAuthAbi,
  provider
);
const account = await auth.account("0xYourEvmAddress");
console.log(account.accountAddress, account.accountNumber.toString());

const slashing = new ethers.Contract(
  "0x0000000000000000000000000000000000001014",
  ISlashingAbi,
  provider
);
const p = await slashing.params();
console.log(p.signedBlocksWindow.toString(), p.slashFractionDowntime);
```

## Notes

- Paginated methods take a `bytes pageKey` (empty bytes for the first page) and return a `bytes nextKey` (empty when the final page is reached).
- Fields typed as `bytes` holding authorizations, allowances, or evidence are JSON encodings of the underlying protobuf `Any`, produced by `codec.MarshalAsJSON`; decode them as JSON (look for the `@type` field), not ABI.
- Each precompile package exposes its address constant in Go (e.g. `auth.AuthAddress`, `authz.AuthzAddress`, `evidence.EvidenceAddress`, `feegrant.FeegrantAddress`, `mint.MintAddress`, `params.ParamsAddress`, `slashing.SlashingAddress`, `upgrade.UpgradeAddress`).
