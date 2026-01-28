# ChainQuest - Deployment Guide

## Overview

This guide provides comprehensive instructions for deploying ChainQuest across different environments, from local development to production mainnet deployment.

## Deployment Environments

### 1. Local Development
- **Blockchain**: Local Anvil node
- **Database**: Local PostgreSQL
- **Backend**: Local Node.js server
- **Frontend**: Local Next.js development server

### 2. Staging Environment
- **Blockchain**: Base Sepolia testnet
- **Database**: Cloud PostgreSQL (AWS RDS)
- **Backend**: Cloud server (AWS EC2)
- **Frontend**: Vercel preview deployment

### 3. Production Environment
- **Blockchain**: Base mainnet
- **Database**: Cloud PostgreSQL with replication
- **Backend**: Load-balanced cloud servers
- **Frontend**: CDN-backed static site (Vercel/Netlify)

## Prerequisites

### Infrastructure Requirements

#### Development
- Docker & Docker Compose
- Node.js 18+
- PostgreSQL 15+
- Redis 7+
- Foundry

#### Staging/Production
- Cloud provider account (AWS/GCP/Azure)
- Domain name
- SSL certificates
- Monitoring tools
- Backup solutions

### Security Requirements
- Hardware wallet for mainnet deployments
- Multi-signature wallets for critical operations
- Secure key management (AWS KMS, HashiCorp Vault)
- VPN access to infrastructure
- Security audit clearance

## Environment Configuration

### Environment Variables Matrix

| Variable | Development | Staging | Production |
|----------|-------------|---------|------------|
| `NODE_ENV` | development | staging | production |
| `BASE_RPC_URL` | http://localhost:8545 | https://sepolia.base.org | https://mainnet.base.org |
| `BASE_CHAIN_ID` | 31337 | 84532 | 8453 |
| `DATABASE_URL` | postgresql://localhost/chainquest_dev | postgresql://staging-db/chainquest_staging | postgresql://prod-db/chainquest_prod |
| `REDIS_URL` | redis://localhost:6379 | redis://staging-redis:6379 | redis://prod-redis:6379 |
| `JWT_SECRET` | dev_secret | staging_secret | production_secret |
| `IPFS_PROJECT_ID` | dev_project_id | staging_project_id | production_project_id |
| `PRIVATE_KEY` | dev_private_key | staging_private_key | mainnet_private_key |

## Smart Contract Deployment

### 1. Local Development Deployment

#### Setup Local Blockchain
```bash
# Start local Anvil node
anvil --host 0.0.0.0 --port 8545 --accounts 20

# In another terminal, deploy contracts
cd contracts

# Set environment variables
export RPC_URL=http://localhost:8545
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Deploy contracts
forge script script/Deploy.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

# Save deployment addresses
forge script script/SaveDeployments.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

#### Verify Deployment
```bash
# Check contract deployment
cast code <quest_factory_address> --rpc-url $RPC_URL

# Test contract functionality
cast call <quest_factory_address> "nextQuestId()" --rpc-url $RPC_URL
```

### 2. Testnet Deployment (Base Sepolia)

#### Preparation
```bash
# Ensure you have testnet ETH
curl https://sepolia.base.org \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_getBalance","params":["0xYourAddress","latest"],"id":1}'

# Fund account if needed (use faucet)
# https://sepoliafaucet.base.org/
```

#### Deployment Script
```bash
cd contracts

# Set testnet environment
export RPC_URL=https://sepolia.base.org
export CHAIN_ID=84532
export ETHERSCAN_API_KEY=your_etherscan_api_key
export PRIVATE_KEY=your_testnet_private_key

# Deploy contracts
forge script script/Deploy.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --chain-id $CHAIN_ID \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY

# Run post-deployment verification
forge script script/VerifyDeployment.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

#### Contract Verification
```bash
# Verify individual contracts
forge verify-contract <contract_address> <contract_name> \
  --chain-id 84532 \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --watch

# Check verification status
cast code <contract_address> --rpc-url $RPC_URL
```

### 3. Mainnet Deployment (Base)

#### Security Checklist
- [ ] Code audited by reputable firm
- [ ] Test coverage > 90%
- [ ] Security review completed
- [ ] Emergency procedures documented
- [ ] Multi-sig wallet configured
- [ ] Team training completed

