# seid CLI

Reference for the `seid` node/CLI binary. This documents notable command and flag changes after the full removal of the IAVL backend (SeiDB state-commit is now mandatory).

## Important: SeiDB state-commit is mandatory

The IAVL backend has been fully removed. SeiDB state-commit (SC) must be enabled.

- In `app.toml`, under `[state-commit]`, `sc-enable` **must** be `true`.
- If `sc-enable = false`, the node **panics** at startup with:
  `SeiDB state-commit (SC) must be enabled; IAVL backend has been fully deprecated`
- Operators must ensure `sc-enable = true` before upgrading. IAVL configuration and commands are removed and any leftover IAVL config no longer takes effect.

## Removed commands

The following commands no longer exist:

- `seid compact` — previously compacted the application levelDB. **Removed.**
- `seid debug dump-iavl [height]` (with flags `--db-path`/`-d`, `--output-dir`, `--module`/`-m`) — previously dumped IAVL data for a height. **Removed.**
- `seid prune` (with flags `--home`, `--app-db-backend`, `--pruning`, `--pruning-keep-recent`, `--pruning-keep-every`, `--pruning-interval`) — previously pruned app history states. **Removed.**
- `seid latest_version` — previously printed the latest app DB version. **Removed.**

## Removed `seid start` flags

The following IAVL/orphan-storage flags have been removed from `seid start`:

- `--separate-orphan-storage`
- `--separate-orphan-versions-to-keep`
- `--num-orphan-per-file`
- `--orphan-dir`
- `--iavl-disable-fastnode`

Top-level pruning flags (`--pruning`, `--pruning-keep-recent`, `--pruning-keep-every`, `--pruning-interval`) remain, but the separate `[iavl]` config section and the `iavl.*` pruning keys have been removed. Only the top-level pruning settings apply.

## Removed config fields (app.toml)

- `iavl-cache-size` — removed.
- Base config fields removed: `iavl-disable-fastnode`, `no-versioning`, `separate-orphan-storage`, `separate-orphan-versions-to-keep`, `num-orphan-per-file`, `orphan-dir`.
- The entire `[iavl]` section (`pruning`, `pruning-keep-recent`, `pruning-keep-every`, `pruning-interval`) has been removed.

## Snapshots / restore

Legacy IAVL snapshot and restore via the rootmulti store are no longer supported. Attempting the legacy IAVL snapshot/restore path returns an error:
`legacy IAVL snapshots/restore are no longer supported`

Use the SeiDB-based snapshot/restore tooling instead.



## seidb trace-profile-report

Runs the `debug_traceTransactionProfile` JSON-RPC method across a range of blocks and writes a raw JSONL dump plus an aggregated summary. Useful for offline profiling of transaction execution and historical DB (store) access across a block range.

```bash
seidb trace-profile-report \
  --endpoint <rpc-url> \
  --start-block <n> \
  --end-block <n> \
  --output-dir <dir>
```

### Flags

- `--endpoint` (**required**) — RPC endpoint, e.g. `http://localhost:8545`. Must expose `eth_getBlockByNumber` and `debug_traceTransactionProfile`.
- `--start-block` (**required**) — starting block number (must be positive).
- `--end-block` (**required**) — ending block number (must be positive and `>= --start-block`).
- `--output-dir` / `-o` (**required**) — directory for the output files `raw_profiles.jsonl` and `summary.json` (created if it does not exist).
- `--concurrency` / `-c` — number of concurrent `debug_traceTransactionProfile` requests (default `4`; values `<= 0` are treated as `1`).
- `--trace-config-json` — JSON object passed as the trace config to each request (default `{}`). Invalid JSON causes the command to error.
- `--max-transactions` — optional cap on the total number of transactions processed (`0` = no cap).

### Output

- `raw_profiles.jsonl` — one JSON record per transaction with `blockNumber`, `blockHash`, `txHash`, and either the full `result` (trace + profile) or an `error` string.
- `summary.json` — aggregated stats: tx/block/success/error counts, average and P50/P95 total & historical-DB-lookup latencies, per-phase totals (`lookupTransaction`, `loadBlock`, `replayHistoricalTxs`, `buildBlockContext`, `prepareTx`, `execution`, `traceResult`), per-module store operation totals, and top transactions/blocks by total time.

The underlying `debug_traceTransactionProfile(hash, config)` method returns `{ "trace": ..., "profile": { "totalNanos", "historicalDbLookupNanos", "otherNanos", "phases": {...}, "store": { "modules": {...}, "stats": {...} } } }`.



## seidb state-size

Scans a memIAVL database and reports per-module state size (key/value/total bytes, key counts, prefix breakdown, and top EVM contracts). Can optionally scan a FlatKV store alongside memIAVL and fold the result into the same output.

