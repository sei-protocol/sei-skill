# Node Operations

Operational reference for running a Sei node (`seid`), focused on SeiDB state storage configuration and CLI commands.

## SeiDB state-commit is mandatory

As of the IAVL removal, SeiDB state-commit (SC) is **required**. The legacy IAVL backend has been fully removed.

- `sc-enable` must be `true` in `app.toml`.
- If `sc-enable = false`, the node **panics** on startup with:
  ```
  panic: SeiDB state-commit (SC) must be enabled; IAVL backend has been fully deprecated
  ```
- Before upgrading, node operators must ensure `sc-enable = true`. There is no IAVL fallback.
- Legacy IAVL snapshot/restore via the rootmulti store is no longer supported; snapshot/restore of the legacy IAVL path returns an error (`legacy IAVL snapshots/restore are no longer supported`).

## app.toml: [state-commit]

```toml
[state-commit]
# Enable defines if the state-commit should be enabled.
# Must be true — the node will panic if this is false.
sc-enable = true

# Defines the SC store directory; defaults to the application home directory if unset.
# sc-directory = ""

# ZeroCopy defines if memiavl should return slices pointing to mmap-ed buffers directly (zero-copy).
# zero-copy = false

# AsyncCommitBuffer defines the size of the asynchronous commit queue.
# async-commit-buffer = 100

# SnapshotInterval defines the block interval the memiavl snapshot is taken (0 = disabled by default in tests).
# snapshot-interval = 10000
```

## app.toml: [state-store]

State-store (SS) is the historical query layer and is separate from state-commit.

```toml
[state-store]
# ss-enable defines whether the state-store should be enabled for historical queries.
ss-enable = true

# ss-backend defines the backend database used for state-store.
ss-backend = "pebbledb"
```

## Removed config fields

The following IAVL-related config fields have been **removed**. They no longer take effect and should be deleted from `app.toml` when upgrading:

- `iavl-cache-size` (was `iavl-cache-size = 781250`)
- `iavl-disable-fastnode`
- `no-versioning`
- `separate-orphan-storage`
- `separate-orphan-versions-to-keep`
- `num-orphan-per-file`
- `orphan-dir`
- The entire `[iavl]` section, including `pruning`, `pruning-keep-recent`, `pruning-keep-every`, and `pruning-interval` under `[iavl]`.

Pruning is now controlled only by the top-level `pruning` flags:

```toml
pruning = "nothing"          # default | nothing | everything | custom
pruning-keep-recent = "0"
pruning-keep-every = "0"
pruning-interval = "0"
```

## Removed CLI commands and flags

The following IAVL-related commands have been **removed** from `seid`:

- `seid compact` — compacted the application levelDB.
- `seid debug dump-iavl [height]` (and flags `--db-path`/`-d`, `--output-dir`, `--module`/`-m`).
- `seid prune` (and flags `--home`, `--app-db-backend`, `--pruning`, `--pruning-keep-recent`, etc.).
- `seid latest_version` — printed the latest app DB version.

Removed `seid start` flags related to IAVL/orphan storage:

- `--separate-orphan-storage`
- `--separate-orphan-versions-to-keep`
- `--num-orphan-per-file`
- `--orphan-dir`
- `--iavl-disable-fastnode`

## Migration checklist

1. Set `sc-enable = true` under `[state-commit]` in `app.toml` (required — node panics otherwise).
2. Remove the `[iavl]` section and all removed fields listed above.
3. Configure top-level `pruning` flags if you relied on the old `[iavl]` pruning keys.
4. Stop using removed CLI commands (`compact`, `debug dump-iavl`, `prune`, `latest_version`) and removed orphan-storage start flags.
5. Start the node normally:
   ```bash
   seid start --home ~/.sei
   ```



## Autobahn (GigaRouter) config

Autobahn wiring is enabled by pointing the node at a generated JSON config via a **top-level** `autobahn-config-file` field in `config.toml`:

```toml
# Must appear before any [section] header so the TOML parser reads it as a top-level key.
autobahn-config-file = "/root/.sei/config/autobahn.json"
```

When `autobahn-config-file` is set, the node loads the file at startup and wires up the GigaRouter. Currently only validator nodes are supported (a signing validator key must be present); observer/non-validator support is not yet available.

### Pubkey side-effect files

Saving keys now also writes autobahn-compatible pubkey text files alongside the key files, in the same directory:

- Saving the validator private key (`priv_validator_key.json`) also writes **`validator_pubkey.txt`** in `validator:<pubkey>` format.
- Saving the node key (`node_key.json`) also writes **`node_pubkey.txt`** in `node:ed25519:public:<hex>` format.

These files are consumed by the config generator below.

### Generating the config

Use `seid tendermint gen-autobahn-config` to produce the JSON config. Each node directory passed as an argument must contain:

