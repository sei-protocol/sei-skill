---
title: Bridges to/from Sei
description: Bridges live on Sei — LayerZero V2 (OFT), Wormhole, Axelar, IBC, ThirdWeb. Supported assets, source chains, contract addresses, and integration patterns for each.
---

# Bridges to/from Sei

How users and contracts move assets between Sei and other chains. Sei supports three EVM-style bridges (LayerZero, Wormhole, Axelar) plus IBC for the Cosmos ecosystem.

> **Always verify bridge contract addresses** against the bridge's official docs before sending real value. Bridges are high-value targets and addresses change during version upgrades.

## Quick decision: which bridge?

| Bridge | Best for | Avoid when |
|---|---|---|
| **LayerZero V2** | OFT-style omnichain tokens; cross-chain dApp messaging | You need maximum decentralization (LZ uses a configurable DVN model) |
| **Wormhole** | Native asset transfers from Solana, Ethereum, Polygon | You want native LayerZero/CCTP routing |
| **Axelar** | Generalized message passing + asset transfers from Cosmos and EVM | Lowest-fee swaps (Axelar adds infra cost) |
| **IBC** | Cosmos ecosystem (Osmosis, Stride, Noble) | EVM source/dest chain |
| **ThirdWeb Bridge** | Embedded bridge UX in your dApp | You need direct contract integration |
| **Native USDC via CCTP** | USDC ↔ USDC across chains, no synthetic | Other assets |

## LayerZero V2

Live on Sei mainnet and testnet. Sei is fully integrated as a LayerZero V2 endpoint.

### Endpoints (mainnet)

| Component | Address |
|---|---|
| LayerZero Endpoint | `0x1a44076050125825900e736c501f859c50fE728c` |
| SendUln302 | `0xC39161c743D0307EB9BCc9FEF03eeb9Dc4802de7` |

> Verify against https://docs.layerzero.network/v2/deployments/sei before deploying.

### OFT (Omnichain Fungible Token) pattern

Deploying a token that exists on Sei + Ethereum + Arbitrum simultaneously, with native cross-chain transfers:

```solidity
// MyOFT.sol
pragma solidity ^0.8.28;
import "@layerzerolabs/oft-evm/contracts/OFT.sol";

contract MyOFT is OFT {
    constructor(string memory name, string memory symbol, address lzEndpoint, address owner)
        OFT(name, symbol, lzEndpoint, owner)
        Ownable(owner)
    {}
}
```

Deploy on each chain with the local LayerZero endpoint. Then wire the peers:

```ts
// Set Sei as a peer of Ethereum's MyOFT
await ethOft.setPeer(SEI_EID, addressToBytes32(seiOftAddress));
// And vice versa
await seiOft.setPeer(ETH_EID, addressToBytes32(ethOftAddress));
```

Cross-chain send:

```ts
import { Options } from "@layerzerolabs/lz-v2-utilities";

const options = Options.newOptions().addExecutorLzReceiveOption(200_000n, 0n).toHex();
const sendParam = {
  dstEid: SEI_EID,
  to: addressToBytes32(recipient),
  amountLD: parseEther("100"),
  minAmountLD: parseEther("99"),
  extraOptions: options,
  composeMsg: "0x",
  oftCmd: "0x",
};

const { nativeFee } = await oft.read.quoteSend([sendParam, false]);
await oft.write.send([sendParam, { nativeFee, lzTokenFee: 0n }, refundAddr], { value: nativeFee });
```

See https://docs.layerzero.network/v2/concepts/intro for full OFT walkthrough.

### Sei Endpoint IDs

| Network | EID |
|---|---|
| Sei mainnet | (verify via LZ docs — values change) |
| Sei testnet | (verify via LZ docs) |

## Wormhole

Live on Sei mainnet. Supports native token transfers, ERC-20 wrapping, NFT bridging, and generic messaging.

### Use cases

- Transfer USDC from Solana to Sei.
- Bridge ETH from Ethereum to Sei (becomes wrapped wETH).
- Cross-chain governance messages.

### Integration

Wormhole's TokenBridge contract on Sei has a fixed address — **verify via https://docs.wormhole.com/wormhole/reference/constants before integrating**.

```ts
import {
  wormhole,
  Wormhole,
  TokenId,
  amount,
} from "@wormhole-foundation/sdk";
import evm from "@wormhole-foundation/sdk/platforms/evm";

const wh = await wormhole("Mainnet", [evm]);
const sei = wh.getChain("Sei");
const eth = wh.getChain("Ethereum");

const xfer = await wh.tokenTransfer(
  Wormhole.tokenId("Ethereum", "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"), // USDC on ETH
  amount.units(amount.parse("100", 6)),
  Wormhole.chainAddress("Ethereum", senderEth),
  Wormhole.chainAddress("Sei", recipientSei),
  false, // not automatic
);

const txids = await xfer.initiateTransfer(ethSigner);
// Wait, then:
const vaa = await xfer.fetchAttestation();
const completeTxids = await xfer.completeTransfer(seiSigner);
```

## Axelar

