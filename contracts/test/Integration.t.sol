// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/QuestFactory.sol";
import "../src/Quest.sol";
import "../src/RewardPool.sol";
import "../src/VerificationOracle.sol";
import "../src/AchievementNFT.sol";
import "../src/GovernanceToken.sol";

/**
 * @title IntegrationTest
 * @notice Integration tests for the complete ChainQuest system
 */
contract IntegrationTest is Test {
    // ========== Test State ==========
    
    QuestFactory public questFactory;
    Quest public questImplementation;
    RewardPool public rewardPool;
    VerificationOracle public verificationOracle;
    AchievementNFT public achievementNFT;
    GovernanceToken public governanceToken;
    
    address public owner;
    address public creator;
    address public participant1;
    address public participant2;
    address public validator1;
    address public validator2;
    
    address public questAddress;
    uint256 public questId;
    
    uint256 public constant CREATION_FEE = 0.01 ether;
    uint256 public constant STAKE_AMOUNT = 1 ether;
    uint256 public constant VALIDATOR_STAKE = 100 ether;
    uint256 public constant QUEST_DURATION = 30 days;

    // ========== Setup ==========
    
    function setUp() public {
        // Setup test accounts
        owner = address(this);
        creator = makeAddr("creator");
        participant1 = makeAddr("participant1");
        participant2 = makeAddr("participant2");
        validator1 = makeAddr("validator1");
        validator2 = makeAddr("validator2");
        
        // Fund accounts
        vm.deal(creator, 200 ether);
        vm.deal(participant1, 10 ether);
        vm.deal(participant2, 10 ether);
        vm.deal(validator1, 200 ether);
        vm.deal(validator2, 200 ether);
        
        // Deploy and configure system
        _deploySystem();
        _setupRoles();
        _registerValidators();
        _createAchievements();
    }
    
    function _deploySystem() internal {
        // Deploy governance token
        governanceToken = new GovernanceToken("ChainQuest Governance", "CQT", owner);
        
        // Deploy core contracts
        rewardPool = new RewardPool(owner);
        verificationOracle = new VerificationOracle(address(governanceToken));
        achievementNFT = new AchievementNFT("ChainQuest Achievements", "CQA", owner);
        questImplementation = new Quest();
        questFactory = new QuestFactory(address(questImplementation));
        
        // Configure system
        questFactory.updateSystemContracts(
            address(rewardPool),
            address(verificationOracle),
            address(achievementNFT),
            address(governanceToken)
        );
        
        // Add tokens to reward pool
        rewardPool.addToken(address(governanceToken), "CQT", 18);
        
        // Mint tokens for testing
        governanceToken.mint(creator, 10000 * 10**18);
        governanceToken.mint(participant1, 1000 * 10**18);
        governanceToken.mint(participant2, 1000 * 10**18);
        governanceToken.mint(validator1, 10000 * 10**18);
        governanceToken.mint(validator2, 10000 * 10**18);
    }
    
    function _setupRoles() internal {
        // Grant roles
        questFactory.grantRole(questFactory.QUEST_CREATOR_ROLE(), creator);
        rewardPool.grantRole(rewardPool.QUEST_CONTRACT_ROLE(), address(questFactory));
        verificationOracle.grantRole(verificationOracle.VALIDATOR_ROLE(), validator1);
        verificationOracle.grantRole(verificationOracle.VALIDATOR_ROLE(), validator2);
        achievementNFT.grantRole(achievementNFT.MINTER_ROLE(), address(questFactory));
    }
    
    function _registerValidators() internal {
        // Register validators
        vm.startPrank(validator1);
        verificationOracle.registerValidator{value: VALIDATOR_STAKE}(VALIDATOR_STAKE);
        vm.stopPrank();
        
        vm.startPrank(validator2);
        verificationOracle.registerValidator{value: VALIDATOR_STAKE}(VALIDATOR_STAKE);
        vm.stopPrank();
    }
    
    function _createAchievements() internal {
        // Create achievement templates
        vm.startPrank(owner);
        
        achievementNFT.createAchievement(
            "Quest Completion",
            "Completed a quest successfully",
            "https://ipfs.io/ipfs/QmQuestCompletion",
            AchievementNFT.AchievementRarity.Common,
            AchievementNFT.AchievementType.QuestCompletion,
            AchievementNFT.TransferRestriction.None,
            1000
        );
        
        vm.stopPrank();
    }

    // ========== Full Quest Lifecycle Tests ==========
    
    function testFullQuestLifecycle() public {
        // 1. Create quest
        _createQuest();
        
        // 2. Participants join quest
        _participantsJoinQuest();
        
        // 3. Submit evidence and verify
        _submitAndVerifyEvidence();
        
        // 4. Complete quest and claim rewards
        _completeQuestAndClaimRewards();
        
        // 5. Mint achievement NFTs
        _mintAchievements();
        
        // 6. Verify final state
        _verifyFinalState();
    }
    
    function _createQuest() internal {
        vm.startPrank(creator);
        
        QuestFactory.CreateQuestParams memory params = _createQuestParams();
        
        questAddress = questFactory.createQuest{value: CREATION_FEE}(params);
        questId = 1;
        
        // Verify quest creation
        assertTrue(questAddress != address(0));
        assertEq(questFactory.totalQuests(), 1);
        
        // Verify quest contract
        Quest quest = Quest(payable(questAddress));
        (,,,,,,,Quest.QuestStatus status,) = quest.getQuestStats();
        assertEq(uint256(status), uint256(Quest.QuestStatus.Active));
        
        vm.stopPrank();
    }
    
    function _participantsJoinQuest() internal {
        Quest quest = Quest(payable(questAddress));
        
        // Participant 1 joins
        vm.startPrank(participant1);
        quest.joinQuest{value: STAKE_AMOUNT}();
        vm.stopPrank();
        
        // Participant 2 joins
        vm.startPrank(participant2);
        quest.joinQuest{value: STAKE_AMOUNT}();
        vm.stopPrank();
        
        // Verify participants
        assertTrue(quest.isParticipant(participant1));
        assertTrue(quest.isParticipant(participant2));
        
        address[] memory participants = quest.getParticipants();
        assertEq(participants.length, 2);
        
        // Verify staking in reward pool
        (uint256 totalStaked,,,,,,) = rewardPool.getQuestPool(questAddress);
        assertEq(totalStaked, STAKE_AMOUNT * 2);
    }
    
    function _submitAndVerifyEvidence() internal {
        Quest quest = Quest(payable(questAddress));
        
        // Get milestone
        uint256[] memory milestoneIds = quest.getMilestoneIds();
        uint256 milestoneId = milestoneIds[0];
        
        // Participant 1 submits evidence
        vm.startPrank(participant1);
        quest.submitEvidence(
            milestoneId,
            "QmEvidenceHash1",
            keccak256("evidence1")
        );
        vm.stopPrank();
        
        // Get evidence ID
        uint256[] memory evidenceIds = quest.getMilestoneEvidence(milestoneId);
        uint256 evidenceId = evidenceIds[0];
        
        // Request verification
        quest.requestVerification(evidenceId, VerificationOracle.VerificationType.Community, 2);
        
        // Validators vote
        vm.startPrank(validator1);
        verificationOracle.castVote(evidenceId, true, 85, "Evidence looks valid");
        vm.stopPrank();
        
        vm.startPrank(validator2);
        verificationOracle.castVote(evidenceId, true, 90, "Evidence is authentic");
        vm.stopPrank();
        
        // Verify milestone completion
        (,,,,,,,,Quest.MilestoneStatus milestoneStatus,,,) = quest.getMilestone(milestoneId);
        assertEq(uint256(milestoneStatus), uint256(Quest.MilestoneStatus.Completed));
    }
    
    function _completeQuestAndClaimRewards() internal {
        // Simulate quest completion
        vm.startPrank(owner);
        
        Quest quest = Quest(payable(questAddress));
        quest.endQuest();
        
        vm.stopPrank();
        
        // Verify quest completion
        (,,,,,,,Quest.QuestStatus status,) = quest.getQuestStats();
        assertEq(uint256(status), uint256(Quest.QuestStatus.Completed));
        
        // Participants withdraw stakes and rewards
        vm.startPrank(participant1);
        uint256 balanceBefore = participant1.balance;
        uint256[] memory stakeIds = rewardPool.getUserStakes(participant1);
        rewardPool.withdraw(stakeIds[0]);
        uint256 balanceAfter = participant1.balance;
        assertTrue(balanceAfter > balanceBefore);
        vm.stopPrank();
        
        vm.startPrank(participant2);
        balanceBefore = participant2.balance;
        stakeIds = rewardPool.getUserStakes(participant2);
        rewardPool.withdraw(stakeIds[0]);
        balanceAfter = participant2.balance;
        assertTrue(balanceAfter > balanceBefore);
        vm.stopPrank();
    }
    
    function _mintAchievements() internal {
        // Mint achievement NFTs for participants
        vm.startPrank(owner);
        
        uint256 achievementId = 1; // First achievement template
        
        uint256 tokenId1 = achievementNFT.mintAchievement(
            participant1,
            achievementId,
            questAddress,
            "https://ipfs.io/ipfs/QmAchievement1"
        );
        
        uint256 tokenId2 = achievementNFT.mintAchievement(
            participant2,
            achievementId,
            questAddress,
            "https://ipfs.io/ipfs/QmAchievement2"
        );
        
        // Verify NFT ownership
        assertEq(achievementNFT.ownerOf(tokenId1), participant1);
        assertEq(achievementNFT.ownerOf(tokenId2), participant2);
        assertEq(achievementNFT.balanceOf(participant1), 1);
        assertEq(achievementNFT.balanceOf(participant2), 1);
        
        vm.stopPrank();
    }
    
    function _verifyFinalState() internal {
        // Verify quest statistics
        QuestFactory.QuestInfo memory questInfo = questFactory.getQuest(questId);
        assertTrue(questInfo.isActive);
        
        // Verify reward pool statistics
        RewardPool.GlobalStats memory stats = rewardPool.getGlobalStats();
        assertEq(stats.totalParticipants, 2);
        assertEq(stats.totalRewardsDistributed, 0); // Rewards are distributed through staking
        
        // Verify achievement statistics
        AchievementNFT.AchievementStats memory achievementStats = achievementNFT.getAchievementStats();
        assertEq(achievementStats.totalMinted, 2);
        assertEq(achievementStats.totalOwners, 2);
        
        // Verify validator earnings
        (,,,,,uint256 totalEarnings,,) = verificationOracle.getValidator(validator1);
        assertTrue(totalEarnings > 0);
    }

    // ========== Edge Case Tests ==========
    
    function testQuestExpiration() public {
        // Create quest with short duration
        vm.startPrank(creator);
        
        QuestFactory.CreateQuestParams memory params = _createQuestParams();
        params.duration = 1 hours; // Very short duration
        
        address shortQuestAddress = questFactory.createQuest{value: CREATION_FEE}(params);
        
        vm.stopPrank();
        
        // Wait for quest to expire
        vm.warp(block.timestamp + 2 hours);
        
        // Check quest status
        Quest shortQuest = Quest(payable(shortQuestAddress));
        (,,,,,,,Quest.QuestStatus status,) = shortQuest.getQuestStats();
        assertEq(uint256(status), uint256(Quest.QuestStatus.Expired));
    }
    
    function testDisputeResolution() public {
        _createQuest();
        
        Quest quest = Quest(payable(questAddress));
        uint256[] memory milestoneIds = quest.getMilestoneIds();
        uint256 milestoneId = milestoneIds[0];
        
        // Submit evidence
        vm.startPrank(participant1);
        quest.submitEvidence(
            milestoneId,
            "QmDisputedEvidence",
            keccak256("disputed_evidence")
        );
        vm.stopPrank();
        
        uint256[] memory evidenceIds = quest.getMilestoneEvidence(milestoneId);
        uint256 evidenceId = evidenceIds[0];
        
        // Request verification
        quest.requestVerification(evidenceId, VerificationOracle.VerificationType.Community, 2);
        
        // Validators vote against
        vm.startPrank(validator1);
        verificationOracle.castVote(evidenceId, false, 30, "Evidence seems fake");
        vm.stopPrank();
        
        vm.startPrank(validator2);
        verificationOracle.castVote(evidenceId, false, 25, "Poor quality evidence");
        vm.stopPrank();
        
        // Create dispute
        vm.startPrank(participant1);
        verificationOracle.createDispute{value: 1 ether}(
            evidenceId,
            "Evidence is legitimate",
            "Additional proof"
        );
        vm.stopPrank();
        
        // Verify dispute was created
        uint256 disputeId = verificationOracle.getDisputeByEvidence(evidenceId);
        assertTrue(disputeId > 0);
        
        (,,,,,,VerificationOracle.DisputeStatus disputeStatus,,) = verificationOracle.getDispute(disputeId);
        assertEq(uint256(disputeStatus), uint256(VerificationOracle.DisputeStatus.Pending));
    }
    
    function testValidatorSlashing() public {
        // Register malicious validator
        address maliciousValidator = makeAddr("maliciousValidator");
        vm.deal(maliciousValidator, VALIDATOR_STAKE);
        
        vm.startPrank(maliciousValidator);
        verificationOracle.registerValidator{value: VALIDATOR_STAKE}(VALIDATOR_STAKE);
        vm.stopPrank();
        
        // Slash validator for malicious behavior
        vm.startPrank(owner);
        verificationOracle.slashValidator(maliciousValidator, 5000, "Malicious voting");
        vm.stopPrank();
        
        // Verify validator was slashed
        (,,,,,VerificationOracle.ValidatorStatus status,,) = verificationOracle.getValidator(maliciousValidator);
        assertEq(uint256(status), uint256(VerificationOracle.ValidatorStatus.Slashed));
    }

    // ========== Performance Tests ==========
    
    function testMultipleQuestsPerformance() public {
        uint256 numQuests = 10;
        uint256 gasUsed;
        
        vm.startPrank(creator);
        
        for (uint256 i = 0; i < numQuests; i++) {
            uint256 gasBefore = gasleft();
            
            QuestFactory.CreateQuestParams memory params = _createQuestParams();
            params.title = string(abi.encodePacked("Quest ", i));
            
            questFactory.createQuest{value: CREATION_FEE}(params);
            
            gasUsed = gasBefore - gasleft();
            console.log("Gas used for quest", i, ":", gasUsed);
        }
        
        vm.stopPrank();
        
        assertEq(questFactory.totalQuests(), numQuests);
    }
    
    function testManyParticipantsPerformance() public {
        _createQuest();
        
        uint256 numParticipants = 20;
        address[] memory participants = new address[](numParticipants);
        
        // Create participants
        for (uint256 i = 0; i < numParticipants; i++) {
            participants[i] = makeAddr(string(abi.encodePacked("participant", i)));
            vm.deal(participants[i], STAKE_AMOUNT + 1 ether);
        }
        
        Quest quest = Quest(payable(questAddress));
        
        // All participants join
        vm.startPrank(participants[0]);
        for (uint256 i = 0; i < numParticipants; i++) {
            vm.stopPrank();
            vm.startPrank(participants[i]);
            
            uint256 gasBefore = gasleft();
            quest.joinQuest{value: STAKE_AMOUNT}();
            uint256 gasUsed = gasBefore - gasleft();
            
            if (i < 5) { // Log first few
                console.log("Gas used for participant", i, ":", gasUsed);
            }
        }
        vm.stopPrank();
        
        // Verify all participants joined
        address[] memory questParticipants = quest.getParticipants();
        assertEq(questParticipants.length, numParticipants);
    }

    // ========== Security Tests ==========
    
    function testReentrancyProtection() public {
        // Deploy malicious contract
        MaliciousQuest maliciousQuest = new MaliciousQuest(questAddress);
        
        vm.deal(address(maliciousQuest), STAKE_AMOUNT);
        
        // Attempt reentrancy attack
        vm.startPrank(address(maliciousQuest));
        vm.expectRevert();
        maliciousQuest.attemptReentrancy();
        vm.stopPrank();
    }
    
    function testUnauthorizedAccess() public {
        // Test unauthorized quest creation
        vm.startPrank(participant1);
        QuestFactory.CreateQuestParams memory params = _createQuestParams();
        vm.expectRevert();
        questFactory.createQuest{value: CREATION_FEE}(params);
        vm.stopPrank();
        
        // Test unauthorized reward distribution
        vm.startPrank(participant1);
        vm.expectRevert();
        rewardPool.distributeReward(questAddress, participant2, STAKE_AMOUNT);
        vm.stopPrank();
        
        // Test unauthorized verification
        vm.startPrank(participant1);
        vm.expectRevert();
        verificationOracle.castVote(1, true, 80, "Valid evidence");
        vm.stopPrank();
    }

    // ========== Helper Functions ==========
    
    function _createQuestParams() internal view returns (QuestFactory.CreateQuestParams memory) {
        QuestFactory.Milestone[] memory milestones = new QuestFactory.Milestone[](2);
        
        milestones[0] = QuestFactory.Milestone({
            title: "First Milestone",
            description: "Complete the first task",
            orderIndex: 0,
            verificationType: 0,
            requiredEvidence: new string[](1),
            deadline: block.timestamp + 7 days
        });
        milestones[0].requiredEvidence[0] = "photo";
        
        milestones[1] = QuestFactory.Milestone({
            title: "Second Milestone",
            description: "Complete the second task",
            orderIndex: 1,
            verificationType: 0,
            requiredEvidence: new string[](1),
            deadline: block.timestamp + 14 days
        });
        milestones[1].requiredEvidence[0] = "document";
        
        return QuestFactory.CreateQuestParams({
            title: "Integration Test Quest",
            description: "Quest for integration testing",
            creator: creator,
            stakeAmount: STAKE_AMOUNT,
            rewardPool: STAKE_AMOUNT * 2,
            duration: QUEST_DURATION,
            maxParticipants: 10,
            verificationThreshold: 2,
            category: "testing",
            rewardToken: address(0),
            milestones: milestones,
            metadataURI: "https://ipfs.io/ipfs/QmIntegrationTest"
        });
    }
}

/**
 * @title MaliciousQuest
 * @notice Malicious contract for testing reentrancy protection
 */
contract MaliciousQuest {
    Quest public quest;
    uint256 public callCount;
    
    constructor(address _quest) {
        quest = Quest(payable(_quest));
    }
    
    function attemptReentrancy() external {
        callCount++;
        if (callCount < 3) {
            quest.joinQuest{value: 1 ether}();
        }
    }
    
    receive() external payable {
        if (callCount < 3) {
            quest.joinQuest{value: 1 ether}();
        }
    }
}
