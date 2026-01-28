# ChainQuest - Smart Contracts Documentation

## Overview

ChainQuest smart contracts are built using Solidity and deployed on the Base blockchain. The contract architecture follows modular design principles with upgradeability, security, and gas efficiency as primary concerns.

## Contract Architecture

### Contract Hierarchy

```
QuestFactory (Factory Pattern)
    ├── Creates Quest contracts
    ├── Manages quest registry
    └── Handles quest templates

Quest (Individual Quest Logic)
    ├── Milestone tracking
    ├── State management
    ├── Reward distribution
    └── Event emissions

RewardPool (Financial Management)
    ├── Staking mechanism
    ├── Reward calculation
    ├── Slashing logic
    └── Emergency functions

VerificationOracle (Decentralized Verification)
    ├── Validator management
    ├── Voting logic
    ├── Dispute resolution
    └── Reward distribution

AchievementNFT (ERC721)
    ├── Badge minting
    ├── Metadata management
    ├── Transfer controls
    └── Batch operations

GovernanceToken (ERC20)
    ├── Token distribution
    ├── Voting rights
    ├── Staking rewards
    └── Governance functions
```

## Core Contracts

### 1. QuestFactory Contract

#### Purpose
Factory contract for creating new quest instances using the EIP-1167 minimal proxy pattern for gas efficiency.

#### Key Features
- Gas-efficient quest creation using clones
- Quest registry and metadata storage
- Access control for quest creation
- Quest template management
- Emergency pause functionality

#### Main Functions

##### createQuest
```solidity
function createQuest(
    CreateQuestParams calldata params
) external returns (address questAddress) {
    require(!paused, "QuestFactory: Contract is paused");
    require(params.stakeAmount > 0, "QuestFactory: Invalid stake amount");
    require(params.duration > 0, "QuestFactory: Invalid duration");
    
    // Create quest clone
    address questClone = Clones.clone(questImplementation);
    
    // Initialize quest
    Quest(questClone).initialize(params);
    
    // Register quest
    quests[questClone] = QuestInfo({
        id: nextQuestId,
        creator: msg.sender,
        createdAt: block.timestamp,
        isActive: true
    });
    
    emit QuestCreated(questClone, msg.sender, nextQuestId);
    nextQuestId++;
    
    return questClone;
}
```

##### Parameters
```solidity
struct CreateQuestParams {
    string title;
    string description;
    address creator;
    uint256 stakeAmount;
    uint256 rewardPool;
    uint256 duration;
    uint256 maxParticipants;
    uint256 verificationThreshold;
    address rewardToken;
    Milestone[] milestones;
    string metadataURI;
}
```

##### Events
```solidity
event QuestCreated(
    address indexed questAddress,
    address indexed creator,
    uint256 indexed questId
);

event QuestTemplateUpdated(
    uint256 indexed templateId,
    address indexed implementation
);

event FactoryPaused(address indexed pausedBy);
event FactoryUnpaused(address indexed unpausedBy);
```

#### Gas Optimization
- Uses EIP-1167 minimal proxy pattern (~70% gas savings)
- Batch operations for multiple quest creation
- Efficient storage with packed structs
- Event-based off-chain storage for metadata

### 2. Quest Contract

#### Purpose
Individual quest contract managing participant lifecycle, milestone tracking, and reward distribution.

#### State Machine
```
Created → Active → Completed/Expired/Failed
    ↓
[Participants join, submit evidence, verification]
```

#### Key Features
- Participant management with staking
- Milestone tracking and evidence submission
- Verification workflow integration
- Automatic reward distribution
- Time-based quest expiration

#### Main Functions

##### joinQuest
```solidity
function joinQuest() external payable {
    require(isActive, "Quest: Not active");
    require(block.timestamp < expiresAt, "Quest: Expired");
    require(participants.length < maxParticipants, "Quest: Full");
    require(msg.value == stakeAmount, "Quest: Incorrect stake");
    
    require(!hasParticipated[msg.sender], "Quest: Already joined");
    
    participants.push(Participant({
        user: msg.sender,
        stakeAmount: msg.value,
        joinedAt: block.timestamp,
        status: ParticipantStatus.Active,
        completedMilestones: 0
    }));
    
    hasParticipated[msg.sender] = true;
    
    emit ParticipantJoined(msg.sender, msg.value);
}
```

