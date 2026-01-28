# ChainQuest - Setup Instructions

## Overview

This guide provides comprehensive instructions for setting up the ChainQuest development environment, including all components: smart contracts, backend API, and frontend application.

## Prerequisites

### System Requirements
- **Operating System**: Linux (Ubuntu 20.04+), macOS (10.15+), or Windows 10+ with WSL2
- **RAM**: Minimum 8GB, recommended 16GB
- **Storage**: Minimum 20GB free space
- **Network**: Stable internet connection for blockchain interactions

### Required Software

#### Core Development Tools
```bash
# Node.js (v18+)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Git
sudo apt-get install git

# Docker & Docker Compose
sudo apt-get install docker.io docker-compose
sudo usermod -aG docker $USER

# PostgreSQL Client
sudo apt-get install postgresql-client
```

#### Blockchain Development Tools
```bash
# Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install Foundry binaries
forge install
cast install
anvil install
chisel install
```

#### Browser Extensions
- **MetaMask**: Wallet for blockchain interactions
- **React Developer Tools**: For frontend debugging
- **Redux DevTools**: For state management debugging

## Environment Setup

### 1. Repository Setup

```bash
# Clone the repository
git clone https://github.com/your-org/chainquest.git
cd chainquest

# Install dependencies
npm install

# Setup environment files
cp .env.example .env
cp contracts/.env.example contracts/.env
cp backend/.env.example backend/.env
cp frontend/.env.example frontend/.env
```

### 2. Environment Variables

#### Root `.env`
```bash
# General Configuration
NODE_ENV=development
LOG_LEVEL=debug

# Blockchain Configuration
BASE_RPC_URL=https://sepolia.base.org
BASE_CHAIN_ID=84532
PRIVATE_KEY=your_private_key_here

# IPFS Configuration
IPFS_PROJECT_ID=your_ipfs_project_id
IPFS_PROJECT_SECRET=your_ipfs_project_secret

# Monitoring
SENTRY_DSN=your_sentry_dsn
```

#### Contracts `.env`
```bash
# Foundry Configuration
FOUNDRY_PROFILE=default
RPC_URL=https://sepolia.base.org
PRIVATE_KEY=your_private_key_here
ETHERSCAN_API_KEY=your_etherscan_api_key

# Deployment Configuration
DEPLOYER_PRIVATE_KEY=your_deployer_private_key
VERIFIER_PRIVATE_KEY=your_verifier_private_key

# Test Configuration
TEST_PRIVATE_KEY=your_test_private_key
```

#### Backend `.env`
```bash
# Database Configuration
DATABASE_URL=postgresql://chainquest:password@localhost:5432/chainquest
REDIS_URL=redis://localhost:6379

# JWT Configuration
JWT_SECRET=your_jwt_secret_here
JWT_EXPIRES_IN=7d

# API Configuration
API_PORT=8000
API_HOST=localhost
CORS_ORIGIN=http://localhost:3000

# Blockchain Configuration
BASE_RPC_URL=https://sepolia.base.org
BASE_CHAIN_ID=84532
PRIVATE_KEY=your_private_key_here

# IPFS Configuration
IPFS_PROJECT_ID=your_ipfs_project_id
IPFS_PROJECT_SECRET=your_ipfs_project_secret

# External Services
WEBHOOK_SECRET=your_webhook_secret
EMAIL_SERVICE_API_KEY=your_email_service_key
```

#### Frontend `.env`
```bash
# Next.js Configuration
NEXT_PUBLIC_APP_URL=http://localhost:3000
NEXT_PUBLIC_API_URL=http://localhost:8000

# Wallet Configuration
NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=your_wallet_connect_project_id

# Blockchain Configuration
NEXT_PUBLIC_BASE_CHAIN_ID=84532
NEXT_PUBLIC_BASE_RPC_URL=https://sepolia.base.org

# Analytics
NEXT_PUBLIC_GA_ID=your_google_analytics_id
NEXT_PUBLIC_SENTRY_DSN=your_sentry_dsn
```

## Database Setup

### 1. PostgreSQL Installation

#### Ubuntu/Debian
```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

#### macOS
```bash
brew install postgresql
brew services start postgresql
```

#### Windows
Download and install PostgreSQL from the official website.

### 2. Database Configuration

```bash
# Switch to postgres user
sudo -u postgres psql

# Create database and user
CREATE DATABASE chainquest;
CREATE USER chainquest WITH PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE chainquest TO chainquest;
\q
```

### 3. Database Migration

```bash
cd backend

# Install dependencies
npm install

# Run database migrations
npx prisma migrate dev

# Generate Prisma client
npx prisma generate

# Seed database (optional)
npx prisma db seed
```

## Smart Contracts Setup

### 1. Foundry Project Setup

```bash
cd contracts

