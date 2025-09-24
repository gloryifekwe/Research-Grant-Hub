# Automated Research Grant Distribution Smart Contract

## Overview

This smart contract manages the submission, evaluation, and distribution of research grants on the Stacks blockchain. It provides an automated system for researchers to submit proposals, evaluators to score them, and for approved grants to be distributed automatically based on quality metrics.

## Features

- **Proposal Submission**: Researchers can submit detailed research proposals with funding requests
- **Multi-Criteria Evaluation**: Authorized evaluators score proposals across technical, innovation, feasibility, and impact dimensions
- **Automated Scoring**: Weighted scoring system calculates overall proposal quality
- **Transparent Distribution**: Approved proposals receive funding automatically based on evaluation results
- **Access Control**: Only authorized evaluators can participate in the scoring process
- **Audit Trail**: Complete history of evaluations and funding distributions

## Contract Configuration

### Constants

- **MAX_PROPOSAL_TITLE_LENGTH**: 200 characters
- **MAX_PROPOSAL_DESCRIPTION_LENGTH**: 2000 characters
- **MIN_FUNDING_AMOUNT**: 1,000,000 microSTX (1 STX)
- **MAX_FUNDING_AMOUNT**: 100,000,000,000 microSTX (100,000 STX)
- **EVALUATION_PERIOD**: 144 blocks (~24 hours)
- **MIN_EVALUATOR_COUNT**: 3 evaluations required
- **MAX_SCORE**: 100 points maximum per category
- **PASSING_SCORE_THRESHOLD**: 70 points required for approval

### Scoring Weights

The overall score is calculated using weighted averages:
- **Technical Quality**: 25%
- **Innovation**: 30%
- **Feasibility**: 25%
- **Impact**: 20%

## Data Structures

### Proposals
```clarity
{
    title: string-ascii,
    description: string-ascii,
    researcher: principal,
    funding-requested: uint,
    submission-block: uint,
    status: string-ascii, // "pending", "approved", "rejected", "funded"
    total-score: uint,
    evaluation-count: uint,
    final-score: uint
}
```

### Evaluations
```clarity
{
    technical-score: uint,
    innovation-score: uint,
    feasibility-score: uint,
    impact-score: uint,
    overall-score: uint,
    evaluation-block: uint
}
```

### Evaluators
```clarity
{
    authorized: bool,
    evaluation-count: uint,
    reputation-score: uint
}
```

## Public Functions

### For Researchers

#### `submit-proposal`
Submit a new research proposal for evaluation.

**Parameters:**
- `title` (string-ascii 200): Proposal title
- `description` (string-ascii 2000): Detailed proposal description
- `funding-requested` (uint): Amount of STX requested

**Returns:** Proposal ID on success

**Example:**
```clarity
(submit-proposal 
    "AI-Powered Climate Modeling" 
    "Development of machine learning algorithms for improved climate prediction models..." 
    u50000000) ;; 50 STX
```

### For Evaluators

#### `evaluate-proposal`
Evaluate a submitted proposal across multiple criteria.

**Parameters:**
- `proposal-id` (uint): ID of proposal to evaluate
- `technical-score` (uint): Technical quality score (0-100)
- `innovation-score` (uint): Innovation level score (0-100)
- `feasibility-score` (uint): Project feasibility score (0-100)
- `impact-score` (uint): Expected impact score (0-100)

**Returns:** Calculated overall score

**Requirements:**
- Must be an authorized evaluator
- Cannot evaluate the same proposal twice
- Must evaluate within the evaluation period

### For Contract Management

#### `finalize-proposal`
Finalize the evaluation of a proposal and determine approval status.

**Parameters:**
- `proposal-id` (uint): ID of proposal to finalize

**Requirements:**
- Evaluation period must have ended
- Minimum number of evaluations must be received
- Proposal must still be in "pending" status

#### `distribute-funding`
Distribute funding to an approved proposal.

**Parameters:**
- `proposal-id` (uint): ID of approved proposal

**Requirements:**
- Proposal must be approved
- Cannot fund the same proposal twice
- Contract must have sufficient balance

### Administrative Functions

#### `add-authorized-evaluator`
Add a new authorized evaluator (admin only).

**Parameters:**
- `evaluator` (principal): Address of new evaluator

#### `remove-authorized-evaluator`
Remove evaluator authorization (admin only).

**Parameters:**
- `evaluator` (principal): Address of evaluator to remove

#### `fund-contract`
Add STX to the contract for grant distribution.

**Parameters:**
- `amount` (uint): Amount of STX to add to contract

## Read-Only Functions

### `get-proposal`
Retrieve complete proposal details by ID.

### `get-proposal-evaluation`
Get evaluation details for a specific proposal and evaluator.

### `is-authorized-evaluator`
Check if a principal is an authorized evaluator.

### `get-contract-stats`
Get current contract statistics including next proposal ID, total grants distributed, and contract balance.

### `get-funding-history`
Get funding history for a specific proposal.

### `is-evaluation-period-ended`
Check if the evaluation period has ended for a proposal.

## Workflow

### 1. Setup Phase
1. Deploy the contract
2. Contract owner adds authorized evaluators using `add-authorized-evaluator`
3. Fund the contract using `fund-contract`

### 2. Proposal Submission
1. Researchers submit proposals using `submit-proposal`
2. Proposals enter "pending" status
3. Evaluation period begins (144 blocks)

### 3. Evaluation Phase
1. Authorized evaluators score proposals using `evaluate-proposal`
2. Each evaluator can only evaluate each proposal once
3. Scores are weighted and combined automatically

### 4. Finalization
1. After evaluation period ends, anyone can call `finalize-proposal`
2. Proposals with scores >= 70 are marked "approved"
3. Proposals with scores < 70 are marked "rejected"

### 5. Funding Distribution
1. Approved proposals can receive funding via `distribute-funding`
2. STX is transferred automatically to the researcher
3. Proposals are marked "funded"

## Error Codes

- `u100`: Unauthorized access
- `u101`: Proposal not found
- `u102`: Invalid proposal title
- `u103`: Invalid proposal description
- `u104`: Invalid funding amount
- `u105`: Proposal already exists
- `u106`: Proposal already evaluated
- `u107`: Evaluation period not ended
- `u108`: Insufficient contract balance
- `u109`: Evaluator already voted
- `u110`: Invalid score
- `u111`: Not authorized evaluator
- `u112`: Proposal already funded
- `u113`: Proposal not approved
- `u114`: Evaluation period active
- `u115`: Insufficient evaluations
- `u116`: Transfer failed

## Security Considerations

- Only the contract owner can authorize/remove evaluators
- Evaluators cannot evaluate the same proposal multiple times
- Evaluation period prevents rushed decisions
- Minimum evaluator count ensures diverse input
- Funding is only distributed to approved proposals
- Complete audit trail for all transactions