---
title: seid CLI Reference
description: seid command-line tool — setup, wallet management, EVM queries, payload generation, pointer lookups, transaction commands, and raw JSON-RPC access via curl.
---

# seid CLI Reference

When interacting with Sei chains, prefer `seid` commands. Do not substitute generic EVM tooling unless the user explicitly asks for it.

## Setup

Only run setup when `seid` is not already installed and the task requires local CLI execution.

```bash
# 1 — Clone
git clone https://github.com/sei-protocol/sei-chain
cd sei-chain

# 2 — Check out a version (do not invent one — verify against docs or release notes)
git checkout <VERSION>

# 3 — Build and confirm
make install
seid version
```

Requirements:
- Go 1.24.x required. Run `go version` to confirm.
- If `seid` is not found after install: run `go env GOPATH` and ensure `$GOPATH/bin` is on `PATH`.

## Network Reference

| Network | Cosmos chain ID | EVM chain ID |
|---|---|---|
| Mainnet | `pacific-1` | `1329` |
| Testnet | `atlantic-2` | `1328` |

Flag rules:
- Most `seid q evm` commands need `--node http://<cosmos-rpc>` when not running a local node.
- `seid q evm tx` is the exception — it uses `--evm-rpc <evm-rpc>`, not `--node`.
- Never mix `--node` and `--evm-rpc` in the same command.

## Wallet Management

```bash
# Create a new wallet (outputs 24-word seed phrase — store securely)
seid keys add <name>

# Recover from existing mnemonic (CLI prompts locally — never paste mnemonic into chat)
seid keys add <name> --recover

# Create EVM-compatible wallet (coin type 60, MetaMask-style)
seid keys add <name> --coin-type=60

# Recover EVM wallet from MetaMask mnemonic
seid keys add <name> --coin-type=60 --recover

# List all local keys
seid keys list

# Show one key
seid keys show <name>

# Delete a key
seid keys delete <name>
```

Use coin type `118` (default) for standard Cosmos workflows; `60` for EVM/MetaMask compatibility.

## Queries

### Address Mapping

Sei and EVM addresses are linked via on-chain associations. Both directions are queryable.

```bash
# EVM → Sei
seid q evm sei-addr 0x1234... --node http://<cosmos-rpc>

# Sei → EVM
seid q evm evm-addr sei1... --node http://<cosmos-rpc>
```

Response includes `associated: true/false` indicating whether the accounts are linked.

### ERC20 Reads

```bash
seid q evm erc20 <contract> name       --node http://<cosmos-rpc>
seid q evm erc20 <contract> symbol     --node http://<cosmos-rpc>
seid q evm erc20 <contract> decimals   --node http://<cosmos-rpc>
seid q evm erc20 <contract> totalSupply --node http://<cosmos-rpc>
seid q evm erc20 <contract> balanceOf  <address>           --node http://<cosmos-rpc>
seid q evm erc20 <contract> allowance  <owner> <spender>   --node http://<cosmos-rpc>
```

### Payload Generation

Encodes calldata without broadcasting — use to build payloads for `call-contract` or external signing.

```bash
# ERC20
seid q evm erc20-payload transfer    <recipient> <amount-in-wei>
seid q evm erc20-payload approve     <spender>   <amount-in-wei>
seid q evm erc20-payload transferFrom <from> <to> <amount-in-wei>

# ERC721
seid q evm erc721-payload approve           <spender>  <token-id>
seid q evm erc721-payload transferFrom      <from> <to> <token-id>
seid q evm erc721-payload setApprovalForAll <operator> true|false

# ERC1155
seid q evm erc1155-payload safeTransferFrom      <from> <to> <id> <amount> <data>
seid q evm erc1155-payload safeBatchTransferFrom <from> <to> [id1,id2] [amt1,amt2] <data>
seid q evm erc1155-payload setApprovalForAll     <operator> true|false

# Custom ABI
seid q evm payload ./MyContract.json <methodName> [args...]
```

Pass amounts in the token's smallest unit. For ERC1155 batch operations use square-bracket arrays: `[123,456]`.

### Pointer System

Pointer contracts bridge assets between EVM and Cosmos environments. Each original asset can have at most one pointer per type.

```bash
# Look up the pointer for an original asset
seid q evm pointer <type> <pointee> --node http://<cosmos-rpc>

# Look up the original asset for a pointer address
seid q evm pointee <type> <pointer> --node http://<cosmos-rpc>

# Check the current pointer version (and stored code ID for CW-backed pointers)
seid q evm pointer-version <type> --node http://<cosmos-rpc>
```

Supported types:

