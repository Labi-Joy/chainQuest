# ChainQuest - System Architecture

## Overview

ChainQuest is a decentralized achievement platform built on a modern, scalable architecture that combines blockchain technology with traditional web infrastructure. The system is designed to handle millions of users while maintaining security, performance, and decentralization principles.

## High-Level Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │   Backend       │    │   Blockchain    │
│   (Next.js)     │◄──►│   (Node.js)     │◄──►│   (Base)        │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   CDN/Storage   │    │   Database      │    │   IPFS          │
│   (Cloudflare)  │    │   (PostgreSQL)  │    │   (Metadata)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## System Components

### 1. Frontend Architecture

#### Technology Stack
- **Framework**: Next.js 14+ with App Router
- **Language**: TypeScript
- **Styling**: Tailwind CSS + shadcn/ui
- **State Management**: React Query + Zustand
- **Wallet Integration**: RainbowKit + Wagmi
- **Form Handling**: React Hook Form + Zod

#### Component Architecture
```
src/
├── app/                    # Next.js App Router
│   ├── (auth)/            # Authentication pages
│   ├── (dashboard)/       # Dashboard pages
│   ├── quests/            # Quest-related pages
│   ├── profile/           # User profile pages
│   └── api/               # API routes
├── components/            # Reusable components
│   ├── ui/               # shadcn/ui components
│   ├── forms/            # Form components
│   ├── quest/            # Quest-specific components
│   └── layout/           # Layout components
├── hooks/                # Custom React hooks
├── lib/                  # Utility libraries
├── store/                # State management
└── types/                # TypeScript definitions
```

#### Key Features
- **Server-Side Rendering (SSR)**: SEO-friendly quest pages
- **Client-Side Navigation**: Smooth SPA experience
- **Progressive Web App (PWA)**: Offline capabilities
- **Responsive Design**: Mobile-first approach
- **Accessibility**: WCAG 2.1 AA compliance

### 2. Backend Architecture

#### Technology Stack
- **Runtime**: Node.js 18+
- **Language**: TypeScript
- **Framework**: Express.js
- **Database**: PostgreSQL 15+
- **ORM**: Prisma
- **Authentication**: SIWE (Sign-In with Ethereum)
- **Real-time**: Socket.io

#### Service Architecture
```
src/
├── controllers/          # Request handlers
├── services/            # Business logic
├── models/              # Data models
├── middleware/          # Express middleware
├── routes/              # API routes
├── utils/               # Utility functions
├── config/              # Configuration
├── events/              # Event handlers
└── jobs/                # Background jobs
```

#### Microservices Design

##### API Gateway Service
- Request routing and load balancing
- Rate limiting and throttling
- Authentication and authorization
- Request/response transformation
- API versioning

##### Quest Service
- Quest CRUD operations
- Quest search and filtering
- Quest state management
- Quest analytics
- Quest recommendations

##### User Service
- User profile management
- Authentication and authorization
- User statistics
- Social features
- Reputation system

##### Verification Service
- Evidence processing
- Verification logic
- Dispute resolution
- Validator management
- Reward distribution

##### Notification Service
- Real-time notifications
- Email notifications
- Push notifications
- Notification preferences
- Notification analytics

##### Analytics Service
- User behavior tracking
- Quest performance metrics
- Platform statistics
- Business intelligence
- Reporting tools

### 3. Smart Contract Architecture

#### Contract Design Principles
- **Modularity**: Separate concerns into focused contracts
- **Upgradeability**: Proxy pattern for contract upgrades
- **Gas Efficiency**: Optimized for minimal gas usage
- **Security**: Reentrancy guards, access controls
- **Interoperability**: Standard interfaces (ERC20, ERC721)

