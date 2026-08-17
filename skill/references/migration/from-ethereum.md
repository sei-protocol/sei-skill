---
title: Migrating from Ethereum (and Other EVMs) to Sei
description: Step-by-step migration guide for EVM dApps moving to Sei — key differences, required code changes, frontend updates, and chain-specific gotchas.
---

# Migrating from Ethereum (and Other EVMs) to Sei

Sei is fully EVM bytecode-compatible. Most contracts deploy unchanged. The work is in understanding the behavioral differences and updating your tooling.

## Why Migrate

| Feature | Sei | Ethereum | Arbitrum | Base |
|---|---|---|---|---|
| Block time | 400 ms | ~12 s | ~250 ms | ~2 s |
| Finality | Instant | ~15 min | ~7 days (L1) | ~7 days (L1) |
| Gas limit | 12.5 M | 60 M | 32 M | 375 M |
| Parallel execution | Yes (OCC) | No | No | No |
| Base fee burn | No (100% to validators) | Yes (EIP-1559) | Yes | Yes |
| EVM version | Pectra (no blobs) | Fusaka | Fusaka | Pectra |
| Chain ID | 1329 (mainnet) | 1 | 42161 | 8453 |

---

## Critical Behavioral Differences

These are not optional edge cases — they **will** break your app if ignored.

### 1. Gas Price: Prefer `gasPrice` Over EIP-1559 Fields

