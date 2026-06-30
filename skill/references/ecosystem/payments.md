---
title: Payments on Sei (USDC + x402)
description: Accept and send payments on Sei with USDC (ERC-20, 6 decimals) and x402 HTTP-native micropayments. Addresses, transfer flow, the 402 challenge/verify cycle, and replay protection.
---

# Payments on Sei (USDC + x402)

Moving and accepting digital dollars on Sei: transferring **USDC** as a standard ERC-20, and gating HTTP endpoints behind per-request payments with the **x402** protocol so APIs, agents, and content can charge in stablecoins. USDC is the unit of account for both flows — x402 settles in USDC on Sei.

## Critical facts

- **USDC is a standard ERC-20 on Sei EVM.** Transfer with `transfer(to, amount)`, read balances with `balanceOf(account)`. No special precompile or bridge call for plain transfers.
- **USDC has 6 decimals** (not 18). `1 USDC = 1_000_000` base units. Convert with `parseUnits(value, 6)` / `formatUnits(value, 6)` — using 18 overpays by 10^12×.
- **USDC token addresses** (verify on [Seiscan](https://seiscan.io) before sending real value):
  - Mainnet (pacific-1, 1329): `0xe15fC38F6D8c56aF07bbCBe3BAf5708A2Bf42392`
  - Testnet (atlantic-2, 1328): `0x4fCF1784B31630811181f670Aea7A7bEF803eaED`
- **Get testnet USDC** from the [Circle Faucet](https://faucet.circle.com), or bridge real USDC cross-chain with [Circle CCTP v2](https://developers.circle.com/cctp). You still need a little native SEI for fees.
- **~400ms blocks with fast finality make micropayments practical.** Confirm with one confirmation (`tx.wait(1)` / one block of polling), never `tx.wait(12)`. `safe`/`finalized`/`latest` resolve to the same instantly-final block — query `latest`.
- **Use legacy `gasPrice`.** No EIP-1559 base-fee burn (all fees go to validators). The minimum gas price is governance-adjustable (currently ~50 gwei on mainnet — query `eth_gasPrice` for the live floor). See https://docs.sei.io/evm/differences-with-ethereum.
- **x402 uses HTTP 402 ("Payment Required").** The server answers an unpaid request with `402` + a JSON payment challenge; the client pays on-chain, then retries with proof in a base64 `X-Payment` header. The challenge `x402Version` is `1`, scheme `exact`.

## x402 packages (`@sei-js`)

Pick by role rather than hand-rolling challenge/verify:
- Client (paying): [`@sei-js/x402-fetch`](https://www.npmjs.com/package/@sei-js/x402-fetch) or [`@sei-js/x402-axios`](https://www.npmjs.com/package/@sei-js/x402-axios).
- Server (charging): [`@sei-js/x402-express`](https://www.npmjs.com/package/@sei-js/x402-express), [`@sei-js/x402-hono`](https://www.npmjs.com/package/@sei-js/x402-hono), or [`@sei-js/x402-next`](https://www.npmjs.com/package/@sei-js/x402-next).
- Core protocol: [`@sei-js/x402`](https://www.npmjs.com/package/@sei-js/x402).

## Send / accept USDC (viem)

Minimal ERC-20 flow — check balance, then transfer. Default to testnet; switch to mainnet only on explicit confirmation.

```js
import { createPublicClient, createWalletClient, http, formatUnits, parseUnits } from 'viem';
import { sei, seiTestnet } from 'viem/chains';
import { privateKeyToAccount } from 'viem/accounts';

const NETWORK = (process.env.SEI_NETWORK || 'testnet').toLowerCase();
const chain = NETWORK === 'mainnet' ? sei : seiTestnet;

// USDC: 6 decimals. Verify addresses on Seiscan before mainnet use.
const USDC_ADDRESS = NETWORK === 'mainnet'
  ? '0xe15fC38F6D8c56aF07bbCBe3BAf5708A2Bf42392'
  : '0x4fCF1784B31630811181f670Aea7A7bEF803eaED';
const USDC_ABI = [
  { name: 'balanceOf', type: 'function', stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }], outputs: [{ type: 'uint256' }] },
  { name: 'transfer', type: 'function', stateMutability: 'nonpayable',
    inputs: [{ name: 'to', type: 'address' }, { name: 'amount', type: 'uint256' }],
    outputs: [{ type: 'bool' }] },
];

const account = privateKeyToAccount(process.env.PRIVATE_KEY);
const publicClient = createPublicClient({ chain, transport: http() });
const walletClient = createWalletClient({ account, chain, transport: http() });

const balance = await publicClient.readContract({
  address: USDC_ADDRESS, abi: USDC_ABI, functionName: 'balanceOf', args: [account.address],
});
console.log('USDC balance:', formatUnits(balance, 6));

const amount = parseUnits('10', 6); // 10 USDC
if (balance < amount) throw new Error('Insufficient USDC balance');

const hash = await walletClient.writeContract({
  address: USDC_ADDRESS, abi: USDC_ABI, functionName: 'transfer', args: [process.env.RECIPIENT_ADDRESS, amount],
});
await publicClient.waitForTransactionReceipt({ hash }); // one confirmation is enough on Sei
```

## Charge per request with x402

Five steps: (1) client requests a protected resource; (2) server returns `402` with a payment challenge; (3) client pays on-chain (a USDC transfer to `payTo`); (4) client retries with a base64 `X-Payment` proof; (5) server verifies on-chain and serves the resource.

The challenge advertised on a `402` response:

```json
{
  "x402Version": 1,
  "accepts": [{
    "scheme": "exact",
    "network": "sei-testnet",
    "maxAmountRequired": "1000",
    "resource": "/api/weather",
    "payTo": "0x9dC2aA0038830c052253161B1EE49B9dD449bD66",
    "asset": "0x4fCF1784B31630811181f670Aea7A7bEF803eaED",
    "extra": { "name": "USDC", "version": "2", "reference": "sei-1234567890-abc123" }
  }]
}
```

`maxAmountRequired` is in USDC base units — `"1000"` is `0.001` USDC. The `reference` is a per-challenge nonce used to prevent replay. Note `extra.version` (`"2"`) is the USDC contract's **EIP-712 domain version**, *not* the x402 protocol version (the top-level `x402Version`, `1`) — do not conflate them.

Verification must check the receipt status, the recipient, the exact amount, **and** that the reference nonce has not been seen before:

```typescript
async function verifyPayment(paymentHeader: string) {
  const data = JSON.parse(Buffer.from(paymentHeader, 'base64').toString());
  const { x402Version, scheme, network, payload } = data;
  if (x402Version !== 1 || scheme !== 'exact' || network !== 'sei-testnet') {
    return { isValid: false, reason: 'Invalid payment format or network' };
  }

  const receipt = await publicClient.getTransactionReceipt({ hash: payload.txHash });
  if (receipt?.status !== 'success') {
    return { isValid: false, reason: 'Transaction not found or reverted' };
  }

  // REQUIRED for a non-replayable paywall — do NOT ship without these.
  // transferMatches decodes the USDC Transfer event from receipt.logs and confirms
  // to === payTo and value >= maxAmountRequired; the reference helpers persist seen
  // nonces so one valid payment can't be replayed. (The @sei-js/x402-* middleware does this.)
  if (!transferMatches(receipt, payTo, maxAmountRequired) || !isReferenceUnused(payload.reference)) {
    return { isValid: false, reason: 'Payment does not match challenge or was already used' };
  }
  markReferenceUsed(payload.reference);
  return { isValid: true, txHash: payload.txHash };
}
```

For production, prefer the `@sei-js/x402-*` middleware (Express/Hono/Next) and client wrappers over hand-rolling challenge/verify. See the [sei-x402 repo](https://github.com/sei-protocol/sei-x402).

## Common pitfalls

- **Treating USDC as 18 decimals.** It is 6 decimals — `parseUnits('10', 6)`, not `parseEther('10')`. A wrong constant multiplies the amount by 10^12.
- **Waiting for 12 confirmations.** Sei finalizes in ~400ms — one confirmation; waiting 12 defeats the point of micropayments.
- **Sending EIP-1559 fee fields.** Use legacy `gasPrice`; query the live floor rather than hardcoding.
- **Forgetting native SEI for fees.** A USDC transfer still costs fees in native SEI.
- **Trusting `txHash` alone in x402.** Verify receipt status, recipient (`payTo`), exact amount, AND the unused `reference` nonce — otherwise a valid payment can be replayed.
- **Using testnet addresses on mainnet (or vice versa).** The USDC address differs per network — re-verify on Seiscan before moving real value.

## Key links

| Topic | Link |
|---|---|
| USDC on Sei (addresses, transfer guide) | https://docs.sei.io/evm/usdc-on-sei |
| x402 protocol on Sei | https://docs.sei.io/ai/x402 |
| sei-x402 repo (packages, quickstarts) | https://github.com/sei-protocol/sei-x402 |
| Circle CCTP v2 (bridge USDC in) | https://developers.circle.com/cctp |
| Circle testnet faucet | https://faucet.circle.com |