#### Contract Hierarchy
```
QuestFactory (Factory)
    ├── Creates Quest contracts
    ├── Manages quest templates
    └── Handles quest registry

Quest (Individual Quest)
    ├── Milestone tracking
    ├── State management
    ├── Reward distribution
    └── Event emissions

RewardPool (Financial Management)
    ├── Staking mechanism
    ├── Reward calculation
    ├── Slashing logic
    └── Emergency functions

VerificationOracle (Decentralized Verification)
    ├── Validator management
    ├── Voting logic
    ├── Dispute resolution
    └── Reward distribution

AchievementNFT (ERC721)
    ├── Badge minting
    ├── Metadata management
    ├── Transfer controls
    └── Batch operations

GovernanceToken (ERC20)
    ├── Token distribution
    ├── Voting rights
    ├── Staking rewards
    └── Governance functions
```

#### Contract Interactions
```
User → QuestFactory.createQuest()
     → Quest (new contract)
     → RewardPool.stake()
     → VerificationOracle.registerValidator()
     → AchievementNFT.mint()
```

### 4. Database Architecture

#### Schema Design
```sql
-- Users and Authentication
users
├── id (UUID, Primary Key)
├── wallet_address (VARCHAR, Unique)
├── nonce (VARCHAR)
├── created_at (TIMESTAMP)
├── updated_at (TIMESTAMP)
└── profile_data (JSONB)

-- Quests
quests
├── id (UUID, Primary Key)
├── contract_address (VARCHAR, Unique)
├── creator_id (UUID, Foreign Key)
├── title (VARCHAR)
├── description (TEXT)
├── category_id (UUID, Foreign Key)
├── stake_amount (DECIMAL)
├── reward_pool (DECIMAL)
├── status (ENUM)
├── created_at (TIMESTAMP)
├── expires_at (TIMESTAMP)
└── metadata (JSONB)

-- Quest Participants
quest_participants
├── id (UUID, Primary Key)
├── quest_id (UUID, Foreign Key)
├── user_id (UUID, Foreign Key)
├── stake_amount (DECIMAL)
├── status (ENUM)
├── joined_at (TIMESTAMP)
├── completed_at (TIMESTAMP)
└── progress_data (JSONB)

-- Milestones
milestones
├── id (UUID, Primary Key)
├── quest_id (UUID, Foreign Key)
├── title (VARCHAR)
├── description (TEXT)
├── order_index (INTEGER)
├── verification_type (ENUM)
└── required_evidence (JSONB)

-- Evidence Submissions
evidence
├── id (UUID, Primary Key)
├── milestone_id (UUID, Foreign Key)
├── participant_id (UUID, Foreign Key)
├── evidence_type (ENUM)
├── ipfs_hash (VARCHAR)
├── submitted_at (TIMESTAMP)
└── metadata (JSONB)

-- Verification Votes
verification_votes
├── id (UUID, Primary Key)
├── evidence_id (UUID, Foreign Key)
├── validator_id (UUID, Foreign Key)
├── vote_type (ENUM)
├── confidence_score (INTEGER)
├── voted_at (TIMESTAMP)
└── reasoning (TEXT)

-- Achievements
achievements
├── id (UUID, Primary Key)
├── user_id (UUID, Foreign Key)
├── quest_id (UUID, Foreign Key)
├── nft_token_id (INTEGER)
├── minted_at (TIMESTAMP)
├── rarity_level (ENUM)
└── metadata (JSONB)

-- Categories
categories
├── id (UUID, Primary Key)
├── name (VARCHAR, Unique)
├── description (TEXT)
├── icon_url (VARCHAR)
├── parent_id (UUID, Foreign Key)
└── sort_order (INTEGER)
```

