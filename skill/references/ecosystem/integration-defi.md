---
title: Integrating with Sei DeFi Protocols
description: How to integrate with major DEXes, lending markets, and yield protocols on Sei mainnet — router/comet ABIs, common patterns for swaps, quotes, deposits, borrows, and approvals. With viem and ethers code examples.
---

# Integrating with Sei DeFi Protocols

Patterns and code examples for calling DEX routers, lending markets, and other DeFi primitives on Sei. The protocol APIs themselves match their canonical EVM versions (Uniswap-V2/V3, Compound, Aave); this file calls out **only the Sei-specific deltas**.

> **Always verify contract addresses** against the protocol's official docs before sending real value. Addresses below are illustrative — the truth is in [docs.sei.io ecosystem contracts](https://docs.sei.io/evm/reference/ecosystem-contracts).

## Pre-flight checklist (every DeFi integration)

1. **Network**: testnet (1328) for development, mainnet (1329) for production.
2. **Gas price**: ≥ 50 gwei legacy `gasPrice`; not `maxFeePerGas`.
3. **Approvals**: ERC-20 `approve()` is a separate tx (or batch via Multicall3 / smart account).
4. **Slippage**: standard EVM patterns apply; Sei's instant finality means slippage windows close in ~400ms.
5. **Address association**: the user's `0x...` and `sei1...` must be associated if the integration touches Cosmos-side modules. See [addresses-wallets.md](../addresses-wallets.md).

## DEX swap (Uniswap-V2-compatible router)

DragonSwap exposes a Uniswap-V2-style router. Same ABI as `IUniswapV2Router02`.

```ts
// viem
import { createPublicClient, createWalletClient, http, parseEther, parseAbi } from "viem";

const ROUTER = "0x..."; // get from DragonSwap docs / Sei ecosystem-contracts page
const ROUTER_ABI = parseAbi([
  "function swapExactTokensForTokens(uint256,uint256,address[],address,uint256) returns (uint256[])",
  "function getAmountsOut(uint256,address[]) view returns (uint256[])",
]);

// 1. Quote
const [, amountOut] = await publicClient.readContract({
  address: ROUTER,
  abi: ROUTER_ABI,
  functionName: "getAmountsOut",
  args: [parseEther("1"), [tokenIn, tokenOut]],
});

// 2. Approve tokenIn (if not already approved)
await wallet.writeContract({
  address: tokenIn,
  abi: parseAbi(["function approve(address,uint256) returns (bool)"]),
  functionName: "approve",
  args: [ROUTER, parseEther("1")],
  gasPrice: 50_000_000_000n,
});

// 3. Swap
const minOut = (amountOut * 99n) / 100n; // 1% slippage
await wallet.writeContract({
  address: ROUTER,
  abi: ROUTER_ABI,
  functionName: "swapExactTokensForTokens",
  args: [parseEther("1"), minOut, [tokenIn, tokenOut], userAddress, BigInt(Math.floor(Date.now() / 1000) + 600)],
  gasPrice: 50_000_000_000n,
});
```

Sei deltas vs Ethereum:
- `gasPrice` instead of EIP-1559 fields.
- 400ms blocks → use a tighter `deadline` (e.g., now + 60s instead of now + 1200s) to limit MEV exposure.

## DEX swap (V3-style with concentrated liquidity)

V3-style routers expose `exactInputSingle` and `exactInput` (multi-hop). Protocol-specific addresses; check the project's docs.

```ts
const V3_ROUTER_ABI = parseAbi([
  "function exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160)) payable returns (uint256)",
]);

await wallet.writeContract({
  address: V3_ROUTER,
  abi: V3_ROUTER_ABI,
  functionName: "exactInputSingle",
  args: [{
    tokenIn,
    tokenOut,
    fee: 3000,
    recipient: user,
    deadline: BigInt(Math.floor(Date.now() / 1000) + 60),
    amountIn: parseEther("1"),
    amountOutMinimum: minOut,
    sqrtPriceLimitX96: 0n,
  }],
  gasPrice: 50_000_000_000n,
});
```

> Concentrated-liquidity pools partition state by tick range — they're more parallelism-friendly under load than V2 pools. See [dev/occ-aware-design.md](../dev/occ-aware-design.md).

## Lending: deposit + borrow (Compound v3 / Aave v3 style)

Yei Finance and Takara Lend follow Compound/Aave conventions. The shared concepts:

```ts
const COMET = "0x..."; // Compound-v3-style market

// 1. Approve the supply token
await wallet.writeContract({
  address: USDC,
  abi: parseAbi(["function approve(address,uint256) returns (bool)"]),
  functionName: "approve",
  args: [COMET, depositAmount],
  gasPrice: 50_000_000_000n,
});

// 2. Supply collateral
await wallet.writeContract({
  address: COMET,
  abi: parseAbi(["function supply(address,uint256)"]),
  functionName: "supply",
  args: [USDC, depositAmount],
  gasPrice: 50_000_000_000n,
});

// 3. Borrow (withdraw the base asset)
await wallet.writeContract({
  address: COMET,
  abi: parseAbi(["function withdraw(address,uint256)"]),
  functionName: "withdraw",
  args: [BASE_ASSET, borrowAmount],
  gasPrice: 50_000_000_000n,
});
```

