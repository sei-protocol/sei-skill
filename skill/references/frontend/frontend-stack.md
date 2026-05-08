---
title: Frontend Stack for Sei dApps
description: Build web frontends that interact with Sei. Default stack is Wagmi + Viem + Sei Global Wallet for React; ethers v6 for scripts. Covers wallet detection (EIP-6963), dual-address UX, fast-finality patterns, multichain configs, and common pitfalls.
---

# Frontend Stack for Sei dApps

Build dApps that interact with Sei from the browser or Node. This file replaces and expands the older `frontend.md` — same default stack, more depth on wallet detection, dual-address UX, and Sei-specific patterns.

## Default stack (opinionated)

| Layer | Default | Use instead when |
|---|---|---|
| **Library** | Wagmi + Viem | You want maximum control or React-free scripts → ethers v6 |
| **Wallet (consumer)** | Sei Global Wallet (`@sei-js/sei-global-wallet`) | Power-user app → MetaMask, Compass, Ledger |
| **Wallet UX shell** | RainbowKit or ConnectKit | You want bare bones → Wagmi `useConnect` directly |
| **Chain config** | `@sei-js/evm` exports | You need a chain not in `@sei-js/evm` → manual `defineChain` |
| **State / data** | TanStack Query (Wagmi default) | Already on Redux/Zustand → integrate manually |

## Quick install

```bash
# React + Wagmi + Viem default
npm install wagmi viem @tanstack/react-query @sei-js/evm

# Optional embedded wallet
npm install @sei-js/sei-global-wallet

# Optional pretty connect modal
npm install @rainbow-me/rainbowkit

# Non-React / Node.js scripts
npm install ethers @sei-js/evm
```

## Wagmi setup

```ts
// wagmi.config.ts
import { createConfig, http } from "wagmi";
import { seiMainnet, seiTestnet } from "@sei-js/evm";
import { injected, walletConnect } from "wagmi/connectors";

export const wagmiConfig = createConfig({
  chains: [seiMainnet, seiTestnet],
  transports: {
    [seiMainnet.id]: http("https://evm-rpc.sei-apis.com"),
    [seiTestnet.id]: http("https://evm-rpc-testnet.sei-apis.com"),
  },
  connectors: [
    injected(),
    walletConnect({ projectId: process.env.NEXT_PUBLIC_WC_PROJECT_ID! }),
  ],
});
```

```tsx
// app.tsx
import { WagmiProvider } from "wagmi";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { wagmiConfig } from "./wagmi.config";

const queryClient = new QueryClient();

export function App({ children }: { children: React.ReactNode }) {
  return (
    <WagmiProvider config={wagmiConfig}>
      <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
    </WagmiProvider>
  );
}
```

## Reading and writing contracts

```tsx
import { useAccount, useReadContract, useWriteContract } from "wagmi";
import { parseEther, parseUnits } from "viem";
import { seiMainnet } from "@sei-js/evm";

function Balance({ token }: { token: `0x${string}` }) {
  const { address } = useAccount();
  const { data } = useReadContract({
    address: token,
    abi: ERC20_ABI,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
  });
  return <span>{data?.toString() ?? "—"}</span>;
}

function Send({ token, to, amount }: { token: `0x${string}`; to: `0x${string}`; amount: string }) {
  const { writeContractAsync, isPending } = useWriteContract();
  const onClick = async () => {
    await writeContractAsync({
      address: token,
      abi: ERC20_ABI,
      functionName: "transfer",
      args: [to, parseUnits(amount, 18)],
      gasPrice: parseUnits("50", "gwei"),  // ≥ 50 gwei on Sei
      chainId: seiMainnet.id,              // pin chain to prevent cross-chain mistakes
    });
  };
  return <button onClick={onClick} disabled={isPending}>Send</button>;
}
```

## Wallet detection (EIP-6963)

EIP-6963 lets multiple wallet extensions coexist without fighting over `window.ethereum`. Wagmi's `injected()` connector discovers all EIP-6963 wallets automatically — Sei Global Wallet, MetaMask, Rabby, Compass, Coinbase Wallet, etc.

```ts
import { useConnect } from "wagmi";

function ConnectMenu() {
  const { connectors, connect } = useConnect();
  return (
    <ul>
      {connectors.map(c => (
        <li key={c.uid}>
          <button onClick={() => connect({ connector: c })}>
            {c.name}{c.icon && <img src={c.icon} alt="" width={20} />}
          </button>
        </li>
      ))}
    </ul>
  );
}
```

