# Stock Market Blockchain Network

A Hyperledger Fabric-based blockchain network simulating a stock market ecosystem with multiple organizations including stock exchanges, brokers, clearing houses, and regulatory authorities.

## 🏗️ Architecture Overview

This network consists of:
- **StockMarket**: Main exchange organization
- **MarocClear**: Settlement and clearing house
- **Broker1 & Broker2**: Trading brokers
- **AMMC**: Regulatory authority
- **Orderer**: Network ordering service

## 📋 Prerequisites

### System Requirements
- **Operating System**: Linux (Ubuntu 18.04+), macOS, or Windows with WSL2
- **Docker**: Version 20.10 or higher
- **Docker Compose**: Version 1.25 or higher
- **Node.js**: Version 14 or higher (for UI components)
- **Git**: For cloning repositories
- **Curl**: For downloading Hyperledger Fabric

### Hardware Requirements
- **RAM**: Minimum 8GB (16GB recommended)
- **Storage**: At least 10GB free space
- **CPU**: Multi-core processor recommended

## 🚀 Installation Guide

### Step 1: Install Docker and Docker Compose

#### Ubuntu/Debian:
```bash
# Update package index
sudo apt update

# Install Docker
sudo apt install docker.io docker-compose

# Add your user to docker group (requires logout/login)
sudo usermod -aG docker $USER

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker
```

#### macOS:
```bash
# Install Docker Desktop from https://www.docker.com/products/docker-desktop
# Or using Homebrew:
brew install --cask docker
```

