---
title: Node Operations on Sei
description: Running and maintaining Sei full nodes — node types, setup, state sync, configuration, database management, service management, and performance tuning.
---

# Node Operations on Sei

## Node Types

| Type | Purpose | Config |
|---|---|---|
| **Full / RPC** | Query data, relay txs | Default settings |
| **Archive** | Full history from genesis (10 TB+) | `min-retain-blocks=0`, `pruning="nothing"` |
| **State Sync** | Provide snapshots to bootstrap peers | `enable=true` under `[statesync]` in `config.toml` |
| **Validator** | Sign blocks, secure network | `mode=validator` in `config.toml` + sufficient delegation |

---

## Quick Node Setup

### Prerequisites

- Ubuntu 22.04 (recommended) or macOS
- 16+ CPU cores, 256 GB DDR5 RAM, 2 TB NVMe SSD
- Go 1.24.x installed (required for seid v6.3+)

### Build from Source

```bash
git clone https://github.com/sei-protocol/sei-chain.git
cd sei-chain
git checkout <version-tag>   # pick the recommended tag from the Network Versions table on docs.sei.io
make install

# Verify
seid version
```

### Initialize Node

```bash
# Initialize with your moniker. genesis.json is written automatically for known
# networks (mainnet/testnets) — do NOT hand-download or overwrite it.
seid init <YOUR_MONIKER> --chain-id pacific-1

# For a validator (binds RPC/P2P to localhost), init in validator mode instead:
# seid init <YOUR_MONIKER> --chain-id pacific-1 --mode validator
```

> **Never start from genesis on a live network** — it panics with `integer divide by zero`. Bootstrap via state sync (below) or a snapshot.

---

## State Sync (Recommended for Fast Bootstrap)

State sync fetches a recent snapshot instead of replaying all history — reduces sync from days to minutes.

### Automated State Sync

```bash
#!/bin/bash
# Set these before running
STATE_SYNC_RPC="https://rpc.sei-apis.com:443"   # or https://sei-rpc.polkachu.com:443

# Backup validator keys if upgrading an existing node
cp $HOME/.sei/config/priv_validator_key.json $HOME/priv_validator_key.json.bak
cp $HOME/.sei/data/priv_validator_state.json $HOME/priv_validator_state.json.bak

# Reset state (existing nodes only)
seid tendermint unsafe-reset-all --home $HOME/.sei
rm -rf $HOME/.sei/data/* $HOME/.sei/wasm

# Fetch latest trusted height and hash
LATEST_HEIGHT=$(curl -s $STATE_SYNC_RPC/block | jq -r .block.header.height)
BLOCK_HEIGHT=$(( (LATEST_HEIGHT / 100000) * 100000 ))
TRUST_HASH=$(curl -s "$STATE_SYNC_RPC/block?height=$BLOCK_HEIGHT" | jq -r .block_id.hash)

# Configure statesync in config.toml
sed -i.bak -E "
s|^(enable[[:space:]]+=[[:space:]]+).*$|\1true|
s|^(rpc-servers[[:space:]]+=[[:space:]]+).*$|\1\"$STATE_SYNC_RPC,$STATE_SYNC_RPC\"|
s|^(trust-height[[:space:]]+=[[:space:]]+).*$|\1$BLOCK_HEIGHT|
s|^(trust-hash[[:space:]]+=[[:space:]]+).*$|\1\"$TRUST_HASH\"|
" $HOME/.sei/config/config.toml

# Set persistent peers for mainnet (pacific-1)
PEERS="3be6b24cf86a5938cce7d48f44fb6598465a9924@p2p.state-sync-0.pacific-1.seinetwork.io:26656,b21279d7092fde2e41770832a1cacc7d0051e9dc@p2p.state-sync-1.pacific-1.seinetwork.io:26656"
sed -i "s|^persistent-peers *=.*|persistent-peers = \"$PEERS\"|" $HOME/.sei/config/config.toml

sudo systemctl start seid
```

