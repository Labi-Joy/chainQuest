// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title VerificationOracle
 * @notice Decentralized verification system for quest evidence
 * @dev Manages validators, voting, and dispute resolution
 */
contract VerificationOracle is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ========== Constants ==========
    bytes32 public constant ORACLE_ADMIN_ROLE = keccak256("ORACLE_ADMIN_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    uint256 public constant MIN_VALIDATOR_STAKE = 100 ether;
    uint256 public constant MIN_REPUTATION = 100;
    uint256 public constant MAX_REPUTATION = 10000;
    uint256 public constant DEFAULT_VERIFICATION_THRESHOLD = 3;
    uint256 public constant MAX_VOTING_POWER = 5000; // 5x max multiplier
    uint256 public constant DISPUTE_FEE = 1 ether;
    uint256 public constant REWARD_BASIS_POINTS = 10000;
    uint256 public constant BASE_VOTING_POWER = 1000;
    uint256 public constant ACTIVITY_BONUS_MAX = 1000; // 10% max activity bonus
    
    // ========== Enums ==========
    
    enum VerificationType {
        Community,  // Community voting
        Oracle,     // Oracle validation
        Automated   // Automated verification
    }
    
    enum VerificationStatus {
        Pending,
        Approved,
        Rejected,
        Disputed,
        Expired
    }
    
    enum DisputeStatus {
        Pending,
        UnderReview,
        Resolved,
        Rejected
    }
    
    enum ValidatorStatus {
        Registered,
        Active,
        Suspended,
        Slashed
    }

    // ========== Structs ==========
    
    struct Validator {
        address validatorAddress;
        uint256 stakeAmount;
        uint256 reputationScore;
        uint256 totalVotes;
        uint256 correctVotes;
        uint256 totalEarnings;
        uint256 registeredAt;
        uint256 lastActivity;
        ValidatorStatus status;
        uint256[] voteHistory;
        mapping(address => bool) canValidate;
    }
    
    struct Evidence {
        uint256 id;
        address quest;
        address submitter;
        uint256 milestoneId;
        string ipfsHash;
        bytes32 evidenceHash;
        VerificationType verificationType;
        uint256 verificationThreshold;
        uint256 submittedAt;
        uint256 deadline;
        VerificationStatus status;
        uint256 totalVotes;
        uint256 approvalVotes;
        uint256 rejectionVotes;
        uint256 confidenceScore;
        address[] assignedValidators;
        mapping(address => Vote) votes;
        mapping(address => bool) hasVoted;
    }
    
    struct Vote {
        address validator;
        bool approve;
        uint256 confidence;
        string reasoning;
        uint256 votingPower;
        uint256 votedAt;
        bool valid;
    }
    
    struct Dispute {
        uint256 id;
        uint256 evidenceId;
        address challenger;
        string reason;
        string evidence;
        uint256 fee;
        uint256 createdAt;
        uint256 deadline;
        DisputeStatus status;
        address[] reviewers;
        mapping(address => bool) hasReviewed;
        uint256 approvalVotes;
        uint256 rejectionVotes;
        uint256 resolutionVotes;
    }
    
    struct VerificationRequest {
        uint256 evidenceId;
        VerificationType verificationType;
        uint256 threshold;
        uint256 requestedAt;
        uint256 assignedValidators;
        uint256 requiredValidators;
    }

    // ========== State Variables ==========
    
    // Validator management
    mapping(address => Validator) public validators;
    address[] public validatorList;
    mapping(address => bool) public isValidator;
    uint256 public totalValidators;
    uint256 public activeValidators;
    
    // Evidence verification
    mapping(uint256 => Evidence) public evidence;
    mapping(address => uint256[]) public validatorEvidence; // validator => evidenceIds
    mapping(address => uint256[]) public submitterEvidence; // submitter => evidenceIds
    uint256 public nextEvidenceId;
    
    // Dispute management
    mapping(uint256 => Dispute) public disputes;
    mapping(uint256 => uint256) public evidenceDisputes; // evidenceId => disputeId
    uint256 public nextDisputeId;
    
    // Verification requests
    mapping(uint256 => VerificationRequest) public verificationRequests;
    uint256[] public pendingRequests;
    
    // Reward pool
    address public rewardToken;
    uint256 public totalRewardPool;
    uint256 public totalRewardsDistributed;
    mapping(address => uint256) public validatorEarnings;
    
    // Oracle parameters
    uint256 public validatorStakeRequirement;
    uint256 public defaultVerificationThreshold;
    uint256 public verificationTimeout;
    uint256 public disputeTimeout;
    uint256 public reputationDecayRate;
    uint256 public activityWindow;
    
    // Statistics
    uint256 public totalVerifications;
    uint256 public totalDisputes;
    uint256 public averageVerificationTime;
    uint256 public successRate;
    
    // ========== Events ==========
    
    event ValidatorRegistered(
        address indexed validator,
        uint256 stakeAmount,
        uint256 reputationScore,
        uint256 registeredAt
    );
    
    event ValidatorSlashed(
        address indexed validator,
        uint256 slashAmount,
        uint256 reason,
        uint256 slashedAt
    );
    
    event ValidatorSuspended(
        address indexed validator,
        uint256 suspendedAt
    );
    
    event ValidatorReinstated(
        address indexed validator,
        uint256 reinstatedAt
    );
    
    event EvidenceSubmitted(
        uint256 indexed evidenceId,
        address indexed submitter,
        uint256 milestoneId,
        VerificationType verificationType,
        uint256 submittedAt
    );
    
    event VerificationRequested(
        uint256 indexed evidenceId,
        VerificationType verificationType,
        uint256 threshold,
        uint256 requestedAt
    );
    
    event VoteCast(
        uint256 indexed evidenceId,
        address indexed validator,
        bool approve,
        uint256 confidence,
        uint256 votingPower,
        uint256 votedAt
    );
    
    event VerificationCompleted(
        uint256 indexed evidenceId,
        VerificationStatus status,
        uint256 approvalVotes,
        uint256 rejectionVotes,
        uint256 completedAt
    );
    
    event DisputeCreated(
        uint256 indexed disputeId,
        uint256 indexed evidenceId,
        address indexed challenger,
        string reason,
        uint256 createdAt
    );
    
    event DisputeResolved(
        uint256 indexed disputeId,
        DisputeStatus status,
        uint256 resolutionVotes,
        uint256 resolvedAt
    );
    
    event RewardDistributed(
        address indexed validator,
        uint256 rewardAmount,
        uint256 distributedAt
    );
    
    event OracleParametersUpdated(
        uint256 validatorStakeRequirement,
        uint256 defaultVerificationThreshold,
        uint256 verificationTimeout
    );
    
    event ReputationUpdated(
        address indexed validator,
        uint256 oldReputation,
        uint256 newReputation,
        uint256 updatedAt
    );

    // ========== Errors ==========
    
    error VerificationOracle__InvalidAddress();
    error VerificationOracle__InvalidAmount();
    error VerificationOracle__InsufficientStake();
    error VerificationOracle__Unauthorized();
    error VerificationOracle__NotValidator();
    error VerificationOracle__ValidatorNotFound();
    error VerificationOracle__EvidenceNotFound();
    error VerificationOracle__DisputeNotFound();
    error VerificationOracle__AlreadyVoted();
    error VerificationOracle__VerificationExpired();
    error VerificationOracle__InvalidThreshold();
    error VerificationOracle__InsufficientReputation();
    error VerificationOracle__InvalidStatus();
    error VerificationOracle__TransferFailed();

    // ========== Modifiers ==========
    
    modifier onlyOracleAdmin() {
        if (!hasRole(ORACLE_ADMIN_ROLE, msg.sender) && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert VerificationOracle__Unauthorized();
        }
        _;
    }
    
    modifier onlyValidator() {
        if (!isValidator[msg.sender]) {
            revert VerificationOracle__NotValidator();
        }
        _;
    }
    
    modifier onlyEmergencyRole() {
        if (!hasRole(EMERGENCY_ROLE, msg.sender)) {
            revert VerificationOracle__Unauthorized();
        }
        _;
    }
    
    modifier validValidator(address validator) {
        if (!isValidator[validator]) {
            revert VerificationOracle__ValidatorNotFound();
        }
        _;
    }
    
    modifier validEvidence(uint256 evidenceId) {
        if (evidenceId >= nextEvidenceId || evidence[evidenceId].submitter == address(0)) {
            revert VerificationOracle__EvidenceNotFound();
        }
        _;
    }
    
    modifier validDispute(uint256 disputeId) {
        if (disputeId >= nextDisputeId || disputes[disputeId].challenger == address(0)) {
            revert VerificationOracle__DisputeNotFound();
        }
        _;
    }
    
    modifier activeValidator(address validator) {
        if (validators[validator].status != ValidatorStatus.Active) {
            revert VerificationOracle__InvalidStatus();
        }
        _;
    }

    // ========== Constructor ==========
    
    constructor(address _rewardToken) validAddress(_rewardToken) {
        rewardToken = _rewardToken;
        
        // Initialize parameters
        validatorStakeRequirement = MIN_VALIDATOR_STAKE;
        defaultVerificationThreshold = DEFAULT_VERIFICATION_THRESHOLD;
        verificationTimeout = 7 days;
        disputeTimeout = 3 days;
        reputationDecayRate = 100; // 1% decay per month
        activityWindow = 30 days;
        
        nextEvidenceId = 1;
        nextDisputeId = 1;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORACLE_ADMIN_ROLE, msg.sender);
        _grantRole(VALIDATOR_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);
    }

    // ========== Validator Management Functions ==========
    
    /**
     * @notice Registers as a validator
     * @param stakeAmount Amount to stake
     */
    function registerValidator(uint256 stakeAmount)
        external
        payable
        nonReentrant
        whenNotPaused
        validAmount(stakeAmount)
    {
        if (isValidator[msg.sender]) {
            revert VerificationOracle__AlreadyVoted();
        }
        
        if (stakeAmount < validatorStakeRequirement) {
            revert VerificationOracle__InsufficientStake();
        }
        
        // Transfer stake to contract
        uint256 actualAmount = _transferTokens(msg.sender, stakeAmount);
        
        // Create validator record
        Validator storage validator = validators[msg.sender];
        validator.validatorAddress = msg.sender;
        validator.stakeAmount = actualAmount;
        validator.reputationScore = MIN_REPUTATION;
        validator.totalVotes = 0;
        validator.correctVotes = 0;
        validator.totalEarnings = 0;
        validator.registeredAt = block.timestamp;
        validator.lastActivity = block.timestamp;
        validator.status = ValidatorStatus.Active;
        
        // Update mappings
        isValidator[msg.sender] = true;
        validatorList.push(msg.sender);
        totalValidators++;
        activeValidators++;
        
        // Update reward pool
        totalRewardPool += actualAmount;
        
        emit ValidatorRegistered(msg.sender, actualAmount, MIN_REPUTATION, block.timestamp);
    }
    
    /**
     * @notice Unregisters as a validator
     */
    function unregisterValidator()
        external
        nonReentrant
        onlyValidator
    {
        Validator storage validator = validators[msg.sender];
        
        if (validator.status != ValidatorStatus.Active) {
            revert VerificationOracle__InvalidStatus();
        }
        
        // Check for pending verifications
        if (validator.voteHistory.length > 0) {
            uint256 recentVotes = 0;
            uint256 cutoff = block.timestamp - activityWindow;
            
            for (uint256 i = validator.voteHistory.length - 1; i >= 0; i--) {
                if (evidence[validator.voteHistory[i]].submittedAt < cutoff) {
                    break;
                }
                recentVotes++;
            }
            
            if (recentVotes > 0) {
                revert VerificationOracle__InvalidStatus(); // Has recent activity
            }
        }
        
        // Update status
        validator.status = ValidatorStatus.Suspended;
        activeValidators--;
        
        // Return stake after cooldown period
        uint256 cooldownPeriod = 7 days;
        uint256 eligibleTime = validator.lastActivity + cooldownPeriod;
        
        if (block.timestamp >= eligibleTime) {
            _returnStake(msg.sender, validator.stakeAmount);
        }
    }
    
    /**
     * @notice Updates validator reputation
     * @param validator Address of the validator
     * @param newReputation New reputation score
     */
    function updateReputation(address validator, uint256 newReputation)
        external
        onlyOracleAdmin
        validValidator(validator)
    {
        if (newReputation < MIN_REPUTATION || newReputation > MAX_REPUTATION) {
            revert VerificationOracle__InvalidAmount();
        }
        
        Validator storage v = validators[validator];
        uint256 oldReputation = v.reputationScore;
        v.reputationScore = newReputation;
        
        emit ReputationUpdated(validator, oldReputation, newReputation, block.timestamp);
    }
    
    /**
     * @notice Slashes a validator for malicious behavior
     * @param validator Address of the validator to slash
     * @param slashPercentage Percentage to slash (in basis points)
     * @param reason Reason for slashing
     */
    function slashValidator(
        address validator,
        uint256 slashPercentage,
        string calldata reason
    )
        external
        onlyOracleAdmin
        validValidator(validator)
    {
        if (slashPercentage > REWARD_BASIS_POINTS) {
            revert VerificationOracle__InvalidAmount();
        }
        
        Validator storage v = validators[validator];
        
        uint256 slashAmount = (v.stakeAmount * slashPercentage) / REWARD_BASIS_POINTS;
        uint256 remainingStake = v.stakeAmount - slashAmount;
        
        // Update validator status
        v.status = ValidatorStatus.Slashed;
        v.stakeAmount = remainingStake;
        activeValidators--;
        
        // Transfer slash amount to treasury
        _transferTokens(address(this), slashAmount);
        
        emit ValidatorSlashed(validator, slashAmount, slashPercentage, block.timestamp);
    }

    // ========== Verification Functions ==========
    
    /**
     * @notice Requests verification for evidence
     * @param evidenceId ID of the evidence
     * @param verificationType Type of verification
     * @param threshold Verification threshold
     */
    function requestVerification(
        uint256 evidenceId,
        VerificationType verificationType,
        uint256 threshold
    )
        external
        nonReentrant
        whenNotPaused
        validEvidence(evidenceId)
    {
        Evidence storage e = evidence[evidenceId];
        
        if (e.status != VerificationStatus.Pending) {
            revert VerificationOracle__InvalidStatus();
        }
        
        // Set verification parameters
        e.verificationType = verificationType;
        e.verificationThreshold = threshold > 0 ? threshold : defaultVerificationThreshold;
        e.deadline = block.timestamp + verificationTimeout;
        
        // Create verification request
        verificationRequests[evidenceId] = VerificationRequest({
            evidenceId: evidenceId,
            verificationType: verificationType,
            threshold: e.verificationThreshold,
            requestedAt: block.timestamp,
            assignedValidators: 0,
            requiredValidators: e.verificationThreshold
        });
        
        pendingRequests.push(evidenceId);
        
        // Assign validators
        _assignValidators(evidenceId);
        
        emit VerificationRequested(evidenceId, verificationType, e.verificationThreshold, block.timestamp);
    }
    
    /**
     * @notice Casts a vote on evidence
     * @param evidenceId ID of the evidence
     * @param approve Whether to approve the evidence
     * @param confidence Confidence level (0-100)
     * @param reasoning Reasoning for the vote
     */
    function castVote(
        uint256 evidenceId,
        bool approve,
        uint256 confidence,
        string calldata reasoning
    )
        external
        nonReentrant
        whenNotPaused
        onlyValidator
        validEvidence(evidenceId)
        activeValidator(msg.sender)
    {
        Evidence storage e = evidence[evidenceId];
        
        if (e.status != VerificationStatus.Pending) {
            revert VerificationOracle__InvalidStatus();
        }
        
        if (block.timestamp > e.deadline) {
            revert VerificationOracle__VerificationExpired();
        }
        
        if (e.hasVoted[msg.sender]) {
            revert VerificationOracle__AlreadyVoted();
        }
        
        if (confidence > 100) {
            revert VerificationOracle__InvalidAmount();
        }
        
        // Calculate voting power
        uint256 votingPower = _calculateVotingPower(msg.sender);
        
        // Record vote
        Vote storage vote = e.votes[msg.sender];
        vote.validator = msg.sender;
        vote.approve = approve;
        vote.confidence = confidence;
        vote.reasoning = reasoning;
        vote.votingPower = votingPower;
        vote.votedAt = block.timestamp;
        vote.valid = true;
        
        e.hasVoted[msg.sender] = true;
        e.totalVotes++;
        
        if (approve) {
            e.approvalVotes += votingPower;
        } else {
            e.rejectionVotes += votingPower;
        }
        
        // Update validator stats
        Validator storage validator = validators[msg.sender];
        validator.totalVotes++;
        validator.lastActivity = block.timestamp;
        validator.voteHistory.push(evidenceId);
        
        // Add to validator evidence mapping
        validatorEvidence[msg.sender].push(evidenceId);
        
        emit VoteCast(evidenceId, msg.sender, approve, confidence, votingPower, block.timestamp);
        
        // Check if verification is complete
        if (e.totalVotes >= e.verificationThreshold) {
            _processVerificationResult(evidenceId);
        }
    }
    
    /**
     * @notice Creates a dispute for evidence verification
     * @param evidenceId ID of the evidence to dispute
     * @param reason Reason for the dispute
     * @param disputeEvidence Evidence supporting the dispute
     */
    function createDispute(
        uint256 evidenceId,
        string calldata reason,
        string calldata disputeEvidence
    )
        external
        payable
        nonReentrant
        whenNotPaused
        validEvidence(evidenceId)
    {
        Evidence storage e = evidence[evidenceId];
        
        if (e.status != VerificationStatus.Approved && e.status != VerificationStatus.Rejected) {
            revert VerificationOracle__InvalidStatus();
        }
        
        if (msg.value < DISPUTE_FEE) {
            revert VerificationOracle__InsufficientStake();
        }
        
        // Check if dispute already exists
        if (evidenceDisputes[evidenceId] > 0) {
            revert VerificationOracle__InvalidStatus();
        }
        
        // Create dispute
        uint256 disputeId = nextDisputeId++;
        Dispute storage dispute = disputes[disputeId];
        dispute.id = disputeId;
        dispute.evidenceId = evidenceId;
        dispute.challenger = msg.sender;
        dispute.reason = reason;
        dispute.evidence = disputeEvidence;
        dispute.fee = msg.value;
        dispute.createdAt = block.timestamp;
        dispute.deadline = block.timestamp + disputeTimeout;
        dispute.status = DisputeStatus.Pending;
        
        // Update mappings
        evidenceDisputes[evidenceId] = disputeId;
        
        // Update evidence status
        e.status = VerificationStatus.Disputed;
        
        // Assign reviewers
        _assignReviewers(disputeId);
        
        emit DisputeCreated(disputeId, evidenceId, msg.sender, reason, block.timestamp);
    }
    
    /**
     * @notice Resolves a dispute
     * @param disputeId ID of the dispute
     * @param approve Whether to approve the dispute
     * @param reasoning Reasoning for the resolution
     */
    function resolveDispute(
        uint256 disputeId,
        bool approve,
        string calldata reasoning
    )
        external
        nonReentrant
        onlyValidator
        validDispute(disputeId)
        activeValidator(msg.sender)
    {
        Dispute storage dispute = disputes[disputeId];
        
        if (dispute.status != DisputeStatus.Pending && dispute.status != DisputeStatus.UnderReview) {
            revert VerificationOracle__InvalidStatus();
        }
        
        if (block.timestamp > dispute.deadline) {
            revert VerificationOracle__VerificationExpired();
        }
        
        if (dispute.hasReviewed[msg.sender]) {
            revert VerificationOracle__AlreadyVoted();
        }
        
        // Record review
        dispute.hasReviewed[msg.sender] = true;
        dispute.resolutionVotes++;
        
        if (approve) {
            dispute.approvalVotes++;
        } else {
            dispute.rejectionVotes++;
        }
        
        // Check if dispute resolution is complete
        if (dispute.resolutionVotes >= 3) { // 3 reviewers required
            _processDisputeResult(disputeId);
        }
    }

    // ========== Admin Functions ==========
    
    /**
     * @notice Updates oracle parameters
     * @param _validatorStakeRequirement New validator stake requirement
     * @param _defaultVerificationThreshold New default verification threshold
     * @param _verificationTimeout New verification timeout
     */
    function updateOracleParameters(
        uint256 _validatorStakeRequirement,
        uint256 _defaultVerificationThreshold,
        uint256 _verificationTimeout
    )
        external
        onlyOracleAdmin
    {
        validatorStakeRequirement = _validatorStakeRequirement;
        defaultVerificationThreshold = _defaultVerificationThreshold;
        verificationTimeout = _verificationTimeout;
        
        emit OracleParametersUpdated(
            _validatorStakeRequirement,
            _defaultVerificationThreshold,
            _verificationTimeout
        );
    }
    
    /**
     * @notice Pauses the oracle (emergency only)
     */
    function pause() external onlyEmergencyRole {
        _pause();
    }
    
    /**
     * @notice Unpauses the oracle
     */
    function unpause() external onlyEmergencyRole {
        _unpause();
    }

    // ========== View Functions ==========
    
    /**
     * @notice Gets validator information
     * @param validator Address of the validator
     * @return Validator information
     */
    function getValidator(address validator)
        external
        view
        validValidator(validator)
        returns (
            uint256 stakeAmount,
            uint256 reputationScore,
            uint256 totalVotes,
            uint256 correctVotes,
            uint256 totalEarnings,
            uint256 registeredAt,
            uint256 lastActivity,
            ValidatorStatus status
        )
    {
        Validator storage v = validators[validator];
        return (
            v.stakeAmount,
            v.reputationScore,
            v.totalVotes,
            v.correctVotes,
            v.totalEarnings,
            v.registeredAt,
            v.lastActivity,
            v.status
        );
    }
    
    /**
     * @notice Gets evidence information
     * @param evidenceId ID of the evidence
     * @return Evidence information
     */
    function getEvidence(uint256 evidenceId)
        external
        view
        validEvidence(evidenceId)
        returns (
            address quest,
            address submitter,
            uint256 milestoneId,
            string memory ipfsHash,
            VerificationType verificationType,
            uint256 verificationThreshold,
            uint256 submittedAt,
            uint256 deadline,
            VerificationStatus status,
            uint256 totalVotes,
            uint256 approvalVotes,
            uint256 rejectionVotes,
            uint256 confidenceScore
        )
    {
        Evidence storage e = evidence[evidenceId];
        return (
            e.quest,
            e.submitter,
            e.milestoneId,
            e.ipfsHash,
            e.verificationType,
            e.verificationThreshold,
            e.submittedAt,
            e.deadline,
            e.status,
            e.totalVotes,
            e.approvalVotes,
            e.rejectionVotes,
            e.confidenceScore
        );
    }
    
    /**
     * @notice Gets vote information
     * @param evidenceId ID of the evidence
     * @param validator Address of the validator
     * @return Vote information
     */
    function getVote(uint256 evidenceId, address validator)
        external
        view
        validEvidence(evidenceId)
        returns (
            bool approve,
            uint256 confidence,
            string memory reasoning,
            uint256 votingPower,
            uint256 votedAt,
            bool valid
        )
    {
        Vote storage vote = evidence[evidenceId].votes[validator];
        return (
            vote.approve,
            vote.confidence,
            vote.reasoning,
            vote.votingPower,
            vote.votedAt,
            vote.valid
        );
    }
    
    /**
     * @notice Gets dispute information
     * @param disputeId ID of the dispute
     * @return Dispute information
     */
    function getDispute(uint256 disputeId)
        external
        view
        validDispute(disputeId)
        returns (
            uint256 evidenceId,
            address challenger,
            string memory reason,
            uint256 fee,
            uint256 createdAt,
            uint256 deadline,
            DisputeStatus status,
            uint256 approvalVotes,
            uint256 rejectionVotes,
            uint256 resolutionVotes
        )
    {
        Dispute storage d = disputes[disputeId];
        return (
            d.evidenceId,
            d.challenger,
            d.reason,
            d.fee,
            d.createdAt,
            d.deadline,
            d.status,
            d.approvalVotes,
            d.rejectionVotes,
            d.resolutionVotes
        );
    }
    
    /**
     * @notice Calculates voting power for a validator
     * @param validator Address of the validator
     * @return Voting power
     */
    function calculateVotingPower(address validator) external view returns (uint256) {
        return _calculateVotingPower(validator);
    }
    
    /**
     * @notice Gets validator list
     * @return Array of validator addresses
     */
    function getValidators() external view returns (address[] memory) {
        return validatorList;
    }
    
    /**
     * @notice Gets pending verification requests
     * @return Array of evidence IDs
     */
    function getPendingRequests() external view returns (uint256[] memory) {
        return pendingRequests;
    }
    
    /**
     * @notice Gets oracle statistics
     * @return Oracle statistics
     */
    function getOracleStats()
        external
        view
        returns (
            uint256 totalValidators_,
            uint256 activeValidators_,
            uint256 totalVerifications_,
            uint256 totalDisputes_,
            uint256 averageVerificationTime_,
            uint256 successRate_
        )
    {
        return (
            totalValidators,
            activeValidators,
            totalVerifications,
            totalDisputes,
            averageVerificationTime,
            successRate
        );
    }

    // ========== Internal Functions ==========
    
    function _transferTokens(address from, uint256 amount) internal returns (uint256) {
        if (rewardToken == address(0)) {
            // Handle ETH
            require(msg.value >= amount, "Insufficient ETH sent");
            uint256 actualAmount = Math.min(msg.value, amount);
            if (msg.value > actualAmount) {
                payable(from).transfer(msg.value - actualAmount);
            }
            return actualAmount;
        } else {
            // Handle ERC20 tokens
            uint256 balanceBefore = IERC20(rewardToken).balanceOf(address(this));
            IERC20(rewardToken).safeTransferFrom(from, address(this), amount);
            uint256 balanceAfter = IERC20(rewardToken).balanceOf(address(this));
            uint256 actualAmount = balanceAfter - balanceBefore;
            require(actualAmount == amount, "Transfer failed");
            return actualAmount;
        }
    }
    
    function _transferTokens(address to, uint256 amount) internal {
        if (rewardToken == address(0)) {
            payable(to).transfer(amount);
        } else {
            IERC20(rewardToken).safeTransfer(to, amount);
        }
    }
    
    function _returnStake(address validator, uint256 amount) internal {
        // Apply reputation decay
        Validator storage v = validators[validator];
        uint256 decayAmount = (amount * reputationDecayRate) / REWARD_BASIS_POINTS;
        uint256 returnAmount = amount - decayAmount;
        
        // Transfer stake back
        _transferTokens(validator, returnAmount);
        
        // Transfer decay amount to treasury
        if (decayAmount > 0) {
            _transferTokens(treasury, decayAmount);
        }
        
        // Update reward pool
        totalRewardPool -= amount;
    }
    
    function _calculateVotingPower(address validator) internal view returns (uint256) {
        Validator storage v = validators[validator];
        
        // Base voting power
        uint256 basePower = BASE_VOTING_POWER;
        
        // Reputation multiplier (1x to 5x)
        uint256 reputationMultiplier = (v.reputationScore * 10000) / (MIN_REPUTATION * 10000);
        reputationMultiplier = Math.min(reputationMultiplier, MAX_VOTING_POWER);
        
        // Activity bonus
        uint256 activityBonus = _getActivityBonus(validator);
        
        return (basePower * reputationMultiplier / 10000) + activityBonus;
    }
    
    function _getActivityBonus(address validator) internal view returns (uint256) {
        Validator storage v = validators[validator];
        
        uint256 recentVotes = 0;
        uint256 cutoff = block.timestamp - activityWindow;
        
        for (uint256 i = v.voteHistory.length - 1; i >= 0; i--) {
            if (evidence[v.voteHistory[i]].submittedAt < cutoff) {
                break;
            }
            recentVotes++;
        }
        
        // Activity bonus up to 10%
        uint256 bonusPercentage = Math.min((recentVotes * 100) / 10, ACTIVITY_BONUS_MAX);
        return (BASE_VOTING_POWER * bonusPercentage) / REWARD_BASIS_POINTS;
    }
    
    function _assignValidators(uint256 evidenceId) internal {
        Evidence storage e = evidence[evidenceId];
        uint256 required = e.verificationThreshold;
        
        // Select validators based on reputation and availability
        address[] memory selected = new address[](required);
        uint256 selectedCount = 0;
        
        for (uint256 i = 0; i < validatorList.length && selectedCount < required; i++) {
            address validator = validatorList[i];
            Validator storage v = validators[validator];
            
            if (v.status == ValidatorStatus.Active && !e.hasVoted[validator]) {
                selected[selectedCount] = validator;
                selectedCount++;
                e.assignedValidators.push(validator);
            }
        }
        
        // Update verification request
        VerificationRequest storage request = verificationRequests[evidenceId];
        request.assignedValidators = selectedCount;
    }
    
    function _assignReviewers(uint256 disputeId) internal {
        Dispute storage dispute = disputes[disputeId];
        uint256 required = 3; // 3 reviewers required
        
        // Select reviewers based on reputation
        address[] memory selected = new address[](required);
        uint256 selectedCount = 0;
        
        for (uint256 i = 0; i < validatorList.length && selectedCount < required; i++) {
            address validator = validatorList[i];
            Validator storage v = validators[validator];
            
            if (v.status == ValidatorStatus.Active && v.reputationScore >= 1000) {
                selected[selectedCount] = validator;
                selectedCount++;
                dispute.reviewers.push(validator);
            }
        }
        
        dispute.status = DisputeStatus.UnderReview;
    }
    
    function _processVerificationResult(uint256 evidenceId) internal {
        Evidence storage e = evidence[evidenceId];
        
        // Determine result
        bool approved = e.approvalVotes > e.rejectionVotes;
        
        if (approved) {
            e.status = VerificationStatus.Approved;
        } else {
            e.status = VerificationStatus.Rejected;
        }
        
        // Calculate confidence score
        e.confidenceScore = (e.approvalVotes * 100) / e.totalVotes;
        
        // Update validator statistics and distribute rewards
        _updateValidatorStats(evidenceId, approved);
        
        // Remove from pending requests
        _removeFromPending(evidenceId);
        
        // Update global stats
        totalVerifications++;
        
        emit VerificationCompleted(
            evidenceId,
            e.status,
            e.approvalVotes,
            e.rejectionVotes,
            block.timestamp
        );
    }
    
    function _processDisputeResult(uint256 disputeId) internal {
        Dispute storage dispute = disputes[disputeId];
        Evidence storage e = evidence[dispute.evidenceId];
        
        // Determine dispute result
        bool disputeApproved = dispute.approvalVotes > dispute.rejectionVotes;
        
        if (disputeApproved) {
            // Dispute approved - reverse verification result
            e.status = e.status == VerificationStatus.Approved ? 
                VerificationStatus.Rejected : VerificationStatus.Approved;
            
            // Return dispute fee to challenger
            _transferTokens(dispute.challenger, dispute.fee);
        } else {
            // Dispute rejected - keep fee and penalize challenger
            _transferTokens(treasury, dispute.fee);
        }
        
        dispute.status = DisputeStatus.Resolved;
        
        // Update global stats
        totalDisputes++;
        
        emit DisputeResolved(disputeId, dispute.status, dispute.resolutionVotes, block.timestamp);
    }
    
    function _updateValidatorStats(uint256 evidenceId, bool approved) internal {
        Evidence storage e = evidence[evidenceId];
        
        // Calculate reward per validator
        uint256 baseReward = 1 ether; // Base reward per verification
        uint256 totalReward = 0;
        
        for (uint256 i = 0; i < e.assignedValidators.length; i++) {
            address validator = e.assignedValidators[i];
            Vote storage vote = e.votes[validator];
            
            if (vote.valid) {
                Validator storage v = validators[validator];
                
                // Update correct votes count
                if (vote.approve == approved) {
                    v.correctVotes++;
                    
                    // Calculate reward
                    uint256 reward = baseReward + (baseReward * vote.confidence) / 100;
                    totalReward += reward;
                    
                    // Update earnings
                    v.totalEarnings += reward;
                    validatorEarnings[validator] += reward;
                    
                    // Distribute reward
                    _transferTokens(validator, reward);
                    
                    emit RewardDistributed(validator, reward, block.timestamp);
                }
                
                // Update reputation
                _updateValidatorReputation(validator, vote.approve == approved);
            }
        }
        
        totalRewardsDistributed += totalReward;
    }
    
    function _updateValidatorReputation(address validator, bool correctVote) internal {
        Validator storage v = validators[validator];
        
        if (correctVote) {
            // Increase reputation for correct votes
            uint256 increase = 10;
            v.reputationScore = Math.min(v.reputationScore + increase, MAX_REPUTATION);
        } else {
            // Decrease reputation for incorrect votes
            uint256 decrease = 5;
            v.reputationScore = Math.max(v.reputationScore - decrease, MIN_REPUTATION);
        }
    }
    
    function _removeFromPending(uint256 evidenceId) internal {
        for (uint256 i = 0; i < pendingRequests.length; i++) {
            if (pendingRequests[i] == evidenceId) {
                pendingRequests[i] = pendingRequests[pendingRequests.length - 1];
                pendingRequests.pop();
                break;
            }
        }
    }
}
