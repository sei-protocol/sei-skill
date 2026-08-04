---
title: Bridges to/from Sei
description: Bridges on Sei — LayerZero V2 (OFT) and Circle CCTP v2 (native USDC) are the documented EVM bridges, plus the official Sei bridge UI. Wormhole is verify-first (not Sei-documented); IBC is closed in both directions.
---

# Bridges to/from Sei

How users and contracts move assets and messages between Sei and other chains. The EVM bridges **Sei documents and recommends** are **LayerZero V2** (Sei is a full LayerZero V2 endpoint) and **Circle CCTP v2** (native USDC); the official UI is the **Sei bridge dashboard** / Thirdweb. Wormhole is supported at the protocol level but is **not documented by Sei** and its Sei CosmWasm side is closed — see the caveat below. Pick the bridge by the asset, not by habit.

> **IBC is closed on Sei in both directions.** Inbound was disabled by pacific-1 [Proposal 116](https://www.mintscan.io/sei/proposals/116) (atlantic-2 testnet **#247**); outbound was disabled by [Proposal 121](https://seistream.app/proposals/121) on 2026-07-31. Assets can neither arrive on Sei nor leave it via IBC. Existing `ibc/...` balances remain usable *within* Sei. Use an EVM bridge for all transfers. See [ibc-bridging.md](ibc-bridging.md).

> **Always verify bridge contract addresses, endpoint IDs, and CCTP domain IDs** against each bridge's official docs and on [Seiscan](https://seiscan.io) before sending real value. Bridges are high-value targets and addresses change across version upgrades — never hardcode them from memory.

## Which bridge? (decision matrix)

| You have / want | Use | Mechanism | Why |
|---|---|---|---|
| A **new token** native on Sei + other chains | **LayerZero V2 OFT** | burn-and-mint, unified supply | You control both ends; no wrapped IOU, one canonical supply |
| **Native USDC** moved onto/off Sei | **Circle CCTP v2** | burn-and-mint native USDC | Canonical USDC, fewest trust assumptions, no synthetic |
| An **existing asset** only Wormhole covers (some Solana-native tokens) | **Wormhole** (WTT/NTT) — *verify first* | wrapped / native-token transfer | Supported per Wormhole's network list, but **not documented by Sei**; confirm current support and prefer LayerZero V2 / CCTP where they cover the asset |
| **Arbitrary cross-chain messages** / calls + transfers | **LayerZero** (OApp) | GMP messaging | Generalized message passing via Sei's LayerZero V2 endpoint |
| **End users** bridging in a UI, no integration | **Sei bridge dashboard** / Thirdweb | aggregated routing | Drop-in UX, no contract work |
| Assets moving **to or from a Cosmos chain via IBC** | **Not available — either direction** | — | Inbound disabled (Prop 116 / #247), outbound disabled (Prop 121). No EVM alternative reaches Cosmos chains; there is no route. |

## LayerZero V2

Live on Sei mainnet and testnet — Sei is fully integrated as a LayerZero V2 endpoint.

> Sei LayerZero **Endpoint IDs (EIDs): mainnet `30280`, testnet `40455`.** Read the EndpointV2 address and all protocol contracts from https://docs.layerzero.network/v2/deployments/deployed-contracts?chains=sei — do not hardcode them from memory.

### OFT (Omnichain Fungible Token) pattern

A token that exists natively on Sei + other chains, with cross-chain sends that burn on the source and mint on the destination. Scaffold with `npx create-lz-oapp@latest` (choose the OFT example), deploy the same contract on each chain pointing at that chain's endpoint, then wire the peers.

```solidity
// MyOFT.sol — same contract deploys on Sei and every other chain.
pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";

contract MyOFT is OFT {
    // `endpoint` is the LayerZero EndpointV2 address for the chain you deploy on
    // (Sei mainnet EID 30280 / testnet EID 40455) — read it from the deployments page.
    constructor(string memory name, string memory symbol, address endpoint, address owner)
        OFT(name, symbol, endpoint, owner) Ownable(owner) {}
}
```

Wire peers, quote the fee, then send (the cross-chain fee is paid in native gas and must be quoted first):

```ts
import { Options, addressToBytes32 } from "@layerzerolabs/lz-v2-utilities";
import { parseUnits } from "ethers";

// Tell Sei's OFT about the peer on the other chain (and vice versa on that chain).
await seiOft.setPeer(DST_EID, addressToBytes32(remoteOftAddress));

const options = Options.newOptions().addExecutorLzReceiveOption(80_000n, 0n).toHex();
const sendParam = {
  dstEid: DST_EID,
  to: addressToBytes32(recipient0x),   // 0x recipient on the destination chain
  amountLD: parseUnits("100", 18),
  minAmountLD: parseUnits("99", 18),   // slippage floor
  extraOptions: options,
  composeMsg: "0x",
  oftCmd: "0x",
};

const { nativeFee } = await seiOft.quoteSend(sendParam, false); // quote BEFORE sending
const tx = await seiOft.send(sendParam, { nativeFee, lzTokenFee: 0n }, refund0x, { value: nativeFee });
await tx.wait(1); // one confirmation — Sei finalizes fast
```

For an *already-deployed* ERC-20 you can't reissue, use an **OFT Adapter** (locks the existing token instead of minting) rather than `OFT`. Full walkthrough, EIDs, and deployed contracts: https://docs.sei.io/evm/bridging/layerzero and https://docs.layerzero.network/v2/concepts/intro.

## Wormhole (verify first — not documented by Sei)

Wormhole's [supported-networks list](https://wormhole.com/docs/products/reference/supported-networks/) shows a **SeiEVM** entry (chain id 1329) with NTT, WTT (wrapped token transfers), and CCTP routing on mainnet. **But Sei's own docs provide no Wormhole EVM integration guide — the documented, recommended EVM bridges are LayerZero V2 and Circle CCTP.** Treat Wormhole as verify-first:

- **The Wormhole *CosmWasm* side on Sei is closed.** Wrapped assets that arrived on the Cosmos side (e.g. `USDCso`, Wormhole-bridged `WETH`, `USDCet`) are still held in the bank module and still move within Sei. These are **not** IBC vouchers and were **not** affected by the IBC proposals (#116/#120/#121) — but the legacy [Portal Bridge](https://legacy.portalbridge.com) is no longer available as a route off Sei, so there is no exit path for them either. See https://docs.sei.io/learn/sip-03-migration. Do not route transfers through it in either direction.
- **For your own multichain token,** Wormhole **NTT** is the analogue of LayerZero's OFT; **WTT** is the lock/mint wrapped path. If you specifically need Wormhole (coverage LayerZero/CCTP lack), **verify the current SeiEVM contract addresses and the exact SDK chain handle** on https://wormhole.com/docs/products/reference/supported-networks/ before integrating — do not assume them from memory.

When LayerZero V2 (OFT / messaging) or CCTP (USDC) cover your case, prefer them: they have first-class Sei documentation and deployed-contract tables.

## Native USDC via Circle CCTP v2

CCTP moves *native* USDC (no wrapper): burn on the source chain, Circle attests off-chain, mint on Sei. **USDC is 6 decimals on Sei** — convert with `parseUnits(value, 6)`. The recipient is passed as a 32-byte value (`mintRecipient` is the `0x...` Sei address left-padded to bytes32).

```ts
import { parseUnits, pad } from "viem";

// 1) Approve + burn on the SOURCE chain. SEI_DOMAIN comes from Circle's CCTP
//    supported-chains/domain table — verify, do not hardcode.
const amount = parseUnits("100", 6); // 100 USDC, 6 decimals
await sourceUsdc.write.approve([TOKEN_MESSENGER, amount]);
await sourceTokenMessenger.write.depositForBurn([
  amount,
  SEI_DOMAIN,                            // Circle domain id for Sei
  pad(seiRecipient0x, { size: 32 }),     // mintRecipient as bytes32
  sourceUsdcAddress,
]);

// 2) Poll Circle's attestation API, then mint on Sei.
const tx = await seiMessageTransmitter.write.receiveMessage([message, attestation]);
await tx.wait(1); // mint confirms in ~one Sei block
```

End-to-end time is dominated by **source-chain** finality + Circle's attestation (often 15+ min), independent of Sei's sub-second finality. Get testnet USDC from the [Circle Faucet](https://faucet.circle.com). Addresses/domains: https://developers.circle.com/cctp. USDC on Sei: https://docs.sei.io/evm/usdc-on-sei.

## End-user bridging UI

For users (not contract integrations), point them at the official **[Sei bridge dashboard](https://dashboard.sei.io/bridge)** — it aggregates routes onto Sei. To embed bridging in your own dApp, use Thirdweb Payments (onramp/swap/bridge widget): https://docs.sei.io/evm/bridging/thirdweb. The dashboard's transfer tool also handles native↔EVM asset movement during SIP-3 migration: https://dashboard.sei.io/evm-upgrade.

## Comparison: time to finality

| Bridge | Source → Sei time | Notes |
|---|---|---|
| LayerZero V2 | ~2-5 min | Depends on DVN config + source-chain finality |
| Wormhole | ~10-15 min | Guardian set attestation + source finality |
| CCTP (native USDC) | ~15-30 min | Source-chain finality is the bottleneck |

Sei's instant finality on the **destination side** is fast; the bottleneck for cross-chain transfers is always the source chain's finality + the bridge's attestation.

## Bridge security risks

- **DVN/oracle set** (LayerZero) — review the DVN set the pathway uses; if `quoteSend` reverts, the pathway/DVNs aren't wired.
- **Guardian set** (Wormhole) — historically targeted; check current guardian status.
- **Smart-contract risk** — every bridge holds locked or burnable value. Audit history matters.

For high-value transfers, prefer:
1. **CCTP** for USDC (fewest trust assumptions).
2. A self-controlled **LayerZero V2 OFT** if you control both ends of the token.

## Sei-specific notes

- **EVM bridges accept `0x...` addresses on the Sei side.** Don't pass `sei1...` addresses to LayerZero / CCTP — they expect EVM format. (Wormhole lists Sei twice — a CosmWasm `Sei` side and an EVM `SeiEVM` side; if you use it, confirm the exact SDK handle on Wormhole's docs.)
- **Use legacy `gasPrice` for Sei-side claim/redeem/mint transactions.** Sei has no EIP-1559 base-fee burn — set a single `gasPrice`, not `maxFeePerGas`/`maxPriorityFeePerGas`. The minimum gas price is governance-adjustable (currently ~50 gwei on mainnet — query `eth_gasPrice` for the live floor); an under-priced redemption just sits in the mempool. See https://docs.sei.io/evm/differences-with-ethereum.
- **IBC is closed in both directions.** Don't route assets onto Sei via IBC, and don't tell holders of legacy `ibc/...` assets to bridge, migrate, or exit — there is no route off the chain. Their balances are intact and still transfer within Sei, including through ERC-20 pointers. See [ibc-bridging.md](ibc-bridging.md).
- **CosmWasm is deprecated for new development (SIP-3).** Deploy ERC-20 / OFT contracts directly. Pointer contracts remain useful for cross-VM access to existing denoms; the IBC precompile does not — its `transfer` cannot succeed with outbound IBC disabled.
- **Verify every contract address, EID, and CCTP domain ID** against the bridge's official docs and on Seiscan before deploying.