For a polished modal, use RainbowKit:

```tsx
import { RainbowKitProvider, getDefaultConfig } from "@rainbow-me/rainbowkit";
import "@rainbow-me/rainbowkit/styles.css";
import { seiMainnet, seiTestnet } from "@sei-js/evm";

const config = getDefaultConfig({
  appName: "My Sei App",
  projectId: process.env.NEXT_PUBLIC_WC_PROJECT_ID!,
  chains: [seiMainnet, seiTestnet],
});

export function App() {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider>{/* app */}</RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
}
```

## Sei Global Wallet (embedded, social-login)

For consumer apps, **default to Sei Global Wallet**: passkey/social login, no extension install, EIP-6963 compatible (so Wagmi's `injected()` picks it up).

```ts
// Side-effect import registers the wallet as an EIP-6963 provider
import "@sei-js/sei-global-wallet";

// That's it — Wagmi's injected() now sees it alongside MetaMask et al.
```

In a Wagmi connect menu, Sei Global Wallet appears as a discovered connector. Users without any extension still see it as an option.

## Dual-address UX (`sei1...` ↔ `0x...`)

Every Sei account has both an EVM address (`0x...`) and a Cosmos address (`sei1...`). Frontends should usually:

1. Show the user's EVM address as the primary identifier.
2. Show the Cosmos counterpart when the user might need it (delegations, IBC transfers).
3. Detect and surface the **association** state.

```tsx
import { ADDR_PRECOMPILE_ADDRESS, ADDR_PRECOMPILE_ABI } from "@sei-js/evm";

function DualAddress({ evm }: { evm: `0x${string}` }) {
  const { data: cosmos } = useReadContract({
    address: ADDR_PRECOMPILE_ADDRESS,
    abi: ADDR_PRECOMPILE_ABI,
    functionName: "getSeiAddr",
    args: [evm],
  });

  const associated = cosmos && cosmos !== "";
  return (
    <div>
      <code>EVM: {evm}</code>
      <code>Cosmos: {associated ? cosmos : "(unassociated)"}</code>
      {!associated && <small>Associate to enable cross-VM transfers.</small>}
    </div>
  );
}
```

Pre-association, certain operations fail (e.g., receiving CW20 → ERC20 pointer transfers). See [addresses-wallets.md](../addresses-wallets.md) for the association flow.

## Fast-finality UX (no multi-confirm spinners)

Sei has 400ms blocks and instant finality. Standard "wait 12 confirmations" patterns are wrong:

```ts
// Ethereum mental model — DON'T do this on Sei
await tx.wait(12); // ~144 seconds

// Sei
await publicClient.waitForTransactionReceipt({ hash, confirmations: 1 });
// Done in ~400ms — no extra waiting needed
```

UX implication: a Sei tx flow can complete in under a second. Don't show a 10-second progress bar to fill time — show success immediately on receipt.

## Block tag handling

Sei doesn't expose `safe` / `finalized` block tags as distinct from `latest`:

```ts
// All equivalent on Sei
const block = await publicClient.getBlock({ blockTag: "latest" });
// "safe" and "finalized" are not Sei concepts; if your code asks for them, treat them as "latest".
```

Some libraries map `finalized` → 64 blocks back automatically. On Sei that just lags by 25 seconds for no benefit; prefer `latest`.

## Multi-chain frontends (Sei + Ethereum + L2s)

Wagmi handles multichain natively. Just include the chains you support:

```ts
import { mainnet, arbitrum, optimism } from "wagmi/chains";
import { seiMainnet } from "@sei-js/evm";

export const config = createConfig({
  chains: [seiMainnet, mainnet, arbitrum, optimism],
  transports: {
    [seiMainnet.id]: http("https://evm-rpc.sei-apis.com"),
    [mainnet.id]: http(),
    [arbitrum.id]: http(),
    [optimism.id]: http(),
  },
});
```

When sending a tx, always pin `chainId` to prevent the wallet from routing to the wrong chain:

```ts
await writeContract({ /* ... */, chainId: seiMainnet.id });
```

## Network-add UX

If the user's wallet doesn't already know about Sei, prompt to add it:

```ts
import { useSwitchChain } from "wagmi";
import { seiMainnet } from "@sei-js/evm";

const { switchChainAsync } = useSwitchChain();

await switchChainAsync({ chainId: seiMainnet.id });
// Wagmi triggers wallet_addEthereumChain if needed
```

`@sei-js/evm`'s exports include the canonical `chainName`, `nativeCurrency`, `rpcUrls`, and `blockExplorers` that wallets need.

## ethers v6 (non-React, scripts)

```ts
import { ethers } from "ethers";

// Browser
const provider = new ethers.BrowserProvider(window.ethereum);
await provider.send("eth_requestAccounts", []);
const signer = await provider.getSigner();

// Node.js
const provider = new ethers.JsonRpcProvider("https://evm-rpc.sei-apis.com");
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

// Send with gasPrice (NOT EIP-1559)
const tx = await contract.connect(wallet).transfer(to, amount, {
  gasPrice: ethers.parseUnits("50", "gwei"),
});
const receipt = await tx.wait(1); // 1 block = final
```

## RPC failover

Use viem's `fallback` transport (or ethers' `FallbackProvider`) for production:

