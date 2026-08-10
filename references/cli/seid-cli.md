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
