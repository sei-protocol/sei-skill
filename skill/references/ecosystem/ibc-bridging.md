---
title: IBC on Sei (closed — both directions)
description: Inter-Blockchain Communication (IBC) is disabled on Sei in both directions. Inbound was disabled under SIP-3; outbound was disabled by Proposal 121. Legacy ibc/... balances still exist and still move within Sei, but there is no route on or off the chain via IBC. For bridging use the EVM bridges in bridges.md.
---

# IBC on Sei (closed — both directions)

> **IBC is closed on Sei. Do not present it as a way to move assets on or off the chain, in either direction.**
>
> - **Inbound** is disabled — pacific-1 [Proposal 116](https://www.mintscan.io/sei/proposals/116) (with [Proposal 120](https://www.mintscan.io/sei/proposals/120)) set the `ibc` module's `InboundEnabled` to `false`. The atlantic-2 testnet equivalent is **#247** (Disable IBC Inbound).
> - **Outbound** is disabled — [Proposal 121](https://seistream.app/proposals/121) ("Disable IBC Outbound") passed 2026-07-31 and set `OutboundEnabled` to `false`.
>
> Related: [Proposal 115](https://www.mintscan.io/sei/proposals/115) froze new CosmWasm uploads (atlantic-2 **#246**).
>
> **For any bridging, use the EVM bridges — LayerZero V2, Circle CCTP for native USDC, or Wormhole (verify first).** See [bridges.md](bridges.md).

## Current parameter state

Both governing parameters are `false` on mainnet:

```
cosmos/params/v1beta1/params?subspace=ibc&key=InboundEnabled  -> "false"
cosmos/params/v1beta1/params?subspace=ibc&key=OutboundEnabled -> "false"
```

Query them directly rather than trusting a proposal page, since a later proposal could change either one:

```bash
seid q params subspace ibc InboundEnabled  --node https://rpc.sei-apis.com
seid q params subspace ibc OutboundEnabled --node https://rpc.sei-apis.com
```

## What this means for existing balances

**Legacy `ibc/...` assets are not gone, and they are not frozen.** They remain in the bank module and behave like any other native denom *inside* Sei:

- They still appear in `seid q bank balances <sei1...>`.
- They still transfer between Sei accounts.
- They still work through their ERC-20 pointer contracts, so EVM contracts can still read and move them.
- They can still be swapped on a Sei DEX, subject to that DEX having liquidity for the pair.

What is closed is the **redemption path**: there is no way to send an `ibc/...` asset back to its origin chain, and no way for a new one to arrive.

Resolving what a denom represents still works — that is a local query, not a transfer:

```bash
seid q ibc-transfer denom-trace <IBC_HASH> --node https://rpc.sei-apis.com
```

## What is no longer possible

- Sending assets **out** of Sei over IBC. `seid tx ibc-transfer transfer` fails — the module rejects outbound transfers regardless of channel, recipient, or amount.
- Receiving assets **into** Sei over IBC from any Cosmos chain.
- The exit and migration routes Sei previously documented for legacy holders. Noble/CCTP for `USDC.n` and Skip:Go for ATOM and WBTC all depended on outbound IBC and no longer function.
- Opening or recovering IBC channels and light clients for asset-transfer purposes.

Anything phrased as "migrate your IBC assets before the proposal activates" is **out of date** — that window closed with Proposal 121.

## IBC precompile (`0x…1009`) — do not use

The IBC precompile at `0x0000000000000000000000000000000000001009` exposed IBC transfers to the EVM. **Its `transfer` function cannot succeed now that outbound IBC is disabled.** Do not include it in new contracts and do not present it as a bridging option; existing contracts that call it will revert on that path.

For cross-VM asset access that *does* still work — moving native SEI, factory tokens, and existing `ibc/...` denoms between the EVM and Cosmos layers within Sei — see the Bank and Pointer precompiles in [../precompiles/cosmwasm-bridge.md](../precompiles/cosmwasm-bridge.md).

## For new bridging → use the EVM bridges

| Need | Use |
|---|---|
| Omnichain token across EVM chains | **LayerZero V2 OFT** |
| Native USDC | **Circle CCTP v2** |
| Coverage LayerZero/CCTP lack | **Wormhole NTT/WTT** — verify first, not documented by Sei |
| End-user bridging UI | [Sei bridge dashboard](https://dashboard.sei.io/bridge) or the [Thirdweb widget](https://docs.sei.io/evm/bridging/thirdweb) |

Addresses, EIDs and the full comparison are in [bridges.md](bridges.md).

## Checklist

- [ ] Do **not** plan any IBC transfer, inbound or outbound. Use an EVM bridge.
- [ ] Do **not** tell a holder to bridge, migrate, or exit `ibc/...` assets — there is no route.
- [ ] Do tell them their balances are intact and still usable within Sei.
- [ ] Do **not** call the IBC precompile (`0x…1009`) in new contracts.
- [ ] Verify any bridge is audited and has significant TVL before integrating.
- [ ] Test the full round trip on testnet (atlantic-2) first.
- [ ] For LayerZero: deploy + wire your OFT on both chains before launch; quote the native fee with `quoteSend`.
- [ ] Use legacy `gasPrice` for Sei-side claim/redeem transactions (no EIP-1559 base-fee burn).

## Historical context

IBC operated on the **Cosmos side** of Sei using `sei1...` addresses, with assets arriving as `ibc/<hash>` denoms relayed packet-by-packet by third-party relayers. Sei is EVM-first as of SIP-3, and the chain no longer participates in IBC in either direction. Running an IBC relayer for Sei is therefore no longer a viable role — see [participation-roles.md](participation-roles.md).
