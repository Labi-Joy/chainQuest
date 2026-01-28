import { Router, Request, Response } from 'express';
import { prisma } from '@/config/database';
import { redisClient } from '@/config/redis';
import { catchAsync } from '@/middleware/errorHandler';

const router = Router();

router.get(
  '/',
  catchAsync(async (req: Request, res: Response) => {
    // Check database connection
    const dbHealthy = await prisma.healthCheck();
    
    // Check Redis connection
    const redisHealthy = await redisClient.healthCheck();
    
    // Overall health status
    const isHealthy = dbHealthy && redisHealthy;
    
    const healthData = {
      status: isHealthy ? 'healthy' : 'unhealthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      version: process.env.npm_package_version || '1.0.0',
      environment: process.env.NODE_ENV || 'development',
      services: {
        database: {
          status: dbHealthy ? 'connected' : 'disconnected',
          responseTime: Date.now(),
        },
        redis: {
          status: redisHealthy ? 'connected' : 'disconnected',
          responseTime: Date.now(),
        },
      },
      memory: {
        used: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
        total: Math.round(process.memoryUsage().heapTotal / 1024 / 1024),
        external: Math.round(process.memoryUsage().external / 1024 / 1024),
      },
    };

    const statusCode = isHealthy ? 200 : 503;
    res.status(statusCode).json(healthData);
  })
);

router.get(
  '/db',
  catchAsync(async (req: Request, res: Response) => {
    const stats = await prisma.getDatabaseStats();
    res.json({
      status: 'connected',
      timestamp: new Date().toISOString(),
      stats,
    });
  })
);

router.get(
  '/redis',
  catchAsync(async (req: Request, res: Response) => {
    const isHealthy = await redisClient.healthCheck();
    const info = {
      status: isHealthy ? 'connected' : 'disconnected',
      timestamp: new Date().toISOString(),
      connected: redisClient.isRedisConnected(),
    };
    
    res.json(info);
  })
);

export default router;
