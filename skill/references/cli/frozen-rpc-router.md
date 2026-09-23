# frozen-rpc-router

`frozen-rpc-router` exposes an HTTP EVM JSON-RPC endpoint that proxies requests to a live node and any number of freeze-height-frozen nodes, routing each request by block number (added in sei-chain #frozen-rpc-router, v6.6.3).

## Freeze height model

A freeze height is an **exclusive** boundary. A node started with `seid start ... --freeze-height 100` serves blocks through height 99. The router therefore sends height 99 to that node and height 100 to the next configured interval (or to the live node).

To run a frozen node, start `seid` with the `--freeze-height` flag:

```sh
seid start --chain-id sei --inv-check-period 0 --freeze-height 100
```

## Usage

```sh
go run ./cmd/frozen-rpc-router \
  --listen-address 0.0.0.0:8545 \
  --live-node localhost:9545 \
  --frozen-node 1000000=localhost:9546 \
  --frozen-node 2000000=10.0.0.12:8545
```

Or build and run the binary:

```sh
make build-frozen-rpc-router
./build/frozen-rpc-router --live-node localhost:9545 --frozen-node 1000000=localhost:9546
```

## Flags

| Flag | Default | Description |
|------|---------|-------------|
| `--listen-address` | `127.0.0.1:8545` | Address on which the router listens. |
| `--live-node` | (required) | HTTP RPC address of the live node. |
| `--frozen-node` | — | `freeze-height=ip:port` pair; repeat once per frozen node. |
| `--max-request-body-bytes` | `5242880` (5 MiB) | Maximum JSON-RPC request body size. Must be positive. |
| `--max-block-reference-depth` | `16` | Maximum nested block reference depth when parsing block references. Must be positive. |


| `--batch-request-limit` | `1000` | Maximum number of calls in a JSON-RPC batch. Must be positive. |
| `--write-timeout` | `30s` | Maximum duration for writing an HTTP response. Must be positive. |
| `--shutdown-timeout` | `10s` | Graceful shutdown timeout. Must be positive. |

- `--live-node` is required; omitting it fails with `--live-node is required`.
- Each `--frozen-node` value must be `freeze-height=ip:port`; the freeze height must be a positive integer no greater than `math.MaxInt64`, and freeze heights must be unique (duplicates fail with `duplicate freeze height <n>`).
- Node addresses may include an explicit `http://` or `https://` scheme; a bare `ip:port` is treated as `http://`.
- Frozen nodes may be listed in any order; the router sorts them by freeze height internally.

## Routing behaviour

- **Methods with explicit numeric block parameters** (e.g. `eth_getBlockByNumber`, `eth_getBalance`, `eth_call`, `eth_getStorageAt`, `debug_traceBlockByNumber`, and others) are routed to the frozen interval whose freeze height is greater than the requested height, or to the live node if no frozen interval covers it. The `earliest` tag routes to the lowest frozen interval (height 0).
- **`eth_getLogs` and `eth_feeHistory`** are routed only when their entire explicit block range falls within one interval. A range crossing an interval boundary returns JSON-RPC error `-32000` (`block ranges spanning multiple frozen-node intervals are not supported`). For a notification (no `id`), no error is returned.
- **Latest-style block tags** (`latest`, `pending`, `safe`, `finalized`), methods without block numbers, `eth_getLogs` by `blockHash`, EIP-1898 `blockHash` references, stateful filter methods, subscriptions, and WebSocket / non-POST requests all go to the **live** node.

## Sei-RPC-Route response header

Every HTTP response carries a `Sei-RPC-Route` header describing where the request was served:

- `frozen:<height>` — served entirely by the frozen node with that freeze height.
- `live` — served entirely by the live node.
- `mixed` — a batch request split across multiple backends.

## Other error codes

- `-32700` parse error (invalid JSON).
- `-32600` invalid request.
- `-32000` unsupported (range spanning intervals).
- `-32001` upstream request failed.
- Requests exceeding `--max-request-body-bytes` return HTTP `413 Request Entity Too Large`.