#### Indexing Strategy
```sql
-- Performance Indexes
CREATE INDEX idx_quests_creator_id ON quests(creator_id);
CREATE INDEX idx_quests_status ON quests(status);
CREATE INDEX idx_quests_category_id ON quests(category_id);
CREATE INDEX idx_quests_expires_at ON quests(expires_at);
CREATE INDEX idx_quest_participants_user_id ON quest_participants(user_id);
CREATE INDEX idx_quest_participants_quest_id ON quest_participants(quest_id);
CREATE INDEX idx_evidence_milestone_id ON evidence(milestone_id);
CREATE INDEX idx_verification_votes_evidence_id ON verification_votes(evidence_id);
CREATE INDEX idx_achievements_user_id ON achievements(user_id);

-- Composite Indexes
CREATE INDEX idx_quests_status_category ON quests(status, category_id);
CREATE INDEX idx_participants_user_status ON quest_participants(user_id, status);
CREATE INDEX idx_achievements_user_quest ON achievements(user_id, quest_id);
```

### 5. API Architecture

#### RESTful API Design
```
/api/v1/
├── auth/
│   ├── POST /login          # SIWE authentication
│   ├── POST /logout         # Session termination
│   └── GET /nonce           # Get nonce for signature
├── users/
│   ├── GET /me              # Current user profile
│   ├── PUT /me              # Update profile
│   ├── GET /:id             # User profile
│   └── GET /:id/achievements # User achievements
├── quests/
│   ├── GET /                # List quests
│   ├── POST /               # Create quest
│   ├── GET /:id             # Quest details
│   ├── PUT /:id             # Update quest
│   ├── DELETE /:id          # Delete quest
│   ├── POST /:id/join       # Join quest
│   ├── POST /:id/leave      # Leave quest
│   └── GET /:id/participants # Quest participants
├── milestones/
│   ├── GET /:quest_id       # List milestones
│   ├── POST /:quest_id      # Create milestone
│   ├── GET /:id             # Milestone details
│   └── POST /:id/evidence   # Submit evidence
├── verification/
│   ├── GET /pending         # Pending verifications
│   ├── POST /:evidence_id/vote # Cast vote
│   └── POST /:evidence_id/dispute # Create dispute
└── achievements/
    ├── GET /                # User achievements
    ├── GET /:id             # Achievement details
    └── POST /mint           # Mint achievement NFT
```

#### GraphQL API (Alternative)
```graphql
type Query {
  user(id: ID!): User
  quests(filter: QuestFilter): [Quest!]!
  quest(id: ID!): Quest
  achievements(userId: ID!): [Achievement!]!
}

type Mutation {
  createQuest(input: CreateQuestInput!): Quest!
  joinQuest(questId: ID!): QuestParticipant!
  submitEvidence(milestoneId: ID!, evidence: EvidenceInput!): Evidence!
  castVote(evidenceId: ID!, vote: VoteInput!): VerificationVote!
}

type Subscription {
  questUpdates(questId: ID!): Quest!
  verificationUpdates: VerificationUpdate!
  userNotifications(userId: ID!): Notification!
}
```

#### WebSocket Events
```javascript
// Client → Server
socket.emit('join-quest', questId);
socket.emit('leave-quest', questId);
socket.emit('submit-evidence', evidenceData);
socket.emit('cast-vote', voteData);

// Server → Client
socket.emit('quest-updated', questData);
socket.emit('evidence-submitted', evidenceData);
socket.emit('verification-complete', verificationResult);
socket.emit('achievement-unlocked', achievementData);
socket.emit('notification', notificationData);
```

## Security Architecture

### 1. Authentication & Authorization

#### SIWE Implementation
```javascript
// Authentication Flow
1. Frontend requests nonce from backend
2. Backend generates and stores nonce
3. Frontend requests wallet signature
4. User signs message with wallet
5. Frontend sends signature to backend
6. Backend verifies signature and nonce
7. Backend issues JWT token
8. Frontend stores token for API calls
```

#### Access Control
```javascript
// Role-based Access Control
const roles = {
  USER: 'user',
  QUEST_CREATOR: 'quest_creator',
  VALIDATOR: 'validator',
  MODERATOR: 'moderator',
  ADMIN: 'admin'
};

// Permission Matrix
const permissions = {
  'create_quest': ['QUEST_CREATOR', 'ADMIN'],
  'verify_evidence': ['VALIDATOR', 'MODERATOR', 'ADMIN'],
  'moderate_content': ['MODERATOR', 'ADMIN'],
  'manage_platform': ['ADMIN']
};
```