##### submitEvidence
```solidity
function submitEvidence(
    uint256 milestoneId,
    string calldata evidenceHash,
    Evidence calldata evidence
) external {
    require(isActive, "Quest: Not active");
    require(hasParticipated[msg.sender], "Quest: Not participant");
    
    Participant storage participant = getParticipant(msg.sender);
    require(participant.status == ParticipantStatus.Active, "Quest: Inactive participant");
    
    Milestone storage milestone = milestones[milestoneId];
    require(!milestone.completedBy[msg.sender], "Quest: Milestone already completed");
    
    // Store evidence on-chain (hash) and off-chain (IPFS)
    EvidenceSubmission storage submission = evidenceSubmissions[nextEvidenceId];
    submission.participant = msg.sender;
    submission.milestoneId = milestoneId;
    submission.evidenceHash = keccak256(abi.encode(evidence));
    submission.ipfsHash = evidenceHash;
    submission.submittedAt = block.timestamp;
    submission.status = VerificationStatus.Pending;
    
    emit EvidenceSubmitted(nextEvidenceId, msg.sender, milestoneId, evidenceHash);
    
    // Trigger verification process
    IVerificationOracle(verificationOracle).requestVerification(
        nextEvidenceId,
        milestone.verificationType,
        evidence
    );
    
    nextEvidenceId++;
}
```

##### completeMilestone
```solidity
function completeMilestone(
    address participant,
    uint256 milestoneId
) external onlyRole(VERIFIER_ROLE) {
    require(hasParticipated[participant], "Quest: Not participant");
    
    Participant storage userParticipant = getParticipant(participant);
    Milestone storage milestone = milestones[milestoneId];
    
    require(!milestone.completedBy[participant], "Quest: Already completed");
    
    // Mark milestone as completed
    milestone.completedBy[participant] = true;
    userParticipant.completedMilestones++;
    
    // Check if all milestones completed
    if (userParticipant.completedMilestones == milestones.length) {
        _completeQuest(participant);
    }
    
    emit MilestoneCompleted(participant, milestoneId);
}
```

##### Events
```solidity
event ParticipantJoined(
    address indexed participant,
    uint256 stakeAmount
);

event EvidenceSubmitted(
    uint256 indexed evidenceId,
    address indexed participant,
    uint256 indexed milestoneId,
    string evidenceHash
);

event MilestoneCompleted(
    address indexed participant,
    uint256 indexed milestoneId
);

event QuestCompleted(
    address indexed participant,
    uint256 rewardAmount
);

event QuestExpired(uint256 timestamp);
```

#### Security Features
- Reentrancy protection on all external functions
- Access control with OpenZeppelin Roles
- Input validation and overflow checks
- Emergency pause functionality
- Time-based constraints

### 3. RewardPool Contract

#### Purpose
Centralized reward management contract handling staking, reward distribution, and slashing mechanisms.

#### Key Features
- Multi-token support (ETH, ERC20)
- Automated reward calculation
- Slashing for failed quests
- Emergency withdrawal mechanisms
- Reward pool management

#### Main Functions

##### stake
```solidity
function stake(
    address quest,
    uint256 amount,
    address token
) external payable {
    require(amount > 0, "RewardPool: Invalid amount");
    require(quests[quest].isActive, "RewardPool: Quest not active");
    
    address user = msg.sender;
    
    // Handle ETH vs ERC20
    if (token == address(0)) {
        require(msg.value == amount, "RewardPool: Incorrect ETH amount");
        ethBalances[user] += amount;
    } else {
        IERC20(token).transferFrom(user, address(this), amount);
        tokenBalances[token][user] += amount;
    }
    
    // Record stake
    Stake storage stakeRecord = stakes[quest][user];
    stakeRecord.amount += amount;
    stakeRecord.token = token;
    stakeRecord.stakedAt = block.timestamp;
    
    emit Staked(user, quest, amount, token);
}
```

##### distributeReward
```solidity
function distributeReward(
    address quest,
    address participant,
    uint256 amount
) external onlyRole(QUEST_CONTRACT_ROLE) {
    require(amount > 0, "RewardPool: Invalid amount");
    
    Stake storage stakeRecord = stakes[quest][participant];
    require(stakeRecord.amount >= amount, "RewardPool: Insufficient stake");
    
    // Calculate reward (stake + bonus)
    uint256 rewardAmount = stakeRecord.amount + calculateRewardBonus(quest, participant);
    
    // Distribute reward
    if (stakeRecord.token == address(0)) {
        payable(participant).transfer(rewardAmount);
    } else {
        IERC20(stakeRecord.token).transfer(participant, rewardAmount);
    }
    
    // Clear stake
    delete stakes[quest][participant];
    
    emit RewardDistributed(participant, quest, rewardAmount);
}
```

