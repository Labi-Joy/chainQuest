// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title RewardPool
 * @notice Manages staking, rewards, and slashing for quests
 * @dev Handles multiple tokens and calculates rewards based on performance
 */
contract RewardPool is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ========== Constants ==========
    bytes32 public constant REWARD_ADMIN_ROLE = keccak256("REWARD_ADMIN_ROLE");
    bytes32 public constant QUEST_CONTRACT_ROLE = keccak256("QUEST_CONTRACT_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    uint256 public constant MIN_STAKE_AMOUNT = 0.001 ether;
    uint256 public constant MAX_SLASH_PERCENTAGE = 10000; // 100% in basis points
    uint256 public constant DEFAULT_SLASH_PERCENTAGE = 5000; // 50% in basis points
    uint256 public constant REWARD_BASIS_POINTS = 10000;
    uint256 public constant PERFORMANCE_BONUS_MAX = 2000; // 20% max bonus
    
    // ========== Structs ==========
    
    struct Stake {
        address user;
        address quest;
        uint256 amount;
        address token;
        uint256 stakedAt;
        uint256 lastActivity;
        bool active;
        uint256 rewardDebt;
    }
    
    struct QuestPool {
        address questAddress;
        uint256 totalStaked;
        uint256 totalRewards;
        uint256 totalSlashed;
        uint256 participantCount;
        uint256 createdAt;
        bool active;
        mapping(address => uint256) userStakes;
        address[] participants;
    }
    
    struct RewardCalculation {
        uint256 baseReward;
        uint256 performanceBonus;
        uint256 speedBonus;
        uint256 totalReward;
        uint256 timestamp;
    }
    
    struct GlobalStats {
        uint256 totalValueLocked;
        uint256 totalRewardsDistributed;
        uint256 totalSlashed;
        uint256 activeQuests;
        uint256 totalParticipants;
    }

    // ========== State Variables ==========
    
    // Staking data
    mapping(uint256 => Stake) public stakes; // stakeId => Stake
    mapping(address => uint256[]) public userStakes; // user => stakeIds
    mapping(address => uint256[]) public questStakes; // quest => stakeIds
    
    // Quest pools
    mapping(address => QuestPool) public questPools;
    address[] public activeQuests;
    
    // Token balances
    mapping(address => uint256) public tokenBalances; // token => balance
    mapping(address => bool) public supportedTokens;
    address[] public tokenList;
    
    // Reward calculation parameters
    uint256 public baseRewardRate = 1000; // 10% base reward
    uint256 public speedBonusThreshold = 50; // 50% faster than average gets bonus
    uint256 public speedBonusRate = 1000; // 10% speed bonus
    
    // Global statistics
    GlobalStats public globalStats;
    
    // Treasury
    address public treasury;
    uint256 public treasuryBalance;
    
    // Emergency controls
    uint256 public emergencyWithdrawalFee = 1000; // 10% fee for emergency withdrawals
    
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
    
    event QuestPoolCreated(
        address indexed questAddress,
        uint256 createdAt
    );
    
    event QuestPoolUpdated(
        address indexed questAddress,
        bool active,
        uint256 updatedAt
    );
    
    event TokenAdded(
        address indexed token,
        string symbol,
        uint256 decimals
    );
    
    event TokenRemoved(
        address indexed token
    );
    
    event RewardParametersUpdated(
        uint256 baseRewardRate,
        uint256 speedBonusThreshold,
        uint256 speedBonusRate
    );
    
    event TreasuryUpdated(
        address indexed newTreasury,
        uint256 transferredAmount
    );
    
    event EmergencyWithdrawal(
        address indexed user,
        uint256 amount,
        uint256 fee,
        uint256 timestamp
    );

    // ========== Errors ==========
    
    error RewardPool__InvalidAddress();
    error RewardPool__InvalidAmount();
    error RewardPool__InvalidToken();
    error RewardPool__InsufficientBalance();
    error RewardPool__InsufficientStake();
    error RewardPool__Unauthorized();
    error RewardPool__StakeNotFound();
    error RewardPool__StakeNotActive();
    error RewardPool__QuestNotFound();
    error RewardPool__InvalidPercentage();
    error RewardPool__AlreadyStaked();
    error RewardPool__MaxSlashPercentage();
    error RewardPool__TransferFailed();

    // ========== Modifiers ==========
    
    modifier onlyRewardAdmin() {
        if (!hasRole(REWARD_ADMIN_ROLE, msg.sender) && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert RewardPool__Unauthorized();
        }
        _;
    }
    
    modifier onlyQuestContract() {
        if (!hasRole(QUEST_CONTRACT_ROLE, msg.sender)) {
            revert RewardPool__Unauthorized();
        }
        _;
    }
    
    modifier onlyEmergencyRole() {
        if (!hasRole(EMERGENCY_ROLE, msg.sender)) {
            revert RewardPool__Unauthorized();
        }
        _;
    }
    
    modifier validAddress(address addr) {
        if (addr == address(0)) {
            revert RewardPool__InvalidAddress();
        }
        _;
    }
    
    modifier validAmount(uint256 amount) {
        if (amount == 0) {
            revert RewardPool__InvalidAmount();
        }
        _;
    }
    
    modifier supportedToken(address token) {
        if (token != address(0) && !supportedTokens[token]) {
            revert RewardPool__InvalidToken();
        }
        _;
    }
    
    modifier validStakeId(uint256 stakeId) {
        if (stakeId >= userStakes[msg.sender].length || stakes[stakeId].user == address(0)) {
            revert RewardPool__StakeNotFound();
        }
        _;
    }
    
    modifier activeStake(uint256 stakeId) {
        if (!stakes[stakeId].active) {
            revert RewardPool__StakeNotActive();
        }
        _;

    // ========== Constructor ==========
    
    constructor(address _treasury) validAddress(_treasury) {
        treasury = _treasury;
        
        // Add ETH as supported token (address(0) represents ETH)
        supportedTokens[address(0)] = true;
        tokenList.push(address(0));
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REWARD_ADMIN_ROLE, msg.sender);
        _grantRole(QUEST_CONTRACT_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);
        
        // Initialize global stats
        globalStats = GlobalStats({
            totalValueLocked: 0,
            totalRewardsDistributed: 0,
            totalSlashed: 0,
            activeQuests: 0,
            totalParticipants: 0
        });
    }

    // ========== Staking Functions ==========
    
    /**
     * @notice Stakes tokens for a quest
     * @param quest Address of the quest contract
     * @param amount Amount to stake
     * @param token Token address (address(0) for ETH)
     */
    function stake(
        address quest,
        uint256 amount,
        address token
    )
        external
        payable
        nonReentrant
        whenNotPaused
        validAddress(quest)
        validAmount(amount)
        supportedToken(token)
    {
        // Validate quest exists
        if (questPools[quest].questAddress == address(0)) {
            _createQuestPool(quest);
        }
        
        // Check minimum stake amount
        if (amount < MIN_STAKE_AMOUNT) {
            revert RewardPool__InsufficientStake();
        }
        
        // Check if user already staked for this quest
        if (questPools[quest].userStakes[msg.sender] > 0) {
            revert RewardPool__AlreadyStaked();
        }
        
        // Transfer tokens to contract
        uint256 actualAmount = _transferTokens(msg.sender, token, amount);
        
        // Create stake record
        uint256 stakeId = userStakes[msg.sender].length;
        stakes[stakeId] = Stake({
            user: msg.sender,
            quest: quest,
            amount: actualAmount,
            token: token,
            stakedAt: block.timestamp,
            lastActivity: block.timestamp,
            active: true,
            rewardDebt: 0
        });
        
        // Update mappings
        userStakes[msg.sender].push(stakeId);
        questStakes[quest].push(stakeId);
        
        // Update quest pool
        QuestPool storage pool = questPools[quest];
        pool.userStakes[msg.sender] = actualAmount;
        pool.totalStaked += actualAmount;
        pool.participantCount++;
        pool.participants.push(msg.sender);
        
        // Update token balance
        tokenBalances[token] += actualAmount;
        
        // Update global stats
        globalStats.totalValueLocked += actualAmount;
        globalStats.totalParticipants++;
        
        emit Staked(stakeId, msg.sender, quest, actualAmount, token, block.timestamp);
    }
    
    /**
     * @notice Withdraws stake with rewards
     * @param stakeId ID of the stake to withdraw
     */
    function withdraw(uint256 stakeId)
        external
        nonReentrant
        whenNotPaused
        validStakeId(stakeId)
        activeStake(stakeId)
    {
        Stake storage stake = stakes[stakeId];
        
        // Calculate final reward
        uint256 rewardAmount = _calculateFinalReward(stakeId);
        
        // Update stake status
        stake.active = false;
        
        // Update quest pool
        QuestPool storage pool = questPools[stake.quest];
        pool.totalStaked -= stake.amount;
        pool.participantCount--;
        
        // Update global stats
        globalStats.totalValueLocked -= stake.amount;
        globalStats.totalRewardsDistributed += rewardAmount;
        
        // Transfer stake amount + reward
        uint256 totalAmount = stake.amount + rewardAmount;
        _transferTokens(address(this), stake.token, msg.sender, totalAmount);
        
        // Update token balance
        tokenBalances[stake.token] -= totalAmount;
        
        emit Withdrawn(stakeId, msg.sender, stake.amount, 0, block.timestamp);
        emit RewardDistributed(stakeId, msg.sender, rewardAmount, 0, 0, block.timestamp);
    }
    
    /**
     * @notice Emergency withdrawal with penalty
     * @param stakeId ID of the stake to withdraw
     */
    function emergencyWithdraw(uint256 stakeId)
        external
        nonReentrant
        validStakeId(stakeId)
        activeStake(stakeId)
    {
        Stake storage stake = stakes[stakeId];
        
        // Calculate withdrawal amount with penalty
        uint256 penaltyAmount = (stake.amount * emergencyWithdrawalFee) / REWARD_BASIS_POINTS;
        uint256 withdrawalAmount = stake.amount - penaltyAmount;
        
        // Update stake status
        stake.active = false;
        
        // Update quest pool and global stats
        QuestPool storage pool = questPools[stake.quest];
        pool.totalStaked -= stake.amount;
        pool.participantCount--;
        globalStats.totalValueLocked -= stake.amount;
        globalStats.totalSlashed += penaltyAmount;
        
        // Transfer withdrawal amount
        _transferTokens(address(this), stake.token, msg.sender, withdrawalAmount);
        
        // Transfer penalty to treasury
        _transferTokens(address(this), stake.token, treasury, penaltyAmount);
        treasuryBalance += penaltyAmount;
        
        // Update token balance
        tokenBalances[stake.token] -= stake.amount;
        
        emit EmergencyWithdrawal(msg.sender, withdrawalAmount, penaltyAmount, block.timestamp);
        emit Slashed(stakeId, msg.sender, penaltyAmount, emergencyWithdrawalFee, block.timestamp);
    }

    // ========== Quest Contract Functions ==========
    
    /**
     * @notice Distributes reward to a participant (called by quest contract)
     * @param quest Address of the quest contract
     * @param participant Address of the participant
     * @param rewardAmount Amount of reward to distribute
     */
    function distributeReward(
        address quest,
        address participant,
        uint256 rewardAmount
    )
        external
        nonReentrant
        onlyQuestContract
        validAddress(quest)
        validAddress(participant)
        validAmount(rewardAmount)
    {
        QuestPool storage pool = questPools[quest];
        if (pool.questAddress == address(0)) {
            revert RewardPool__QuestNotFound();
        }
        
        // Find user's stake for this quest
        uint256 stakeId = pool.userStakes[participant];
        if (stakeId == 0) {
            revert RewardPool__StakeNotFound();
        }
        
        Stake storage stake = stakes[stakeId];
        
        // Calculate performance and speed bonuses
        RewardCalculation memory calc = _calculateDetailedReward(stakeId, rewardAmount);
        
        // Update stake's reward debt
        stake.rewardDebt += calc.totalReward;
        
        // Update global stats
        globalStats.totalRewardsDistributed += calc.totalReward;
        
        // Transfer reward
        address rewardToken = stake.token; // Use same token as stake
        _transferTokens(address(this), rewardToken, participant, calc.totalReward);
        
        // Update token balance
        tokenBalances[rewardToken] -= calc.totalReward;
        
        emit RewardDistributed(
            stakeId,
            participant,
            calc.baseReward,
            calc.performanceBonus,
            calc.speedBonus,
            block.timestamp
        );
    }
    
    /**
     * @notice Slashes a participant's stake (called by quest contract)
     * @param participant Address of the participant to slash
     * @param slashPercentage Percentage to slash (in basis points)
     */
    function slash(
        address participant,
        uint256 slashPercentage
    )
        external
        nonReentrant
        onlyQuestContract
        validAddress(participant)
    {
        if (slashPercentage > MAX_SLASH_PERCENTAGE) {
            revert RewardPool__MaxSlashPercentage();
        }
        
        // Find all active stakes for participant
        uint256[] storage userStakeIds = userStakes[participant];
        uint256 totalSlashed = 0;
        
        for (uint256 i = 0; i < userStakeIds.length; i++) {
            uint256 stakeId = userStakeIds[i];
            Stake storage stake = stakes[stakeId];
            
            if (stake.active) {
                uint256 slashAmount = (stake.amount * slashPercentage) / REWARD_BASIS_POINTS;
                uint256 refundAmount = stake.amount - slashAmount;
                
                // Update stake
                stake.active = false;
                
                // Update quest pool
                QuestPool storage pool = questPools[stake.quest];
                pool.totalStaked -= stake.amount;
                pool.participantCount--;
                
                // Transfer refund to participant
                _transferTokens(address(this), stake.token, participant, refundAmount);
                
                // Transfer slash amount to treasury
                _transferTokens(address(this), stake.token, treasury, slashAmount);
                treasuryBalance += slashAmount;
                
                // Update balances and stats
                tokenBalances[stake.token] -= stake.amount;
                globalStats.totalValueLocked -= stake.amount;
                globalStats.totalSlashed += slashAmount;
                totalSlashed += slashAmount;
                
                emit Slashed(stakeId, participant, slashAmount, slashPercentage, block.timestamp);
            }
        }
    }

    // ========== Admin Functions ==========
    
    /**
     * @notice Adds support for a new token
     * @param token Address of the token to add
     * @param symbol Token symbol
     * @param decimals Token decimals
     */
    function addToken(
        address token,
        string calldata symbol,
        uint256 decimals
    )
        external
        onlyRewardAdmin
        validAddress(token)
    {
        if (supportedTokens[token]) {
            return; // Token already supported
        }
        
        supportedTokens[token] = true;
        tokenList.push(token);
        
        emit TokenAdded(token, symbol, decimals);
    }
    
    /**
     * @notice Removes support for a token
     * @param token Address of the token to remove
     */
    function removeToken(address token)
        external
        onlyRewardAdmin
        validAddress(token)
    {
        if (!supportedTokens[token]) {
            return; // Token not supported
        }
        
        // Check if any active stakes use this token
        require(tokenBalances[token] == 0, "Active stakes exist");
        
        supportedTokens[token] = false;
        
        // Remove from token list
        for (uint256 i = 0; i < tokenList.length; i++) {
            if (tokenList[i] == token) {
                tokenList[i] = tokenList[tokenList.length - 1];
                tokenList.pop();
                break;
            }
        }
        
        emit TokenRemoved(token);
    }
    
    /**
     * @notice Updates reward calculation parameters
     * @param _baseRewardRate New base reward rate
     * @param _speedBonusThreshold New speed bonus threshold
     * @param _speedBonusRate New speed bonus rate
     */
    function updateRewardParameters(
        uint256 _baseRewardRate,
        uint256 _speedBonusThreshold,
        uint256 _speedBonusRate
    )
        external
        onlyRewardAdmin
    {
        baseRewardRate = _baseRewardRate;
        speedBonusThreshold = _speedBonusThreshold;
        speedBonusRate = _speedBonusRate;
        
        emit RewardParametersUpdated(_baseRewardRate, _speedBonusThreshold, _speedBonusRate);
    }
    
    /**
     * @notice Updates the treasury address
     * @param newTreasury New treasury address
     */
    function updateTreasury(address newTreasury)
        external
        onlyRewardAdmin
        validAddress(newTreasury)
    {
        uint256 currentBalance = treasuryBalance;
        if (currentBalance > 0) {
            _transferTokens(address(this), address(0), newTreasury, currentBalance);
        }
        
        treasury = newTreasury;
        treasuryBalance = 0;
        
        emit TreasuryUpdated(newTreasury, currentBalance);
    }
    
    /**
     * @notice Updates emergency withdrawal fee
     * @param newFee New fee in basis points
     */
    function updateEmergencyWithdrawalFee(uint256 newFee)
        external
        onlyRewardAdmin
    {
        if (newFee > MAX_SLASH_PERCENTAGE) {
            revert RewardPool__MaxSlashPercentage();
        }
        
        emergencyWithdrawalFee = newFee;
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

    // ========== View Functions ==========
    
    /**
     * @notice Gets stake information
     * @param stakeId ID of the stake
     * @return Stake information
     */
    function getStake(uint256 stakeId)
        external
        view
        returns (
            address user,
            address quest,
            uint256 amount,
            address token,
            uint256 stakedAt,
            uint256 lastActivity,
            bool active,
            uint256 rewardDebt
        )
    {
        Stake storage s = stakes[stakeId];
        return (
            s.user,
            s.quest,
            s.amount,
            s.token,
            s.stakedAt,
            s.lastActivity,
            s.active,
            s.rewardDebt
        );
    }
    
    /**
     * @notice Gets quest pool information
     * @param quest Address of the quest
     * @return Quest pool information
     */
    function getQuestPool(address quest)
        external
        view
        returns (
            uint256 totalStaked,
            uint256 totalRewards,
            uint256 totalSlashed,
            uint256 participantCount,
            uint256 createdAt,
            bool active
        )
    {
        QuestPool storage pool = questPools[quest];
        return (
            pool.totalStaked,
            pool.totalRewards,
            pool.totalSlashed,
            pool.participantCount,
            pool.createdAt,
            pool.active
        );
    }
    
    /**
     * @notice Gets user's stake IDs
     * @param user Address of the user
     * @return Array of stake IDs
     */
    function getUserStakes(address user) external view returns (uint256[] memory) {
        return userStakes[user];
    }
    
    /**
     * @notice Gets quest's stake IDs
     * @param quest Address of the quest
     * @return Array of stake IDs
     */
    function getQuestStakes(address quest) external view returns (uint256[] memory) {
        return questStakes[quest];
    }
    
    /**
     * @notice Calculates estimated reward for a stake
     * @param stakeId ID of the stake
     * @return Estimated reward amount
     */
    function calculateEstimatedReward(uint256 stakeId) external view returns (uint256) {
        return _calculateFinalReward(stakeId);
    }
    
    /**
     * @notice Gets supported tokens
     * @return Array of supported token addresses
     */
    function getSupportedTokens() external view returns (address[] memory) {
        return tokenList;
    }
    
    /**
     * @notice Gets contract statistics
     * @return Global statistics
     */
    function getGlobalStats() external view returns (GlobalStats memory) {
        return globalStats;
    }
    
    /**
     * @notice Gets token balance
     * @param token Address of the token
     * @return Token balance
     */
    function getTokenBalance(address token) external view returns (uint256) {
        return tokenBalances[token];
    }

    // ========== Internal Functions ==========
    
    function _createQuestPool(address quest) internal {
        QuestPool storage pool = questPools[quest];
        pool.questAddress = quest;
        pool.totalStaked = 0;
        pool.totalRewards = 0;
        pool.totalSlashed = 0;
        pool.participantCount = 0;
        pool.createdAt = block.timestamp;
        pool.active = true;
        
        activeQuests.push(quest);
        globalStats.activeQuests++;
        
        emit QuestPoolCreated(quest, block.timestamp);
    }
    
    function _transferTokens(
        address from,
        address token,
        address to,
        uint256 amount
    ) internal {
        if (token == address(0)) {
            // Handle ETH
            if (from == address(this)) {
                payable(to).transfer(amount);
            } else {
                require(msg.value >= amount, "Insufficient ETH sent");
                if (msg.value > amount) {
                    payable(from).transfer(msg.value - amount);
                }
            }
        } else {
            // Handle ERC20 tokens
            if (from == address(this)) {
                IERC20(token).safeTransfer(to, amount);
            } else {
                uint256 balanceBefore = IERC20(token).balanceOf(address(this));
                IERC20(token).safeTransferFrom(from, address(this), amount);
                uint256 balanceAfter = IERC20(token).balanceOf(address(this));
                require(balanceAfter - balanceBefore == amount, "Transfer failed");
            }
        }
    }
    
    function _transferTokens(
        address from,
        address token,
        uint256 amount
    ) internal returns (uint256) {
        if (token == address(0)) {
            // Handle ETH
            require(msg.value >= amount, "Insufficient ETH sent");
            uint256 actualAmount = Math.min(msg.value, amount);
            if (msg.value > actualAmount) {
                payable(from).transfer(msg.value - actualAmount);
            }
            return actualAmount;
        } else {
            // Handle ERC20 tokens
            uint256 balanceBefore = IERC20(token).balanceOf(address(this));
            IERC20(token).safeTransferFrom(from, address(this), amount);
            uint256 balanceAfter = IERC20(token).balanceOf(address(this));
            uint256 actualAmount = balanceAfter - balanceBefore;
            require(actualAmount == amount, "Transfer failed");
            return actualAmount;
        }
    }
    
    function _calculateFinalReward(uint256 stakeId) internal view returns (uint256) {
        Stake storage stake = stakes[stakeId];
        
        // Base reward calculation
        uint256 baseReward = (stake.amount * baseRewardRate) / REWARD_BASIS_POINTS;
        
        // Performance bonus (simplified - would be based on actual quest performance)
        uint256 performanceBonus = (baseReward * 10) / 100; // 10% performance bonus
        
        // Speed bonus (simplified - would be based on completion speed)
        uint256 speedBonus = 0;
        uint256 stakingDuration = block.timestamp - stake.stakedAt;
        if (stakingDuration < 7 days) {
            speedBonus = (baseReward * speedBonusRate) / REWARD_BASIS_POINTS;
        }
        
        return baseReward + performanceBonus + speedBonus;
    }
    
    function _calculateDetailedReward(uint256 stakeId, uint256 baseRewardAmount)
        internal
        view
        returns (RewardCalculation memory)
    {
        Stake storage stake = stakes[stakeId];
        
        // Performance bonus based on quest completion rate
        uint256 performanceBonus = (baseRewardAmount * 15) / 100; // 15% performance bonus
        
        // Speed bonus based on completion speed
        uint256 speedBonus = 0;
        uint256 stakingDuration = block.timestamp - stake.stakedAt;
        if (stakingDuration < 7 days) {
            speedBonus = (baseRewardAmount * speedBonusRate) / REWARD_BASIS_POINTS;
        }
        
        uint256 totalReward = baseRewardAmount + performanceBonus + speedBonus;
        
        return RewardCalculation({
            baseReward: baseRewardAmount,
            performanceBonus: performanceBonus,
            speedBonus: speedBonus,
            totalReward: totalReward,
            timestamp: block.timestamp
        });
    }
}
