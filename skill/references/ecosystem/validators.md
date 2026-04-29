---
title: Validator Operations on Sei
description: Setting up and running a Sei validator — key management, HSM, creating a validator, jailing/unjailing, commission, monitoring, and security hardening.
---

# Validator Operations on Sei

## Key Concepts

- Sei uses **delegated proof-of-stake (dPoS)** — validators need bonded stake (own + delegated) to enter the active set
- **No slashing of funds** in Sei (jailing occurs for downtime but does not slash delegator tokens)
- `priv_validator_key.json` is the consensus signing key — losing it or double-signing is catastrophic
- Validator set is bounded by the `MaxValidators` governance parameter (default 100)

---

## Key Management

### Key Types

| File | Purpose | Risk if lost |
|---|---|---|
| `node_key.json` | P2P identity | Node loses its peer identity — low risk |
| `priv_validator_key.json` | Consensus signing | Cannot sign blocks; if stolen → double-sign risk |
| `priv_validator_state.json` | Last signed height | If reset to zero → double-sign risk |

### Create Operator Key

```bash
# Create a new key (stored in OS keyring by default)
seid keys add validator-key

# Or recover from mnemonic
seid keys add validator-key --recover

# List keys
seid keys list

# Export key address
seid keys show validator-key --bech val
```

### Backup Strategy

```bash
# Before any maintenance, always back up:
cp $HOME/.sei/config/priv_validator_key.json /secure-offline-backup/
cp $HOME/.sei/data/priv_validator_state.json /secure-offline-backup/

# Never share priv_validator_key.json — ever
# Store on encrypted USB or hardware HSM
```

### Hardware Security Module (HSM) Integration

For production validators, use a remote signing HSM to prevent key exposure:

```toml
# config.toml — connect to remote signer (Horcrux, TMKMS, etc.)
[priv-validator]
key-type = "socket"
laddr = "tcp://127.0.0.1:1234"
server-address = "tcp://HSM_HOST:1234"
```

Common HSM/remote signer options:
- **TMKMS** (Tendermint Key Management System) — battle-tested, supports YubiHSM2/Ledger
- **Horcrux** — threshold signing across multiple signers (no single point of failure)

---

## Creating a Validator

### 1. Ensure Node is Synced

```bash
# Check sync status — wait until catching_up is false
seid status | jq .SyncInfo
```

### 2. Fund Your Account

```bash
# Check your balance
seid q bank balances $(seid keys show validator-key -a) \
  --node https://rpc.sei-apis.com

# Need at least your self-delegation amount + gas
```

### 3. Submit Create-Validator Transaction

```bash
seid tx staking create-validator \
  --amount 1000000usei \                          # self-delegation (1 SEI)
  --pubkey $(seid tendermint show-validator) \    # consensus pubkey
  --moniker "My Validator" \
  --chain-id pacific-1 \
  --commission-rate 0.10 \                        # 10% commission
  --commission-max-rate 0.20 \                    # max 20% commission
  --commission-max-change-rate 0.01 \             # max 1% change per day
  --min-self-delegation 1 \
  --from validator-key \
  --node https://rpc.sei-apis.com \
  --fees 20000usei
```

### 4. Verify Validator Status

```bash
# Query your validator
seid q staking validator $(seid keys show validator-key --bech val -a) \
  --node https://rpc.sei-apis.com

# Check if in active set
seid q staking validators \
  --node https://rpc.sei-apis.com | grep "My Validator"
```

---

## Validator Lifecycle

### Monitor Signing Status

```bash
# Check missed blocks / signing info
seid q slashing signing-info \
  $(seid tendermint show-validator) \
  --node https://rpc.sei-apis.com
```

### Jailing

A validator is **jailed** (excluded from consensus) for prolonged downtime:

```bash
# Check if jailed
seid q staking validator <VALIDATOR_ADDRESS> \
  --node https://rpc.sei-apis.com | grep jailed
```

### Unjailing

```bash
seid tx slashing unjail \
  --from validator-key \
  --chain-id pacific-1 \
  --node https://rpc.sei-apis.com \
  --fees 20000usei
```

