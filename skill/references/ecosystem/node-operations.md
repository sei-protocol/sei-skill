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
sc-enable = true                    # Enable SeiDB (recommended)
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
- **Giga Storage (SC FlatKV routing)** is a *separate*, broader option that routes EVM **State Commit** data through FlatKV, controlled by the single `sc-write-mode` key:

  ```toml
  [state-commit]
  # Valid: memiavl_only (default), migrate_evm, evm_migrated, migrate_all_but_bank,
  # all_migrated_but_bank, migrate_bank, flatkv_only.  (test_only_dual_write is
  # test-only — never in production.) There is NO sc-read-mode and NO
  # sc-enable-lattice-hash key; the evm_lattice app-hash handling is internal.
  sc-write-mode = "memiavl_only"
  # Keys drained memiavl→FlatKV per block while migrating (migrate_* modes):
  sc-keys-to-migrate-per-block = 1024
  ```

  The migration is staged: `migrate_evm` drains EVM data in the background and settles at `evm_migrated`; later modes migrate the remaining modules.
- **Giga Executor** (`[giga_executor] enabled`) is a *separate* feature — an evmone-based EVM interpreter for throughput. Don't conflate it with Giga Storage.

> Minimum gas price, block gas limit, and SSTORE/storage gas are governance-adjustable — confirm live values at https://docs.sei.io/evm/differences-with-ethereum, and set `minimum-gas-prices` at or above the mainnet floor (`0usei` is local-dev only).



### seidb `trace-profile-report` (batch transaction profiling)

Batch-runs the `debug_traceTransactionProfile` JSON-RPC method across a block range and writes two files to the output directory: `raw_profiles.jsonl` (one JSON record per traced transaction) and `summary.json` (aggregate stats — average/p50/p95 total & historical-DB-lookup latencies, per-phase totals, per-module store-access totals, top transactions, and top blocks).

`debug_traceTransactionProfile(hash, config)` returns `{ trace, profile }`, where `profile` includes `totalNanos`, `historicalDbLookupNanos`, `otherNanos`, per-phase timings (`lookupTransactionNanos`, `loadBlockNanos`, `replayHistoricalTxsNanos`, `buildBlockContextNanos`, `prepareTxNanos`, `executionNanos`, `traceResultNanos`), and per-module store access stats/iterators. Enable it as a `debug_*` method on the EVM JSON-RPC endpoint (`8545`).

```bash
seid trace-profile-report \
  --endpoint http://localhost:8545 \
  --start-block 1000000 \
  --end-block 1000100 \
  --output-dir ./trace-report \
  --concurrency 4 \
  --trace-config-json '{}' \
  --max-transactions 0
```

Flags:

| Flag | Default | Purpose |
|---|---|---|
| `--endpoint` | *(required)* | RPC endpoint, e.g. `http://localhost:8545` |
| `--start-block` | *(required, >0)* | Starting block number |
| `--end-block` | *(required, >=start)* | Ending block number |
| `--output-dir` / `-o` | *(required)* | Directory for `raw_profiles.jsonl` and `summary.json` |
| `--concurrency` / `-c` | `4` | Concurrent `traceTransactionProfile` requests |
| `--trace-config-json` | `{}` | JSON object passed as the trace config |
| `--max-transactions` | `0` (no cap) | Optional cap on the number of transactions processed |

> Offline analysis tool — point it at an archive/RPC node with `debug_*` enabled. Each request has a 120s client timeout. The command collects tx hashes via `eth_getBlockByNumber` across the range, then traces them concurrently.




### seidb FlatKV analysis tooling

When a node runs Giga Storage (SC FlatKV routing — see `sc-write-mode` above), EVM State Commit data lives in a FlatKV store (a sibling `flatkv/` directory next to the memIAVL `committer.db`). Two seidb subcommands inspect it. Both operate on a **read-only temp clone** of the selected snapshot + changelog (snapshot files are hardlinked, changelog files are byte-copied) so they never contend for the live FlatKV writer lock — safe to run against a running node.

#### `dump-flatkv` — dump physical (key, value) pairs per bucket

Iterates every physical FlatKV (key, value) pair and writes one file per bucket (`account`, `code`, `storage`, `legacy`) into the output directory, formatted identically to `dump-iavl` so the same diff tooling works on both. Each file starts with a `Bucket <name> at version <V>` header followed by `Key: <HEX>, Value: <HEX>` lines. Physical keys are emitted verbatim (with their `<module>/` + type-prefix header). Internal metadata rows are excluded.

```bash
seid dump-flatkv \
  --db-dir /path/to/data/flatkv \
  --output-dir ./flatkv-dump \
  --height 0 \
  --bucket storage
```

| Flag | Default | Purpose |
|---|---|---|
| `--db-dir` / `-d` | *(required)* | FlatKV database directory |
| `--output-dir` / `-o` | *(required)* | Output directory (one file per bucket) |
| `--height` | `0` (latest) | FlatKV target version; `0` selects the latest available version |
| `--bucket` / `-b` | *(all)* | Restrict dump to a single bucket: `account`, `code`, `storage`, or `legacy` |

