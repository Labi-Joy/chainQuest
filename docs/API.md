# ChainQuest - API Documentation

## Overview

ChainQuest provides a comprehensive RESTful API for managing quests, users, achievements, and verification processes. The API is designed to be secure, scalable, and easy to integrate with frontend applications and third-party services.

## Base URL

- **Development**: `http://localhost:8000/api/v1`
- **Staging**: `https://staging-api.chainquest.app/api/v1`
- **Production**: `https://api.chainquest.app/api/v1`

## Authentication

### SIWE (Sign-In with Ethereum)

ChainQuest uses Sign-In with Ethereum for authentication. The flow involves:

1. **Get Nonce**: Request a unique nonce from the server
2. **Sign Message**: User signs the nonce message with their wallet
3. **Verify Signature**: Server verifies the signature and issues a JWT token
4. **API Calls**: Include JWT token in Authorization header

#### Get Nonce
```http
GET /auth/nonce
```

**Response:**
```json
{
  "nonce": "random_nonce_string",
  "message": "Welcome to ChainQuest! Sign this message to authenticate.",
  "issuedAt": "2023-12-01T10:00:00.000Z"
}
```

#### Authenticate
```http
POST /auth/login
Content-Type: application/json

{
  "address": "0x742d35Cc6634C0532925a3b8D4C9db96C4b4Db45",
  "signature": "0x...",
  "nonce": "random_nonce_string"
}
```

**Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "uuid",
    "address": "0x742d35Cc6634C0532925a3b8D4C9db96C4b4Db45",
    "nonce": "new_nonce",
    "createdAt": "2023-12-01T10:00:00.000Z"
  }
}
```

#### API Authentication
Include the JWT token in the Authorization header:
```http
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

## API Endpoints

### Authentication

#### Login
```http
POST /auth/login
```

**Request Body:**
```json
{
  "address": "0x742d35Cc6634C0532925a3b8D4C9db96C4b4Db45",
  "signature": "0x...",
  "nonce": "random_nonce_string"
}
```

**Response:**
```json
{
  "token": "jwt_token",
  "user": {
    "id": "user_uuid",
    "address": "0x742d35Cc6634C0532925a3b8D4C9db96C4b4Db45",
    "profile": {
      "username": "johndoe",
      "bio": "Blockchain enthusiast",
      "avatar": "https://ipfs.io/ipfs/Qm...",
      "socialLinks": {
        "twitter": "@johndoe",
        "github": "johndoe"
      }
    }
  }
}
```

#### Logout
```http
POST /auth/logout
Authorization: Bearer jwt_token
```

**Response:**
```json
{
  "message": "Logged out successfully"
}
```

#### Refresh Token
```http
POST /auth/refresh
Authorization: Bearer jwt_token
```

**Response:**
```json
{
  "token": "new_jwt_token",
  "expiresIn": "7d"
}
```

### Users

#### Get Current User
```http
GET /users/me
Authorization: Bearer jwt_token
```

**Response:**
```json
{
  "id": "user_uuid",
  "address": "0x742d35Cc6634C0532925a3b8D4C9db96C4b4Db45",
  "profile": {
    "username": "johndoe",
    "bio": "Blockchain enthusiast",
    "avatar": "https://ipfs.io/ipfs/Qm...",
    "socialLinks": {
      "twitter": "@johndoe",
      "github": "johndoe"
    }
  },
  "statistics": {
    "totalQuests": 15,
    "completedQuests": 12,
    "successRate": 80,
    "totalEarnings": "1250.50",
    "reputationScore": 850
  },
  "createdAt": "2023-12-01T10:00:00.000Z"
}
```

#### Update Profile
```http
PUT /users/me
Authorization: Bearer jwt_token
Content-Type: application/json

{
  "profile": {
    "username": "johndoe",
    "bio": "Blockchain enthusiast and quest creator",
    "avatar": "https://ipfs.io/ipfs/Qm...",
    "socialLinks": {
      "twitter": "@johndoe",
      "github": "johndoe",
      "website": "https://johndoe.com"
    }
  }
}
```

