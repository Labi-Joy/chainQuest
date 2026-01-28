import winston from 'winston';
import DailyRotateFile from 'winston-daily-rotate-file';
import { config } from '@/config/config';

// Define log levels
const levels = {
  error: 0,
  warn: 1,
  info: 2,
  http: 3,
  debug: 4,
};

// Define colors for each level
const colors = {
  error: 'red',
  warn: 'yellow',
  info: 'green',
  http: 'magenta',
  debug: 'white',
};

// Tell winston that you want to link the colors
winston.addColors(colors);

// Define which level to log based on environment
const level = () => {
  const env = config.env || 'development';
  const isDevelopment = env === 'development';
  return isDevelopment ? 'debug' : 'warn';
};

// Define different log formats
const format = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss:ms' }),
  winston.format.colorize({ all: true }),
  winston.format.printf(
    (info) => `${info.timestamp} ${info.level}: ${info.message}`,
  ),
);

// Define transports
const transports = [
  // Console transport
  new winston.transports.Console({
    format,
  }),
];

// Add file transport only in production or when log file path is specified
if (config.env === 'production' || config.logging.filePath) {
  // Daily rotate file transport for all logs
  transports.push(
    new DailyRotateFile({
      filename: `${config.logging.filePath}/application-%DATE%.log`,
      datePattern: 'YYYY-MM-DD',
      zippedArchive: true,
      maxSize: '20m',
      maxFiles: '14d',
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json(),
      ),
    }),
  );

  // Separate file for errors
  transports.push(
    new DailyRotateFile({
      filename: `${config.logging.filePath}/error-%DATE%.log`,
      datePattern: 'YYYY-MM-DD',
      zippedArchive: true,
      maxSize: '20m',
      maxFiles: '30d',
      level: 'error',
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json(),
      ),
    }),
  );
}

// Create the logger
const logger = winston.createLogger({
  level: level(),
  levels,
  format,
  transports,
  exitOnError: false,
});

// Add custom methods for structured logging
logger.logRequest = (req: any, res: any, responseTime?: number) => {
  const logData = {
    method: req.method,
    url: req.url,
    statusCode: res.statusCode,
    responseTime: responseTime ? `${responseTime}ms` : undefined,
    userAgent: req.get('User-Agent'),
    ip: req.ip || req.connection.remoteAddress,
  };

  if (res.statusCode >= 400) {
    logger.warn('HTTP Request', logData);
  } else {
    logger.http('HTTP Request', logData);
  }
};

logger.logError = (error: Error, context?: any) => {
  const logData = {
    message: error.message,
    stack: error.stack,
    context,
  };

  logger.error('Application Error', logData);
};

logger.logBlockchain = (action: string, data: any) => {
  logger.info('Blockchain Action', { action, ...data });
};

logger.logDatabase = (operation: string, table: string, data?: any) => {
  logger.debug('Database Operation', { operation, table, ...data });
};

logger.logSecurity = (event: string, data: any) => {
  logger.warn('Security Event', { event, ...data });
};

logger.logPerformance = (operation: string, duration: number, data?: any) => {
  logger.info('Performance Metric', { operation, duration: `${duration}ms`, ...data });
};

// Create a stream object for Morgan HTTP logger
logger.stream = {
  write: (message: string) => {
    logger.http(message.trim());
  },
};

// Handle uncaught exceptions
logger.exceptions.handle(
  new DailyRotateFile({
    filename: `${config.logging.filePath}/exceptions-%DATE%.log`,
    datePattern: 'YYYY-MM-DD',
    zippedArchive: true,
    maxSize: '20m',
    maxFiles: '30d',
  }),
);

// Handle unhandled promise rejections
logger.rejections.handle(
  new DailyRotateFile({
    filename: `${config.logging.filePath}/rejections-%DATE%.log`,
    datePattern: 'YYYY-MM-DD',
    zippedArchive: true,
    maxSize: '20m',
    maxFiles: '30d',
  }),
);

// Export the logger
export { logger };

// Also export a child logger with context
export const createChildLogger = (service: string) => {
  return logger.child({ service });
};