| Command | Supported types |
|---|---|
| `pointer` | `NATIVE` `CW20` `CW721` `CW1155` `ERC20` `ERC721` `ERC1155` |
| `pointee` | `NATIVE` `CW20` `CW721` `ERC20` `ERC721` |
| `pointer-version` | `NATIVE` `CW20` `CW721` `CW1155` `ERC20` `ERC721` `ERC1155` |

Note: `pointee` does not support `CW1155` or `ERC1155`.

### Transaction Lookup

```bash
seid q evm tx <0x-hash> --evm-rpc https://evm-rpc.sei-apis.com
```

Returns standard Ethereum transaction fields. Uses `--evm-rpc`, not `--node`.

## Transactions

All transaction commands require a funded key in the local keyring (`--from`).

### Common Flags

| Flag | Purpose | Default |
|---|---|---|
| `--from <name>` | Signing key | Required |
| `--gas-fee-cap <gwei>` | Gas price ceiling | 1000 gwei (varies) |
| `--gas-limit <n>` | Execution limit | Command-dependent |
| `--evm-rpc <url>` | RPC endpoint | http://localhost:8545 |
| `--nonce <n>` | Override sequence number | Auto-calculated |
| `--value <wei>` | SEI to attach | 0 |

### Default Gas Limits by Command

| Command | Default gas |
|---|---|
| `send` (native) | 21,000 |
| `erc20-send` | 7,000,000 |
| `deploy` | 5,000,000 |
| `call-contract` | 7,000,000 |
| `call-precompile` | 7,000,000 |

### Commands

```bash
# Associate a Sei address with an EVM address
seid tx evm associate-address [optional-priv-key-hex] --from <name> --evm-rpc <url>

# Send native SEI (amount in wei)
seid tx evm send <to-evm-addr> <amount-wei> --from <name> --gas-fee-cap <cap> --gas-limit <limit>

# Send ERC20 tokens
seid tx evm erc20-send <contract> <recipient> <amount> --from <name>

# Deploy a contract
seid tx evm deploy <path-to-binary> --from <name>

# Call a contract with pre-encoded payload
seid tx evm call-contract <addr> <payload-hex> --value <wei> --from <name>

# Call a precompile by name and method
seid tx evm call-precompile <precompile-name> <method> [args...]
```