### 2. Smart Contract Security

#### Security Measures
- **Reentrancy Guards**: Prevent reentrancy attacks
- **Access Control**: Role-based permissions
- **Input Validation**: Validate all inputs
- **Emergency Controls**: Pause/circuit breakers
- **Upgrade Safety**: Secure proxy patterns
- **Event Logging**: Comprehensive event emission

#### Audit Checklist
- [ ] Integer overflow/underflow protection
- [ ] Access control verification
- [ ] Gas limit considerations
- [ ] Front-running protection
- [ ] Oracle manipulation resistance
- [ ] Upgrade mechanism security

### 3. Data Security

#### Encryption Strategy
```javascript
// Data at Rest
- Database encryption (AES-256)
- Environment variable encryption
- Backup encryption

// Data in Transit
- TLS 1.3 for all API communications
- WebSocket secure connections
- Certificate pinning for mobile

// Data Privacy
- PII anonymization
- GDPR compliance
- Data retention policies
```

#### Privacy Controls
```javascript
// User Privacy Settings
const privacySettings = {
  profileVisibility: 'public|private|friends',
  achievementVisibility: 'public|private',
  dataSharing: 'marketing|analytics|none',
  communicationPreferences: 'email|push|none'
};
```

## Performance Architecture

### 1. Caching Strategy

#### Multi-level Caching
```
Browser Cache (CDN)
    ↓
Edge Cache (Cloudflare)
    ↓
Application Cache (Redis)
    ↓
Database Cache (PostgreSQL)
```

#### Cache Implementation
```javascript
// Redis Caching
const cacheKeys = {
  user: (userId) => `user:${userId}`,
  quest: (questId) => `quest:${questId}`,
  questList: (filters) => `quests:${JSON.stringify(filters)}`,
  userAchievements: (userId) => `achievements:${userId}`
};

// Cache TTL
const cacheTTL = {
  user: 3600,        // 1 hour
  quest: 1800,       // 30 minutes
  questList: 300,    // 5 minutes
  userAchievements: 600 // 10 minutes
};
```

### 2. Database Optimization

#### Query Optimization
```sql
-- Optimized Quest Listing
SELECT 
  q.id, q.title, q.stake_amount, q.expires_at,
  c.name as category_name,
  COUNT(p.id) as participant_count
FROM quests q
LEFT JOIN categories c ON q.category_id = c.id
LEFT JOIN quest_participants p ON q.id = p.quest_id
WHERE q.status = 'active'
  AND q.expires_at > NOW()
GROUP BY q.id, c.name
ORDER BY q.created_at DESC
LIMIT 20;
```

#### Connection Pooling
```javascript
// PostgreSQL Pool Configuration
const pool = {
  min: 2,
  max: 10,
  acquire: 30000,
  idle: 10000,
  evict: 1000
};
```

### 3. Frontend Performance

#### Code Splitting
```javascript
// Dynamic Imports
const QuestCreation = dynamic(() => import('./components/QuestCreation'));
const UserProfile = dynamic(() => import('./components/UserProfile'));
const Dashboard = dynamic(() => import('./components/Dashboard'));
```

#### Image Optimization
```javascript
// Next.js Image Optimization
<Image
  src="/quest-cover.jpg"
  alt="Quest Cover"
  width={400}
  height={300}
  priority={isAboveFold}
  placeholder="blur"
  blurDataURL="data:image/jpeg;base64,..."
/>
```

## Scalability Architecture

### 1. Horizontal Scaling

#### Load Balancing
```
Internet → CDN → Load Balancer → API Servers
                              → Database Cluster
                              → Cache Cluster
```

