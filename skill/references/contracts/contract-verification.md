---
title: Contract Verification on Sei
description: Verify EVM contracts on Seitrace (Sei's block explorer) using Foundry forge verify-contract or Hardhat's verification plugin. Covers single-file, multi-file, and proxy patterns plus common failure modes.
---

# Contract Verification on Sei

After deploying, verify source code so users and integrators can read your contract on the block explorer. Sei's primary explorer is **Seitrace** (https://seitrace.com).

## Quick decision: which tool?

| Tool | Use when |
|---|---|
| `forge verify-contract` | Foundry deployment; simpler one-shot verification |
| `hardhat verify` | Hardhat deployment; matches existing JS toolchain |
| Manual via Seitrace UI | Anything else fails; flatten + paste source |

## Explorers and chain IDs

| Network | Explorer | Chain ID | Verification API |
|---|---|---|---|
| Mainnet (`pacific-1`) | https://seitrace.com | 1329 | https://seitrace.com/pacific-1/api |
| Testnet (`atlantic-2`) | https://seitrace.com/?chain=atlantic-2 | 1328 | https://seitrace.com/atlantic-2/api |

> Always pass `--chain-id` and `--verifier-url` explicitly. Seitrace serves both networks from the same hostname; the path differs.

## Foundry: `forge verify-contract`

```bash
forge verify-contract \
  --rpc-url https://evm-rpc.sei-apis.com \
  --verifier blockscout \
  --verifier-url https://seitrace.com/pacific-1/api \
  --chain-id 1329 \
  <DEPLOYED_ADDRESS> \
  src/MyContract.sol:MyContract
```

Seitrace is Blockscout-compatible — pass `--verifier blockscout`. Etherscan-format verification is **not** supported.

### Verifying with constructor args

```bash
forge verify-contract \
  --verifier blockscout \
  --verifier-url https://seitrace.com/pacific-1/api \
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
  --verifier blockscout \
  --verifier-url https://seitrace.com/pacific-1/api \
  --chain-id 1329
```

## Hardhat: `hardhat verify`

Add to `hardhat.config.ts`:

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
  etherscan: {
    apiKey: { seiMainnet: "no-key-needed", seiTestnet: "no-key-needed" },
    customChains: [
      {
        network: "seiMainnet",
        chainId: 1329,
        urls: {
          apiURL: "https://seitrace.com/pacific-1/api",
          browserURL: "https://seitrace.com",
        },
      },
      {
        network: "seiTestnet",
        chainId: 1328,
        urls: {
          apiURL: "https://seitrace.com/atlantic-2/api",
          browserURL: "https://seitrace.com/?chain=atlantic-2",
        },
      },
    ],
  },
};
```

Then:

```bash
npx hardhat verify --network seiMainnet <DEPLOYED_ADDRESS> "constructor-arg-1" "constructor-arg-2"
```

Seitrace's API is Blockscout-compatible and accepts a no-op API key.

## Proxy verification (UUPS, Transparent, Beacon)

1. Verify the **implementation** contract first using its deployed address.
2. On Seitrace, navigate to the **proxy** address → "More" tab → "Is this a proxy?" → confirm.
3. Seitrace then routes reads through the implementation ABI.

For OpenZeppelin proxies deployed via Hardhat-Upgrades:

```bash
npx hardhat verify --network seiMainnet <PROXY_ADDRESS>
# Then on Seitrace: mark address as proxy + link to implementation
```

## Common failure modes

| Symptom | Cause | Fix |
|---|---|---|
| `Bytecode mismatch` | Compiler version or optimizer settings differ from deploy | Pin `solc_version`, `optimizer_runs`, and `evm_version` exactly; rebuild with same `foundry.toml` / `hardhat.config.ts` used at deploy |
| `Source code does not match` | Modified source after deployment | Re-fetch the exact commit used to deploy |
| `Could not detect network` (Hardhat) | `customChains` entry missing or chainId wrong | Add the `customChains` block above |
| `--verifier etherscan` fails | Seitrace is Blockscout, not Etherscan | Use `--verifier blockscout` |
| Verification succeeds but proxy reads as opaque | Proxy not linked to impl | Use Seitrace UI: address → "Is this a proxy?" → set implementation |
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

## Sourcify (alternative)

Seitrace also accepts Sourcify-verified contracts. After publishing to Sourcify (https://sourcify.dev), Seitrace will mark the contract as verified within minutes — no Sei-specific config needed beyond chain ID 1329 / 1328.

## Sei-specific notes

- Verification works the same on testnet — verify there first to confirm config before mainnet.
- After SSTORE-cost differences between testnet and mainnet, the **deployed bytecode is identical** — verification metadata depends only on `solc` settings, not gas params.
- For contracts that call precompiles, no special verification step is needed; precompile addresses are immutable and decoded by Seitrace automatically.