State sync peers:
- **Mainnet (pacific-1)**: `https://rpc.sei-apis.com:443` or `https://sei-rpc.polkachu.com:443`
- **Testnet (atlantic-2)**: `https://rpc-testnet.sei-apis.com:443`

---

## Directory Structure

```
$HOME/.sei/config/
├── app.toml                  # Gas prices, API, pruning
├── config.toml               # P2P, RPC, consensus, statesync
├── client.toml               # CLI settings
├── genesis.json              # Chain genesis
├── node_key.json             # P2P identity key
└── priv_validator_key.json   # Validator signing key (validators only)
```

---

## Essential Configuration

### config.toml (P2P + RPC)

```toml
[p2p]
external-address = "YOUR_PUBLIC_IP:26656"
laddr = "tcp://0.0.0.0:26656"
max-num-inbound-peers = 40
max-num-outbound-peers = 20
send-rate = 204800000   # 200 MB/s
recv-rate = 204800000

[rpc]
laddr = "tcp://0.0.0.0:26657"
max-open-connections = 900
timeout-broadcast-tx-commit = "10s"
```

### app.toml (Database + API)

```toml
minimum-gas-prices = "0.02usei"   # set at or above the mainnet-enforced floor; 0usei = local dev only

[api]
enable = true
max-open-connections = 1000

[state-commit]
sc-enable = true                    # Enable state-commit. As of Sei v6.6.0 SC is MANDATORY:
                                    # the node PANICS at startup if sc-enable is false
                                    # ("SeiDB state-commit (SC) must be enabled; IAVL
                                    #  backend has been fully deprecated"). The legacy IAVL
                                    # backend has been fully removed.
sc-async-commit-buffer = 100
sc-keep-recent = 1
sc-snapshot-interval = 10000

[state-store]
ss-enable = true
ss-backend = "pebbledb"
ss-keep-recent = 100000             # Keep last 100k blocks
ss-prune-interval = 600
```

---

## SeiDB storage, RocksDB, and Giga

SeiDB has two layers: **State Commit (SC)** — a memiavl Merkle tree that holds Cosmos module state and computes the app hash — and **State Store (SS)** — versioned raw key/values for historical queries (`ss-enable = true` is required for any RPC node).

