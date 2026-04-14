---
title: Migrating from Solana to Sei
description: A guide for Solana/Anchor developers transitioning to Sei EVM — concept mapping, Rust-to-Solidity translations, toolchain differences, and parallel execution patterns.
---

# Migrating from Solana to Sei

Sei offers Solana developers a familiar execution model (parallel, high throughput, fast block times) combined with full EVM compatibility and Ethereum's mature ecosystem.

## Why Solana Developers Choose Sei

- **Familiar parallelization** — Sei uses optimistic parallel execution (OCC), analogous to Solana's Sealevel
- **400ms block times** — same speed as Solana, with **instant** single-block finality (vs Solana's ~2.5-4.5 second finality)
- **No dependency declarations** — Sei parallelizes automatically; no need to declare accounts upfront
- **EVM ecosystem** — Ethereum tooling (Foundry, Hardhat, OpenZeppelin, Etherscan), audited contracts, liquidity

---

## Concept Mapping

| Solana Concept | Sei EVM Equivalent | Key Difference |
|---|---|---|
| Program (stateless executable) | Smart Contract | Contract holds both code + state |
| Account (external data store) | Contract storage | State lives inside the contract |
| PDA (Program Derived Address) | CREATE2 deterministic address | Derived differently (keccak256 vs SHA256) |
| CPI (Cross-Program Invocation) | External contract call | Much simpler — just `Contract(addr).method()` |
| SPL Token | ERC-20 | No Associated Token Accounts needed |
| NFT (Metaplex) | ERC-721 / ERC-1155 | Standard OpenZeppelin implementations |
| Sysvar (clock, rent, etc.) | `block.timestamp`, `block.number` | Built-in globals, no imports |
| Compute Units | Gas | Both measure computational work |
| Lamports | Wei (18 decimals) | 1 SOL = 1e9 lamports; 1 SEI = 1e18 wei |
| Rent / Rent Exemption | None | No rent on Sei — storage is permanent |
| Priority fee | Gas price | Higher gasPrice → faster inclusion |
| Anchor | Hardhat / Foundry | Dev frameworks (Foundry feels most similar) |
| `@solana/web3.js` | ethers.js / viem | Core SDKs |
| `@coral-xyz/anchor` | TypeChain | Type-safe contract bindings |
| `@solana/wallet-adapter` | Wagmi / RainbowKit | Wallet connection |

---

## Code Translation

### Program → Smart Contract

```rust
// Solana/Anchor: Program is stateless, state in separate accounts
#[program]
pub mod counter {
    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        let counter = &mut ctx.accounts.counter;
        counter.count = 0;
        counter.authority = ctx.accounts.authority.key();
        Ok(())
    }

    pub fn increment(ctx: Context<Increment>) -> Result<()> {
        ctx.accounts.counter.count += 1;
        Ok(())
    }
}

#[account]
pub struct Counter {
    pub count: u64,
    pub authority: Pubkey,
}
```

```solidity
// Sei EVM: Contract holds both code and state
pragma solidity ^0.8.28;

contract Counter {
    uint256 public count;
    address public authority;

    constructor() {
        count = 0;
        authority = msg.sender;
    }

    function increment() external {
        count += 1;
    }
}
```

**Key simplifications**:
- No account space allocation — storage grows dynamically
- No explicit `Signer` validation — `msg.sender` is always authenticated
- No system program imports — native ops built into EVM
- Constructor replaces `initialize` instruction

---

### PDA → CREATE2

```rust
// Solana PDA derivation
let (pda, bump) = Pubkey::find_program_address(
    &[b"vault", user.key().as_ref()],
    &program_id,
);
```

```solidity
// Sei EVM: Use CREATE2 for deterministic addresses
// Or simply: map user address to data
mapping(address => Vault) public vaults;

// For CREATE2 deterministic deployment:
bytes32 salt = keccak256(abi.encodePacked("vault", user));
address vaultAddr = address(uint160(uint256(keccak256(abi.encodePacked(
    bytes1(0xff),
    factory,
    salt,
    keccak256(bytecode)
)))));
```

---

### CPI → Contract Call

```rust
// Solana CPI to token program
let cpi_accounts = Transfer {
    from: ctx.accounts.from_token_account.to_account_info(),
    to: ctx.accounts.to_token_account.to_account_info(),
    authority: ctx.accounts.authority.to_account_info(),
};
token::transfer(CpiContext::new(ctx.accounts.token_program.to_account_info(), cpi_accounts), amount)?;
```

```solidity
// Sei EVM: Direct interface call — no account setup
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

IERC20(tokenAddress).transferFrom(msg.sender, recipient, amount);
```

---

### SPL Token → ERC-20

```rust
// Solana SPL — requires Associated Token Accounts
#[derive(Accounts)]
pub struct TransferTokens<'info> {
    #[account(mut)] pub from: Account<'info, TokenAccount>,
    #[account(mut)] pub to: Account<'info, TokenAccount>,
    pub authority: Signer<'info>,
    pub token_program: Program<'info, Token>,
}
```

```solidity
// Sei EVM ERC-20 — balances stored directly in contract
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {
    constructor() ERC20("MyToken", "MTK") {
        _mint(msg.sender, 1_000_000 * 10**18);
    }
}
```

No Associated Token Accounts. No mint authority keys. Approvals via `approve()` / `transferFrom()`.

---

### Error Handling

```rust
// Solana custom errors
#[error_code]
pub enum ErrorCode {
    #[msg("Insufficient balance")]
    InsufficientBalance,
    #[msg("Unauthorized")]
    Unauthorized,
}
require!(amount > 0, ErrorCode::InvalidAmount);
```

```solidity
// Solidity custom errors (gas efficient)
error InsufficientBalance(uint256 available, uint256 required);
error Unauthorized();

if (amount == 0) revert Unauthorized();
if (balance < required) revert InsufficientBalance(balance, required);
```

---

### Events

```rust
// Solana Anchor events
#[event]
pub struct TradeEvent { pub trader: Pubkey, pub amount: u64 }
emit!(TradeEvent { trader: ctx.accounts.trader.key(), amount });
```

```solidity
// Solidity events
event Trade(address indexed trader, uint256 amount);
emit Trade(msg.sender, amount);
```

Up to 3 parameters can be `indexed` (searchable). Include computed values in events to simplify indexing.

---

### Access Control

```rust
// Solana: check signer matches stored authority
require!(ctx.accounts.authority.key() == ctx.accounts.state.authority, ErrorCode::Unauthorized);
```

```solidity
// Solidity: use OpenZeppelin Ownable or manual modifier
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyContract is Ownable {
    constructor() Ownable(msg.sender) {}
    function adminAction() external onlyOwner { ... }
}
```

---

## Parallelization: Explicit vs Automatic

On Solana you declare every account a transaction will touch — this is how the runtime knows what can run in parallel. On Sei, **you write normal Solidity and the OCC engine handles it automatically**.

```rust
// Solana: Must declare all accounts for the runtime to parallelize
#[derive(Accounts)]
pub struct Swap<'info> {
    #[account(mut)] pub user_token_a: Account<'info, TokenAccount>,
    #[account(mut)] pub user_token_b: Account<'info, TokenAccount>,
    #[account(mut)] pub pool_token_a: Account<'info, TokenAccount>,
    #[account(mut)] pub pool_token_b: Account<'info, TokenAccount>,
    #[account(mut)] pub pool_state: Account<'info, PoolState>,
}
```

```solidity
// Sei: Just write normal code — OCC parallelizes automatically
function swap(address tokenIn, address tokenOut, uint256 amountIn) external {
    IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
    uint256 amountOut = calculateOutput(amountIn);
    IERC20(tokenOut).transfer(msg.sender, amountOut);
    // Sei's OCC engine detects which storage slots are touched and
    // runs non-conflicting swaps in parallel, re-runs conflicts
}
```

**Optimization tip**: To maximize parallel throughput, avoid shared global counters. Partition state by user or position ID — see [`evm/best-practices.md`](../evm/best-practices.md).

---

## Fee Model Translation

| Solana | Sei EVM |
|---|---|
| Compute Units (CU) | Gas |
| Priority fee (microlamports/CU) | Gas price (gwei) |
| Rent / Rent exemption | **None** — no rent on Sei |
| Base fee | Dynamic, not burned |

```typescript
// Solana fee estimation
const computeUnits = 200_000;
const priorityFee = 1_000; // microlamports per CU
const rentExempt = await connection.getMinimumBalanceForRentExemption(accountSize);

// Sei EVM fee estimation
const gasLimit = 200_000n;
const gasPrice = parseUnits("50", "gwei");   // minimum on Sei
const fee = gasLimit * gasPrice;              // no rent
```

Storage on Sei is permanent — no minimum balance requirement, no account closure.

---

## Toolchain Translation

| Solana | Sei EVM |
|---|---|
| Anchor | Hardhat or Foundry |
| Solana CLI | seid CLI |
| `solana-test-validator` | `anvil --fork-url https://evm-rpc-testnet.sei-apis.com` |
| `anchor test` | `forge test` or `npx hardhat test` |
| `anchor deploy` | `forge create` or `npx hardhat run deploy.ts` |
| Solana Explorer | Seitrace (https://seitrace.com) |
| `@solana/web3.js` | ethers.js v6 or viem |
| `@solana/wallet-adapter` | Wagmi + `@sei-js/sei-global-wallet` |
| Phantom / Solflare | MetaMask / Compass / Sei Global Wallet |

### Frontend SDK Comparison

```typescript
// Solana
import { Connection, PublicKey } from '@solana/web3.js';
import { Program, AnchorProvider } from '@coral-xyz/anchor';

const connection = new Connection('https://api.mainnet-beta.solana.com');
const program = new Program(idl, programId, provider);
const state = await program.account.myAccount.fetch(address);
const tx = await program.methods.increment().accounts({...}).rpc();
```

```typescript
// Sei EVM
import { ethers } from 'ethers';

const provider = new ethers.JsonRpcProvider('https://evm-rpc.sei-apis.com');
const contract = new ethers.Contract(contractAddress, abi, signer);
const value = await contract.value();
const tx = await contract.increment({ gasPrice: ethers.parseUnits("50", "gwei") });
await tx.wait(1);  // instant finality
```

---

## Migration Checklist

```
□ Install Foundry (curl -L https://foundry.paradigm.xyz | bash && foundryup)
□ Create foundry.toml with sei_testnet RPC endpoint
□ Translate program accounts → Solidity storage variables
□ Replace explicit Signer checks → msg.sender
□ Replace CPI → external contract calls
□ Replace SPL Token logic → ERC-20 (OpenZeppelin)
□ Remove rent-exemption checks (no rent on Sei)
□ Replace Anchor error codes → Solidity custom errors
□ Remove account declarations from functions (not needed)
□ Update frontend: @solana/web3.js → ethers.js or viem
□ Update wallet: wallet-adapter → wagmi + @sei-js/sei-global-wallet
□ Use gasPrice (not EIP-1559 fields): minimum 50 gwei
□ Use tx.wait(1) — instant finality
□ Test on atlantic-2 testnet first
□ Get testnet SEI at https://atlantic-2.app.sei.io/faucet
```

---

## Common Pitfalls

```solidity
// ❌ Solana mental model: lamports for amounts
uint256 amount = 1_000_000_000; // Solana: 1 SOL in lamports

// ✅ Sei: wei (18 decimals)
uint256 amount = 1 ether;   // 1 SEI = 1e18 wei

// ❌ Over-engineering account ownership checks
require(accountOwner == expectedOwner, "Invalid account owner");
// ✅ msg.sender is always authenticated — no extra check needed

// ❌ Declaring "accounts" parameter for parallelization
function swap(address[] memory accounts, ...) external { ... }
// ✅ Just write normal Solidity — Sei handles parallelization
function swap(address tokenIn, address tokenOut, uint256 amount) external { ... }

// ❌ PREVRANDAO for randomness
uint256 rand = uint256(block.prevrandao) % 100;
// ✅ Use Pyth VRF — see oracles.md
```
