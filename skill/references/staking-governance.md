---
title: Staking and Governance on Sei
description: Delegated proof-of-stake on Sei — delegation, unbonding, redelegation, rewards, and on-chain governance via CLI, Staking precompile, and Governance precompile.
---

# Staking and Governance on Sei

## Staking Overview

Sei uses **delegated proof-of-stake (dPoS)**:
- Token holders delegate to validators, who sign blocks
- Delegators earn proportional rewards from gas fees and genesis unlocks
- **No slashing of funds** — jailed validators lose rewards but not stake
- Unbonding period: **21 days**

---

## Delegation via CLI

```bash
# Delegate to a validator
seid tx staking delegate <VALIDATOR_ADDRESS> 1000000usei \
  --from mykey \
  --chain-id pacific-1 \
  --node https://rpc.sei-apis.com \
  --fees 20000usei

# Example: delegate 1 SEI (1_000_000 usei)
seid tx staking delegate sei1valoper...abc 1000000usei \
  --from mykey --chain-id pacific-1

# Query your delegation
seid q staking delegation $(seid keys show mykey -a) sei1valoper...abc \
  --node https://rpc.sei-apis.com

# Query all delegations for your address
seid q staking delegations $(seid keys show mykey -a) \
  --node https://rpc.sei-apis.com
```

## Undelegation (Unbonding)

```bash
# Undelegate — starts 21-day unbonding period
seid tx staking unbond <VALIDATOR_ADDRESS> 500000usei \
  --from mykey \
  --chain-id pacific-1 \
  --node https://rpc.sei-apis.com \
  --fees 20000usei

# Check unbonding progress
seid q staking unbonding-delegation $(seid keys show mykey -a) sei1valoper...abc \
  --node https://rpc.sei-apis.com
```

**During unbonding**:
- Tokens are locked (not earning rewards, not transferable)
- After 21 days they return to your wallet automatically

## Redelegation

Move stake between validators instantly without waiting for unbonding.

```bash
seid tx staking redelegate <SRC_VALIDATOR> <DST_VALIDATOR> 500000usei \
  --from mykey \
  --chain-id pacific-1 \
  --node https://rpc.sei-apis.com \
  --fees 20000usei
```

**Redelegation rules**:
- Instant move — no unbonding wait
- Destination validator cannot be re-redelegated for 21 days
- Max 7 simultaneous redelegations per account

---

## Staking Rewards

```bash
# Query pending rewards
seid q distribution rewards $(seid keys show mykey -a) \
  --node https://rpc.sei-apis.com

# Withdraw all rewards from all validators
seid tx distribution withdraw-all-rewards \
  --from mykey \
  --chain-id pacific-1 \
  --node https://rpc.sei-apis.com \
  --fees 20000usei

# Withdraw from a specific validator
seid tx distribution withdraw-rewards <VALIDATOR_ADDRESS> \
  --from mykey \
  --chain-id pacific-1 \
  --node https://rpc.sei-apis.com \
  --fees 20000usei
```

---

## Staking via EVM (Precompile)

See [`precompiles/staking-distribution.md`](./precompiles/staking-distribution.md) for full examples. Quick reference:

```solidity
import { STAKING_PRECOMPILE_ADDRESS, STAKING_PRECOMPILE_ABI } from '@sei-js/evm';

// Delegate: takes ETH value in wei
STAKING(0x1005).delegate{value: amount}(validatorAddress);

// Undelegate: amount in usei (6 decimals), not wei
STAKING(0x1005).undelegate(validatorAddress, amountInUsei);

// Claim rewards
DISTRIBUTION(0x1007).withdrawDelegatorReward(validatorAddress);
```

**Critical**: `delegate` is `payable` (send wei). `undelegate`/`redelegate` take amounts in **usei** (1 SEI = 1,000,000 usei).

---

## Governance

### Parameters

| Parameter | Mainnet | Testnet |
|---|---|---|
| Min deposit | 3,500 SEI | 10 SEI |
| Min expedited deposit | 7,000 SEI | 20 SEI |
| Deposit period | 2 days | — |
| Voting period | 3 days | 12 hours |
| Expedited voting period | 24 hours | 6 hours |
| Quorum | 33.4% | — |
| Expedited quorum | 66.7% | — |
| Approval threshold | 50% | — |
| Expedited threshold | 66.7% | — |
| Veto threshold | 33.4% | — |