```bash
seidb state-size \
  --db-dir <memiavl-dir> \
  [--height <n>] \
  [--module <name>] \
  [--flatkv-dir <flatkv-dir>] \
  [--export-dynamodb] \
  [--dynamodb-table <table>] \
  [--aws-region <region>]
```

### Flags

- `--db-dir` / `-d` — memIAVL database directory. (Help text is now "memIAVL database directory".)
- `--height` — block height to analyze (`0` = latest available version).
- `--module` / `-m` — restrict analysis to a single module. Default: all modules.
- `--flatkv-dir` — FlatKV data directory. **Optional.** When omitted, the tool auto-detects a sibling `flatkv/` directory next to `--db-dir` (i.e. `<db-dir>/../flatkv`, the standard `seid` shadow-node layout: `<home>/data/committer.db` -> `<home>/data/flatkv`). Set explicitly to point at a FlatKV dir elsewhere.
- `--export-dynamodb` — export results to DynamoDB instead of printing to console.
- `--dynamodb-table` — DynamoDB table name (default `state_size_analysis`).
- `--aws-region` — AWS region for the DynamoDB export.

### FlatKV integration

FlatKV analysis is strictly additive and only runs when `--module` is empty or `evm` (FlatKV in production holds only evm keys; everything else is bucketed into a `legacy` DB). If the FlatKV directory is missing, its snapshot is unavailable, or the store fails to open, the tool logs the reason and continues — the memIAVL path always still succeeds.

When a FlatKV directory is present:

- **Console output** gains a `=== FlatKV state size (version N) ===` section with totals, a per-DB breakdown (`account`, `code`, `storage`, `legacy`), and a top EVM contracts table (top 100 by storage size).
- **DynamoDB export** appends a FlatKV row (module name `flatkv`) to the same batch as the memIAVL module rows. Its `PrefixBreakdown` is a JSON map keyed by bucket name (`{"account": {...}, "storage": {...}}`), matching the shape memIAVL uses.

The FlatKV store is opened read-only via a temporary snapshot + WAL clone, so it does not contend with a live node for the FlatKV writer lock.

### Console output notes

- Modules are printed in alphabetical order so successive runs produce diffable output.
- Each module's prefix breakdown is marshaled as a single combined map (key/value/total bytes and key count per prefix byte).
- The top-contracts table is skipped for modules with no `0x03` (contract storage) entries.
- Progress logging cadence is every 10M keys (previously every 1M).

### Example

```bash
# memIAVL + auto-detected sibling flatkv/ at latest height
seidb state-size --db-dir ~/.sei/data/committer.db

# explicit FlatKV dir and a historical height, evm module only
seidb state-size \
  --db-dir ~/.sei/data/committer.db \
  --flatkv-dir ~/.sei/data/flatkv \
  --height 12345678 \
  --module evm

# export both memIAVL and FlatKV rows to DynamoDB
seidb state-size \
  --db-dir ~/.sei/data/committer.db \
  --export-dynamodb \
  --dynamodb-table state_size_analysis \
  --aws-region us-east-1
```


## seidb dump-flatkv

Iterates and dumps every physical FlatKV (key, value) pair into per-bucket files (`account`, `code`, `storage`, `legacy`), formatted to match `dump-iavl` so the same diff tooling works on both. Keys and values are emitted as `Key: <HEX>, Value: <HEX>`, one per line, under a `Bucket <name> at version <V>` header.

```bash
seidb dump-flatkv \
  --db-dir <flatkv-dir> \
  --output-dir <dir> \
  [--height <n>] \
  [--bucket account|code|storage|legacy]
```

### Flags

- `--db-dir` / `-d` (**required**) — FlatKV database directory.
- `--output-dir` / `-o` (**required**) — output directory; one file per bucket is written.
- `--height` — FlatKV target version (`0` = latest available version).
- `--bucket` / `-b` — restrict the dump to a single bucket (`account`, `code`, `storage`, or `legacy`). Default: all buckets. When set, only that bucket's file is created.

The store is opened via a read-only temporary snapshot + WAL clone. The FlatKV `metadataDB` and internal `_meta/*` rows are excluded.

### Example

```bash
seidb dump-flatkv \
  --db-dir ~/.sei/data/flatkv \
  --output-dir ./flatkv-dump \
  --height 12345678 \
  --bucket storage
```



## seidb dump-flatkv

Iterates and dumps physical FlatKV `(key, value)` pairs into per-bucket files, formatted to match `dump-iavl` so the same diff tooling works on both. The tool operates on a temporary read-only clone of the selected snapshot + WAL, so it does not contend with a live node for the FlatKV writer lock.

