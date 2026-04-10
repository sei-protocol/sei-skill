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

### 1. Gas Price: Use `gasPrice`, Not EIP-1559 Fields

Sei does not support `maxFeePerGas` / `maxPriorityFeePerGas`. Always use legacy `gasPrice`.

```typescript
// ❌ Ethereum EIP-1559 style — will fail on Sei
const tx = await contract.myFunction({
  maxFeePerGas: parseUnits("20", "gwei"),
  maxPriorityFeePerGas: parseUnits("1", "gwei"),
});

// ✅ Sei style — legacy gasPrice
const tx = await contract.myFunction({
  gasPrice: parseUnits("10", "gwei"),  // minimum 10 gwei
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

### 6. SSTORE Costs 72,000 Gas (Not 20,000)

Storage writes are significantly more expensive on Sei:

```solidity
// ❌ Bad: multiple storage writes in a loop
function updateAll(address[] calldata users, uint256[] calldata amounts) external {
    for (uint i = 0; i < users.length; i++) {
        balances[users[i]] = amounts[i];   // 72,000 gas each!
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

### 7. No "safe" / "finalized" Block Tags

```typescript
// ❌ Ethereum: different commitment levels exist
const safeBlock = await provider.getBlock("safe");
const finalBlock = await provider.getBlock("finalized");

// ✅ Sei: all equivalent to "latest"
const block = await provider.getBlock("latest");
```

### 8. No Pending State

Sei does not expose a `pending` block tag. Use `latest`.

---

## Contract Migration Checklist

```
□ Remove maxFeePerGas / maxPriorityFeePerGas usage
□ Remove PREVRANDAO randomness → integrate VRF oracle
□ Check COINBASE usage — does not return block proposer
□ Check for blob opcodes (BLOBHASH, BLOBBASEFEE) — not available
□ Audit SSTORE patterns — consider caching in memory before writing
□ Remove "safe"/"finalized" block tag references
□ Test contract on atlantic-2 testnet before mainnet
```

---

## Frontend Migration Checklist

### Update Provider/Chain Config

```typescript
// Add Sei to your Wagmi config
import { seiMainnet, seiTestnet } from '@sei-js/evm';

export const config = createConfig({
  chains: [seiMainnet, seiTestnet],
  transports: {
    [seiMainnet.id]: http('https://evm-rpc.sei-apis.com'),
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
  gasPrice: parseUnits("10", "gwei"),  // minimum 10 gwei
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

# Verify on Seitrace
forge verify-contract \
  --chain-id 1328 \
  --verifier blockscout \
  --verifier-url https://seitrace.com/atlantic-2/api \
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
| **Native oracle** | Free price feeds without external dependencies |

See [`precompiles/overview.md`](../precompiles/overview.md) and [`pointers/overview.md`](../pointers/overview.md) for details.

---

## Ecosystem Contracts on Sei

| Contract | Address |
|---|---|
| Multicall3 | `0xcA11bde05977b3631167028862bE2a173976CA11` |
| Permit2 | `0xB952578f3520EE8Ea45b7914994dcf4702cEe578` |
| CREATE2 Factory | `0x0000000000FFe8B47B3e2130213B802212439497` |
| USDC (mainnet) | `0x3894085Ef7Ff0f0aeDf52E2A2704928d1Ec074F` |
| USDC (testnet) | `0xace91bFb5c09C1B2EE5cc9aB23F6EBF2F5dde23` |

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