**Response:**
```json
{
  "message": "Profile updated successfully",
  "user": {
    "id": "user_uuid",
    "profile": {
      "username": "johndoe",
      "bio": "Blockchain enthusiast and quest creator",
      "avatar": "https://ipfs.io/ipfs/Qm...",
      "socialLinks": {
        "twitter": "@johndoe",
        "github": "johndoe",
        "website": "https://johndoe.com"
      }
    }
  }
}
```

#### Get User by ID
```http
GET /users/{userId}
```

**Response:**
```json
{
  "id": "user_uuid",
  "address": "0x742d35Cc6634C0532925a3b8D4C9db96C4b4Db45",
  "profile": {
    "username": "johndoe",
    "bio": "Blockchain enthusiast",
    "avatar": "https://ipfs.io/ipfs/Qm...",
    "socialLinks": {
      "twitter": "@johndoe",
      "github": "johndoe"
    }
  },
  "statistics": {
    "totalQuests": 15,
    "completedQuests": 12,
    "successRate": 80,
    "reputationScore": 850
  },
  "achievements": [
    {
      "id": "achievement_uuid",
      "title": "First Quest Completed",
      "description": "Completed your first quest",
      "imageUrl": "https://ipfs.io/ipfs/Qm...",
      "rarity": "common",
      "mintedAt": "2023-12-01T10:00:00.000Z"
    }
  ]
}
```

### Quests

#### List Quests
```http
GET /quests?page=1&limit=20&category=fitness&status=active&sort=newest
```

**Query Parameters:**
- `page` (number): Page number (default: 1)
- `limit` (number): Items per page (default: 20, max: 100)
- `category` (string): Filter by category
- `status` (string): Filter by status (active, completed, expired)
- `sort` (string): Sort order (newest, oldest, popular, endingSoon, rewardHigh)
- `search` (string): Search term
- `creator` (string): Filter by creator address

**Response:**
```json
{
  "quests": [
    {
      "id": "quest_uuid",
      "contractAddress": "0x...",
      "title": "Run 100km in 30 Days",
      "description": "Complete a 100km running challenge within 30 days",
      "category": {
        "id": "category_uuid",
        "name": "Fitness",
        "icon": "🏃"
      },
      "creator": {
        "id": "user_uuid",
        "address": "0x...",
        "username": "fitnessguru"
      },
      "stakeAmount": "100.00",
      "rewardPool": "150.00",
      "participantCount": 25,
      "maxParticipants": 100,
      "status": "active",
      "createdAt": "2023-12-01T10:00:00.000Z",
      "expiresAt": "2023-12-31T23:59:59.000Z",
      "milestones": [
        {
          "id": "milestone_uuid",
          "title": "Complete 25km",
          "description": "Run 25km total",
          "orderIndex": 1,
          "verificationType": "community"
        }
      ]
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 150,
    "totalPages": 8,
    "hasNext": true,
    "hasPrev": false
  }
}
```

#### Get Quest Details
```http
GET /quests/{questId}
```

