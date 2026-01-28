// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title Quest
 * @notice Individual quest contract managing participants, milestones, and rewards
 * @dev Implements quest lifecycle from creation to completion
 */
contract Quest is AccessControl, Pausable, ReentrancyGuard {
    // ========== Constants ==========
    bytes32 public constant QUEST_ADMIN_ROLE = keccak256("QUEST_ADMIN_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    uint256 public constant MIN_PARTICIPANTS = 1;
    uint256 public constant MAX_PARTICIPANTS = 10000;
    uint256 public constant MIN_STAKE_AMOUNT = 0.001 ether;
    uint256 public constant MAX_MILESTONES = 50;
    uint256 public constant VERIFICATION_WINDOW = 7 days;
    uint256 public constant DISPUTE_WINDOW = 3 days;
    
    // ========== Enums ==========
    
    enum QuestStatus {
        Created,
        Active,
        Completed,
        Expired,
        Failed,
        EmergencyPaused
    }
    
    enum ParticipantStatus {
        Registered,
        Active,
        Completed,
        Failed,
        Withdrawn
    }
    
    enum VerificationStatus {
        Pending,
        Approved,
        Rejected,
        Disputed
    }
    
    enum MilestoneStatus {
        Locked,
        Active,
        Completed,
        Failed
    }

    // ========== Structs ==========
    
    struct Participant {
        address user;
        uint256 stakeAmount;
        uint256 joinedAt;
        ParticipantStatus status;
        uint256 completedMilestones;
        uint256 lastActivity;
        mapping(uint256 => bool) milestoneCompleted;
        mapping(uint256 => uint256) evidenceSubmissionIds;
    }
    
    struct Milestone {
        uint256 id;
        string title;
        string description;
        uint256 orderIndex;
        uint8 verificationType; // 0: community, 1: oracle, 2: automated
        string[] requiredEvidence;
        uint256 deadline;
        MilestoneStatus status;
        uint256 verificationThreshold;
        uint256 currentVotes;
        uint256 approvalVotes;
        uint256 rejectionVotes;
    }
    
    struct EvidenceSubmission {
        uint256 id;
        uint256 milestoneId;
        address participant;
        string ipfsHash;
        bytes32 evidenceHash;
        uint256 submittedAt;
        VerificationStatus status;
        uint256 verificationDeadline;
        uint256 disputeDeadline;
        address[] approvers;
        address[] rejecters;
        mapping(address => bool) hasVoted;
    }
    
    struct QuestConfig {
        string title;
        string description;
        address creator;
        uint256 stakeAmount;
        uint256 rewardPool;
        uint256 duration;
        uint256 maxParticipants;
        uint256 verificationThreshold;
        string category;
        address rewardToken;
        string metadataURI;
    }

    // ========== State Variables ==========
    
    // Quest configuration
    QuestConfig public config;
    QuestStatus public questStatus;
    uint256 public createdAt;
    uint256 public startedAt;
    uint256 public expiresAt;
    uint256 public completedAt;
    
    // System contracts
    address public rewardPool;
    address public verificationOracle;
    address public achievementNFT;
    
    // Quest data
    uint256 public currentParticipantCount;
    uint256 public maxParticipants;
    mapping(address => Participant) public participants;
    address[] public participantList;
    
    // Milestones
    uint256 public milestoneCount;
    mapping(uint256 => Milestone) public milestones;
    uint256[] public milestoneIds;
    
    // Evidence submissions
    uint256 public nextEvidenceId;
    mapping(uint256 => EvidenceSubmission) public evidenceSubmissions;
    mapping(uint256 => uint256[]) public milestoneEvidence; // milestoneId => evidenceIds
    
    // Quest statistics
    uint256 public totalStaked;
    uint256 public totalRewardsDistributed;
    uint256 public completionRate;
    
    // ========== Events ==========
    
    event QuestInitialized(
        address indexed creator,
        string title,
        uint256 stakeAmount,
        uint256 duration,
        uint256 maxParticipants
    );
    
    event QuestStarted(uint256 startedAt);
    event QuestCompleted(uint256 completedAt, uint256 completionRate);
    event QuestExpired(uint256 expiredAt);
    event QuestFailed(uint256 failedAt);
    
    event ParticipantJoined(
        address indexed participant,
        uint256 stakeAmount,
        uint256 joinedAt
    );
    
    event ParticipantWithdrawn(
        address indexed participant,
        uint256 refundAmount,
        uint256 withdrawnAt
    );
    
    event MilestoneCompleted(
        uint256 indexed milestoneId,
        address indexed participant,
        uint256 completedAt
    );
    
    event EvidenceSubmitted(
        uint256 indexed evidenceId,
        uint256 indexed milestoneId,
        address indexed participant,
        string ipfsHash,
        uint256 submittedAt
    );
    
    event EvidenceVerified(
        uint256 indexed evidenceId,
        VerificationStatus status,
        uint256 verifiedAt
    );
    
    event RewardDistributed(
        address indexed participant,
        uint256 rewardAmount,
        uint256 distributedAt
    );
    
    event QuestPaused(address indexed pausedBy, string reason);
    event QuestUnpaused(address indexed unpausedBy);

    // ========== Errors ==========
    
    error Quest__InvalidAddress();
    error Quest__InvalidAmount();
    error Quest__InvalidDuration();
    error Quest__InvalidStatus();
    error Quest__Unauthorized();
    error Quest__QuestNotActive();
    error Quest__QuestExpired();
    error Quest__QuestFull();
    error Quest__AlreadyParticipant();
    error Quest__NotParticipant();
    error Quest__InvalidMilestone();
    error Quest__MilestoneNotActive();
    error Quest__MilestoneAlreadyCompleted();
    error Quest__EvidenceNotFound();
    error Quest__VerificationExpired();
    error Quest__InvalidEvidence();
    error Quest__InsufficientStake();
    error Quest__MaxMilestonesReached();

    // ========== Modifiers ==========
    
    modifier onlyQuestAdmin() {
        if (!hasRole(QUEST_ADMIN_ROLE, msg.sender) && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert Quest__Unauthorized();
        }
        _;
    }
    
    modifier onlyVerifier() {
        if (!hasRole(VERIFIER_ROLE, msg.sender)) {
            revert Quest__Unauthorized();
        }
        _;
    }
    
    modifier onlyEmergencyRole() {
        if (!hasRole(EMERGENCY_ROLE, msg.sender)) {
            revert Quest__Unauthorized();
        }
        _;
    }
    
    modifier onlyParticipant() {
        if (participants[msg.sender].user == address(0)) {
            revert Quest__NotParticipant();
        }
        _;
    }
    
    modifier questActive() {
        if (questStatus != QuestStatus.Active) {
            revert Quest__QuestNotActive();
        }
        _;
    }
    
    modifier questNotExpired() {
        if (block.timestamp > expiresAt) {
            revert Quest__QuestExpired();
        }
        _;
    }
    
    modifier validMilestone(uint256 milestoneId) {
        if (milestoneId >= milestoneCount || milestones[milestoneId].id != milestoneId) {
            revert Quest__InvalidMilestone();
        }
        _;
    }
    
    modifier validEvidence(uint256 evidenceId) {
        if (evidenceId >= nextEvidenceId || evidenceSubmissions[evidenceId].participant == address(0)) {
            revert Quest__EvidenceNotFound();
        }
        _;
    }

    // ========== Constructor ==========
    
    constructor() {
        // This will be called by the clone proxy
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(QUEST_ADMIN_ROLE, msg.sender);
        _grantRole(VERIFIER_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);
    }
    
    /**
     * @notice Initializes the quest contract
     * @param params Quest configuration parameters
     * @param _rewardPool Reward pool contract address
     * @param _verificationOracle Verification oracle contract address
     * @param _achievementNFT Achievement NFT contract address
     */
    function initialize(
        QuestConfig calldata params,
        address _rewardPool,
        address _verificationOracle,
        address _achievementNFT
    ) external {
        // Only allow initialization once
        if (questStatus != QuestStatus.Created) {
            return;
        }
        
        // Validate parameters
        _validateQuestConfig(params);
        _validateSystemContracts(_rewardPool, _verificationOracle, _achievementNFT);
        
        // Set configuration
        config = params;
        rewardPool = _rewardPool;
        verificationOracle = _verificationOracle;
        achievementNFT = _achievementNFT;
        
        // Set timestamps
        createdAt = block.timestamp;
        startedAt = block.timestamp;
        expiresAt = block.timestamp + params.duration;
        maxParticipants = params.maxParticipants;
        
        // Initialize milestones
        _initializeMilestones();
        
        // Set quest status to active
        questStatus = QuestStatus.Active;
        
        emit QuestInitialized(
            params.creator,
            params.title,
            params.stakeAmount,
            params.duration,
            params.maxParticipants
        );
        
        emit QuestStarted(block.timestamp);
    }

    // ========== Participant Functions ==========
    
    /**
     * @notice Allows a user to join the quest by staking tokens
     */
    function joinQuest() external payable nonReentrant questActive questNotExpired {
        address participant = msg.sender;
        
        // Validate participant
        if (participants[participant].user != address(0)) {
            revert Quest__AlreadyParticipant();
        }
        
        if (currentParticipantCount >= maxParticipants) {
            revert Quest__QuestFull();
        }
        
        uint256 stakeAmount = config.stakeAmount;
        if (msg.value != stakeAmount) {
            revert Quest__InsufficientStake();
        }
        
        // Create participant record
        Participant storage p = participants[participant];
        p.user = participant;
        p.stakeAmount = stakeAmount;
        p.joinedAt = block.timestamp;
        p.status = ParticipantStatus.Active;
        p.completedMilestones = 0;
        p.lastActivity = block.timestamp;
        
        participantList.push(participant);
        currentParticipantCount++;
        totalStaked += stakeAmount;
        
        // Stake in reward pool
        if (rewardPool != address(0)) {
            IRewardPool(rewardPool).stake{value: stakeAmount}(address(this), stakeAmount, address(0));
        }
        
        emit ParticipantJoined(participant, stakeAmount, block.timestamp);
    }
    
    /**
     * @notice Allows a participant to withdraw from the quest
     */
    function withdrawQuest() external nonReentrant onlyParticipant {
        Participant storage participant = participants[msg.sender];
        
        if (participant.status != ParticipantStatus.Active) {
            revert Quest__InvalidStatus();
        }
        
        // Calculate refund (with penalty if withdrawing early)
        uint256 refundAmount = _calculateRefundAmount(participant);
        
        // Update participant status
        participant.status = ParticipantStatus.Withdrawn;
        currentParticipantCount--;
        
        // Process refund through reward pool
        if (rewardPool != address(0)) {
            IRewardPool(rewardPool).withdraw(msg.sender, refundAmount);
        } else {
            payable(msg.sender).transfer(refundAmount);
        }
        
        emit ParticipantWithdrawn(msg.sender, refundAmount, block.timestamp);
    }
    
    /**
     * @notice Submits evidence for a milestone
     * @param milestoneId ID of the milestone
     * @param ipfsHash IPFS hash of the evidence
     * @param evidenceHash Hash of the evidence data
     */
    function submitEvidence(
        uint256 milestoneId,
        string calldata ipfsHash,
        bytes32 evidenceHash
    ) external nonReentrant onlyParticipant questActive questNotExpired validMilestone(milestoneId) {
        Participant storage participant = participants[msg.sender];
        Milestone storage milestone = milestones[milestoneId];
        
        // Validate milestone status
        if (milestone.status != MilestoneStatus.Active) {
            revert Quest__MilestoneNotActive();
        }
        
        if (participant.milestoneCompleted[milestoneId]) {
            revert Quest__MilestoneAlreadyCompleted();
        }
        
        // Validate evidence
        if (bytes(ipfsHash).length == 0 || evidenceHash == bytes32(0)) {
            revert Quest__InvalidEvidence();
        }
        
        // Create evidence submission
        uint256 evidenceId = nextEvidenceId++;
        EvidenceSubmission storage submission = evidenceSubmissions[evidenceId];
        submission.id = evidenceId;
        submission.milestoneId = milestoneId;
        submission.participant = msg.sender;
        submission.ipfsHash = ipfsHash;
        submission.evidenceHash = evidenceHash;
        submission.submittedAt = block.timestamp;
        submission.status = VerificationStatus.Pending;
        submission.verificationDeadline = block.timestamp + VERIFICATION_WINDOW;
        submission.disputeDeadline = block.timestamp + VERIFICATION_WINDOW + DISPUTE_WINDOW;
        
        // Update mappings
        participant.evidenceSubmissionIds[milestoneId] = evidenceId;
        milestoneEvidence[milestoneId].push(evidenceId);
        
        // Update participant activity
        participant.lastActivity = block.timestamp;
        
        emit EvidenceSubmitted(evidenceId, milestoneId, msg.sender, ipfsHash, block.timestamp);
        
        // Request verification from oracle
        if (verificationOracle != address(0)) {
            IVerificationOracle(verificationOracle).requestVerification(
                evidenceId,
                milestone.verificationType,
                milestone.verificationThreshold
            );
        }
    }

    // ========== Verification Functions ==========
    
    /**
     * @notice Verifies evidence submission (called by verification oracle)
     * @param evidenceId ID of the evidence to verify
     * @param approved Whether the evidence is approved
     * @param verifier Address of the verifier
     */
    function verifyEvidence(
        uint256 evidenceId,
        bool approved,
        address verifier
    ) external onlyVerifier validEvidence(evidenceId) {
        EvidenceSubmission storage submission = evidenceSubmissions[evidenceId];
        
        // Check if verification window is still open
        if (block.timestamp > submission.verificationDeadline) {
            revert Quest__VerificationExpired();
        }
        
        // Check if verifier hasn't already voted
        if (submission.hasVoted[verifier]) {
            return;
        }
        
        // Record vote
        submission.hasVoted[verifier] = true;
        if (approved) {
            submission.approvers.push(verifier);
        } else {
            submission.rejecters.push(verifier);
        }
        
        // Update milestone vote counts
        Milestone storage milestone = milestones[submission.milestoneId];
        milestone.currentVotes++;
        
        if (approved) {
            milestone.approvalVotes++;
        } else {
            milestone.rejectionVotes++;
        }
        
        // Check if verification threshold is met
        if (milestone.currentVotes >= milestone.verificationThreshold) {
            _processVerificationResult(evidenceId);
        }
    }
    
    /**
     * @notice Creates a dispute for evidence verification
     * @param evidenceId ID of the evidence to dispute
     * @param reason Reason for the dispute
     */
    function createDispute(
        uint256 evidenceId,
        string calldata reason
    ) external onlyParticipant validEvidence(evidenceId) {
        EvidenceSubmission storage submission = evidenceSubmissions[evidenceId];
        
        // Check if dispute window is open
        if (block.timestamp > submission.disputeDeadline) {
            revert Quest__VerificationExpired();
        }
        
        // Only participant can dispute their own evidence
        if (submission.participant != msg.sender) {
            revert Quest__Unauthorized();
        }
        
        // Update status to disputed
        submission.status = VerificationStatus.Disputed;
        
        // Notify verification oracle of dispute
        if (verificationOracle != address(0)) {
            IVerificationOracle(verificationOracle).createDispute(evidenceId, reason);
        }
    }

    // ========== Admin Functions ==========
    
    /**
     * @notice Manually completes a milestone (emergency function)
     * @param participant Address of the participant
     * @param milestoneId ID of the milestone
     */
    function manualCompleteMilestone(
        address participant,
        uint256 milestoneId
    ) external onlyQuestAdmin validMilestone(milestoneId) {
        if (participants[participant].user == address(0)) {
            revert Quest__NotParticipant();
        }
        
        _completeMilestone(participant, milestoneId);
    }
    
    /**
     * @notice Pauses the quest (emergency only)
     * @param reason Reason for pausing
     */
    function pauseQuest(string calldata reason) external onlyEmergencyRole {
        questStatus = QuestStatus.EmergencyPaused;
        _pause();
        
        emit QuestPaused(msg.sender, reason);
    }
    
    /**
     * @notice Unpauses the quest
     */
    function unpauseQuest() external onlyEmergencyRole {
        questStatus = QuestStatus.Active;
        _unpause();
        
        emit QuestUnpaused(msg.sender);
    }
    
    /**
     * @notice Ends the quest and distributes final rewards
     */
    function endQuest() external onlyQuestAdmin {
        if (questStatus != QuestStatus.Active) {
            revert Quest__InvalidStatus();
        }
        
        _processQuestCompletion();
    }

    // ========== View Functions ==========
    
    /**
     * @notice Gets participant information
     * @param participant Address of the participant
     * @return Participant information
     */
    function getParticipant(address participant)
        external
        view
        returns (
            uint256 stakeAmount,
            uint256 joinedAt,
            ParticipantStatus status,
            uint256 completedMilestones,
            uint256 lastActivity
        )
    {
        Participant storage p = participants[participant];
        return (
            p.stakeAmount,
            p.joinedAt,
            p.status,
            p.completedMilestones,
            p.lastActivity
        );
    }
    
    /**
     * @notice Gets milestone information
     * @param milestoneId ID of the milestone
     * @return Milestone information
     */
    function getMilestone(uint256 milestoneId)
        external
        view
        validMilestone(milestoneId)
        returns (
            string memory title,
            string memory description,
            uint256 orderIndex,
            uint8 verificationType,
            uint256 deadline,
            MilestoneStatus status,
            uint256 verificationThreshold,
            uint256 currentVotes,
            uint256 approvalVotes,
            uint256 rejectionVotes
        )
    {
        Milestone storage m = milestones[milestoneId];
        return (
            m.title,
            m.description,
            m.orderIndex,
            m.verificationType,
            m.deadline,
            m.status,
            m.verificationThreshold,
            m.currentVotes,
            m.approvalVotes,
            m.rejectionVotes
        );
    }
    
    /**
     * @notice Gets evidence submission information
     * @param evidenceId ID of the evidence submission
     * @return Evidence submission information
     */
    function getEvidenceSubmission(uint256 evidenceId)
        external
        view
        validEvidence(evidenceId)
        returns (
            uint256 milestoneId,
            address participant,
            string memory ipfsHash,
            uint256 submittedAt,
            VerificationStatus status,
            uint256 verificationDeadline,
            uint256 disputeDeadline
        )
    {
        EvidenceSubmission storage e = evidenceSubmissions[evidenceId];
        return (
            e.milestoneId,
            e.participant,
            e.ipfsHash,
            e.submittedAt,
            e.status,
            e.verificationDeadline,
            e.disputeDeadline
        );
    }
    
    /**
     * @notice Gets quest statistics
     * @return Quest statistics
     */
    function getQuestStats()
        external
        view
        returns (
            uint256 participantCount,
            uint256 totalStakedAmount,
            uint256 totalRewards,
            uint256 currentCompletionRate,
            uint256 activeMilestones,
            uint256 completedMilestones
        )
    {
        uint256 active = 0;
        uint256 completed = 0;
        
        for (uint256 i = 0; i < milestoneCount; i++) {
            if (milestones[i].status == MilestoneStatus.Active) {
                active++;
            } else if (milestones[i].status == MilestoneStatus.Completed) {
                completed++;
            }
        }
        
        return (
            currentParticipantCount,
            totalStaked,
            totalRewardsDistributed,
            completionRate,
            active,
            completed
        );
    }
    
    /**
     * @notice Checks if an address is a participant
     * @param addr Address to check
     * @return isParticipant True if the address is a participant
     */
    function isParticipant(address addr) external view returns (bool isParticipant) {
        return participants[addr].user != address(0);
    }
    
    /**
     * @notice Gets the participant list
     * @return Array of participant addresses
     */
    function getParticipants() external view returns (address[] memory) {
        return participantList;
    }
    
    /**
     * @notice Gets milestone IDs
     * @return Array of milestone IDs
     */
    function getMilestoneIds() external view returns (uint256[] memory) {
        return milestoneIds;
    }
    
    /**
     * @notice Gets evidence submissions for a milestone
     * @param milestoneId ID of the milestone
     * @return Array of evidence submission IDs
     */
    function getMilestoneEvidence(uint256 milestoneId)
        external
        view
        validMilestone(milestoneId)
        returns (uint256[] memory)
    {
        return milestoneEvidence[milestoneId];
    }

    // ========== Internal Functions ==========
    
    function _validateQuestConfig(QuestConfig calldata params) internal pure {
        if (params.creator == address(0)) {
            revert Quest__InvalidAddress();
        }
        if (params.stakeAmount < MIN_STAKE_AMOUNT) {
            revert Quest__InvalidAmount();
        }
        if (params.duration == 0) {
            revert Quest__InvalidDuration();
        }
        if (params.maxParticipants < MIN_PARTICIPANTS || params.maxParticipants > MAX_PARTICIPANTS) {
            revert Quest__InvalidAmount();
        }
        if (bytes(params.title).length == 0) {
            revert Quest__InvalidAmount();
        }
    }
    
    function _validateSystemContracts(
        address _rewardPool,
        address _verificationOracle,
        address _achievementNFT
    ) internal pure {
        if (_rewardPool == address(0)) {
            revert Quest__InvalidAddress();
        }
        if (_verificationOracle == address(0)) {
            revert Quest__InvalidAddress();
        }
        if (_achievementNFT == address(0)) {
            revert Quest__InvalidAddress();
        }
    }
    
    function _initializeMilestones() internal {
        // This would be called with milestone data from the factory
        // For now, we'll set up the structure
        milestoneCount = 0;
    }
    
    function _calculateRefundAmount(Participant storage participant) internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - participant.joinedAt;
        uint256 totalTime = expiresAt - createdAt;
        
        // Early withdrawal penalty (up to 50%)
        uint256 penaltyPercentage = Math.min((totalTime - timeElapsed) * 100 / totalTime, 50);
        uint256 penaltyAmount = (participant.stakeAmount * penaltyPercentage) / 100;
        
        return participant.stakeAmount - penaltyAmount;
    }
    
    function _processVerificationResult(uint256 evidenceId) internal {
        EvidenceSubmission storage submission = evidenceSubmissions[evidenceId];
        Milestone storage milestone = milestones[submission.milestoneId];
        
        // Determine verification result
        bool approved = milestone.approvalVotes > milestone.rejectionVotes;
        
        if (approved) {
            submission.status = VerificationStatus.Approved;
            _completeMilestone(submission.participant, submission.milestoneId);
        } else {
            submission.status = VerificationStatus.Rejected;
        }
        
        emit EvidenceVerified(evidenceId, submission.status, block.timestamp);
    }
    
    function _completeMilestone(address participant, uint256 milestoneId) internal {
        Participant storage p = participants[participant];
        Milestone storage m = milestones[milestoneId];
        
        // Mark milestone as completed for participant
        p.milestoneCompleted[milestoneId] = true;
        p.completedMilestones++;
        p.lastActivity = block.timestamp;
        
        // Update milestone status if all participants completed
        // This is simplified - in production you'd track completion per milestone
        m.status = MilestoneStatus.Completed;
        
        emit MilestoneCompleted(milestoneId, participant, block.timestamp);
        
        // Check if participant completed all milestones
        if (p.completedMilestones == milestoneCount) {
            _completeQuestForParticipant(participant);
        }
    }
    
    function _completeQuestForParticipant(address participant) internal {
        Participant storage p = participants[participant];
        p.status = ParticipantStatus.Completed;
        
        // Calculate and distribute reward
        uint256 rewardAmount = _calculateRewardAmount(participant);
        totalRewardsDistributed += rewardAmount;
        
        // Distribute reward through reward pool
        if (rewardPool != address(0)) {
            IRewardPool(rewardPool).distributeReward(address(this), participant, rewardAmount);
        }
        
        // Mint achievement NFT
        if (achievementNFT != address(0)) {
            _mintAchievementNFT(participant);
        }
        
        emit RewardDistributed(participant, rewardAmount, block.timestamp);
    }
    
    function _calculateRewardAmount(Participant storage participant) internal view returns (uint256) {
        // Base reward is stake amount plus bonus from reward pool
        uint256 baseReward = participant.stakeAmount;
        uint256 bonusAmount = (config.rewardPool * participant.stakeAmount) / totalStaked;
        
        // Performance bonus based on completion speed
        uint256 speedBonus = _calculateSpeedBonus(participant);
        
        return baseReward + bonusAmount + speedBonus;
    }
    
    function _calculateSpeedBonus(Participant storage participant) internal view returns (uint256) {
        uint256 questDuration = expiresAt - startedAt;
        uint256 completionTime = block.timestamp - participant.joinedAt;
        
        // Faster completion gets higher bonus (up to 20% of stake)
        if (completionTime < questDuration / 2) {
            return (participant.stakeAmount * 20) / 100;
        } else if (completionTime < questDuration * 3 / 4) {
            return (participant.stakeAmount * 10) / 100;
        } else {
            return 0;
        }
    }
    
    function _mintAchievementNFT(address participant) internal {
        // This would mint an achievement NFT for completing the quest
        // Implementation depends on the AchievementNFT contract interface
        IAchievementNFT(achievementNFT).mintAchievement(
            participant,
            string(abi.encodePacked("Quest Completed: ", config.title)),
            string(abi.encodePacked("Successfully completed quest: ", config.description))
        );
    }
    
    function _processQuestCompletion() internal {
        // Calculate final completion rate
        uint256 completedCount = 0;
        for (uint256 i = 0; i < participantList.length; i++) {
            if (participants[participantList[i]].status == ParticipantStatus.Completed) {
                completedCount++;
            }
        }
        
        completionRate = (completedCount * 100) / participantList.length;
        
        // Update quest status
        if (completionRate >= 80) {
            questStatus = QuestStatus.Completed;
            completedAt = block.timestamp;
            emit QuestCompleted(block.timestamp, completionRate);
        } else {
            questStatus = QuestStatus.Failed;
            emit QuestFailed(block.timestamp);
        }
        
        // Handle remaining stakes for failed participants
        _handleFailedParticipants();
    }
    
    function _handleFailedParticipants() internal {
        for (uint256 i = 0; i < participantList.length; i++) {
            address participantAddr = participantList[i];
            Participant storage p = participants[participantAddr];
            
            if (p.status == ParticipantStatus.Active) {
                p.status = ParticipantStatus.Failed;
                
                // Slash stake and return remaining amount
                if (rewardPool != address(0)) {
                    IRewardPool(rewardPool).slash(participantAddr, 50); // 50% slash
                }
            }
        }
    }
}

// ========== Interface Definitions ==========

interface IRewardPool {
    function stake(address quest, uint256 amount, address token) external payable;
    function withdraw(address user, uint256 amount) external;
    function distributeReward(address quest, address participant, uint256 amount) external;
    function slash(address participant, uint256 percentage) external;
}

interface IVerificationOracle {
    function requestVerification(uint256 evidenceId, uint8 verificationType, uint256 threshold) external;
    function createDispute(uint256 evidenceId, string calldata reason) external;
}

interface IAchievementNFT {
    function mintAchievement(address to, string calldata title, string calldata description) external;
}
