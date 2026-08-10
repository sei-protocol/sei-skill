# Architecture

## State Storage: SeiDB

Sei uses **SeiDB** for state storage. As of the IAVL removal, SeiDB state-commit (SC) is **mandatory** — the legacy IAVL backend has been fully removed and is no longer available as a fallback.

### State Commit (SC)

The state-commit layer is backed by **memIAVL** (an in-memory IAVL implementation with a write-ahead log and snapshotting). It is enabled via `sc-enable` in `app.toml`:

```toml
[state-commit]
# Enable defines if the state-commit should be enabled.
sc-enable = true
```

**`sc-enable` must be `true`.** If it is `false`, the node panics on startup:

```
panic: SeiDB state-commit (SC) must be enabled; IAVL backend has been fully deprecated
```

There is no IAVL fallback. memIAVL is the sole state-commit backend; it does not "override" or coexist with an IAVL db backend — the IAVL backend does not exist anymore.

### State Store (SS)

The optional state-store layer provides historical state for queries and is configured under `[state-store]`:

```toml
[state-store]
ss-enable = true
ss-backend = "pebbledb"
```

## Migration Notes

Node operators upgrading from a version that supported the IAVL backend must ensure `sc-enable = true` before upgrading. The following have been removed and no longer take effect:

### Removed CLI commands

- `seid compact` — compacted the application levelDB
- `seid debug dump-iavl [height]` (with `--db-path`/`-d`, `--output-dir`, `--module`/`-m`) — dumped IAVL data
- `seid prune` (with `--home`, `--app-db-backend`, `--pruning`, `--pruning-keep-recent`, etc.) — pruned app history states
- `seid latest_version` — printed the latest app DB version

### Removed `start` flags

- `--separate-orphan-storage`
- `--separate-orphan-versions-to-keep`
- `--num-orphan-per-file`
- `--orphan-dir`
- `--iavl-disable-fastnode`

### Removed `app.toml` config fields

- `iavl-cache-size`
- `iavl-disable-fastnode`
- `no-versioning`
- `separate-orphan-storage`
- `separate-orphan-versions-to-keep`
- `num-orphan-per-file`
- `orphan-dir`
- The entire `[iavl]` section (including `iavl.pruning`, `iavl.pruning-keep-recent`, `iavl.pruning-keep-every`, `iavl.pruning-interval`)

Only the top-level `pruning`, `pruning-keep-recent`, `pruning-keep-every`, and `pruning-interval` flags remain.

### Snapshots / restore

Legacy IAVL snapshot and restore via the rootmulti store are no longer supported. Attempting the legacy IAVL path returns an error:

```
legacy IAVL snapshots are no longer supported
legacy IAVL restore is no longer supported
```
