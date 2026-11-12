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

## Node Initialization

```bash
seid init <moniker> --chain-id <chain-id> [--home <dir>] [--mode full|validator|seed|archive] [--overwrite]
```

- `--chain-id` is **required** — e.g. `pacific-1` or `atlantic-2`. `seid init` panics with `chain-id is required, please set using --chain-id` if it is left blank.
- For validator or seed nodes, pass `--mode validator` or `--mode seed` so RPC and P2P are configured for that role. Default mode is `full`. `--mode archive` is also accepted: it runs as a full node in CometBFT but takes archive-specific app and EVM config.

### Default bootstrap-peers

On a public network `seid init` now auto-populates the `bootstrap-peers` field in `config.toml` with the Sei Labs seed nodes for that chain, so a freshly initialised node bootstraps peer discovery with no manual seed configuration. Behaviour by chain-id:

| Chain-id | bootstrap-peers written |
|---|---|
| `pacific-1` (mainnet) | Sei Labs seeds (3 nodes) |
| `atlantic-2` (testnet) | Sei Labs seeds (3 nodes) |
| `arctic-1` (devnet) | none — devnets set peers explicitly |
| unknown / private / local chains | none |

Notes:
- The seeds go in `bootstrap-peers` (dialled to populate the address book via PEX, then may be dropped), not `persistent-peers`.
- An existing `bootstrap-peers` value is never overwritten — if the field is already set, `seid init` leaves it untouched.
- Chain-id matching is exact and case-sensitive; `Pacific-1` or a trailing space contributes no seeds.

Example:

```bash
seid init my-node --chain-id pacific-1
# config.toml now has bootstrap-peers pre-filled with the Sei Labs mainnet seeds
```

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

## Node Start (`seid start`)

### `--freeze-height`

Stops the node *before* executing a target block while keeping the process and RPC servers running (unlike `--halt-height`, which gracefully shuts the node down). Block sync and consensus stop before executing the block at the configured height and do not advance beyond it. The node is read-only from startup: query RPC stays available, but transaction and evidence submission, mempool gossip, and state sync are disabled.

```bash
seid start --freeze-height <uint64>
```

- Default `0` disables freeze mode.
- Also settable as the top-level `freeze-height` key in `app.toml`, next to `halt-height` and `halt-time` (it is not under any `[section]`; `freeze-height = 0` by default).

Constraints:
- Must not exceed `MaxInt64`.
- Cannot be combined with `--halt-height`/`halt-height` or `--halt-time`/`halt-time`.
- Cannot be combined with grpc-only mode (`--grpc-only`).
- State sync is disabled under freeze mode and falls back to block sync.
- Full nodes only: not supported in validator or seed mode, or with Autobahn.
- The target height must not be below the chain's initial height, and the application, block store, and state store must not have reached it yet — otherwise the node refuses to start.
- Auto-remediation restart halts at the freeze boundary rather than restarting past it.

Run v6.6.4+ or v6.7.2+. On v6.6.3 and v6.7.0–v6.7.1 a frozen node's EVM JSON-RPC does not come back after the process restarts, because the EVM servers waited for a processed block ([sei-chain#4448](https://github.com/sei-protocol/sei-chain/pull/4448), [#4447](https://github.com/sei-protocol/sei-chain/pull/4447)). A frozen node runs the latest patch of the release that its upgrade replaced: v6.6.4 for the v6.7 upgrade, `--freeze-height 236450000` on mainnet and `273966500` on testnet. See "Which release a frozen node runs" in [node operations](../ecosystem/node-operations.md).

The freeze height is an *exclusive* boundary: a node started with `--freeze-height 100` serves blocks through height 99 and never executes block 100. This is the interval semantics the `frozen-rpc-router` relies on when routing requests by block number (see [Frozen RPC Router](frozen-rpc-router.md)).

Example — freeze a node just before executing block 5,000,000 while continuing to serve RPC (the node serves blocks through height 4,999,999):

```bash
seid start --freeze-height 5000000
```

## Rollback (`seid rollback`)

Stop the node first. `seid rollback` rolls the application and Tendermint state back so the node re-fetches and re-executes the removed blocks on restart. It is the usual first step for `wrong Block.Header.AppHash`.

