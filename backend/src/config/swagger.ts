import swaggerJsdoc from 'swagger-jsdoc';
import swaggerUi from 'swagger-ui-express';
import { Express } from 'express';
import { config } from './config';

const options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'ChainQuest API',
      version: '1.0.0',
      description: 'Decentralized achievement and quest platform API',
      contact: {
        name: 'ChainQuest Team',
        email: 'support@chainquest.app',
      },
      license: {
        name: 'MIT',
        url: 'https://opensource.org/licenses/MIT',
      },
    },
    servers: [
      {
        url: `http://${config.host}:${config.port}/api/v1`,
        description: 'Development server',
      },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
        },
      },
      schemas: {
        User: {
          type: 'object',
          properties: {
            id: { type: 'string', format: 'cuid' },
            address: { type: 'string' },
            username: { type: 'string' },
            bio: { type: 'string' },
            avatar: { type: 'string' },
            reputationScore: { type: 'integer' },
            totalQuests: { type: 'integer' },
            completedQuests: { type: 'integer' },
            successRate: { type: 'number' },
            totalEarnings: { type: 'string', format: 'decimal' },
            isActive: { type: 'boolean' },
            createdAt: { type: 'string', format: 'date-time' },
            updatedAt: { type: 'string', format: 'date-time' },
          },
        },
        Quest: {
          type: 'object',
          properties: {
            id: { type: 'string', format: 'cuid' },
            contractAddress: { type: 'string' },
            title: { type: 'string' },
            description: { type: 'string' },
            creatorId: { type: 'string', format: 'cuid' },
            categoryId: { type: 'string', format: 'cuid' },
            stakeAmount: { type: 'string', format: 'decimal' },
            rewardPool: { type: 'string', format: 'decimal' },
            maxParticipants: { type: 'integer' },
            currentParticipants: { type: 'integer' },
            verificationThreshold: { type: 'integer' },
            status: { 
              type: 'string', 
              enum: ['CREATED', 'ACTIVE', 'COMPLETED', 'EXPIRED', 'FAILED', 'EMERGENCY_PAUSED'] 
            },
            createdAt: { type: 'string', format: 'date-time' },
            updatedAt: { type: 'string', format: 'date-time' },
            expiresAt: { type: 'string', format: 'date-time' },
          },
        },
        Achievement: {
          type: 'object',
          properties: {
            id: { type: 'string', format: 'cuid' },
            userId: { type: 'string', format: 'cuid' },
            questId: { type: 'string', format: 'cuid' },
            tokenId: { type: 'integer' },
            title: { type: 'string' },
            description: { type: 'string' },
            imageUrl: { type: 'string' },
            rarity: { 
              type: 'string', 
              enum: ['COMMON', 'UNCOMMON', 'RARE', 'EPIC', 'LEGENDARY'] 
            },
            achievementType: { 
              type: 'string', 
              enum: ['QUEST_COMPLETION', 'MILESTONE_REACHED', 'SPECIAL_EVENT', 'COMMUNITY_CONTRIBUTION', 'CREATOR_REWARD', 'VALIDATOR_REWARD'] 
            },
            mintedAt: { type: 'string', format: 'date-time' },
          },
        },
        Error: {
          type: 'object',
          properties: {
            status: { type: 'string' },
            message: { type: 'string' },
            error: { type: 'string' },
          },
        },
      },
    },
    security: [
      {
        bearerAuth: [],
      },
    ],
  },
  apis: ['./src/routes/*.ts'], // Path to the API docs
};

const specs = swaggerJsdoc(options);

export const setupSwagger = (app: Express): void => {
  app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(specs, {
    explorer: true,
    customCss: '.swagger-ui .topbar { display: none }',
    customSiteTitle: 'ChainQuest API Documentation',
  }));

  // Serve JSON spec
  app.get('/api-docs.json', (req, res) => {
    res.setHeader('Content-Type', 'application/json');
    res.send(specs);
  });
};
