---
title: Upgradeable Contracts on Sei
description: Proxy patterns (UUPS, Transparent, Beacon, Diamond) on Sei EVM with Sei-specific caveats — precompile interactions, dual-address pitfalls, OCC implications, and Seiscan verification of proxies.
---

# Upgradeable Contracts on Sei

Standard EVM upgradeability works on Sei with no Sei-specific bugs in the proxies themselves. This page covers when to use which pattern and the Sei-specific gotchas you'd otherwise miss.

## Pattern selection

| Pattern | Use when | Avoid when |
|---|---|---|
| **UUPS (ERC-1822)** | Default for new contracts; proxy is small (~2KB), upgrade logic in implementation | You want to disable upgrades quickly without redeploying |
| **Transparent** | Existing OpenZeppelin codebases; admin is a dedicated EOA/multisig | Storage layout will change frequently (storage clash risk between admin and impl) |
| **Beacon** | Many proxy instances sharing one upgradeable impl (e.g., factory-deployed pools) | Single contract — overhead not worth it |
| **Diamond (EIP-2535)** | Contract too large for the 24KB code-size limit; need fine-grained per-facet upgrade | Smaller contracts where complexity isn't justified |
| **Immutable** (no proxy) | Trust-minimized; contract logic is settled | You expect bugs or evolving requirements |

## UUPS with OpenZeppelin (recommended default)

```solidity
// MyToken.sol
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MyToken is Initializable, ERC20Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() { _disableInitializers(); }

    function initialize(address owner) public initializer {
        __ERC20_init("MyToken", "MTK");
        __Ownable_init(owner);
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
```

Deploy with Hardhat-Upgrades:

```ts
// scripts/deploy.ts
import { ethers, upgrades } from "hardhat";

async function main() {
  const MyToken = await ethers.getContractFactory("MyToken");
  const proxy = await upgrades.deployProxy(MyToken, [process.env.OWNER], {
    initializer: "initialize",
    kind: "uups",
  });
  await proxy.waitForDeployment();
  console.log("Proxy at:", await proxy.getAddress());
}

main();
```

Upgrading:

```ts
const MyTokenV2 = await ethers.getContractFactory("MyTokenV2");
await upgrades.upgradeProxy(PROXY_ADDRESS, MyTokenV2, { kind: "uups" });
```

## Sei-specific caveats

### 1. Precompile addresses are constants — don't store them as upgradeable

Precompile addresses are fixed by Sei consensus and won't move. Hardcoding them as `immutable` (or just constants) is fine:

```solidity
contract Staker {
    address constant STAKING_PRECOMPILE = 0x0000000000000000000000000000000000001005;
    // OK — precompile addresses won't change in an upgrade
}
```

Storing them in upgradeable storage is unnecessary overhead and adds an upgrade vector for an immutable system contract.

### 2. Pointer contract dependencies

If your upgradeable contract holds references to pointer contracts (ERC20↔CW20 bridges), the pointer addresses are deterministic from the underlying CW/ERC token. They won't change unless you deploy a new pointer. Treat them as constants once registered. See [pointers/overview.md](../pointers/overview.md).

### 3. Dual-address system in upgrade authorization

Your upgrade admin (the address that can call `upgradeTo`) is a `0x...` EVM address. If your governance lives on the Cosmos side (e.g., a multisig of `sei1...` validators), you have to bridge the authorization:

- **Option A**: Convert the admin Cosmos addresses to their EVM-derived counterparts and authorize those — requires associated keys.
- **Option B**: Authorize a multisig (Safe) on the EVM side; manage signers off-chain or via a governance bridge.

Don't assume `Ownable(seiCosmosAddress)` works — it expects a `0x...` address.

### 4. Storage layout across versions

OpenZeppelin's storage-layout linter (`hardhat-upgrades`) catches accidental clashes. **Always run it** before upgrading:

```ts
await upgrades.upgradeProxy(PROXY, V2, { kind: "uups" });
// Hardhat-Upgrades will refuse if layout is incompatible.
```

For Foundry deployments, use `forge inspect <Contract> storageLayout` and diff manually.

### 5. OCC and reinitialization

If your upgrade adds a `reinitializer`, the call writes to storage during the upgrade tx. Schedule upgrades during low-traffic windows; otherwise the OCC scheduler conflicts every concurrent caller against your reinit write.

