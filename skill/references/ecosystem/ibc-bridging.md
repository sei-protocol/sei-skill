---
title: IBC on Sei (legacy / exit-only)
description: Inter-Blockchain Communication (IBC) on Sei is legacy — inbound IBC is disabled under SIP-3. This covers IBC mechanics for exiting legacy ibc/... assets. For new bridging use the EVM bridges in bridges.md.
---

# IBC on Sei (legacy / exit-only)

> **Inbound IBC is disabled under SIP-3.** On mainnet, pacific-1 [Proposal 116](https://www.mintscan.io/sei/proposals/116) disables inbound IBC transfers and [Proposal 115](https://www.mintscan.io/sei/proposals/115) freezes new CosmWasm; the atlantic-2 testnet equivalents are **#247** (Disable IBC Inbound) and **#246** (Disable CosmWasm Uploads). IBC assets from Cosmos chains can **no longer arrive** on Sei. Do **not** present IBC as a way to bring assets onto Sei.
>
> **For new inbound/outbound bridging, use the EVM bridges — LayerZero V2, Wormhole, or Circle CCTP for native USDC.** See [bridges.md](bridges.md). This file is retained for the one IBC action that still matters: **exiting** legacy `ibc/...` assets.

## Why IBC is legacy on Sei

Sei is EVM-first as of SIP-3. IBC operated on the **Cosmos side** of Sei using `sei1...` addresses. With inbound IBC disabled, the only relevant flow is *exiting*: holders of legacy `ibc/...` assets (e.g. USDC.n bridged via Noble) must move them off the Cosmos side — swap to native USDC (bridge out via CCTP) or transfer out — before the upgrade fully activates. Migration routes and the affected-asset table are in https://docs.sei.io/learn/sip-03-migration.

## IBC mechanics (for exit / historical context)

An IBC transfer is relayed packet-by-packet; assets arrive as `ibc/<hash>` denoms. To send a Cosmos-side asset **out** of Sei to another Cosmos chain:

```bash
# Transfer tokens from Sei to another Cosmos chain (exit flow)
seid tx ibc-transfer transfer \
  transfer \                          # port
  channel-0 \                         # channel (e.g. Sei→Osmosis)
  <RECIPIENT_ADDRESS> \
  1000000usei \                       # amount + denom
  --from <YOUR_KEY> \
  --chain-id pacific-1 \
  --node https://rpc.sei-apis.com \
  --fees 20000usei \
  --timeout-timestamp $(date -d "+1 hour" +%s)000000000
```

Resolve what an `ibc/...` denom represents:

```bash
seid q ibc-transfer denom-trace <IBC_HASH> --node https://rpc.sei-apis.com
```

Check current channels at https://www.mintscan.io/sei/relayers.

## IBC precompile (legacy)

The IBC precompile (`0x0000000000000000000000000000000000001009`) exposed IBC transfers to the EVM for CosmWasm-adjacent workflows. It is **legacy** — CosmWasm is deprecated (SIP-3) and inbound IBC is disabled, so it is not a path for new builds. The interface is documented for completeness only:

```solidity
interface IIBC {
    function transfer(
        string memory toAddress, string memory port, string memory channel,
        string memory denom, uint256 amount,
        uint64 revisionNumber, uint64 revisionHeight, uint64 timeoutTimestamp,
        string memory memo
    ) external payable returns (uint64 sequence);
}
```

## New bridging → use the EVM bridges

For omnichain tokens, wrapped assets, native USDC, or cross-chain messaging, use the EVM bridges. The canonical, Sei-documented patterns are **LayerZero V2 OFT** and **Circle CCTP v2** — addresses/EIDs live in [bridges.md](bridges.md) and on https://docs.sei.io/evm/bridging/layerzero. (Wormhole supports SeiEVM per its own network list but is not documented by Sei — verify first; see [bridges.md](bridges.md).) End users can bridge through the official [Sei bridge dashboard](https://dashboard.sei.io/bridge) or an embedded Thirdweb widget (https://docs.sei.io/evm/bridging/thirdweb).

## Bridge checklist

- [ ] Do **not** plan inbound IBC — it is disabled (SIP-3). Use an EVM bridge.
- [ ] For legacy `ibc/...` holdings, plan the **exit** before SIP-3 fully activates (CCTP for USDC).
- [ ] Verify any bridge is audited and has significant TVL before integrating.
- [ ] Test the full round trip on testnet (atlantic-2) first.
- [ ] For LayerZero: deploy + wire your OFT on both chains before launch; quote the native fee with `quoteSend`.
- [ ] Use legacy `gasPrice` for Sei-side claim/redeem transactions (no EIP-1559 base-fee burn).