```ts
import { createPublicClient, fallback, http } from "viem";

const client = createPublicClient({
  chain: seiMainnet,
  transport: fallback([
    http("https://evm-rpc.sei-apis.com"),
    http("https://1rpc.io/sei"),
    http("https://your-paid-provider.example/sei"),
  ], { rank: true }),
});
```

See [ecosystem/rpc-providers.md](../ecosystem/rpc-providers.md) for the endpoint list.

## Sei Global Wallet vs MetaMask vs Compass — UX trade-offs

| Wallet | Strength | When to pick it |
|---|---|---|
| **Sei Global Wallet** | No install; social login; Sei-native | Consumer apps; onboarding new users |
| **MetaMask** | Universal; user already has it | Desktop power users; multi-chain dApps |
| **Compass** | Native Sei (Cosmos + EVM); Sei-only | Sei-focused dApps targeting Sei power users |
| **Leap** | Cosmos + EVM; multi-chain | Users who already use Cosmos chains |
| **Ledger** | Hardware; air-gapped | Custody-focused; high-value flows |

For most consumer apps, expose Sei Global Wallet **first** in the connect menu and MetaMask second.

## Common frontend pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| `unsupported chain` from wallet | Wallet doesn't know Sei | Use `useSwitchChain` to add Sei via `@sei-js/evm` config |
| `replacement transaction underpriced` | gas price < 50 gwei | Set `gasPrice: parseUnits("50", "gwei")` |
| `user rejected` after delay | EIP-1559 fields confused wallet | Drop `maxFeePerGas`/`maxPriorityFeePerGas`; use legacy `gasPrice` |
| Transaction confirms but UI never updates | Watching wrong chain | Pin `chainId` in writes; ensure read hooks watch the same chain |
| `ChainId 1329 not found` | Stale `@sei-js/evm` version | Upgrade to latest |
| Two wallets fight for `window.ethereum` | Pre-EIP-6963 wallet behavior | Use `injected()` connector — it uses EIP-6963 discovery, not `window.ethereum` |
| Sei Global Wallet doesn't appear | Forgot side-effect import | Add `import "@sei-js/sei-global-wallet"` at app entry |

## Testing your frontend

- **Unit**: mock contracts; test hooks with `@testing-library/react`.
- **Integration**: spin up a forked anvil (`anvil --fork-url https://evm-rpc-testnet.sei-apis.com --chain-id 1328`) and point Wagmi at `http://localhost:8545`.
- **End-to-end**: testnet with the faucet (`https://atlantic-2.app.sei.io/faucet`) — verify dual-address flows, especially.

## Project scaffolding

```bash
npx @sei-js/create-sei my-sei-app
# Interactive: pick React/Next.js, Wagmi/Ethers, TypeScript
```

Includes pre-configured Sei network entries.

## Sei-specific notes

- **Always use legacy `gasPrice ≥ 50 gwei`**; never EIP-1559 priority fee fields.
- **Always pin `chainId`** in write calls.
- **Always use `wait(1)` / `confirmations: 1`** — anything more is wasted UX time.
- **Always import precompile addresses + ABIs from `@sei-js/evm`** rather than hardcoding.
- **For consumer onboarding**, lead with Sei Global Wallet + social login rather than MetaMask.
- **For production**, use multi-RPC failover (viem `fallback` or ethers `FallbackProvider`).
- **For dual-address UX**, surface the `sei1...` counterpart when the user touches IBC, staking, or governance flows.
