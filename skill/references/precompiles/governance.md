---
title: Governance Precompile
description: Submit proposals, vote, and deposit tokens using Sei's Governance precompile (0x1006) from EVM contracts or frontends.
---

# Governance Precompile

**Address:** `0x0000000000000000000000000000000000001006`

## Sei Governance Overview

| Parameter | Value |
|---|---|
| Minimum deposit | 3,500 SEI (mainnet) |
| Expedited minimum deposit | 7,000 SEI |
| Deposit period | 2 days |
| Voting period | 3 days |
| Expedited voting period | 1 day |
| Quorum required | 33.4% of bonded stake |
| Deposit burned if | >33.4% NoWithVeto votes |

## Vote Options

| Value | Meaning |
|---|---|
| `1` | Yes |
| `2` | Abstain |
| `3` | No |
| `4` | NoWithVeto |

## Functions

```solidity
// Vote on a proposal
function vote(uint64 proposalID, int32 option) external returns (bool success);

// Vote with split weights (weights must sum to exactly 1.0)
struct WeightedVoteOption {
    int32 option;   // 1=Yes, 2=Abstain, 3=No, 4=NoWithVeto
    string weight;  // decimal string e.g. "0.7" — all weights must sum to "1.0"
}
function voteWeighted(uint64 proposalID, WeightedVoteOption[] memory options)
    external returns (bool success);

// Deposit tokens to a proposal (msg.value = amount in wei; must be a whole number of usei)
function deposit(uint64 proposalID) external payable returns (bool success);

// Submit a new proposal described by a JSON string; msg.value is the initial deposit
// (wei, whole usei only). Returns the new proposal ID.
function submitProposal(string memory proposalJSON) external payable returns (uint64 proposalID);
```

`proposalJSON` fields: `title` and `description` (both required), `type` (`"Text"` — the default when empty — `"ParameterChange"`, `"SoftwareUpgrade"`, `"CancelSoftwareUpgrade"`, `"CommunityPoolSpend"`, …), `is_expedited` (bool), plus the type's payload: `changes` (`[{subspace, key, value}]`) for parameter changes, `plan` for software upgrades, `community_pool_spend` for spends. CosmWasm and IBC proposal types are rejected (`... proposals are not supported yet via precompile`).

There are no `getProposal` / `getProposals` methods; use `proposal` / `proposals` below.

## Authorization Methods (v6.7+)

