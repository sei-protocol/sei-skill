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
