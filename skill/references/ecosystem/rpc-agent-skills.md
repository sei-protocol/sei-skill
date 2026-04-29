---
title: RPC Agent Skills for Sei
description: The 17 canonical agent skills for interacting with Sei via RPC — read ops, write ops, and derived/multi-step ops — with setup requirements, safety protocols, retry logic, and standardized response shapes.
---

# RPC Agent Skills for Sei

Reference for AI agents interacting with the Sei blockchain directly via RPC. These 17 skills cover the full lifecycle: querying state, sending transactions, deploying contracts, staking, and monitoring.

Source: https://docs.sei.io/skill.md

---

## Setup Requirements

| Parameter | Required | Notes |
|---|---|---|
| `rpc_url` | Yes | EVM JSON-RPC endpoint |
| `network` | Yes | `mainnet`, `testnet` (default), or `devnet` |
| `chain_id` | No | Auto-derived from network if omitted |
| `private_key` | Write ops only | Or signer abstraction; never log or expose |

**Default RPC URLs:**

| Network | EVM RPC |
|---|---|
| Mainnet | `https://evm-rpc.sei-apis.com` |
| Testnet | `https://evm-rpc-testnet.sei-apis.com` |

**Address handling**: Sei uses both bech32 (`sei1...`) and EVM (`0x...`) formats. Use `get_evm_address` / `get_sei_address` to convert. Always validate format before use.

---

## Read Skills (No State Changes)

### 1. `get_chain_status`
Retrieves latest block height, chain ID, and sync status.

```typescript
// Input
{ rpc_url: string, network: string }

// Output
{ block_height: number, chain_id: number, syncing: boolean }
```

### 2. `get_account_balance`
Fetches token balances for an address, optionally filtered by denom.

```typescript
// Input
{ address: string, denom?: string, rpc_url: string }

// Output — EVM native balance
const balance = await provider.getBalance(address);

// Output — ERC20 balance
const balance = await erc20.balanceOf(address);
```

### 3. `get_evm_address`
Converts a Sei bech32 address to EVM `0x` format.

```typescript
// Uses Addr precompile (0x1004)
const evmAddr = await ADDR.getEvmAddr("sei1abc...");
// Returns "0x..." or empty string if unassociated
```

### 4. `get_sei_address`
Converts an EVM `0x` address to Sei bech32 format.

```typescript
const seiAddr = await ADDR.getSeiAddr("0xabc...");
// Returns "sei1..." or empty string if unassociated
```

### 5. `get_transaction`
Returns transaction status, gas consumed, logs, and events.

```typescript
// Input
{ tx_hash: string, rpc_url: string }

// Output
const receipt = await provider.getTransactionReceipt(tx_hash);
// receipt.status: 1 = success, 0 = reverted
// receipt.gasUsed, receipt.logs
```

### 6. `get_block`
Retrieves block hash, timestamp, and transaction list by height.

```typescript
// Input
{ block_height: number, rpc_url: string }

const block = await provider.getBlock(block_height);
// block.hash, block.timestamp, block.transactions
```

### 7. `get_gas_price`
Queries current network gas price.

```typescript
const gasPrice = await provider.getGasPrice();
// Minimum on Sei: 50 gwei (50_000_000_000n wei)
// Always use gasPrice — NOT maxFeePerGas/maxPriorityFeePerGas
```

### 8. `get_contract_state`
Queries smart contract state with custom call parameters.

```typescript
// Input
{ contract_address: string, abi: any[], method: string, args: any[], rpc_url: string }

const contract = new ethers.Contract(address, abi, provider);
const result = await contract[method](...args);
```

---

## Write Skills (Require Signing + Explicit Confirmation)

> **Rule**: Never execute a write op without first running `simulate_contract_execution` and presenting a summary to the user for confirmation.

### 9. `send_tokens`
Transfers native SEI or ERC20 tokens between addresses.

```typescript
// Pre-checks (mandatory)
// 1. Validate balance >= amount + gas
// 2. Validate recipient address format
// 3. Present summary: "Send X SEI to 0x... — fee ~Y SEI. Confirm?"
// 4. Wait for explicit confirmation

// Native SEI transfer
const tx = await signer.sendTransaction({
  to: recipient,
  value: amount,
  gasPrice: await provider.getGasPrice(),
  chainId: 1329,  // always specify
});
await tx.wait(1);  // instant finality

// ERC20 transfer
const tx = await token.transfer(recipient, amount, {
  gasPrice: await provider.getGasPrice(),
  chainId: 1329,
});
```

### 10. `execute_contract`
Invokes a smart contract function that changes state.

