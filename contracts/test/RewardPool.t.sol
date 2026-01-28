// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/RewardPool.sol";
import "../src/GovernanceToken.sol";

/**
 * @title RewardPoolTest
 * @notice Comprehensive test suite for RewardPool contract
 */
contract RewardPoolTest is Test {
    // ========== Test State ==========
    
    RewardPool public rewardPool;
    GovernanceToken public governanceToken;
    
    address public owner;
    address public user1;
    address public user2;
    address public user3;
    address public quest;
    
    uint256 public constant MIN_STAKE_AMOUNT = 0.001 ether;
    uint256 public constant TEST_STAKE_AMOUNT = 1 ether;
    uint256 public constant TEST_REWARD_AMOUNT = 0.1 ether;
    
    // ========== Events ==========
    
    event Staked(
        uint256 indexed stakeId,
        address indexed user,
        address indexed quest,
        uint256 amount,
        address token,
        uint256 stakedAt
    );
    
    event Withdrawn(
        uint256 indexed stakeId,
        address indexed user,
        uint256 amount,
        uint256 fee,
        uint256 withdrawnAt
    );
    
    event RewardDistributed(
        uint256 indexed stakeId,
        address indexed user,
        uint256 rewardAmount,
        uint256 performanceBonus,
        uint256 speedBonus,
        uint256 distributedAt
    );
    
    event Slashed(
        uint256 indexed stakeId,
        address indexed user,
        uint256 slashAmount,
        uint256 percentage,
        uint256 slashedAt
    );

    // ========== Setup ==========
    
    function setUp() public {
        // Setup test accounts
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        quest = makeAddr("quest");
        
        // Fund accounts
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
        
        // Deploy contracts
        governanceToken = new GovernanceToken("ChainQuest Governance", "CQT", owner);
        rewardPool = new RewardPool(owner);
        
        // Setup roles
        _setupRoles();
        
        // Add governance token to reward pool
        rewardPool.addToken(address(governanceToken), "CQT", 18);
        
        // Mint tokens to users
        governanceToken.mint(user1, 1000 * 10**18);
        governanceToken.mint(user2, 1000 * 10**18);
        governanceToken.mint(user3, 1000 * 10**18);
    }
    
    function _setupRoles() internal {
        rewardPool.grantRole(rewardPool.REWARD_ADMIN_ROLE(), owner);
        rewardPool.grantRole(rewardPool.QUEST_CONTRACT_ROLE(), quest);
    }

    // ========== Constructor Tests ==========
    
    function testConstructor() public {
        assertEq(rewardPool.treasury(), owner);
        assertTrue(rewardPool.supportedTokens(address(0))); // ETH
        assertTrue(rewardPool.hasRole(rewardPool.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(rewardPool.hasRole(rewardPool.REWARD_ADMIN_ROLE(), owner));
        assertTrue(rewardPool.hasRole(rewardPool.QUEST_CONTRACT_ROLE(), quest));
        assertEq(rewardPool.globalStats().totalValueLocked, 0);
        assertEq(rewardPool.globalStats().totalRewardsDistributed, 0);
    }
    
    function testConstructorInvalidTreasury() public {
        vm.expectRevert();
        new RewardPool(address(0));
    }

    // ========== Staking Tests ==========
    
    function testStakeETH() public {
        vm.startPrank(user1);
        
        uint256 stakeAmount = TEST_STAKE_AMOUNT;
        
        vm.expectEmit(true, true, true, true);
        emit Staked(0, user1, quest, stakeAmount, address(0), block.timestamp);
        
        rewardPool.stake{value: stakeAmount}(quest, stakeAmount, address(0));
        
        // Verify stake
        (address user, address questAddr, uint256 amount, address token, uint256 stakedAt, uint256 lastActivity, bool active, uint256 rewardDebt) = rewardPool.getStake(0);
        assertEq(user, user1);
        assertEq(questAddr, quest);
        assertEq(amount, stakeAmount);
        assertEq(token, address(0));
        assertEq(stakedAt, block.timestamp);
        assertTrue(active);
        assertEq(rewardDebt, 0);
        
        // Verify global stats
        RewardPool.GlobalStats memory stats = rewardPool.getGlobalStats();
        assertEq(stats.totalValueLocked, stakeAmount);
        assertEq(stats.totalParticipants, 1);
        
        // Verify quest pool
        (uint256 totalStaked, uint256 totalRewards, uint256 totalSlashed, uint256 participantCount, uint256 createdAt, bool active) = rewardPool.getQuestPool(quest);
        assertEq(totalStaked, stakeAmount);
        assertEq(participantCount, 1);
        assertTrue(active);
        
        vm.stopPrank();
    }
    
    function testStakeERC20() public {
        vm.startPrank(user1);
        
        uint256 stakeAmount = 100 * 10**18; // 100 CQT
        
        // Approve tokens
        governanceToken.approve(address(rewardPool), stakeAmount);
        
        vm.expectEmit(true, true, true, true);
        emit Staked(0, user1, quest, stakeAmount, address(governanceToken), block.timestamp);
        
        rewardPool.stake(quest, stakeAmount, address(governanceToken));
        
        // Verify stake
        (address user, address questAddr, uint256 amount, address token, , , , ) = rewardPool.getStake(0);
        assertEq(user, user1);
        assertEq(questAddr, quest);
        assertEq(amount, stakeAmount);
        assertEq(token, address(governanceToken));
        
        vm.stopPrank();
    }
    
    function testStakeInvalidAmount() public {
        vm.startPrank(user1);
        
        vm.expectRevert();
        rewardPool.stake{value: 0}(quest, 0, address(0));
        
        vm.stopPrank();
    }
    
    function testStakeInsufficientAmount() public {
        vm.startPrank(user1);
        
        vm.expectRevert();
        rewardPool.stake{value: MIN_STAKE_AMOUNT - 1}(quest, MIN_STAKE_AMOUNT - 1, address(0));
        
        vm.stopPrank();
    }
    
    function testStakeAlreadyStaked() public {
        vm.startPrank(user1);
        
        // First stake
        rewardPool.stake{value: TEST_STAKE_AMOUNT}(quest, TEST_STAKE_AMOUNT, address(0));
        
        // Second stake should fail
        vm.expectRevert();
        rewardPool.stake{value: TEST_STAKE_AMOUNT}(quest, TEST_STAKE_AMOUNT, address(0));
        
        vm.stopPrank();
    }
    
    function testStakeUnsupportedToken() public {
        vm.startPrank(user1);
        
        address unsupportedToken = makeAddr("unsupportedToken");
        
        vm.expectRevert();
        rewardPool.stake(quest, TEST_STAKE_AMOUNT, unsupportedToken);
        
        vm.stopPrank();
    }

    // ========== Withdrawal Tests ==========
    
    function testWithdraw() public {
        vm.startPrank(user1);
        
        // Stake first
        uint256 stakeAmount = TEST_STAKE_AMOUNT;
        rewardPool.stake{value: stakeAmount}(quest, stakeAmount, address(0));
        
        // Wait some time to accumulate rewards
        vm.warp(block.timestamp + 1 days);
        
        uint256 balanceBefore = user1.balance;
        uint256 rewardAmount = rewardPool.calculateEstimatedReward(0);
        
        vm.expectEmit(true, true, true, true);
        emit Withdrawn(0, user1, stakeAmount, 0, block.timestamp);
        
        rewardPool.withdraw(0);
        
        // Verify withdrawal
        assertEq(user1.balance, balanceBefore + stakeAmount + rewardAmount);
        
        // Verify stake is inactive
        (, , , , , , bool active, ) = rewardPool.getStake(0);
        assertFalse(active);
        
        vm.stopPrank();
    }
    
    function testWithdrawUnauthorized() public {
        vm.startPrank(user1);
        
        // Stake
        rewardPool.stake{value: TEST_STAKE_AMOUNT}(quest, TEST_STAKE_AMOUNT, address(0));
        
        vm.stopPrank();
        
        // Try to withdraw from different account
        vm.startPrank(user2);
        
        vm.expectRevert();
        rewardPool.withdraw(0);
        
        vm.stopPrank();
    }
    
    function testEmergencyWithdraw() public {
        vm.startPrank(user1);
        
        // Stake
        uint256 stakeAmount = TEST_STAKE_AMOUNT;
        rewardPool.stake{value: stakeAmount}(quest, stakeAmount, address(0));
        
        uint256 balanceBefore = user1.balance;
        uint256 treasuryBalanceBefore = owner.balance;
        
        // Emergency withdraw (10% fee)
        rewardPool.emergencyWithdraw(0);
        
        // Verify withdrawal with fee
        uint256 expectedFee = stakeAmount * 10 / 100; // 10% fee
        uint256 expectedWithdrawal = stakeAmount - expectedFee;
        
        assertEq(user1.balance, balanceBefore + expectedWithdrawal);
        assertEq(owner.balance, treasuryBalanceBefore + expectedFee);
        
        vm.stopPrank();
    }

    // ========== Reward Distribution Tests ==========
    
    function testDistributeReward() public {
        vm.startPrank(user1);
        
        // Stake
        uint256 stakeAmount = TEST_STAKE_AMOUNT;
        rewardPool.stake{value: stakeAmount}(quest, stakeAmount, address(0));
        
        vm.stopPrank();
        
        // Distribute reward (called by quest contract)
        vm.startPrank(quest);
        
        uint256 rewardAmount = TEST_REWARD_AMOUNT;
        uint256 balanceBefore = user1.balance;
        
        vm.expectEmit(true, true, true, true);
        emit RewardDistributed(0, user1, rewardAmount, 0, 0, block.timestamp);
        
        rewardPool.distributeReward(quest, user1, rewardAmount);
        
        assertEq(user1.balance, balanceBefore + rewardAmount);
        
        vm.stopPrank();
    }
    
    function testDistributeRewardUnauthorized() public {
        vm.startPrank(user1);
        
        vm.expectRevert();
        rewardPool.distributeReward(quest, user2, TEST_REWARD_AMOUNT);
        
        vm.stopPrank();
    }

    // ========== Slashing Tests ==========
    
    function testSlash() public {
        vm.startPrank(user1);
        
        // Stake
        uint256 stakeAmount = TEST_STAKE_AMOUNT;
        rewardPool.stake{value: stakeAmount}(quest, stakeAmount, address(0));
        
        vm.stopPrank();
        
        // Slash (called by quest contract)
        vm.startPrank(quest);
        
        uint256 slashPercentage = 5000; // 50%
        uint256 balanceBefore = user1.balance;
        uint256 treasuryBalanceBefore = owner.balance;
        
        vm.expectEmit(true, true, true, true);
        emit Slashed(0, user1, stakeAmount / 2, slashPercentage, block.timestamp);
        
        rewardPool.slash(user1, slashPercentage);
        
        // Verify slash
        uint256 expectedRefund = stakeAmount / 2;
        assertEq(user1.balance, balanceBefore + expectedRefund);
        assertEq(owner.balance, treasuryBalanceBefore + expectedRefund);
        
        vm.stopPrank();
    }
    
    function testSlashUnauthorized() public {
        vm.startPrank(user1);
        
        vm.expectRevert();
        rewardPool.slash(user2, 5000);
        
        vm.stopPrank();
    }
    
    function testSlashMaxPercentage() public {
        vm.startPrank(user1);
        
        // Stake
        rewardPool.stake{value: TEST_STAKE_AMOUNT}(quest, TEST_STAKE_AMOUNT, address(0));
        
        vm.stopPrank();
        
        // Try to slash more than 100%
        vm.startPrank(quest);
        
        vm.expectRevert();
        rewardPool.slash(user1, 10001); // 100.01%
        
        vm.stopPrank();
    }

    // ========== Token Management Tests ==========
    
    function testAddToken() public {
        address newToken = makeAddr("newToken");
        
        vm.startPrank(owner);
        
        rewardPool.addToken(newToken, "NEW", 18);
        
        assertTrue(rewardPool.supportedTokens(newToken));
        
        vm.stopPrank();
    }
    
    function testAddTokenUnauthorized() public {
        address newToken = makeAddr("newToken");
        
        vm.startPrank(user1);
        
        vm.expectRevert();
        rewardPool.addToken(newToken, "NEW", 18);
        
        vm.stopPrank();
    }
    
    function testRemoveToken() public {
        address newToken = makeAddr("newToken");
        
        vm.startPrank(owner);
        
        // Add token first
        rewardPool.addToken(newToken, "NEW", 18);
        
        // Remove token
        rewardPool.removeToken(newToken);
        
        assertFalse(rewardPool.supportedTokens(newToken));
        
        vm.stopPrank();
    }
    
    function testRemoveTokenWithActiveStakes() public {
        vm.startPrank(owner);
        
        // Can't remove ETH as it has active stakes
        vm.expectRevert();
        rewardPool.removeToken(address(0));
        
        vm.stopPrank();
    }

    // ========== Parameter Update Tests ==========
    
    function testUpdateRewardParameters() public {
        vm.startPrank(owner);
        
        rewardPool.updateRewardParameters(2000, 60, 1500);
        
        assertEq(rewardPool.baseRewardRate(), 2000);
        assertEq(rewardPool.speedBonusThreshold(), 60);
        assertEq(rewardPool.speedBonusRate(), 1500);
        
        vm.stopPrank();
    }
    
    function testUpdateRewardParametersUnauthorized() public {
        vm.startPrank(user1);
        
        vm.expectRevert();
        rewardPool.updateRewardParameters(2000, 60, 1500);
        
        vm.stopPrank();
    }
    
    function testUpdateTreasury() public {
        address newTreasury = makeAddr("newTreasury");
        
        vm.startPrank(owner);
        
        rewardPool.updateTreasury(newTreasury);
        
        assertEq(rewardPool.treasury(), newTreasury);
        
        vm.stopPrank();
    }
    
    function testUpdateEmergencyWithdrawalFee() public {
        vm.startPrank(owner);
        
        rewardPool.updateEmergencyWithdrawalFee(2000); // 20%
        
        assertEq(rewardPool.emergencyWithdrawalFee(), 2000);
        
        vm.stopPrank();
    }

    // ========== View Function Tests ==========
    
    function testGetStake() public {
        vm.startPrank(user1);
        
        uint256 stakeAmount = TEST_STAKE_AMOUNT;
        rewardPool.stake{value: stakeAmount}(quest, stakeAmount, address(0));
        
        (address user, address questAddr, uint256 amount, address token, uint256 stakedAt, uint256 lastActivity, bool active, uint256 rewardDebt) = rewardPool.getStake(0);
        
        assertEq(user, user1);
        assertEq(questAddr, quest);
        assertEq(amount, stakeAmount);
        assertEq(token, address(0));
        assertEq(stakedAt, block.timestamp);
        assertEq(lastActivity, block.timestamp);
        assertTrue(active);
        assertEq(rewardDebt, 0);
        
        vm.stopPrank();
    }
    
    function testGetQuestPool() public {
        vm.startPrank(user1);
        
        uint256 stakeAmount = TEST_STAKE_AMOUNT;
        rewardPool.stake{value: stakeAmount}(quest, stakeAmount, address(0));
        
        (uint256 totalStaked, uint256 totalRewards, uint256 totalSlashed, uint256 participantCount, uint256 createdAt, bool active) = rewardPool.getQuestPool(quest);
        
        assertEq(totalStaked, stakeAmount);
        assertEq(totalRewards, 0);
        assertEq(totalSlashed, 0);
        assertEq(participantCount, 1);
        assertEq(createdAt, block.timestamp);
        assertTrue(active);
        
        vm.stopPrank();
    }
    
    function testGetUserStakes() public {
        vm.startPrank(user1);
        
        // Create multiple stakes for different quests
        address quest2 = makeAddr("quest2");
        
        rewardPool.stake{value: TEST_STAKE_AMOUNT}(quest, TEST_STAKE_AMOUNT, address(0));
        rewardPool.stake{value: TEST_STAKE_AMOUNT}(quest2, TEST_STAKE_AMOUNT, address(0));
        
        uint256[] memory stakeIds = rewardPool.getUserStakes(user1);
        assertEq(stakeIds.length, 2);
        assertEq(stakeIds[0], 0);
        assertEq(stakeIds[1], 1);
        
        vm.stopPrank();
    }
    
    function testCalculateEstimatedReward() public {
        vm.startPrank(user1);
        
        uint256 stakeAmount = TEST_STAKE_AMOUNT;
        rewardPool.stake{value: stakeAmount}(quest, stakeAmount, address(0));
        
        uint256 estimatedReward = rewardPool.calculateEstimatedReward(0);
        
        // Should be greater than 0 due to base reward rate
        assertTrue(estimatedReward > 0);
        
        vm.stopPrank();
    }
    
    function testGetSupportedTokens() public {
        address[] memory tokens = rewardPool.getSupportedTokens();
        
        assertEq(tokens.length, 2); // ETH and CQT
        assertEq(tokens[0], address(0)); // ETH
        assertEq(tokens[1], address(governanceToken)); // CQT
    }
    
    function testGetTokenBalance() public {
        vm.startPrank(user1);
        
        uint256 stakeAmount = TEST_STAKE_AMOUNT;
        rewardPool.stake{value: stakeAmount}(quest, stakeAmount, address(0));
        
        assertEq(rewardPool.getTokenBalance(address(0)), stakeAmount);
        
        vm.stopPrank();
    }

    // ========== Emergency Function Tests ==========
    
    function testPause() public {
        vm.startPrank(owner);
        rewardPool.pause();
        assertTrue(rewardPool.paused());
        vm.stopPrank();
    }
    
    function testPauseUnauthorized() public {
        vm.expectRevert();
        rewardPool.pause();
    }
    
    function testUnpause() public {
        vm.startPrank(owner);
        rewardPool.pause();
        rewardPool.unpause();
        assertFalse(rewardPool.paused());
        vm.stopPrank();
    }

    // ========== Gas Tests ==========
    
    function testStakeGasUsage() public {
        vm.startPrank(user1);
        
        uint256 gasBefore = gasleft();
        rewardPool.stake{value: TEST_STAKE_AMOUNT}(quest, TEST_STAKE_AMOUNT, address(0));
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for stake:", gasUsed);
        
        vm.stopPrank();
    }
    
    function testWithdrawGasUsage() public {
        vm.startPrank(user1);
        
        // Stake first
        rewardPool.stake{value: TEST_STAKE_AMOUNT}(quest, TEST_STAKE_AMOUNT, address(0));
        
        uint256 gasBefore = gasleft();
        rewardPool.withdraw(0);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for withdraw:", gasUsed);
        
        vm.stopPrank();
    }

    // ========== Fuzz Tests ==========
    
    function testFuzzStake(uint256 stakeAmount) public {
        vm.assume(stakeAmount >= MIN_STAKE_AMOUNT && stakeAmount <= 1000 ether);
        
        vm.startPrank(user1);
        
        rewardPool.stake{value: stakeAmount}(quest, stakeAmount, address(0));
        
        (, , uint256 amount, , , , , ) = rewardPool.getStake(0);
        assertEq(amount, stakeAmount);
        
        vm.stopPrank();
    }
    
    function testFuzzDistributeReward(uint256 rewardAmount) public {
        vm.assume(rewardAmount > 0 && rewardAmount <= 10 ether);
        
        vm.startPrank(user1);
        
        // Stake
        rewardPool.stake{value: TEST_STAKE_AMOUNT}(quest, TEST_STAKE_AMOUNT, address(0));
        
        vm.stopPrank();
        
        // Distribute reward
        vm.startPrank(quest);
        
        uint256 balanceBefore = user1.balance;
        rewardPool.distributeReward(quest, user1, rewardAmount);
        uint256 balanceAfter = user1.balance;
        
        assertEq(balanceAfter - balanceBefore, rewardAmount);
        
        vm.stopPrank();
    }

    // ========== Integration Tests ==========
    
    function testFullQuestLifecycle() public {
        vm.startPrank(user1);
        
        // 1. Stake
        uint256 stakeAmount = TEST_STAKE_AMOUNT;
        rewardPool.stake{value: stakeAmount}(quest, stakeAmount, address(0));
        
        // 2. Wait for rewards
        vm.warp(block.timestamp + 7 days);
        
        // 3. Distribute reward
        vm.stopPrank();
        vm.startPrank(quest);
        
        uint256 rewardAmount = TEST_REWARD_AMOUNT;
        rewardPool.distributeReward(quest, user1, rewardAmount);
        
        vm.stopPrank();
        
        // 4. Withdraw
        vm.startPrank(user1);
        
        uint256 balanceBefore = user1.balance;
        rewardPool.withdraw(0);
        uint256 balanceAfter = user1.balance;
        
        uint256 expectedTotal = stakeAmount + rewardAmount;
        assertEq(balanceAfter - balanceBefore, expectedTotal);
        
        vm.stopPrank();
    }
}
