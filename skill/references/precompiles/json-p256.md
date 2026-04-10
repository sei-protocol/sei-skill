---
title: JSON and P256 Precompiles
description: On-chain JSON parsing (0x1003) and P-256 signature verification (0x1011) — use cases, functions, and code examples.
---

# JSON and P256 Precompiles

## JSON Precompile

**Address:** `0x0000000000000000000000000000000000001003`

The JSON precompile provides native on-chain JSON parsing, which is significantly cheaper than implementing JSON parsing in Solidity.

### When to Use

- Parsing oracle response payloads stored on-chain
- Extracting values from cross-VM data payloads (CosmWasm → EVM)
- Processing structured metadata in contracts
- Any case where you'd otherwise write JSON string parsing in Solidity

### Functions

```solidity
// Extract a JSON field as raw bytes
function extractAsBytes(bytes memory input, string memory key)
    external pure returns (bytes memory);

// Extract a JSON field as bytes32
function extractAsBytes32(bytes memory input, string memory key)
    external pure returns (bytes32);

// Extract a JSON field as a list of byte arrays
function extractAsBytesList(bytes memory input, string memory key)
    external pure returns (bytes[] memory);

// Extract a JSON field as uint256
function extractAsUint256(bytes memory input, string memory key)
    external pure returns (uint256);
```

### Solidity Example

```solidity
pragma solidity ^0.8.28;

interface IJSON {
    function extractAsUint256(bytes memory input, string memory key)
        external pure returns (uint256);
    function extractAsBytes(bytes memory input, string memory key)
        external pure returns (bytes memory);
}

contract OracleConsumer {
    address constant JSON = 0x0000000000000000000000000000000000001003;

    // Parse a JSON price payload: {"price": "123456789000000000000"}
    function parsePrice(bytes calldata jsonPayload) external pure returns (uint256) {
        return IJSON(JSON).extractAsUint256(jsonPayload, "price");
    }

    // Extract a nested string value: {"oracle": {"symbol": "BTC"}}
    function parseSymbol(bytes calldata jsonPayload) external pure returns (bytes memory) {
        bytes memory oracle = IJSON(JSON).extractAsBytes(jsonPayload, "oracle");
        return IJSON(JSON).extractAsBytes(oracle, "symbol");
    }
}
```

### ethers.js Example

```typescript
import { ethers } from 'ethers';
import { JSON_PRECOMPILE_ADDRESS, JSON_PRECOMPILE_ABI } from '@sei-js/evm';

const json = new ethers.Contract(JSON_PRECOMPILE_ADDRESS, JSON_PRECOMPILE_ABI, provider);

const payload = ethers.toUtf8Bytes('{"price": "1234000000000000000000"}');
const price = await json.extractAsUint256(payload, "price");
console.log("Price:", price.toString()); // 1234000000000000000000
```

---

## P256 Precompile

**Address:** `0x0000000000000000000000000000000000001011`

The P256 precompile verifies signatures on the NIST P-256 curve (also called secp256r1). This is different from the secp256k1 curve used for standard Ethereum signatures.

### When to Use

- **WebAuthn / Passkeys**: verify hardware authenticator signatures (Touch ID, Face ID, hardware security keys all use P-256)
- **Account Abstraction (ERC-4337)**: build smart accounts with passkey-based signing instead of seed phrases
- **Enterprise integrations**: verify signatures from HSMs or devices that use P-256
- **Apple/Google platform credentials**: both platforms use P-256 for attestation

### Function

```solidity
// Returns true if (r, s) is a valid P-256 signature of messageHash by the public key (x, y)
function verify(
    bytes32 messageHash,
    bytes32 r,
    bytes32 s,
    bytes32 x,   // public key x coordinate
    bytes32 y    // public key y coordinate
) external view returns (bool);
```

### Solidity Example — WebAuthn Smart Account

```solidity
pragma solidity ^0.8.28;

interface IP256 {
    function verify(
        bytes32 messageHash,
        bytes32 r,
        bytes32 s,
        bytes32 x,
        bytes32 y
    ) external view returns (bool);
}

contract PasskeyWallet {
    address constant P256 = 0x0000000000000000000000000000000000001011;

    // Stored public key from WebAuthn registration
    bytes32 public pubKeyX;
    bytes32 public pubKeyY;

    constructor(bytes32 _x, bytes32 _y) {
        pubKeyX = _x;
        pubKeyY = _y;
    }

    // Verify a WebAuthn assertion before executing a transaction
    modifier onlyPasskey(bytes32 msgHash, bytes32 r, bytes32 s) {
        require(
            IP256(P256).verify(msgHash, r, s, pubKeyX, pubKeyY),
            "Invalid passkey signature"
        );
        _;
    }

    function execute(
        address target,
        bytes calldata data,
        bytes32 msgHash,
        bytes32 r,
        bytes32 s
    ) external onlyPasskey(msgHash, r, s) returns (bytes memory) {
        (bool ok, bytes memory result) = target.call(data);
        require(ok, "Execution failed");
        return result;
    }
}
```

### ethers.js Example

```typescript
import { ethers } from 'ethers';
import { P256_PRECOMPILE_ADDRESS, P256_PRECOMPILE_ABI } from '@sei-js/evm';

const p256 = new ethers.Contract(P256_PRECOMPILE_ADDRESS, P256_PRECOMPILE_ABI, provider);

// Verify a P-256 signature (e.g., from WebAuthn assertion)
const messageHash = ethers.keccak256(ethers.toUtf8Bytes("hello world"));
const isValid = await p256.verify(
  messageHash,
  r,    // bytes32 signature r component
  s,    // bytes32 signature s component
  x,    // bytes32 public key x coordinate
  y     // bytes32 public key y coordinate
);
console.log("Signature valid:", isValid);
```

### P-256 vs secp256k1

| | P-256 (secp256r1) | secp256k1 |
|---|---|---|
| Used by | WebAuthn, HSMs, Apple/Google | Ethereum, Bitcoin |
| Precompile address | `0x1011` | Built into EVM (ECRECOVER at `0x01`) |
| Use case | Passkey wallets, hardware auth | Standard EOA signing |
| Solidity function | `P256.verify(hash, r, s, x, y)` | `ecrecover(hash, v, r, s)` |