### 6. Verification on Seiscan

Upgrade flow on Seiscan:

1. Verify the **new implementation** contract: `forge verify-contract <NEW_IMPL> src/MyTokenV2.sol:MyTokenV2 --verifier sourcify --chain-id 1329`.
2. After the upgrade tx confirms, navigate to the **proxy** address on Seiscan.
3. Click "More" → "Is this a proxy?" → confirm. Seiscan will reroute reads to the new impl ABI.

If Seiscan shows stale ABI, manually re-link via the proxy admin tab.

See [contract-verification.md](contract-verification.md) for full verification flow.

## Beacon proxy pattern (factory deployments)

Use when one impl is shared across many proxy instances — e.g., a pool factory that deploys one proxy per asset pair.

```solidity
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

contract PoolFactory {
    UpgradeableBeacon public immutable beacon;

    constructor(address impl, address owner) {
        beacon = new UpgradeableBeacon(impl, owner);
    }

    function createPool(bytes calldata initData) external returns (address) {
        return address(new BeaconProxy(address(beacon), initData));
    }
}
```

Upgrading the beacon upgrades **every** proxy at once. Powerful and dangerous — make sure your governance has a thoughtful pause+upgrade flow.

## Diamond (EIP-2535) — when to consider

Solidity contracts max out at 24,576 bytes deployed bytecode. Hit that ceiling, and Diamond is a structured way to split logic across "facets" upgradeable independently.

Use a maintained library (louper-dev's diamond-3) rather than rolling your own. The selector→facet routing is correct on Sei (no Sei-specific opcodes involved), but the complexity overhead is real — most projects don't need it.

## Initialization safety

```solidity
// Always disable initializers in the implementation constructor
/// @custom:oz-upgrades-unsafe-allow constructor
constructor() { _disableInitializers(); }
```

Without this, an attacker can call `initialize` on the implementation directly, take ownership, and call `selfdestruct`-equivalents. (`SELFDESTRUCT` is mostly a no-op post-Cancun, but the principle holds: lock impls.)

## Pause/freeze pattern for emergencies

```solidity
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract MyToken is /* ... */, PausableUpgradeable {
    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    function transfer(address to, uint256 v) public override whenNotPaused returns (bool) {
        return super.transfer(to, v);
    }
}
```

On Sei's instant finality, a "pause within seconds" response to an exploit is real — 400ms blocks make `pause()` land before the next-block exploit transaction in many cases.

## Renouncing upgrade authority

When the protocol matures and upgrades should stop, transfer admin to a non-existent address — but use OpenZeppelin's `transferOwnership(address(0))` only on contracts that handle that gracefully (some refuse zero-address transfer).

For UUPS, override `_authorizeUpgrade` to always revert post-renounce:

```solidity
bool public upgradeable = true;

function renounceUpgradeability() external onlyOwner {
    upgradeable = false;
}

function _authorizeUpgrade(address) internal override onlyOwner {
    require(upgradeable, "FROZEN");
}
```

## Common failure modes

| Issue | Cause | Fix |
|---|---|---|
| Storage layout clash | Reordered or removed variable | Use `__gap` slots; never delete variables, only deprecate |
| `Initializable: contract is already initialized` | Trying to re-init without `reinitializer(N)` | Use `reinitializer(2)` for V2-specific init logic |
| Proxy reads return zeros after upgrade | New impl forgot to import storage layout from V1 | Inherit V1 → V2 chain or use the `__gap` trick |
| Seiscan shows old ABI | Proxy not re-linked to new impl | Re-confirm via Seiscan UI proxy tab |
| `Ownable` constructor revert | Implementation deployed without `_disableInitializers()` | Always include the constructor pattern above |

## Sei-specific notes

- All standard OpenZeppelin upgrade tooling works unchanged. There's no Sei fork of `@openzeppelin/hardhat-upgrades` needed.
- `evm_version = "cancun"` (or earlier) — newer EVM versions may not be enabled.
- Proxy contracts work correctly with pointer contracts and precompiles.
- OCC parallelism applies to upgrade-target contracts the same way: the upgrade itself is a single tx (serializing on the proxy slot for that one tx), but normal users hitting the proxy run in parallel.