- `validator_pubkey.txt` (`validator:<pubkey>`)
- `node_pubkey.txt` (`node:ed25519:public:<hex>`)
- `autobahn_address.txt` (a single `host:port` line, e.g. the node's P2P address)

Syntax:

```bash
seid tendermint gen-autobahn-config [node-dirs...] --output <path> [--persistent-state-dir <dir>]
```

- `--output` / `-o` (**required**): output file path for the generated autobahn config.
- `--persistent-state-dir` (default `data/autobahn`): directory to persist autobahn consensus and data WALs across restarts. Relative paths are resolved against the node's `--home` dir at load time; absolute paths pass through unchanged. Pass `--persistent-state-dir=` (empty) to disable persistence and run both consensus and data layers **in-memory only**.
- Requires at least one node directory argument.

By default (`data/autobahn`), Autobahn persists both the consensus and data layer WALs to disk under a shared on-disk root, with distinct subdirectories per layer, so state survives node restarts. Persistence is on without operator action.

Example (4-node cluster):

```bash
seid tendermint gen-autobahn-config \
  build/generated/node_0 \
  build/generated/node_1 \
  build/generated/node_2 \
  build/generated/node_3 \
  --output ~/.sei/config/autobahn.json
```

Then set `autobahn-config-file` in `config.toml` to that path (placed before any `[section]` header). The generated config includes each validator's `validator_key`, `node_key`, and `address`, plus defaults such as `max_gas_per_block = 50000000`, `max_txs_per_block = 5000`, `mempool_size = 5000`, `block_interval = 400ms`, `view_timeout = 1500ms`, and `dial_interval = 10s`.



## FlatKV EVM in-flight migration

SeiDB supports an in-flight (online) migration of EVM state from memiavl into FlatKV, driven by the `sc-write-mode` config under `[state-commit]`. The in-flight migration modes are `migrate_evm`, `migrate_bank`, and `migrate_all_but_bank`; each drains keys from the old backend (memiavl) into the new backend (FlatKV) over multiple blocks.

### app.toml: [state-commit] migration fields

```toml
[state-commit]
# sc-write-mode selects the SC backend routing. In-flight migration modes:
#   migrate_evm | migrate_bank | migrate_all_but_bank
# (also: memiavl_only, evm_migrated, flatkv_only, test_only_dual_write, etc.)
sc-write-mode = "migrate_evm"

# sc-keys-to-migrate-per-block controls how many keys the in-flight migration
# drains from memiavl into FlatKV per block. Must be > 0; defaults to 1024
# when unset. Default 1024 is appropriate for production drains; lower it
# (e.g. 256) to spread the migration across more blocks.
sc-keys-to-migrate-per-block = 1024
```

Notes:

- `sc-keys-to-migrate-per-block` must be `> 0`. An absent app.toml entry preserves the default of `1024`; explicitly setting it to `0` fails `StateCommitConfig.Validate` ("keys-to-migrate-per-block must be > 0") and brings the node down at startup when write-mode is a migration mode.
- Flipping `sc-write-mode` into a migration mode across a validator quorum changes how EVM data contributes to the AppHash, so it must be done with a coordinated stop / edit / restart across all validators — flipping one node while the rest stay in the old mode diverges the AppHash and halts consensus.
- Once the migration completes, operators flip `sc-write-mode` from `migrate_evm` to `evm_migrated` so subsequent restarts do not spin up the migration manager. This flip is lossless (same version, same FlatKV root, same reads).

### Behavior during in-flight migration

While a migration is in flight (`NotStarted` / `InProgress`):

- **Reads** for unmigrated keys consult the old DB first and fall back to the new DB if not found — brand-new keys created after migration starts are routed to the new DB, so read transparency holds across the boundary.
- **Writes** to existing not-yet-migrated keys stay in the old DB until the iterator reaches them; writes to already-migrated keys and to brand-new keys go to the new DB (avoids the migration chasing an ever-growing key tail).
- **Iteration** is forwarded to the old-DB iterator. Caveat: keys already migrated out of the old DB are silently skipped, so iteration results may be incomplete during `InProgress` and must only be used for best-effort work (this self-heals once migration completes). Once migration is `Complete`, iteration is refused (the old DB has been retired).

### Polling migration status with `seidb migrate-evm-status`

Use the `seidb migrate-evm-status` subcommand to poll on-disk FlatKV migration state as JSON, without a custom RPC or grepping node logs:

```bash
seidb migrate-evm-status --db-dir <flatkv-dir> [--height <n>]
```

- `--db-dir` / `-d` (**required**): FlatKV database directory (e.g. `/root/.sei/data/state_commit/flatkv`).
- `--height` (default `0`): FlatKV target version; `0` selects the latest available version.

The tool hardlink-clones the latest snapshot + WAL into a temp dir before opening, so it can read concurrently with a live node without contending for the FlatKV writer lock. Example output:

```json
{
  "version_at": 1234,
  "migration_version": 1,
  "migrate_evm_complete": true,
  "boundary_present": false
}
```

- `migrate_evm_complete` is `true` once the `migration-version` key reaches `1` (Version1_MigrateEVM).
- `boundary_present` is `true` while the migration cursor is still in flight (strictly between not-started and complete).

This is the recommended way to poll for migration completion from the host across a multi-validator cluster: repeatedly run `migrate-evm-status` against each validator's FlatKV dir until every node reports `migrate_evm_complete: true`.

### Relationship to the offline import workflow

The offline `seidb import-flatkv-from-memiavl` path bulk-imports FlatKV from a memiavl snapshot before startup. The in-flight `migrate_evm` mode plus `migrate-evm-status` polling is the **online** alternative: the node keeps producing blocks while draining keys per block, and operators watch progress with `migrate-evm-status` rather than waiting for an offline import to finish.
