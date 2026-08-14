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
- **Proofs:** Sei stores state in SeiDB state-commit (SC), a memiavl-based tree, not Merkle Patricia Tries. The legacy IAVL backend has been fully removed and SeiDB SC is mandatory — a node started with `sc-enable = false` panics with `SeiDB state-commit (SC) must be enabled; IAVL backend has been fully deprecated`. Proofs returned by proof-bearing endpoints are IAVL-style (memiavl) proofs, not Merkle Patricia Trie proofs.


- **`eth_getProof` storage keys:** Each storage key in an `eth_getProof` request must be a valid hex-encoded value (e.g. a 32-byte slot like `0x0000000000000000000000000000000000000000000000000000000000000001`). Keys are decoded as hex hashes — malformed (non-hex) keys are rejected with an error such as `invalid storage key "..."` rather than being silently interpreted as raw bytes. A single request may include at most `1024` storage keys (`MaxStorageKeysPerProof`); exceeding this returns `too many storage keys: got <n>, max 1024`.
- **Filter limits:** Open-ended log queries return up to 10,000 logs; closed-range queries cover up to 2,000 blocks.
- **Deprecated:** `sei_*` and `sei2_*` namespaced methods (EVM HTTP only) are deprecated and scheduled for removal — migrate to standard `eth_*` and `debug_*` methods. The `sei2_*` namespace is block-only (same block shape as `sei` blocks, with bank transfers included in block payloads): seven methods (`sei2_getBlockByHash`, `sei2_getBlockByNumber`, `sei2_getBlockReceipts`, `sei2_getBlockTransactionCountByHash`, `sei2_getBlockTransactionCountByNumber`, and the `*ExcludeTraceFail` variants); there is no `sei2` transaction or filter API.
- **Removed block-trace endpoints:** As of v6.6.0 the `sei_traceBlockByNumberExcludeTraceFail` and `sei_traceBlockByHashExcludeTraceFail` JSON-RPC endpoints are fully removed — not merely deprecated or gated. They no longer exist in the EVM RPC server and have been dropped from the `enabled_legacy_sei_apis` allowlist; adding them there has no effect. Use the standard `debug_traceBlockByNumber` and `debug_traceBlockByHash` endpoints instead.
- **Legacy `sei_*` / `sei2_*` gating:** These gated methods are governed by the `[evm].enabled_legacy_sei_apis` allowlist in `app.toml` (also settable via the `evm.enabled_legacy_sei_apis` AppOptions flag). The `seid init` / default allowlist enables only three methods: `sei_getSeiAddress`, `sei_getEVMAddress`, `sei_getCosmosTx`; any other gated `sei_*` / `sei2_*` method must be added to the list explicitly. All responses return HTTP 200. A call to a gated method not on the allowlist returns a JSON-RPC error with code `-32601` and `data` `"legacy_sei_deprecated"` (message explains the method is not enabled and the surface is deprecated). Allowed calls pass through with an unchanged JSON body but may set the HTTP response header `Sei-Legacy-RPC-Deprecation`.
- **`debug_traceTransaction`:** Only available if the RPC node exposes debug methods. If unavailable, fall back to standard RPC queries.



## seidb Tool

`seidb` is the SeiDB maintenance/analysis tool (built from `sei-db/tools/cmd/seidb`). Use it for inspecting on-disk state stores — not for chain queries. Two commands cover FlatKV analysis.

### dump-flatkv

Iterates a FlatKV store and dumps every physical `(key, value)` pair into per-bucket files, one file per bucket, formatted to match `dump-iavl` so the same diff tooling works on both.

```bash
seidb dump-flatkv --db-dir <flatkv-data-dir> --output-dir <dir> [--height <n>] [--bucket account|code|storage|legacy]
```

| Flag | Short | Purpose | Default |
|---|---|---|---|
| `--db-dir` | `-d` | FlatKV database directory (required) | — |
| `--output-dir` | `-o` | Output directory; one file per bucket (required) | — |
| `--height` | | FlatKV target version; `0` selects the latest available version | `0` |
| `--bucket` | `-b` | Restrict dump to a single bucket (`account`, `code`, `storage`, or `legacy`) | all buckets |

Notes:
- Valid `--bucket` values are exactly `account`, `code`, `storage`, `legacy`. `metadata` is intentionally excluded and module names (e.g. `evm`) are not valid buckets.
- When `--bucket` is set, only that bucket's file is created under `--output-dir`; the others are not written.
- Each output file begins with a `Bucket <name> at version <V>` header, followed by `Key: <HEX>, Value: <HEX>` lines. Physical keys are emitted verbatim (including their `<module>/` + type-prefix header).
- The tool operates on a read-only temp clone of the selected snapshot + changelog, so it does not contend with a live node for the FlatKV writer lock.

Example:

```bash
seidb dump-flatkv \
  --db-dir /root/.sei/data/flatkv \
  --output-dir /tmp/flatkv-dump \
  --height 0 \
  --bucket storage
```

### state-size (--flatkv-dir)

The `state-size` command analyzes memIAVL state size. It now accepts an optional `--flatkv-dir` flag to fold FlatKV analysis into the same console output and DynamoDB batch.

```bash
seidb state-size --db-dir <memiavl-db-dir> [--flatkv-dir <flatkv-data-dir>] [--height <n>] [--module <name>]
```