- **RocksDB SS backend** (optional): faster for iteration-heavy work (`debug_trace*`, large archive queries). Build with `make build-rocksdb && make install-rocksdb`, then set `ss-backend = "rocksdb"`. RocksDB RPC nodes must state-sync on first start.
- **Giga SS Store** (optional, RPC nodes): splits the **State Store** so EVM state lives in its own SS DB. Controlled by a single bool — `evm-ss-split = true` (Sei v6.5+; older releases used per-key `evm-ss-write-mode`/`evm-ss-read-mode`). Requires a **fresh state sync** — flipping it on a node with existing data fails startup safety checks. **SC config is left untouched.** See the [Giga SS Store Migration Guide](https://docs.sei.io/node/giga-storage-migration).
- **Giga Storage (SC FlatKV routing)** is a *separate*, broader option that routes EVM **State Commit** data through FlatKV. Since v6.7.0 the migration is **governance-driven**: `state-commit.sc-write-mode-enable-auto` defaults to `true` (it is not rendered into `app.toml`), which runs the node in `auto` and **ignores** `sc-write-mode`. The per-block drain rate is the on-chain param `migration.NumKeysToMigratePerBlock` (default `0` = paused), set by governance — see [staking-governance.md](staking-governance.md). The old `sc-keys-to-migrate-per-block` key was removed.

  ```toml
  [state-commit]
  # Ignored while sc-write-mode-enable-auto is true (the default).
  # Valid: memiavl_only (default), migrate_evm, evm_migrated, migrate_all_but_bank,
  # all_migrated_but_bank, migrate_bank, flatkv_only, auto. (test_only_dual_write
  # is test-only — never in production.) There is NO sc-read-mode and NO
  # sc-enable-lattice-hash key; the evm_lattice app-hash handling is internal.
  sc-write-mode = "memiavl_only"
  # Only to pin an explicit mode — a pinned node does not follow the
  # governance-driven migration and diverges once the chain migrates:
  # sc-write-mode-enable-auto = false
  ```

  The migration is staged: `migrate_evm` drains EVM data in the background and settles at `evm_migrated`; later modes migrate the remaining modules.
- **Giga Executor** (`[giga_executor] enabled`) is a *separate* feature — an evmone-based EVM interpreter for throughput. Don't conflate it with Giga Storage.

> Minimum gas price, block gas limit, and SSTORE/storage gas are governance-adjustable — confirm live values at https://docs.sei.io/evm/differences-with-ethereum, and set `minimum-gas-prices` at or above the mainnet floor (`0usei` is local-dev only).



---

## Legacy `sei_*` JSON-RPC gating (`[evm] enabled_legacy_sei_apis`)

Only three legacy `sei_*` methods remain on the EVM HTTP endpoint (port `8545` — not WebSocket, and not the Cosmos REST API on `1317`): `sei_getSeiAddress`, `sei_getEVMAddress`, and `sei_getCosmosTx`. They are deprecated; build new integrations on `eth_*` / `debug_*`. The `sei2_*` namespace and all other `sei_*` methods were removed ([sei-chain#3912](https://github.com/sei-protocol/sei-chain/pull/3912), [#3924](https://github.com/sei-protocol/sei-chain/pull/3924), [#3927](https://github.com/sei-protocol/sei-chain/pull/3927), [#3945](https://github.com/sei-protocol/sei-chain/pull/3945)); the `sei_traceBlockBy*ExcludeTraceFail` endpoints went in v6.6.0.

`sei_getTransactionReceipt` has been **fully removed** — it is no longer available even when explicitly listed in the allowlist. Use `eth_getTransactionReceipt` instead. There is no longer any JSON-RPC method for discovering synthetic logs from Cosmos-originated transactions.

Which of these are served is controlled by the `enabled_legacy_sei_apis` allowlist under `[evm]` in `app.toml`:

```toml
[evm]
# seid init / DefaultConfig list all three remaining address/Cosmos helpers.
enabled_legacy_sei_apis = [
  "sei_getSeiAddress",
  "sei_getEVMAddress",
  "sei_getCosmosTx",
]
```

- **Only these three names have any effect.** Names are matched case-insensitively; any other name in the list is ignored, so a removed method (including `sei_getTransactionReceipt`) cannot be re-enabled.
- **Internally read through the AppOptions/viper key** `evm.enabled_legacy_sei_apis` (an environment-variable override via viper is possible; there is no dedicated `seid` CLI flag).
- The Docker localnet config (`docker/localnode/config/app.toml`) lists the same three.

### Behavior for legacy calls (all HTTP 200)

- **Any other `sei_*` name** (removed, misspelled, or left out of the allowlist): JSON-RPC error — code `-32601`, `data` `"legacy_sei_deprecated"`, and a message saying the method is not enabled on this node. The request never reaches a handler.
- **`sei2_*` names**: the standard `-32601` `the method ... does not exist/is not available`.
- **Allowed**: passes through unchanged (JSON body identical), but the response may set the HTTP header `Sei-Legacy-RPC-Deprecation` signaling deprecation.

---

## `debug_trace*` tracer gating (`[evm] trace_allowed_tracers` / `trace_allow_js_tracers`)

Since v6.7.0 ([sei-chain#3718](https://github.com/sei-protocol/sei-chain/pull/3718)) caller-supplied `TraceConfig.Tracer` values on `debug_traceCall`, `debug_traceTransaction`, `debug_traceBlockByNumber`, `debug_traceBlockByHash`, and `debug_traceTransactionProfile` are gated by two `[evm]` fields in `app.toml`. This is a deliberate deviation from upstream geth, which accepts any supported tracer (including request-supplied JavaScript) by default.

```toml
[evm]
# Native debug tracers callers may request with TraceConfig.Tracer. Validated
# native-only at startup; a non-native / typo'd name fails startup. The default
# struct logger (TraceConfig.Tracer omitted) is always available. Set to [] to
# disable all named tracers.
trace_allowed_tracers = ["callTracer", "prestateTracer", "flatCallTracer", "4byteTracer", "noopTracer", "muxTracer"]

# Opt in to request-supplied JavaScript tracer source in TraceConfig.Tracer.
# Executes untrusted code in-process — keep disabled on public/default RPC nodes.
# Enabling it does NOT widen trace_allowed_tracers: native names must still be
# listed above to be usable.
trace_allow_js_tracers = false
```

- **`trace_allowed_tracers`** — the native geth tracer names a caller may pass via `TraceConfig.Tracer`. Default: `["callTracer", "prestateTracer", "flatCallTracer", "4byteTracer", "noopTracer", "muxTracer"]`. Only native tracers are accepted here; entries are validated native-only at startup (empty or non-native/typo'd names fail startup), deduplicated, and whitespace-trimmed. Set to `[]` to disable all named tracers (the default struct logger still works when `Tracer` is omitted).
- **`trace_allow_js_tracers`** — default `false`. When `false`, any request-supplied JavaScript tracer source is rejected; a tracer name not in `trace_allowed_tracers` is rejected with an error noting JavaScript tracers are disabled. Setting it to `true` is a separate opt-in that allows request-supplied JS — it does **not** widen the native allowlist, so native names must still appear in `trace_allowed_tracers` to be usable.
- **`muxTracer` nesting** — when `muxTracer` is requested, its nested tracer names are validated recursively against the same allowlist, bounded to a nesting depth of 16. Nested names must not contain leading/trailing whitespace (they are forwarded to geth inside the raw JSON and cannot be rewritten).
- **`trace_bake_tracers`** — now held to the same native-only rule and validated at startup; a non-native or JS-looking name fails startup rather than being evaluated as JS source by the baker on every committed block. Default: `["callTracer"]`.

Both fields are read through the AppOptions/viper keys `evm.trace_allowed_tracers` and `evm.trace_allow_js_tracers`. Validation runs before trace-cache lookups and before any tracer is constructed.

---

## Commonly Used Ports

| Port | Protocol | Purpose |
|---|---|---|
| `26656` | TCP | P2P — must be open to join the network |
| `26657` | TCP | Tendermint RPC |
| `1317` | TCP | Cosmos REST API |
| `9090` | TCP | gRPC |
| `8545` | TCP | EVM JSON-RPC (HTTP) |
| `8546` | TCP | EVM JSON-RPC (WebSocket) |
| `26660` | TCP | Prometheus metrics (disabled by default) |

---

## Systemd Service

```ini
[Unit]
Description=Sei Node
After=network.target

[Service]
User=<USER>
Type=simple
ExecStart=<PATH_TO_SEID>/seid start --chain-id pacific-1
Restart=always
RestartSec=30
TimeoutStopSec=30
KillSignal=SIGINT
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
```

```bash
# Service management
systemctl status seid
systemctl start seid
systemctl stop seid
systemctl restart seid

# Live logs
journalctl -fu seid -o cat
```

---

## Update Procedures

### Non-consensus-breaking Update

```bash
sudo systemctl stop seid
cd sei-chain && git fetch --all && git checkout <new-version>
make install
sudo systemctl restart seid
```

### Governance Upgrade (consensus-breaking)

1. Monitor the upgrade block height (in the upgrade proposal's `plan` field)
2. Node halts automatically at the upgrade height
3. Build the new binary **before** the halt height to minimize downtime
4. Replace binary and restart:

```bash
cd sei-chain && git pull && git checkout <new-version>
make install
sudo systemctl restart seid
```

---

## Freeze Height (`--freeze-height` / `freeze-height`)

Stops the node **before executing** a target block while **continuing to serve RPC** (the process and gRPC/JSON-RPC servers keep running). Unlike `halt-height`, which gracefully shuts the node down, freeze mode keeps the node alive and queryable at `freeze-height - 1`.

Enable it via the start flag or the top-level `freeze-height` key in `app.toml` (both default `0` = disabled):

```bash
# CLI flag on the start command
seid start --freeze-height 12345678
```

```toml
# app.toml — top-level key next to halt-height / halt-time (not under any [section])
freeze-height = 12345678
```

To serve historical EVM JSON-RPC from frozen nodes behind one endpoint, put [frozen-rpc-router](../cli/frozen-rpc-router.md) in front of them.

### Behavior

- Block sync and consensus stop before executing the block at `freeze-height` and never advance beyond it — the node settles at `freeze-height - 1`.
- The node keeps serving query RPC while frozen (no WAL writes, no new consensus rounds).
- The node is read-only from startup: **transaction and evidence submission and mempool gossip are disabled**. Broadcasts (including `eth_sendRawTransaction`, which goes through the same path) fail with `RPC writes are disabled in freeze mode`; send transactions to a live node.
- **State sync is disabled** when freeze mode is active and the node falls back to block sync.
- Auto-remediation restart halts at the freeze boundary rather than restarting past it.

### Validation constraints (startup fails if violated)

- `freeze-height` **cannot be combined with `halt-height` or `halt-time`**.
- `--freeze-height` **cannot be used with grpc-only mode**.
- **Full nodes only** — not supported in validator or seed mode (`mode = "validator"` / `mode = "seed"` in `config.toml`).
- **Not supported with Autobahn** (fails if `autobahn-config-file` is set).
- Must **not exceed `MaxInt64`** (`9223372036854775807`).
- Must be **at or above the genesis initial height** and **above the current application, block store, and state store heights** — you cannot freeze at a height the node has already reached or passed.

---

## Database Management

```bash
# Check data directory size
du -sh $HOME/.sei/data/

# Backup before any maintenance
cp -r $HOME/.sei/data/ $HOME/sei-backup-$(date +%Y%m%d)/

# Full backup (node stopped)
systemctl stop seid
tar czf /backup/sei-backup-$(date +%Y%m%d).tar.gz $HOME/.sei/
systemctl start seid
```

### Wipe and Resync

```bash
# ALWAYS back up these files first:
# priv_validator_key.json — validator signing key (losing this risks double-sign)
# priv_validator_state.json — last signed height (losing this risks double-sign)

cp $HOME/.sei/config/priv_validator_key.json $HOME/priv_validator_key.json.bak
cp $HOME/.sei/data/priv_validator_state.json $HOME/priv_validator_state.json.bak

find $HOME/.sei/data/ -mindepth 1 ! -name 'priv_validator_state.json' -delete
rm -rf $HOME/.sei/wasm
```

---

## Performance Tuning

### Kernel Parameters (sysctl)

```bash
# Add to /etc/sysctl.conf and run sysctl -p
vm.swappiness = 1
vm.dirty_background_ratio = 3
vm.dirty_ratio = 10
net.core.somaxconn = 32768
net.core.netdev_max_backlog = 32768
net.ipv4.tcp_max_syn_backlog = 16384
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
```

### NVMe Storage

```bash
echo "none" > /sys/block/nvme0n1/queue/scheduler   # disable I/O scheduler
blockdev --setra 4096 /dev/nvme0n1                  # optimize sequential reads
```

### Log Rotation

```bash
sudo tee /etc/logrotate.d/sei > /dev/null << 'EOF'
/var/log/sei/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 sei sei
    sharedscripts
    postrotate
        systemctl reload seid
    endscript
}
EOF
```
