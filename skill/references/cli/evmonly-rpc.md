# EVM-only JSON-RPC surface

The EVM-only (Autobahn / giga) deployment exposes a deliberately minimal EVM
JSON-RPC surface. All other `eth_*` methods return JSON-RPC method-not-found.

## Supported methods


## WebSocket endpoint and `eth_subscribe("newHeads")`

The EVM-only JSON-RPC is served over **both** HTTP and WebSocket. The HTTP
listener binds `giga.execution.evm_rpc_port` (default 8545); the WebSocket
listener binds `giga.execution.evm_ws_port` (default 8546). Both must be in
`1..65535` and `evm_ws_port` must differ from `evm_rpc_port`, or the node
refuses to start.

- The WebSocket listener serves the **same** JSON-RPC methods as the HTTP
  listener, plus the WebSocket-only `eth_subscribe`/`eth_unsubscribe` flow.
- Upgrades are accepted from **any `Origin`** header (WebSocket is exempt from
  the browser same-origin policy), and concurrent WebSocket connections are
  bounded to **2000**.
- Plain (non-upgraded) HTTP requests to the WebSocket listener, and
  `eth_subscribe` over the HTTP listener, are rejected
  (`notifications not supported`).

`eth_subscribe("newHeads")` pushes **one Ethereum header per executed block**,
starting from the block after the subscription is created. Each header carries
the block's `number`, `hash`, `gasUsed`, `gasLimit`, `timestamp`, etc.

**Requires Autobahn execution.** On nodes that do not execute blocks through
Autobahn the subscription is unavailable and fails with
`newHeads subscriptions require Autobahn execution`.

### Subscribe to new heads via `cast`

```sh
cast subscribe \
  --rpc-url ws://127.0.0.1:8546 \
  newHeads
```

### Subscribe to new heads via JSON-RPC over WebSocket

```sh
wscat -c ws://127.0.0.1:8546 \
  -x '{"jsonrpc":"2.0","id":1,"method":"eth_subscribe","params":["newHeads"]}'
```


- `eth_sendRawTransaction` — submit a signed raw EVM transaction. Used by
  `sei-load` and `cast publish`. Because there is no chain ID, nonce,
  fee-estimation, gas-estimation, or call method, raw transactions must supply
  chain ID, nonce, gas limit, and gas price offline.
