import dotenv from 'dotenv';

dotenv.config();

interface Config {
  env: string;
  port: number;
  host: string;
  database: {
    url: string;
  };
  redis: {
    url: string;
  };
  jwt: {
    secret: string;
    expiresIn: string;
  };
  blockchain: {
    baseRpcUrl: string;
    baseChainId: number;
    privateKey: string;
    contracts: {
      questFactory: string;
      rewardPool: string;
      verificationOracle: string;
      achievementNft: string;
      governanceToken: string;
    };
  };
  ipfs: {
    projectId: string;
    projectSecret: string;
  };
  cors: {
    origin: string | string[];
  };
  rateLimit: {
    windowMs: number;
    maxRequests: number;
  };
  upload: {
    maxFileSize: number;
    uploadPath: string;
  };
  logging: {
    level: string;
    filePath: string;
  };
  monitoring: {
    sentryDsn?: string;
  };
  webhooks: {
    secret: string;
  };
  email: {
    serviceApiKey?: string;
  };
  cron: {
    questExpirationCheck: string;
    verificationTimeoutCheck: string;
    disputeDeadlineCheck: string;
  };
}

const config: Config = {
  env: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.API_PORT || '8000', 10),
  host: process.env.API_HOST || 'localhost',
  database: {
    url: process.env.DATABASE_URL || 'postgresql://chainquest:password@localhost:5432/chainquest',
  },
  redis: {
    url: process.env.REDIS_URL || 'redis://localhost:6379',
  },
  jwt: {
    secret: process.env.JWT_SECRET || 'your-super-secret-jwt-key',
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  },
  blockchain: {
    baseRpcUrl: process.env.BASE_RPC_URL || 'https://sepolia.base.org',
    baseChainId: parseInt(process.env.BASE_CHAIN_ID || '84532', 10),
    privateKey: process.env.PRIVATE_KEY || '',
    contracts: {
      questFactory: process.env.QUEST_FACTORY_ADDRESS || '',
      rewardPool: process.env.REWARD_POOL_ADDRESS || '',
      verificationOracle: process.env.VERIFICATION_ORACLE_ADDRESS || '',
      achievementNft: process.env.ACHIEVEMENT_NFT_ADDRESS || '',
      governanceToken: process.env.GOVERNANCE_TOKEN_ADDRESS || '',
    },
  },
  ipfs: {
    projectId: process.env.IPFS_PROJECT_ID || '',
    projectSecret: process.env.IPFS_PROJECT_SECRET || '',
  },
  cors: {
    origin: process.env.CORS_ORIGIN?.split(',') || ['http://localhost:3000'],
  },
  rateLimit: {
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000', 10), // 15 minutes
    maxRequests: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '100', 10),
  },
  upload: {
    maxFileSize: parseInt(process.env.MAX_FILE_SIZE || '10485760', 10), // 10MB
    uploadPath: process.env.UPLOAD_PATH || './uploads',
  },
  logging: {
    level: process.env.LOG_LEVEL || 'info',
    filePath: process.env.LOG_FILE_PATH || './logs',
  },
  monitoring: {
    sentryDsn: process.env.SENTRY_DSN,
  },
  webhooks: {
    secret: process.env.WEBHOOK_SECRET || 'your-webhook-secret',
  },
  email: {
    serviceApiKey: process.env.EMAIL_SERVICE_API_KEY,
  },
  cron: {
    questExpirationCheck: process.env.QUEST_EXPIRATION_CHECK || '0 */6 * * *',
    verificationTimeoutCheck: process.env.VERIFICATION_TIMEOUT_CHECK || '0 */2 * * *',
    disputeDeadlineCheck: process.env.DISPUTE_DEADLINE_CHECK || '0 * * * *',
  },
};

// Validate required environment variables
const requiredEnvVars = [
  'DATABASE_URL',
  'JWT_SECRET',
  'BASE_RPC_URL',
  'BASE_CHAIN_ID',
];

const missingEnvVars = requiredEnvVars.filter(envVar => !process.env[envVar]);

if (missingEnvVars.length > 0 && config.env === 'production') {
  throw new Error(`Missing required environment variables: ${missingEnvVars.join(', ')}`);
}

// Validate configuration values
if (config.port < 1 || config.port > 65535) {
  throw new Error('Invalid port number');
}

if (config.jwt.secret.length < 32) {
  throw new Error('JWT secret must be at least 32 characters long');
}

if (!config.blockchain.baseRpcUrl.startsWith('http')) {
  throw new Error('Invalid blockchain RPC URL');
}

if (config.blockchain.baseChainId <= 0) {
  throw new Error('Invalid blockchain chain ID');
}

export { config };