#### Deployment Preparation
```bash
# Create deployment plan
cat > deployment_plan.md << EOF
# Mainnet Deployment Plan
## Date: $(date)
## Team: Core Team
## Phase: Initial Deployment

### Pre-deployment Checks
- [ ] Final audit report received
- [ ] Testnet deployment verified
- [ ] Funding secured for deployment
- [ ] Monitoring systems ready

### Deployment Steps
1. Deploy QuestFactory
2. Deploy RewardPool
3. Deploy VerificationOracle
4. Deploy AchievementNFT
5. Deploy GovernanceToken
6. Configure contracts
7. Run integration tests
8. Enable public access

### Rollback Plan
- Pause contracts
- Notify users
- Investigate issues
- Deploy fixes if needed
EOF
```

#### Multi-sig Deployment
```bash
# Use Gnosis Safe for deployment
# 1. Create transaction in Safe UI
# 2. Get required confirmations
# 3. Execute transaction

# Or use CLI tools
safe-cli propose-transaction \
  --to <factory_address> \
  --data <deployment_calldata> \
  --value 0 \
  --safe-address <safe_address>
```

#### Mainnet Deployment
```bash
cd contracts

# Set mainnet environment
export RPC_URL=https://mainnet.base.org
export CHAIN_ID=8453
export ETHERSCAN_API_KEY=your_etherscan_api_key
export PRIVATE_KEY=your_mainnet_private_key # Use hardware wallet

# Deploy with additional safety checks
forge script script/Deploy.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --chain-id $CHAIN_ID \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --slow

# Post-deployment verification
forge script script/ProductionVerify.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

#### Contract Configuration
```bash
# Configure contract parameters
forge script script/ConfigureContracts.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast

# Set up initial roles and permissions
forge script script/SetupRoles.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

## Backend Deployment

### 1. Local Development

#### Docker Setup
```bash
# Create docker-compose.yml
cat > docker-compose.dev.yml << EOF
version: '3.8'
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: chainquest_dev
      POSTGRES_USER: chainquest
      POSTGRES_PASSWORD: dev_password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  backend:
    build: ./backend
    ports:
      - "8000:8000"
    environment:
      - NODE_ENV=development
      - DATABASE_URL=postgresql://chainquest:dev_password@postgres:5432/chainquest_dev
      - REDIS_URL=redis://redis:6379
    depends_on:
      - postgres
      - redis
    volumes:
      - ./backend:/app

volumes:
  postgres_data:
EOF

# Start services
docker-compose -f docker-compose.dev.yml up -d

# Run database migrations
docker-compose -f docker-compose.dev.yml exec backend npx prisma migrate dev

# Seed development data
docker-compose -f docker-compose.dev.yml exec backend npx prisma db seed
```

### 2. Staging Deployment

#### AWS EC2 Setup
```bash
# Create EC2 instance
aws ec2 run-instances \
  --image-id ami-0c02fb55956c7d316 \
  --instance-type t3.medium \
  --key-name chainquest-staging \
  --security-group-ids sg-xxxxxxxxx \
  --subnet-id subnet-xxxxxxxxx \
  --user-data file://user-data.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=chainquest-staging}]'

# User data script (user-data.sh)
#!/bin/bash
yum update -y
yum install -y docker
systemctl start docker
systemctl enable docker

# Pull and run application
docker pull chainquest/backend:staging
docker run -d \
  --name chainquest-backend \
  -p 80:8000 \
  -e NODE_ENV=staging \
  -e DATABASE_URL=$DATABASE_URL \
  -e REDIS_URL=$REDIS_URL \
  chainquest/backend:staging
```

#### Database Setup
```bash
# Create RDS PostgreSQL instance
aws rds create-db-instance \
  --db-instance-identifier chainquest-staging \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --master-username chainquest \
  --master-user-password $DB_PASSWORD \
  --allocated-storage 20 \
  --vpc-security-group-ids sg-xxxxxxxxx \
  --db-subnet-group-name default

# Wait for instance to be available
aws rds wait db-instance-available \
  --db-instance-identifier chainquest-staging

# Get connection endpoint
DB_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier chainquest-staging \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

# Run migrations
psql $DATABASE_URL -f migrations.sql
```

#### Application Deployment
```bash
# Build and push Docker image
cd backend
docker build -t chainquest/backend:staging .
docker push chainquest/backend:staging

# Deploy to EC2
ssh -i chainquest-staging.pem ec2-user@<instance-ip> << EOF
  docker pull chainquest/backend:staging
  docker stop chainquest-backend
  docker rm chainquest-backend
  docker run -d \
    --name chainquest-backend \
    -p 80:8000 \
    --env-file .env.staging \
    chainquest/backend:staging
EOF
```

