---
title: Contract Verification on Sei
description: Verify EVM contracts on Seiscan (Sei's block explorer) using Sourcify via Foundry forge verify-contract or Hardhat's verification plugin. Covers single-file, multi-file, and proxy patterns plus common failure modes.
---

# Contract Verification on Sei

After deploying, verify source code so users and integrators can read your contract on the block explorer. Sei's primary explorer is **Seiscan** (https://seiscan.io).

Sei uses **Sourcify** for contract verification — no API key required, no explorer-specific endpoint needed.

## Quick decision: which tool?

| Tool | Use when |
|---|---|
| `forge verify-contract` | Foundry deployment; simpler one-shot verification |
| `hardhat verify sourcify` | Hardhat deployment; matches existing JS toolchain |
| Manual via Sourcify UI | Anything else fails; upload source files directly |

## Explorers and chain IDs

| Network | Explorer | Chain ID |
|---|---|---|
| Mainnet (`pacific-1`) | https://seiscan.io | 1329 |
| Testnet (`atlantic-2`) | https://testnet.seiscan.io | 1328 |

## Foundry: `forge verify-contract`

```bash
forge verify-contract \
  --rpc-url https://evm-rpc.sei-apis.com \
  --verifier sourcify \
  --chain-id 1329 \
  <DEPLOYED_ADDRESS> \
  src/MyContract.sol:MyContract
```

Use `--verifier sourcify` — no `--verifier-url` needed.

### Verifying with constructor args

```bash
forge verify-contract \
  --verifier sourcify \
  --chain-id 1329 \
  --constructor-args $(cast abi-encode "constructor(address,uint256)" 0xOwner 1000) \
  <DEPLOYED_ADDRESS> \
  src/MyContract.sol:MyContract
```

### Verifying after `forge script` deploy

Add `--verify` to the deploy script and Foundry verifies in one shot:

```bash
forge script script/Deploy.s.sol \
  --rpc-url https://evm-rpc.sei-apis.com \
  --broadcast \
  --verify \
  --verifier sourcify \
  --chain-id 1329
```

## Hardhat: `hardhat verify`

Install the verify plugin if not already included in `hardhat-toolbox`:

```bash
npm install --save-dev @nomicfoundation/hardhat-verify
```

No special `etherscan` block is needed in `hardhat.config.ts` for Sourcify. The network config alone is sufficient:

```ts
import "@nomicfoundation/hardhat-verify";

export default {
  networks: {
    seiMainnet: {
      url: "https://evm-rpc.sei-apis.com",
      chainId: 1329,
    },
    seiTestnet: {
      url: "https://evm-rpc-testnet.sei-apis.com",
      chainId: 1328,
    },
  },
};
```

Then verify:

```bash
npx hardhat verify sourcify --network seiMainnet <DEPLOYED_ADDRESS> "constructor-arg-1" "constructor-arg-2"
```

## Proxy verification (UUPS, Transparent, Beacon)

1. Verify the **implementation** contract first using its deployed address.
2. On Seiscan, navigate to the **proxy** address → "More" tab → "Is this a proxy?" → confirm.
3. Seiscan then routes reads through the implementation ABI.

For OpenZeppelin proxies deployed via Hardhat-Upgrades:

```bash
npx hardhat verify sourcify --network seiMainnet <PROXY_ADDRESS>
# Then on Seiscan: mark address as proxy + link to implementation
```

## Common failure modes

| Symptom | Cause | Fix |
|---|---|---|
| `Bytecode mismatch` | Compiler version or optimizer settings differ from deploy | Pin `solc_version`, `optimizer_runs`, and `evm_version` exactly; rebuild with same `foundry.toml` / `hardhat.config.ts` used at deploy |
| `Source code does not match` | Modified source after deployment | Re-fetch the exact commit used to deploy |
| Verification succeeds but proxy reads as opaque | Proxy not linked to impl | Use Seiscan UI: address → "Is this a proxy?" → set implementation |
| `evm_version` mismatch | Sei-EVM compatibility | Set `evm_version = "cancun"` (or earlier; never above what Sei supports) |

## EVM version setting

Set `evm_version` to **`cancun`** or earlier in `foundry.toml` / `hardhat.config.ts`. Newer (e.g., `prague`) opcodes may not be enabled on Sei yet. Mismatched evm_version is a common silent verification failure.

```toml
# foundry.toml
[profile.default]
solc_version = "0.8.28"
optimizer = true
optimizer_runs = 200
evm_version = "cancun"
```

## Sourcify (direct)

Sourcify performs byte-by-byte verification by recompiling your source with the exact same compiler settings. You can also verify directly at https://verify.sourcify.dev — upload your source files and metadata. Seiscan shows contracts verified via Sourcify automatically.

## Sei-specific notes

- Verify on testnet first to confirm config before mainnet — same steps, swap chain ID 1329 → 1328 and RPC URL.
- After SSTORE-cost differences between testnet and mainnet, the **deployed bytecode is identical** — verification metadata depends only on `solc` settings, not gas params.
- For contracts that call precompiles, no special verification step is needed; precompile addresses are immutable and decoded by Seiscan automatically.
