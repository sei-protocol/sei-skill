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
- 8+ CPU cores, 64 GB RAM, 2 TB NVMe SSD
- Go 1.21+ installed

### Build from Source

```bash
git clone https://github.com/sei-protocol/sei-chain.git
cd sei-chain
git checkout <latest-version>   # e.g. v5.9.0
make install

# Verify
seid version
```

### Initialize Node

```bash
# Initialize with your moniker
seid init <YOUR_MONIKER> --chain-id pacific-1

# Download genesis
curl -s https://raw.githubusercontent.com/sei-protocol/testnet/main/pacific-1/genesis.json \
  > $HOME/.sei/config/genesis.json
```

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
minimum-gas-prices = "0.01usei"

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
