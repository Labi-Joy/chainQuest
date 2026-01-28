import { PrismaClient } from '@prisma/client';
import { logger } from '@/utils/logger';
import { config } from './config';

declare global {
  var __prisma: PrismaClient | undefined;
}

// Extend Prisma Client with custom methods
class ExtendedPrismaClient extends PrismaClient {
  async healthCheck(): Promise<boolean> {
    try {
      await this.$queryRaw`SELECT 1`;
      return true;
    } catch (error) {
      logger.error('Database health check failed:', error);
      return false;
    }
  }

  async getDatabaseStats() {
    try {
      const [
        userCount,
        questCount,
        achievementCount,
        verificationCount,
      ] = await Promise.all([
        this.user.count(),
        this.quest.count(),
        this.achievement.count(),
        this.verificationVote.count(),
      ]);

      return {
        users: userCount,
        quests: questCount,
        achievements: achievementCount,
        verifications: verificationCount,
      };
    } catch (error) {
      logger.error('Failed to get database stats:', error);
      throw error;
    }
  }

  async softDeleteUser(userId: string) {
    return this.user.update({
      where: { id: userId },
      data: {
        isActive: false,
        email: null, // Remove PII
        updatedAt: new Date(),
      },
    });
  }

  async getUserWithStats(userId: string) {
    return this.user.findUnique({
      where: { id: userId },
      include: {
        createdQuests: {
          select: {
            id: true,
            title: true,
            status: true,
            createdAt: true,
          },
        },
        participations: {
          include: {
            quest: {
              select: {
                id: true,
                title: true,
                status: true,
              },
            },
          },
        },
        achievements: {
          select: {
            id: true,
            title: true,
            rarity: true,
            mintedAt: true,
          },
        },
        _count: {
          select: {
            createdQuests: true,
            participations: true,
            achievements: true,
            verificationVotes: true,
          },
        },
      },
    });
  }

  async getQuestWithDetails(questId: string) {
    return this.quest.findUnique({
      where: { id: questId },
      include: {
        creator: {
          select: {
            id: true,
            username: true,
            avatar: true,
            reputationScore: true,
          },
        },
        category: true,
        participations: {
          include: {
            user: {
              select: {
                id: true,
                username: true,
                avatar: true,
              },
            },
          },
        },
        milestones: {
          orderBy: {
            orderIndex: 'asc',
          },
        },
        achievements: {
          select: {
            id: true,
            title: true,
            rarity: true,
            userId: true,
          },
        },
        _count: {
          select: {
            participations: true,
            evidenceSubmissions: true,
            achievements: true,
          },
        },
      },
    });
  }

  async getLeaderboardData(limit: number = 50) {
    return this.user.findMany({
      where: {
        isActive: true,
      },
      select: {
        id: true,
        username: true,
        avatar: true,
        reputationScore: true,
        completedQuests: true,
        totalEarnings: true,
        _count: {
          select: {
            achievements: true,
          },
        },
      },
      orderBy: [
        { reputationScore: 'desc' },
        { completedQuests: 'desc' },
        { totalEarnings: 'desc' },
      ],
      take: limit,
    });
  }

  async searchQuests(query: string, filters: {
    categoryId?: string;
    status?: string;
    creatorId?: string;
    limit?: number;
    offset?: number;
  }) {
    const where: any = {
      title: {
        contains: query,
        mode: 'insensitive',
      },
      isActive: true,
    };

    if (filters.categoryId) {
      where.categoryId = filters.categoryId;
    }

    if (filters.status) {
      where.status = filters.status;
    }

    if (filters.creatorId) {
      where.creatorId = filters.creatorId;
    }

    const [quests, total] = await Promise.all([
      this.quest.findMany({
        where,
        include: {
          creator: {
            select: {
              id: true,
              username: true,
              avatar: true,
            },
          },
          category: true,
          _count: {
            select: {
              participations: true,
            },
          },
        },
        orderBy: {
          createdAt: 'desc',
        },
        take: filters.limit || 20,
        skip: filters.offset || 0,
      }),
      this.quest.count({ where }),
    ]);

    return {
      quests,
      total,
      hasMore: (filters.offset || 0) + quests.length < total,
    };
  }
}

// Create singleton instance
const prisma = new ExtendedPrismaClient({
  datasources: {
    db: {
      url: config.database.url,
    },
  },
  log: config.env === 'development' ? ['query', 'info', 'warn', 'error'] : ['warn', 'error'],
  errorFormat: 'pretty',
});

// Handle graceful shutdown
process.on('beforeExit', async () => {
  await prisma.$disconnect();
  logger.info('Database disconnected');
});

// Export for global access in development
if (config.env === 'development') {
  (global as any).__prisma = prisma;
}

export const connectDatabase = async (): Promise<void> => {
  try {
    await prisma.$connect();
    logger.info('Database connected successfully');
    
    // Test connection
    const isHealthy = await prisma.healthCheck();
    if (!isHealthy) {
      throw new Error('Database health check failed');
    }
    
    logger.info('Database health check passed');
  } catch (error) {
    logger.error('Failed to connect to database:', error);
    throw error;
  }
};

export { prisma };
export type { ExtendedPrismaClient };