```bash
seidb dump-flatkv \
  --db-dir <flatkv-dir> \
  --output-dir <dir> \
  [--height <n>] \
  [--bucket account|code|storage|legacy]
```

### Flags

- `--db-dir` / `-d` (**required**) — FlatKV database directory. Panics if omitted.
- `--output-dir` / `-o` (**required**) — output directory; one file is written per bucket. Panics if omitted.
- `--height` — FlatKV target version. `0` (default) selects the latest available version.
- `--bucket` / `-b` — restrict the dump to a single bucket (`account`, `code`, `storage`, or `legacy`). Default: all buckets. Invalid values panic.

### Buckets

Physical keys are classified into four buckets in this order (`account` → `code` → `storage` → `legacy`):

- `account` — evm nonce and codehash rows (both canonicalize to the same account row per address).
- `code` — evm contract bytecode.
- `storage` — evm contract storage slots.
- `legacy` — non-evm module keys and any evm keys with an unrecognized type prefix.

The FlatKV metadata DB and per-DB `_meta/*` rows are intentionally excluded. Physical keys are emitted verbatim (including their `<module>/` + type-prefix header) because they are not byte-for-byte comparable with memIAVL logical keys.

### Output format

Each bucket file mirrors the `dump-iavl` format:

```
Bucket <name> at version <V>
Key: <HEX>, Value: <HEX>
...
```

When `--bucket` is set, only that bucket's file is created; unselected buckets produce no file.

### Example

```bash
seidb dump-flatkv \
  --db-dir ~/.sei/data/flatkv \
  --output-dir ./flatkv-dump \
  --height 0 \
  --bucket storage
```



## seidb import-flatkv-from-memiavl

Imports selected memIAVL modules into FlatKV. This is the offline migration tool for moving the EVM module's SC-layer data from memIAVL into FlatKV. It is a restore-style import: it **resets the FlatKV directory before loading** the imported rows and refuses to run over existing committed FlatKV data unless `--force` is supplied.

```bash
seidb import-flatkv-from-memiavl \
  --modules=evm \
  --data-dir <dir> \
  --height <h> \
  [--home <home>] \
  [--force]
```

### Flags

- `--modules` — comma-separated module names to import (default `evm`). **Initial production scope is evm-only**; any other module name is rejected at the CLI boundary.
- `--data-dir` — Sei data directory or home directory. If the basename is `data`, its parent is used as home.
- `--home` — Sei home directory. Defaults to `$HOME/.sei`. Takes precedence over `--data-dir` when both are set.
- `--height` — memIAVL version to import. `0` (default) means the latest committed memIAVL version.
- `--force` — overwrite existing committed FlatKV data. Without it, the command refuses to run when FlatKV already has a committed version.

### Constraints

- **Import must run at the memiavl latest height.** Importing at `H < memiavl latest` is refused, because a subsequent `GIGA_STORAGE` startup would call `CompositeCommitStore.reconcileVersions` and silently roll memIAVL back to `H`, truncating every cosmos block in `(H, memiavlLatest]`. To import at a lower height, roll memIAVL back to `H` first (this CLI never does that rollback for you). Importing at `H > memiavl latest` is also refused.
- On failure the import is **aborted, not finalized** — FlatKV is left at its pre-import committed version so the operation can be retried without `--force`.
- After a successful import, the offline migration workflow requires keeping `evm-ss-split = false` and `sc-enable-lattice-hash = false` across the import boundary on restart, to avoid AppHash-mismatch and rootmulti startup panics. See `sei-db/state_db/sc/migration/OPERATIONS.md`.

### Multi-validator workflow

For a cluster, stop every validator, read each node's latest memIAVL version with `memiavl-latest-version`, pick the minimum as a uniform import height, roll any node that committed extra blocks back to that height, then run the import on every node at the same `--height`.

### Example

```bash
# import the evm module at the latest memiavl height
seidb import-flatkv-from-memiavl \
  --modules=evm \
  --data-dir /root/.sei/data \
  --height 12345678

# overwrite an existing committed FlatKV store
seidb import-flatkv-from-memiavl \
  --modules=evm \
  --data-dir /root/.sei/data \
  --height 12345678 \
  --force
```


## seidb memiavl-latest-version

Prints the latest committed memIAVL version of a stopped node to stdout. This is the read-only companion to `import-flatkv-from-memiavl`: orchestration scripts read each validator's version to pick a single uniform import height across a multi-validator cluster.

```bash
seidb memiavl-latest-version --data-dir <dir> [--home <home>]
```

### Flags

- `--data-dir` — Sei data directory or home directory. If the basename is `data`, its parent is used as home.
- `--home` — Sei home directory. Defaults to `$HOME/.sei`. Takes precedence over `--data-dir` when both are set.

