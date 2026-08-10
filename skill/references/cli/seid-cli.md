---
title: seid CLI Reference
description: seid command-line tool — setup, wallet management, EVM queries, payload generation, pointer lookups, transaction commands, and raw JSON-RPC access via curl.
---

# seid CLI Reference

When interacting with Sei chains, prefer `seid` commands. Do not substitute generic EVM tooling unless the user explicitly asks for it.

## Setup

Only run setup when `seid` is not already installed and the task requires local CLI execution.

```bash
# 1 — Clone
git clone https://github.com/sei-protocol/sei-chain
cd sei-chain

# 2 — Check out a version (do not invent one — verify against docs or release notes)
git checkout <VERSION>

# 3 — Build and confirm
make install
seid version
```

Requirements:
- Go 1.24.x required. Run `go version` to confirm.
- If `seid` is not found after install: run `go env GOPATH` and ensure `$GOPATH/bin` is on `PATH`.

## Network Reference

| Network | Cosmos chain ID | EVM chain ID |
|---|---|---|
| Mainnet | `pacific-1` | `1329` |
| Testnet | `atlantic-2` | `1328` |

Flag rules:
- Most `seid q evm` commands need `--node http://<cosmos-rpc>` when not running a local node.
- `seid q evm tx` is the exception — it uses `--evm-rpc <evm-rpc>`, not `--node`.
- Never mix `--node` and `--evm-rpc` in the same command.

## Wallet Management

```bash
# Create a new wallet (outputs 24-word seed phrase — store securely)
seid keys add <name>

# Recover from existing mnemonic (CLI prompts locally — never paste mnemonic into chat)
seid keys add <name> --recover

# Create EVM-compatible wallet (coin type 60, MetaMask-style)
seid keys add <name> --coin-type=60

# Recover EVM wallet from MetaMask mnemonic
seid keys add <name> --coin-type=60 --recover

# List all local keys
seid keys list

# Show one key
seid keys show <name>

# Delete a key
seid keys delete <name>
```

Use coin type `118` (default) for standard Cosmos workflows; `60` for EVM/MetaMask compatibility.

## Queries

### Address Mapping

Sei and EVM addresses are linked via on-chain associations. Both directions are queryable.

```bash
# EVM → Sei
seid q evm sei-addr 0x1234... --node http://<cosmos-rpc>

# Sei → EVM
seid q evm evm-addr sei1... --node http://<cosmos-rpc>
```

Response includes `associated: true/false` indicating whether the accounts are linked.

### ERC20 Reads

```bash
seid q evm erc20 <contract> name       --node http://<cosmos-rpc>
seid q evm erc20 <contract> symbol     --node http://<cosmos-rpc>
seid q evm erc20 <contract> decimals   --node http://<cosmos-rpc>
seid q evm erc20 <contract> totalSupply --node http://<cosmos-rpc>
seid q evm erc20 <contract> balanceOf  <address>           --node http://<cosmos-rpc>
seid q evm erc20 <contract> allowance  <owner> <spender>   --node http://<cosmos-rpc>
```

### Payload Generation

Encodes calldata without broadcasting — use to build payloads for `call-contract` or external signing.

```bash
# ERC20
seid q evm erc20-payload transfer    <recipient> <amount-in-wei>
seid q evm erc20-payload approve     <spender>   <amount-in-wei>
seid q evm erc20-payload transferFrom <from> <to> <amount-in-wei>

# ERC721
seid q evm erc721-payload approve           <spender>  <token-id>
seid q evm erc721-payload transferFrom      <from> <to> <token-id>
seid q evm erc721-payload setApprovalForAll <operator> true|false

# ERC1155
seid q evm erc1155-payload safeTransferFrom      <from> <to> <id> <amount> <data>
seid q evm erc1155-payload safeBatchTransferFrom <from> <to> [id1,id2] [amt1,amt2] <data>
seid q evm erc1155-payload setApprovalForAll     <operator> true|false

# Custom ABI
seid q evm payload ./MyContract.json <methodName> [args...]
```