Let a grantee vote or submit proposals for the caller ([sei-chain#3846](https://github.com/sei-protocol/sei-chain/pull/3846), [sei-chain#3893](https://github.com/sei-protocol/sei-chain/pull/3893)). See "Scoped Authorizations" in [overview.md](overview.md) for how grants work.

```solidity
// Called by the voter/proposer (granter). `expiration` is Unix seconds, after the current block time.
function grantVoteAuthorization(address grantee, int64 expiration) external returns (bool success);     // MsgVote only
function grantProposalAuthorization(address grantee, int64 expiration) external returns (bool success); // MsgSubmitProposal only
function revokeVoteAuthorization(address grantee) external returns (bool success);
function revokeProposalAuthorization(address grantee) external returns (bool success);

// Called by the grantee
function voteWithAuthorization(address voter, uint64 proposalID, int32 option) external returns (bool success);
// msg.value (from the grantee, whole usei) is the initial deposit, made for `proposer`
function submitProposalWithAuthorization(address proposer, string memory proposalJSON)
    external payable returns (uint64 proposalID);
```

A vote grant does not cover `voteWeighted`, and a proposal grant does not cover `deposit`.

## Query Methods (view)

Since the v6.7 upgrade ([sei-chain#3767](https://github.com/sei-protocol/sei-chain/pull/3767)), the Gov precompile exposes on-chain query methods accessible from EVM contracts. The vote and deposit queries are named `getVote`/`getDeposit` (not overloaded onto the `vote`/`deposit` transaction methods) because overloaded function names break common tooling like ethers.js.

```solidity
// Query a single proposal by ID
function proposal(uint64 proposalID) external view returns (ProposalData memory proposal);

// Query proposals with optional filters.
// proposalStatus: 0 = all. voter/depositor: zero address = no filter.
// pageKey: empty bytes for the first page.
function proposals(
    int32 proposalStatus,
    address voter,
    address depositor,
    bytes memory pageKey
) external view returns (ProposalData[] memory proposals, bytes memory nextKey);

// Query a single vote cast on a proposal
function getVote(uint64 proposalID, address voter) external view returns (VoteData memory vote);

// Query all votes on a proposal, paginated
function votes(uint64 proposalID, bytes memory pageKey)
    external view returns (VoteData[] memory votes, bytes memory nextKey);

// Query gov module voting/deposit/tally parameters
function params() external view returns (GovParams memory params);

// Query a single deposit on a proposal
function getDeposit(uint64 proposalID, address depositor)
    external view returns (DepositData memory deposit);

// Query all deposits on a proposal, paginated
function deposits(uint64 proposalID, bytes memory pageKey)
    external view returns (DepositData[] memory deposits, bytes memory nextKey);

// Query the current live tally of votes on a proposal
function tallyResult(uint64 proposalID) external view returns (TallyResultData memory tallyResult);
```

### Return structs

```solidity
struct Coin { uint256 amount; string denom; }

struct TallyResultData { string yes; string abstain; string no; string noWithVeto; }

struct WeightedVoteOptionData { int32 option; string weight; } // weight as decimal string, e.g. "0.7"

struct ProposalData {
    uint64 id;
    int32 status;                      // ProposalStatus enum value
    TallyResultData finalTallyResult;
    int64 submitTime;                  // Unix seconds
    int64 depositEndTime;              // Unix seconds
    Coin[] totalDeposit;
    int64 votingStartTime;             // Unix seconds
    int64 votingEndTime;               // Unix seconds
    bool isExpedited;
    bytes content;                     // proposal content as JSON
}

struct VoteData { uint64 proposalId; string voter; WeightedVoteOptionData[] options; } // voter is bech32

struct DepositData { uint64 proposalId; string depositor; Coin[] amount; } // depositor is bech32

struct GovParams {
    uint64 votingPeriod;               // seconds
    uint64 expeditedVotingPeriod;      // seconds
    Coin[] minDeposit;
    uint64 maxDepositPeriod;           // seconds
    Coin[] minExpeditedDeposit;
    string quorum;
    string threshold;
    string vetoThreshold;
    string expeditedQuorum;
    string expeditedThreshold;
}
```

### Query notes

- All query methods are `view` and non-payable; passing a non-zero `value` reverts.
- Address arguments (`voter`, `depositor`) must be EVM addresses associated with a Sei address. For `proposals`, pass the zero address to skip that filter.
- `tallyResult` returns the live tally without side effects — the underlying `Tally` deletes votes as it counts, but the precompile runs it on a branched context and discards the writes, so your votes are preserved.

## Gas Model

The Gov precompile uses **dynamic gas** — gas is metered against actual execution rather than a fixed per-method cost. This applies to both the transaction methods (`vote`, `voteWeighted`, `deposit`, `submitProposal`) and all the query methods above.

## ethers.js Examples

### Setup

```typescript
import { ethers } from 'ethers';
import { GOVERNANCE_PRECOMPILE_ADDRESS, GOVERNANCE_PRECOMPILE_ABI } from '@sei-js/precompiles';

const provider = new ethers.BrowserProvider(window.ethereum);
const signer = await provider.getSigner();
const governance = new ethers.Contract(
  GOVERNANCE_PRECOMPILE_ADDRESS,
  GOVERNANCE_PRECOMPILE_ABI,
  signer
);
```

### Vote on a Proposal

```typescript
const proposalId = 42n;
const YES = 1;

const tx = await governance.vote(proposalId, YES);
await tx.wait(1);
console.log("Voted YES on proposal", proposalId);
```

### Vote with Split Weights

```typescript
// Split vote: 70% Yes, 30% Abstain
const tx = await governance.voteWeighted(proposalId, [
  { option: 1, weight: "0.7" },   // 70% Yes
  { option: 2, weight: "0.3" },   // 30% Abstain
]);
await tx.wait(1);
// Weights MUST sum to exactly "1.0" or the transaction will fail
```

### Deposit on a Proposal

```typescript
// Deposit 100 SEI on proposal to push it to voting period
const amount = ethers.parseEther("100");
const tx = await governance.deposit(proposalId, { value: amount });
await tx.wait(1);
```

### Submit a Proposal

```typescript
// 3,500 SEI minimum deposit to submit (mainnet)
const deposit = ethers.parseEther("3500");

const proposalJSON = JSON.stringify({
  title: "My Proposal Title",
  description: "Detailed description of the proposed changes...",
  type: "Text",
  is_expedited: false,
});
const tx = await governance.submitProposal(proposalJSON, { value: deposit });
const receipt = await tx.wait(1);
// submitProposal returns the proposal ID; read it with staticCall before sending,
// or look it up afterwards with governance.proposals(...)
```

### Query a Proposal (v6.7+)

```typescript
// v6.7 method: if your packaged ABI predates it, build the contract from
// precompiles/gov/Gov.sol in sei-chain (or an ABI fragment) instead
const proposal = await governance.proposal(proposalId);
console.log("Status:", proposal.status); // ProposalStatus enum value
// content is the proposal content (protobuf Any) as JSON bytes
const content = JSON.parse(ethers.toUtf8String(proposal.content));
console.log("Title:", content.title);
// tally values are usei amounts as decimal strings
console.log("Yes votes:", ethers.formatUnits(proposal.finalTallyResult.yes, 6), "SEI");
```

## Automated Governance in Solidity

Smart contracts can vote on behalf of their stakers:

```solidity
pragma solidity ^0.8.28;

interface IGovernance {
    function vote(uint64 proposalID, int32 option) external returns (bool);
}

contract AutoVoter {
    address constant GOVERNANCE = 0x0000000000000000000000000000000000001006;

    address public owner;
    int32 public defaultVote; // e.g., 1 = Yes

    constructor(int32 _defaultVote) {
        owner = msg.sender;
        defaultVote = _defaultVote;
    }

    // Vote on a proposal with the contract's default preference
    function castVote(uint64 proposalId) external {
        require(msg.sender == owner, "Only owner");
        bool success = IGovernance(GOVERNANCE).vote(proposalId, defaultVote);
        require(success, "Vote failed");
    }
}
```

## Key Notes

- **Voting power**: you must have staked SEI (delegated to a validator) to have voting power; unstaked SEI does not count
- **Deposit risk**: if a proposal receives >33.4% NoWithVeto votes, ALL deposits are burned — including yours
- **Inherited vote**: if a staker does not vote, their validator's vote counts for them
- **Weighted vote**: weights in `voteWeighted` must be exact decimal strings and sum to precisely `"1.0"`
- **Testnet governance**: proposals on atlantic-2 use much smaller deposit requirements; safe to test full flow there