Live on Sei. Generalized message passing + asset transfers via the Axelar Network.

```solidity
import "@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";

contract MyAxelarApp is AxelarExecutable {
    constructor(address gateway) AxelarExecutable(gateway) {}

    function sendMessage(string calldata destChain, string calldata destAddress, bytes calldata payload) external payable {
        gateway.callContract(destChain, destAddress, payload);
    }

    function _execute(string calldata sourceChain, string calldata sourceAddress, bytes calldata payload) internal override {
        // Handle inbound message
    }
}
```

Sei Axelar gateway address: verify via https://docs.axelar.dev/dev/reference/mainnet-contract-addresses.

## IBC (Cosmos ecosystem)

For asset transfers between Sei and Cosmos chains (Osmosis, Stride, Noble, etc.). IBC operates on the **Cosmos side** of Sei — uses `sei1...` addresses, not `0x...`.

To bridge an EVM-side asset (e.g., a pointer-wrapped ERC20) to a Cosmos chain via IBC:

1. **Bridge EVM → Cosmos via the pointer/precompile bridge** — the asset becomes a Cosmos-side `ibc/...` denom.
2. **Send via `seid tx ibc-transfer transfer`** — standard IBC transfer to the destination chain.

```bash
seid tx ibc-transfer transfer \
  transfer channel-X \
  sei1recipient... \
  100usei \
  --from mywallet \
  --node https://rpc.sei-apis.com \
  --chain-id pacific-1
```

Channel IDs and counterparties: https://www.mintscan.io/sei/relayers.

See [ibc-bridging.md](ibc-bridging.md) for full IBC mechanics.

## ThirdWeb Bridge

ThirdWeb's bridge UI integrates as a drop-in widget for dApps. Supports Sei mainnet.

```ts
import { Bridge } from "@thirdweb-dev/react";

<Bridge
  client={thirdwebClient}
  chains={["sei", "ethereum", "arbitrum"]}
  defaultChain="sei"
/>
```

See https://docs.sei.io/evm/bridging/thirdweb.

## Native USDC via CCTP

Circle's Cross-Chain Transfer Protocol (CCTP) is the canonical way to move **native USDC** between supported chains, including Sei (verify support status at https://www.circle.com/cross-chain-transfer-protocol). CCTP burns USDC on the source chain and mints fresh USDC on Sei — no synthetic, no wrapped IOU.

```ts
// Burn USDC on source chain (e.g., Ethereum)
await sourceUsdc.write.approve([CCTP_TOKEN_MESSENGER, amount]);
await ethCctp.write.depositForBurn([
  amount,
  SEI_DOMAIN_ID,
  addressToBytes32(seiRecipient),
  USDC_ETH_ADDRESS,
]);

// Wait for Circle attestation, then mint on Sei
await seiCctp.write.receiveMessage([message, attestation]);
```

CCTP attestation is off-chain (Circle's API); typical end-to-end time is 15-30 minutes due to attestation finalization on the source chain (independent of Sei's 400ms finality).

## Bridging from EVM-side Sei to Cosmos-side Sei (cross-VM)

This is **not a bridge** but rather an in-chain pointer/association mechanism. See [pointers/overview.md](../pointers/overview.md) for ERC20↔CW20 routing within Sei itself.

## Comparison: time to finality

| Bridge | Source → Sei time | Notes |
|---|---|---|
| LayerZero V2 | ~2-5 min | Depends on DVN config + source-chain finality |
| Wormhole | ~10-15 min | Guardian set attestation + source finality |
| Axelar | ~5-15 min | Validator set attestation |
| CCTP (native USDC) | ~15-30 min | Source-chain finality is the bottleneck |
| IBC | ~30-60s | Cosmos-to-Cosmos only |

Sei's instant finality on the **destination side** is fast; the bottleneck for cross-chain transfers is always the source chain's finality.

## Bridge security risks

- **DVN/oracle compromise** (LayerZero) — review the DVN set the bridge uses.
- **Guardian set compromise** (Wormhole) — historically targeted; check current guardian status.
- **Validator set compromise** (Axelar) — Axelar is a separate L1 with its own validator economic security.
- **Smart-contract risk** — every bridge has a contract that holds locked or burnable assets. Audit history matters.

For high-value transfers, prefer:
1. CCTP for USDC (fewest trust assumptions).
2. Native LayerZero V2 OFT if you control both ends of the token.
3. Multiple-bridge redundancy for arbitrarily large value.

## Sei-specific notes

- **All EVM bridges accept `0x...` addresses on the Sei side.** Don't pass `sei1...` addresses to LayerZero/Wormhole/Axelar — they expect EVM format.
- **For IBC, use the user's `sei1...` address.** If the user only knows their `0x...`, derive the Cosmos-side via [addresses-wallets.md](../addresses-wallets.md).
- **Pointer contracts** let bridged assets exist as both ERC20 (for EVM dApps) and CW20/native denom (for Cosmos modules). See [pointers/overview.md](../pointers/overview.md).
- **Min gas price 50 gwei** applies to bridge claim/redemption transactions on Sei — under-priced redemptions just sit in mempool.