Available precompile names: `distribution`, `json`, `p256`, `staking`. See [EVM Precompiles](https://docs.sei.io/evm/precompiles) for method signatures.

## curl and JSON-RPC

Use `curl` when the user wants raw EVM RPC access, debug methods, or JSON-RPC examples. Use `seid` for everything else.

```bash
EVM_RPC="https://evm-rpc.sei-apis.com"

# Transaction by hash
curl -s "$EVM_RPC" \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_getTransactionByHash","params":["0x..."],"id":1}' | jq

# Submit a signed raw transaction
curl -s "$EVM_RPC" \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_sendRawTransaction","params":["0x<signed-raw-tx>"],"id":1}' | jq

# Read contract state (eth_call)
curl -s "$EVM_RPC" \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_call","params":[{"to":"0xtoken...","data":"0x70a08231000000000000000000000000<address-no-0x>"},"latest"],"id":1}' | jq

# Debug trace (only if the RPC exposes debug methods)
curl -s "$EVM_RPC" \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"debug_traceTransaction","params":["0x...",{}],"id":1}' | jq
```

Decode helpers:
- `jq` — inspect JSON-RPC responses.
- `cast to-dec <hex>` — convert hex quantities (balances, gas, block numbers).
- `cast abi-decode "<sig>" <hex>` — decode `eth_call` return data.

For writes: sign first, then submit via `eth_sendRawTransaction`. Prefer a wallet, `cast send`, or another signing tool over hand-crafting RLP.

### Sei-Specific JSON-RPC Behaviour

- **Finality:** `safe`, `finalized`, and `latest` are equivalent on Sei (instant single-block finality).
- **Proofs:** Sei uses IAVL trees, not Merkle Patricia Tries. Proofs returned by proof-bearing endpoints are IAVL proofs. `eth_getProof` now unwraps additional KVStore wrappers (`cachekv`, Giga cache, `tracekv`, and prefix stores) to reach the underlying proof-capable queryable store, so it succeeds across more node/store configurations (classic IAVL, store/v2 memiavl, and future proof-capable roots) rather than only classic IAVL. If no proof-capable store can be found it errors with `cannot find a proof-capable queryable KV store`.
- **`eth_getBlockByNumber` for future/unknown heights:** A numeric block number above the node's safe latest watermark (non-existent/future height) returns `result: null`, matching the Ethereum JSON-RPC spec — not a JSON-RPC error. (Previously this returned error `-32000`, e.g. `requested height 1000 is not yet available; safe latest is 128`.)


- **`eth_getTransactionByBlockHashAndIndex` / `eth_getTransactionByBlockNumberAndIndex` for out-of-range index:** (v6.5) An index beyond the number of transactions in the block returns `result: null`, matching the Ethereum JSON-RPC spec — instead of erroring or returning unexpected data as in earlier versions.
- **Filter limits:** Open-ended log queries return up to 10,000 logs; closed-range queries cover up to 2,000 blocks.
- **Deprecated + gated:** `sei_*` and `sei2_*` namespaced methods are deprecated and scheduled for removal — migrate to standard `eth_*` and `debug_*` methods. They are gated by the `[evm].enabled_legacy_sei_apis` list in `app.toml` (env/flag `evm.enabled_legacy_sei_apis`). Only methods named in that list are served on the EVM HTTP endpoint. `seid init` / defaults enable **only three helpers**: `sei_getSeiAddress`, `sei_getEVMAddress`, `sei_getCosmosTx`. Every other gated `sei_*` / `sei2_*` method — and any unknown `sei_*` name (fails closed) — returns HTTP 200 with a JSON-RPC error (`code: -32601`, `data: "legacy_sei_deprecated"`) unless explicitly allowlisted. To enable a legacy method, add its exact name to `enabled_legacy_sei_apis` under `[evm]`. Successful allowlisted responses set the `Sei-Legacy-RPC-Deprecation` HTTP header (JSON body unchanged) as a deprecation signal.
- **`sei2_*` namespace:** Seven block-related methods (`sei2_getBlockByHash`, `sei2_getBlockByNumber`, `sei2_getBlockReceipts`, `sei2_getBlockTransactionCountByHash`, `sei2_getBlockTransactionCountByNumber`, plus `*ExcludeTraceFail` variants) mirror the `sei` block payloads but include bank transfers (HTTP only). There is no `sei2` transaction or filter API. These are gated by the same allowlist and off by default.
- **`debug_traceTransaction`:** Only available if the RPC node exposes debug methods. If unavailable, fall back to standard RPC queries.


- **`debug_traceTransactionProfile`:** Sei-specific debug method (`debug_traceTransactionProfile(hash, config)`, only when the node exposes debug methods). Returns the standard transaction trace plus a `profile` object for latency analysis. Params: transaction hash and a trace config object (same shape as `debug_traceTransaction`, e.g. `{"timeout":"60s"}`; pass `{}` for defaults). Response shape:
  - `trace` — the normal trace result (identical to `debug_traceTransaction`).
  - `profile.totalNanos` — total time spent handling the request.
  - `profile.historicalDbLookupNanos` — time spent in historical DB lookups (sum of `get`/`has`/`iterator`/`iteratorNext` store access nanos).
  - `profile.otherNanos` — `totalNanos` minus historical-lookup and execution time.
  - `profile.phases` — per-phase timings: `lookupTransactionNanos`, `loadBlockNanos`, `replayHistoricalTxsNanos`, `buildBlockContextNanos`, `prepareTxNanos`, `executionNanos`, `traceResultNanos`.
  - `profile.store.modules.<module>` — per-module store access with `stats` (per-op `count`/`totalNanos` for `get`/`has`/`set`/`delete`/`iterator`/`iteratorNext`/`iteratorValue`) and `iterators` (each with `start`, `end`, `ascending`, sampled `keys`, `nextCount`, `totalNanos`, `truncated`). Per-tx sampling is capped (16 iterators, 64 keys each) to bound the response size; overflow sets `truncated: true`.

  ```bash
  curl -s "$EVM_RPC" \
    -H 'Content-Type: application/json' \
    --data '{"jsonrpc":"2.0","method":"debug_traceTransactionProfile","params":["0x...",{"timeout":"60s"}],"id":1}' | jq
  ```

  To batch this across a block range and produce aggregate reports, use the `seidb trace-profile-report` command (writes `raw_profiles.jsonl` + `summary.json`):

  ```bash
  seidb trace-profile-report \
    --endpoint http://localhost:8545 \
    --start-block 100 --end-block 200 \
    -o ./trace-report \
    -c 4 \
    --trace-config-json '{}' \
    --max-transactions 0
  ```

  Flags: `--endpoint` (RPC URL, required), `--start-block`/`--end-block` (positive block numbers, required), `--output-dir`/`-o` (output directory, required), `--concurrency`/`-c` (concurrent requests, default 4), `--trace-config-json` (JSON trace config, default `{}`), `--max-transactions` (optional cap, `0` = no cap).


### seidb FlatKV Import (memiavl → FlatKV migration)

Offline tooling for migrating the EVM module's SC-layer data from memiavl into FlatKV storage. Run these only while `seid` is stopped (they open the node's data directory directly).

