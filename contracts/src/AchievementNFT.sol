// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title AchievementNFT
 * @notice ERC721 contract for achievement badges and quest completions
 * @dev Manages NFT minting, metadata, and transfer restrictions
 */
contract AchievementNFT is ERC721, ERC721URIStorage, AccessControl, Pausable, ReentrancyGuard {
    using Counters for Counters.Counter;

    // ========== Constants ==========
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    uint256 public constant MAX_SUPPLY = 1000000;
    uint256 public constant MAX_MINT_PER_ADDRESS = 100;
    uint256 public constant ROYALTY_BASIS_POINTS = 250; // 2.5% royalty
    
    // ========== Enums ==========
    
    enum AchievementRarity {
        Common,      // 50% supply
        Uncommon,    // 30% supply
        Rare,        // 15% supply
        Epic,        // 4% supply
        Legendary    // 1% supply
    }
    
    enum AchievementType {
        QuestCompletion,
        MilestoneReached,
        SpecialEvent,
        CommunityContribution,
        CreatorReward,
        ValidatorReward
    }
    
    enum TransferRestriction {
        None,           // No restrictions
        SoulBound,      // Cannot be transferred
        Timelocked,     // Transferable after time
        ApprovalOnly    // Requires approval
    }

    // ========== Structs ==========
    
    struct Achievement {
        uint256 id;
        string title;
        string description;
        string imageURI;
        AchievementRarity rarity;
        AchievementType achievementType;
        address creator;
        address quest;
        uint256 createdAt;
        uint256 earnedAt;
        TransferRestriction transferRestriction;
        uint256 transferUnlockTime;
        bool isActive;
        uint256 edition;
        uint256 maxEdition;
        mapping(address => bool) hasAchievement;
        mapping(address => uint256) ownerTokenId;
    }
    
    struct AchievementMetadata {
        string name;
        string description;
        string image;
        string external_url;
        string background_color;
        string[] attributes;
        uint256[] trait_values;
    }
    
    struct AchievementStats {
        uint256 totalMinted;
        uint256 totalOwners;
        uint256 totalTransfers;
        uint256 totalBurned;
        uint256 rarityDistribution[5]; // Count per rarity
        uint256 typeDistribution[6];   // Count per type
    }
    
    struct RoyaltyInfo {
        address recipient;
        uint256 royaltyBps;
    }

    // ========== State Variables ==========
    
    // Token management
    Counters.Counter private _tokenIdCounter;
    mapping(uint256 => Achievement) public achievements;
    mapping(uint256 => uint256) public tokenToAchievement; // tokenId => achievementId
    mapping(address => uint256[]) public ownerAchievements; // owner => achievementIds
    mapping(uint256 => uint256) public achievementEditions; // achievementId => edition count
    
    // Achievement templates
    mapping(uint256 => AchievementMetadata) public achievementTemplates;
    mapping(string => uint256) public templateNameToId;
    uint256 public nextTemplateId;
    
    // Transfer restrictions
    mapping(uint256 => bool) public transferApproved;
    mapping(address => mapping(address => bool)) public operatorApproval; // owner => operator => approved
    
    // Royalties
    mapping(uint256 => RoyaltyInfo) public royalties;
    address public defaultRoyaltyRecipient;
    uint256 public defaultRoyaltyBps;
    
    // Statistics
    AchievementStats public stats;
    mapping(address => uint256) public userAchievementCount;
    mapping(address => uint256) public userRarityCount[5]; // Count per rarity per user
    
    // Quest achievements
    mapping(address => uint256[]) public questAchievements; // quest => achievementIds
    mapping(address => mapping(address => uint256)) public userQuestAchievements; // user => quest => achievementId
    
    // Special achievements
    mapping(address => bool) public hasFirstAchievement;
    mapping(address => bool) public hasLegendaryAchievement;
    mapping(address => uint256) public achievementStreak; // Consecutive days with achievements
    
    // ========== Events ==========
    
    event AchievementCreated(
        uint256 indexed achievementId,
        string title,
        AchievementRarity rarity,
        AchievementType achievementType,
        address indexed creator,
        uint256 createdAt
    );
    
    event AchievementMinted(
        uint256 indexed tokenId,
        uint256 indexed achievementId,
        address indexed to,
        uint256 edition,
        uint256 mintedAt
    );
    
    event AchievementTransferred(
        uint256 indexed tokenId,
        address indexed from,
        address indexed to,
        uint256 transferredAt
    );
    
    event AchievementBurned(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 burnedAt
    );
    
    event TransferRestrictionUpdated(
        uint256 indexed achievementId,
        TransferRestriction oldRestriction,
        TransferRestriction newRestriction,
        uint256 unlockTime
    );
    
    event RoyaltyUpdated(
        uint256 indexed achievementId,
        address recipient,
        uint256 royaltyBps
    );
    
    event AchievementTemplateCreated(
        uint256 indexed templateId,
        string name,
        uint256 createdAt
    );
    
    event AchievementStreakUpdated(
        address indexed user,
        uint256 oldStreak,
        uint256 newStreak,
        uint256 updatedAt
    );

    // ========== Errors ==========
    
    error AchievementNFT__InvalidAddress();
    error AchievementNFT__InvalidTokenId();
    error AchievementNFT__InvalidAchievementId();
    error AchievementNFT__AchievementNotFound();
    error AchievementNFT__TokenNotFound();
    error AchievementNFT__Unauthorized();
    error AchievementNFT__MaxSupplyReached();
    error AchievementNFT__MaxMintPerAddress();
    error AchievementNFT__AlreadyMinted();
    error AchievementNFT__TransferRestricted();
    error AchievementNFT__TransferNotApproved();
    error AchievementNFT__TimelockActive();
    error AchievementNFT__InvalidRarity();
    error AchievementNFT__InvalidType();
    error AchievementNFT__InvalidRoyalty();
    error AchievementNFT__TransferFailed();

    // ========== Modifiers ==========
    
    modifier onlyMinter() {
        if (!hasRole(MINTER_ROLE, msg.sender) && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert AchievementNFT__Unauthorized();
        }
        _;
    }
    
    modifier onlyAdmin() {
        if (!hasRole(ADMIN_ROLE, msg.sender) && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert AchievementNFT__Unauthorized();
        }
        _;
    }
    
    modifier onlyEmergencyRole() {
        if (!hasRole(EMERGENCY_ROLE, msg.sender)) {
            revert AchievementNFT__Unauthorized();
        }
        _;
    }
    
    modifier validAddress(address addr) {
        if (addr == address(0)) {
            revert AchievementNFT__InvalidAddress();
        }
        _;
    }
    
    modifier validTokenId(uint256 tokenId) {
        if (!_exists(tokenId)) {
            revert AchievementNFT__TokenNotFound();
        }
        _;
    }
    
    modifier validAchievementId(uint256 achievementId) {
        if (achievementId >= nextTemplateId || achievementTemplates[achievementId].name.length == 0) {
            revert AchievementNFT__AchievementNotFound();
        }
        _;
    }
    
    modifier transferAllowed(uint256 tokenId) {
        if (!_isTransferAllowed(tokenId)) {
            revert AchievementNFT__TransferRestricted();
        }
        _;
    }

    // ========== Constructor ==========
    
    constructor(
        string memory name,
        string memory symbol,
        address _defaultRoyaltyRecipient
    ) ERC721(name, symbol) validAddress(_defaultRoyaltyRecipient) {
        defaultRoyaltyRecipient = _defaultRoyaltyRecipient;
        defaultRoyaltyBps = ROYALTY_BASIS_POINTS;
        nextTemplateId = 1;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);
        
        // Initialize stats
        stats = AchievementStats({
            totalMinted: 0,
            totalOwners: 0,
            totalTransfers: 0,
            totalBurned: 0,
            rarityDistribution: [uint256(0), 0, 0, 0, 0],
            typeDistribution: [uint256(0), 0, 0, 0, 0, 0]
        });
    }

    // ========== Achievement Creation Functions ==========
    
    /**
     * @notice Creates a new achievement template
     * @param name Achievement name
     * @param description Achievement description
     * @param imageURI Image URI
     * @param rarity Achievement rarity
     * @param achievementType Achievement type
     * @param transferRestriction Transfer restriction type
     * @param maxEdition Maximum edition count
     * @return achievementId ID of the created achievement
     */
    function createAchievement(
        string calldata name,
        string calldata description,
        string calldata imageURI,
        AchievementRarity rarity,
        AchievementType achievementType,
        TransferRestriction transferRestriction,
        uint256 maxEdition
    )
        external
        onlyMinter
        returns (uint256 achievementId)
    {
        // Validate inputs
        if (bytes(name).length == 0) {
            revert AchievementNFT__InvalidTokenId();
        }
        
        if (maxEdition == 0) {
            maxEdition = 1; // Default to single edition
        }
        
        // Create achievement
        achievementId = nextTemplateId++;
        Achievement storage achievement = achievements[achievementId];
        
        achievement.id = achievementId;
        achievement.title = name;
        achievement.description = description;
        achievement.imageURI = imageURI;
        achievement.rarity = rarity;
        achievement.achievementType = achievementType;
        achievement.creator = msg.sender;
        achievement.createdAt = block.timestamp;
        achievement.transferRestriction = transferRestriction;
        achievement.maxEdition = maxEdition;
        achievement.isActive = true;
        achievement.edition = 0;
        
        // Create metadata template
        achievementTemplates[achievementId] = AchievementMetadata({
            name: name,
            description: description,
            image: imageURI,
            external_url: string(abi.encodePacked("https://chainquest.app/achievement/", achievementId)),
            background_color: _getRarityColor(rarity),
            attributes: _getDefaultAttributes(rarity, achievementType),
            trait_values: _getDefaultTraitValues(rarity, achievementType)
        });
        
        templateNameToId[name] = achievementId;
        
        emit AchievementCreated(
            achievementId,
            name,
            rarity,
            achievementType,
            msg.sender,
            block.timestamp
        );
        
        return achievementId;
    }
    
    /**
     * @notice Mints an achievement NFT
     * @param to Address to mint to
     * @param achievementId ID of the achievement to mint
     * @param quest Address of the related quest (optional)
     * @param metadataURI Custom metadata URI (optional)
     * @return tokenId ID of the minted token
     */
    function mintAchievement(
        address to,
        uint256 achievementId,
        address quest,
        string calldata metadataURI
    )
        external
        nonReentrant
        whenNotPaused
        onlyMinter
        validAddress(to)
        validAchievementId(achievementId)
        returns (uint256 tokenId)
    {
        Achievement storage achievement = achievements[achievementId];
        
        if (!achievement.isActive) {
            revert AchievementNFT__AchievementNotFound();
        }
        
        if (achievement.edition >= achievement.maxEdition) {
            revert AchievementNFT__MaxSupplyReached();
        }
        
        if (achievement.hasAchievement[to]) {
            revert AchievementNFT__AlreadyMinted();
        }
        
        if (userAchievementCount[to] >= MAX_MINT_PER_ADDRESS) {
            revert AchievementNFT__MaxMintPerAddress();
        }
        
        // Check total supply
        if (_tokenIdCounter.current() >= MAX_SUPPLY) {
            revert AchievementNFT__MaxSupplyReached();
        }
        
        // Mint token
        tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        
        // Set token URI
        string memory finalURI = bytes(metadataURI).length > 0 ? 
            metadataURI : 
            _buildTokenURI(achievementId);
        _setTokenURI(tokenId, finalURI);
        
        // Update achievement
        achievement.edition++;
        achievement.earnedAt = block.timestamp;
        achievement.quest = quest;
        achievement.hasAchievement[to] = true;
        achievement.ownerTokenId[to] = tokenId;
        
        // Update mappings
        tokenToAchievement[tokenId] = achievementId;
        ownerAchievements[to].push(achievementId);
        userAchievementCount[to]++;
        userRarityCount[to][uint256(achievement.rarity)]++;
        
        if (quest != address(0)) {
            questAchievements[quest].push(achievementId);
            userQuestAchievements[to][quest] = achievementId;
        }
        
        // Update statistics
        stats.totalMinted++;
        stats.rarityDistribution[uint256(achievement.rarity)]++;
        stats.typeDistribution[uint256(achievement.achievementType)]++;
        
        // Update user achievements
        _updateUserAchievements(to, achievement);
        
        // Set royalties
        royalties[tokenId] = RoyaltyInfo({
            recipient: defaultRoyaltyRecipient,
            royaltyBps: defaultRoyaltyBps
        });
        
        emit AchievementMinted(tokenId, achievementId, to, achievement.edition, block.timestamp);
        
        return tokenId;
    }
    
    /**
     * @notice Batch mints achievements
     * @param to Address to mint to
     * @param achievementIds Array of achievement IDs
     * @param quests Array of quest addresses
     * @param metadataURIs Array of metadata URIs
     * @return tokenIds Array of minted token IDs
     */
    function batchMintAchievements(
        address to,
        uint256[] calldata achievementIds,
        address[] calldata quests,
        string[] calldata metadataURIs
    )
        external
        nonReentrant
        whenNotPaused
        onlyMinter
        validAddress(to)
        returns (uint256[] memory tokenIds)
    {
        require(
            achievementIds.length == quests.length && 
            achievementIds.length == metadataURIs.length,
            "Array length mismatch"
        );
        
        tokenIds = new uint256[](achievementIds.length);
        
        for (uint256 i = 0; i < achievementIds.length; i++) {
            tokenIds[i] = mintAchievement(to, achievementIds[i], quests[i], metadataURIs[i]);
        }
        
        return tokenIds;
    }

    // ========== Transfer Functions ==========
    
    /**
     * @notice Approves transfer of a restricted achievement
     * @param tokenId ID of the token to approve
     * @param to Address to approve transfer to
     */
    function approveTransfer(uint256 tokenId, address to)
        external
        validTokenId(tokenId)
        validAddress(to)
    {
        address owner = ownerOf(tokenId);
        if (msg.sender != owner && !isApprovedForAll(owner, msg.sender)) {
            revert AchievementNFT__Unauthorized();
        }
        
        transferApproved[tokenId] = true;
        operatorApproval[owner][to] = true;
    }
    
    /**
     * @notice Sets operator approval for transfers
     * @param operator Address to approve
     * @param approved Whether to approve
     */
    function setOperatorApproval(address operator, bool approved)
        external
        validAddress(operator)
    {
        operatorApproval[msg.sender][operator] = approved;
    }
    
    /**
     * @notice Updates transfer restriction for an achievement
     * @param achievementId ID of the achievement
     * @param restriction New transfer restriction
     * @param unlockTime Unlock time for timelocked transfers
     */
    function updateTransferRestriction(
        uint256 achievementId,
        TransferRestriction restriction,
        uint256 unlockTime
    )
        external
        onlyAdmin
        validAchievementId(achievementId)
    {
        Achievement storage achievement = achievements[achievementId];
        TransferRestriction oldRestriction = achievement.transferRestriction;
        
        achievement.transferRestriction = restriction;
        achievement.transferUnlockTime = unlockTime;
        
        emit TransferRestrictionUpdated(achievementId, oldRestriction, restriction, unlockTime);
    }
    
    /**
     * @notice Burns an achievement NFT
     * @param tokenId ID of the token to burn
     */
    function burn(uint256 tokenId)
        external
        nonReentrant
        validTokenId(tokenId)
    {
        address owner = ownerOf(tokenId);
        if (msg.sender != owner && !isApprovedForAll(owner, msg.sender)) {
            revert AchievementNFT__Unauthorized();
        }
        
        // Update achievement
        uint256 achievementId = tokenToAchievement[tokenId];
        Achievement storage achievement = achievements[achievementId];
        
        achievement.hasAchievement[owner] = false;
        delete achievement.ownerTokenId[owner];
        
        // Update mappings
        delete tokenToAchievement[tokenId];
        _removeFromOwnerAchievements(owner, achievementId);
        userAchievementCount[owner]--;
        userRarityCount[owner][uint256(achievement.rarity)]--;
        
        // Update statistics
        stats.totalBurned++;
        
        // Burn token
        _burn(tokenId);
        
        emit AchievementBurned(tokenId, owner, block.timestamp);
    }

    // ========== View Functions ==========
    
    /**
     * @notice Gets achievement information
     * @param achievementId ID of the achievement
     * @return Achievement information
     */
    function getAchievement(uint256 achievementId)
        external
        view
        validAchievementId(achievementId)
        returns (
            string memory title,
            string memory description,
            string memory imageURI,
            AchievementRarity rarity,
            AchievementType achievementType,
            address creator,
            address quest,
            uint256 createdAt,
            uint256 earnedAt,
            TransferRestriction transferRestriction,
            uint256 transferUnlockTime,
            bool isActive,
            uint256 edition,
            uint256 maxEdition
        )
    {
        Achievement storage a = achievements[achievementId];
        return (
            a.title,
            a.description,
            a.imageURI,
            a.rarity,
            a.achievementType,
            a.creator,
            a.quest,
            a.createdAt,
            a.earnedAt,
            a.transferRestriction,
            a.transferUnlockTime,
            a.isActive,
            a.edition,
            a.maxEdition
        );
    }
    
    /**
     * @notice Gets achievement metadata
     * @param achievementId ID of the achievement
     * @return Achievement metadata
     */
    function getAchievementMetadata(uint256 achievementId)
        external
        view
        validAchievementId(achievementId)
        returns (
            string memory name,
            string memory description,
            string memory image,
            string memory external_url,
            string memory background_color,
            string[] memory attributes,
            uint256[] memory trait_values
        )
    {
        AchievementMetadata storage m = achievementTemplates[achievementId];
        return (
            m.name,
            m.description,
            m.image,
            m.external_url,
            m.background_color,
            m.attributes,
            m.trait_values
        );
    }
    
    /**
     * @notice Gets user's achievements
     * @param user Address of the user
     * @return Array of achievement IDs
     */
    function getUserAchievements(address user) external view returns (uint256[] memory) {
        return ownerAchievements[user];
    }
    
    /**
     * @notice Gets quest achievements
     * @param quest Address of the quest
     * @return Array of achievement IDs
     */
    function getQuestAchievements(address quest) external view returns (uint256[] memory) {
        return questAchievements[quest];
    }
    
    /**
     * @notice Gets user's achievement count per rarity
     * @param user Address of the user
     * @param rarity Achievement rarity
     * @return Count of achievements
     */
    function getUserRarityCount(address user, AchievementRarity rarity) external view returns (uint256) {
        return userRarityCount[user][uint256(rarity)];
    }
    
    /**
     * @notice Gets achievement statistics
     * @return Achievement statistics
     */
    function getAchievementStats() external view returns (AchievementStats memory) {
        return stats;
    }
    
    /**
     * @notice Gets royalty information
     * @param tokenId ID of the token
     * @return Royalty information
     */
    function getRoyaltyInfo(uint256 tokenId)
        external
        view
        validTokenId(tokenId)
        returns (address recipient, uint256 royaltyBps)
    {
        RoyaltyInfo storage royalty = royalties[tokenId];
        return (royalty.recipient, royalty.royaltyBps);
    }
    
    /**
     * @notice Checks if transfer is allowed
     * @param tokenId ID of the token
     * @return Whether transfer is allowed
     */
    function isTransferAllowed(uint256 tokenId) external view returns (bool) {
        return _isTransferAllowed(tokenId);
    }
    
    /**
     * @notice Gets achievement ID by name
     * @param name Name of the achievement
     * @return Achievement ID
     */
    function getAchievementByName(string calldata name) external view returns (uint256) {
        return templateNameToId[name];
    }
    
    /**
     * @notice Gets user's achievement streak
     * @param user Address of the user
     * @return Achievement streak
     */
    function getAchievementStreak(address user) external view returns (uint256) {
        return achievementStreak[user];
    }

    // ========== Internal Functions ==========
    
    function _isTransferAllowed(uint256 tokenId) internal view returns (bool) {
        uint256 achievementId = tokenToAchievement[tokenId];
        Achievement storage achievement = achievements[achievementId];
        
        if (achievement.transferRestriction == TransferRestriction.None) {
            return true;
        }
        
        if (achievement.transferRestriction == TransferRestriction.SoulBound) {
            return false;
        }
        
        if (achievement.transferRestriction == TransferRestriction.Timelocked) {
            return block.timestamp >= achievement.transferUnlockTime;
        }
        
        if (achievement.transferRestriction == TransferRestriction.ApprovalOnly) {
            return transferApproved[tokenId] || operatorApproval[ownerOf(tokenId)][msg.sender];
        }
        
        return false;
    }
    
    function _buildTokenURI(uint256 achievementId) internal view returns (string memory) {
        AchievementMetadata storage metadata = achievementTemplates[achievementId];
        
        // Build JSON metadata
        string memory json = string(abi.encodePacked(
            "{",
            '"name":"', metadata.name, '",',
            '"description":"', metadata.description, '",',
            '"image":"', metadata.image, '",',
            '"external_url":"', metadata.external_url, '",',
            '"background_color":"', metadata.background_color, '",',
            '"attributes":['
        ));
        
        // Add attributes
        for (uint256 i = 0; i < metadata.attributes.length; i++) {
            if (i > 0) {
                json = string(abi.encodePacked(json, ","));
            }
            json = string(abi.encodePacked(json, '"', metadata.attributes[i], '"'));
        }
        
        json = string(abi.encodePacked(json, "]}"));
        
        return json;
    }
    
    function _getRarityColor(AchievementRarity rarity) internal pure returns (string memory) {
        if (rarity == AchievementRarity.Common) return "E8E8E8";
        if (rarity == AchievementRarity.Uncommon) return "4CAF50";
        if (rarity == AchievementRarity.Rare) return "2196F3";
        if (rarity == AchievementRarity.Epic) return "9C27B0";
        if (rarity == AchievementRarity.Legendary) return "FF9800";
        return "FFFFFF";
    }
    
    function _getDefaultAttributes(AchievementRarity rarity, AchievementType achievementType) 
        internal 
        pure 
        returns (string[] memory) 
    {
        string[] memory attributes = new string[](2);
        
        attributes[0] = string(abi.encodePacked("Rarity:", _rarityToString(rarity)));
        attributes[1] = string(abi.encodePacked("Type:", _typeToString(achievementType)));
        
        return attributes;
    }
    
    function _getDefaultTraitValues(AchievementRarity rarity, AchievementType achievementType) 
        internal 
        pure 
        returns (uint256[] memory) 
    {
        uint256[] memory values = new uint256[](2);
        values[0] = uint256(rarity);
        values[1] = uint256(achievementType);
        return values;
    }
    
    function _rarityToString(AchievementRarity rarity) internal pure returns (string memory) {
        if (rarity == AchievementRarity.Common) return "Common";
        if (rarity == AchievementRarity.Uncommon) return "Uncommon";
        if (rarity == AchievementRarity.Rare) return "Rare";
        if (rarity == AchievementRarity.Epic) return "Epic";
        if (rarity == AchievementRarity.Legendary) return "Legendary";
        return "Unknown";
    }
    
    function _typeToString(AchievementType achievementType) internal pure returns (string memory) {
        if (achievementType == AchievementType.QuestCompletion) return "Quest Completion";
        if (achievementType == AchievementType.MilestoneReached) return "Milestone Reached";
        if (achievementType == AchievementType.SpecialEvent) return "Special Event";
        if (achievementType == AchievementType.CommunityContribution) return "Community Contribution";
        if (achievementType == AchievementType.CreatorReward) return "Creator Reward";
        if (achievementType == AchievementType.ValidatorReward) return "Validator Reward";
        return "Unknown";
    }
    
    function _removeFromOwnerAchievements(address owner, uint256 achievementId) internal {
        uint256[] storage achievements = ownerAchievements[owner];
        for (uint256 i = 0; i < achievements.length; i++) {
            if (achievements[i] == achievementId) {
                achievements[i] = achievements[achievements.length - 1];
                achievements.pop();
                break;
            }
        }
    }
    
    function _updateUserAchievements(address user, Achievement storage achievement) internal {
        // Update first achievement
        if (!hasFirstAchievement[user]) {
            hasFirstAchievement[user] = true;
        }
        
        // Update legendary achievement
        if (achievement.rarity == AchievementRarity.Legendary) {
            hasLegendaryAchievement[user] = true;
        }
        
        // Update achievement streak (simplified - would need proper date tracking)
        achievementStreak[user]++;
        
        emit AchievementStreakUpdated(user, achievementStreak[user] - 1, achievementStreak[user], block.timestamp);
    }
    
    // ========== Override Functions ==========
    
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721) {
        if (from != address(0) && to != address(0)) {
            // Check transfer restrictions
            if (!_isTransferAllowed(tokenId)) {
                revert AchievementNFT__TransferRestricted();
            }
        }
        super._beforeTokenTransfer(from, to, tokenId);
    }
    
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721) {
        if (from != address(0) && to != address(0)) {
            // Update statistics
            stats.totalTransfers++;
            
            // Update owner achievements
            uint256 achievementId = tokenToAchievement[tokenId];
            Achievement storage achievement = achievements[achievementId];
            
            achievement.hasAchievement[from] = false;
            delete achievement.ownerTokenId[from];
            
            achievement.hasAchievement[to] = true;
            achievement.ownerTokenId[to] = tokenId;
            
            _removeFromOwnerAchievements(from, achievementId);
            ownerAchievements[to].push(achievementId);
            
            emit AchievementTransferred(tokenId, from, to, block.timestamp);
        }
        super._afterTokenTransfer(from, to, tokenId);
    }
    
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // ========== Admin Functions ==========
    
    /**
     * @notice Updates royalty information
     * @param tokenId ID of the token
     * @param recipient Royalty recipient
     * @param royaltyBps Royalty basis points
     */
    function updateRoyaltyInfo(
        uint256 tokenId,
        address recipient,
        uint256 royaltyBps
    )
        external
        onlyAdmin
        validTokenId(tokenId)
        validAddress(recipient)
    {
        if (royaltyBps > 1000) { // Max 10%
            revert AchievementNFT__InvalidRoyalty();
        }
        
        royalties[tokenId] = RoyaltyInfo({
            recipient: recipient,
            royaltyBps: royaltyBps
        });
        
        emit RoyaltyUpdated(tokenId, recipient, royaltyBps);
    }
    
    /**
     * @notice Updates default royalty settings
     * @param recipient Default royalty recipient
     * @param royaltyBps Default royalty basis points
     */
    function updateDefaultRoyalty(
        address recipient,
        uint256 royaltyBps
    )
        external
        onlyAdmin
        validAddress(recipient)
    {
        if (royaltyBps > 1000) { // Max 10%
            revert AchievementNFT__InvalidRoyalty();
        }
        
        defaultRoyaltyRecipient = recipient;
        defaultRoyaltyBps = royaltyBps;
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