Bucket classification of physical EVM keys: nonce + codehash → `account`, code → `code`, storage → `storage`; any non-EVM module (or unrecognized EVM type prefix) → `legacy`.

#### `state-size --flatkv-dir` — fold FlatKV into state-size analysis

The existing `state-size` command now scans FlatKV alongside memIAVL. Supply `--flatkv-dir` explicitly, or leave it unset to auto-detect a sibling `flatkv/` directory next to `--db-dir` (e.g. `<home>/data/committer.db` → `<home>/data/flatkv`). FlatKV is only scanned when `--module` is empty or `evm` (FlatKV holds only EVM keys). FlatKV analysis is strictly additive — any FlatKV open/scan failure is logged and skipped, leaving the memIAVL analysis intact.

```bash
seid state-size \
  --db-dir /path/to/data/committer.db \
  --flatkv-dir /path/to/data/flatkv \
  --height 0
```

Relevant flags:

| Flag | Default | Purpose |
|---|---|---|
| `--db-dir` / `-d` | *(required)* | memIAVL database directory |
| `--flatkv-dir` | auto-detect `<db-dir>/../flatkv` | FlatKV data directory (empty + no sibling ⇒ FlatKV skipped) |
| `--module` / `-m` | *(all)* | Module to analyze; FlatKV scanned only when empty or `evm` |
| `--height` | `0` (latest) | Block height / version |
| `--export-dynamodb` | `false` | Export to DynamoDB instead of printing; FlatKV is added as a `flatkv` module row in the same batch |

Console output notes (as of this change): modules are printed alphabetically for diffable runs, the prefix breakdown is marshaled as a full map (key/value/total bytes + key count per prefix byte), and scan progress logs every **10M** keys (previously 1M). The FlatKV section reports total keys/size, a per-DB breakdown (`account`/`code`/`storage`/`legacy`), and the top EVM contracts by storage size.

> Both commands are offline analysis tools. `--height 0` uses the latest snapshot; an explicit height selects the newest snapshot at or below that version.



---

## Legacy `sei_*` / `sei2_*` JSON-RPC gating (`app.toml [evm]`)

All `sei_*` and `sei2_*` JSON-RPC methods (EVM HTTP endpoint on `8545` only — not the Cosmos REST API on `1317`) are **deprecated and scheduled for removal**. New integrations should use `eth_*` / `debug_*` methods. Access to these gated methods is controlled by `[evm].enabled_legacy_sei_apis` in `app.toml`.

```toml
[evm]
# Only methods listed here are served on the EVM HTTP endpoint.
# seid init / DefaultConfig pre-fills just these three address/Cosmos helpers:
enabled_legacy_sei_apis = ["sei_getSeiAddress", "sei_getEVMAddress", "sei_getCosmosTx"]
```

- **Env var / flag:** `evm.enabled_legacy_sei_apis`.
- **Default:** only the three helpers `sei_getSeiAddress`, `sei_getEVMAddress`, `sei_getCosmosTx` are enabled out of the box. Every other gated `sei_*` and `sei2_*` method must be **explicitly added to the list**, or it fails closed.
- **Behavior when a method is not allowlisted:** the node returns **HTTP 200** with a JSON-RPC error — code `-32601`, `data = "legacy_sei_deprecated"`, and a message noting the method is not enabled and is deprecated. The inner handler is never invoked. Unknown `sei_*` / `sei2_*` names (typos, future methods) also fail closed. Matching is case-insensitive against canonical method names.
- **Behavior when a method is allowlisted:** the call passes through unchanged; the response may include the HTTP header `Sei-Legacy-RPC-Deprecation` as a deprecation signal (JSON body is not mutated).
- **`sei2_*` namespace:** seven block-only methods that mirror `sei_*` block payloads but include bank transfers (HTTP only) — `sei2_getBlockByHash`, `sei2_getBlockByNumber`, `sei2_getBlockReceipts`, `sei2_getBlockTransactionCountByHash`, `sei2_getBlockTransactionCountByNumber`, and the `*ExcludeTraceFail` variants. There is no `sei2` transaction or filter API. They are gated by the same `enabled_legacy_sei_apis` list.

To enable more legacy methods, add their exact names to the array, e.g.:

```toml
[evm]
enabled_legacy_sei_apis = [
  "sei_getSeiAddress",
  "sei_getEVMAddress",
  "sei_getCosmosTx",
  "sei_getBlockByNumber",
  "sei_getLogs",
  "sei2_getBlockByNumber",
]
```

> Because the list is an allowlist, upgrading a node keeps only the three default helpers enabled unless you explicitly re-add the legacy methods your integrations still depend on. Plan migrations to `eth_*` / `debug_*` accordingly.

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
