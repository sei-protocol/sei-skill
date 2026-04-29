---
title: Account Abstraction (ERC-4337) on Sei
description: Status of ERC-4337 on Sei EVM, available bundlers and paymasters (Pimlico, Particle), what works today and what doesn't, and concrete integration code with viem + permissionless.
---

# Account Abstraction (ERC-4337) on Sei

ERC-4337 is supported on Sei EVM. Sei's instant finality and 50 gwei minimum make AA bundlers behave differently than on Ethereum — design accordingly.

> **Quick answer:** Use **Pimlico** as your bundler/paymaster on Sei. The `@sei-js/sei-global-wallet` covers consumer flows without requiring the user to think about smart accounts at all.

## What's available on Sei

| Component | Provider | Status on Sei |
|---|---|---|
| EntryPoint v0.7 | canonical (`0x0000000071727De22E5E9d8BAf0edAc6f37da032`) | Deployed |
| Bundler | **Pimlico** | Live on mainnet + testnet |
| Bundler | Particle Network | Live |
| Paymaster | Pimlico | Live (verifying + ERC20) |
| Paymaster | Particle | Live |
| Smart-account factory | Safe (Gnosis), Kernel (Zerodev), SimpleAccount, Biconomy V2 | Available via Pimlico SDK |
| Embedded-wallet UX | Sei Global Wallet | Live (built on AA primitives) |

Always verify against the latest at https://docs.sei.io/evm/wallet-integrations/pimlico and https://docs.sei.io/evm/wallet-integrations/particle.

## When to use AA on Sei vs not

Use AA when:
- **Gasless UX** — sponsor the user's first N transactions via paymaster.
- **Pay gas in stablecoins** — ERC20 paymaster lets users pay in USDC, USDT.
- **Session keys** — issue a temporary signing key scoped to one dApp.
- **Batch transactions** — atomically execute multiple ops in one user op.
- **Social login / no seed phrase** — embedded wallet with passkey or OAuth.

Skip AA when:
- The user already has MetaMask or Compass and is comfortable signing — adding a smart account is friction without UX win.
- Your dApp is a single contract call — no batching benefit.
- You're price-sensitive on every gas cent — AA adds 30-100k gas overhead per user op vs. a direct EOA tx.

## Pimlico bundler setup (viem + permissionless)

```bash
npm i viem permissionless
```

```ts
// pimlico-client.ts
import { createPublicClient, http } from "viem";
import { createSmartAccountClient } from "permissionless";
import { toSafeSmartAccount } from "permissionless/accounts";
import { createPimlicoClient } from "permissionless/clients/pimlico";
import { entryPoint07Address } from "viem/account-abstraction";

const SEI_MAINNET = {
  id: 1329,
  name: "Sei",
  nativeCurrency: { name: "SEI", symbol: "SEI", decimals: 18 },
  rpcUrls: { default: { http: ["https://evm-rpc.sei-apis.com"] } },
} as const;

const PIMLICO_API_KEY = process.env.PIMLICO_API_KEY!;
const pimlicoUrl = `https://api.pimlico.io/v2/sei/rpc?apikey=${PIMLICO_API_KEY}`;

export const publicClient = createPublicClient({
  chain: SEI_MAINNET,
  transport: http(),
});

export const pimlicoClient = createPimlicoClient({
  transport: http(pimlicoUrl),
  entryPoint: { address: entryPoint07Address, version: "0.7" },
});

export async function getSmartAccountClient(ownerSigner: any) {
  const account = await toSafeSmartAccount({
    client: publicClient,
    owners: [ownerSigner],
    entryPoint: { address: entryPoint07Address, version: "0.7" },
    version: "1.4.1",
  });

  return createSmartAccountClient({
    account,
    chain: SEI_MAINNET,
    bundlerTransport: http(pimlicoUrl),
    paymaster: pimlicoClient,
    userOperation: {
      estimateFeesPerGas: async () => (await pimlicoClient.getUserOperationGasPrice()).fast,
    },
  });
}
```

## Sending a sponsored user operation

```ts
const smartAccount = await getSmartAccountClient(ownerSigner);