# Initialize Foundry project (if not already done)
forge init --force

# Install dependencies
forge install OpenZeppelin/openzeppelin-contracts --no-commit
forge install smartcontractkit/chainlink --no-commit

# Compile contracts
forge build

# Run tests
forge test
```

### 2. Local Blockchain Setup

```bash
# Start local Anvil node
anvil --host 0.0.0.0 --port 8545

# In another terminal, deploy contracts
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# Verify contracts (if on testnet)
forge verify-contract <contract_address> <contract_name> --chain-id 84532 --etherscan-api-key $ETHERSCAN_API_KEY
```

### 3. Contract Deployment

#### Local Deployment
```bash
# Deploy to local Anvil
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# Save deployment addresses
cp deployments/localhost.json .deployments/local.json
```

#### Testnet Deployment
```bash
# Deploy to Base Sepolia
forge script script/Deploy.s.sol --rpc-url https://sepolia.base.org --broadcast --verify

# Save deployment addresses
cp deployments/base-sepolia.json .deployments/testnet.json
```

## Backend Setup

### 1. Installation and Configuration

```bash
cd backend

# Install dependencies
npm install

# Generate Prisma client
npx prisma generate

# Run database migrations
npx prisma migrate dev

# Create environment file
cp .env.example .env
# Edit .env with your configuration

# Start development server
npm run dev
```

### 2. Redis Setup

#### Ubuntu/Debian
```bash
sudo apt install redis-server
sudo systemctl start redis-server
sudo systemctl enable redis-server
```

#### macOS
```bash
brew install redis
brew services start redis
```

#### Docker
```bash
docker run -d -p 6379:6379 --name redis redis:7-alpine
```

### 3. API Testing

```bash
# Install testing tools
npm install -g @prisma/cli

# Test API endpoints
curl http://localhost:8000/api/v1/health
curl http://localhost:8000/api/v1/quests
```

## Frontend Setup

### 1. Installation and Configuration

```bash
cd frontend

# Install dependencies
npm install

# Create environment file
cp .env.example .env
# Edit .env with your configuration

# Start development server
npm run dev
```

### 2. Tailwind CSS Setup

```bash
# Tailwind is already configured, but if needed:
npx tailwindcss init -p

# Build CSS
npm run build:css
```

### 3. shadcn/ui Components

```bash
# Initialize shadcn/ui (if not already done)
npx shadcn-ui@latest init

# Add components as needed
npx shadcn-ui@latest add button
npx shadcn-ui@latest add card
npx shadcn-ui@latest add form
npx shadcn-ui@latest add input
npx shadcn-ui@latest add dialog
```

## Development Workflow

### 1. Starting the Development Environment

#### Option 1: Individual Services
```bash
# Terminal 1: Start local blockchain
cd contracts && anvil --host 0.0.0.0 --port 8545

# Terminal 2: Deploy contracts
cd contracts && forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# Terminal 3: Start backend
cd backend && npm run dev

# Terminal 4: Start frontend
cd frontend && npm run dev
```

#### Option 2: Docker Compose
```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

### 2. Common Development Tasks

#### Running Tests
```bash
# Smart contract tests
cd contracts && forge test

# Backend tests
cd backend && npm test

# Frontend tests
cd frontend && npm test

# E2E tests
npm run test:e2e
```

#### Code Quality
```bash
# Linting
npm run lint

# Formatting
npm run format

# Type checking
npm run type-check
```

#### Database Operations
```bash
# Create new migration
npx prisma migrate dev --name migration_name

# Reset database
npx prisma migrate reset

# View database
npx prisma studio
```

## Testing Setup

### 1. Smart Contract Testing

#### Unit Tests
```bash
# Run all tests
forge test

# Run specific test
forge test --match-test testCreateQuest

# Run tests with gas reporting
forge test --gas-report

# Run tests with coverage
forge coverage
```

#### Integration Tests
```bash
# Run integration tests
forge script script/IntegrationTest.s.sol --rpc-url http://localhost:8545 --broadcast
```

### 2. Backend Testing

#### Unit Tests
```bash
cd backend

# Run all tests
npm test

# Run specific test file
npm test -- auth.test.ts

# Run tests with coverage
npm run test:coverage
```

#### Integration Tests
```bash
# Run integration tests
npm run test:integration

# Run API tests
npm run test:api
```

### 3. Frontend Testing

#### Unit Tests
```bash
cd frontend

# Run all tests
npm test

# Run tests with coverage
npm run test:coverage
```

#### E2E Tests
```bash
# Install Playwright
npm install -g @playwright/test

# Run E2E tests
npx playwright test

# Run specific test
npx playwright test quest-creation.spec.ts
```

## Production Setup

### 1. Environment Preparation

