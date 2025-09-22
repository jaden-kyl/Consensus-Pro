# Consensus Pro 🗳️

A liquid democracy smart contract with expertise-weighted voting built on the Stacks blockchain using Clarity.

## Overview

Consensus Pro revolutionizes democratic decision-making by combining liquid democracy with expertise-based voting weights. Users can either vote directly or delegate their voting power to trusted experts in specific domains, creating a more informed and efficient governance system.

## Key Features

### 🔄 Liquid Democracy
- **Flexible Delegation**: Delegate your voting power to experts in specific categories or general governance
- **Easy Revocation**: Remove delegations at any time with a single transaction
- **Delegate Voting**: Delegates can vote on behalf of their delegators

### 🎯 Expertise-Weighted Voting
- **Domain Expertise**: Different voting categories with varying influence multipliers
- **Dynamic Weighting**: Voting power calculated based on expertise scores and category relevance
- **Expert Recognition**: Users with high expertise scores gain "expert" status

### 📋 Comprehensive Governance
- **Proposal System**: Create time-bound proposals with descriptions and categories
- **Result Tracking**: Automatic vote tallying with participation metrics
- **Category Management**: Flexible system for adding new expertise domains

## Architecture

### Data Structures

**Users**: Store expertise scores, reputation, expert status, and current delegates
```clarity
{
  expertise-score: uint,
  reputation: uint,
  is-expert: bool,
  delegate: (optional principal)
}
```

**Proposals**: Track voting proposals with metadata and results
```clarity
{
  title: string,
  description: string,
  proposer: principal,
  created-at: uint,
  expires-at: uint,
  category: string,
  yes-votes: uint,
  no-votes: uint,
  total-weight: uint,
  is-active: bool
}
```

**Delegations**: Record delegation relationships with optional category specificity
```clarity
{
  category: (optional string),
  weight: uint,
  created-at: uint
}
```

## Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Basic understanding of Clarity smart contracts
- Stacks wallet for deployment

### Installation

1. Clone the repository:
```bash
git clone <your-repo-url>
cd consensus-pro
```

2. Check contract syntax:
```bash
clarinet check
```

3. Run tests:
```bash
npm install
npm test
```

### Deployment

Deploy to testnet:
```bash
clarinet deploy --testnet
```

Deploy to mainnet:
```bash
clarinet deploy --mainnet
```

## Usage Guide

### For Regular Users

#### 1. Register as a User
```clarity
(contract-call? .consensus-pro register-user u25)
```
Register with an initial expertise score (0-100).

#### 2. Create a Proposal
```clarity
(contract-call? .consensus-pro create-proposal 
  "Implement New Feature" 
  "Detailed description of the proposal..." 
  u1440  ;; 10 days duration
  "technology")
```

#### 3. Vote on Proposals
```clarity
(contract-call? .consensus-pro vote u1 true)  ;; Vote yes on proposal #1
```

#### 4. Delegate Your Vote
```clarity
(contract-call? .consensus-pro delegate-vote 'SP1EXPERT123... (some "technology"))
```

### For Delegates

#### Vote on Behalf of Delegators
```clarity
(contract-call? .consensus-pro vote-as-delegate u1 true 'SP1DELEGATOR123...)
```

### For Administrators

#### Update User Expertise
```clarity
(contract-call? .consensus-pro update-expertise 'SP1USER123... u75)
```

#### Add New Expertise Category
```clarity
(contract-call? .consensus-pro add-expertise-category "healthcare" u40 u140)
```

## Expertise Categories

The contract comes with four default categories:

| Category | Minimum Score | Weight Multiplier |
|----------|---------------|-------------------|
| Technology | 50 | 150% |
| Economics | 50 | 150% |
| Governance | 30 | 130% |
| General | 0 | 100% |

### Weight Calculation

Voting weight is calculated as:
```
weight = expertise_score × category_multiplier / 100
```

For example, a user with expertise score 60 in "technology" category would have:
```
weight = 60 × 150 / 100 = 90
```

## Read-Only Functions

### Get User Information
```clarity
(contract-call? .consensus-pro get-user 'SP1USER123...)
```

### Get Proposal Details
```clarity
(contract-call? .consensus-pro get-proposal u1)
```

### Check Vote Results
```clarity
(contract-call? .consensus-pro get-proposal-result u1)
```

### Calculate Voting Power
```clarity
(contract-call? .consensus-pro get-voting-power 'SP1USER123... "technology")
```

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | err-owner-only | Function restricted to contract owner |
| u101 | err-not-found | Requested entity does not exist |
| u102 | err-already-exists | Entity already exists |
| u103 | err-unauthorized | User lacks required permissions |
| u104 | err-invalid-input | Invalid parameter provided |
| u105 | err-proposal-expired | Proposal voting period has ended |
| u106 | err-already-voted | User has already cast their vote |

## Security Features

- **Double Voting Prevention**: Users cannot vote twice on the same proposal
- **Authorization Checks**: Delegates must be properly authorized
- **Time-based Validation**: Proposals have enforced duration limits
- **Owner-only Functions**: Administrative functions restricted to contract owner

## Best Practices

### For Users
- Set realistic expertise scores based on your actual knowledge
- Delegate to trusted experts in domains outside your expertise
- Participate actively in governance decisions

### For Delegates
- Only accept delegations in your areas of expertise
- Vote responsibly on behalf of your delegators
- Maintain transparency about your voting decisions

### For Administrators
- Regularly review and update expertise scores based on community feedback
- Add new categories as the ecosystem grows
- Monitor for potential gaming of the system

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes and add tests
4. Run `clarinet check` to validate syntax
5. Submit a pull request

### Development Guidelines

- Follow Clarity best practices
- Include comprehensive tests for new features
- Update documentation for any interface changes
- Use descriptive error messages

## Testing

Run the test suite:
```bash
npm test
```

Tests cover:
- User registration and management
- Proposal creation and voting
- Delegation mechanisms
- Weight calculations
- Error conditions

## Roadmap

- [ ] Multi-signature proposal creation
- [ ] Reputation-based expertise scoring
- [ ] Time-locked delegations
- [ ] Proposal categories with different voting thresholds
- [ ] Integration with other Stacks DeFi protocols