const txHash = await smartAccount.sendTransaction({
  to: "0xRecipient",
  value: 0n,
  data: "0xabcdef...",
});

await publicClient.waitForTransactionReceipt({ hash: txHash });
```

Pimlico's verifying paymaster sponsors the gas. The user signs the user op; their EOA balance never decrements.

## Batching multiple calls

```ts
const txHash = await smartAccount.sendTransactions({
  calls: [
    { to: tokenA, data: approveData, value: 0n },
    { to: dexRouter, data: swapData, value: 0n },
    { to: tokenB, data: transferData, value: 0n },
  ],
});
```

One user op, three calls, atomic — either all three execute or none.

## ERC20 paymaster (pay in USDC)

```ts
const txHash = await smartAccount.sendTransaction({
  to: "0xRecipient",
  data: "0x...",
  paymasterContext: {
    token: "0x3894085Ef7Ff0f0aeDf52E2A2704928d1Ec074F1", // example USDC on Sei mainnet — verify
  },
});
```

The paymaster pulls the equivalent USDC from the smart account to cover gas. The user holds zero SEI and still transacts.

> Verify the USDC contract address against [docs.sei.io USDC page](https://docs.sei.io/evm/reference/usdc) before deploying — addresses move during integration phases.

## Sei Global Wallet (embedded AA)

For consumer apps, **prefer Sei Global Wallet** (`@sei-js/sei-global-wallet`) over building your own AA stack. It bundles:

- Embedded smart account (no extension install).
- Social login (Google, Apple, etc.) via passkey-backed key custody.
- Built-in gas sponsorship for onboarding.
- EIP-6963 compatible — works alongside MetaMask/Compass.

See [website/frontend-stack.md](../website/frontend-stack.md) for the wallet setup pattern.

## Gotchas on Sei

| Issue | Cause | Fix |
|---|---|---|
| Bundler rejects user op with `aa23 reverted` | EntryPoint sim failed | Increase `verificationGasLimit`; check that smart account has been deployed (first user op deploys) |
| `gasPrice` confusion in user ops | AA uses `maxFeePerGas` semantically; bundler converts to legacy on submit | Always set `maxFeePerGas ≥ 50 gwei`; bundler picks legacy on Sei |
| User op succeeds on testnet, fails on mainnet | SSTORE 72k testnet vs 20k mainnet — gas estimate may underestimate testnet cost | Use Pimlico's `estimateFeesPerGas` from the bundler, not your own ceiling |
| Smart account address differs across chains | Some factories use chain-id in CREATE2 salt | Use a chain-agnostic factory (Safe, Kernel) if you need address parity |
| Long-tail user op pending | Bundler congestion or under-priced | Bump `maxPriorityFeePerGas`; on Sei the priority fee just inflates total gasPrice |

## Observability

- Track user ops via Seitrace: search by user op hash (the bundler returns it; it differs from the underlying tx hash).
- Pimlico dashboard shows bundler success/fail rate per chain.
- Indexers (Goldsky, The Graph) can index `UserOperationEvent` from the EntryPoint contract — see [indexers.md](../ecosystem/indexers.md).

## Sei-specific notes

- **400ms finality** means the typical "wait for user op confirmation" UX is ~1-2 seconds total (bundler bundling + 1 block). Match Ethereum-style 12s spinners look broken.
- **No EIP-1559 priority fee** — paymasters on Sei don't price the same way as on Optimism/Arbitrum.
- **Cross-VM via precompiles** — a smart account can call CosmWasm precompiles in a user op; the precompile call counts as a single internal call for gas estimation.
- **Deprecated CosmWasm** (SIP-3) — don't build smart-account logic that depends on CosmWasm contracts; stick to EVM.