#### Auto-scaling Configuration
```yaml
# Kubernetes HPA
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: chainquest-api
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: chainquest-api
  minReplicas: 2
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### 2. Database Scaling

#### Read Replicas
```
Primary Database (Write)
    ↓
Read Replica 1 (Read)
Read Replica 2 (Read)
Read Replica 3 (Read)
```

#### Sharding Strategy
```javascript
// User-based Sharding
const getShard = (userId) => {
  const shardCount = 4;
  const hash = crypto.createHash('sha256').update(userId).digest('hex');
  const shardIndex = parseInt(hash.substring(0, 8), 16) % shardCount;
  return `shard_${shardIndex}`;
};
```

### 3. Blockchain Scaling

#### Layer 2 Integration
```javascript
// Base Network Configuration
const baseConfig = {
  network: 'base-sepolia', // Testnet
  rpcUrl: 'https://sepolia.base.org',
  blockTime: 2, // seconds
  gasPrice: '0.1 gwei'
};
```

#### Gas Optimization
```solidity
// Gas-efficient Quest Creation
function createQuest(
    string memory title,
    uint256 stakeAmount,
    uint256 duration
) external returns (address) {
    // Use minimal storage
    // Batch operations
    // Optimize data types
    // Use events for off-chain storage
}
```

## Monitoring & Observability

### 1. Application Monitoring

#### Metrics Collection
```javascript
// Prometheus Metrics
const metrics = {
  httpRequestsTotal: new Counter({
    name: 'http_requests_total',
    help: 'Total HTTP requests',
    labelNames: ['method', 'route', 'status']
  }),
  httpRequestDuration: new Histogram({
    name: 'http_request_duration_seconds',
    help: 'HTTP request duration',
    labelNames: ['method', 'route']
  }),
  activeUsers: new Gauge({
    name: 'active_users_total',
    help: 'Number of active users'
  })
};
```

#### Health Checks
```javascript
// Health Check Endpoints
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    services: {
      database: 'healthy',
      redis: 'healthy',
      blockchain: 'healthy',
      ipfs: 'healthy'
    }
  });
});
```

### 2. Error Tracking

#### Sentry Integration
```javascript
// Error Tracking
Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  tracesSampleRate: 0.1
});

// Custom Error Context
Sentry.withScope((scope) => {
  scope.setUser({ id: userId });
  scope.setTag('questId', questId);
  scope.setExtra('evidence', evidenceData);
  Sentry.captureException(error);
});
```

### 3. Performance Monitoring

#### Frontend Performance
```javascript
// Web Vitals Monitoring
import { getCLS, getFID, getFCP, getLCP, getTTFB } from 'web-vitals';

getCLS(console.log);
getFID(console.log);
getFCP(console.log);
getLCP(console.log);
getTTFB(console.log);
```

#### Database Performance
```sql
-- Query Performance Analysis
EXPLAIN ANALYZE
SELECT * FROM quests 
WHERE status = 'active' 
  AND expires_at > NOW()
ORDER BY created_at DESC
LIMIT 20;
```

## Deployment Architecture

### 1. Container Strategy

#### Docker Configuration
```dockerfile
# Multi-stage Dockerfile
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:18-alpine AS runtime
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
```

#### Docker Compose
```yaml
version: '3.8'
services:
  frontend:
    build: ./frontend
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
  
  backend:
    build: ./backend
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql://user:pass@postgres:5432/chainquest
    depends_on:
      - postgres
      - redis
  
  postgres:
    image: postgres:15
    environment:
      - POSTGRES_DB=chainquest
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=pass
    volumes:
      - postgres_data:/var/lib/postgresql/data
  
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
```

### 2. CI/CD Pipeline

#### GitHub Actions
```yaml
name: Deploy ChainQuest
on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run tests
        run: npm test
  
  deploy:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to production
        run: ./deploy.sh
```

This architecture provides a solid foundation for ChainQuest to scale from a prototype to a production platform serving millions of users while maintaining security, performance, and decentralization principles.
