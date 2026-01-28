// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title GovernanceToken
 * @notice ERC20 governance token for ChainQuest platform
 * @dev Implements voting, staking, and governance features
 */
contract GovernanceToken is ERC20, ERC20Votes, ERC20Permit, AccessControl, Pausable, ReentrancyGuard {
    // ========== Constants ==========
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    uint256 public constant MAX_SUPPLY = 1000000000 * 10**18; // 1 billion tokens
    uint256 public constant INITIAL_SUPPLY = 100000000 * 10**18; // 100 million tokens
    uint256 public constant STAKING_REWARD_RATE = 1000; // 10% annual rate
    uint256 public constant MIN_STAKE_AMOUNT = 100 * 10**18; // 100 tokens
    uint256 public constant MAX_STAKE_AMOUNT = 10000000 * 10**18; // 10 million tokens
    uint256 public constant UNSTAKING_PERIOD = 7 days;
    uint256 public constant PROPOSAL_THRESHOLD = 1000000 * 10**18; // 1 million tokens
    uint256 public constant QUORUM_THRESHOLD = 5000000 * 10**18; // 5 million tokens
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant EXECUTION_DELAY = 2 days;
    uint256 public constant BASIS_POINTS = 10000;

    // ========== Structs ==========
    
    struct Stake {
        address staker;
        uint256 amount;
        uint256 stakedAt;
        uint256 lockedUntil;
        uint256 rewardDebt;
        uint256 votingPower;
        bool active;
        uint256[] proposalVotes; // Track proposals voted on
    }
    
    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        uint256[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
        uint256 startBlock;
        uint256 endBlock;
        uint256 executionBlock;
        bool executed;
        bool canceled;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        mapping(address => bool) hasVoted;
        mapping(address => uint8) voteType; // 0: against, 1: for, 2: abstain
        address[] voters;
    }
    
    struct StakingReward {
        uint256 totalRewards;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
        mapping(address => uint256) userRewardPerTokenPaid;
        mapping(address => uint256) rewards;
    }
    
    struct GovernanceStats {
        uint256 totalStaked;
        uint256 totalVotingPower;
        uint256 activeProposals;
        uint256 executedProposals;
        uint256 totalProposals;
        uint256 participationRate;
    }

    // ========== State Variables ==========
    
    // Token distribution
    mapping(address => uint256) public tokenBalances;
    uint256 public totalMinted;
    uint256 public totalBurned;
    
    // Staking
    mapping(address => Stake) public stakes;
    mapping(address => uint256[]) public userStakeHistory;
    uint256 public totalStaked;
    uint256 public totalVotingPower;
    uint256 public nextStakeId;
    
    // Staking rewards
    StakingReward public stakingRewards;
    mapping(address => uint256) public userStakingRewards;
    
    // Governance
    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256[]) public userProposals;
    uint256 public nextProposalId;
    uint256 public proposalCount;
    
    // Timelock
    mapping(bytes32 => bool) public queuedTransactions;
    uint256 public timelockDelay = EXECUTION_DELAY;
    
    // Delegation
    mapping(address => address) public delegations;
    mapping(address => uint256) public delegationVotes;
    
    // Vesting
    mapping(address => VestingSchedule) public vestingSchedules;
    
    // Statistics
    GovernanceStats public governanceStats;
    
    // ========== Events ==========
    
    event TokensMinted(
        address indexed to,
        uint256 amount,
        uint256 timestamp
    );
    
    event TokensBurned(
        address indexed from,
        uint256 amount,
        uint256 timestamp
    );
    
    event Staked(
        address indexed staker,
        uint256 amount,
        uint256 lockedUntil,
        uint256 timestamp
    );
    
    event Unstaked(
        address indexed staker,
        uint256 amount,
        uint256 reward,
        uint256 timestamp
    );
    
    event RewardClaimed(
        address indexed staker,
        uint256 rewardAmount,
        uint256 timestamp
    );
    
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        uint256 startBlock,
        uint256 endBlock
    );
    
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        uint8 voteType,
        uint256 votingPower,
        uint256 timestamp
    );
    
    event ProposalExecuted(
        uint256 indexed proposalId,
        uint256 executedBlock
    );
    
    event ProposalCanceled(
        uint256 indexed proposalId,
        uint256 canceledBlock
    );
    
    event Delegated(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 timestamp
    );
    
    event Undelegated(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 timestamp
    );
    
    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 duration,
        uint256 cliff
    );
    
    event VestingScheduleClaimed(
        address indexed beneficiary,
        uint256 amount,
        uint256 timestamp
    );

    // ========== Errors ==========
    
    error GovernanceToken__InvalidAddress();
    error GovernanceToken__InvalidAmount();
    error GovernanceToken__InsufficientBalance();
    error GovernanceToken__InsufficientStake();
    error GovernanceToken__Unauthorized();
    error GovernanceToken__MaxSupplyReached();
    error GovernanceToken__StakeNotFound();
    error GovernanceToken__StakeNotActive();
    error GovernanceToken__UnstakingPeriodNotMet();
    error GovernanceToken__ProposalNotFound();
    error GovernanceToken__ProposalNotActive();
    error GovernanceToken__AlreadyVoted();
    error GovernanceToken__VotingPeriodEnded();
    error GovernanceToken__InsufficientVotingPower();
    error GovernanceToken__ExecutionDelayNotMet();
    error GovernanceToken__TransactionAlreadyQueued();
    error GovernanceToken__TransferFailed();

    // ========== Modifiers ==========
    
    modifier onlyMinter() {
        if (!hasRole(MINTER_ROLE, msg.sender) && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert GovernanceToken__Unauthorized();
        }
        _;
    }
    
    modifier onlyGovernance() {
        if (!hasRole(GOVERNANCE_ROLE, msg.sender) && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert GovernanceToken__Unauthorized();
        }
        _;
    }
    
    modifier onlyEmergencyRole() {
        if (!hasRole(EMERGENCY_ROLE, msg.sender)) {
            revert GovernanceToken__Unauthorized();
        }
        _;
    }
    
    modifier validAddress(address addr) {
        if (addr == address(0)) {
            revert GovernanceToken__InvalidAddress();
        }
        _;
    }
    
    modifier validAmount(uint256 amount) {
        if (amount == 0) {
            revert GovernanceToken__InvalidAmount();
        }
        _;
    }
    
    modifier sufficientBalance(address account, uint256 amount) {
        if (balanceOf(account) < amount) {
            revert GovernanceToken__InsufficientBalance();
        }
        _;
    }
    
    modifier activeStake(address staker) {
        if (!stakes[staker].active) {
            revert GovernanceToken__StakeNotActive();
        }
        _;
    }
    
    modifier validProposal(uint256 proposalId) {
        if (proposalId >= nextProposalId || proposals[proposalId].proposer == address(0)) {
            revert GovernanceToken__ProposalNotFound();
        }
        _;
    }
    
    modifier proposalActive(uint256 proposalId) {
        Proposal storage proposal = proposals[proposalId];
        if (block.number < proposal.startBlock || block.number > proposal.endBlock) {
            revert GovernanceToken__ProposalNotActive();
        }
        if (proposal.executed || proposal.canceled) {
            revert GovernanceToken__ProposalNotActive();
        }
        _;
    }

    // ========== Constructor ==========
    
    constructor(
        string memory name,
        string memory symbol,
        address initialOwner
    ) ERC20(name, symbol) ERC20Permit(name) validAddress(initialOwner) {
        // Mint initial supply
        _mint(initialOwner, INITIAL_SUPPLY);
        totalMinted = INITIAL_SUPPLY;
        
        // Initialize staking rewards
        stakingRewards.rewardRate = STAKING_REWARD_RATE;
        stakingRewards.lastUpdateTime = block.timestamp;
        
        // Initialize governance stats
        governanceStats = GovernanceStats({
            totalStaked: 0,
            totalVotingPower: 0,
            activeProposals: 0,
            executedProposals: 0,
            totalProposals: 0,
            participationRate: 0
        });
        
        nextStakeId = 1;
        nextProposalId = 1;
        
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        _grantRole(MINTER_ROLE, initialOwner);
        _grantRole(GOVERNANCE_ROLE, initialOwner);
        _grantRole(EMERGENCY_ROLE, initialOwner);
        
        emit TokensMinted(initialOwner, INITIAL_SUPPLY, block.timestamp);
    }

    // ========== Token Functions ==========
    
    /**
     * @notice Mints new tokens
     * @param to Address to mint to
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount)
        external
        onlyMinter
        validAddress(to)
        validAmount(amount)
    {
        if (totalMinted + amount > MAX_SUPPLY) {
            revert GovernanceToken__MaxSupplyReached();
        }
        
        _mint(to, amount);
        totalMinted += amount;
        
        emit TokensMinted(to, amount, block.timestamp);
    }
    
    /**
     * @notice Burns tokens
     * @param amount Amount to burn
     */
    function burn(uint256 amount)
        external
        validAmount(amount)
        sufficientBalance(msg.sender, amount)
    {
        _burn(msg.sender, amount);
        totalBurned += amount;
        
        emit TokensBurned(msg.sender, amount, block.timestamp);
    }
    
    /**
     * @notice Burns tokens from specified address
     * @param from Address to burn from
     * @param amount Amount to burn
     */
    function burnFrom(address from, uint256 amount)
        external
        validAmount(amount)
        sufficientBalance(from, amount)
    {
        uint256 currentAllowance = allowance(from, msg.sender);
        if (currentAllowance < amount) {
            revert GovernanceToken__InsufficientBalance();
        }
        
        _approve(from, msg.sender, currentAllowance - amount);
        _burn(from, amount);
        totalBurned += amount;
        
        emit TokensBurned(from, amount, block.timestamp);
    }

    // ========== Staking Functions ==========
    
    /**
     * @notice Stakes tokens for voting and rewards
     * @param amount Amount to stake
     * @param lockDuration Duration to lock tokens
     */
    function stake(uint256 amount, uint256 lockDuration)
        external
        nonReentrant
        whenNotPaused
        validAmount(amount)
        sufficientBalance(msg.sender, amount)
    {
        if (amount < MIN_STAKE_AMOUNT || amount > MAX_STAKE_AMOUNT) {
            revert GovernanceToken__InsufficientStake();
        }
        
        Stake storage userStake = stakes[msg.sender];
        
        if (userStake.active) {
            // Add to existing stake
            userStake.amount += amount;
            userStake.votingPower += _calculateVotingPower(amount);
        } else {
            // Create new stake
            userStake.staker = msg.sender;
            userStake.amount = amount;
            userStake.stakedAt = block.timestamp;
            userStake.lockedUntil = block.timestamp + lockDuration;
            userStake.rewardDebt = 0;
            userStake.votingPower = _calculateVotingPower(amount);
            userStake.active = true;
        }
        
        // Update rewards
        _updateStakingRewards(msg.sender);
        
        // Update global stats
        totalStaked += amount;
        totalVotingPower += userStake.votingPower;
        governanceStats.totalStaked = totalStaked;
        governanceStats.totalVotingPower = totalVotingPower;
        
        // Transfer tokens to contract
        _transfer(msg.sender, address(this), amount);
        
        emit Staked(msg.sender, amount, userStake.lockedUntil, block.timestamp);
    }
    
    /**
     * @notice Unstakes tokens
     * @param amount Amount to unstake
     */
    function unstake(uint256 amount)
        external
        nonReentrant
        whenNotPaused
        validAmount(amount)
        activeStake(msg.sender)
    {
        Stake storage userStake = stakes[msg.sender];
        
        if (amount > userStake.amount) {
            revert GovernanceToken__InsufficientBalance();
        }
        
        if (block.timestamp < userStake.lockedUntil) {
            revert GovernanceToken__UnstakingPeriodNotMet();
        }
        
        // Calculate rewards
        uint256 rewardAmount = _calculateStakingReward(msg.sender);
        
        // Update stake
        userStake.amount -= amount;
        userStake.votingPower -= _calculateVotingPower(amount);
        
        if (userStake.amount == 0) {
            userStake.active = false;
        }
        
        // Update rewards
        _updateStakingRewards(msg.sender);
        userStakingRewards[msg.sender] += rewardAmount;
        
        // Update global stats
        totalStaked -= amount;
        totalVotingPower -= _calculateVotingPower(amount);
        governanceStats.totalStaked = totalStaked;
        governanceStats.totalVotingPower = totalVotingPower;
        
        // Transfer tokens back
        _transfer(address(this), msg.sender, amount);
        
        // Transfer rewards
        if (rewardAmount > 0) {
            _transfer(address(this), msg.sender, rewardAmount);
        }
        
        emit Unstaked(msg.sender, amount, rewardAmount, block.timestamp);
    }
    
    /**
     * @notice Claims staking rewards
     */
    function claimRewards()
        external
        nonReentrant
        whenNotPaused
        activeStake(msg.sender)
    {
        uint256 rewardAmount = userStakingRewards[msg.sender];
        
        if (rewardAmount == 0) {
            revert GovernanceToken__InvalidAmount();
        }
        
        // Reset rewards
        userStakingRewards[msg.sender] = 0;
        
        // Transfer rewards
        _transfer(address(this), msg.sender, rewardAmount);
        
        emit RewardClaimed(msg.sender, rewardAmount, block.timestamp);
    }

    // ========== Governance Functions ==========
    
    /**
     * @notice Creates a new proposal
     * @param targets Target addresses
     * @param values ETH values to send
     * @param signatures Function signatures
     * @param calldatas Function calldata
     * @param title Proposal title
     * @param description Proposal description
     * @return proposalId ID of the created proposal
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory title,
        string memory description
    )
        external
        nonReentrant
        whenNotPaused
        returns (uint256 proposalId)
    {
        // Check proposal threshold
        if (getVotes(msg.sender, block.number - 1) < PROPOSAL_THRESHOLD) {
            revert GovernanceToken__InsufficientVotingPower();
        }
        
        // Create proposal
        proposalId = nextProposalId++;
        Proposal storage proposal = proposals[proposalId];
        
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.title = title;
        proposal.description = description;
        proposal.targets = targets;
        proposal.values = values;
        proposal.signatures = signatures;
        proposal.calldatas = calldatas;
        proposal.startBlock = block.number + 1;
        proposal.endBlock = block.number + VOTING_PERIOD;
        proposal.executionBlock = proposal.endBlock + timelockDelay;
        proposal.executed = false;
        proposal.canceled = false;
        
        // Update mappings
        userProposals[msg.sender].push(proposalId);
        proposalCount++;
        governanceStats.totalProposals = proposalCount;
        governanceStats.activeProposals++;
        
        emit ProposalCreated(proposalId, msg.sender, title, proposal.startBlock, proposal.endBlock);
        
        return proposalId;
    }
    
    /**
     * @notice Casts a vote on a proposal
     * @param proposalId ID of the proposal
     * @param support Whether to support the proposal
     * @param reason Voting reason
     */
    function castVote(
        uint256 proposalId,
        bool support,
        string calldata reason
    )
        external
        nonReentrant
        whenNotPaused
        validProposal(proposalId)
        proposalActive(proposalId)
    {
        Proposal storage proposal = proposals[proposalId];
        
        if (proposal.hasVoted[msg.sender]) {
            revert GovernanceToken__AlreadyVoted();
        }
        
        uint256 votingPower = getVotes(msg.sender, proposal.startBlock - 1);
        
        if (votingPower == 0) {
            revert GovernanceToken__InsufficientVotingPower();
        }
        
        // Record vote
        proposal.hasVoted[msg.sender] = true;
        proposal.voters.push(msg.sender);
        
        uint8 voteType = support ? 1 : 0;
        proposal.voteType[msg.sender] = voteType;
        
        if (support) {
            proposal.forVotes += votingPower;
        } else {
            proposal.againstVotes += votingPower;
        }
        
        // Update stake voting history
        if (stakes[msg.sender].active) {
            stakes[msg.sender].proposalVotes.push(proposalId);
        }
        
        emit VoteCast(proposalId, msg.sender, voteType, votingPower, block.timestamp);
    }
    
    /**
     * @notice Executes a proposal
     * @param proposalId ID of the proposal
     */
    function execute(uint256 proposalId)
        external
        nonReentrant
        whenNotPaused
        validProposal(proposalId)
    {
        Proposal storage proposal = proposals[proposalId];
        
        if (proposal.executed || proposal.canceled) {
            revert GovernanceToken__ProposalNotActive();
        }
        
        if (block.number <= proposal.endBlock) {
            revert GovernanceToken__VotingPeriodEnded();
        }
        
        if (block.number < proposal.executionBlock) {
            revert GovernanceToken__ExecutionDelayNotMet();
        }
        
        // Check quorum
        if (proposal.forVotes + proposal.againstVotes < QUORUM_THRESHOLD) {
            revert GovernanceToken__InsufficientVotingPower();
        }
        
        // Check if proposal passed
        if (proposal.forVotes <= proposal.againstVotes) {
            revert GovernanceToken__ProposalNotActive();
        }
        
        // Execute proposal
        proposal.executed = true;
        governanceStats.activeProposals--;
        governanceStats.executedProposals++;
        
        // Execute transactions
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            (bool success, ) = proposal.targets[i].call{value: proposal.values[i]}(
                abi.encodePacked(
                    bytes4(keccak256(bytes(proposal.signatures[i]))),
                    proposal.calldatas[i]
                )
            );
            
            if (!success) {
                revert GovernanceToken__TransferFailed();
            }
        }
        
        emit ProposalExecuted(proposalId, block.number);
    }
    
    /**
     * @notice Cancels a proposal
     * @param proposalId ID of the proposal
     */
    function cancel(uint256 proposalId)
        external
        nonReentrant
        onlyGovernance
        validProposal(proposalId)
    {
        Proposal storage proposal = proposals[proposalId];
        
        if (proposal.executed || proposal.canceled) {
            revert GovernanceToken__ProposalNotActive();
        }
        
        proposal.canceled = true;
        governanceStats.activeProposals--;
        
        emit ProposalCanceled(proposalId, block.number);
    }

    // ========== Delegation Functions ==========
    
    /**
     * @notice Delegates voting power to another address
     * @param to Address to delegate to
     */
    function delegate(address to)
        external
        validAddress(to)
    {
        address currentDelegate = delegations[msg.sender];
        
        if (currentDelegate != address(0)) {
            delegationVotes[currentDelegate] -= getVotes(msg.sender, block.number - 1);
        }
        
        delegations[msg.sender] = to;
        delegationVotes[to] += getVotes(msg.sender, block.number - 1);
        
        emit Delegated(msg.sender, to, getVotes(msg.sender, block.number), block.timestamp);
    }
    
    /**
     * @notice Undelegates voting power
     */
    function undelegate()
        external
    {
        address currentDelegate = delegations[msg.sender];
        
        if (currentDelegate != address(0)) {
            delegationVotes[currentDelegate] -= getVotes(msg.sender, block.number - 1);
            delete delegations[msg.sender];
            
            emit Undelegated(msg.sender, currentDelegate, getVotes(msg.sender, block.number), block.timestamp);
        }
    }

    // ========== View Functions ==========
    
    /**
     * @notice Gets stake information
     * @param staker Address of the staker
     * @return Stake information
     */
    function getStake(address staker)
        external
        view
        returns (
            uint256 amount,
            uint256 stakedAt,
            uint256 lockedUntil,
            uint256 rewardDebt,
            uint256 votingPower,
            bool active
        )
    {
        Stake storage s = stakes[staker];
        return (
            s.amount,
            s.stakedAt,
            s.lockedUntil,
            s.rewardDebt,
            s.votingPower,
            s.active
        );
    }
    
    /**
     * @notice Gets proposal information
     * @param proposalId ID of the proposal
     * @return Proposal information
     */
    function getProposal(uint256 proposalId)
        external
        view
        validProposal(proposalId)
        returns (
            address proposer,
            string memory title,
            string memory description,
            uint256 startBlock,
            uint256 endBlock,
            uint256 executionBlock,
            bool executed,
            bool canceled,
            uint256 forVotes,
            uint256 againstVotes,
            uint256 abstainVotes
        )
    {
        Proposal storage p = proposals[proposalId];
        return (
            p.proposer,
            p.title,
            p.description,
            p.startBlock,
            p.endBlock,
            p.executionBlock,
            p.executed,
            p.canceled,
            p.forVotes,
            p.againstVotes,
            p.abstainVotes
        );
    }
    
    /**
     * @notice Gets user's proposals
     * @param user Address of the user
     * @return Array of proposal IDs
     */
    function getUserProposals(address user) external view returns (uint256[] memory) {
        return userProposals[user];
    }
    
    /**
     * @notice Gets user's voting power
     * @param user Address of the user
     * @param blockNumber Block number to check
     * @return Voting power
     */
    function getVotingPower(address user, uint256 blockNumber) external view returns (uint256) {
        return getVotes(user, blockNumber);
    }
    
    /**
     * @notice Gets staking reward amount
     * @param staker Address of the staker
     * @return Reward amount
     */
    function getStakingReward(address staker) external view returns (uint256) {
        return _calculateStakingReward(staker) + userStakingRewards[staker];
    }
    
    /**
     * @notice Gets governance statistics
     * @return Governance statistics
     */
    function getGovernanceStats() external view returns (GovernanceStats memory) {
        return governanceStats;
    }
    
    /**
     * @notice Gets total supply
     * @return Total supply
     */
    function getTotalSupply() external view returns (uint256) {
        return totalSupply();
    }
    
    /**
     * @notice Gets total minted
     * @return Total minted
     */
    function getTotalMinted() external view returns (uint256) {
        return totalMinted;
    }
    
    /**
     * @notice Gets total burned
     * @return Total burned
     */
    function getTotalBurned() external view returns (uint256) {
        return totalBurned;
    }

    // ========== Internal Functions ==========
    
    function _calculateVotingPower(uint256 amount) internal pure returns (uint256) {
        // Simple 1:1 voting power, can be enhanced with multipliers
        return amount;
    }
    
    function _updateStakingRewards(address staker) internal {
        Stake storage userStake = stakes[staker];
        
        if (userStake.amount > 0) {
            uint256 rewardAmount = _calculateStakingReward(staker);
            userStake.rewardDebt += rewardAmount;
        }
    }
    
    function _calculateStakingReward(address staker) internal view returns (uint256) {
        Stake storage userStake = stakes[staker];
        
        if (!userStake.active || userStake.amount == 0) {
            return 0;
        }
        
        uint256 stakingDuration = block.timestamp - userStake.stakedAt;
        uint256 annualReward = (userStake.amount * stakingRewards.rewardRate) / BASIS_POINTS;
        uint256 reward = (annualReward * stakingDuration) / (365 days);
        
        return reward;
    }
    
    // ========== Override Functions ==========
    
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20) {
        if (from != address(0) && to != address(0)) {
            // Update voting power for transfers
            _moveDelegates(from, to, amount);
        }
        super._beforeTokenTransfer(from, to, amount);
    }
    
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20) {
        // Update token balances
        if (from != address(0)) {
            tokenBalances[from] -= amount;
        }
        if (to != address(0)) {
            tokenBalances[to] += amount;
        }
        super._afterTokenTransfer(from, to, amount);
    }
    
    function _mint(address to, uint256 amount) internal override(ERC20) {
        super._mint(to, amount);
        tokenBalances[to] += amount;
    }
    
    function _burn(address from, uint256 amount) internal override(ERC20) {
        super._burn(from, amount);
        tokenBalances[from] -= amount;
    }

    // ========== Admin Functions ==========
    
    /**
     * @notice Updates staking reward rate
     * @param newRate New reward rate
     */
    function updateStakingRewardRate(uint256 newRate)
        external
        onlyGovernance
    {
        stakingRewards.rewardRate = newRate;
    }
    
    /**
     * @notice Updates timelock delay
     * @param newDelay New delay
     */
    function updateTimelockDelay(uint256 newDelay)
        external
        onlyGovernance
    {
        timelockDelay = newDelay;
    }
    
    /**
     * @notice Updates proposal threshold
     * @param newThreshold New threshold
     */
    function updateProposalThreshold(uint256 newThreshold)
        external
        onlyGovernance
    {
        PROPOSAL_THRESHOLD = newThreshold;
    }
    
    /**
     * @notice Updates quorum threshold
     * @param newThreshold New threshold
     */
    function updateQuorumThreshold(uint256 newThreshold)
        external
        onlyGovernance
    {
        QUORUM_THRESHOLD = newThreshold;
    }
    
    /**
     * @notice Pauses the contract (emergency only)
     */
    function pause() external onlyEmergencyRole {
        _pause();
    }
    
    /**
     * @notice Unpauses the contract
     */
    function unpause() external onlyEmergencyRole {
        _unpause();
    }
}

// ========== Vesting Schedule Struct ==========
struct VestingSchedule {
    uint256 totalAmount;
    uint256 startTime;
    uint256 duration;
    uint256 cliff;
    uint256 claimedAmount;
    bool active;
}
