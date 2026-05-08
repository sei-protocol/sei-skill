---
title: IBC and Bridging on Sei
description: Inter-Blockchain Communication (IBC), LayerZero omnichain bridging, and ThirdWeb bridge integration on Sei.
---

# IBC and Bridging on Sei

## Inter-Blockchain Communication (IBC)

IBC is the native cross-chain messaging protocol for Cosmos chains. Sei supports IBC for transferring assets between Cosmos ecosystem chains (Cosmos Hub, Osmosis, Noble, Axelar, etc.).

### How IBC Works

1. User initiates an IBC transfer on the source chain
2. A relayer picks up the packet and relays it to the destination chain
3. The destination chain mints/unlocks the asset
4. The asset is represented as an IBC denom: `ibc/<hash>/<original-denom>`

### IBC Transfer via seid CLI

```bash
# Transfer tokens from Sei to another Cosmos chain
seid tx ibc-transfer transfer \
  transfer \                          # port
  channel-0 \                         # channel (Sei→Osmosis, e.g.)
  <RECIPIENT_OSMOSIS_ADDRESS> \
  1000000usei \                       # amount + denom
  --from <YOUR_KEY> \
  --chain-id pacific-1 \
  --node https://rpc.sei-apis.com \
  --fees 20000usei \
  --timeout-height 0 \
  --timeout-timestamp $(date -d "+1 hour" +%s)000000000

# Transfer IBC tokens from another chain to Sei
# (Run from the source chain's node)
```

### Common IBC Channels (Sei Mainnet)

| Destination | Channel |
|---|---|
| Osmosis | channel-0 |
| Cosmos Hub | channel-1 |
| Noble (USDC) | channel-36 |
| Axelar | channel-19 |

> Check current channels at https://seiscan.io or https://www.mintscan.io/sei/relayers

### IBC Denoms

IBC assets arrive as `ibc/<hash>` denoms:

```bash
# Query what an IBC denom represents
seid q ibc-transfer denom-trace <IBC_HASH> \
  --node https://rpc.sei-apis.com

# Example: ibc/FE2CD1E6828EC0FA5F0... might be USDC from Noble
```

### IBC from EVM Contract

Use the IBC precompile (legacy, for CosmWasm-adjacent workflows):

```solidity
interface IIBC {
    function transfer(
        string memory toAddress,
        string memory port,
        string memory channel,
        string memory denom,
        uint256 amount,
        uint64 revisionNumber,
        uint64 revisionHeight,
        uint64 timeoutTimestamp,
        string memory memo
    ) external payable returns (uint64 sequence);
}

contract IBCSender {
    address constant IBC = 0x0000000000000000000000000000000000001009;

    function sendToOsmosis(string memory recipient, uint256 amount) external {
        uint64 timeout = uint64(block.timestamp + 3600) * 1_000_000_000; // 1 hour

        IIBC(IBC).transfer(
            recipient,       // osmo1...
            "transfer",      // port
            "channel-0",     // Sei→Osmosis channel
            "usei",          // denom
            amount,
            0,               // revision number
            0,               // revision height (use timeout timestamp instead)
            timeout,
            ""               // memo
        );
    }
}
```

---

## LayerZero

LayerZero is an omnichain messaging protocol that enables asset bridging between EVM chains (Ethereum, Arbitrum, Avalanche, etc.) and Sei.

### Omnichain Fungible Token (OFT) Standard

LayerZero's OFT standard lets ERC20 tokens bridge between chains with a burn-and-mint mechanism:

```solidity
pragma solidity ^0.8.28;

import "@layerzerolabs/solidity-examples/contracts/token/oft/OFT.sol";

// Deploy this on Sei — token burns here when bridging out, mints when bridging in
contract MySeiToken is OFT {
    constructor(
        string memory name,
        string memory symbol,
        address lzEndpoint  // LayerZero endpoint address for Sei
    ) OFT(name, symbol, lzEndpoint) {
        _mint(msg.sender, 1_000_000 * 10**18);
    }
}
```

### Initiating a Bridge Transfer

```typescript
import { ethers } from 'ethers';

// OFT contract on Sei
const oftContract = new ethers.Contract(OFT_ADDRESS_ON_SEI, OFT_ABI, signer);

// Bridge 100 tokens from Sei to Ethereum mainnet
const amount = ethers.parseEther("100");
const toChainId = 101; // LayerZero chain ID for Ethereum

// Estimate cross-chain fee
const [nativeFee, zroFee] = await oftContract.estimateSendFee(
  toChainId,
  ethers.zeroPadValue(recipientAddress, 32),
  amount,
  false,  // use ZRO token for fee? no
  "0x"    // adapter params
);

// Execute bridge
const tx = await oftContract.sendFrom(
  await signer.getAddress(),
  toChainId,
  ethers.zeroPadValue(recipientAddress, 32),
  amount,
  await signer.getAddress(),  // refund address
  ethers.ZeroAddress,          // ZRO payment address
  "0x",                        // adapter params
  { value: nativeFee }
);
await tx.wait(1); // instant finality on Sei
```

### LayerZero Endpoints on Sei

| Network | Endpoint Address | LayerZero Chain ID |
|---|---|---|
| Mainnet | (see LayerZero docs for current address) | 46 |
| Testnet | (see LayerZero docs for current address) | 10045 |

---

## ThirdWeb Bridge

ThirdWeb provides a bridge interface and React components for cross-chain transfers.

### ThirdWeb Universal Bridge

```typescript
import { Bridge, NATIVE_TOKEN_ADDRESS } from "thirdweb/bridge";
import { client } from "./client"; // your ThirdWeb client

// Get quote for bridging SEI from Sei to Ethereum
const quote = await Bridge.Buy.quote({
  client,
  originChainId: 1329,     // Sei mainnet
  originTokenAddress: NATIVE_TOKEN_ADDRESS,
  destinationChainId: 1,   // Ethereum mainnet
  destinationTokenAddress: NATIVE_TOKEN_ADDRESS,
  amount: parseEther("10"),
});

console.log("Bridge fee:", quote.fees);
console.log("Expected output:", quote.destinationAmount);
```

### ThirdWeb EIP-7702 + Bridge (Account Abstraction)

ThirdWeb supports EIP-7702 smart account upgrades on Sei, enabling gasless bridge transactions:

```typescript
import { inAppWallet } from "thirdweb/wallets";
import { bridgeTokens } from "thirdweb/bridge";

// Create an in-app wallet (social login)
const wallet = inAppWallet();
const account = await wallet.connect({ client, strategy: "google" });

// Execute bridge with EIP-7702 smart session
const bridgeTx = await bridgeTokens({
  client,
  account,
  originChain: sei,
  destinationChain: ethereum,
  amount: parseEther("5"),
});
```

---

## Bridge Checklist

Before integrating any bridge:

- [ ] Verify the bridge is audited and has significant TVL (do not build on unaudited bridges)
- [ ] Test the full round trip on testnet first
- [ ] Handle failed IBC transfers (packets can timeout — implement a re-claim flow)
- [ ] Communicate to users that IBC transfers take 1-30 seconds; LayerZero takes 1-5 minutes
- [ ] Display the IBC denom correctly on the receiving chain (`ibc/...` format)
- [ ] For LayerZero: ensure your OFT contract is deployed and configured on both chains before launch
