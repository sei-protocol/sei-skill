---
title: Foundry for Sei
description: Setting up Foundry for Sei EVM development — configuration, forge test, forge script deployment, cast, and contract verification on Seitrace.
---

# Foundry for Sei

## When to Use Foundry

Use Foundry when:
- You want the fastest test suite (Rust-based, no Node.js overhead)
- You need fuzz testing and invariant testing
- You prefer Solidity test syntax (write tests in Solidity)
- You need fork testing with fine-grained cheat codes (`vm.*`)
- You want native gas snapshots

## Installation

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

## Project Setup

```bash
mkdir sei-foundry-project && cd sei-foundry-project
forge init --no-git
git init

# Install OpenZeppelin
forge install OpenZeppelin/openzeppelin-contracts
forge remappings > remappings.txt
```

## foundry.toml for Sei

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc_version = "0.8.28"
optimizer = true
optimizer_runs = 200

[rpc_endpoints]
sei_testnet = "${SEI_TESTNET_RPC}"
sei_mainnet = "${SEI_MAINNET_RPC}"

[etherscan]
sei_testnet = { key = "placeholder", url = "https://seitrace.com/api?chain=atlantic-2" }
sei_mainnet = { key = "placeholder", url = "https://seitrace.com/api" }
```

## .env Setup

```bash
# .env (add to .gitignore!)
PRIVATE_KEY=0xYourPrivateKeyHere
SEI_TESTNET_RPC=https://evm-rpc-testnet.sei-apis.com
SEI_MAINNET_RPC=https://evm-rpc.sei-apis.com
```

## Writing Tests (Solidity)

```solidity
// test/MyToken.t.sol
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/MyToken.sol";

contract MyTokenTest is Test {
    MyToken token;
    address owner = address(1);
    address user = address(2);

    function setUp() public {
        vm.prank(owner);
        token = new MyToken("My Token", "MTK", 1_000_000e18);
    }

    function test_InitialBalance() public view {
        assertEq(token.balanceOf(owner), 1_000_000e18);
    }

    function testFuzz_Transfer(uint256 amount) public {
        amount = bound(amount, 1, 1_000_000e18);
        vm.prank(owner);
        token.transfer(user, amount);
        assertEq(token.balanceOf(user), amount);
    }
}
```

```bash
forge test
forge test --match-test test_InitialBalance -vvv  # verbose
forge test --gas-report                            # gas summary
```

## Fork Testing Against Sei Testnet

```solidity
// test/PrecompileTest.t.sol
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "@sei-js/evm/contracts/IStaking.sol";

contract PrecompileTest is Test {
    address constant STAKING = 0x0000000000000000000000000000000000001005;
    IStaking staking = IStaking(STAKING);

    function setUp() public {
        // Fork testnet — precompiles live at fixed addresses
        vm.createSelectFork("sei_testnet");
    }

    function test_QueryValidators() public view {
        // Precompile call works against real chain state
        IStaking.Validator[] memory vals = staking.validators("BONDED", 10, "");
        assertGt(vals.length, 0);
    }
}
```

```bash
forge test --fork-url https://evm-rpc-testnet.sei-apis.com
# Or use the rpc_endpoints alias:
forge test --fork-url sei_testnet
```

## Deployment with forge script

```solidity
// script/DeployMyToken.s.sol
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/MyToken.sol";

contract DeployMyToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        MyToken token = new MyToken("My Token", "MTK", 1_000_000e18);
        console.log("Deployed to:", address(token));

        vm.stopBroadcast();
    }
}
```

```bash
# Simulate first
forge script script/DeployMyToken.s.sol --rpc-url sei_testnet --simulate

# Deploy to testnet
forge script script/DeployMyToken.s.sol \
  --rpc-url https://evm-rpc-testnet.sei-apis.com \
  --broadcast \
  --verify \
  --verifier-url https://seitrace.com/api?chain=atlantic-2 \
  --verifier etherscan \
  --etherscan-api-key placeholder

# Deploy to mainnet
forge script script/DeployMyToken.s.sol \
  --rpc-url https://evm-rpc.sei-apis.com \
  --broadcast \
  --verify \
  --verifier-url https://seitrace.com/api \
  --verifier etherscan \
  --etherscan-api-key placeholder
```

## Useful cast Commands

```bash
# Query contract state
cast call <CONTRACT> "balanceOf(address)(uint256)" <ADDRESS> \
  --rpc-url https://evm-rpc-testnet.sei-apis.com

# Send transaction
cast send <CONTRACT> "transfer(address,uint256)" <TO> 1000000000000000000 \
  --rpc-url https://evm-rpc-testnet.sei-apis.com \
  --private-key $PRIVATE_KEY \
  --gas-price 50000000000  # 50 gwei minimum

# Get transaction receipt
cast receipt <TX_HASH> --rpc-url https://evm-rpc-testnet.sei-apis.com

# Decode calldata
cast 4byte-decode <CALLDATA>

# ABI encode
cast abi-encode "transfer(address,uint256)" 0x1234... 1000000000000000000

# Get block
cast block latest --rpc-url https://evm-rpc-testnet.sei-apis.com
```

## Contract Verification

```bash
# Verify after deployment
forge verify-contract <CONTRACT_ADDRESS> src/MyToken.sol:MyToken \
  --chain 1328 \
  --verifier-url https://seitrace.com/api?chain=atlantic-2 \
  --verifier etherscan \
  --etherscan-api-key placeholder \
  --constructor-args $(cast abi-encode "constructor(string,string,uint256)" "My Token" "MTK" 1000000000000000000000000)
```

## Gas Snapshots

```bash
forge snapshot            # creates .gas-snapshot file
forge snapshot --check    # compare against existing snapshot (CI usage)
```

## Testing Pointer Contract Registration

```bash
# Register an ERC20 pointer for a CW20 contract (Cosmos-side CLI)
seid tx evm register-evm-pointer CW20 <CW20_CONTRACT_ADDRESS> \
  --from <KEY_NAME> \
  --chain-id atlantic-2 \
  --node https://rpc-testnet.sei-apis.com \
  --fees 40000usei
```

## Common Issues

**`forge: command not found`** — run `foundryup` again to update your PATH

**Precompile calls fail in unit tests** — precompile addresses (`0x1005`, etc.) are not available in local Foundry EVM; use `--fork-url sei_testnet` for tests involving precompiles

**`REVERT` with no message** — check SSTORE budget (72k gas per write); add `--gas-report` to identify expensive operations

**Deployment fails with `replacement transaction underpriced`** — increase `gasPrice` or wait for pending txs to clear