##### slash
```solidity
function slash(
    address quest,
    address participant,
    uint256 percentage
) external onlyRole(QUEST_CONTRACT_ROLE) {
    require(percentage <= 10000, "RewardPool: Invalid percentage"); // 100% = 10000 basis points
    
    Stake storage stakeRecord = stakes[quest][participant];
    uint256 slashAmount = (stakeRecord.amount * percentage) / 10000;
    
    // Transfer to treasury
    if (stakeRecord.token == address(0)) {
        payable(treasury).transfer(slashAmount);
    } else {
        IERC20(stakeRecord.token).transfer(treasury, slashAmount);
    }
    
    // Refund remaining amount
    uint256 refundAmount = stakeRecord.amount - slashAmount;
    if (refundAmount > 0) {
        if (stakeRecord.token == address(0)) {
            payable(participant).transfer(refundAmount);
        } else {
            IERC20(stakeRecord.token).transfer(participant, refundAmount);
        }
    }
    
    emit Slashed(participant, quest, slashAmount, percentage);
}
```

#### Reward Calculation
```solidity
function calculateRewardBonus(
    address quest,
    address participant
) internal view returns (uint256) {
    QuestInfo storage questInfo = quests[quest];
    
    // Base bonus from quest reward pool
    uint256 baseBonus = (questInfo.rewardPool * 10000) / 
                       (questInfo.maxParticipants * 10000);
    
    // Performance multiplier based on completion speed
    uint256 speedMultiplier = getSpeedMultiplier(quest, participant);
    
    return (baseBonus * speedMultiplier) / 10000;
}
```

### 4. VerificationOracle Contract

#### Purpose
Decentralized verification system managing validator staking, voting logic, and dispute resolution.

#### Key Features
- Validator reputation system
- Weighted voting based on reputation
- Dispute resolution mechanism
- Validator rewards
- Anti-manipulation measures

#### Main Functions

##### registerValidator
```solidity
function registerValidator() external {
    require(!isValidator[msg.sender], "VerificationOracle: Already validator");
    require(validatorStake[msg.sender] >= MIN_VALIDATOR_STAKE, "VerificationOracle: Insufficient stake");
    
    isValidator[msg.sender] = true;
    validators.push(msg.sender);
    
    // Initialize validator stats
    ValidatorStats storage stats = validatorStats[msg.sender];
    stats.registeredAt = block.timestamp;
    stats.totalVotes = 0;
    stats.correctVotes = 0;
    stats.reputationScore = 1000; // Starting reputation
    
    emit ValidatorRegistered(msg.sender);
}
```

##### castVote
```solidity
function castVote(
    uint256 evidenceId,
    bool approve,
    uint256 confidence,
    string calldata reasoning
) external {
    require(isValidator[msg.sender], "VerificationOracle: Not validator");
    require(!hasVoted[evidenceId][msg.sender], "VerificationOracle: Already voted");
    
    EvidenceSubmission storage submission = evidenceSubmissions[evidenceId];
    require(submission.status == VerificationStatus.Pending, "VerificationOracle: Not pending");
    
    // Record vote
    Vote storage vote = votes[nextVoteId];
    vote.voter = msg.sender;
    vote.evidenceId = evidenceId;
    vote.approve = approve;
    vote.confidence = confidence;
    vote.reasoning = reasoning;
    vote.votedAt = block.timestamp;
    
    hasVoted[evidenceId][msg.sender] = true;
    
    // Calculate voting power based on reputation
    uint256 votingPower = calculateVotingPower(msg.sender);
    vote.votingPower = votingPower;
    
    // Update vote tallies
    if (approve) {
        submission.approvalVotes += votingPower;
    } else {
        submission.rejectionVotes += votingPower;
    }
    submission.totalVotes += votingPower;
    
    emit VoteCast(nextVoteId, msg.sender, evidenceId, approve, confidence);
    
    // Check if verification threshold met
    if (submission.totalVotes >= submission.verificationThreshold) {
        _processVerificationResult(evidenceId);
    }
    
    nextVoteId++;
}
```