**Response:**
```json
{
  "id": "quest_uuid",
  "contractAddress": "0x...",
  "title": "Run 100km in 30 Days",
  "description": "Complete a 100km running challenge within 30 days. Track your progress and submit evidence for each milestone.",
  "category": {
    "id": "category_uuid",
    "name": "Fitness",
    "icon": "🏃"
  },
  "creator": {
    "id": "user_uuid",
    "address": "0x...",
    "username": "fitnessguru",
    "reputationScore": 950
  },
  "stakeAmount": "100.00",
  "rewardPool": "150.00",
  "participantCount": 25,
  "maxParticipants": 100,
  "status": "active",
  "createdAt": "2023-12-01T10:00:00.000Z",
  "expiresAt": "2023-12-31T23:59:59.000Z",
  "milestones": [
    {
      "id": "milestone_uuid",
      "title": "Complete 25km",
      "description": "Run 25km total",
      "orderIndex": 1,
      "verificationType": "community",
      "requiredEvidence": ["gps_data", "photo"],
      "evidenceSubmissions": [
        {
          "id": "evidence_uuid",
          "participant": {
            "id": "user_uuid",
            "username": "runner123"
          },
          "evidenceType": "gps_data",
          "ipfsHash": "Qm...",
          "submittedAt": "2023-12-05T15:30:00.000Z",
          "verificationStatus": "pending",
          "verificationVotes": 3,
          "confidenceScore": 85
        }
      ]
    }
  ],
  "participants": [
    {
      "id": "participant_uuid",
      "user": {
        "id": "user_uuid",
        "username": "runner123",
        "avatar": "https://ipfs.io/ipfs/Qm..."
      },
      "stakeAmount": "100.00",
      "status": "active",
      "joinedAt": "2023-12-02T10:00:00.000Z",
      "progress": {
        "completedMilestones": 1,
        "totalMilestones": 4,
        "percentage": 25
      }
    }
  ],
  "tags": ["fitness", "running", "challenge", "30day"],
  "metadata": {
    "difficulty": "medium",
    "estimatedTime": "30 days",
    "requirements": ["running shoes", "fitness tracker"]
  }
}
```

#### Create Quest
```http
POST /quests
Authorization: Bearer jwt_token
Content-Type: application/json

{
  "title": "Learn Solidity Basics",
  "description": "Complete a comprehensive Solidity course and build your first smart contract",
  "categoryId": "category_uuid",
  "stakeAmount": "200.00",
  "rewardPool": "300.00",
  "maxParticipants": 50,
  "duration": 30,
  "milestones": [
    {
      "title": "Complete Course Modules 1-3",
      "description": "Finish the first three course modules",
      "orderIndex": 1,
      "verificationType": "automated",
      "requiredEvidence": ["certificate"]
    },
    {
      "title": "Build Simple Smart Contract",
      "description": "Create and deploy a simple storage contract",
      "orderIndex": 2,
      "verificationType": "community",
      "requiredEvidence": ["code_repository", "deployment_proof"]
    }
  ],
  "tags": ["learning", "blockchain", "solidity", "programming"],
  "metadata": {
    "difficulty": "beginner",
    "estimatedTime": "30 days",
    "requirements": ["basic programming knowledge", "computer with internet"]
  }
}
```

**Response:**
```json
{
  "id": "quest_uuid",
  "contractAddress": "0x...",
  "title": "Learn Solidity Basics",
  "description": "Complete a comprehensive Solidity course and build your first smart contract",
  "status": "pending_deployment",
  "transactionHash": "0x...",
  "estimatedDeploymentTime": "2-3 minutes"
}
```

#### Join Quest
```http
POST /quests/{questId}/join
Authorization: Bearer jwt_token
Content-Type: application/json

{
  "stakeAmount": "100.00"
}
```

**Response:**
```json
{
  "participantId": "participant_uuid",
  "questId": "quest_uuid",
  "status": "joined",
  "transactionHash": "0x...",
  "stakeAmount": "100.00",
  "joinedAt": "2023-12-05T10:00:00.000Z"
}
```

#### Leave Quest
```http
POST /quests/{questId}/leave
Authorization: Bearer jwt_token
```

**Response:**
```json
{
  "message": "Left quest successfully",
  "refundAmount": "95.00",
  "penaltyAmount": "5.00",
  "transactionHash": "0x..."
}
```

### Milestones

#### Get Quest Milestones
```http
GET /quests/{questId}/milestones
```