Aave-v3-style (separate `supply` + `borrow` calls):

```ts
const POOL = "0x..."; // Aave-style pool

// supply
await wallet.writeContract({
  address: POOL,
  abi: parseAbi(["function supply(address,uint256,address,uint16)"]),
  functionName: "supply",
  args: [USDC, amount, user, 0],
  gasPrice: 50_000_000_000n,
});

// borrow (variable rate = 2)
await wallet.writeContract({
  address: POOL,
  abi: parseAbi(["function borrow(address,uint256,uint256,uint16,address)"]),
  functionName: "borrow",
  args: [WETH, borrowAmount, 2n, 0, user],
  gasPrice: 50_000_000_000n,
});
```

Sei deltas vs Ethereum:
- Liquidations are ~30× faster (12s → 400ms) — health factor tolerances should be tighter.
- SSTORE cost difference between testnet (72k) and mainnet (20k) means lending operations cost noticeably more on testnet — budget gas estimates accordingly.

## Reading prices (oracles)

Most Sei DeFi protocols use Pyth or Chainlink. Pull-style Pyth requires the user to push the price update in the same tx:

```ts
import { PriceServiceConnection } from "@pythnetwork/price-service-client";

const pyth = new PriceServiceConnection("https://hermes.pyth.network");
const priceIds = ["0x..."]; // SEI/USD price feed ID
const updateData = await pyth.getPriceFeedsUpdateData(priceIds);

// Bundle into the same tx
await wallet.writeContract({
  address: PROTOCOL,
  abi: PROTOCOL_ABI,
  functionName: "trade",
  args: [tradeArgs, updateData],
  value: 1n, // Pyth update fee — usually 1 wei
  gasPrice: 50_000_000_000n,
});
```

See [oracles.md](oracles.md) for full Pyth/Chainlink integration patterns.

## Stablecoin handling: USDC on Sei

USDC on Sei mainnet is **native USDC issued by Circle**, not a bridged synthetic. Verify the current canonical address via [docs.sei.io USDC integration](https://docs.sei.io/evm/reference/usdc).

```ts
const USDC_DECIMALS = 6;
const oneUSDC = 1_000_000n; // 6 decimals, NOT 18
```

Common mistake: assuming 18 decimals. USDC is 6.

## Multicall3 for batched reads

Available at the standard address `0xCA11bde05977b3631167028862bE2a173976CA11` on both networks.

```ts
import { multicall } from "viem/actions";

const [balance, allowance, symbol] = await multicall(client, {
  contracts: [
    { address: token, abi: ERC20_ABI, functionName: "balanceOf", args: [user] },
    { address: token, abi: ERC20_ABI, functionName: "allowance", args: [user, router] },
    { address: token, abi: ERC20_ABI, functionName: "symbol" },
  ],
});
```

Reduces RPC roundtrips by 3× for typical pre-trade checks.

## Pointer contracts: trading CW20 ↔ ERC20

If the user holds a CW20 token (Cosmos-side) and wants to trade it on an EVM DEX, route through the pointer contract:

```
CW20 (sei1...) → pointer ERC20 (0x...) → DEX → other ERC20
```

Pointer addresses are deterministic from the underlying CW20 denom. See [pointers/overview.md](../pointers/overview.md) for derivation and registration.

## Protocol-specific notes

| Protocol | Documentation | Notes |
|---|---|---|
| DragonSwap | https://docs.dragonswap.app | V2 + V3 style; SEI/USDC, SEI/WETH common pairs |
| Yei Finance | https://docs.yei.finance | Compound-v3-style; flat fee structure |
| Takara Lend | https://docs.takara.lend | Lending; integrated with Ondo USDY |
| Pyth (oracles) | https://docs.pyth.network | Pull oracle; user pushes update in tx |
| Chainlink | https://docs.chain.link | Push oracle; standard `latestRoundData()` |

## Common pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| `INSUFFICIENT_OUTPUT_AMOUNT` | Slippage exceeded between quote and execute | Tighten time between quote and tx; use shorter deadline (60s) |
| Approve succeeds but swap reverts with `TRANSFER_FROM_FAILED` | Approval went to wrong router address | Verify router address against latest docs |
| Quote returns 0 | Pool doesn't exist for that pair | Check `factory.getPair(tokenA, tokenB)` first |
| Price oracle returns stale data | Pyth update wasn't included in tx | Bundle the Pyth update payload in the same tx |
| Native SEI (not wrapped) errors | DEXes use WSEI; native SEI requires `swapExactETHForTokens` (V2) or `payable` route (V3) | Use the `*ETH*` variants for native SEI; or wrap to WSEI manually |

## Sei-specific notes

- **WSEI** (wrapped SEI) plays the role of WETH. Verify the canonical WSEI address via [docs.sei.io ecosystem contracts](https://docs.sei.io/evm/reference/ecosystem-contracts).
- **Native SEI** uses 18 decimals (not 6 like Cosmos-side `usei` micro-denom — that's a Cosmos-side concept; EVM sees 18 decimals).
- **Atomic batching**: account abstraction (see [dev/account-abstraction.md](../dev/account-abstraction.md)) lets users do approve+swap in one user op without a separate approval tx.
- **Liquidation latency**: 400ms blocks make liquidation MEV competitive; bots can react within 1-2 blocks.
