import Redis from 'ioredis';
import { logger } from '@/utils/logger';
import { config } from './config';

class RedisClient {
  private client: Redis;
  private isConnected: boolean = false;

  constructor() {
    this.client = new Redis(config.redis.url, {
      retryDelayOnFailover: 100,
      enableReadyCheck: false,
      maxRetriesPerRequest: 3,
      lazyConnect: true,
      keepAlive: 30000,
      connectTimeout: 10000,
      commandTimeout: 5000,
    });

    this.setupEventHandlers();
  }

  private setupEventHandlers(): void {
    this.client.on('connect', () => {
      logger.info('Redis client connected');
      this.isConnected = true;
    });

    this.client.on('ready', () => {
      logger.info('Redis client ready');
    });

    this.client.on('error', (error) => {
      logger.error('Redis client error:', error);
      this.isConnected = false;
    });

    this.client.on('close', () => {
      logger.info('Redis client connection closed');
      this.isConnected = false;
    });

    this.client.on('reconnecting', () => {
      logger.info('Redis client reconnecting...');
    });
  }

  async connect(): Promise<void> {
    try {
      await this.client.connect();
      
      // Test connection
      await this.client.ping();
      
      logger.info('Redis connection established');
    } catch (error) {
      logger.error('Failed to connect to Redis:', error);
      throw error;
    }
  }

  async disconnect(): Promise<void> {
    try {
      await this.client.quit();
      logger.info('Redis client disconnected');
    } catch (error) {
      logger.error('Error disconnecting Redis:', error);
    }
  }

  getClient(): Redis {
    if (!this.isConnected) {
      throw new Error('Redis client is not connected');
    }
    return this.client;
  }

  // Cache operations
  async set(key: string, value: string, ttl?: number): Promise<void> {
    const client = this.getClient();
    if (ttl) {
      await client.setex(key, ttl, value);
    } else {
      await client.set(key, value);
    }
  }

  async get(key: string): Promise<string | null> {
    const client = this.getClient();
    return await client.get(key);
  }

  async del(key: string): Promise<number> {
    const client = this.getClient();
    return await client.del(key);
  }

  async exists(key: string): Promise<boolean> {
    const client = this.getClient();
    const result = await client.exists(key);
    return result === 1;
  }

  async expire(key: string, ttl: number): Promise<boolean> {
    const client = this.getClient();
    const result = await client.expire(key, ttl);
    return result === 1;
  }

  // Hash operations
  async hset(key: string, field: string, value: string): Promise<number> {
    const client = this.getClient();
    return await client.hset(key, field, value);
  }

  async hget(key: string, field: string): Promise<string | null> {
    const client = this.getClient();
    return await client.hget(key, field);
  }

  async hgetall(key: string): Promise<Record<string, string>> {
    const client = this.getClient();
    return await client.hgetall(key);
  }

  async hdel(key: string, field: string): Promise<number> {
    const client = this.getClient();
    return await client.hdel(key, field);
  }

  // List operations
  async lpush(key: string, ...values: string[]): Promise<number> {
    const client = this.getClient();
    return await client.lpush(key, ...values);
  }

  async rpush(key: string, ...values: string[]): Promise<number> {
    const client = this.getClient();
    return await client.rpush(key, ...values);
  }

  async lpop(key: string): Promise<string | null> {
    const client = this.getClient();
    return await client.lpop(key);
  }

  async rpop(key: string): Promise<string | null> {
    const client = this.getClient();
    return await client.rpop(key);
  }

  async lrange(key: string, start: number, stop: number): Promise<string[]> {
    const client = this.getClient();
    return await client.lrange(key, start, stop);
  }

  // Set operations
  async sadd(key: string, ...members: string[]): Promise<number> {
    const client = this.getClient();
    return await client.sadd(key, ...members);
  }

  async srem(key: string, ...members: string[]): Promise<number> {
    const client = this.getClient();
    return await client.srem(key, ...members);
  }

  async smembers(key: string): Promise<string[]> {
    const client = this.getClient();
    return await client.smembers(key);
  }

  async sismember(key: string, member: string): Promise<boolean> {
    const client = this.getClient();
    const result = await client.sismember(key, member);
    return result === 1;
  }

  // Pub/Sub operations
  async publish(channel: string, message: string): Promise<number> {
    const client = this.getClient();
    return await client.publish(channel, message);
  }

  async subscribe(channel: string, callback: (channel: string, message: string) => void): Promise<void> {
    const subscriber = new Redis(config.redis.url);
    
    subscriber.subscribe(channel, (err, count) => {
      if (err) {
        logger.error('Redis subscription error:', err);
        return;
      }
      logger.info(`Subscribed to ${count} channels`);
    });

    subscriber.on('message', (channel, message) => {
      callback(channel, message);
    });
  }

  // Utility methods
  async flushdb(): Promise<string> {
    const client = this.getClient();
    return await client.flushdb();
  }

  async keys(pattern: string): Promise<string[]> {
    const client = this.getClient();
    return await client.keys(pattern);
  }

  async ttl(key: string): Promise<number> {
    const client = this.getClient();
    return await client.ttl(key);
  }

  // Health check
  async healthCheck(): Promise<boolean> {
    try {
      await this.client.ping();
      return true;
    } catch (error) {
      logger.error('Redis health check failed:', error);
      return false;
    }
  }

  // Get connection status
  isRedisConnected(): boolean {
    return this.isConnected;
  }
}

// Create singleton instance
const redisClient = new RedisClient();

export const connectRedis = async (): Promise<void> => {
  await redisClient.connect();
};

export const disconnectRedis = async (): Promise<void> => {
  await redisClient.disconnect();
};

export { redisClient };
export type { RedisClient };
