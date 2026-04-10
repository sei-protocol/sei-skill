---
title: Oracles on Sei
description: Chainlink, Pyth Network, API3, and RedStone oracle integrations on Sei EVM — when to use each, setup, and code examples. Plus Pyth VRF for on-chain randomness.
---

# Oracles on Sei

## When to Use Which Oracle

| Oracle | Best for | Model |
|---|---|---|
| **Chainlink** | Battle-tested price feeds, production DeFi | Push (on-chain, always fresh) |
| **Pyth Network** | Sub-second latency, NFTs, perps, high-frequency | Pull (user pushes update per tx) |
| **API3** | First-party data, operational simplicity | Push (dAPI proxies) |
| **RedStone** | On-demand, modular, custom feeds | Pull (wrap tx with price data) |
| **Native Oracle** | Simple on-chain access to Sei's oracle module | Precompile (always available) |

> **NEVER use `block.prevrandao` or `block.timestamp` for randomness** — use Pyth VRF or Chainlink VRF instead.

---

## Native Oracle Precompile

**Address:** `0x0000000000000000000000000000000000001008`

Sei has a built-in oracle module. Price data is submitted by validators each epoch.

```solidity
pragma solidity ^0.8.28;

interface IOracle {
    struct OracleData {
        int64 price;    // price in micro-USD (divide by 1e6 to get USD)
        uint64 denom;
        uint64 timestamp;
    }

    function getExchangeRates() external view returns (OracleData[] memory);
    function getOracleTwaps(uint64 lookbackSeconds) external view returns (OracleData[] memory);
}

contract PriceFeed {
    address constant ORACLE = 0x0000000000000000000000000000000000001008;

    function getSeiPrice() external view returns (int64) {
        IOracle.OracleData[] memory rates = IOracle(ORACLE).getExchangeRates();
        for (uint i = 0; i < rates.length; i++) {
            // Find SEI/USD rate
            return rates[i].price; // micro-USD
        }
        revert("SEI rate not found");
    }
}
```

---

## Chainlink Price Feeds

Chainlink provides battle-tested push oracles. Data is submitted on-chain by Chainlink nodes and always fresh.

### Setup

```bash
npm install @chainlink/contracts
```

### Usage

```solidity
pragma solidity ^0.8.28;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract ChainlinkConsumer {
    AggregatorV3Interface public priceFeed;

    // Constructor with Sei testnet Chainlink feed address
    constructor(address feedAddress) {
        priceFeed = AggregatorV3Interface(feedAddress);
    }

    function getLatestPrice() external view returns (int) {
        (
            uint80 roundId,
            int answer,
            uint startedAt,
            uint updatedAt,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();

        // Validate freshness
        require(updatedAt > block.timestamp - 3600, "Price data stale");
        require(answer > 0, "Invalid price");

        return answer; // decimals() tells you the precision
    }

    function decimals() external view returns (uint8) {
        return priceFeed.decimals(); // typically 8
    }
}
```

Find Chainlink feed addresses for Sei at: https://docs.chain.link/data-feeds/price-feeds/addresses

---

## Pyth Network

Pyth uses a **pull model** — the dApp user pushes a signed price update into the transaction before using it. This enables sub-second latency and more frequent updates.

### Setup

```bash
npm install @pythnetwork/pyth-evm-js @pythnetwork/price-service-client
```

### Frontend: Fetch and Push Price Update

```typescript
import { PriceServiceConnection } from '@pythnetwork/price-service-client';
import { EvmPriceServiceConnection } from '@pythnetwork/pyth-evm-js';
import { ethers } from 'ethers';

const SEI_USD_PRICE_ID = "0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace";

async function updatePriceAndCall(contract, method, args) {
  const priceService = new EvmPriceServiceConnection(
    "https://hermes.pyth.network"
  );

  // Get the latest price update VAA
  const updateData = await priceService.getPriceFeedsUpdateData([SEI_USD_PRICE_ID]);

  // Get update fee
  const pythContract = new ethers.Contract(PYTH_ADDRESS_ON_SEI, pythAbi, signer);
  const updateFee = await pythContract.getUpdateFee(updateData);

  // Push price update + call your contract in the same tx
  const tx = await pythContract.updatePriceFeeds(updateData, { value: updateFee });
  await tx.wait(1);

  // Now call your contract
  await contract[method](...args);
}
```

