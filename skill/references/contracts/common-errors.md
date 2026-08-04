---
title: Common Errors on Sei
description: Error messages, their root causes, and solutions — covering EVM transactions, node operations, precompiles, wallets, and contract development on Sei.
---

# Common Errors on Sei

## EVM / Transaction Errors

### `intrinsic gas too low`
**Cause**: Gas limit set below the intrinsic cost for the transaction type.  
**Fix**: Increase gas limit. Use `eth_estimateGas` to get a baseline, then add 20% buffer.
```typescript
const gasEstimate = await provider.estimateGas(tx);
const gasLimit = gasEstimate * 120n / 100n;  // 20% buffer
```

### `max fee per gas less than block base fee`
**Cause**: Using `maxFeePerGas`/`maxPriorityFeePerGas` (EIP-1559 fields) on Sei. Sei's fee model does not burn a base fee, so EIP-1559 priority mechanics don't apply.  
**Fix**: Use `gasPrice` instead. Minimum 50 gwei.
```typescript
// Wrong
{ maxFeePerGas: parseUnits("20", "gwei"), maxPriorityFeePerGas: parseUnits("1", "gwei") }

// Correct
{ gasPrice: parseUnits("50", "gwei") }
```

### `transaction underpriced`
**Cause**: `gasPrice` is below the network minimum (50 gwei).  
**Fix**: Set `gasPrice` to at least `parseUnits("50", "gwei")`.

### `nonce too low`
**Cause**: Transaction nonce already used; another transaction from the same account was included first.  
**Fix**: Fetch the current nonce with `provider.getTransactionCount(address, "latest")` and resend.

### `execution reverted`
**Cause**: Contract function threw (via `revert`, `require`, or `assert`).  
**Fix**: Decode the revert reason. In ethers.js v6:
```typescript
try {
  await contract.myFunction();
} catch (e) {
  if (e.data) {
    const decoded = contract.interface.parseError(e.data);
    console.log("Revert:", decoded?.name, decoded?.args);
  }
}
```

### `out of gas`
**Cause**: Gas limit exhausted before execution completed.  
**Fix**: Check SSTORE patterns. Both mainnet and testnet charge 72,000 gas per cold storage write. Cache in memory and minimize writes regardless of network.

### `transaction gas limit exceeds block gas limit`
**Cause**: Single transaction gas limit > 12.5 M (Sei block gas cap).  
**Fix**: Split into multiple smaller transactions, or reduce loop iterations.

---

## Address / Wallet Errors

### `address not associated`
**Cause**: Attempting a cross-VM operation (e.g., sending ERC20 to a `sei1...` address via pointer) before the two address formats are linked.  
**Fix**: Associate the addresses first. The easiest method is to send any transaction from the account (the association happens automatically on first EVM tx).
```typescript
// Check if associated
const addrPrecompile = new ethers.Contract(ADDRESS_PRECOMPILE_ADDRESS, ADDRESS_PRECOMPILE_ABI, provider);
const seiAddr = await addrPrecompile.getSeiAddr(evmAddress);
// If returns empty string, address is not yet associated
```

### `invalid address`
**Cause**: Passing a bech32 `sei1...` address where an EVM `0x...` address is expected, or vice versa.  
**Fix**: Use the Addr precompile to convert between address formats.
```solidity
address evmAddr = ADDR(0x1004).getEvmAddr("sei1abc...");
```

### MetaMask "wrong network"
**Cause**: MetaMask is connected to a different chain.  
**Fix**: Always specify `chainId` in transactions to fail fast on wrong network.
```typescript
const txHash = await writeContractAsync({ ..., chainId: 1329 }); // fails if not on Sei mainnet
```

---

## Precompile Errors

### `delegate` sending wrong amount unit
**Cause**: `delegate` in the Staking precompile is `payable` — value is in **wei** (18 decimals). Common mistake is passing usei (6 decimals) as the `value`.  
**Fix**: 
```solidity
// Delegate 1 SEI = 1e18 wei
STAKING.delegate{value: 1 ether}(validatorAddr);
// NOT: STAKING.delegate{value: 1_000_000}(validatorAddr); // That's only 0.000001 SEI
```

### `undelegate` / `redelegate` wrong amount unit
**Cause**: These functions take amounts in **usei** (6 decimals), not wei.  
**Fix**: `1 SEI = 1_000_000 usei` for undelegate/redelegate.

### Precompile call fails silently
**Cause**: Calling a precompile from a contract without `payable` when the precompile requires value.  
**Fix**: Ensure the calling function is `payable` and forwards `msg.value`.

### `JSON precompile: path not found`
**Cause**: `extractAs*` function given a JSON path that doesn't exist in the input.  
**Fix**: Validate JSON structure before passing to precompile. Use try/catch.

---

## Node / Sync Errors

