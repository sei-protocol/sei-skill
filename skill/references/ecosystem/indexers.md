---
title: Indexers on Sei
description: The Graph, Goldsky, Dune Analytics, Moralis, and Goldrush indexing solutions for Sei EVM — setup, capabilities, and usage patterns.
---

# Indexers on Sei

## Why Use an Indexer?

Sei's high throughput means direct RPC queries for historical event data can be slow or unreliable. Indexers provide:

- Fast historical event queries (no full-node RPC pagination)
- Aggregated analytics (DEX volume, user stats)
- Real-time webhooks/subscriptions
- Complex filtering and joins across contract state

## Summary

| Provider | Type | Best for |
|---|---|---|
| **The Graph** | Subgraph (GraphQL) | Complex custom queries, decentralized |
| **Goldsky** | Real-time pipelines | Webhooks, mirror pipelines, fast setup |
| **Dune Analytics** | SQL analytics | Research, dashboards, analytics |
| **Moralis** | Multi-chain API | NFT data, token transfers, wallets |
| **Goldrush (Covalent)** | Unified API | Quick integration, multi-chain |

---

## The Graph

The Graph lets you deploy custom "subgraphs" that index your contract events and expose them via GraphQL.

### Create a Subgraph

```bash
npm install -g @graphprotocol/graph-cli
graph init --product hosted-service myorg/my-sei-subgraph
# Select network: sei-mainnet or sei-testnet
```

### Define Schema

```graphql
# schema.graphql
type Transfer @entity {
  id: ID!
  from: Bytes!
  to: Bytes!
  amount: BigInt!
  blockNumber: BigInt!
  timestamp: BigInt!
}
```

### Define Mappings

```typescript
// src/mapping.ts
import { Transfer as TransferEvent } from '../generated/MyToken/MyToken';
import { Transfer } from '../generated/schema';

export function handleTransfer(event: TransferEvent): void {
  const transfer = new Transfer(
    event.transaction.hash.toHex() + '-' + event.logIndex.toString()
  );
  transfer.from = event.params.from;
  transfer.to = event.params.to;
  transfer.amount = event.params.value;
  transfer.blockNumber = event.block.number;
  transfer.timestamp = event.block.timestamp;
  transfer.save();
}
```

### Define Manifest

```yaml
# subgraph.yaml
specVersion: 0.0.5
schema:
  file: ./schema.graphql
dataSources:
  - kind: ethereum
    name: MyToken
    network: sei-mainnet  # or sei-testnet
    source:
      address: "0xYourContractAddress"
      abi: MyToken
      startBlock: 100000000
    mapping:
      kind: ethereum/events
      apiVersion: 0.0.7
      language: wasm/assemblyscript
      entities:
        - Transfer
      abis:
        - name: MyToken
          file: ./abis/MyToken.json
      eventHandlers:
        - event: Transfer(indexed address,indexed address,uint256)
          handler: handleTransfer
      file: ./src/mapping.ts
```

### Deploy and Query

```bash
graph deploy --product hosted-service myorg/my-sei-subgraph
```

```graphql
# Query example
{
  transfers(
    first: 10
    orderBy: timestamp
    orderDirection: desc
    where: { from: "0x1234..." }
  ) {
    id
    from
    to
    amount
    timestamp
  }
}
```

---

## Goldsky

Goldsky specializes in real-time indexing with webhook delivery and managed subgraph hosting.

### Instant Mirror (No Code Required)

```bash
npm install -g @goldsky/cli
goldsky login

# Mirror all ERC20 Transfer events from a contract to a database
goldsky mirror create my-transfers \
  --source-name mytoken-transfers \
  --source-type log \
  --source-chain sei \
  --source-address 0xYourToken \
  --source-event Transfer(address,address,uint256) \
  --destination-type webhook \
  --destination-webhook-url https://my-backend.com/webhook
```

### Subgraph Hosting

```bash
# Deploy a subgraph to Goldsky (same format as The Graph)
goldsky subgraph deploy my-subgraph/1.0.0 --path ./subgraph.yaml
```

---

## Dune Analytics

Dune provides SQL-based blockchain analytics with a Sei dataset.

### Sei Dataset

Query Sei data in Dune SQL:

```sql
-- Top ERC20 transfers in the last 24 hours
SELECT
  contract_address,
  from_address,
  to_address,
  value / 1e18 as amount,
  block_time
FROM sei.erc20_evt_transfer
WHERE block_time > NOW() - INTERVAL '24 hours'
ORDER BY value DESC
LIMIT 100
```

```sql
-- Contract interactions by address
SELECT
  "to" as contract,
  COUNT(*) as tx_count,
  SUM(gas_used) as total_gas
FROM sei.transactions
WHERE block_time > NOW() - INTERVAL '7 days'
  AND "from" = LOWER('0xYourAddress')
GROUP BY "to"
ORDER BY tx_count DESC
```

Access Dune at: https://dune.com — create a free account and browse the Sei dataset.

---

## Moralis

Moralis provides a multi-chain API covering NFT data, token transfers, and wallet history.

### Setup

```bash
npm install moralis
```

```typescript
import Moralis from 'moralis';

await Moralis.start({ apiKey: process.env.MORALIS_API_KEY });

// Get ERC20 token transfers for an address
const transfers = await Moralis.EvmApi.token.getWalletTokenTransfers({
  address: "0x1234...",
  chain: "0x521", // Sei mainnet (0x521 = 1329 decimal)
});

// Get NFT holdings
const nfts = await Moralis.EvmApi.nft.getWalletNFTs({
  address: "0x1234...",
  chain: "0x521",
});
```

Sei chain IDs for Moralis:
- Mainnet: `0x521` (1329)
- Testnet: `0x520` (1328)

---

## Goldrush (Covalent)

Goldrush provides a unified multi-chain API for quick integrations.

### Setup

```bash
npm install @covalenthq/client-sdk
```

```typescript
import { CovalentClient } from "@covalenthq/client-sdk";

const client = new CovalentClient(process.env.COVALENT_API_KEY!);

// Get all token balances for an address on Sei
const balances = await client.BalanceService.getTokenBalancesForWalletAddress(
  "sei-mainnet",  // chain name
  "0x1234..."     // wallet address
);

// Get ERC20 transfer history
const transfers = await client.TransactionsService.getAllTransactionsForAddress(
  "sei-mainnet",
  "0x1234..."
);
```

---

## Event Design for Indexers

Well-designed events make indexing significantly easier:

```solidity
// Good: all relevant data in one event, indexed fields for filtering
event PositionOpened(
    address indexed trader,    // indexed = filterable
    uint256 indexed positionId,
    address indexed token,
    uint256 amount,
    uint256 price,
    uint256 timestamp
);

// Good: include computed values in events so indexers don't need to re-derive
event LiquidityAdded(
    address indexed provider,
    uint256 token0Amount,
    uint256 token1Amount,
    uint256 lpTokensMinted,
    uint256 totalLiquidity  // total after this addition
);

// Bad: insufficient data forces indexers to call contract state
event Trade(address user, uint256 amount); // missing token, price, direction
```

**Up to 3 parameters can be indexed** — use indexed for fields you'll filter on (address, id, status). Include computed aggregates as non-indexed fields to reduce indexer complexity.
