#!/bin/bash

# Exit on first error
set -e

# Export path to Fabric binaries
export PATH="/home/zarath/github.com/zarathez/fabric/fabric-samples/bin:$PATH"

# Check if required Docker images exist
echo "Checking for required Docker images..."
if [[ "$(docker images -q couchdb:3.1.1 2> /dev/null)" == "" || \
      "$(docker images -q hyperledger/fabric-tools:latest 2> /dev/null)" == "" || \
      "$(docker images -q hyperledger/fabric-peer:latest 2> /dev/null)" == "" || \
      "$(docker images -q hyperledger/fabric-orderer:latest 2> /dev/null)" == "" || \
      "$(docker images -q hyperledger/fabric-ca:latest 2> /dev/null)" == "" ]]; then
  echo "Some required Docker images need to be pulled. This may take some time..."
else
  echo "All required Docker images already exist. Proceeding with network startup..."
fi

# Start the CA containers
echo "Starting CA containers..."
docker-compose -f docker-compose-ca.yaml up -d

# Wait for CAs to initialize properly
echo "Waiting for CAs to initialize (15 seconds)..."
sleep 10

# Check if CA certificates are created
CA_CERT_PATH="./organizations/stockmarket/ca/ca-cert.pem"
MAX_RETRIES=5
RETRY_COUNT=0

while [ ! -f "$CA_CERT_PATH" ] && [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  echo "CA certificates not ready yet. Waiting additional 5 seconds..."
  sleep 5
  RETRY_COUNT=$((RETRY_COUNT+1))
done

if [ ! -f "$CA_CERT_PATH" ]; then
  echo "Warning: CA certificates may not be ready. Attempting to proceed anyway..."
fi

# Register and enroll identities
echo "Registering and enrolling identities..."
./registerEnroll.sh

# Create channel artifacts
echo "Creating channel artifacts..."
./createArtifacts.sh

# Start the network
echo "Starting the network..."
docker-compose -f docker-compose-net.yaml up -d

# Wait for network to start
echo "Waiting for network to start (20 seconds)..."

# Create and join channels
echo "Creating and joining channels..."
./createJoinChannels.sh

# Install and instantiate chaincodes
echo "Installing and instantiating chaincodes..."
./installChaincodes.sh

echo "Network startup completed!"