### 3. Production Deployment

#### Load Balancer Setup
```bash
# Create Application Load Balancer
aws elbv2 create-load-balancer \
  --name chainquest-prod-alb \
  --subnets subnet-xxxxxxxxx subnet-yyyyyyyyy \
  --security-groups sg-xxxxxxxxx \
  --scheme internet-facing \
  --type application

# Create target group
aws elbv2 create-target-group \
  --name chainquest-prod-tg \
  --protocol HTTP \
  --port 8000 \
  --vpc-id vpc-xxxxxxxxx \
  --health-check-path /api/v1/health \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3

# Register instances
aws elbv2 register-targets \
  --target-group-arn arn:aws:elasticloadbalancing:...:targetgroup/chainquest-prod-tg/xxxxxxxxx \
  --targets Id=i-xxxxxxxxx Id=i-yyyyyyyyy
```

#### Auto Scaling Group
```bash
# Create launch template
aws ec2 create-launch-template \
  --launch-template-name chainquest-prod \
  --launch-template-data file://launch-template.json

# Create auto scaling group
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name chainquest-prod-asg \
  --launch-template-name chainquest-prod \
  --min-size 2 \
  --max-size 10 \
  --desired-capacity 3 \
  --vpc-zone-identifier subnet-xxxxxxxxx,subnet-yyyyyyyyy \
  --target-group-arns arn:aws:elasticloadbalancing:...:targetgroup/chainquest-prod-tg/xxxxxxxxx

# Set up scaling policies
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name chainquest-prod-asg \
  --policy-name scale-out \
  --policy-type TargetTrackingScaling \
  --target-tracking-configurations file://scale-out-config.json
```

#### Database Replication
```bash
# Create read replica
aws rds create-db-instance-read-replica \
  --db-instance-identifier chainquest-prod-replica \
  --source-db-instance-identifier chainquest-prod \
  --db-instance-class db.t3.micro

# Configure application to use read replicas
# Update DATABASE_URL in production environment
```

## Frontend Deployment

### 1. Local Development
```bash
cd frontend

# Install dependencies
npm install

# Start development server
npm run dev

# Access at http://localhost:3000
```

### 2. Staging Deployment (Vercel)

#### Vercel Setup
```bash
# Install Vercel CLI
npm install -g vercel

# Login to Vercel
vercel login

# Configure project
cd frontend
vercel link

# Set environment variables
vercel env add NEXT_PUBLIC_API_URL staging
vercel env add NEXT_PUBLIC_BASE_CHAIN_ID staging
vercel env add NEXT_PUBLIC_BASE_RPC_URL staging

# Deploy to preview
vercel --env staging
```

#### Configuration Files
```json
// vercel.json
{
  "version": 2,
  "builds": [
    {
      "src": "package.json",
      "use": "@vercel/next"
    }
  ],
  "routes": [
    {
      "src": "/(.*)",
      "dest": "/$1"
    }
  ],
  "env": {
    "NEXT_PUBLIC_API_URL": "https://staging-api.chainquest.app/api/v1"
  }
}
```

### 3. Production Deployment

#### Vercel Production
```bash
# Deploy to production
vercel --prod

# Set production environment variables
vercel env add NEXT_PUBLIC_API_URL production
vercel env add NEXT_PUBLIC_BASE_CHAIN_ID production
vercel env add NEXT_PUBLIC_BASE_RPC_URL production

# Configure custom domain
vercel domains add chainquest.app
```

#### CDN Configuration
```bash
# Configure Cloudflare (if using)
# 1. Add domain to Cloudflare
# 2. Configure DNS records
# 3. Set up page rules for caching
# 4. Configure SSL/TLS

# Example page rules
# chainquest.app/api/* - Cache Level: Bypass
# chainquest.app/* - Cache Level: Everything, Edge TTL: 1 day
```

## Infrastructure as Code

### Terraform Configuration

#### Provider Setup
```hcl
# provider.tf
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}
```

#### VPC Configuration
```hcl
# vpc.tf
resource "aws_vpc" "chainquest" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "chainquest-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.chainquest.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-west-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "chainquest-public-subnet"
  }
}

resource "aws_internet_gateway" "chainquest" {
  vpc_id = aws_vpc.chainquest.id

  tags = {
    Name = "chainquest-igw"
  }
}
```

#### Security Groups
```hcl
# security.tf
resource "aws_security_group" "chainquest_backend" {
  name        = "chainquest-backend"
  description = "Security group for backend servers"
  vpc_id      = aws_vpc.chainquest.id

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "chainquest-backend"
  }
}
```

