import 'express-async-errors';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import morgan from 'morgan';
import dotenv from 'dotenv';
import { createServer } from 'http';
import { Server as SocketIOServer } from 'socket.io';

import { config } from '@/config/config';
import { logger } from '@/utils/logger';
import { connectDatabase } from '@/config/database';
import { connectRedis } from '@/config/redis';
import { errorHandler } from '@/middleware/errorHandler';
import { notFoundHandler } from '@/middleware/notFoundHandler';
import { rateLimiter } from '@/middleware/rateLimiter';
import { requestLogger } from '@/middleware/requestLogger';
import { setupSwagger } from '@/config/swagger';
import { setupSocketIO } from '@/config/socket';
import { startCronJobs } from '@/jobs/cronJobs';

// Routes
import authRoutes from '@/routes/auth';
import userRoutes from '@/routes/users';
import questRoutes from '@/routes/quests';
import milestoneRoutes from '@/routes/milestones';
import verificationRoutes from '@/routes/verification';
import achievementRoutes from '@/routes/achievements';
import categoryRoutes from '@/routes/categories';
import leaderboardRoutes from '@/routes/leaderboard';
import notificationRoutes from '@/routes/notifications';
import healthRoutes from '@/routes/health';

// Load environment variables
dotenv.config();

class Application {
  public app: express.Application;
  public server: any;
  public io: SocketIOServer;

  constructor() {
    this.app = express();
    this.server = createServer(this.app);
    this.io = new SocketIOServer(this.server, {
      cors: {
        origin: config.cors.origin,
        methods: ['GET', 'POST'],
        credentials: true,
      },
      transports: ['websocket', 'polling'],
    });

    this.initializeMiddlewares();
    this.initializeRoutes();
    this.initializeSwagger();
    this.initializeErrorHandling();
    this.initializeSocketIO();
  }

  private initializeMiddlewares(): void {
    // Security middleware
    this.app.use(helmet({
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          styleSrc: ["'self'", "'unsafe-inline'"],
          scriptSrc: ["'self'"],
          imgSrc: ["'self'", "data:", "https:"],
        },
      },
    }));

    // CORS configuration
    this.app.use(cors({
      origin: config.cors.origin,
      credentials: true,
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
    }));

    // Compression middleware
    this.app.use(compression());

    // Body parsing middleware
    this.app.use(express.json({ limit: '10mb' }));
    this.app.use(express.urlencoded({ extended: true, limit: '10mb' }));

    // Logging middleware
    if (config.env !== 'test') {
      this.app.use(morgan('combined', {
        stream: {
          write: (message: string) => logger.info(message.trim()),
        },
      }));
    }

    // Custom middleware
    this.app.use(requestLogger);
    this.app.use(rateLimiter);
  }

  private initializeRoutes(): void {
    // Health check
    this.app.use('/api/v1/health', healthRoutes);

    // API routes
    this.app.use('/api/v1/auth', authRoutes);
    this.app.use('/api/v1/users', userRoutes);
    this.app.use('/api/v1/quests', questRoutes);
    this.app.use('/api/v1/milestones', milestoneRoutes);
    this.app.use('/api/v1/verification', verificationRoutes);
    this.app.use('/api/v1/achievements', achievementRoutes);
    this.app.use('/api/v1/categories', categoryRoutes);
    this.app.use('/api/v1/leaderboard', leaderboardRoutes);
    this.app.use('/api/v1/notifications', notificationRoutes);

    // Root endpoint
    this.app.get('/', (req, res) => {
      res.json({
        message: 'ChainQuest API Server',
        version: '1.0.0',
        status: 'running',
        timestamp: new Date().toISOString(),
      });
    });
  }

  private initializeSwagger(): void {
    setupSwagger(this.app);
  }

  private initializeErrorHandling(): void {
    // 404 handler
    this.app.use(notFoundHandler);

    // Global error handler
    this.app.use(errorHandler);
  }

  private initializeSocketIO(): void {
    setupSocketIO(this.io);
  }

  public async start(): Promise<void> {
    try {
      // Connect to database
      await connectDatabase();
      logger.info('Database connected successfully');

      // Connect to Redis
      await connectRedis();
      logger.info('Redis connected successfully');

      // Start cron jobs
      startCronJobs();
      logger.info('Cron jobs started');

      // Start server
      this.server.listen(config.port, config.host, () => {
        logger.info(`🚀 Server running on ${config.host}:${config.port}`);
        logger.info(`📚 API Documentation: http://${config.host}:${config.port}/api-docs`);
        logger.info(`🔗 Environment: ${config.env}`);
      });

      // Graceful shutdown
      this.setupGracefulShutdown();

    } catch (error) {
      logger.error('Failed to start application:', error);
      process.exit(1);
    }
  }

  private setupGracefulShutdown(): void {
    const gracefulShutdown = async (signal: string) => {
      logger.info(`Received ${signal}. Starting graceful shutdown...`);

      // Stop accepting new connections
      this.server.close(async () => {
        logger.info('HTTP server closed');

        try {
          // Close Socket.IO
          this.io.close();
          logger.info('Socket.IO server closed');

          // Close database connections
          // Add database cleanup here if needed

          logger.info('Graceful shutdown completed');
          process.exit(0);
        } catch (error) {
          logger.error('Error during graceful shutdown:', error);
          process.exit(1);
        }
      });

      // Force shutdown after 30 seconds
      setTimeout(() => {
        logger.error('Forced shutdown after timeout');
        process.exit(1);
      }, 30000);
    };

    // Handle process signals
    process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
    process.on('SIGINT', () => gracefulShutdown('SIGINT'));

    // Handle uncaught exceptions
    process.on('uncaughtException', (error) => {
      logger.error('Uncaught Exception:', error);
      process.exit(1);
    });

    // Handle unhandled promise rejections
    process.on('unhandledRejection', (reason, promise) => {
      logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
      process.exit(1);
    });
  }
}

// Create and start the application
const application = new Application();

// Start the server if this file is run directly
if (require.main === module) {
  application.start().catch((error) => {
    console.error('Failed to start application:', error);
    process.exit(1);
  });
}

export default application;