**Response:**
```json
{
  "milestones": [
    {
      "id": "milestone_uuid",
      "title": "Complete 25km",
      "description": "Run 25km total",
      "orderIndex": 1,
      "verificationType": "community",
      "requiredEvidence": ["gps_data", "photo"],
      "deadline": "2023-12-15T23:59:59.000Z",
      "status": "active",
      "participantProgress": {
        "completed": 15,
        "total": 25,
        "percentage": 60
      }
    }
  ]
}
```

#### Submit Evidence
```http
POST /milestones/{milestoneId}/evidence
Authorization: Bearer jwt_token
Content-Type: multipart/form-data

evidence: [file]
evidenceType: gps_data
description: "Completed 25km run with GPS tracking"
```

**Response:**
```json
{
  "evidenceId": "evidence_uuid",
  "milestoneId": "milestone_uuid",
  "ipfsHash": "Qm...",
  "evidenceType": "gps_data",
  "submittedAt": "2023-12-05T15:30:00.000Z",
  "status": "pending_verification",
  "verificationThreshold": 3,
  "currentVotes": 0
}
```

### Verification

#### Get Pending Verifications
```http
GET /verification/pending?page=1&limit=10&category=fitness
Authorization: Bearer jwt_token
```

**Response:**
```json
{
  "evidence": [
    {
      "id": "evidence_uuid",
      "milestone": {
        "id": "milestone_uuid",
        "title": "Complete 25km",
        "quest": {
          "id": "quest_uuid",
          "title": "Run 100km in 30 Days"
        }
      },
      "participant": {
        "id": "user_uuid",
        "username": "runner123",
        "reputationScore": 750
      },
      "evidenceType": "gps_data",
      "ipfsHash": "Qm...",
      "submittedAt": "2023-12-05T15:30:00.000Z",
      "verificationVotes": 2,
      "verificationThreshold": 3,
      "confidenceScore": 0,
      "status": "pending"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 10,
    "total": 45,
    "totalPages": 5
  }
}
```

#### Cast Verification Vote
```http
POST /verification/{evidenceId}/vote
Authorization: Bearer jwt_token
Content-Type: application/json

{
  "vote": "approve",
  "confidenceScore": 85,
  "reasoning": "GPS data clearly shows 25km completed within valid timeframe",
  "flagged": false
}
```

**Response:**
```json
{
  "voteId": "vote_uuid",
  "evidenceId": "evidence_uuid",
  "vote": "approve",
  "confidenceScore": 85,
  "reasoning": "GPS data clearly shows 25km completed within valid timeframe",
  "voter": {
    "id": "user_uuid",
    "username": "validator123"
  },
  "votedAt": "2023-12-05T16:00:00.000Z",
  "rewardEarned": "2.50",
  "verificationStatus": "approved",
  "currentVotes": 3,
  "thresholdMet": true
}
```

#### Create Dispute
```http
POST /verification/{evidenceId}/dispute
Authorization: Bearer jwt_token
Content-Type: application/json

{
  "reason": "Evidence appears to be fabricated or manipulated",
  "description": "GPS data shows impossible speeds and inconsistent timestamps",
  "evidenceOfManipulation": ["screenshot_1.png", "screenshot_2.png"]
}
```

**Response:**
```json
{
  "disputeId": "dispute_uuid",
  "evidenceId": "evidence_uuid",
  "status": "pending_review",
  "submittedAt": "2023-12-05T16:30:00.000Z",
  "reviewDeadline": "2023-12-07T16:30:00.000Z"
}
```

### Achievements

#### Get User Achievements
```http
GET /achievements?page=1&limit=20&rarity=legendary
Authorization: Bearer jwt_token
```

**Response:**
```json
{
  "achievements": [
    {
      "id": "achievement_uuid",
      "title": "Quest Master",
      "description": "Completed 10 quests successfully",
      "imageUrl": "https://ipfs.io/ipfs/Qm...",
      "rarity": "legendary",
      "tokenId": 1234,
      "contractAddress": "0x...",
      "quest": {
        "id": "quest_uuid",
        "title": "Run 100km in 30 Days"
      },
      "mintedAt": "2023-12-01T10:00:00.000Z",
      "attributes": {
        "completionDate": "2023-12-01",
        "difficulty": "hard",
        "category": "fitness"
      }
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 25,
    "totalPages": 2
  }
}
```