#### RDS Configuration
```hcl
# rds.tf
resource "aws_db_instance" "chainquest" {
  identifier     = "chainquest-prod"
  engine         = "postgres"
  engine_version = "15.3"
  instance_class = "db.t3.micro"
  
  allocated_storage     = 100
  max_allocated_storage = 1000
  storage_encrypted     = true
  
  db_name  = "chainquest"
  username = "chainquest"
  password = random_password.db_password.result
  
  vpc_security_group_ids = [aws_security_group.chainquest_rds.id]
  db_subnet_group_name   = aws_db_subnet_group.chainquest.name
  
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  skip_final_snapshot = false
  final_snapshot_identifier = "chainquest-final-snapshot"
  
  tags = {
    Name = "chainquest-prod"
  }
}

resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()"
}
```

## Monitoring and Logging

### 1. Application Monitoring

#### Prometheus Setup
```yaml
# prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'chainquest-backend'
    static_configs:
      - targets: ['localhost:8000']
    metrics_path: '/metrics'
    scrape_interval: 5s

  - job_name: 'chainquest-frontend'
    static_configs:
      - targets: ['localhost:3000']
    metrics_path: '/api/metrics'
```

#### Grafana Dashboards
```json
{
  "dashboard": {
    "title": "ChainQuest Production Dashboard",
    "panels": [
      {
        "title": "API Response Time",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))"
          }
        ]
      },
      {
        "title": "Active Users",
        "type": "stat",
        "targets": [
          {
            "expr": "active_users_total"
          }
        ]
      }
    ]
  }
}
```

### 2. Error Tracking

#### Sentry Configuration
```javascript
// backend/src/config/sentry.ts
import * as Sentry from '@sentry/node';

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  tracesSampleRate: 0.1,
});

export default Sentry;
```

### 3. Log Management

#### ELK Stack Setup
```yaml
# docker-compose.logging.yml
version: '3.8'
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.5.0
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    ports:
      - "9200:9200"

  logstash:
    image: docker.elastic.co/logstash/logstash:8.5.0
    ports:
      - "5044:5044"
    volumes:
      - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf

  kibana:
    image: docker.elastic.co/kibana/kibana:8.5.0
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
```

## CI/CD Pipeline

### GitHub Actions Workflow

#### Main Workflow
```yaml
# .github/workflows/deploy.yml
name: Deploy ChainQuest

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run tests
        run: npm test
      
      - name: Run contract tests
        run: |
          cd contracts
          forge test --gas-report

  deploy-staging:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v3
      
      - name: Deploy to staging
        run: ./deploy.sh staging

  deploy-production:
    needs: deploy-staging
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v3
      
      - name: Deploy to production
        run: ./deploy.sh production
```

#### Deployment Script
```bash
#!/bin/bash
# deploy.sh

set -e

ENVIRONMENT=$1
REGION="us-west-2"

echo "Deploying to $ENVIRONMENT..."

# Deploy smart contracts
if [ "$ENVIRONMENT" = "production" ]; then
  echo "Deploying contracts to mainnet..."
  cd contracts
  forge script script/Deploy.s.sol \
    --rpc-url $MAINNET_RPC_URL \
    --private-key $DEPLOYER_PRIVATE_KEY \
    --broadcast \
    --verify
else
  echo "Deploying contracts to testnet..."
  cd contracts
  forge script script/Deploy.s.sol \
    --rpc-url $TESTNET_RPC_URL \
    --private-key $DEPLOYER_PRIVATE_KEY \
    --broadcast \
    --verify
fi

# Deploy backend
echo "Deploying backend..."
cd ../backend
docker build -t chainquest/backend:$ENVIRONMENT .
docker push chainquest/backend:$ENVIRONMENT

# Update infrastructure
cd ../infrastructure
terraform apply -auto-approve -var-file="$ENVIRONMENT.tfvars"

# Deploy frontend
echo "Deploying frontend..."
cd ../frontend
if [ "$ENVIRONMENT" = "production" ]; then
  vercel --prod
else
  vercel --env $ENVIRONMENT
fi

echo "Deployment to $ENVIRONMENT completed!"
```

## Backup and Recovery