#### Windows:
Install Docker Desktop from [Docker's official website](https://www.docker.com/products/docker-desktop)

### Step 2: Install Node.js

#### Ubuntu/Debian:
```bash
# Install Node.js 16.x
curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
sudo apt-get install -y nodejs
```

#### macOS:
```bash
# Using Homebrew
brew install node

# Or download from https://nodejs.org/
```

### Step 3: Set Up Project Directory Structure

**Important**: The `stock-market-network` project and `fabric-samples` must be in the same parent directory for the setup to work correctly.

```bash
# Create a workspace directory
mkdir blockchain-workspace
cd blockchain-workspace

# Clone this project
git clone <your-repository-url> stock-market-network

# Download Hyperledger Fabric samples and binaries
curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.4.7 1.5.2
```

Your directory structure should look like this:
```
blockchain-workspace/
├── stock-market-network/          # This project
│   ├── docker-compose-ca.yaml
│   ├── docker-compose-net.yaml
│   ├── startNetwork.sh
│   └── ...
└── fabric-samples/                # Hyperledger Fabric
    ├── bin/                       # Fabric binaries (configtxgen, peer, etc.)
    ├── config/
    └── ...
```

### Step 4: Update startNetwork.sh

Update the `startNetwork.sh` file to reference the fabric binaries relatively:

```bash
cd stock-market-network
```

Replace the PATH export line in `startNetwork.sh` (around line 6) with:
```bash
# Export path to Fabric binaries (relative to parent directory)
export PATH="../fabric-samples/bin:$PATH"
```

### Step 5: Install UI Dependencies

```bash
# Install server dependencies
cd ui/server
npm install

# Install client dependencies
cd ../client
npm install

# Install broker UI server dependencies
cd ../../broker-ui/server
npm install

# Install broker UI client dependencies
cd ../client
npm install

# Return to project root
cd ../../
```

## 🎯 Quick Start

### Start the Network

```bash
# Make scripts executable
chmod +x *.sh

# Start the complete network
./startNetwork.sh
```

The startup process will:
1. Pull required Docker images (first time only)
2. Start Certificate Authority (CA) containers
3. Register and enroll all identities
4. Create channel artifacts
5. Start peer and orderer containers
6. Create and join channels
7. Install and instantiate chaincodes

### Populate with Sample Data

```bash
# Add sample securities, orders, and trades
./populate-securities-orders-trades.sh
```

### Start User Interfaces

```bash
# Start all UI components
./userInterface.sh
```

Access the applications:
- **Stock Market UI**: http://localhost:3000
- **Broker UI**: http://localhost:3001

## 🔧 Network Management

### Stop the Network
```bash
./networkDown.sh
```

### Restart the Network
```bash
# Clean shutdown
./networkDown.sh

# Fresh start
./startNetwork.sh
```

### View Container Status
```bash
docker ps -a
```

### View Container Logs
```bash
# View specific container logs
docker logs peer0.stockmarket

# Follow logs in real-time
docker logs -f peer0.stockmarket
```

## 🧪 Testing the Network

### Query Securities
```bash
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/users/Admin@stockmarket/msp && \
export CORE_PEER_ADDRESS=peer0.stockmarket:7051 && \
export CORE_PEER_LOCALMSPID=StockMarketMSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/peers/peer0.stockmarket/tls/ca.crt && \
peer chaincode query -C trading-channel -n order-matching -c '{\"Args\":[\"GetAllSecurities\"]}'"
```

### Query Orders
```bash
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker1/users/Admin@broker1/msp && \
export CORE_PEER_ADDRESS=peer0.broker1:7051 && \
export CORE_PEER_LOCALMSPID=Broker1MSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker1/peers/peer0.broker1/tls/ca.crt && \
peer chaincode query -C trading-channel -n order-matching -c '{\"Args\":[\"GetAllOrders\"]}'"
```

### Query Trades
```bash
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/users/Admin@stockmarket/msp && \
export CORE_PEER_ADDRESS=peer0.stockmarket:7051 && \
export CORE_PEER_LOCALMSPID=StockMarketMSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/peers/peer0.stockmarket/tls/ca.crt && \
peer chaincode query -C trading-channel -n order-matching -c '{\"Args\":[\"GetAllTrades\"]}'"
```

## 📁 Project Structure

```
stock-market-network/
├── chaincodes/                    # Smart contracts
│   ├── order-matching/           # Trading and order matching
│   ├── compliance/               # Regulatory compliance
│   └── settlement/               # Settlement processing
├── docker-compose-ca.yaml        # CA containers configuration
├── docker-compose-net.yaml       # Network containers configuration
├── configtx.yaml                 # Channel configuration
├── organizations/                # MSP and crypto materials
├── ui/                           # Stock market user interface
├── broker-ui/                    # Broker user interface
├── scripts/                      # Utility scripts
├── startNetwork.sh              # Main startup script
├── networkDown.sh               # Network shutdown script
├── registerEnroll.sh            # Identity management
├── createArtifacts.sh           # Channel artifacts creation
├── createJoinChannels.sh        # Channel management
├── installChaincodes.sh         # Chaincode deployment
└── populate-securities-orders-trades.sh  # Sample data
```

## 🐛 Troubleshooting

### Common Issues

#### "fabric binaries not found"
- Ensure `fabric-samples` and `stock-market-network` are in the same parent directory
- Verify the PATH in `startNetwork.sh` points to `../fabric-samples/bin`
- Check that fabric binaries exist: `ls ../fabric-samples/bin/`

#### "Permission denied" on scripts
```bash
chmod +x *.sh
```

#### "Docker daemon not running"
```bash
sudo systemctl start docker
```

#### "Port already in use"
```bash
# Stop any existing containers
docker stop $(docker ps -aq)
./networkDown.sh
```

#### "CouchDB connection failed"
```bash
# Wait longer for CouchDB to initialize
sleep 30
# Or restart the network
./networkDown.sh && ./startNetwork.sh
```

### Clean Reset
```bash
# Complete cleanup
./networkDown.sh
docker system prune -f
docker volume prune -f

# Fresh start
./startNetwork.sh
```

### View Detailed Logs
```bash
# All container logs
docker-compose -f docker-compose-net.yaml logs

# Specific service logs
docker-compose -f docker-compose-net.yaml logs peer0.stockmarket
```