```bash
seid rollback [--num-blocks <n>] [--home <dir>]
```

- `--num-blocks` / `-n` (default `1`): how many heights to roll back when the application and Tendermint are at the same height. If their heights differ, rollback only brings the one that is ahead down to the other's height.
- **FlatKV retention floor (v6.7.1+, [sei-chain#4496](https://github.com/sei-protocol/sei-chain/pull/4496)):** on a node whose FlatKV store is open (the EVM storage migration has started, or a FlatKV write mode is pinned), rollback first checks that FlatKV can rebuild the target height from its retained snapshots and WAL. If it cannot, it refuses before changing anything: `flatkv cannot roll back to version <N>: version unreachable: ...; use state sync instead`. State sync is then the only way back.

`seid export` was **removed in v6.7.1** ([sei-chain#4478](https://github.com/sei-protocol/sei-chain/pull/4478)). There is no supported way to dump live state to a genesis file; recover with `seid rollback`, state sync, or a snapshot. `seid init`, `seid collect-gentxs`, and starting a chain from a genesis file are unchanged.

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
- **Proofs:** Sei stores state in SeiDB state-commit (SC), a memiavl-based tree, not Merkle Patricia Tries. The legacy IAVL backend has been fully removed and SeiDB SC is mandatory — a node started with `sc-enable = false` panics with `SeiDB state-commit (SC) must be enabled; IAVL backend has been fully deprecated`. Proofs from Cosmos-side queries are IAVL-style (memiavl) proofs, not Merkle Patricia Trie proofs.
- **`eth_getProof` is not supported** (since v6.7.0, [sei-chain#3926](https://github.com/sei-protocol/sei-chain/pull/3926)): it returns `-32000` `eth_getProof is not supported yet; please reach out to the Sei Labs if you need this endpoint`.
- **Filter limits:** Open-ended log queries return up to 10,000 logs; closed-range queries cover up to 2,000 blocks.
- **Legacy `sei_*` methods:** As of v6.7.0 only three remain, all deprecated: `sei_getSeiAddress`, `sei_getEVMAddress`, `sei_getCosmosTx` (EVM HTTP only). The `sei2_*` namespace and every other `sei_*` method (block/receipt/count getters, filters, logs, `sei_getTransactionReceipt`, `sei_sign`, `sei_associate`) were removed ([sei-chain#3912](https://github.com/sei-protocol/sei-chain/pull/3912), [#3924](https://github.com/sei-protocol/sei-chain/pull/3924), [#3927](https://github.com/sei-protocol/sei-chain/pull/3927), [#3945](https://github.com/sei-protocol/sei-chain/pull/3945)); the `sei_traceBlockBy*ExcludeTraceFail` endpoints were removed in v6.6.0. Use standard `eth_*` / `debug_*` methods.
- **Legacy `sei_*` gating:** The three remaining methods are served only if listed in `[evm].enabled_legacy_sei_apis` in `app.toml` (also settable via the `evm.enabled_legacy_sei_apis` AppOptions flag); the `seid init` default lists all three, and other names in the list are ignored. All responses return HTTP 200. Any other `sei_*` name returns a JSON-RPC error with code `-32601` and `data` `"legacy_sei_deprecated"` (the message says the method is not enabled; for removed methods, adding them to the allowlist does nothing). `sei2_*` calls return the standard `-32601` "does not exist". Allowed calls pass through with an unchanged JSON body but may set the HTTP response header `Sei-Legacy-RPC-Deprecation`.
- **`debug_traceTransaction`:** Only available if the RPC node exposes debug methods. If unavailable, fall back to standard RPC queries.
- **`debug_trace*` tracer gating (deviation from upstream geth):** `debug_traceCall`, `debug_traceTransaction`, `debug_traceBlockByNumber`, `debug_traceBlockByHash`, and `debug_traceTransactionProfile` now reject any caller-supplied `TraceConfig.Tracer` name that is not in the `[evm].trace_allowed_tracers` allowlist in `app.toml` (also settable via the `evm.trace_allowed_tracers` AppOptions flag). The default allowlist is the native geth tracers `["callTracer", "prestateTracer", "flatCallTracer", "4byteTracer", "noopTracer", "muxTracer"]`; set it to `[]` to disable all named tracers. Requesting a name not on the list returns an error like `debug tracer "<name>" is not allowed; JavaScript tracers are disabled and only native tracers listed in evm.trace_allowed_tracers may be used`. Omitting `Tracer` (the default struct logger) is always available. Request-supplied JavaScript tracer source is rejected unless `[evm].trace_allow_js_tracers` (`evm.trace_allow_js_tracers`, default `false`) is explicitly enabled — upstream geth accepts JS tracers by default, Sei does not. Enabling `trace_allow_js_tracers` does **not** widen the native allowlist: native tracer names must still be listed in `trace_allowed_tracers` to be usable. `trace_allowed_tracers` is validated native-only at startup (a non-native/typo'd name fails startup), and `muxTracer` nested tracer names are validated recursively up to a bounded depth of 16. The baked-tracer list `[evm].trace_bake_tracers` is held to the same native-only rule at startup. (v6.7.0, [sei-chain#3718](https://github.com/sei-protocol/sei-chain/pull/3718))

## seidb Tool

`seidb` is the SeiDB maintenance/analysis tool (built from `sei-db/tools/cmd/seidb`). Use it for inspecting on-disk state stores — not for chain queries. The commands below cover FlatKV analysis and hash-log inspection. As of v6.7.0 the fourth FlatKV bucket is named `misc` (it was `legacy` in v6.6).

### dump-flatkv

Iterates a FlatKV store and dumps every physical `(key, value)` pair into per-bucket files, one file per bucket, formatted to match `dump-iavl` so the same diff tooling works on both.

```bash
seidb dump-flatkv --db-dir <flatkv-data-dir> [--output-dir <dir>] [--height <n>] [--bucket account|code|storage|misc] [--lthash] [--lthash-only] [--read-limit-mb <mibps>]
```

| Flag | Short | Purpose | Default |
|---|---|---|---|
| `--db-dir` | `-d` | FlatKV database directory (required) | — |
| `--output-dir` | `-o` | Output directory; one file per bucket. Required unless `--lthash-only` is used | — |
| `--height` | | FlatKV target version; `0` selects the latest available version | `0` |
| `--bucket` | `-b` | Restrict dump to a single bucket (`account`, `code`, `storage`, or `misc`) | all buckets |
| `--lthash` | | Also compute per-bucket and total LtHash (lattice hash) over the scanned state and verify the total against the committed snapshot metadata | `true` |
| `--lthash-only` | | Only compute and verify LtHash; do not write any bucket dump files. Requires `--lthash=true` and does not require `--output-dir` | `false` |
| `--read-limit-mb` | | Throttle the scan to at most this many MiB/s of (key+value) bytes read, so a dump against a running node does not starve the chain of disk bandwidth. `0` = unlimited | `64` |

Notes:
- Valid `--bucket` values are exactly `account`, `code`, `storage`, `misc`. `metadata` is intentionally excluded and module names (e.g. `evm`) are not valid buckets.
- When `--bucket` is set, only that bucket's file is created under `--output-dir`; the others are not written. The full keyspace is still scanned, and LtHash always covers all four buckets, so the printed total stays valid.
- Each output file begins with a `Bucket <name> at version <V>` header, followed by `Key: <HEX>, Value: <HEX>` lines. Physical keys are emitted verbatim (including their `<module>/` + type-prefix header).
- The tool operates on a read-only temp clone of the selected snapshot + changelog, so it does not contend with a live node for the FlatKV writer lock.
- With `--lthash` (the default), after the dump it prints a `LtHash (lattice hash) at version <V>` block listing each bucket's `count` and checksum plus the `TOTAL`, then a `LtHash verification vs snapshot metadata (committed)` PASS/FAIL line. A mismatch exits non-zero. Verification is skipped (not failed) when the selected snapshot predates LtHash metadata or carries no committed LtHash.
- `--lthash-only` requires `--lthash=true` and cannot be combined with `--bucket`. In this mode no output dir or bucket files are created, so `--output-dir` may be omitted.
- `--read-limit-mb` must be `>= 0`. Keep it at the default (or lower) on a shared/live node; raise it or set `0` only for offline runs on idle disks.

Example:

```bash
# Dump one bucket at latest version with default 64 MiB/s throttle + LtHash verify
seidb dump-flatkv \
  --db-dir /root/.sei/data/flatkv \
  --output-dir /tmp/flatkv-dump \
  --height 0 \
  --bucket storage

# Verify the FlatKV lattice hash only, writing no key/value dump files
seidb dump-flatkv --db-dir /root/.sei/data/flatkv --lthash-only

# Offline / idle disk: go full speed, skip LtHash
seidb dump-flatkv --db-dir /root/.sei/data/flatkv --output-dir /tmp/flatkv-dump \
  --read-limit-mb 0 --lthash=false
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
- FlatKV analysis is only attempted when `--module` is empty or `evm` (FlatKV in production holds only evm keys; everything else is bucketed into `misc`).
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

Computes a backend-independent digest of EVM *logical* state (account / code / storage canonical buckets) so a memIAVL node and a FlatKV node can be compared at the same chain height. Each FlatKV value embeds a per-key `blockHeight` stamp, so a raw physical byte-for-byte digest would diverge even when the underlying EVM state is identical; this command strips the serialization-version + blockHeight header on both sides and digests only the logical payload. A `composite` backend additionally digests the union of flatkv (migrated) rows and memiavl (not-yet-migrated) rows so a mid-migration node can be compared against a memiavl-only or completed node.

```bash
seidb evm-logical-digest --backend flatkv|memiavl|composite --db-dir <dir> --height <H>
```

| Flag | Short | Purpose | Default |
|---|---|---|---|
| `--backend` | | Backend to read: `flatkv`, `memiavl`, or `composite` (required) | — |
| `--db-dir` | `-d` | For flatkv: the flatkv data dir. For memiavl: the memiavl root dir (contains `current/` and `snapshot-*`). Not required for `composite` (use `--flatkv-dir`/`--memiavl-dir` instead) | — |
| `--flatkv-dir` | | Composite mode: flatkv data dir (required with `--backend composite`) | — |
| `--memiavl-dir` | | Composite mode: memiavl root dir (contains `current/` and `snapshot-*`) (required with `--backend composite`) | — |
| `--height` | | Target version. flatkv WAL-replays to it; memiavl resolves `snapshot-<height>/evm` (`0` = `current` symlink) | `0` |
| `--memiavl-open-mode` | | memiavl read mode (memiavl/composite only): `snapshot` (FAST — sequential scan of the completed snapshot kvs file; requires an on-disk snapshot at `--height`, or `--height 0` for `current`), `replay` (SLOW ~10x — replays the changelog to `--height` then walks the mmap tree; use only when no snapshot exists at the target height), or `changelog` (scans the snapshot kvs file at or below `--height` merged with the EVM writes of the changelog above it; same rows as `replay`) | `snapshot` |
| `--memiavl-normalization` | | memiavl normalization: `semantic`/`independent` (raw EVM key/value decoder) or `translator` (current migration mapping via `flatkv.ImportTranslator`) | `semantic` |
| `--inspect-bucket` | | Inspect one normalized bucket (`account`, `code`, `storage`, `misc`) instead of printing the global digest. With `--memiavl-normalization=translator`, or `--details` on the storage bucket, only `--memiavl-open-mode=snapshot` is supported | — |
| `--inspect-plan` | | Inspect mode: JSON file listing several inspect reports to take from one scan; each item sets `inspect_bucket`, `key_offset`, `key_prefix`, `shard_next_bytes`, `list`, `list_limit`, and `out` (the file its report is written to). Replaces the single-report inspect flags | — |
| `--key-offset` | | Inspect mode: byte offset into physical key before applying `--key-prefix` / sharding | `0` |
| `--key-prefix` | | Inspect mode: hex prefix, relative to `--key-offset`, used to filter physical keys | — |
| `--shard-next-bytes` | | Inspect mode: group matching keys by this many bytes after `--key-prefix` | `0` |
| `--list` | | Inspect mode: list matching key/logical-value pairs instead of shard `bucket_digest` values | `false` |
| `--list-limit` | | Inspect mode: maximum pairs to print with `--list`; `<=0` means unlimited | `1000` |
| `--details` | | Inspect list mode: include backend-specific version metadata | `false` |
| `--find-hash` | | 32-byte hex per-entry hash to hunt for; every entry whose `sha256(len(key)||key||len(val)||val)` matches is printed as `FOUND-HASH` | — |
| `--json` | | Emit the digest or inspect report as one JSON object on stdout (narration goes to stderr), for scheduled digest checks | `false` |

Notes:
- The per-bucket accumulator is an order-independent XOR of `sha256(len(key)||key||len(val)||val)`, so it does not matter that flatkv iterates in pebble global order while memiavl is scanned by leaf index.
- flatkv opens a read-only clone from snapshot + changelog WAL replay. memiavl does **not** replay WAL — it opens `snapshot-<height>/evm` or `current/evm`.
- The primary comparison is `account+code+storage+misc`, printed as one `FINAL_DIGEST` line. flatkv can contain flatkv-only migration rows that a memiavl-only node never owns — the migration-version marker (`migration/migration-version`, once a migration completes) and the migration-boundary cursor (only while a migration is in flight). Both are folded into the `misc` bucket but XORed back out for the final comparison, and a `flatkv_marker_adjustment` line reports this. This makes the flatkv `FINAL_DIGEST` comparable apples-to-apples against memiavl-only output.
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

### hashlog

`seidb hashlog` groups read-only tools for inspecting the on-disk hash log archives produced by the hashlogger. Use it to pull a single block's recorded hashes or to diff two archives.

```bash
seidb hashlog get-block <archive> <block> [--json]
seidb hashlog compare <archive-a> <archive-b> [--low N --high M] [--max-diffs N] [--full] [--json]
```

#### get-block

Prints every hash recorded for a single block in a hash log archive. Takes exactly two positional args: the archive path and the block number.

| Flag | Purpose | Default |
|---|---|---|
| `--json` | Emit JSON instead of human-readable text | `false` |

Notes:
- A block may have more than one record if it was executed more than once (e.g. after a rollback and replay); each execution's hashes are reported separately.
- A hash type that was registered but not recorded for the block prints as `<none>` (and serializes to JSON `null`, distinguishable from an absent type).

#### compare

Compares two hash log archives and reports blocks whose hashes differ. Takes exactly two positional args: the two archive paths.

| Flag | Purpose | Default |
|---|---|---|
| `--low` | Lowest block to compare (inclusive); **requires `--high`** | `0` |
| `--high` | Highest block to compare (inclusive); **requires `--low`** | `0` |
| `--max-diffs` | Maximum number of differing blocks to report, or `-1` for all | `-1` |
| `--full` | Show every column for each differing block (default shows only the columns that differ) | `false` |
| `--json` | Emit JSON instead of human-readable text | `false` |

Notes:
- `--low` and `--high` are optional but must be supplied **together** — providing only one panics with `Must provide both --low and --high to compare a block range`.
- The default (compact) output shows only the columns that differ between the two sides; `--full` shows every column for both sides. This applies to both text and JSON output.
- Column-level diffing is only well-defined when each side holds exactly one record. When the record counts differ (a rollback re-executed the block a different number of times), compact mode reports the record counts and defers to `--full` for the details.
- If the number of reported diffs equals `--max-diffs`, the output may have been truncated and a warning is printed (`Output truncated at --max-diffs=N; there may be more differing blocks.`); widen or remove the cap (`--max-diffs -1`) to see all.

Example:

```bash
# Print every hash recorded for block 213200000 in an archive
seidb hashlog get-block /root/.sei/data/hashlog 213200000

# As JSON
seidb hashlog get-block /root/.sei/data/hashlog 213200000 --json

# Diff two archives over a block range, showing full columns for each diff
seidb hashlog compare /node-a/hashlog /node-b/hashlog \
  --low 213200000 --high 213210000 --full

# Diff whole archives, cap at the first 50 differing blocks
seidb hashlog compare /node-a/hashlog /node-b/hashlog --max-diffs 50
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