Pass amounts in the token's smallest unit. For ERC1155 batch operations use square-bracket arrays: `[123,456]`.

### Pointer System

Pointer contracts bridge assets between EVM and Cosmos environments. Each original asset can have at most one pointer per type.

```bash
# Look up the pointer for an original asset
seid q evm pointer <type> <pointee> --node http://<cosmos-rpc>

# Look up the original asset for a pointer address
seid q evm pointee <type> <pointer> --node http://<cosmos-rpc>

# Check the current pointer version (and stored code ID for CW-backed pointers)
seid q evm pointer-version <type> --node http://<cosmos-rpc>
```

Supported types:

| Command | Supported types |
|---|---|
| `pointer` | `NATIVE` `CW20` `CW721` `CW1155` `ERC20` `ERC721` `ERC1155` |
| `pointee` | `NATIVE` `CW20` `CW721` `ERC20` `ERC721` |
| `pointer-version` | `NATIVE` `CW20` `CW721` `CW1155` `ERC20` `ERC721` `ERC1155` |

Note: `pointee` does not support `CW1155` or `ERC1155`.

### Transaction Lookup

```bash
seid q evm tx <0x-hash> --evm-rpc https://evm-rpc.sei-apis.com
```

Returns standard Ethereum transaction fields. Uses `--evm-rpc`, not `--node`.

## Transactions

All transaction commands require a funded key in the local keyring (`--from`).

### Common Flags

| Flag | Purpose | Default |
|---|---|---|
| `--from <name>` | Signing key | Required |
| `--gas-fee-cap <gwei>` | Gas price ceiling | 1000 gwei (varies) |
| `--gas-limit <n>` | Execution limit | Command-dependent |
| `--evm-rpc <url>` | RPC endpoint | http://localhost:8545 |
| `--nonce <n>` | Override sequence number | Auto-calculated |
| `--value <wei>` | SEI to attach | 0 |

### Default Gas Limits by Command

| Command | Default gas |
|---|---|
| `send` (native) | 21,000 |
| `erc20-send` | 7,000,000 |
| `deploy` | 5,000,000 |
| `call-contract` | 7,000,000 |
| `call-precompile` | 7,000,000 |

### Commands

```bash
# Associate a Sei address with an EVM address
seid tx evm associate-address [optional-priv-key-hex] --from <name> --evm-rpc <url>

# Send native SEI (amount in wei)
seid tx evm send <to-evm-addr> <amount-wei> --from <name> --gas-fee-cap <cap> --gas-limit <limit>

# Send ERC20 tokens
seid tx evm erc20-send <contract> <recipient> <amount> --from <name>

# Deploy a contract
seid tx evm deploy <path-to-binary> --from <name>

# Call a contract with pre-encoded payload
seid tx evm call-contract <addr> <payload-hex> --value <wei> --from <name>

# Call a precompile by name and method
seid tx evm call-precompile <precompile-name> <method> [args...]
```