### Voting

A proposal **passes** when:
- Quorum met (≥33.4% of bonded tokens voted)
- Approval > 50% (excluding abstain)
- NoWithVeto < 33.4%

A proposal is **vetoed** if NoWithVeto ≥ 33.4%, regardless of Yes votes.

---

## Submitting Proposals via CLI

### Text Proposal

```bash
seid tx gov submit-proposal \
  --title "My Proposal" \
  --description "Detailed description..." \
  --type Text \
  --deposit 3500000000usei \
  --from mykey \
  --chain-id pacific-1 \
  --node https://rpc.sei-apis.com \
  --fees 20000usei
```

### Parameter Change Proposal

```bash
# proposal.json
cat > proposal.json << 'EOF'
{
  "title": "Update Max Validators",
  "description": "Increase max validators from 100 to 125",
  "changes": [
    {
      "subspace": "staking",
      "key": "MaxValidators",
      "value": 125
    }
  ]
}
EOF

seid tx gov submit-proposal param-change proposal.json \
  --deposit 3500000000usei \
  --from mykey \
  --chain-id pacific-1 \
  --node https://rpc.sei-apis.com \
  --fees 20000usei
```

### Software Upgrade Proposal

```bash
seid tx gov submit-proposal software-upgrade v5.9.0 \
  --upgrade-height 20000000 \
  --upgrade-info "https://github.com/sei-protocol/sei-chain/releases/v5.9.0" \
  --title "Sei v5.9.0 Upgrade" \
  --description "Performance improvements and bug fixes" \
  --deposit 3500000000usei \
  --from mykey \
  --chain-id pacific-1 \
  --node https://rpc.sei-apis.com \
  --fees 20000usei
```

### Expedited Proposal (Fast-Track)

```bash
seid tx gov submit-proposal software-upgrade emergency-patch \
  --upgrade-height 20100000 \
  --upgrade-info "https://github.com/sei-protocol/sei-chain/releases/emergency-patch" \
  --title "Emergency Security Patch" \
  --description "Critical security fix" \
  --deposit 7000000000usei \    # doubled deposit required
  --expedited \
  --from mykey \
  --chain-id pacific-1 \
  --fees 20000usei
```

---

## Voting on Proposals

```bash
# Vote options: yes | no | abstain | no_with_veto
seid tx gov vote 42 yes \
  --from mykey \
  --chain-id pacific-1 \
  --node https://rpc.sei-apis.com \
  --fees 20000usei

# Weighted vote (split voting power)
seid tx gov weighted-vote 42 "yes=0.6,no=0.4" \
  --from mykey \
  --chain-id pacific-1 \
  --fees 20000usei
```

## Querying Proposals

```bash
# All proposals
seid q gov proposals --node https://rpc.sei-apis.com

# Active proposals only
seid q gov proposals --status voting_period --node https://rpc.sei-apis.com

# Specific proposal
seid q gov proposal 42 --node https://rpc.sei-apis.com

# Vote tally
seid q gov tally 42 --node https://rpc.sei-apis.com

# All votes on a proposal
seid q gov votes 42 --node https://rpc.sei-apis.com
```

---

## Governance via EVM (Precompile)

See [`precompiles/governance.md`](./precompiles/governance.md) for full examples.

```solidity
// Vote on proposal ID 42
GOVERNANCE(0x1006).vote(42, 1);  // 1=Yes, 2=Abstain, 3=No, 4=NoWithVeto

// Weighted vote: weights must sum to "1.0"
GOVERNANCE(0x1006).voteWeighted(42, [
    { option: 1, weight: "0.7" },  // 70% Yes
    { option: 3, weight: "0.3" }   // 30% No
]);

// Add deposit
GOVERNANCE(0x1006).deposit(42);  // send SEI value with the call
```

---

## Validator List and Querying

```bash
# All active validators sorted by voting power
seid q staking validators --status bonded --node https://rpc.sei-apis.com

# Single validator details
seid q staking validator sei1valoper...abc --node https://rpc.sei-apis.com

# Delegations to a specific validator
seid q staking delegations-to sei1valoper...abc --node https://rpc.sei-apis.com
```