### Database Backup
```bash
#!/bin/bash
# backup.sh

BACKUP_DIR="/backups/chainquest"
DATE=$(date +%Y%m%d_%H%M%S)
DB_NAME="chainquest_prod"

# Create backup directory
mkdir -p $BACKUP_DIR

# Create database backup
pg_dump -h $DB_HOST -U $DB_USER -d $DB_NAME > $BACKUP_DIR/backup_$DATE.sql

# Compress backup
gzip $BACKUP_DIR/backup_$DATE.sql

# Upload to S3
aws s3 cp $BACKUP_DIR/backup_$DATE.sql.gz s3://chainquest-backups/

# Clean up old backups (keep last 30 days)
find $BACKUP_DIR -name "backup_*.sql.gz" -mtime +30 -delete

echo "Backup completed: backup_$DATE.sql.gz"
```

### Recovery Procedures
```bash
#!/bin/bash
# recovery.sh

BACKUP_FILE=$1
DB_NAME="chainquest_prod"

if [ -z "$BACKUP_FILE" ]; then
  echo "Usage: $0 <backup_file>"
  exit 1
fi

# Download backup from S3
aws s3 cp s3://chainquest-backups/$BACKUP_FILE ./

# Decompress backup
gunzip $BACKUP_FILE

# Restore database
psql -h $DB_HOST -U $DB_USER -d $DB_NAME < ${BACKUP_FILE%.gz}

echo "Recovery completed from $BACKUP_FILE"
```

## Security Hardening

### 1. Network Security
```bash
# Configure security groups
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxxxxxx \
  --protocol tcp \
  --port 8000 \
  --cidr 0.0.0.0/0

# Configure WAF
aws wafv2 create-web-acl \
  --name chainquest-waf \
  --scope CLOUDFRONT \
  --default-action Allow={} \
  --rules file://waf-rules.json
```

### 2. Access Control
```bash
# Create IAM roles
aws iam create-role \
  --role-name chainquest-deployer \
  --assume-role-policy-document file://trust-policy.json

# Attach policies
aws iam attach-role-policy \
  --role-name chainquest-deployer \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess
```

### 3. Key Management
```bash
# Create KMS key
aws kms create-key \
  --description "ChainQuest encryption key" \
  --key-usage ENCRYPT_DECRYPT

# Create alias
aws kms create-alias \
  --alias-name alias/chainquest \
  --target-key-id <key-id>
```

## Performance Optimization

### 1. Database Optimization
```sql
-- Create indexes
CREATE INDEX CONCURRENTLY idx_quests_creator_status 
ON quests(creator_id, status);

CREATE INDEX CONCURRENTLY idx_participants_user_quest 
ON quest_participants(user_id, quest_id);

-- Analyze query performance
EXPLAIN ANALYZE SELECT * FROM quests 
WHERE status = 'active' 
ORDER BY created_at DESC 
LIMIT 20;
```

### 2. Caching Strategy
```javascript
// Redis caching configuration
const redis = require('redis');
const client = redis.createClient({
  url: process.env.REDIS_URL,
  retry_strategy: (options) => {
    if (options.error && options.error.code === 'ECONNREFUSED') {
      return new Error('Redis server refused connection');
    }
    if (options.total_retry_time > 1000 * 60 * 60) {
      return new Error('Retry time exhausted');
    }
    if (options.attempt > 10) {
      return undefined;
    }
    return Math.min(options.attempt * 100, 3000);
  }
});
```

### 3. CDN Configuration
```javascript
// Next.js static optimization
module.exports = {
  output: 'standalone',
  images: {
    domains: ['chainquest.app'],
    loader: 'custom',
    loaderFile: './image-loader.js'
  },
  compress: true,
  poweredByHeader: false
};
```

## Troubleshooting

### Common Issues

#### 1. Contract Deployment Failures
```bash
# Check gas price
cast gas-price --rpc-url $RPC_URL

# Check account balance
cast balance $DEPLOYER_ADDRESS --rpc-url $RPC_URL

# Check contract verification
forge verify-contract <address> <name> --chain-id $CHAIN_ID
```

#### 2. Database Connection Issues
```bash
# Test database connection
psql $DATABASE_URL -c "SELECT 1;"

# Check PostgreSQL logs
sudo tail -f /var/log/postgresql/postgresql-15-main.log

# Restart database service
sudo systemctl restart postgresql
```

#### 3. Application Performance
```bash
# Check application logs
docker logs chainquest-backend

# Monitor resource usage
docker stats chainquest-backend

# Check network connectivity
curl -I https://api.chainquest.app/api/v1/health
```

This deployment guide provides comprehensive instructions for deploying ChainQuest across all environments. Follow the security best practices and monitoring recommendations to ensure a stable and secure production deployment.