#### Production Environment Variables
```bash
# Production .env
NODE_ENV=production
LOG_LEVEL=info

# Use production URLs
BASE_RPC_URL=https://mainnet.base.org
DATABASE_URL=postgresql://user:pass@prod-db:5432/chainquest
REDIS_URL=redis://prod-redis:6379

# Security
JWT_SECRET=your_production_jwt_secret
CORS_ORIGIN=https://chainquest.app
```

### 2. Database Setup

#### Production Database
```bash
# Create production database
createdb -U postgres chainquest_prod

# Run migrations
npx prisma migrate deploy

# Seed production data (if needed)
npx prisma db seed --preview-feature
```

### 3. Smart Contract Deployment

#### Mainnet Deployment
```bash
# Deploy to Base Mainnet
forge script script/Deploy.s.sol --rpc-url https://mainnet.base.org --broadcast --verify

# Update frontend with contract addresses
cp deployments/base-mainnet.json ../frontend/.deployments/mainnet.json
```

### 4. Application Deployment

#### Backend Deployment
```bash
# Build backend
cd backend
npm run build

# Start production server
npm start
```

#### Frontend Deployment
```bash
# Build frontend
cd frontend
npm run build

# Deploy to Vercel/Netlify
vercel --prod
# or
netlify deploy --prod
```

## Monitoring and Maintenance

### 1. Health Checks

#### Backend Health
```bash
# Check API health
curl https://api.chainquest.app/api/v1/health

# Check database connection
curl https://api.chainquest.app/api/v1/health/db
```

#### Blockchain Health
```bash
# Check blockchain connection
cast block-number --rpc-url https://mainnet.base.org

# Check contract deployment
cast code <contract_address> --rpc-url https://mainnet.base.org
```

### 2. Logging

#### Application Logs
```bash
# View application logs
docker-compose logs -f backend
docker-compose logs -f frontend

# View blockchain logs
cast logs <contract_address> --rpc-url https://mainnet.base.org
```

### 3. Backup Procedures

#### Database Backup
```bash
# Create database backup
pg_dump -U postgres chainquest_prod > backup_$(date +%Y%m%d).sql

# Restore database
psql -U postgres chainquest_prod < backup_20231201.sql
```

#### Configuration Backup
```bash
# Backup environment files
tar -czf config_backup_$(date +%Y%m%d).tar.gz .env* deployments/
```

## Troubleshooting

### Common Issues

#### 1. Blockchain Connection Issues
```bash
# Check RPC URL
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  https://sepolia.base.org

# Check private key format
echo $PRIVATE_KEY | wc -c  # Should be 64 characters (without 0x)
```

#### 2. Database Connection Issues
```bash
# Test database connection
psql $DATABASE_URL -c "SELECT 1;"

# Check PostgreSQL status
sudo systemctl status postgresql
```

#### 3. Frontend Build Issues
```bash
# Clear Next.js cache
rm -rf .next

# Reinstall dependencies
rm -rf node_modules package-lock.json
npm install
```

#### 4. Smart Contract Compilation Issues
```bash
# Clear Foundry cache
forge clean

# Update dependencies
forge update

# Check Solidity version
forge --version
```

### Performance Issues

#### 1. Slow API Response
```bash
# Check database queries
npx prisma studio

# Analyze slow queries
psql $DATABASE_URL -c "SELECT query, mean_time, calls FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;"
```

#### 2. High Gas Costs
```bash
# Estimate gas costs
forge test --gas-report

# Optimize contracts
forge snapshot
```

## Security Considerations

### 1. Private Key Management
- Never commit private keys to version control
- Use hardware wallets for production deployments
- Rotate keys regularly
- Use key management services for production

### 2. Environment Security
- Use strong, unique secrets
- Enable 2FA on all accounts
- Regular security audits
- Monitor for suspicious activity

### 3. Smart Contract Security
- Follow OpenZeppelin guidelines
- Use established audit firms
- Implement emergency controls
- Test thoroughly on testnets

## Support and Resources

### Documentation
- [Smart Contracts Documentation](SMART_CONTRACTS.md)
- [API Documentation](API.md)
- [Architecture Overview](ARCHITECTURE.md)

### Community
- Discord: [ChainQuest Discord](https://discord.gg/chainquest)
- GitHub: [ChainQuest Repository](https://github.com/your-org/chainquest)
- Twitter: [@ChainQuestApp](https://twitter.com/ChainQuestApp)

### Tools and Resources
- [Foundry Book](https://book.getfoundry.sh/)
- [Next.js Documentation](https://nextjs.org/docs)
- [Prisma Documentation](https://www.prisma.io/docs)
- [Base Network Documentation](https://docs.base.org/)

This setup guide provides everything needed to get ChainQuest running in development and production environments. Follow the steps in order and refer to the troubleshooting section if you encounter any issues.
