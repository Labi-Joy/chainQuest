import cron from 'node-cron';
import { logger } from '@/utils/logger';
import { prisma } from '@/config/database';

export const startCronJobs = (): void => {
  // Check for expired quests every 6 hours
  cron.schedule('0 */6 * * *', async () => {
    logger.info('Running quest expiration check...');
    try {
      const expiredQuests = await prisma.quest.updateMany({
        where: {
          status: 'ACTIVE',
          expiresAt: {
            lt: new Date(),
          },
        },
        data: {
          status: 'EXPIRED',
        },
      });

      logger.info(`Updated ${expiredQuests.count} expired quests`);
    } catch (error) {
      logger.error('Error checking expired quests:', error);
    }
  });

  // Check for verification timeouts every 2 hours
  cron.schedule('0 */2 * * *', async () => {
    logger.info('Running verification timeout check...');
    try {
      const timeoutSubmissions = await prisma.evidenceSubmission.updateMany({
        where: {
          verificationStatus: 'PENDING',
          verificationDeadline: {
            lt: new Date(),
          },
        },
        data: {
          verificationStatus: 'EXPIRED',
        },
      });

      logger.info(`Updated ${timeoutSubmissions.count} timed out verifications`);
    } catch (error) {
      logger.error('Error checking verification timeouts:', error);
    }
  });

  // Check for dispute deadlines every hour
  cron.schedule('0 * * * *', async () => {
    logger.info('Running dispute deadline check...');
    try {
      const expiredDisputes = await prisma.dispute.updateMany({
        where: {
          status: 'PENDING',
          deadline: {
            lt: new Date(),
          },
        },
        data: {
          status: 'REJECTED',
        },
      });

      logger.info(`Updated ${expiredDisputes.count} expired disputes`);
    } catch (error) {
      logger.error('Error checking dispute deadlines:', error);
    }
  });

  logger.info('Cron jobs started successfully');
};