### Example

```bash
seidb memiavl-latest-version --data-dir /root/.sei/data
```



## seidb migrate-evm-status

Reports the on-disk FlatKV EVM migration state of a FlatKV directory as JSON. Intended for integration test drivers polling for migration completion from the host: the tool reads the migration bookkeeping keys directly from FlatKV instead of adding a custom RPC or grepping node logs.

```bash
seidb migrate-evm-status --db-dir <flatkv-dir> [--height <n>]
```

### Flags

- `--db-dir` / `-d` (**required**) — FlatKV database directory. Panics if omitted.
- `--height` — FlatKV target version. `0` (default) selects the latest available version.

The store is opened read-only via a temporary snapshot + WAL clone, so it does not contend with a live node for the FlatKV writer lock and gives a stable view even if the live writer rolls snapshots mid-run.

### What it reads

It reads two reserved keys from the FlatKV `migration` store:

- `migration-version` — an 8-byte big-endian `uint64` written exactly once on the migration bump block. Absent or `0` means the FlatKV EVM migration (MigrateEVM, version 1) has not yet completed.
- `migration-boundary` — the in-flight resume cursor `(module, key)`. Present iff the boundary is strictly between not-started and complete.

### JSON output

```json
{
  "version_at": 12345,
  "migration_version": 1,
  "migrate_evm_complete": true,
  "boundary_present": false,
  "boundary_hex": "...",
  "version_raw_hex": "0000000000000001"
}
```

- `version_at` — the FlatKV version the read resolved against.
- `migration_version` — decoded `migration-version` value (`0` when the key is absent).
- `migrate_evm_complete` — `true` when `migration_version >= 1` (Version1_MigrateEVM). This is the field test drivers poll on.
- `boundary_present` — whether the in-flight boundary key exists.
- `boundary_hex` — hex of the boundary bytes, present only when `boundary_present` is true.
- `version_raw_hex` — hex of the raw `migration-version` bytes, present only when the key exists.

### Example

```bash
# poll until migration completes
seidb migrate-evm-status --db-dir /root/.sei/data/state_commit/flatkv \
  | jq -r '.migrate_evm_complete'
```


### Example

```bash
seidb trace-profile-report \
  --endpoint http://localhost:8545 \
  --start-block 1000 \
  --end-block 1100 \
  --output-dir ./trace-report \
  --concurrency 8 \
  --trace-config-json '{"timeout":"60s"}' \
  --max-transactions 500
```



## seid tendermint gen-autobahn-config

Generates an Autobahn (GigaRouter) JSON config file from per-node pubkey/address files.

```bash
seid tendermint gen-autobahn-config [node-dirs...] --output <path>
```

- Takes one or more node directories as positional args (at least one required).
- For each node directory, it reads three files:
  - `validator_pubkey.txt` — validator public key in `validator:<pubkey>` format
  - `node_pubkey.txt` — p2p node public key in `node:ed25519:public:<hex>` format
  - `autobahn_address.txt` — network address in `host:port` format
- `--output` / `-o` (**required**) — output file path for the generated autobahn config. If omitted, the command errors with `--output flag is required`.

The generated JSON contains a `validators` array (one entry per node dir with `validator_key`, `node_key`, `address`) plus default block/mempool settings (e.g. `max_gas_per_block = 50_000_000`, `max_txs_per_block = 5_000`, `mempool_size = 5_000`, `block_interval = 400ms`, `view_timeout = 1500ms`, `dial_interval = 10s`, `allow_empty_blocks = false`).

### Where the pubkey files come from

The two pubkey text files are written automatically as a side effect of saving keys:

- Saving the validator private key file also writes `validator_pubkey.txt` (`validator:<pubkey>`) in the same directory.
- Saving the node key also writes `node_pubkey.txt` (`node:ed25519:public:<hex>`) in the same directory.

The `autobahn_address.txt` file must be provided/generated separately (e.g. `echo "$NODE_IP:26656" > <node-dir>/autobahn_address.txt`).

### Wiring the config into a node

Point the node at the generated config via a top-level `autobahn-config-file` key in `config.toml` (must appear before any `[section]` header so it parses as a top-level key):

```toml
autobahn-config-file = "/root/.sei/config/autobahn.json"
```

### Example

```bash
seid tendermint gen-autobahn-config \
  build/generated/node_0 \
  build/generated/node_1 \
  build/generated/node_2 \
  --output ~/.sei/config/autobahn.json
```


## Example: starting a node

Ensure `sc-enable = true` in `app.toml` before starting:

```toml
[state-commit]
sc-enable = true
```

Then start the node:

```bash
seid start --home ~/.sei
```

If state-commit is disabled, the node will panic on startup rather than falling back to IAVL.
