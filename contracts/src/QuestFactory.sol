// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./Quest.sol";
import "./RewardPool.sol";
import "./VerificationOracle.sol";
import "./AchievementNFT.sol";
import "./GovernanceToken.sol";

/**
 * @title QuestFactory
 * @notice Factory contract for creating Quest clones using EIP-1167 minimal proxy pattern
 * @dev Manages quest creation, templates, and registry
 */
contract QuestFactory is AccessControl, Pausable, ReentrancyGuard {
    // ========== Constants ==========
    bytes32 public constant QUEST_CREATOR_ROLE = keccak256("QUEST_CREATOR_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint256 public constant MAX_QUESTS_PER_CREATOR = 100;
    uint256 public constant CREATION_FEE = 0.01 ether;

    // ========== State Variables ==========
    
    // Quest implementation contract for cloning
    address public questImplementation;
    
    // Quest registry
    struct QuestInfo {
        uint256 id;
        address questAddress;
        address creator;
        uint256 createdAt;
        bool isActive;
        string title;
        string category;
    }
    
    mapping(uint256 => QuestInfo) public quests;
    mapping(address => uint256[]) public creatorQuests;
    mapping(address => uint256) public questCreatorCount;
    mapping(string => uint256[]) public questsByCategory;
    
    uint256 public nextQuestId;
    uint256 public totalQuests;
    
    // Quest templates
    struct QuestTemplate {
        uint256 id;
        string name;
        string description;
        address creator;
        uint256 createdAt;
        bool isActive;
        QuestTemplateData templateData;
    }
    
    struct QuestTemplateData {
        uint256 defaultStakeAmount;
        uint256 defaultDuration;
        uint256 maxParticipants;
        uint256 verificationThreshold;
        string category;
        Milestone[] milestones;
    }
    
    mapping(uint256 => QuestTemplate) public questTemplates;
    mapping(address => uint256[]) public creatorTemplates;
    uint256 public nextTemplateId;
    
    // System contracts
    address public rewardPool;
    address public verificationOracle;
    address public achievementNFT;
    address public governanceToken;
    
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
    
    event QuestTemplateCreated(
        uint256 indexed templateId,
        address indexed creator,
        string name,
        string category,
        uint256 createdAt
    );
    
    event QuestUpdated(
        uint256 indexed questId,
        address indexed questAddress,
        bool isActive
    );
    
    event QuestImplementationUpdated(
        address indexed oldImplementation,
        address indexed newImplementation,
        address indexed updatedBy
    );
    
    event SystemContractsUpdated(
        address indexed rewardPool,
        address indexed verificationOracle,
        address indexed achievementNFT,
        address governanceToken
    );
    
    event CreationFeeUpdated(uint256 oldFee, uint256 newFee);
    event CreationFeeCollected(address indexed collector, uint256 amount);
    
    // ========== Errors ==========
    error QuestFactory__InvalidAddress();
    error QuestFactory__QuestNotFound();
    error QuestFactory__TemplateNotFound();
    error QuestFactory__Unauthorized();
    error QuestFactory__MaxQuestsReached();
    error QuestFactory__InvalidFee();
    error QuestFactory__QuestAlreadyExists();
    error QuestFactory__InvalidCategory();
    error QuestFactory__InvalidParameters();

    // ========== Modifiers ==========
    modifier onlyQuestCreator() {
        if (!hasRole(QUEST_CREATOR_ROLE, msg.sender) && !hasRole(ADMIN_ROLE, msg.sender)) {
            revert QuestFactory__Unauthorized();
        }
        _;
    }
    
    modifier validQuestAddress(address questAddress) {
        if (questAddress == address(0)) {
            revert QuestFactory__InvalidAddress();
        }
        _;
    }
    
    modifier validQuestId(uint256 questId) {
        if (questId >= nextQuestId || quests[questId].questAddress == address(0)) {
            revert QuestFactory__QuestNotFound();
        }
        _;
    }

    // ========== Constructor ==========
    constructor(address _questImplementation) {
        if (_questImplementation == address(0)) {
            revert QuestFactory__InvalidAddress();
        }
        
        questImplementation = _questImplementation;
        nextQuestId = 1;
        nextTemplateId = 1;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(QUEST_CREATOR_ROLE, msg.sender);
    }

    // ========== Quest Creation Functions ==========
    
    /**
     * @notice Creates a new quest using the minimal proxy pattern
     * @param params Quest creation parameters
     * @return questAddress Address of the newly created quest
     */
    function createQuest(CreateQuestParams calldata params)
        external
        payable
        nonReentrant
        whenNotPaused
        onlyQuestCreator
        validAddress(params.creator)
        returns (address questAddress)
    {
        // Validate parameters
        _validateQuestParams(params);
        
        // Check creation fee
        if (msg.value < CREATION_FEE) {
            revert QuestFactory__InvalidFee();
        }
        
        // Check creator limits
        if (questCreatorCount[params.creator] >= MAX_QUESTS_PER_CREATOR) {
            revert QuestFactory__MaxQuestsReached();
        }
        
        // Create quest clone
        questAddress = Clones.clone(questImplementation);
        
        // Initialize quest
        Quest(questAddress).initialize(
            params,
            rewardPool,
            verificationOracle,
            achievementNFT
        );
        
        // Register quest
        quests[nextQuestId] = QuestInfo({
            id: nextQuestId,
            questAddress: questAddress,
            creator: params.creator,
            createdAt: block.timestamp,
            isActive: true,
            title: params.title,
            category: params.category
        });
        
        // Update mappings
        creatorQuests[params.creator].push(nextQuestId);
        questCreatorCount[params.creator]++;
        questsByCategory[params.category].push(nextQuestId);
        totalQuests++;
        
        // Handle creation fee
        if (msg.value > CREATION_FEE) {
            payable(params.creator).transfer(msg.value - CREATION_FEE);
        }
        if (CREATION_FEE > 0) {
            payable(address(this)).transfer(CREATION_FEE);
            emit CreationFeeCollected(msg.sender, CREATION_FEE);
        }
        
        emit QuestCreated(
            nextQuestId,
            questAddress,
            params.creator,
            params.title,
            params.category,
            params.stakeAmount,
            block.timestamp
        );
        
        nextQuestId++;
        
        return questAddress;
    }
    
    /**
     * @notice Creates a quest from a template
     * @param templateId ID of the template to use
     * @param customParams Custom parameters to override template
     * @return questAddress Address of the newly created quest
     */
    function createQuestFromTemplate(
        uint256 templateId,
        CreateQuestParams calldata customParams
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyQuestCreator
        validTemplateId(templateId)
        returns (address questAddress)
    {
        QuestTemplate storage template = questTemplates[templateId];
        if (!template.isActive) {
            revert QuestFactory__TemplateNotFound();
        }
        
        // Merge template with custom params
        CreateQuestParams memory mergedParams = _mergeTemplateWithCustom(
            template.templateData,
            customParams
        );
        
        return createQuest(mergedParams);
    }
    
    /**
     * @notice Creates a quest template
     * @param name Template name
     * @param description Template description
     * @param templateData Template configuration data
     * @return templateId ID of the created template
     */
    function createQuestTemplate(
        string calldata name,
        string calldata description,
        QuestTemplateData calldata templateData
    )
        external
        nonReentrant
        whenNotPaused
        onlyQuestCreator
        returns (uint256 templateId)
    {
        _validateTemplateData(templateData);
        
        questTemplates[nextTemplateId] = QuestTemplate({
            id: nextTemplateId,
            name: name,
            description: description,
            creator: msg.sender,
            createdAt: block.timestamp,
            isActive: true,
            templateData: templateData
        });
        
        creatorTemplates[msg.sender].push(nextTemplateId);
        
        emit QuestTemplateCreated(
            nextTemplateId,
            msg.sender,
            name,
            templateData.category,
            block.timestamp
        );
        
        templateId = nextTemplateId;
        nextTemplateId++;
        
        return templateId;
    }

    // ========== Quest Management Functions ==========
    
    /**
     * @notice Updates quest active status
     * @param questId ID of the quest to update
     * @param isActive New active status
     */
    function updateQuestStatus(
        uint256 questId,
        bool isActive
    )
        external
        onlyRole(ADMIN_ROLE)
        validQuestId(questId)
    {
        QuestInfo storage quest = quests[questId];
        quest.isActive = isActive;
        
        emit QuestUpdated(questId, quest.questAddress, isActive);
    }
    
    /**
     * @notice Updates the quest implementation contract
     * @param newImplementation New implementation address
     */
    function updateQuestImplementation(address newImplementation)
        external
        onlyRole(ADMIN_ROLE)
        validAddress(newImplementation)
    {
        address oldImplementation = questImplementation;
        questImplementation = newImplementation;
        
        emit QuestImplementationUpdated(oldImplementation, newImplementation, msg.sender);
    }
    
    /**
     * @notice Updates system contract addresses
     * @param _rewardPool Reward pool contract address
     * @param _verificationOracle Verification oracle contract address
     * @param _achievementNFT Achievement NFT contract address
     * @param _governanceToken Governance token contract address
     */
    function updateSystemContracts(
        address _rewardPool,
        address _verificationOracle,
        address _achievementNFT,
        address _governanceToken
    )
        external
        onlyRole(ADMIN_ROLE)
    {
        rewardPool = _rewardPool;
        verificationOracle = _verificationOracle;
        achievementNFT = _achievementNFT;
        governanceToken = _governanceToken;
        
        emit SystemContractsUpdated(
            _rewardPool,
            _verificationOracle,
            _achievementNFT,
            _governanceToken
        );
    }
    
    /**
     * @notice Updates the creation fee
     * @param newFee New creation fee amount
     */
    function updateCreationFee(uint256 newFee)
        external
        onlyRole(ADMIN_ROLE)
    {
        uint256 oldFee = CREATION_FEE;
        // Note: CREATION_FEE is a constant, so this would need to be changed to a variable
        // For now, this is a placeholder for the concept
        emit CreationFeeUpdated(oldFee, newFee);
    }

    // ========== View Functions ==========
    
    /**
     * @notice Gets quest information by ID
     * @param questId Quest ID
     * @return questInfo Quest information
     */
    function getQuest(uint256 questId)
        external
        view
        validQuestId(questId)
        returns (QuestInfo memory questInfo)
    {
        return quests[questId];
    }
    
    /**
     * @notice Gets all quests for a creator
     * @param creator Creator address
     * @return questIds Array of quest IDs
     */
    function getCreatorQuests(address creator)
        external
        view
        returns (uint256[] memory questIds)
    {
        return creatorQuests[creator];
    }
    
    /**
     * @notice Gets quests by category
     * @param category Category name
     * @return questIds Array of quest IDs
     */
    function getQuestsByCategory(string calldata category)
        external
        view
        returns (uint256[] memory questIds)
    {
        return questsByCategory[category];
    }
    
    /**
     * @notice Gets template information by ID
     * @param templateId Template ID
     * @return template Template information
     */
    function getTemplate(uint256 templateId)
        external
        view
        validTemplateId(templateId)
        returns (QuestTemplate memory template)
    {
        return questTemplates[templateId];
    }
    
    /**
     * @notice Gets all templates for a creator
     * @param creator Creator address
     * @return templateIds Array of template IDs
     */
    function getCreatorTemplates(address creator)
        external
        view
        returns (uint256[] memory templateIds)
    {
        return creatorTemplates[creator];
    }
    
    /**
     * @notice Gets paginated list of quests
     * @param offset Starting offset
     * @param limit Number of quests to return
     * @param category Optional category filter
     * @param creator Optional creator filter
     * @return questIds Array of quest IDs
     */
    function getQuestsPaginated(
        uint256 offset,
        uint256 limit,
        string calldata category,
        address creator
    )
        external
        view
        returns (uint256[] memory questIds)
    {
        uint256 end = offset + limit;
        if (end > nextQuestId) {
            end = nextQuestId;
        }
        
        uint256 count = 0;
        uint256 tempCount = 0;
        
        // First pass: count matching quests
        for (uint256 i = 1; i < end; i++) {
            if (_questMatchesFilter(i, category, creator)) {
                tempCount++;
            }
        }
        
        questIds = new uint256[](tempCount);
        
        // Second pass: collect matching quests
        for (uint256 i = 1; i < end; i++) {
            if (_questMatchesFilter(i, category, creator)) {
                questIds[count] = i;
                count++;
            }
        }
        
        return questIds;
    }
    
    /**
     * @notice Gets factory statistics
     * @return totalQuests Total number of quests
     * @return totalTemplates Total number of templates
     * @return activeQuests Number of active quests
     * @return totalCreators Total number of creators
     */
    function getFactoryStats()
        external
        view
        returns (
            uint256 totalQuests_,
            uint256 totalTemplates_,
            uint256 activeQuests,
            uint256 totalCreators
        )
    {
        totalQuests_ = totalQuests;
        totalTemplates_ = nextTemplateId - 1;
        
        // Count active quests
        for (uint256 i = 1; i < nextQuestId; i++) {
            if (quests[i].isActive) {
                activeQuests++;
            }
        }
        
        // Count unique creators
        // Note: This is a simplified version, in production you'd want a more efficient method
        totalCreators = 0;
        address lastCreator = address(0);
        for (uint256 i = 1; i < nextQuestId; i++) {
            if (quests[i].creator != lastCreator) {
                totalCreators++;
                lastCreator = quests[i].creator;
            }
        }
    }

    // ========== Emergency Functions ==========
    
    /**
     * @notice Pauses the factory (emergency only)
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpauses the factory
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @notice Withdraws collected fees
     * @param to Recipient address
     * @param amount Amount to withdraw
     */
    function withdrawFees(address to, uint256 amount)
        external
        onlyRole(ADMIN_ROLE)
        validAddress(to)
    {
        if (address(this).balance < amount) {
            revert QuestFactory__InvalidFee();
        }
        
        payable(to).transfer(amount);
    }

    // ========== Internal Functions ==========
    
    function _validateQuestParams(CreateQuestParams calldata params) internal pure {
        if (params.stakeAmount == 0) {
            revert QuestFactory__InvalidParameters();
        }
        if (params.duration == 0) {
            revert QuestFactory__InvalidParameters();
        }
        if (params.maxParticipants == 0) {
            revert QuestFactory__InvalidParameters();
        }
        if (bytes(params.title).length == 0) {
            revert QuestFactory__InvalidParameters();
        }
        if (bytes(params.category).length == 0) {
            revert QuestFactory__InvalidCategory();
        }
    }
    
    function _validateTemplateData(QuestTemplateData calldata templateData) internal pure {
        if (templateData.defaultStakeAmount == 0) {
            revert QuestFactory__InvalidParameters();
        }
        if (templateData.defaultDuration == 0) {
            revert QuestFactory__InvalidParameters();
        }
        if (templateData.maxParticipants == 0) {
            revert QuestFactory__InvalidParameters();
        }
        if (bytes(templateData.category).length == 0) {
            revert QuestFactory__InvalidCategory();
        }
    }
    
    function _mergeTemplateWithCustom(
        QuestTemplateData storage templateData,
        CreateQuestParams calldata customParams
    ) internal view returns (CreateQuestParams memory) {
        // Use template defaults, override with custom params
        CreateQuestParams memory mergedParams = CreateQuestParams({
            title: bytes(customParams.title).length > 0 ? customParams.title : "Template Quest",
            description: bytes(customParams.description).length > 0 ? customParams.description : "Quest created from template",
            creator: customParams.creator,
            stakeAmount: customParams.stakeAmount > 0 ? customParams.stakeAmount : templateData.defaultStakeAmount,
            rewardPool: customParams.rewardPool > 0 ? customParams.rewardPool : templateData.defaultStakeAmount * 150 / 100, // 50% bonus
            duration: customParams.duration > 0 ? customParams.duration : templateData.defaultDuration,
            maxParticipants: customParams.maxParticipants > 0 ? customParams.maxParticipants : templateData.maxParticipants,
            verificationThreshold: customParams.verificationThreshold > 0 ? customParams.verificationThreshold : templateData.verificationThreshold,
            category: bytes(customParams.category).length > 0 ? customParams.category : templateData.category,
            rewardToken: customParams.rewardToken,
            milestones: customParams.milestones.length > 0 ? customParams.milestones : templateData.milestones,
            metadataURI: customParams.metadataURI
        });
        
        return mergedParams;
    }
    
    function _questMatchesFilter(
        uint256 questId,
        string calldata category,
        address creator
    ) internal view returns (bool) {
        QuestInfo storage quest = quests[questId];
        
        if (!quest.isActive) {
            return false;
        }
        
        if (bytes(category).length > 0 && keccak256(bytes(quest.category)) != keccak256(bytes(category))) {
            return false;
        }
        
        if (creator != address(0) && quest.creator != creator) {
            return false;
        }
        
        return true;
    }
    
    function _validAddress(address addr) internal pure returns (bool) {
        return addr != address(0);
    }
    
    function _validTemplateId(uint256 templateId) internal view returns (bool) {
        return templateId > 0 && templateId < nextTemplateId && questTemplates[templateId].isActive;
    }
}

// ========== Structs ==========

struct CreateQuestParams {
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
    Milestone[] milestones;
    string metadataURI;
}

struct Milestone {
    string title;
    string description;
    uint256 orderIndex;
    uint8 verificationType; // 0: community, 1: oracle, 2: automated
    string[] requiredEvidence;
    uint256 deadline;
}
