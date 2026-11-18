# EVM-only JSON-RPC surface

The EVM-only (Autobahn / giga) deployment exposes a deliberately minimal EVM
JSON-RPC surface. All other `eth_*` methods return JSON-RPC method-not-found.

## Supported methods

- `eth_sendRawTransaction` — submit a signed raw EVM transaction. Used by
  `sei-load` and `cast publish`. Because there is no chain ID, nonce,
  fee-estimation, gas-estimation, call, log, or WebSocket subscription method,
  raw transactions must supply chain ID, nonce, gas limit, and gas price
  offline.
- `eth_getTransactionReceipt` — returns a finalized receipt. A lookup for a
  pending or unknown hash returns `null`.
- `eth_getBalance` — returns the current committed EVM balance.

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