#### Mint Achievement NFT
```http
POST /achievements/mint
Authorization: Bearer jwt_token
Content-Type: application/json

{
  "questId": "quest_uuid",
  "recipient": "0x742d35Cc6634C0532925a3b8D4C9db96C4b4Db45",
  "metadata": {
    "title": "Quest Master",
    "description": "Completed 10 quests successfully",
    "imageUrl": "https://ipfs.io/ipfs/Qm...",
    "attributes": {
      "completionDate": "2023-12-01",
      "difficulty": "hard",
      "category": "fitness"
    }
  }
}
```

**Response:**
```json
{
  "achievementId": "achievement_uuid",
  "tokenId": 1234,
  "transactionHash": "0x...",
  "contractAddress": "0x...",
  "mintedAt": "2023-12-05T17:00:00.000Z",
  "owner": "0x742d35Cc6634C0532925a3b8D4C9db96C4b4Db45"
}
```

### Categories

#### List Categories
```http
GET /categories
```

**Response:**
```json
{
  "categories": [
    {
      "id": "category_uuid",
      "name": "Fitness",
      "description": "Physical fitness challenges and activities",
      "icon": "🏃",
      "questCount": 125,
      "parentCategory": null,
      "subcategories": [
        {
          "id": "subcategory_uuid",
          "name": "Running",
          "description": "Running challenges and marathons",
          "icon": "🏃‍♂️",
          "questCount": 45
        }
      ]
    }
  ]
}
```

### Leaderboard

#### Get Leaderboard
```http
GET /leaderboard?type=reputation&period=monthly&limit=50
```

**Query Parameters:**
- `type` (string): Leaderboard type (reputation, quests, earnings, verification)
- `period` (string): Time period (daily, weekly, monthly, yearly, alltime)
- `limit` (number): Number of entries (default: 50, max: 100)
- `category` (string): Filter by category

**Response:**
```json
{
  "leaderboard": [
    {
      "rank": 1,
      "user": {
        "id": "user_uuid",
        "username": "questmaster",
        "avatar": "https://ipfs.io/ipfs/Qm..."
      },
      "score": 1250,
      "change": "+5",
      "achievements": 25,
      "completedQuests": 18
    }
  ],
  "userRank": {
    "rank": 125,
    "score": 450,
    "change": "+12"
  },
  "period": "monthly",
  "updatedAt": "2023-12-05T18:00:00.000Z"
}
```

### Notifications

#### Get Notifications
```http
GET /notifications?page=1&limit=20&unread=true
Authorization: Bearer jwt_token
```

**Response:**
```json
{
  "notifications": [
    {
      "id": "notification_uuid",
      "type": "verification_complete",
      "title": "Evidence Verified",
      "message": "Your evidence for 'Complete 25km' has been approved",
      "data": {
        "evidenceId": "evidence_uuid",
        "milestoneId": "milestone_uuid",
        "questId": "quest_uuid"
      },
      "read": false,
      "createdAt": "2023-12-05T17:30:00.000Z"
    }
  ],
  "unreadCount": 5,
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 25
  }
}
```

#### Mark Notification as Read
```http
PUT /notifications/{notificationId}/read
Authorization: Bearer jwt_token
```

**Response:**
```json
{
  "message": "Notification marked as read"
}
```

## WebSocket Events

### Connection
```javascript
const socket = io('ws://localhost:8000', {
  auth: {
    token: 'jwt_token'
  }
});
```

### Events

#### Quest Updates
```javascript
// Join quest room
socket.emit('join-quest', { questId: 'quest_uuid' });

// Listen for quest updates
socket.on('quest-updated', (data) => {
  console.log('Quest updated:', data);
  // data: { questId, type, payload }
});
```