Available precompile names: `distribution`, `json`, `p256`, `staking`. See [EVM Precompiles](https://docs.sei.io/evm/precompiles) for method signatures.

## curl and JSON-RPC

Use `curl` when the user wants raw EVM RPC access, debug methods, or JSON-RPC examples. Use `seid` for everything else.

```bash
EVM_RPC="https://evm-rpc.sei-apis.com"

# Transaction by hash
curl -s "$EVM_RPC" \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_getTransactionByHash","params":["0x..."],"id":1}' | jq

# Submit a signed raw transaction
curl -s "$EVM_RPC" \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_sendRawTransaction","params":["0x<signed-raw-tx>"],"id":1}' | jq

# Read contract state (eth_call)
curl -s "$EVM_RPC" \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_call","params":[{"to":"0xtoken...","data":"0x70a08231000000000000000000000000<address-no-0x>"},"latest"],"id":1}' | jq

# Debug trace (only if the RPC exposes debug methods)
curl -s "$EVM_RPC" \
  -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"debug_traceTransaction","params":["0x...",{}],"id":1}' | jq
```

Decode helpers:
- `jq` — inspect JSON-RPC responses.
- `cast to-dec <hex>` — convert hex quantities (balances, gas, block numbers).
- `cast abi-decode "<sig>" <hex>` — decode `eth_call` return data.

For writes: sign first, then submit via `eth_sendRawTransaction`. Prefer a wallet, `cast send`, or another signing tool over hand-crafting RLP.

### Sei-Specific JSON-RPC Behaviour

- **Finality:** `safe`, `finalized`, and `latest` are equivalent on Sei (instant single-block finality).
- **Proofs:** Sei uses IAVL trees, not Merkle Patricia Tries. Proofs returned by proof-bearing endpoints are IAVL proofs.
- **Filter limits:** Open-ended log queries return up to 10,000 logs; closed-range queries cover up to 2,000 blocks.
- **Deprecated + gated:** `sei_*` and `sei2_*` namespaced methods are deprecated and scheduled for removal — migrate to standard `eth_*` and `debug_*` methods. They are gated by the `[evm].enabled_legacy_sei_apis` list in `app.toml` (env/flag `evm.enabled_legacy_sei_apis`). Only methods named in that list are served on the EVM HTTP endpoint. `seid init` / defaults enable **only three helpers**: `sei_getSeiAddress`, `sei_getEVMAddress`, `sei_getCosmosTx`. Every other gated `sei_*` / `sei2_*` method — and any unknown `sei_*` name (fails closed) — returns HTTP 200 with a JSON-RPC error (`code: -32601`, `data: "legacy_sei_deprecated"`) unless explicitly allowlisted. To enable a legacy method, add its exact name to `enabled_legacy_sei_apis` under `[evm]`. Successful allowlisted responses set the `Sei-Legacy-RPC-Deprecation` HTTP header (JSON body unchanged) as a deprecation signal.
- **`sei2_*` namespace:** Seven block-related methods (`sei2_getBlockByHash`, `sei2_getBlockByNumber`, `sei2_getBlockReceipts`, `sei2_getBlockTransactionCountByHash`, `sei2_getBlockTransactionCountByNumber`, plus `*ExcludeTraceFail` variants) mirror the `sei` block payloads but include bank transfers (HTTP only). There is no `sei2` transaction or filter API. These are gated by the same allowlist and off by default.
- **`debug_traceTransaction`:** Only available if the RPC node exposes debug methods. If unavailable, fall back to standard RPC queries.

## Agent Workflow

1. Classify the task: install · wallet · read query · payload generation · pointer lookup · tx lookup · transaction submission · raw JSON-RPC.
2. Determine the correct endpoint type: `--node` for `seid q evm` queries, `--evm-rpc` for `seid q evm tx` and transaction commands, `curl` for raw JSON-RPC.
3. Provide the exact `seid` subcommand. Return command output directly, then explain only Sei-specific nuance.
4. If behaviour may be version-dependent, check the [Sei changelog](https://docs.sei.io/evm/changelog) before making claims.

## Rules

- Prefer `seid` over generic Ethereum examples when the user explicitly wants Sei CLI help.
- Never guess flag names or endpoint types.
- Always append `--node` for `seid q evm` commands when the user is not running a local node — except `seid q evm tx`.
- Never use `--node` for `seid q evm tx`; use `--evm-rpc`.
- Use `curl` for raw EVM RPC only when the user wants JSON-RPC access or debug methods.
- Do not install or build `seid` unless setup is required for the task.
- Never ask the user to paste a mnemonic into chat — the CLI prompts locally.
- For unknown flags or subcommand details, use `seid --help` or `seid <subcommand> --help`.

## References

- Install and wallet basics: https://docs.sei.io/evm/installing-seid-cli
- EVM queries and payload generation: https://docs.sei.io/evm/querying-the-evm
- EVM transactions: https://docs.sei.io/evm/transactions-with-seid
- Pointer contracts (conceptual): https://docs.sei.io/learn/pointers
- JSON-RPC reference: https://docs.sei.io/evm/reference
- Release changes: https://docs.sei.io/evm/changelog