##### calculateVotingPower
```solidity
function calculateVotingPower(address validator) public view returns (uint256) {
    ValidatorStats storage stats = validatorStats[validator];
    
    // Base voting power
    uint256 basePower = 1000;
    
    // Reputation multiplier (1x to 5x)
    uint256 reputationMultiplier = (stats.reputationScore * 10000) / (1000 * 10000);
    reputationMultiplier = Math.min(reputationMultiplier, 50000); // Max 5x
    
    // Activity bonus (recent voting activity)
    uint256 activityBonus = getActivityBonus(validator);
    
    return (basePower * reputationMultiplier / 10000) + activityBonus;
}
```

##### Dispute Resolution
```solidity
function createDispute(
    uint256 evidenceId,
    string calldata reason,
    string calldata evidence
) external payable {
    require(msg.value >= DISPUTE_FEE, "VerificationOracle: Insufficient dispute fee");
    
    EvidenceSubmission storage submission = evidenceSubmissions[evidenceId];
    require(submission.status == VerificationStatus.Approved || 
           submission.status == VerificationStatus.Rejected, "VerificationOracle: Invalid status");
    
    Dispute storage dispute = disputes[nextDisputeId];
    dispute.evidenceId = evidenceId;
    dispute.challenger = msg.sender;
    dispute.reason = reason;
    dispute.evidence = evidence;
    dispute.fee = msg.value;
    dispute.createdAt = block.timestamp;
    dispute.status = DisputeStatus.Pending;
    
    // Pause verification result
    submission.status = VerificationStatus.Disputed;
    
    emit DisputeCreated(nextDisputeId, evidenceId, msg.sender);
    nextDisputeId++;
}
```

### 5. AchievementNFT Contract

#### Purpose
ERC721 contract for minting and managing achievement badges as NFTs.

#### Key Features
- Achievement metadata on IPFS
- Rarity-based visual traits
- Transfer restrictions (soul-bound option)
- Batch minting capabilities
- Achievement verification

#### Main Functions

##### mintAchievement
```solidity
function mintAchievement(
    address to,
    string calldata tokenURI,
    Achievement calldata achievement
) external onlyRole(MINTER_ROLE) returns (uint256) {
    require(to != address(0), "AchievementNFT: Invalid recipient");
    require(bytes(tokenURI).length > 0, "AchievementNFT: Invalid URI");
    
    // Mint NFT
    uint256 tokenId = _tokenIdCounter.current();
    _tokenIdCounter.increment();
    _safeMint(to, tokenId);
    
    // Set token URI
    _setTokenURI(tokenId, tokenURI);
    
    // Store achievement metadata
    achievements[tokenId] = achievement;
    
    emit AchievementMinted(to, tokenId, achievement);
    
    return tokenId;
}
```

##### verifyAchievement
```solidity
function verifyAchievement(uint256 tokenId) external view returns (bool) {
    require(_exists(tokenId), "AchievementNFT: Token does not exist");
    
    Achievement storage achievement = achievements[tokenId];
    
    // Verify achievement is valid
    return achievement.questAddress != address(0) &&
           achievement.earnedAt > 0 &&
           achievement.earner != address(0);
}
```

##### Batch Operations
```solidity
function batchMint(
    address[] calldata recipients,
    string[] calldata tokenURIs,
    Achievement[] calldata achievements
) external onlyRole(MINTER_ROLE) {
    require(recipients.length == tokenURIs.length && 
           tokenURIs.length == achievements.length, "AchievementNFT: Array length mismatch");
    
    for (uint256 i = 0; i < recipients.length; i++) {
        mintAchievement(recipients[i], tokenURIs[i], achievements[i]);
    }
}
```

### 6. GovernanceToken Contract

#### Purpose
ERC20 governance token for platform voting, staking, and reward distribution.

#### Key Features
- Governance voting rights
- Staking rewards
- Platform fee discounts
- Anti-manipulation measures
- Vesting schedules

#### Main Functions

##### stake
```solidity
function stake(uint256 amount) external {
    require(amount > 0, "GovernanceToken: Invalid amount");
    require(balanceOf(msg.sender) >= amount, "GovernanceToken: Insufficient balance");
    
    // Transfer tokens to contract
    _transfer(msg.sender, address(this), amount);
    
    // Update stake
    StakeInfo storage stakeInfo = stakes[msg.sender];
    stakeInfo.amount += amount;
    stakeInfo.lastStakeTime = block.timestamp;
    
    // Calculate and update voting power
    _updateVotingPower(msg.sender);
    
    emit Staked(msg.sender, amount);
}
```