```typescript
// Mandatory flow:
// 1. simulate_contract_execution first
// 2. Present: function name, args, estimated gas/fee
// 3. Require explicit user confirmation
// 4. Execute with gasPrice (not EIP-1559 fields)

const tx = await contract[method](...args, {
  gasPrice: await provider.getGasPrice(),
  gasLimit: estimatedGas * 120n / 100n,  // 20% buffer
  chainId: 1329,
});
await tx.wait(1);
```

### 11. `deploy_contract`
Deploys a new contract with bytecode and constructor arguments.

```typescript
const factory = new ethers.ContractFactory(abi, bytecode, signer);
const contract = await factory.deploy(...constructorArgs, {
  gasPrice: await provider.getGasPrice(),
  chainId: 1329,
});
await contract.waitForDeployment();
const address = await contract.getAddress();
```

### 12. `stake_tokens`
Delegates SEI to a validator via the Staking precompile.

```typescript
// Amount in WEI (payable value) for delegate
await STAKING.delegate{value: amount}(validatorAddress);

// Verify validator exists first
const validators = await STAKING.validators();
```

### 13. `unstake_tokens`
Undelegates SEI from a validator.

```typescript
// Amount in USEI (6 decimals), NOT wei
// 1 SEI = 1_000_000 usei
await STAKING.undelegate(validatorAddress, amountInUsei);
// Unbonding period: 21 days
```

---

## Derived Skills (Multi-Step / Computed)

### 14. `estimate_transaction_cost`
Calculates gas and fee estimate before execution.

```typescript
const gasEstimate = await provider.estimateGas({
  to: contractAddress,
  data: contract.interface.encodeFunctionData(method, args),
  value: value ?? 0n,
});
const gasPrice = await provider.getGasPrice();
const estimatedFee = gasEstimate * gasPrice;
// Convert to SEI: Number(estimatedFee) / 1e18
```

### 15. `simulate_contract_execution`
Previews execution outcome including gas usage — **always run before write ops**.

```typescript
// eth_call simulates without broadcasting
const result = await provider.call({
  to: contractAddress,
  data: contract.interface.encodeFunctionData(method, args),
  value: value ?? 0n,
});
// Decode result to check for revert reasons before submitting
```

### 16. `get_portfolio_summary`
Aggregates all token balances for a comprehensive overview.

```typescript
// Native SEI balance
const nativeBalance = await provider.getBalance(address);

// ERC20 balances (check known token list or Transfer event history)
const erc20Balances = await Promise.all(
  tokenList.map(token => token.balanceOf(address))
);
```

### 17. `monitor_transaction`
Tracks transaction confirmation until finality with configurable timeout.

```typescript
// Sei has instant finality — 1 block = final
// Default timeout: 30 seconds (75 blocks at 400ms)
async function monitorTransaction(txHash: string, timeoutMs = 30_000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const receipt = await provider.getTransactionReceipt(txHash);
    if (receipt) {
      return {
        success: receipt.status === 1,
        gasUsed: receipt.gasUsed,
        blockNumber: receipt.blockNumber,
      };
    }
    await new Promise(r => setTimeout(r, 400));  // poll every block
  }
  throw new Error(`Transaction not confirmed within ${timeoutMs}ms`);
}
```

---

## Safety Architecture

### Read Operations
```typescript
async function readWithRetry<T>(fn: () => Promise<T>, maxAttempts = 3): Promise<T> {
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (err) {
      if (attempt === maxAttempts) throw err;
      await new Promise(r => setTimeout(r, 2 ** attempt * 500));  // exponential backoff
    }
  }
  throw new Error("Unreachable");
}
```

### Write Operations
- **No automatic retry** — re-submitting a write op risks duplicate execution
- Always check if the first tx was included before considering a retry
- Use nonce management to safely replace a stuck transaction

### Pre-Execution Checklist (Write Ops)
```
□ Validate all input addresses (format + association check if cross-VM)
□ Run simulate_contract_execution — check for revert
□ Run estimate_transaction_cost — confirm user can afford gas
□ Present summary: action, assets involved, estimated fee
□ Wait for explicit user confirmation
□ Specify chainId in every transaction
□ Use gasPrice (not EIP-1559 fields)
□ Use tx.wait(1) — 1 block is final on Sei
```

---

## Standardized Response Shape

```typescript
// Success
{
  success: true,
  data: { /* skill-specific result */ },
  error: null
}

// Failure
{
  success: false,
  data: null,
  error: {
    message: "Human-readable description",
    recoverable: true | false   // recoverable = user can fix (bad input, low balance); false = system error
  }
}
```

**Recoverable errors** (user can resolve): insufficient balance, unassociated address, invalid input format, slippage exceeded.  
**Non-recoverable errors**: RPC node down, network outage, contract bug causing consistent revert.
