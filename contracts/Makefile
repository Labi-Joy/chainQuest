.PHONY: help build test coverage deploy-verify deploy-local deploy-testnet deploy-mainnet clean

# Default target
help:
	@echo "Available commands:"
	@echo "  build          - Build all contracts"
	@echo "  test           - Run all tests"
	@echo "  coverage       - Run tests with coverage report"
	@echo "  deploy-local   - Deploy to local Anvil node"
	@echo "  deploy-testnet - Deploy to Base Sepolia testnet"
	@echo "  deploy-mainnet - Deploy to Base mainnet"
	@echo "  clean          - Clean build artifacts"

# Build contracts
build:
	@echo "Building contracts..."
	forge build
	@echo "Build complete!"

# Run tests
test:
	@echo "Running tests..."
	forge test -vv
	@echo "Tests complete!"

# Run tests with coverage
coverage:
	@echo "Running tests with coverage..."
	forge coverage --report lcov
	@echo "Coverage report generated!"

# Deploy to local Anvil node
deploy-local:
	@echo "Deploying to local Anvil..."
	anvil --host 0.0.0.0 --port 8545 --accounts 20 &
	sleep 2
	forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
	@echo "Local deployment complete!"

# Deploy to Base Sepolia testnet
deploy-testnet:
	@echo "Deploying to Base Sepolia..."
	forge script script/DeployTestnet.s.sol --rpc-url $(BASE_RPC_URL) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY)
	@echo "Testnet deployment complete!"

# Deploy to Base mainnet
deploy-mainnet:
	@echo "Deploying to Base mainnet..."
	forge script script/DeployMainnet.s.sol --rpc-url $(BASE_MAINNET_RPC_URL) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY)
	@echo "Mainnet deployment complete!"

# Verify deployment
verify:
	@echo "Verifying deployment..."
	forge script script/Deploy.s.sol --rpc-url $(BASE_RPC_URL) --slow

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	forge clean
	rm -rf broadcast cache out
	@echo "Clean complete!"

# Install dependencies
install:
	@echo "Installing dependencies..."
	forge install OpenZeppelin/openzeppelin-contracts --no-commit
	forge install smartcontractkit/chainlink-brownie-contracts --no-commit
	@echo "Dependencies installed!"

# Snapshot gas usage
snapshot:
	@echo "Creating gas snapshot..."
	forge snapshot
	@echo "Gas snapshot complete!"

# Format code
fmt:
	@echo "Formatting code..."
	forge fmt
	@echo "Code formatted!"

# Check code style
check:
	@echo "Checking code style..."
	forge fmt --check
	@echo "Style check complete!"

# Lint code
lint:
	@echo "Linting code..."
	forge --no-test test
	@echo "Lint complete!"

# Generate documentation
docs:
	@echo "Generating documentation..."
	forge doc --out docs
	@echo "Documentation generated!"

# Run specific test file
test-file:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make test-file FILE=test/Contract.t.sol"; \
		exit 1; \
	fi
	@echo "Running tests for $(FILE)..."
	forge test --match-path $(FILE) -vv

# Run specific test function
test-func:
	@if [ -z "$(FUNC)" ]; then \
		echo "Usage: make test-func FUNC=testFunction"; \
		exit 1; \
	fi
	@echo "Running test function $(FUNC)..."
	forge test --match-test $(FUNC) -vv

# Gas profile specific test
gas-profile:
	@if [ -z "$(FUNC)" ]; then \
		echo "Usage: make gas-profile FUNC=testFunction"; \
		exit 1; \
	fi
	@echo "Profiling gas for $(FUNC)..."
	forge test --match-test $(FUNC) --gas-report

# Start local blockchain
local-chain:
	@echo "Starting local Anvil chain..."
	anvil --host 0.0.0.0 --port 8545 --accounts 20 --block-time 2

# Deploy with specific private key
deploy-key:
	@if [ -z "$(KEY)" ]; then \
		echo "Usage: make deploy-key KEY=0x..."; \
		exit 1; \
	fi
	@echo "Deploying with private key..."
	PRIVATE_KEY=$(KEY) forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# Run integration tests
integration:
	@echo "Running integration tests..."
	forge test --match-test Integration -vv

# Run unit tests only
unit:
	@echo "Running unit tests..."
	forge test --no-match-contract Integration -vv

# Check for vulnerabilities
audit:
	@echo "Running security audit..."
	slither . --filter medium,high
	@echo "Audit complete!"

# Setup development environment
setup:
	@echo "Setting up development environment..."
	npm install -g foundryup
	foundryup
	make install
	@echo "Development environment ready!"

# Quick test (skip slow tests)
test-quick:
	@echo "Running quick tests..."
	forge test --no-match-contract Integration --no-match-test testFullQuestLifecycle -vv

# Full test suite
test-full:
	@echo "Running full test suite..."
	make test
	make integration
	make coverage
	@echo "Full test suite complete!"

# Prepare for deployment
prepare-deploy:
	@echo "Preparing for deployment..."
	make build
	make test-full
	make fmt
	@echo "Ready for deployment!"