### Contract: Consume Pyth Price

```solidity
pragma solidity ^0.8.28;

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

contract PythConsumer {
    IPyth pyth;
    bytes32 constant SEI_USD_PRICE_ID =
        0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;

    constructor(address pythAddress) {
        pyth = IPyth(pythAddress);
    }

    function getCurrentPrice() external view returns (int64 price, uint32 conf, int32 expo) {
        PythStructs.Price memory current = pyth.getPrice(SEI_USD_PRICE_ID);
        return (current.price, current.conf, current.expo);
    }

    // In a DeFi function: require fresh price
    function trade(uint256 amount) external {
        PythStructs.Price memory price = pyth.getPriceNoOlderThan(
            SEI_USD_PRICE_ID,
            60  // max 60 seconds old
        );
        // Use price.price / 10^(-price.expo) as USD price
        // ...
    }
}
```

## Pyth VRF (Verifiable Randomness)

For on-chain randomness — use Pyth VRF instead of `block.prevrandao`.

```solidity
pragma solidity ^0.8.28;

interface IPythRandomness {
    function requestWithCallback(
        address provider,
        bool useBlockHash
    ) external payable returns (uint64 sequenceNumber);
}

contract PythVRFConsumer {
    IPythRandomness constant PYTH = IPythRandomness(PYTH_ENTROPY_ADDRESS);
    address constant ENTROPY_PROVIDER = 0x52DeaA1c84233F7bb8C8A45baeDE41091c616506;

    function requestRandom() external payable {
        PYTH.requestWithCallback{value: msg.value}(ENTROPY_PROVIDER, false);
    }

    // Called by Pyth when randomness is ready
    function entropyCallback(
        uint64 sequenceNumber,
        address provider,
        bytes32 randomNumber
    ) external {
        // Use randomNumber as your random value
        uint256 result = uint256(randomNumber) % 100; // 0-99
    }
}
```

---

## API3

API3 provides "dAPIs" — decentralized APIs that push first-party data on-chain.

```solidity
pragma solidity ^0.8.28;

interface IProxy {
    function read() external view returns (int224 value, uint32 timestamp);
}

contract API3Consumer {
    address public proxy; // dAPI proxy address

    constructor(address _proxy) {
        proxy = _proxy;
    }

    function readPrice() external view returns (int224, uint32) {
        return IProxy(proxy).read();
        // value: price with 18 decimals
        // timestamp: last update timestamp
    }
}
```

Find dAPI proxy addresses for Sei at: https://market.api3.org

---

## RedStone

RedStone uses a pull model where price data is bundled into the transaction calldata.

```bash
npm install @redstone-finance/evm-connector
```

```solidity
pragma solidity ^0.8.28;

import "@redstone-finance/evm-connector/contracts/data-services/MainDemoConsumerBase.sol";

contract RedStoneConsumer is MainDemoConsumerBase {
    function getPriceFromPayload() public view returns (uint256) {
        return getOracleNumericValueFromTxMsg(bytes32("SEI"));
    }
}
```

```typescript
import { WrapperBuilder } from "@redstone-finance/evm-connector";

// Wrap your contract calls to include price data
const wrappedContract = WrapperBuilder
  .wrapLite(yourContract)
  .usingSimpleNumericMock({ mockSignersCount: 10, dataPoints: [{ dataFeedId: "SEI", value: 0.5 }] });

await wrappedContract.getPriceFromPayload();
```

---

## Oracle Comparison for Sei

| Feature | Native | Chainlink | Pyth | API3 | RedStone |
|---|---|---|---|---|---|
| Update frequency | Per epoch | Per heartbeat | On demand | Per heartbeat | Per tx |
| Staleness risk | Low | Low | User-controlled | Low | None (per tx) |
| Randomness (VRF) | No | Yes | Yes | No | No |
| Gas cost | Very low (precompile) | Low (view) | Medium (push fee) | Low (view) | Low (calldata) |
| Setup complexity | None | Low | Medium | Low | Medium |