#### Verification Updates
```javascript
// Listen for verification updates
socket.on('verification-update', (data) => {
  console.log('Verification update:', data);
  // data: { evidenceId, status, votes, confidenceScore }
});
```

#### Achievement Unlocked
```javascript
// Listen for achievement unlocks
socket.on('achievement-unlocked', (data) => {
  console.log('Achievement unlocked:', data);
  // data: { achievementId, title, rarity, imageUrl }
});
```

#### Real-time Notifications
```javascript
// Listen for notifications
socket.on('notification', (data) => {
  console.log('New notification:', data);
  // data: { id, type, title, message, createdAt }
});
```

## Error Handling

### Error Response Format
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input data",
    "details": [
      {
        "field": "stakeAmount",
        "message": "Stake amount must be greater than 0"
      }
    ]
  },
  "timestamp": "2023-12-05T18:00:00.000Z",
  "path": "/api/v1/quests"
}
```

### Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `VALIDATION_ERROR` | 400 | Invalid input data |
| `UNAUTHORIZED` | 401 | Authentication required |
| `FORBIDDEN` | 403 | Insufficient permissions |
| `NOT_FOUND` | 404 | Resource not found |
| `CONFLICT` | 409 | Resource conflict |
| `RATE_LIMITED` | 429 | Too many requests |
| `INTERNAL_ERROR` | 500 | Internal server error |
| `BLOCKCHAIN_ERROR` | 502 | Blockchain transaction failed |
| `SERVICE_UNAVAILABLE` | 503 | External service unavailable |

### Rate Limiting

API endpoints are rate limited to prevent abuse:

| Endpoint | Limit | Window |
|----------|-------|--------|
| Authentication | 5 requests | 1 minute |
| Quest Creation | 10 requests | 1 hour |
| Evidence Submission | 20 requests | 1 hour |
| Verification Votes | 50 requests | 1 hour |
| General API | 1000 requests | 1 hour |

Rate limit headers are included in responses:
```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1701825600
```

## API Versioning

The API uses URL versioning (`/api/v1/`). Current version is v1. Backward compatibility is maintained for at least one previous version.

### Version Deprecation
- Notification 3 months before deprecation
- Sunset 6 months after deprecation
- Migration guides provided

## SDKs and Libraries

### JavaScript/TypeScript
```bash
npm install @chainquest/api
```

```javascript
import { ChainQuestAPI } from '@chainquest/api';

const api = new ChainQuestAPI({
  baseURL: 'https://api.chainquest.app/api/v1',
  token: 'jwt_token'
});

const quests = await api.quests.list();
const quest = await api.quests.get('quest_uuid');
```

### Python
```bash
pip install chainquest-api
```

```python
from chainquest import ChainQuestAPI

api = ChainQuestAPI(
    base_url='https://api.chainquest.app/api/v1',
    token='jwt_token'
)

quests = api.quests.list()
quest = api.quests.get('quest_uuid')
```

## Testing

### Sandbox Environment
For testing and development, use the sandbox environment:
- **URL**: `https://sandbox-api.chainquest.app/api/v1`
- **Features**: Testnet blockchain, mock data, relaxed rate limits

### Test Data
Use the test endpoints to create mock data:
```http
POST /test/create-quest
POST /test/create-user
POST /test/submit-evidence
```

## Support

### Documentation
- [API Reference](https://docs.chainquest.app/api)
- [SDK Documentation](https://docs.chainquest.app/sdk)
- [Examples](https://github.com/chainquest/examples)

### Community
- [Discord](https://discord.gg/chainquest)
- [GitHub Issues](https://github.com/chainquest/api/issues)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/chainquest)

### Status
- [API Status](https://status.chainquest.app)
- [Incident History](https://status.chainquest.app/incidents)

This API documentation provides comprehensive information for integrating with ChainQuest. For additional support, refer to the community resources or contact the development team.