Sei's fee model does not burn a base fee, so EIP-1559 priority fee mechanics don't apply. `maxFeePerGas`/`maxPriorityFeePerGas` can be omitted — use legacy `gasPrice` instead. The minimum gas price is a **governance-set, adjustable** value (currently ~50 gwei on mainnet, set by pacific-1 [Proposal #112](https://www.mintscan.io/sei/proposals/112) / atlantic-2 #244; it has changed before — 100 → 10 → 50). **Query the live floor with `eth_gasPrice`** rather than hardcoding a constant.

```typescript
// ⚠️ EIP-1559 style — may not behave as expected on Sei (no base fee burn)
const tx = await contract.myFunction({
  maxFeePerGas: parseUnits("20", "gwei"),
  maxPriorityFeePerGas: parseUnits("1", "gwei"),
});

// ✅ Preferred: legacy gasPrice — read the live floor, don't bake in a number
const tx = await contract.myFunction({
  gasPrice: await provider.send("eth_gasPrice", []),  // ≥ governance floor (~50 gwei mainnet)
});
```

### 2. Finality: Use `wait(1)`, Not `wait(12)`

Sei has instant finality — one block confirmation is final.

```typescript
// ❌ Ethereum habit
const receipt = await tx.wait(12);   // 12 blocks ≈ 2.5 min on Ethereum, but ~4.8s on Sei (wasteful)

// ✅ Sei
const receipt = await tx.wait(1);    // 1 block ≈ 400ms — fully final
```

### 3. PREVRANDAO is NOT Random

```solidity
// ❌ DANGEROUS — PREVRANDAO on Sei is derived from block time, not random
uint256 rand = uint256(block.prevrandao) % 100;

// ✅ Use Pyth VRF or Chainlink VRF
// See oracles.md for VRF integration
```

### 4. COINBASE is Not the Block Proposer

```solidity
// ❌ Wrong — block.coinbase on Sei is the global fee collector, not block proposer
address proposer = block.coinbase;

// ✅ Don't use coinbase for proposer logic
```

### 5. No EIP-4844 Blobs

Sei runs Pectra EVM but without blob transactions (`BLOBHASH` / `BLOBBASEFEE`). If your contract uses blobs, you need to refactor.

The `eth_blobBaseFee` JSON-RPC method **is** exposed, but it always returns a JSON-RPC error (code `-32000`, message `"blobs not supported on this chain"`) rather than a fee value. Do not treat it as method-not-found (`-32601`) — the method exists and the error is the expected, permanent response on Sei.

### 6. SSTORE Costs Are Higher Than Ethereum

Storage writes are far costlier than Ethereum's 20,000 gas:
- **Both mainnet & testnet**: 72,000 gas per cold SSTORE — set by pacific-1 governance [Proposal #109](https://www.mintscan.io/sei/proposals/109) (testnet carries the same value with no separate proposal). Governance-adjustable.

Best practice: minimize storage writes. Note a `forge --gas-report --fork-url` report applies revm's standard EVM schedule and shows ~22,100 — **not** Sei's 72,000; use a live `eth_estimateGas` against a Sei RPC for the real cost.

```solidity
// ❌ Bad: multiple storage writes in a loop (expensive on either network)
function updateAll(address[] calldata users, uint256[] calldata amounts) external {
    for (uint i = 0; i < users.length; i++) {
        balances[users[i]] = amounts[i];   // cold SSTORE each
    }
}

// ✅ Good: batch into memory, single write per slot
function processAndStore(uint256[] calldata items) external {
    uint256 total = 0;
    for (uint i = 0; i < items.length; i++) {
        total += items[i];   // memory only
    }
    storedTotal = total;    // one storage write
}
```

### 7. `safe` / `finalized` Resolve to `latest`

```typescript
// Ethereum: these are different, lagging commitment levels
const safeBlock = await provider.getBlock("safe");
const finalBlock = await provider.getBlock("finalized");

// Sei: the tags are accepted but resolve to the SAME instantly-final
// block as "latest" — there's nothing to gain from safe/finalized.
const block = await provider.getBlock("latest");
```

### 8. No Pending State

Sei does not expose a `pending` block tag. Use `latest`.

### 9. SELFDESTRUCT is Neutered (EIP-6780)

Sei runs post-EIP-6780 semantics: `SELFDESTRUCT` no longer deletes the contract or its storage — it only forwards the remaining ETH, unless it runs in the *same transaction* that created the contract. Any cleanup/upgrade logic that relied on destroying a contract must be refactored to a "soft close".

```solidity
// ❌ Don't rely on SELFDESTRUCT to remove a contract — it won't (EIP-6780).
// ✅ Soft close instead:
bool public closed;
modifier notClosed() { require(!closed, "closed"); _; }
```

---

## Contract Migration Checklist

```
□ Remove maxFeePerGas / maxPriorityFeePerGas usage
□ Remove PREVRANDAO randomness → integrate VRF oracle
□ Check COINBASE usage — does not return block proposer
□ Check for blob opcodes (BLOBHASH, BLOBBASEFEE) — not available
□ Refactor SELFDESTRUCT cleanup → soft-close pattern (EIP-6780 neutered it)
□ Audit SSTORE patterns — consider caching in memory before writing (72k gas/cold write)
□ Drop waits on "safe"/"finalized" — they resolve to "latest" on Sei; use tx.wait(1)
□ Test contract on atlantic-2 testnet before mainnet
```

---

## Frontend Migration Checklist

### Update Provider/Chain Config

```typescript
// Add Sei to your Wagmi config
import { sei, seiTestnet } from 'viem/chains';

export const config = createConfig({
  chains: [sei, seiTestnet],
  transports: {
    [sei.id]: http('https://evm-rpc.sei-apis.com'),
    [seiTestnet.id]: http('https://evm-rpc-testnet.sei-apis.com'),
  },
});
```

### Update Transaction Submissions

```typescript
// Before (Ethereum)
const txHash = await writeContractAsync({
  ...contractArgs,
  maxFeePerGas: parseUnits("20", "gwei"),
  maxPriorityFeePerGas: parseUnits("1", "gwei"),
});

// After (Sei)
const txHash = await writeContractAsync({
  ...contractArgs,
  gasPrice: parseUnits("50", "gwei"),  // minimum 50 gwei
  chainId: 1329,  // always specify to prevent wrong-network submissions
});
```

### Remove Multi-Confirmation UX

```typescript
// Before: spinner with "waiting for confirmations..." (6-12 blocks)
setStatus("Waiting for confirmations...");
await tx.wait(6);

// After: instant success after 1 block
await tx.wait(1);
setStatus("Success!");  // ~400ms after tx broadcast
```

### Update Block Polling

```typescript
// Before: poll every 12+ seconds
provider.on("block", handler);  // fires every 12s on Ethereum

// After: Sei fires this every 400ms — throttle if needed
let lastProcessed = 0;
provider.on("block", (blockNumber) => {
  if (blockNumber - lastProcessed < 5) return;  // throttle
  lastProcessed = blockNumber;
  handler(blockNumber);
});
```

---

## Deployment

```bash
# Hardhat — deploy to Sei testnet
npx hardhat run scripts/deploy.ts --network seiTestnet

# Foundry — deploy to Sei testnet
forge create \
  --rpc-url https://evm-rpc-testnet.sei-apis.com \
  --private-key $PRIVATE_KEY \
  src/MyContract.sol:MyContract

# Verify on Seiscan
forge verify-contract \
  --chain-id 1328 \
  --verifier sourcify \
  $CONTRACT_ADDRESS \
  src/MyContract.sol:MyContract
```

---

## Sei-Unique Capabilities (Optional Upgrades)

Once migrated, you can optionally leverage Sei-specific features:

| Feature | What it enables |
|---|---|
| **Precompiles** | Staking, governance, IBC from Solidity |
| **Pointer contracts** | Your ERC20 token usable in Cosmos wallets |
| **Dual addresses** | Users can interact via `sei1...` or `0x...` |
| **Third-party oracles** | Pyth / Chainlink / API3 / RedStone price feeds (the native Oracle precompile is shut off) |

See [`precompiles/overview.md`](../precompiles/overview.md) and [`pointers/overview.md`](../pointers/overview.md) for details.

---

## Ecosystem Contracts on Sei

| Contract | Address |
|---|---|
| Multicall3 | `0xcA11bde05977b3631167028862bE2a173976CA11` |
| Permit2 | `0xB952578f3520EE8Ea45b7914994dcf4702cEe578` |
| CREATE2 Factory | `0x0000000000FFe8B47B3e2130213B802212439497` |
| USDC (mainnet) | `0xe15fC38F6D8c56aF07bbCBe3BAf5708A2Bf42392` |
| USDC (testnet) | `0x4fCF1784B31630811181f670Aea7A7bEF803eaED` |

---

## Testing Your Migration

1. Deploy to atlantic-2 (testnet) first
2. Run your existing test suite against the testnet fork:

```bash
# Foundry fork test
forge test --fork-url https://evm-rpc-testnet.sei-apis.com -vvv

# Hardhat fork
npx hardhat test --network hardhat  # with forking: { url: "https://evm-rpc-testnet.sei-apis.com" }
```

3. Verify gas usage — SSTORE costs may surprise you; check with `forge snapshot`
4. Test wallet UX end-to-end on testnet before mainnet

Get testnet SEI: https://atlantic-2.app.sei.io/faucet
