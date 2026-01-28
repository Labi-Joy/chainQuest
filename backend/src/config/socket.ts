import { Server as SocketIOServer } from 'socket.io';
import { logger } from '@/utils/logger';

export const setupSocketIO = (io: SocketIOServer): void => {
  io.on('connection', (socket) => {
    logger.info(`User connected: ${socket.id}`);

    // Handle user authentication
    socket.on('authenticate', (token: string) => {
      // TODO: Verify JWT token and associate user with socket
      logger.info(`User ${socket.id} attempting authentication`);
    });

    // Handle joining quest rooms
    socket.on('join-quest', (questId: string) => {
      socket.join(`quest-${questId}`);
      logger.info(`User ${socket.id} joined quest room: ${questId}`);
    });

    // Handle leaving quest rooms
    socket.on('leave-quest', (questId: string) => {
      socket.leave(`quest-${questId}`);
      logger.info(`User ${socket.id} left quest room: ${questId}`);
    });

    // Handle real-time quest updates
    socket.on('quest-update', (data: any) => {
      socket.to(`quest-${data.questId}`).emit('quest-updated', data);
    });

    // Handle verification updates
    socket.on('verification-update', (data: any) => {
      socket.to(`quest-${data.questId}`).emit('verification-updated', data);
    });

    // Handle disconnection
    socket.on('disconnect', () => {
      logger.info(`User disconnected: ${socket.id}`);
    });

    // Error handling
    socket.on('error', (error) => {
      logger.error(`Socket error for user ${socket.id}:`, error);
    });
  });

  logger.info('Socket.IO server configured');
};
