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
 * @title QuestFactoryTest
 * @notice Comprehensive test suite for QuestFactory contract
 */
contract QuestFactoryTest is Test {
    // ========== Test State ==========
    
    QuestFactory public questFactory;
    Quest public questImplementation;
    RewardPool public rewardPool;
    VerificationOracle public verificationOracle;
    AchievementNFT public achievementNFT;
    GovernanceToken public governanceToken;
    
    address public owner;
    address public creator;
    address public user1;
    address public user2;
    address public user3;
    
    uint256 public constant CREATION_FEE = 0.01 ether;
    uint256 public constant STAKE_AMOUNT = 1 ether;
    uint256 public constant QUEST_DURATION = 30 days;
    
    // ========== Events ==========
    
    event QuestCreated(
        uint256 indexed questId,
        address indexed questAddress,
        address indexed creator,
        string title,
        string category,
        uint256 stakeAmount,
        uint256 createdAt
    );

    // ========== Setup ==========
    
    function setUp() public {
        // Setup test accounts
        owner = address(this);
        creator = makeAddr("creator");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        
        // Fund accounts
        vm.deal(creator, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
        
        // Deploy contracts
        _deployContracts();
        
        // Setup roles
        _setupRoles();
    }
    
    function _deployContracts() internal {
        // Deploy governance token first
        governanceToken = new GovernanceToken(
            "ChainQuest Governance",
            "CQT",
            owner
        );
        
        // Deploy reward pool
        rewardPool = new RewardPool(owner);
        
        // Deploy verification oracle
        verificationOracle = new VerificationOracle(address(governanceToken));
        
        // Deploy achievement NFT
        achievementNFT = new AchievementNFT(
            "ChainQuest Achievements",
            "CQA",
            owner
        );
        
        // Deploy quest implementation
        questImplementation = new Quest();
        
        // Deploy quest factory
        questFactory = new QuestFactory(address(questImplementation));
    }
    
    function _setupRoles() internal {
        // Grant roles to contracts
        questFactory.grantRole(questFactory.ADMIN_ROLE(), owner);
        questFactory.grantRole(questFactory.QUEST_CREATOR_ROLE(), creator);
        
        rewardPool.grantRole(rewardPool.QUEST_CONTRACT_ROLE(), address(questFactory));
        
        verificationOracle.grantRole(verificationOracle.VALIDATOR_ROLE(), owner);
        
        achievementNFT.grantRole(achievementNFT.MINTER_ROLE(), owner);
        
        governanceToken.grantRole(governanceToken.MINTER_ROLE(), owner);
    }

    // ========== Constructor Tests ==========
    
    function testConstructor() public {
        assertEq(address(questFactory.questImplementation), address(questImplementation));
        assertTrue(questFactory.hasRole(questFactory.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(questFactory.hasRole(questFactory.ADMIN_ROLE(), owner));
        assertTrue(questFactory.hasRole(questFactory.QUEST_CREATOR_ROLE(), owner));
        assertEq(questFactory.nextQuestId(), 1);
        assertEq(questFactory.totalQuests(), 0);
    }
    
    function testConstructorInvalidImplementation() public {
        vm.expectRevert();
        new QuestFactory(address(0));
    }

    // ========== Quest Creation Tests ==========
    
    function testCreateQuest() public {
        vm.startPrank(creator);
        
        CreateQuestParams memory params = _createValidQuestParams();
        
        vm.expectEmit(true, true, true, true);
        emit QuestCreated(1, address(0), creator, params.title, params.category, params.stakeAmount, block.timestamp);
        
        address questAddress = questFactory.createQuest{value: CREATION_FEE}(params);
        
        // Verify quest was created
        assertTrue(questAddress != address(0));
        assertEq(questFactory.nextQuestId(), 2);
        assertEq(questFactory.totalQuests(), 1);
        
        // Verify quest info
        QuestFactory.QuestInfo memory questInfo = questFactory.getQuest(1);
        assertEq(questInfo.id, 1);
        assertEq(questInfo.questAddress, questAddress);
        assertEq(questInfo.creator, creator);
        assertEq(questInfo.title, params.title);
        assertEq(questInfo.category, params.category);
        assertTrue(questInfo.isActive);
        
        // Verify creator quests
        uint256[] memory creatorQuests = questFactory.getCreatorQuests(creator);
        assertEq(creatorQuests.length, 1);
        assertEq(creatorQuests[0], 1);
        
        vm.stopPrank();
    }
    
    function testCreateQuestInvalidFee() public {
        vm.startPrank(creator);
        
        CreateQuestParams memory params = _createValidQuestParams();
        
        vm.expectRevert();
        questFactory.createQuest{value: CREATION_FEE - 1}(params);
        
        vm.stopPrank();
    }
    
    function testCreateQuestUnauthorized() public {
        CreateQuestParams memory params = _createValidQuestParams();
        
        vm.expectRevert();
        questFactory.createQuest{value: CREATION_FEE}(params);
    }
    
    function testCreateQuestInvalidParams() public {
        vm.startPrank(creator);
        
        // Test invalid stake amount
        CreateQuestParams memory params = _createValidQuestParams();
        params.stakeAmount = 0;
        
        vm.expectRevert();
        questFactory.createQuest{value: CREATION_FEE}(params);
        
        // Test invalid duration
        params = _createValidQuestParams();
        params.duration = 0;
        
        vm.expectRevert();
        questFactory.createQuest{value: CREATION_FEE}(params);
        
        // Test empty title
        params = _createValidQuestParams();
        params.title = "";
        
        vm.expectRevert();
        questFactory.createQuest{value: CREATION_FEE}(params);
        
        vm.stopPrank();
    }
    
    function testCreateQuestMaxQuestsReached() public {
        vm.startPrank(creator);
        
        CreateQuestParams memory params = _createValidQuestParams();
        
        // Create maximum number of quests
        for (uint256 i = 0; i < 100; i++) {
            questFactory.createQuest{value: CREATION_FEE}(params);
        }
        
        // Try to create one more
        vm.expectRevert();
        questFactory.createQuest{value: CREATION_FEE}(params);
        
        vm.stopPrank();
    }
    
    function testCreateQuestFromTemplate() public {
        vm.startPrank(creator);
        
        // Create template first
        QuestFactory.QuestTemplateData memory templateData = _createValidTemplateData();
        uint256 templateId = questFactory.createQuestTemplate("Test Template", "Description", templateData);
        
        // Create quest from template
        CreateQuestParams memory customParams = _createValidQuestParams();
        customParams.title = "Custom Quest";
        
        address questAddress = questFactory.createQuestFromTemplate{value: CREATION_FEE}(templateId, customParams);
        
        assertTrue(questAddress != address(0));
        
        vm.stopPrank();
    }

    // ========== Quest Template Tests ==========
    
    function testCreateQuestTemplate() public {
        vm.startPrank(creator);
        
        QuestFactory.QuestTemplateData memory templateData = _createValidTemplateData();
        
        uint256 templateId = questFactory.createQuestTemplate("Test Template", "Description", templateData);
        
        assertEq(templateId, 1);
        assertEq(questFactory.nextTemplateId(), 2);
        
        // Verify template
        QuestFactory.QuestTemplate memory template = questFactory.getTemplate(templateId);
        assertEq(template.id, templateId);
        assertEq(template.name, "Test Template");
        assertEq(template.creator, creator);
        assertTrue(template.isActive);
        
        vm.stopPrank();
    }
    
    function testCreateQuestTemplateUnauthorized() public {
        QuestFactory.QuestTemplateData memory templateData = _createValidTemplateData();
        
        vm.expectRevert();
        questFactory.createQuestTemplate("Test Template", "Description", templateData);
    }

    // ========== Quest Management Tests ==========
    
    function testUpdateQuestStatus() public {
        vm.startPrank(creator);
        
        CreateQuestParams memory params = _createValidQuestParams();
        address questAddress = questFactory.createQuest{value: CREATION_FEE}(params);
        
        vm.stopPrank();
        
        // Update quest status
        vm.startPrank(owner);
        questFactory.updateQuestStatus(1, false);
        
        QuestFactory.QuestInfo memory questInfo = questFactory.getQuest(1);
        assertFalse(questInfo.isActive);
        
        vm.stopPrank();
    }
    
    function testUpdateQuestStatusUnauthorized() public {
        vm.startPrank(creator);
        
        CreateQuestParams memory params = _createValidQuestParams();
        questFactory.createQuest{value: CREATION_FEE}(params);
        
        vm.expectRevert();
        questFactory.updateQuestStatus(1, false);
        
        vm.stopPrank();
    }
    
    function testUpdateQuestImplementation() public {
        Quest newImplementation = new Quest();
        
        vm.startPrank(owner);
        questFactory.updateQuestImplementation(address(newImplementation));
        
        assertEq(questFactory.questImplementation(), address(newImplementation));
        
        vm.stopPrank();
    }
    
    function testUpdateQuestImplementationUnauthorized() public {
        Quest newImplementation = new Quest();
        
        vm.expectRevert();
        questFactory.updateQuestImplementation(address(newImplementation));
    }

    // ========== System Contract Tests ==========
    
    function testUpdateSystemContracts() public {
        vm.startPrank(owner);
        
        questFactory.updateSystemContracts(
            address(rewardPool),
            address(verificationOracle),
            address(achievementNFT),
            address(governanceToken)
        );
        
        // Verify system contracts are set
        // (This would require a getter function in the actual contract)
        
        vm.stopPrank();
    }
    
    function testUpdateSystemContractsUnauthorized() public {
        vm.expectRevert();
        questFactory.updateSystemContracts(
            address(rewardPool),
            address(verificationOracle),
            address(achievementNFT),
            address(governanceToken)
        );
    }

    // ========== View Function Tests ==========
    
    function testGetQuest() public {
        vm.startPrank(creator);
        
        CreateQuestParams memory params = _createValidQuestParams();
        questFactory.createQuest{value: CREATION_FEE}(params);
        
        QuestFactory.QuestInfo memory questInfo = questFactory.getQuest(1);
        
        assertEq(questInfo.id, 1);
        assertEq(questInfo.creator, creator);
        assertEq(questInfo.title, params.title);
        
        vm.stopPrank();
    }
    
    function testGetQuestNotFound() public {
        vm.expectRevert();
        questFactory.getQuest(999);
    }
    
    function testGetCreatorQuests() public {
        vm.startPrank(creator);
        
        CreateQuestParams memory params = _createValidQuestParams();
        
        // Create multiple quests
        for (uint256 i = 0; i < 3; i++) {
            questFactory.createQuest{value: CREATION_FEE}(params);
        }
        
        uint256[] memory creatorQuests = questFactory.getCreatorQuests(creator);
        assertEq(creatorQuests.length, 3);
        assertEq(creatorQuests[0], 1);
        assertEq(creatorQuests[1], 2);
        assertEq(creatorQuests[2], 3);
        
        vm.stopPrank();
    }
    
    function testGetQuestsByCategory() public {
        vm.startPrank(creator);
        
        CreateQuestParams memory params = _createValidQuestParams();
        params.category = "fitness";
        questFactory.createQuest{value: CREATION_FEE}(params);
        
        params.category = "learning";
        questFactory.createQuest{value: CREATION_FEE}(params);
        
        uint256[] memory fitnessQuests = questFactory.getQuestsByCategory("fitness");
        assertEq(fitnessQuests.length, 1);
        assertEq(fitnessQuests[0], 1);
        
        uint256[] memory learningQuests = questFactory.getQuestsByCategory("learning");
        assertEq(learningQuests.length, 1);
        assertEq(learningQuests[0], 2);
        
        vm.stopPrank();
    }
    
    function testGetQuestsPaginated() public {
        vm.startPrank(creator);
        
        CreateQuestParams memory params = _createValidQuestParams();
        
        // Create multiple quests
        for (uint256 i = 0; i < 10; i++) {
            questFactory.createQuest{value: CREATION_FEE}(params);
        }
        
        uint256[] memory page1 = questFactory.getQuestsPaginated(0, 5, "", address(0));
        assertEq(page1.length, 5);
        
        uint256[] memory page2 = questFactory.getQuestsPaginated(5, 5, "", address(0));
        assertEq(page2.length, 5);
        
        vm.stopPrank();
    }
    
    function testGetFactoryStats() public {
        vm.startPrank(creator);
        
        CreateQuestParams memory params = _createValidQuestParams();
        
        // Create some quests
        for (uint256 i = 0; i < 3; i++) {
            questFactory.createQuest{value: CREATION_FEE}(params);
        }
        
        (uint256 totalQuests, uint256 totalTemplates, uint256 activeQuests, uint256 totalCreators) = questFactory.getFactoryStats();
        
        assertEq(totalQuests, 3);
        assertEq(totalTemplates, 0);
        assertEq(activeQuests, 3);
        assertEq(totalCreators, 1);
        
        vm.stopPrank();
    }

    // ========== Emergency Function Tests ==========
    
    function testPause() public {
        vm.startPrank(owner);
        questFactory.pause();
        assertTrue(questFactory.paused());
        vm.stopPrank();
    }
    
    function testPauseUnauthorized() public {
        vm.expectRevert();
        questFactory.pause();
    }
    
    function testUnpause() public {
        vm.startPrank(owner);
        questFactory.pause();
        questFactory.unpause();
        assertFalse(questFactory.paused());
        vm.stopPrank();
    }
    
    function testWithdrawFees() public {
        vm.startPrank(creator);
        
        CreateQuestParams memory params = _createValidQuestParams();
        questFactory.createQuest{value: CREATION_FEE}(params);
        
        vm.stopPrank();
        
        uint256 balanceBefore = owner.balance;
        
        vm.startPrank(owner);
        questFactory.withdrawFees(owner, CREATION_FEE);
        
        assertEq(owner.balance, balanceBefore + CREATION_FEE);
        vm.stopPrank();
    }
    
    function testWithdrawFeesUnauthorized() public {
        vm.expectRevert();
        questFactory.withdrawFees(user1, CREATION_FEE);
    }

    // ========== Gas Tests ==========
    
    function testCreateQuestGasUsage() public {
        vm.startPrank(creator);
        
        CreateQuestParams memory params = _createValidQuestParams();
        
        uint256 gasBefore = gasleft();
        questFactory.createQuest{value: CREATION_FEE}(params);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for createQuest:", gasUsed);
        
        vm.stopPrank();
    }
    
    function testCreateQuestTemplateGasUsage() public {
        vm.startPrank(creator);
        
        QuestFactory.QuestTemplateData memory templateData = _createValidTemplateData();
        
        uint256 gasBefore = gasleft();
        questFactory.createQuestTemplate("Test Template", "Description", templateData);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for createQuestTemplate:", gasUsed);
        
        vm.stopPrank();
    }

    // ========== Fuzz Tests ==========
    
    function testFuzzCreateQuest(uint256 stakeAmount, uint256 duration) public {
        vm.assume(stakeAmount > 0 && stakeAmount <= 1000 ether);
        vm.assume(duration > 0 && duration <= 365 days);
        
        vm.startPrank(creator);
        
        CreateQuestParams memory params = _createValidQuestParams();
        params.stakeAmount = stakeAmount;
        params.duration = duration;
        
        questFactory.createQuest{value: CREATION_FEE}(params);
        
        vm.stopPrank();
    }

    // ========== Helper Functions ==========
    
    function _createValidQuestParams() internal view returns (CreateQuestParams memory) {
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
        
        return CreateQuestParams({
            title: "Test Quest",
            description: "A test quest for testing",
            creator: creator,
            stakeAmount: STAKE_AMOUNT,
            rewardPool: STAKE_AMOUNT * 2,
            duration: QUEST_DURATION,
            maxParticipants: 10,
            verificationThreshold: 3,
            category: "testing",
            rewardToken: address(0),
            milestones: milestones,
            metadataURI: "https://ipfs.io/ipfs/QmTest"
        });
    }
    
    function _createValidTemplateData() internal view returns (QuestFactory.QuestTemplateData memory) {
        QuestFactory.Milestone[] memory milestones = new QuestFactory.Milestone[](1);
        milestones[0] = QuestFactory.Milestone({
            title: "Template Milestone",
            description: "A milestone from template",
            orderIndex: 0,
            verificationType: 0,
            requiredEvidence: new string[](1),
            deadline: block.timestamp + 7 days
        });
        milestones[0].requiredEvidence[0] = "photo";
        
        return QuestFactory.QuestTemplateData({
            defaultStakeAmount: STAKE_AMOUNT,
            defaultDuration: QUEST_DURATION,
            maxParticipants: 10,
            verificationThreshold: 3,
            category: "template",
            milestones: milestones
        });
    }
}