> Note: There is no slashing of funds in Sei — jailing only excludes the validator from block signing and rewards; delegator tokens are safe.

### Update Commission

```bash
seid tx staking edit-validator \
  --commission-rate 0.08 \
  --from validator-key \
  --chain-id pacific-1 \
  --node https://rpc.sei-apis.com \
  --fees 20000usei

# Commission can only decrease (or stay equal) within max-change-rate per day
```

### Halt / Graceful Shutdown

```bash
# Stop signing (e.g., for maintenance)
sudo systemctl stop seid

# Restart after maintenance
sudo systemctl start seid
# Node auto-resumes signing once synced
```

---

## Delegation and Rewards

### Self-delegation

```bash
# Increase self-delegation
seid tx staking delegate $(seid keys show validator-key --bech val -a) \
  5000000usei \
  --from validator-key \
  --chain-id pacific-1 \
  --node https://rpc.sei-apis.com \
  --fees 20000usei
```

### Claim Validator Commission

```bash
seid tx distribution withdraw-validator-commission \
  $(seid keys show validator-key --bech val -a) \
  --from validator-key \
  --chain-id pacific-1 \
  --node https://rpc.sei-apis.com \
  --fees 20000usei
```

### Withdraw Delegator Rewards

```bash
seid tx distribution withdraw-all-rewards \
  --from validator-key \
  --chain-id pacific-1 \
  --node https://rpc.sei-apis.com \
  --fees 20000usei
```

---

## Monitoring

### Prometheus Metrics

Enable Prometheus in `config.toml`:

```toml
[instrumentation]
prometheus = true
prometheus-listen-addr = ":26660"
```

Key metrics to monitor:

| Metric | Alert threshold |
|---|---|
| `tendermint_consensus_height` | Stalled (no increment) |
| `tendermint_consensus_validators_power` | Drop in total power |
| `tendermint_p2p_peers` | < 5 peers |
| `process_resident_memory_bytes` | > 80% available RAM |

### Grafana Dashboard

Import the community Sei validator Grafana dashboard (search "Sei Validator" on grafana.com) and point it to your Prometheus endpoint.

### Log Monitoring (systemd)

```bash
# Watch for consensus errors
journalctl -fu seid -o cat | grep -E "ERROR|WARN|panic|missed"

# Count missed blocks in last hour
journalctl -u seid --since "1 hour ago" | grep "missed" | wc -l
```

---

## Security Hardening

```bash
# Firewall: only expose necessary ports
ufw default deny incoming
ufw allow 22/tcp        # SSH
ufw allow 26656/tcp     # P2P (required)
# Only open 26657, 8545, 8546 if running a public RPC node
ufw enable

# SSH: disable password auth, require keys
echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
echo "PermitRootLogin no" >> /etc/ssh/sshd_config
systemctl restart sshd

# Separate validator node from public RPC node
# Do NOT expose validator node's RPC publicly
# Use a sentry node architecture for DDoS protection
```

### Sentry Node Architecture

```
[Internet]
    |
[Sentry Node 1] ← public P2P
[Sentry Node 2] ← public P2P
    |
[Validator Node] ← only talks to sentry nodes (private_peer_ids)
```

```toml
# Validator node config.toml — only connect to sentries
persistent-peers = "SENTRY_1_ID@sentry1-private-ip:26656,SENTRY_2_ID@sentry2-private-ip:26656"
private-peer-ids = ""   # validator has no public peers
pex = false             # disable peer exchange
```

---

## Useful Queries

```bash
# Validator set (active validators)
seid q staking validators --status bonded --node https://rpc.sei-apis.com

# Your validator's rank / voting power
seid q staking validator $(seid keys show validator-key --bech val -a) \
  --node https://rpc.sei-apis.com | grep -E "tokens|status|jailed"

# Pending rewards
seid q distribution commission \
  $(seid keys show validator-key --bech val -a) \
  --node https://rpc.sei-apis.com

# Slashing parameters (downtime threshold, etc.)
seid q slashing params --node https://rpc.sei-apis.com
```