- `eth_subscribe("newHeads")` — WebSocket-only subscription that pushes one
  Ethereum header per executed block (#4345, v6.8.0). Delivered over the
  EVM-only WebSocket listener (default port 8546, configured by
  `giga.execution.evm_ws_port`), **not** the HTTP listener on 8545. Requires
  Autobahn execution; on non-Autobahn nodes the subscription errors with
  `newHeads subscriptions require Autobahn execution`. Over plain HTTP it
  returns `notifications not supported`.
- `eth_getTransactionReceipt` — returns a finalized receipt. A lookup for a
  pending or unknown hash returns `null`.
- `eth_getBalance` — returns the current committed EVM balance.


- `eth_getCode` — returns the current committed contract code at an address.

- `eth_feeHistory` — returns `gasUsedRatio`, `baseFeePerGas`, and reward
  percentiles for a range of blocks (see below).
- `eth_gasPrice` — returns a suggested gas price (see below).


- `eth_estimateGas` — estimates the gas a transaction would consume, built on
  the existing estimation libraries (#4325). Now available on the EVM-only Giga
  RPC.
- `eth_getLogs` — returns event logs matching a filter over a block range
  (#4308). Now available on the EVM-only Giga RPC.


- `eth_getBlockTransactionCountByNumber` — returns the number of transactions
  in a finalized block by number as a hex count (#4345, v6.8.0). Resolves the
  block the same way as `eth_getBlockByNumber`: `latest`, `safe`, `finalized`,
  and `pending` all map to the latest committed block, `earliest` to the oldest
  retained height, or an explicit height. Returns `null` for a zero/negative or
  future height; errors for a pruned height. An empty (zero-transaction) block
  returns `0x0`, not `null`.
- `eth_getBlockTransactionCountByHash` — returns the number of transactions in
  a finalized block by hash as a hex count (#4345, v6.8.0). Resolves the block
  the same way as `eth_getBlockByHash`. Returns `null` for an unknown hash.

### Fetch the block transaction count via JSON-RPC

```sh
curl -s http://127.0.0.1:8545 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_getBlockTransactionCountByNumber","params":["latest"]}'
```

```sh
curl -s http://127.0.0.1:8545 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_getBlockTransactionCountByHash","params":["0xYOUR_BLOCK_HASH"]}'
```


## `eth_getTransactionByBlockNumberAndIndex` and `eth_getTransactionByBlockHashAndIndex`

Fetch the transaction at a given index within a finalized block (#4345, v6.8.0).
Each returns exactly the entry the full-transaction `eth_getBlockByNumber` /
`eth_getBlockByHash` lists at that index.

- `eth_getTransactionByBlockNumberAndIndex(number, index)` — resolves the block
  the same way as `eth_getBlockByNumber`: `latest`, `safe`, `finalized`, and
  `pending` all map to the latest committed block, `earliest` to the oldest
  retained height, or an explicit height. Returns `null` for a zero/negative or
  future height, or when `index` is past the end of the block (including an
  index beyond `int` range, or an empty block at index `0`). Errors for a
  pruned height (and surfaces any other backend failure).
- `eth_getTransactionByBlockHashAndIndex(hash, index)` — resolves the block the
  same way as `eth_getBlockByHash`. Returns `null` for an unknown hash or when
  `index` is past the end of the block.

`index` is a hex quantity (e.g. `0x0`, `0x1`). The returned transaction's
`blockNumber` and `transactionIndex` come from the listing block itself, so a
replayed transaction whose stored receipt belongs to an earlier block still
reports this block's number and index here.

### Fetch a transaction by block and index via JSON-RPC

```sh
curl -s http://127.0.0.1:8545 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_getTransactionByBlockNumberAndIndex","params":["latest","0x1"]}'
```

```sh
curl -s http://127.0.0.1:8545 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_getTransactionByBlockHashAndIndex","params":["0xYOUR_BLOCK_HASH","0x0"]}'
```


<!-- The intro above states no fee-estimation, gas-estimation, call, log, or
WebSocket subscription method exists; this is now out of date: eth_estimateGas
and eth_getLogs are supported on the EVM-only surface, and eth_gasPrice /
eth_feeHistory already provide fee estimation. Only call and WebSocket
subscription methods remain unavailable. -->

## `eth_feeHistory`

Signature: `eth_feeHistory(blockCount, lastBlock, rewardPercentiles) -> FeeHistoryResult`.

Returns, for the `blockCount` blocks ending at `lastBlock`:

- `oldestBlock` — the oldest block covered by the response.
- `gasUsedRatio` — per-block `TotalGasUsed / gasLimit`, one entry per block.
- `baseFeePerGas` — **always zero on giga** (giga's base fee is fixed at zero).
  Carries one more entry than `gasUsedRatio`: the projected fee for the block
  after `lastBlock`, also zero.
- `reward` — present only when `rewardPercentiles` is non-empty. One row per
  block, one entry per requested percentile, holding that block's
  gas-weighted priority-fee reward at that percentile.

Constraints and behaviour:

- `blockCount` is capped at **1024**; a larger request is silently clamped. A
  `blockCount` below 1 returns an empty result (`oldestBlock` 0, empty
  `gasUsedRatio`).
- `rewardPercentiles` must be **strictly ascending** and each value in
  **[0, 100]**; otherwise the call errors with
  `invalid reward percentiles: must be ascending and between 0 and 100`. The
  list length must be 100 or fewer.
- `lastBlock` accepts block tags (`latest`, `safe`, `finalized`, `pending` all
  resolve to the latest committed block; `earliest` resolves to the oldest
  retained height) or an explicit height. An explicit height above the latest
  committed block errors (`not yet available`).
- Pruned/unavailable heights below the retention floor are skipped;
  `oldestBlock` reflects the earliest retained height actually returned.
- An empty (zero-transaction) block returns `0` gasUsedRatio and `0` reward
  for every requested percentile.

Which reward percentiles a block can answer from cache is governed by the
`receipt-store.rs-reward-percentiles` config (littidx backend; empty defaults
to `[0, 10, 20, 25, 30, 50, 75, 90, 100]`). A requested percentile not covered
by the stored set is recomputed from the block's receipts.

### Fetch fee history via JSON-RPC

```sh
curl -s http://127.0.0.1:8545 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_feeHistory","params":["0x4","latest",[25,50,75]]}'
```

## `eth_gasPrice`

Signature: `eth_gasPrice() -> hexutil.Big`.

Returns a suggested gas price:

- Base suggestion is a **10% margin over the admission floor** (the minimum
  effective gas price the application admits a transaction at): `floor * 110 / 100`.
- When the latest committed block is **congested** — `gasUsedRatio` strictly
  exceeds **80%** — and that block's **median (50th-percentile) reward** is at
  or above the margin, the median reward is returned instead.
- A block exactly at 80% is not congested. If the median reward is below the
  margin, or no percentile was stored for the congested block, the suggestion
  falls back to the margin.

### Fetch the suggested gas price via JSON-RPC

```sh
curl -s http://127.0.0.1:8545 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_gasPrice","params":[]}'
```

## `eth_getCode`

Signature: `eth_getCode(address, blockNumberOrHash) -> hexutil.Bytes`.

Returns the contract code at the address from the current committed EVM state,
matching go-ethereum semantics.

Block parameter handling:

- Accepts `latest`, `safe`, `finalized`, and `pending`. All four read the
  current committed EVM state, because Sei has instant finality.
- An explicit block number, a block hash, or `earliest` returns the same
  historical-state error as `eth_getBalance` (`historical state is not
  supported by EVM-only RPC`).

Code semantics:

- An address with no code — including an EOA or an address that was never
  touched — returns `0x` (empty bytes), not `null`, as go-ethereum does.

### Fetch contract code with `cast code`

```sh
cast code \
  --rpc-url http://127.0.0.1:8545 \
  0xYOUR_CONTRACT_ADDRESS
```

### Fetch code via JSON-RPC

```sh
curl -s http://127.0.0.1:8545 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_getCode","params":["0xYOUR_CONTRACT_ADDRESS","latest"]}'
```


## `eth_getStorageAt`

Signature: `eth_getStorageAt(address, storageKey, blockNumberOrHash) -> hexutil.Bytes`.

Returns the 32-byte value at a contract storage slot from the current committed
EVM state, matching go-ethereum semantics (#4388 is the EVM-only addition).

Block parameter handling:

- Accepts `latest`, `safe`, `finalized`, and `pending`. All four read the
  current committed EVM state, because Sei has instant finality.
- An explicit block number, a block hash, or `earliest` returns the same
  historical-state error as `eth_getBalance`/`eth_getCode` (`historical state
  is not supported by EVM-only RPC`).

Storage-key semantics:

- The slot key is a hex number of **at most 32 bytes**. A `0x`/`0X` prefix is
  optional; odd-length values are left-padded to a full byte, and the whole
  key is then left-padded to 32 bytes. An empty key (`0x`) is slot zero.
- A non-hex key fails with `hex string invalid`; a doubled prefix (e.g.
  `0x0X1`) is also treated as invalid hex. A key longer than 32 bytes fails
  with `hex string too long, want at most 32 bytes`.
- An **unset slot** — including any slot of an address with no contract —
  returns 32 zero bytes (`0x0000…0000`), not `null` or `0x`, as go-ethereum
  does.

### Read contract storage with `cast storage`

```sh
cast storage \
  --rpc-url http://127.0.0.1:8545 \
  0xYOUR_CONTRACT_ADDRESS \
  0
```

### Fetch a storage slot via JSON-RPC

```sh
curl -s http://127.0.0.1:8545 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_getStorageAt","params":["0xYOUR_CONTRACT_ADDRESS","0x0","latest"]}'
```


## `eth_getBalance`

Signature: `eth_getBalance(address, blockNumberOrHash)`.

Block parameter handling:

- Accepts `latest`, `safe`, `finalized`, and `pending`. All four read the
  current committed EVM state, because Sei has instant finality.
- Explicit block numbers (including `earliest`) and block hashes return an
  error — historical EVM-only state is not supported (`historical state is not
  supported by EVM-only RPC`).

Balance semantics:

- Every previously unseen address starts with a test-only `2^200` wei balance
  in the EVM-only setup.

### Fetch a balance with `cast`

```sh
cast balance \
  --rpc-url http://127.0.0.1:8545 \
  0x000000000000000000000000000000000000dEaD
```

### Fetch a balance via JSON-RPC

```sh
curl -s http://127.0.0.1:8545 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_getBalance","params":["0x000000000000000000000000000000000000dEaD","latest"]}'
```

## Fetch receipts with `cast`

`cast receipt` works for a known finalized transaction hash. There is no
`eth_getTransactionByHash` or block API to discover a transfer hash, so the
hash must be known ahead of time.

The inspection, balance, and receipt examples also require `jq` and Foundry's
`cast`.