##### vote
```solidity
function vote(
    address proposal,
    bool support,
    uint256 votingPower
) external {
    require(votingPower <= getVotingPower(msg.sender), "GovernanceToken: Insufficient voting power");
    require(!hasVoted[proposal][msg.sender], "GovernanceToken: Already voted");
    
    // Record vote
    hasVoted[proposal][msg.sender] = true;
    votes[proposal][msg.sender] = Vote({
        support: support,
        votingPower: votingPower,
        timestamp: block.timestamp
    });
    
    // Update proposal tallies
    if (support) {
        proposalSupport[proposal] += votingPower;
    } else {
        proposalAgainst[proposal] += votingPower;
    }
    
    emit VoteCast(msg.sender, proposal, support, votingPower);
}
```

## Contract Interactions

### Quest Creation Flow
```
1. User calls QuestFactory.createQuest()
2. Factory creates quest clone using EIP-1167
3. Factory initializes quest with parameters
4. Quest registers with RewardPool
5. Quest registers with VerificationOracle
6. Factory emits QuestCreated event
```

### Quest Participation Flow
```
1. User calls Quest.joinQuest() with stake
2. Quest validates participation requirements
3. Quest calls RewardPool.stake()
4. Quest adds participant to list
5. Quest emits ParticipantJoined event
```

### Evidence Submission Flow
```
1. User calls Quest.submitEvidence()
2. Quest validates evidence format
3. Quest stores evidence hash on-chain
4. Quest uploads evidence to IPFS
5. Quest calls VerificationOracle.requestVerification()
6. Oracle assigns validators
7. Oracle emits VerificationRequested event
```

### Verification Flow
```
1. Validators call VerificationOracle.castVote()
2. Oracle calculates weighted voting power
3. Oracle updates vote tallies
4. Oracle checks threshold conditions
5. Oracle processes verification result
6. Oracle calls Quest.completeMilestone() if approved
7. Oracle distributes validator rewards
```

## Security Considerations

### 1. Access Control
- OpenZeppelin AccessControl for role-based permissions
- Multi-signature for critical operations
- Time locks for sensitive changes
- Emergency pause functionality

### 2. Reentrancy Protection
- OpenZeppelin ReentrancyGuard on all external functions
- Checks-Effects-Interactions pattern
- Limited external calls

### 3. Input Validation
- Comprehensive input validation on all functions
- Overflow/underflow protection (Solidity 0.8+)
- Address validation (not zero address)
- Parameter bounds checking

### 4. Economic Security
- Slashing mechanisms for malicious behavior
- Stake requirements for participation
- Reward calculation with safety checks
- Emergency withdrawal options

### 5. Oracle Security
- Decentralized validator selection
- Reputation-based voting power
- Dispute resolution mechanisms
- Anti-collusion measures

## Gas Optimization

### 1. Storage Optimization
- Packed structs for efficient storage
- Minimal on-chain data storage
- IPFS for metadata storage
- Event-based off-chain storage

### 2. Contract Patterns
- EIP-1167 minimal proxy for quest contracts
- Factory pattern for deployment efficiency
- Batch operations for multiple actions
- Lazy initialization where possible

### 3. Algorithm Optimization
- Efficient iteration patterns
- Early returns for validation
- Minimal external calls
- Optimized data structures

## Upgrade Strategy

### 1. Proxy Pattern
- OpenZeppelin Transparent Proxy
- Upgradeable implementation contracts
- Admin role for upgrade management
- Storage compatibility checks

### 2. Governance
- Token holder voting for upgrades
- Time delay for implementation
- Emergency upgrade procedures
- Rollback capabilities

### 3. Migration Planning
- Data migration scripts
- State transition handling
- User notification systems
- Backward compatibility

## Testing Strategy

### 1. Unit Tests
- Function-level testing with Foundry
- Edge case coverage
- Gas usage analysis
- Error condition testing

### 2. Integration Tests
- Contract interaction testing
- End-to-end quest flows
- Cross-contract functionality
- Event emission verification

### 3. Security Tests
- Reentrancy attack simulation
- Access control testing
- Economic manipulation testing
- Oracle attack scenarios

## Deployment

### 1. Testnet Deployment
- Base Sepolia testnet
- Comprehensive testing
- Community feedback
- Security audits

### 2. Mainnet Deployment
- Base mainnet
- Gradual rollout
- Monitoring systems
- Emergency procedures

### 3. Verification
- Etherscan contract verification
- Source code publication
- ABI documentation
- Contract interaction guides

This smart contract documentation provides comprehensive information for developers working with ChainQuest contracts. For specific implementation details, refer to the contract source code and test suites.
