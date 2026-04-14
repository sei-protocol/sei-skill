---
title: Testing Smart Contracts on Sei
description: Testing strategy for Sei smart contracts — unit tests, fork testing, parallelization-aware testing, and precompile mocking.
---

# Testing Smart Contracts on Sei

## Testing Strategy Overview

| Test type | Tool | When to use |
|---|---|---|
| Unit tests (no state) | Foundry (`forge test`) | Pure math, access control, simple token logic |
| Fork tests | Foundry/Hardhat with `--fork-url` | Precompile interactions, pointer contracts, real token balances |
| Testnet staging | Deploy to atlantic-2 | End-to-end flow, wallet integration, gas measurement |
| Invariant/fuzz tests | Foundry | Token invariants, protocol correctness under random inputs |

**Default rule**: Write unit tests in Foundry for speed. Use fork tests for anything that touches a Sei precompile (`0x1001`–`0x100B`) or pointer contracts.

## Unit Testing with Foundry

```solidity
// test/Token.t.sol
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/MyToken.sol";

contract TokenTest is Test {
    MyToken token;

    function setUp() public {
        token = new MyToken("Test", "TST", 1_000_000e18);
    }

    function test_Transfer() public {
        address alice = makeAddr("alice");
        token.transfer(alice, 100e18);
        assertEq(token.balanceOf(alice), 100e18);
    }

    // Fuzz: amount can be any value
    function testFuzz_Transfer(address to, uint256 amount) public {
        vm.assume(to != address(0));
        amount = bound(amount, 1, 1_000_000e18);
        token.transfer(to, amount);
        assertEq(token.balanceOf(to), amount);
    }

    // Invariant: total supply never changes
    function invariant_TotalSupply() public view {
        assertEq(token.totalSupply(), 1_000_000e18);
    }
}
```

```bash
forge test              # run all tests
forge test -vvv         # verbose (show logs, traces on failure)
forge test --gas-report # include gas usage per function
```

## Fork Testing Against Sei Testnet

Required when your contract interacts with precompiles or needs real chain state:

```solidity
// test/StakingIntegration.t.sol
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

interface IStaking {
    function delegate(string memory validatorAddress) external payable returns (bool);
}

contract StakingTest is Test {
    IStaking constant STAKING = IStaking(0x0000000000000000000000000000000000001005);

    address testUser;

    function setUp() public {
        vm.createSelectFork("https://evm-rpc-testnet.sei-apis.com");
        testUser = makeAddr("user");
        vm.deal(testUser, 100 ether); // fund with SEI for staking
    }

    function test_DelegateToValidator() public {
        string memory validator = "seivaloper1..."; // real testnet validator
        vm.prank(testUser);
        bool success = STAKING.delegate{value: 1 ether}(validator);
        assertTrue(success);
    }
}
```

```bash
forge test --fork-url https://evm-rpc-testnet.sei-apis.com
```

## Fork Testing with Hardhat

```typescript
// hardhat.config.ts
networks: {
  hardhat: {
    forking: {
      url: process.env.SEI_TESTNET_RPC!,
    },
    chainId: 1328,  // match testnet for correct precompile addresses
  },
}
```

```typescript
// test/integration.test.ts
import { ethers } from "hardhat";
import { expect } from "chai";

// Addresses from @sei-js/evm
const STAKING_ADDRESS = "0x0000000000000000000000000000000000001005";

describe("Staking precompile integration", () => {
  it("should return validators", async () => {
    const abi = ["function validators(string,uint32,string) view returns (tuple[])"];
    const staking = new ethers.Contract(STAKING_ADDRESS, abi, ethers.provider);
    const validators = await staking.validators("BONDED", 10, "");
    expect(validators.length).to.be.greaterThan(0);
  });
});
```

## Testing Precompile Interactions

### Mocking precompiles in unit tests (Foundry)

When you can't fork (e.g., CI environment without RPC access), use `vm.mockCall`:

```solidity
function test_MyContractWithMockedStaking() public {
    // Mock the staking precompile's delegate function
    vm.mockCall(
        0x0000000000000000000000000000000000001005,
        abi.encodeWithSignature("delegate(string)"),
        abi.encode(true)  // return success
    );

    // Now your contract call will succeed without a real fork
    myContract.stakeForUser{value: 1 ether}("seivaloper1...");
}
```

### Testing with real precompile ABIs

```bash
# Install @sei-js/evm for TypeScript ABI access
npm install @sei-js/evm

# For Foundry — copy ABI JSON files from @sei-js/evm into test/fixtures/
```

## Testing Parallel-Execution Safety

Sei's OCC will re-execute conflicting transactions, but your contract should produce the same result regardless of execution order for independent users.

**Test pattern — verify no cross-user interference:**

```solidity
function test_ParallelSafety() public {
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    // Give both users tokens
    token.transfer(alice, 100e18);
    token.transfer(bob, 100e18);

    // Simulate concurrent operations (Foundry runs these sequentially,
    // but the logic should be independent)
    vm.prank(alice);
    vault.deposit(50e18);

    vm.prank(bob);
    vault.deposit(50e18);

    // Verify Alice's state is unaffected by Bob's operation
    assertEq(vault.balanceOf(alice), 50e18);
    assertEq(vault.balanceOf(bob), 50e18);
}
```

**Anti-pattern to test for — shared counter conflicts:**

```solidity
function test_HotGlobalDoesNotBlockOtherUsers() public {
    // If your contract has: uint256 public totalDeposited;
    // Alice and Bob can conflict on this write — verify your contract
    // handles this correctly or eliminates the hot global.
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    vm.prank(alice);
    vault.deposit(50e18);  // increments totalDeposited

    vm.prank(bob);
    vault.deposit(50e18);  // also increments totalDeposited

    // On Sei, these may conflict and cause a sequential re-execution.
    // Total should be correct regardless:
    assertEq(vault.totalDeposited(), 100e18);
}
```

## Gas Testing

```bash
# Foundry gas snapshot — commits a baseline for CI comparisons
forge snapshot

# Compare against baseline (fails CI if gas increases)
forge snapshot --check

# Report gas per function call
forge test --gas-report
```

**Sei-specific gas callouts:**
- SSTORE — testnet (atlantic-2): 72k gas per write; mainnet (pacific-1): 20k gas. Fork test against your target network; check complex write patterns stay within block gas limit (12.5M)
- Call to precompile — cheaper than equivalent Solidity logic; verify in gas report

## Transaction Tracing for Debugging

```bash
# Foundry trace — shows full call tree
forge test --match-test test_MyFailing -vvvv

# Cast trace against testnet
cast run <TX_HASH> --rpc-url https://evm-rpc-testnet.sei-apis.com

# Debug failed tx
cast run <TX_HASH> \
  --rpc-url https://evm-rpc-testnet.sei-apis.com \
  --debug
```

```javascript
// Ethers.js — trace via debug_traceTransaction
const trace = await provider.send("debug_traceTransaction", [txHash, {}]);
console.log(trace.structLogs);  // step-by-step EVM execution
```

## Testnet Deployment Checklist

Before promoting to mainnet:

1. `forge test --fork-url https://evm-rpc-testnet.sei-apis.com` — all pass
2. `forge script ... --simulate` — deployment simulation succeeds
3. Deploy to atlantic-2, check Seitrace explorer
4. Run integration tests against deployed testnet address
5. Verify contract source on Seitrace
6. Test with a real wallet (MetaMask or Compass) connected to testnet