#### `seidb memiavl-latest-version`

Read-only. Prints the latest committed memiavl version of a stopped node. Use it to pick a single, uniform import height across a multi-validator cluster.

```bash
seidb memiavl-latest-version --data-dir /root/.sei/data
```

Flags:
- `--home` — Sei home directory. Defaults to `$HOME/.sei`.
- `--data-dir` — Sei data directory or home directory. If the basename is `data`, its parent is used as home.

#### `seidb import-flatkv-from-memiavl`

Imports selected memiavl modules into FlatKV. Initial production scope is **evm-only** — any other module name is rejected. This is a restore-style import: it **resets FlatKV** before loading the imported rows and refuses to run over existing committed FlatKV data unless `--force` is supplied.

```bash
seidb import-flatkv-from-memiavl --modules=evm --data-dir /root/.sei/data --height <h>

# Overwrite an existing committed FlatKV store
seidb import-flatkv-from-memiavl --modules=evm --data-dir /root/.sei/data --height <h> --force
```

Flags:
- `--home` — Sei home directory. Defaults to `$HOME/.sei`.
- `--data-dir` — Sei data directory or home directory. If the basename is `data`, its parent is used as home.
- `--modules` — Comma-separated module names to import. Default `evm`; only `evm` is supported in the initial scope.
- `--height` — memiavl version to import. `0` means latest.
- `--force` — overwrite existing committed FlatKV data.

**Import must run at the memiavl latest height.** If `--height H` is below the latest committed memiavl version, the command refuses to run: a subsequent `GIGA_STORAGE` startup would call `CompositeCommitStore.reconcileVersions` and silently roll memiavl back to `H`, truncating every cosmos block in `(H, latest]`. To import at an older `H`, first roll memiavl back to `H` yourself (`seid rollback`), then re-run the import. A height above latest is also rejected. Use `seidb memiavl-latest-version` to determine the correct height. On failure the import aborts without finalizing, so FlatKV is left at its pre-import version and can be retried without `--force`.

#### Post-import startup constraints (MigrateEVM V0 → V1)

The import moves only SC-layer EVM data into FlatKV; SS history for EVM stays in the existing combined cosmos pebbledb. Across the import boundary, keep the following in `app.toml` to avoid AppHash / startup panics:
- `evm-ss-split = false` — otherwise rootmulti panics with `EVM SS directory ... does not exist but Cosmos SS already has history`.
- `sc-enable-lattice-hash = false` — turning it on would fold the FlatKV LtHash into the AppHash and fail the replay check (`state.AppHash does not match AppHash after replay`). `dual_write` does not require lattice hash; only `split_write` does.

See `sei-db/state_db/sc/migration/OPERATIONS.md` for the full operational roadmap.

## Agent Workflow

1. Classify the task: install · wallet · read query · payload generation · pointer lookup · tx lookup · transaction submission · raw JSON-RPC.
2. Determine the correct endpoint type: `--node` for `seid q evm` queries, `--evm-rpc` for `seid q evm tx` and transaction commands, `curl` for raw JSON-RPC.
3. Provide the exact `seid` subcommand. Return command output directly, then explain only Sei-specific nuance.
4. If behaviour may be version-dependent, check the [Sei changelog](https://docs.sei.io/evm/changelog) before making claims.

## Rules

- Prefer `seid` over generic Ethereum examples when the user explicitly wants Sei CLI help.
- Never guess flag names or endpoint types.
- Always append `--node` for `seid q evm` commands when the user is not running a local node — except `seid q evm tx`.
- Never use `--node` for `seid q evm tx`; use `--evm-rpc`.
- Use `curl` for raw EVM RPC only when the user wants JSON-RPC access or debug methods.
- Do not install or build `seid` unless setup is required for the task.
- Never ask the user to paste a mnemonic into chat — the CLI prompts locally.
- For unknown flags or subcommand details, use `seid --help` or `seid <subcommand> --help`.

## References

- Install and wallet basics: https://docs.sei.io/evm/installing-seid-cli
- EVM queries and payload generation: https://docs.sei.io/evm/querying-the-evm
- EVM transactions: https://docs.sei.io/evm/transactions-with-seid
- Pointer contracts (conceptual): https://docs.sei.io/learn/pointers
- JSON-RPC reference: https://docs.sei.io/evm/reference
- Release changes: https://docs.sei.io/evm/changelog