| Flag | Short | Purpose | Default |
|---|---|---|---|
| `--db-dir` | `-d` | memIAVL database directory | — |
| `--flatkv-dir` | | FlatKV data directory | auto-detect `<db-dir>/../flatkv` |
| `--height` | | Block height (`0` = latest) | `0` |
| `--module` | `-m` | Module to export | all modules |

Notes:
- If `--flatkv-dir` is omitted, the tool auto-detects a sibling `flatkv/` directory next to `--db-dir` (e.g. `<home>/data/committer.db` → `<home>/data/flatkv`). If none exists, FlatKV analysis is skipped.
- FlatKV analysis is only attempted when `--module` is empty or `evm` (FlatKV in production holds only evm keys; everything else is bucketed into `legacy`).
- FlatKV analysis is strictly additive: any failure to open or scan FlatKV is logged and skipped, and the memIAVL analysis still completes.
- With `--export-dynamodb`, the FlatKV result is pushed to the same DynamoDB batch under module name `flatkv`.

Example:

```bash
seidb state-size \
  --db-dir /root/.sei/data/committer.db \
  --flatkv-dir /root/.sei/data/flatkv \
  --height 0
```


### evm-logical-digest

Computes a backend-independent digest of EVM *logical* state (account / code / storage canonical buckets) so a memIAVL node and a FlatKV node can be compared at the same chain height. Each FlatKV value embeds a per-key `blockHeight` stamp, so a raw physical byte-for-byte digest would diverge even when the underlying EVM state is identical; this command strips the serialization-version + blockHeight header on both sides and digests only the logical payload.

```bash
seidb evm-logical-digest --backend flatkv|memiavl --db-dir <dir> --height <H>
```

| Flag | Short | Purpose | Default |
|---|---|---|---|
| `--backend` | | Backend to read: `flatkv` or `memiavl` (required) | — |
| `--db-dir` | `-d` | For flatkv: the flatkv data dir. For memiavl: the memiavl root dir (contains `current/` and `snapshot-*`) | — |
| `--height` | | Target version. flatkv WAL-replays to it; memiavl resolves `snapshot-<height>/evm` (`0` = `current` symlink) | `0` |
| `--memiavl-normalization` | | memiavl normalization: `semantic`/`independent` (raw EVM key/value decoder) or `translator` (current migration mapping via `flatkv.ImportTranslator`) | `semantic` |
| `--inspect-bucket` | | Inspect one normalized bucket (`account`, `code`, `storage`, `legacy`) instead of printing the global digest | — |
| `--key-offset` | | Inspect mode: byte offset into physical key before applying `--key-prefix` / sharding | `0` |
| `--key-prefix` | | Inspect mode: hex prefix, relative to `--key-offset`, used to filter physical keys | — |
| `--shard-next-bytes` | | Inspect mode: group matching keys by this many bytes after `--key-prefix` | `0` |
| `--list` | | Inspect mode: list matching key/logical-value pairs instead of shard `bucket_digest` values | `false` |
| `--list-limit` | | Inspect mode: maximum pairs to print with `--list`; `<=0` means unlimited | `1000` |
| `--details` | | Inspect list mode: include backend-specific version metadata | `false` |
| `--find-hash` | | 32-byte hex per-entry hash to hunt for; every entry whose `sha256(len(key)||key||len(val)||val)` matches is printed as `FOUND-HASH` | — |

Notes:
- The per-bucket accumulator is an order-independent XOR of `sha256(len(key)||key||len(val)||val)`, so it does not matter that flatkv iterates in pebble global order while memiavl is scanned by leaf index.
- flatkv opens a read-only clone from snapshot + changelog WAL replay. memiavl does **not** replay WAL — it opens `snapshot-<height>/evm` or `current/evm`.
- The primary comparison is `account+code+storage+legacy`, printed as one `FINAL_DIGEST` line. flatkv contains a flatkv-only migration-version marker row (`migration/migration-version`) that a memiavl-only node never owns; it is folded into the legacy bucket but XORed back out for the final comparison, and a `flatkv_marker_adjustment` line reports this. This makes the flatkv `FINAL_DIGEST` comparable apples-to-apples against memiavl-only output.
- To hunt the single diverging entry when two `bucket_digest` values differ by exactly one row, XOR those two 32-byte hex values and pass the result to `--find-hash`.

Compare a migrated FlatKV node against a memiavl-only node at height `H` — the two `FINAL_DIGEST` lines should match:

```bash
# FlatKV digest at a height (WAL-replays to it)
seidb evm-logical-digest --backend flatkv \
  --db-dir /root/.sei/data/state_commit/flatkv --height 213200000

# memIAVL digest at the same height (default semantic mode)
seidb evm-logical-digest --backend memiavl \
  --db-dir /root/.sei/data/state_commit/memiavl --height 213200000

# Translator-based memIAVL digest (proves FlatKV state matches the current
# migration mapping; useful when debugging ImportTranslator)
seidb evm-logical-digest --backend memiavl \
  --db-dir /root/.sei/data/state_commit/memiavl --height 213200000 \
  --memiavl-normalization translator

# Inspect one bucket: list storage rows under a key prefix, sharded by next 2 bytes
seidb evm-logical-digest --backend flatkv -d <dir> --height H \
  --inspect-bucket storage --key-prefix 03 --shard-next-bytes 2

# Hunt a diverging entry
seidb evm-logical-digest --backend flatkv -d <dir> --height H \
  --find-hash <32-byte-hex>
```


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
