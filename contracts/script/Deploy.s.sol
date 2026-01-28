// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/QuestFactory.sol";
import "../src/Quest.sol";
import "../src/RewardPool.sol";
import "../src/VerificationOracle.sol";
import "../src/AchievementNFT.sol";
import "../src/GovernanceToken.sol";

/**
 * @title Deploy
 * @notice Deployment script for all ChainQuest contracts
 * @dev Deploys contracts in correct order with proper configuration
 */
contract Deploy is Script {
    // ========== Deployment Configuration ==========
    
    struct DeploymentConfig {
        address questFactory;
        address questImplementation;
        address rewardPool;
        address verificationOracle;
        address achievementNFT;
        address governanceToken;
        address treasury;
        uint256 deployerPrivateKey;
        uint256 chainId;
    }
    
    // ========== State Variables ==========
    
    QuestFactory public questFactory;
    Quest public questImplementation;
    RewardPool public rewardPool;
    VerificationOracle public verificationOracle;
    AchievementNFT public achievementNFT;
    GovernanceToken public governanceToken;
    
    DeploymentConfig public config;
    
    // ========== Deployment Functions ==========
    
    function run() external {
        // Load configuration
        config = _loadConfig();
        
        // Start deployment
        vm.startBroadcast(config.deployerPrivateKey);
        
        // Deploy contracts in order
        _deployGovernanceToken();
        _deployRewardPool();
        _deployVerificationOracle();
        _deployAchievementNFT();
        _deployQuestImplementation();
        _deployQuestFactory();
        
        // Configure contracts
        _configureContracts();
        
        // Save deployment
        _saveDeployment();
        
        vm.stopBroadcast();
        
        // Log deployment
        _logDeployment();
    }
    
    function _loadConfig() internal view returns (DeploymentConfig memory) {
        // Default configuration for local deployment
        return DeploymentConfig({
            questFactory: address(0),
            questImplementation: address(0),
            rewardPool: address(0),
            verificationOracle: address(0),
            achievementNFT: address(0),
            governanceToken: address(0),
            treasury: msg.sender,
            deployerPrivateKey: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80,
            chainId: block.chainid
        });
    }
    
    function _deployGovernanceToken() internal {
        governanceToken = new GovernanceToken(
            "ChainQuest Governance",
            "CQT",
            config.treasury
        );
        
        console.log("GovernanceToken deployed at:", address(governanceToken));
    }
    
    function _deployRewardPool() internal {
        rewardPool = new RewardPool(config.treasury);
        
        console.log("RewardPool deployed at:", address(rewardPool));
    }
    
    function _deployVerificationOracle() internal {
        verificationOracle = new VerificationOracle(address(governanceToken));
        
        console.log("VerificationOracle deployed at:", address(verificationOracle));
    }
    
    function _deployAchievementNFT() internal {
        achievementNFT = new AchievementNFT(
            "ChainQuest Achievements",
            "CQA",
            config.treasury
        );
        
        console.log("AchievementNFT deployed at:", address(achievementNFT));
    }
    
    function _deployQuestImplementation() internal {
        questImplementation = new Quest();
        
        console.log("Quest implementation deployed at:", address(questImplementation));
    }
    
    function _deployQuestFactory() internal {
        questFactory = new QuestFactory(address(questImplementation));
        
        console.log("QuestFactory deployed at:", address(questFactory));
    }
    
    function _configureContracts() internal {
        // Configure QuestFactory with system contracts
        questFactory.updateSystemContracts(
            address(rewardPool),
            address(verificationOracle),
            address(achievementNFT),
            address(governanceToken)
        );
        
        // Add governance token to reward pool
        rewardPool.addToken(
            address(governanceToken),
            "CQT",
            18
        );
        
        // Set up initial roles
        _setupRoles();
        
        // Create initial achievements
        _createInitialAchievements();
        
        console.log("Contracts configured successfully");
    }
    
    function _setupRoles() internal {
        // Grant roles to treasury/admin
        address admin = config.treasury;
        
        // QuestFactory roles
        questFactory.grantRole(questFactory.ADMIN_ROLE(), admin);
        questFactory.grantRole(questFactory.QUEST_CREATOR_ROLE(), admin);
        
        // RewardPool roles
        rewardPool.grantRole(rewardPool.REWARD_ADMIN_ROLE(), admin);
        rewardPool.grantRole(rewardPool.QUEST_CONTRACT_ROLE(), address(questFactory));
        
        // VerificationOracle roles
        verificationOracle.grantRole(verificationOracle.ORACLE_ADMIN_ROLE(), admin);
        verificationOracle.grantRole(verificationOracle.VALIDATOR_ROLE(), admin);
        
        // AchievementNFT roles
        achievementNFT.grantRole(achievementNFT.MINTER_ROLE(), admin);
        achievementNFT.grantRole(achievementNFT.ADMIN_ROLE(), admin);
        
        // GovernanceToken roles
        governanceToken.grantRole(governanceToken.MINTER_ROLE(), admin);
        governanceToken.grantRole(governanceToken.GOVERNANCE_ROLE(), admin);
        
        console.log("Roles configured for admin:", admin);
    }
    
    function _createInitialAchievements() internal {
        // Create basic achievement templates
        
        // First Quest Completion
        achievementNFT.createAchievement(
            "First Quest",
            "Completed your first quest on ChainQuest",
            "https://ipfs.io/ipfs/QmFirstQuest",
            AchievementNFT.AchievementRarity.Common,
            AchievementNFT.AchievementType.QuestCompletion,
            AchievementNFT.TransferRestriction.None,
            1000
        );
        
        // Quest Master
        achievementNFT.createAchievement(
            "Quest Master",
            "Completed 10 quests successfully",
            "https://ipfs.io/ipfs/QmQuestMaster",
            AchievementNFT.AchievementRarity.Rare,
            AchievementNFT.AchievementType.QuestCompletion,
            AchievementNFT.TransferRestriction.None,
            500
        );
        
        // Legendary Achiever
        achievementNFT.createAchievement(
            "Legendary Achiever",
            "Completed 100 quests with 90%+ success rate",
            "https://ipfs.io/ipfs/QmLegendary",
            AchievementNFT.AchievementRarity.Legendary,
            AchievementNFT.AchievementType.QuestCompletion,
            AchievementNFT.TransferRestriction.SoulBound,
            100
        );
        
        // Community Contributor
        achievementNFT.createAchievement(
            "Community Contributor",
            "Verified 100 pieces of evidence",
            "https://ipfs.io/ipfs/QmContributor",
            AchievementNFT.AchievementRarity.Uncommon,
            AchievementNFT.AchievementType.CommunityContribution,
            AchievementNFT.TransferRestriction.None,
            2000
        );
        
        // Quest Creator
        achievementNFT.createAchievement(
            "Quest Creator",
            "Created 5 successful quests",
            "https://ipfs.io/ipfs/QmCreator",
            AchievementNFT.AchievementRarity.Epic,
            AchievementNFT.AchievementType.CreatorReward,
            AchievementNFT.TransferRestriction.Timelocked,
            500
        );
        
        console.log("Initial achievements created");
    }
    
    function _saveDeployment() internal {
        // Create deployment record
        string memory deploymentJson = string(abi.encodePacked(
            "{",
            '"network":', vm.toString(config.chainId), ',',
            '"timestamp":', vm.toString(block.timestamp), ',',
            '"deployer":"', vm.toString(msg.sender), '",',
            '"contracts":{',
                '"QuestFactory":"', vm.toString(address(questFactory)), '",',
                '"QuestImplementation":"', vm.toString(address(questImplementation)), '",',
                '"RewardPool":"', vm.toString(address(rewardPool)), '",',
                '"VerificationOracle":"', vm.toString(address(verificationOracle)), '",',
                '"AchievementNFT":"', vm.toString(address(achievementNFT)), '",',
                '"GovernanceToken":"', vm.toString(address(governanceToken)), '"',
            '}',
            "}"
        ));
        
        // Write to file (this would be done in a real deployment script)
        vm.writeFile("./deployments.json", deploymentJson);
        
        console.log("Deployment saved to deployments.json");
    }
    
    function _logDeployment() internal view {
        console.log("\n=== ChainQuest Deployment Summary ===");
        console.log("Network:", config.chainId);
        console.log("Deployer:", msg.sender);
        console.log("Timestamp:", block.timestamp);
        console.log("\nContracts:");
        console.log("QuestFactory:", address(questFactory));
        console.log("QuestImplementation:", address(questImplementation));
        console.log("RewardPool:", address(rewardPool));
        console.log("VerificationOracle:", address(verificationOracle));
        console.log("AchievementNFT:", address(achievementNFT));
        console.log("GovernanceToken:", address(governanceToken));
        console.log("Treasury:", config.treasury);
        console.log("\n=== End Deployment Summary ===");
    }
    
    // ========== Verification Functions ==========
    
    function verifyDeployment() external view {
        require(address(questFactory) != address(0), "QuestFactory not deployed");
        require(address(questImplementation) != address(0), "QuestImplementation not deployed");
        require(address(rewardPool) != address(0), "RewardPool not deployed");
        require(address(verificationOracle) != address(0), "VerificationOracle not deployed");
        require(address(achievementNFT) != address(0), "AchievementNFT not deployed");
        require(address(governanceToken) != address(0), "GovernanceToken not deployed");
        
        console.log("All contracts deployed successfully");
    }
    
    function verifyConfiguration() external view {
        // Verify QuestFactory configuration
        address[] memory systemContracts = questFactory.getSystemContracts();
        require(systemContracts[0] == address(rewardPool), "RewardPool not configured");
        require(systemContracts[1] == address(verificationOracle), "VerificationOracle not configured");
        require(systemContracts[2] == address(achievementNFT), "AchievementNFT not configured");
        require(systemContracts[3] == address(governanceToken), "GovernanceToken not configured");
        
        // Verify RewardPool configuration
        require(rewardPool.supportedTokens(address(0)), "ETH not supported");
        require(rewardPool.supportedTokens(address(governanceToken)), "CQT not supported");
        
        // Verify AchievementNFT configuration
        require(achievementNFT.totalSupply() == 0, "AchievementNFT should have 0 supply initially");
        
        // Verify GovernanceToken configuration
        require(governanceToken.totalSupply() == 100000000 * 10**18, "Incorrect initial supply");
        
        console.log("All contracts configured correctly");
    }
}

/**
 * @title DeployTestnet
 * @notice Deployment script for testnet environments
 */
contract DeployTestnet is Deploy {
    function run() external override {
        // Override with testnet configuration
        config.chainId = 84532; // Base Sepolia
        config.deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Call parent deployment
        Deploy.run();
    }
}

/**
 * @title DeployMainnet
 * @notice Deployment script for mainnet
 */
contract DeployMainnet is Deploy {
    function run() external override {
        // Override with mainnet configuration
        config.chainId = 8453; // Base Mainnet
        config.deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        config.treasury = vm.envAddress("TREASURY_ADDRESS");
        
        // Additional mainnet checks
        require(config.deployerPrivateKey != 0, "Private key required");
        require(config.treasury != address(0), "Treasury address required");
        
        // Call parent deployment
        Deploy.run();
    }
}
