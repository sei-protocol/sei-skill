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

// Deposit tokens to a proposal (msg.value = amount in wei)
function deposit(uint64 proposalID) external payable returns (bool success);

// Submit a new proposal
function submitProposal(
    string memory title,
    string memory description,
    string memory metadata,
    string memory proposalType  // "Text", "ParameterChange", "SoftwareUpgrade"
) external payable returns (uint64 proposalID);

// Query a proposal
function getProposal(uint64 proposalID) external view returns (Proposal memory);

// List proposals with pagination
function getProposals(uint32 proposalStatus, uint32 pageLimit, string memory pageKey)
    external view returns (Proposal[] memory);
```

## ethers.js Examples

### Setup

```typescript
import { ethers } from 'ethers';
import { GOVERNANCE_PRECOMPILE_ADDRESS, GOVERNANCE_PRECOMPILE_ABI } from '@sei-js/evm';

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

const tx = await governance.submitProposal(
  "My Proposal Title",
  "Detailed description of the proposed changes...",
  "ipfs://QmMetadata...",  // optional IPFS metadata
  "Text",                  // proposal type
  { value: deposit }
);
const receipt = await tx.wait(1);
// Parse the proposalID from events
```

### Query a Proposal

```typescript
const proposal = await governance.getProposal(proposalId);
console.log("Status:", proposal.status);
console.log("Title:", proposal.title);
console.log("Yes votes:", ethers.formatEther(proposal.finalTallyResult?.yes ?? 0));
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