### `wrong Block.Header.AppHash`
**Cause**: Node state is inconsistent with the network — usually from using wrong binary version during sync, or database corruption.  
**Fix**:
1. Stop node: `systemctl stop seid`
2. Try rollback: `seid rollback`, then restart
3. If rollback fails: wipe data and state sync from scratch (back up validator keys first)

### `Consensus failure - height halted`
**Cause**: Network upgrade required at this height.  
**Fix**: Update to the new binary version specified in the upgrade proposal.

### `Private validator file not found`
**Cause**: `priv_validator_key.json` is missing or in wrong location.  
**Fix**: Restore from backup. File must be at `$HOME/.sei/config/priv_validator_key.json`.

### `Duplicate signature` / double-sign warning
**Cause**: Two instances of seid are signing with the same validator key simultaneously.  
**Fix**: **STOP ALL INSTANCES IMMEDIATELY.** Running two signers with the same key can get your validator jailed (and potentially slashed on other networks). Verify only one seid instance is running.

### `No peers available`
**Cause**: Node has no P2P connections, can't sync.  
**Fix**:
```bash
# Check peer count
curl http://localhost:26657/net_info | jq '.result.n_peers'
# Update persistent peers in config.toml
# Verify port 26656 is open in firewall
```

### `Database is corrupted`
**Cause**: Improper shutdown or disk failure damaged the LevelDB/PebbleDB files.  
**Fix**: Restore from backup or state sync.

### `failed to initialize database: resource temporarily unavailable`
**Cause**: seid process is still running when you attempt a rollback or reset.  
**Fix**: Kill the seid process completely (`kill $(pgrep seid)`), then run the command.

---

## Solidity / Contract Development

### SSTORE gas unexpectedly high
**Cause**: Sei charges 72,000 gas per cold write on both mainnet and testnet (governance Proposal #109 on pacific-1; testnet carries the same value with no separate proposal). Multiple storage writes in a function compound quickly.  
**Fix**: Cache in memory, minimize storage writes. Use `forge test --gas-report` against the target network.
```solidity
// Both networks: 3 × 72,000 = 216,000 gas just for storage
balances[a] = x;
balances[b] = y;
balances[c] = z;

// Better: read once, compute in memory, write once per slot
```

### Random numbers are predictable
**Cause**: `block.prevrandao` on Sei returns a deterministic value derived from block time — NOT cryptographically random.  
**Fix**: Use Pyth VRF or Chainlink VRF. See `oracles.md`.

### `block.coinbase` returns wrong address
**Cause**: On Sei, `block.coinbase` returns the global fee collector address, not the block proposer. There is no block proposer in the traditional EVM sense.  
**Fix**: Don't use `block.coinbase` for proposer logic.

### State sync snapshot finishes then AppHash errors appear
**Cause**: Using a binary version mismatched with the snapshot.  
**Fix**: Ensure your `seid` binary version matches the chain version at the snapshot height.

### Contract verification fails on Seiscan
**Cause**: Solidity version or optimization settings don't match exactly.  
**Fix**: Match the exact `solc` version and optimizer settings:
```bash
forge verify-contract \
  --chain-id 1328 \
  --verifier sourcify \
  --compiler-version v0.8.28 \
  --num-of-optimizations 200 \
  $CONTRACT_ADDRESS \
  src/MyContract.sol:MyContract
```

---

## IBC Errors

### An IBC transfer fails or reverts
**Cause**: IBC is closed on Sei in both directions — inbound by Props 116/120, outbound by [Proposal 121](https://seistream.app/proposals/121) (2026-07-31). The `ibc` module rejects the transfer regardless of channel, recipient, or amount. This applies to `seid tx ibc-transfer transfer` and to the IBC precompile (`0x…1009`) equally.

**Fix**: There is no IBC route on or off Sei. Do not retry, adjust the timeout, or try another channel. Use an EVM bridge instead — see [../ecosystem/bridges.md](../ecosystem/bridges.md).

Existing `ibc/...` balances are **not** stuck: they remain in the bank module and still transfer between Sei accounts and through their ERC-20 pointers. Only the route off the chain is closed. See [../ecosystem/ibc-bridging.md](../ecosystem/ibc-bridging.md).

### `IBC denom not recognized`
**Cause**: A consumer doesn't know what an `ibc/HASH` denom represents. These denoms still exist and are still valid on Sei.  
**Fix**: Query the denom trace — this is a local query and still works:
```bash
seid q ibc-transfer denom-trace <IBC_HASH> --node https://rpc.sei-apis.com
```

---

## Quick Diagnostic Commands

```bash
# Node sync status
seid status | jq .SyncInfo

# Check if catching up
seid status | jq .SyncInfo.catching_up

# Validator signing info
seid q slashing signing-info $(seid tendermint show-validator) --node https://rpc.sei-apis.com

# Peer count
curl -s http://localhost:26657/net_info | jq '.result.n_peers'

# Current block height
curl -s http://localhost:26657/status | jq '.result.sync_info.latest_block_height'

# Check service
systemctl status seid

# Tail logs
journalctl -fu seid -o cat
```
