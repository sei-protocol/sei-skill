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
