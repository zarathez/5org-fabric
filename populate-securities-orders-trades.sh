#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

#####################
# UTILITY FUNCTIONS #
#####################

# Logging function with timestamp
log() {
  echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Error handling function
handle_error() {
  log "ERROR: $1"
  exit 1
}

# Reference to the CLI container - this is the container used for issuing commands
CLI="docker exec cli"

# Docker path constants - these are the paths inside the Docker container
DOCKER_CRYPTO_PATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto"
ORDERER_CA="${DOCKER_CRYPTO_PATH}/orderer/orderers/orderer0.orderer/tls/ca.crt"
ORDERER_ADDRESS="orderer0.orderer:7050"

# Channel and chaincode constants
TRADING_CHANNEL="trading-channel"
REGULATORY_CHANNEL="regulatory-channel"
SETTLEMENT_CHANNEL="settlement-channel"
ORDER_MATCHING_CC="order-matching"
COMPLIANCE_CC="compliance"
SETTLEMENT_CC="settlement"

# Function to check if command succeeded
check_success() {
  if [ $? -ne 0 ]; then
    handle_error "$1"
  else
    log "SUCCESS: $1"
  fi
}

# Function to set environment for a specific peer within the CLI container
set_peer_env() {
  local ORG=$1
  local MSP_ID=$2
  
  log "Setting peer environment variables for $ORG with MSP_ID: $MSP_ID"
  
  # This function now exports variables that will be used in the Docker commands
  export CURRENT_ORG=$ORG
  export CURRENT_MSP_ID=$MSP_ID
  export CORE_PEER_MSPCONFIGPATH="${DOCKER_CRYPTO_PATH}/${ORG}/users/Admin@${ORG}/msp"
  export CORE_PEER_ADDRESS="peer0.${ORG}:7051"
  export CORE_PEER_LOCALMSPID="${MSP_ID}"
  export CORE_PEER_TLS_ROOTCERT_FILE="${DOCKER_CRYPTO_PATH}/${ORG}/peers/peer0.${ORG}/tls/ca.crt"
}

# Function to execute peer command in the CLI container with proper environment variables
execute_peer_command() {
  local CMD=$1
  local ERROR_MSG=$2
  
  # Execute command in the CLI container with the current environment settings
  $CLI bash -c "export CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH && \
  export CORE_PEER_ADDRESS=$CORE_PEER_ADDRESS && \
  export CORE_PEER_LOCALMSPID=$CORE_PEER_LOCALMSPID && \
  export CORE_PEER_TLS_ROOTCERT_FILE=$CORE_PEER_TLS_ROOTCERT_FILE && \
  $CMD" || handle_error "$ERROR_MSG"
}

# Function to check if a trade exists in a channel
trade_exists() {
  local CHANNEL=$1
  local CHAINCODE=$2
  local TRADE_ID=$3
  local ORG=$4
  local MSP_ID=$5
  
  set_peer_env $ORG $MSP_ID
  
  log "Checking if trade $TRADE_ID exists in $CHANNEL"
  
  local QUERY_CMD="peer chaincode query -C $CHANNEL -n $CHAINCODE -c '{\"Args\":[\"GetTrade\",\"$TRADE_ID\"]}'"
  
  # Capture both output and exit status to properly determine existence
  local QUERY_OUTPUT=""
  local EXIT_STATUS=0
  
  # Execute query but handle potential failure
  QUERY_OUTPUT=$($CLI bash -c "export CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH && \
  export CORE_PEER_ADDRESS=$CORE_PEER_ADDRESS && \
  export CORE_PEER_LOCALMSPID=$CORE_PEER_LOCALMSPID && \
  export CORE_PEER_TLS_ROOTCERT_FILE=$CORE_PEER_TLS_ROOTCERT_FILE && \
  $QUERY_CMD" 2>&1) || EXIT_STATUS=$?
  
  # Check both exit status and output content for proper error detection
  if [[ $EXIT_STATUS -ne 0 || "$QUERY_OUTPUT" == *"Error"* || "$QUERY_OUTPUT" == *"does not exist"* || "$QUERY_OUTPUT" == *"error"* ]]; then
    log "Trade $TRADE_ID does not exist in $CHANNEL: $QUERY_OUTPUT"
    return 1  # Trade does not exist
  else
    log "Trade $TRADE_ID exists in $CHANNEL"
    return 0  # Trade exists
  fi
}

# Function to check if a compliance check exists for a trade
compliance_check_exists() {
  local TRADE_ID=$1
  
  set_peer_env "ammc" "AMMCMSP"
  
  log "Checking if compliance check exists for trade $TRADE_ID"
  
  # Compliance check ID follows the pattern "check-{tradeID}"
  local CHECK_ID="check-$TRADE_ID"
  local QUERY_CMD="peer chaincode query -C $REGULATORY_CHANNEL -n $COMPLIANCE_CC -c '{\"Args\":[\"GetComplianceCheck\",\"$CHECK_ID\"]}' 2>/dev/null || true"
  
  local CHECK=$($CLI bash -c "export CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH && \
  export CORE_PEER_ADDRESS=$CORE_PEER_ADDRESS && \
  export CORE_PEER_LOCALMSPID=$CORE_PEER_LOCALMSPID && \
  export CORE_PEER_TLS_ROOTCERT_FILE=$CORE_PEER_TLS_ROOTCERT_FILE && \
  $QUERY_CMD")
  
  if [[ $CHECK == *"Error"* ]]; then
    return 1  # Check does not exist
  else
    return 0  # Check exists
  fi
}

# Function to check if a settlement instruction exists for a trade
settlement_instruction_exists() {
  local TRADE_ID=$1
  
  set_peer_env "maroclear" "MaroclearMSP"
  
  log "Checking if settlement instruction exists for trade $TRADE_ID"
  
  # Settlement instruction ID follows the pattern "instruction-{tradeID}"
  local INSTRUCTION_ID="instruction-$TRADE_ID"
  local QUERY_CMD="peer chaincode query -C $SETTLEMENT_CHANNEL -n $SETTLEMENT_CC -c '{\"Args\":[\"GetSettlementInstruction\",\"$INSTRUCTION_ID\"]}' 2>/dev/null || true"
  
  local INSTRUCTION=$($CLI bash -c "export CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH && \
  export CORE_PEER_ADDRESS=$CORE_PEER_ADDRESS && \
  export CORE_PEER_LOCALMSPID=$CORE_PEER_LOCALMSPID && \
  export CORE_PEER_TLS_ROOTCERT_FILE=$CORE_PEER_TLS_ROOTCERT_FILE && \
  $QUERY_CMD")
  
  if [[ $INSTRUCTION == *"Error"* ]]; then
    return 1  # Instruction does not exist
  else
    return 0  # Instruction exists
  fi
}

# Function to get trade details
get_trade_details() {
  local TRADE_ID=$1
  
  set_peer_env "stockmarket" "StockMarketMSP"
  
  log "Getting details for trade $TRADE_ID"
  
  local QUERY_CMD="peer chaincode query -C $TRADING_CHANNEL -n $ORDER_MATCHING_CC -c '{\"Args\":[\"GetTrade\",\"$TRADE_ID\"]}'"
  
  local TRADE_DETAILS=$($CLI bash -c "export CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH && \
  export CORE_PEER_ADDRESS=$CORE_PEER_ADDRESS && \
  export CORE_PEER_LOCALMSPID=$CORE_PEER_LOCALMSPID && \
  export CORE_PEER_TLS_ROOTCERT_FILE=$CORE_PEER_TLS_ROOTCERT_FILE && \
  $QUERY_CMD")
  
  echo "$TRADE_DETAILS"
}

#####################
# MAIN SCRIPT START #
#####################

log "Initializing Stock Market Blockchain with sample data"

# Step 1: Creating securities in the trading channel
log "Step 1: Creating securities in the trading channel"
set_peer_env "stockmarket" "StockMarketMSP"

# Security 1: AAPL (Apple Inc.)
log "Creating Apple security (SEC001)"
execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $TRADING_CHANNEL -n $ORDER_MATCHING_CC \
  --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
  -c '{\"Args\":[\"CreateSecurity\",\"SEC001\",\"AAPL\",\"APP001\",\"Apple Inc.\",\"1000000\",\"150.25\"]}'" \
  "Failed to create Apple security"
sleep 3

# Security 2: MSFT (Microsoft Corp)
log "Creating Microsoft security (SEC002)"
execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $TRADING_CHANNEL -n $ORDER_MATCHING_CC \
  --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
  -c '{\"Args\":[\"CreateSecurity\",\"SEC002\",\"MSFT\",\"MSF001\",\"Microsoft Corporation\",\"800000\",\"300.50\"]}'" \
  "Failed to create Microsoft security"
sleep 3

# Security 3: GOOGL (Alphabet Inc.)
log "Creating Alphabet security (SEC003)"
execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $TRADING_CHANNEL -n $ORDER_MATCHING_CC \
  --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
  -c '{\"Args\":[\"CreateSecurity\",\"SEC003\",\"GOOGL\",\"GOO001\",\"Alphabet Inc.\",\"500000\",\"135.75\"]}'" \
  "Failed to create Alphabet security"
sleep 3

log "Securities created successfully in trading channel"

# Step 2: Adding securities to the regulatory channel
log "Step 2: Adding securities to the regulatory channel"
set_peer_env "ammc" "AMMCMSP"

# Add Apple to regulatory channel
log "Adding Apple to regulatory channel"
execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $REGULATORY_CHANNEL -n $COMPLIANCE_CC \
  --peerAddresses peer0.ammc:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
  --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles ${DOCKER_CRYPTO_PATH}/stockmarket/peers/peer0.stockmarket/tls/ca.crt \
  -c '{\"Args\":[\"AddSecurity\",\"SEC001\",\"AAPL\",\"Apple Inc.\",\"APP001\",\"1000000\",\"150.25\",\"10.0\",\"false\"]}'" \
  "Failed to add Apple to regulatory channel"
sleep 3

# Add Microsoft to regulatory channel
log "Adding Microsoft to regulatory channel"
execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $REGULATORY_CHANNEL -n $COMPLIANCE_CC \
  --peerAddresses peer0.ammc:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
  --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles ${DOCKER_CRYPTO_PATH}/stockmarket/peers/peer0.stockmarket/tls/ca.crt \
  -c '{\"Args\":[\"AddSecurity\",\"SEC002\",\"MSFT\",\"Microsoft Corporation\",\"MSF001\",\"800000\",\"300.50\",\"10.0\",\"false\"]}'" \
  "Failed to add Microsoft to regulatory channel"
sleep 3

# Add Alphabet to regulatory channel
log "Adding Alphabet to regulatory channel"
execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $REGULATORY_CHANNEL -n $COMPLIANCE_CC \
  --peerAddresses peer0.ammc:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
  --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles ${DOCKER_CRYPTO_PATH}/stockmarket/peers/peer0.stockmarket/tls/ca.crt \
  -c '{\"Args\":[\"AddSecurity\",\"SEC003\",\"GOOGL\",\"Alphabet Inc.\",\"GOO001\",\"500000\",\"135.75\",\"10.0\",\"false\"]}'" \
  "Failed to add Alphabet to regulatory channel"
sleep 3

log "Securities added to regulatory channel successfully"

# Step 3: Creating broker accounts in settlement channel
log "Step 3: Creating broker accounts in settlement channel"
set_peer_env "maroclear" "MaroclearMSP"

# Create broker accounts with initial balances
log "Creating Broker1 account in settlement channel"
execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $SETTLEMENT_CHANNEL -n $SETTLEMENT_CC \
  --peerAddresses peer0.maroclear:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
  --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles ${DOCKER_CRYPTO_PATH}/stockmarket/peers/peer0.stockmarket/tls/ca.crt \
  -c '{\"Args\":[\"CreateBrokerAccount\",\"BROKER1\",\"1000000\"]}'" \
  "Failed to create broker1 account"
sleep 3

log "Creating Broker2 account in settlement channel"
execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $SETTLEMENT_CHANNEL -n $SETTLEMENT_CC \
  --peerAddresses peer0.maroclear:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
  --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles ${DOCKER_CRYPTO_PATH}/stockmarket/peers/peer0.stockmarket/tls/ca.crt \
  -c '{\"Args\":[\"CreateBrokerAccount\",\"BROKER2\",\"1500000\"]}'" \
  "Failed to create broker2 account"
sleep 3

log "Broker accounts created in settlement channel successfully"

# Step 4: Adding brokers to the regulatory channel
log "Step 4: Adding brokers to regulatory channel"
set_peer_env "ammc" "AMMCMSP"

# Add broker1 to regulatory channel
log "Adding Broker1 to regulatory channel"
execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $REGULATORY_CHANNEL -n $COMPLIANCE_CC \
  --peerAddresses peer0.ammc:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
  --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles ${DOCKER_CRYPTO_PATH}/stockmarket/peers/peer0.stockmarket/tls/ca.crt \
  -c '{\"Args\":[\"AddBroker\",\"BROKER1\",\"Broker One Ltd.\",\"100000\",\"low\"]}'" \
  "Failed to add Broker1 to regulatory channel"
sleep 3

# Add broker2 to regulatory channel
log "Adding Broker2 to regulatory channel"
execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $REGULATORY_CHANNEL -n $COMPLIANCE_CC \
  --peerAddresses peer0.ammc:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
  --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles ${DOCKER_CRYPTO_PATH}/stockmarket/peers/peer0.stockmarket/tls/ca.crt \
  -c '{\"Args\":[\"AddBroker\",\"BROKER2\",\"Broker Two Ltd.\",\"150000\",\"low\"]}'" \
  "Failed to add Broker2 to regulatory channel"
sleep 3

log "Brokers added to regulatory channel successfully"

# Step 5: Creating securities accounts in settlement channel
log "Step 5: Creating securities accounts in settlement channel"
set_peer_env "maroclear" "MaroclearMSP"

# Create securities accounts for broker1
log "Creating securities accounts for Broker1"
execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $SETTLEMENT_CHANNEL -n $SETTLEMENT_CC \
  --peerAddresses peer0.maroclear:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
  --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles ${DOCKER_CRYPTO_PATH}/stockmarket/peers/peer0.stockmarket/tls/ca.crt \
  -c '{\"Args\":[\"CreateSecuritiesAccount\",\"BROKER1\",\"SEC001\",\"10000\"]}'" \
  "Failed to create securities account for Broker1-SEC001"
sleep 3

execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $SETTLEMENT_CHANNEL -n $SETTLEMENT_CC \
  --peerAddresses peer0.maroclear:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
  --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles ${DOCKER_CRYPTO_PATH}/stockmarket/peers/peer0.stockmarket/tls/ca.crt \
  -c '{\"Args\":[\"CreateSecuritiesAccount\",\"BROKER1\",\"SEC002\",\"8000\"]}'" \
  "Failed to create securities account for Broker1-SEC002"
sleep 3

execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $SETTLEMENT_CHANNEL -n $SETTLEMENT_CC \
  --peerAddresses peer0.maroclear:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
  --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles ${DOCKER_CRYPTO_PATH}/stockmarket/peers/peer0.stockmarket/tls/ca.crt \
  -c '{\"Args\":[\"CreateSecuritiesAccount\",\"BROKER1\",\"SEC003\",\"5000\"]}'" \
  "Failed to create securities account for Broker1-SEC003"
sleep 3

# Create securities accounts for broker2
log "Creating securities accounts for Broker2"
execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $SETTLEMENT_CHANNEL -n $SETTLEMENT_CC \
  --peerAddresses peer0.maroclear:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
  --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles ${DOCKER_CRYPTO_PATH}/stockmarket/peers/peer0.stockmarket/tls/ca.crt \
  -c '{\"Args\":[\"CreateSecuritiesAccount\",\"BROKER2\",\"SEC001\",\"15000\"]}'" \
  "Failed to create securities account for Broker2-SEC001"
sleep 3

execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $SETTLEMENT_CHANNEL -n $SETTLEMENT_CC \
  --peerAddresses peer0.maroclear:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
  --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles ${DOCKER_CRYPTO_PATH}/stockmarket/peers/peer0.stockmarket/tls/ca.crt \
  -c '{\"Args\":[\"CreateSecuritiesAccount\",\"BROKER2\",\"SEC002\",\"12000\"]}'" \
  "Failed to create securities account for Broker2-SEC002"
sleep 3

execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $SETTLEMENT_CHANNEL -n $SETTLEMENT_CC \
  --peerAddresses peer0.maroclear:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
  --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles ${DOCKER_CRYPTO_PATH}/stockmarket/peers/peer0.stockmarket/tls/ca.crt \
  -c '{\"Args\":[\"CreateSecuritiesAccount\",\"BROKER2\",\"SEC003\",\"7500\"]}'" \
  "Failed to create securities account for Broker2-SEC003"
sleep 3

log "Securities accounts created in settlement channel successfully"

# Step 6: Creating buy and sell orders
log "Step 6: Creating buy and sell orders"
set_peer_env "broker1" "Broker1MSP"

# Create buy orders from Broker1
log "Creating buy orders from Broker1"
execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $TRADING_CHANNEL -n $ORDER_MATCHING_CC \
  --peerAddresses peer0.broker1:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
  -c '{\"Args\":[\"CreateOrder\",\"BUY001\",\"BROKER1\",\"SEC001\",\"buy\",\"100\",\"152.50\"]}'" \
  "Failed to create buy order BUY001"
sleep 2

execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $TRADING_CHANNEL -n $ORDER_MATCHING_CC \
  --peerAddresses peer0.broker1:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
  -c '{\"Args\":[\"CreateOrder\",\"BUY002\",\"BROKER1\",\"SEC002\",\"buy\",\"50\",\"302.75\"]}'" \
  "Failed to create buy order BUY002"
sleep 2

execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $TRADING_CHANNEL -n $ORDER_MATCHING_CC \
  --peerAddresses peer0.broker1:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
  -c '{\"Args\":[\"CreateOrder\",\"BUY003\",\"BROKER1\",\"SEC003\",\"buy\",\"75\",\"137.25\"]}'" \
  "Failed to create buy order BUY003"
sleep 2

# Create sell orders from Broker2
set_peer_env "broker2" "Broker2MSP"
log "Creating sell orders from Broker2"
execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $TRADING_CHANNEL -n $ORDER_MATCHING_CC \
  --peerAddresses peer0.broker2:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
  -c '{\"Args\":[\"CreateOrder\",\"SELL001\",\"BROKER2\",\"SEC001\",\"sell\",\"100\",\"151.75\"]}'" \
  "Failed to create sell order SELL001"
sleep 2

execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $TRADING_CHANNEL -n $ORDER_MATCHING_CC \
  --peerAddresses peer0.broker2:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
  -c '{\"Args\":[\"CreateOrder\",\"SELL002\",\"BROKER2\",\"SEC002\",\"sell\",\"50\",\"301.50\"]}'" \
  "Failed to create sell order SELL002"
sleep 2

execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $TRADING_CHANNEL -n $ORDER_MATCHING_CC \
  --peerAddresses peer0.broker2:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
  -c '{\"Args\":[\"CreateOrder\",\"SELL003\",\"BROKER2\",\"SEC003\",\"sell\",\"75\",\"136.50\"]}'" \
  "Failed to create sell order SELL003"
sleep 2

log "Buy and sell orders created successfully"

# Step 7: Match orders to create trades
log "Step 7: Matching orders to create trades"
set_peer_env "stockmarket" "StockMarketMSP"

# Match orders for each security
log "Matching orders for SEC001"
execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $TRADING_CHANNEL -n $ORDER_MATCHING_CC \
  --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
  -c '{\"Args\":[\"MatchOrders\",\"SEC001\"]}'" \
  "Failed to match orders for SEC001"
sleep 5

log "Matching orders for SEC002"
execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $TRADING_CHANNEL -n $ORDER_MATCHING_CC \
  --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
  -c '{\"Args\":[\"MatchOrders\",\"SEC002\"]}'" \
  "Failed to match orders for SEC002"
sleep 5

log "Matching orders for SEC003"
execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $TRADING_CHANNEL -n $ORDER_MATCHING_CC \
  --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
  -c '{\"Args\":[\"MatchOrders\",\"SEC003\"]}'" \
  "Failed to match orders for SEC003"
sleep 5

log "Orders matched successfully, trades created"

# Step 8: Getting all pending trades from trading channel
log "Step 8: Getting all pending trades from trading channel"
set_peer_env "stockmarket" "StockMarketMSP"

QUERY_CMD="peer chaincode query -C $TRADING_CHANNEL -n $ORDER_MATCHING_CC -c '{\"Args\":[\"GetAllTradesByStatus\",\"pending\"]}'"
PENDING_TRADES=$($CLI bash -c "export CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH && \
export CORE_PEER_ADDRESS=$CORE_PEER_ADDRESS && \
export CORE_PEER_LOCALMSPID=$CORE_PEER_LOCALMSPID && \
export CORE_PEER_TLS_ROOTCERT_FILE=$CORE_PEER_TLS_ROOTCERT_FILE && \
$QUERY_CMD")
check_success "Retrieved pending trades from trading channel"

log "Found trades: $PENDING_TRADES"

# Expected trade IDs from the matching process
TRADE_IDS=("trade-BUY001-SELL001-0" "trade-BUY002-SELL002-0" "trade-BUY003-SELL003-0")
# Step 9: Process each trade through regulatory and settlement channels
log "Step 9: Processing each trade through regulatory and settlement channels"
for TRADE_ID in "${TRADE_IDS[@]}"; do
  log "Processing trade: $TRADE_ID"
  
  # Get trade details from trading channel
  log "Getting trade details from trading channel"
  QUERY_CMD="peer chaincode query -C $TRADING_CHANNEL -n $ORDER_MATCHING_CC -c '{\"Args\":[\"GetTrade\",\"$TRADE_ID\"]}'"
  TRADE_DETAILS=$($CLI bash -c "export CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH && \
  export CORE_PEER_ADDRESS=$CORE_PEER_ADDRESS && \
  export CORE_PEER_LOCALMSPID=$CORE_PEER_LOCALMSPID && \
  export CORE_PEER_TLS_ROOTCERT_FILE=$CORE_PEER_TLS_ROOTCERT_FILE && \
  $QUERY_CMD")
  check_success "Retrieved trade details from trading channel"
  
  # Extract necessary fields for processing
  BUY_ORDER_ID=$(echo $TRADE_DETAILS | grep -o '"buyOrderID":"[^"]*' | head -1 | cut -d'"' -f4)
  SELL_ORDER_ID=$(echo $TRADE_DETAILS | grep -o '"sellOrderID":"[^"]*' | head -1 | cut -d'"' -f4)
  BUY_BROKER_ID=$(echo $TRADE_DETAILS | grep -o '"buyBrokerID":"[^"]*' | head -1 | cut -d'"' -f4)
  SELL_BROKER_ID=$(echo $TRADE_DETAILS | grep -o '"sellBrokerID":"[^"]*' | head -1 | cut -d'"' -f4)
  SECURITY_ID=$(echo $TRADE_DETAILS | grep -o '"securityID":"[^"]*' | head -1 | cut -d'"' -f4)
  QUANTITY=$(echo $TRADE_DETAILS | grep -o '"quantity":[^,]*' | head -1 | cut -d':' -f2)
  PRICE=$(echo $TRADE_DETAILS | grep -o '"price":[^,]*' | head -1 | cut -d':' -f2)
  STATUS=$(echo $TRADE_DETAILS | grep -o '"status":"[^"]*' | head -1 | cut -d'"' -f4)
  MATCH_TIME=$(echo $TRADE_DETAILS | grep -o '"matchTime":"[^"]*' | head -1 | cut -d'"' -f4)
  
  log "Trade details: BuyOrderID=$BUY_ORDER_ID, SellOrderID=$SELL_ORDER_ID, BuyBrokerID=$BUY_BROKER_ID, SellBrokerID=$SELL_BROKER_ID, SecurityID=$SECURITY_ID, Quantity=$QUANTITY, Price=$PRICE, Status=$STATUS, MatchTime=$MATCH_TIME"
  
  # Step 9.1: Import trade to regulatory channel if it doesn't exist there
  if ! trade_exists "$REGULATORY_CHANNEL" "$COMPLIANCE_CC" "$TRADE_ID" "ammc" "AMMCMSP"; then
    log "Importing trade $TRADE_ID to regulatory channel"
    set_peer_env "ammc" "AMMCMSP"
    
    # Use the CORRECT ImportTrade function signature with ALL parameters
    execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $REGULATORY_CHANNEL -n $COMPLIANCE_CC \
      --peerAddresses peer0.ammc:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
      --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles ${DOCKER_CRYPTO_PATH}/stockmarket/peers/peer0.stockmarket/tls/ca.crt \
      -c '{\"Args\":[\"ImportTrade\",\"$TRADE_ID\",\"$BUY_ORDER_ID\",\"$SELL_ORDER_ID\",\"$BUY_BROKER_ID\",\"$SELL_BROKER_ID\",\"$SECURITY_ID\",\"$QUANTITY\",\"$PRICE\",\"$STATUS\",\"$MATCH_TIME\"]}'" \
      "Failed to import trade to regulatory channel"
    sleep 3
    
    # Verify the import was successful
    if ! trade_exists "$REGULATORY_CHANNEL" "$COMPLIANCE_CC" "$TRADE_ID" "ammc" "AMMCMSP"; then
      handle_error "Failed to verify trade import to regulatory channel"
    fi
    log "Trade successfully imported to regulatory channel"
  else
    log "Trade $TRADE_ID already exists in regulatory channel, skipping import"
  fi
  
  # Step 9.2: Get compliance check status if it exists, or perform a new check
  set_peer_env "ammc" "AMMCMSP"
  CHECK_ID="check-$TRADE_ID"
  
  # Check if compliance check exists
  QUERY_CMD="peer chaincode query -C $REGULATORY_CHANNEL -n $COMPLIANCE_CC -c '{\"Args\":[\"GetComplianceCheck\",\"$CHECK_ID\"]}'"
  COMPLIANCE_CHECK=$($CLI bash -c "export CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH && \
  export CORE_PEER_ADDRESS=$CORE_PEER_ADDRESS && \
  export CORE_PEER_LOCALMSPID=$CORE_PEER_LOCALMSPID && \
  export CORE_PEER_TLS_ROOTCERT_FILE=$CORE_PEER_TLS_ROOTCERT_FILE && \
  $QUERY_CMD" 2>&1) || true
  
  if [[ "$COMPLIANCE_CHECK" == *"does not exist"* || "$COMPLIANCE_CHECK" == *"Error"* ]]; then
    log "Compliance check for trade $TRADE_ID does not exist, performing check now"
    
    execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $REGULATORY_CHANNEL -n $COMPLIANCE_CC \
      --peerAddresses peer0.ammc:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
      --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles ${DOCKER_CRYPTO_PATH}/stockmarket/peers/peer0.stockmarket/tls/ca.crt \
      -c '{\"Args\":[\"PerformTradeCheck\",\"$TRADE_ID\",\"REGULATOR1\"]}'" \
      "Failed to perform compliance check"
    sleep 3
    
    # Get the result of the check
    COMPLIANCE_CHECK=$($CLI bash -c "export CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH && \
    export CORE_PEER_ADDRESS=$CORE_PEER_ADDRESS && \
    export CORE_PEER_LOCALMSPID=$CORE_PEER_LOCALMSPID && \
    export CORE_PEER_TLS_ROOTCERT_FILE=$CORE_PEER_TLS_ROOTCERT_FILE && \
    peer chaincode query -C $REGULATORY_CHANNEL -n $COMPLIANCE_CC -c '{\"Args\":[\"GetComplianceCheck\",\"$CHECK_ID\"]}'")
    check_success "Retrieved compliance check after performing it"
  else
    log "Compliance check already exists for trade $TRADE_ID"
  fi
  
  # Extract compliance status
  COMPLIANCE_STATUS=$(echo $COMPLIANCE_CHECK | grep -o '"status":"[^"]*' | head -1 | cut -d'"' -f4)
  log "Compliance check status: $COMPLIANCE_STATUS"
  
  # Step 9.3: Update trade status in trading channel to match compliance status
  log "Updating trade status in trading channel to: $COMPLIANCE_STATUS"
  set_peer_env "stockmarket" "StockMarketMSP"
  
  execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $TRADING_CHANNEL -n $ORDER_MATCHING_CC \
    --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
    -c '{\"Args\":[\"UpdateTradeStatus\",\"$TRADE_ID\",\"$COMPLIANCE_STATUS\"]}'" \
    "Failed to update trade status in trading channel"
  sleep 3
  
  # Step 9.4: Only proceed with settlement if compliance status is approved
  if [[ "$COMPLIANCE_STATUS" == "approved" ]]; then
    log "Trade $TRADE_ID was approved, proceeding with settlement"
    
    # Step 9.4.1: Import approved trade to settlement channel if it doesn't exist there
    if ! trade_exists "$SETTLEMENT_CHANNEL" "$SETTLEMENT_CC" "$TRADE_ID" "maroclear" "MaroclearMSP"; then
      log "Importing approved trade $TRADE_ID to settlement channel"
      set_peer_env "maroclear" "MaroclearMSP"
      
      # Use a similar ImportTrade function in settlement chaincode
      # This assumes settlement chaincode has a similar ImportTrade function to compliance
      execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $SETTLEMENT_CHANNEL -n $SETTLEMENT_CC \
        --peerAddresses peer0.maroclear:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
        --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles ${DOCKER_CRYPTO_PATH}/stockmarket/peers/peer0.stockmarket/tls/ca.crt \
        -c '{\"Args\":[\"ImportTrade\",\"$TRADE_ID\",\"$BUY_ORDER_ID\",\"$SELL_ORDER_ID\",\"$BUY_BROKER_ID\",\"$SELL_BROKER_ID\",\"$SECURITY_ID\",\"$QUANTITY\",\"$PRICE\",\"$COMPLIANCE_STATUS\",\"$MATCH_TIME\"]}'" \
        "Failed to import trade to settlement channel"
      sleep 3
      
      # Verify the import to settlement channel was successful
      if ! trade_exists "$SETTLEMENT_CHANNEL" "$SETTLEMENT_CC" "$TRADE_ID" "maroclear" "MaroclearMSP"; then
        handle_error "Failed to verify trade import to settlement channel"
      fi
      log "Trade successfully imported to settlement channel"
    else
      log "Trade $TRADE_ID already exists in settlement channel, skipping import"
    fi
    
    # Step 9.4.2: Create settlement instruction if it doesn't exist
    set_peer_env "maroclear" "MaroclearMSP"
    INSTRUCTION_ID="instruction-$TRADE_ID"
    
    QUERY_CMD="peer chaincode query -C $SETTLEMENT_CHANNEL -n $SETTLEMENT_CC -c '{\"Args\":[\"GetSettlementInstruction\",\"$INSTRUCTION_ID\"]}'"
    INSTRUCTION=$($CLI bash -c "export CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH && \
    export CORE_PEER_ADDRESS=$CORE_PEER_ADDRESS && \
    export CORE_PEER_LOCALMSPID=$CORE_PEER_LOCALMSPID && \
    export CORE_PEER_TLS_ROOTCERT_FILE=$CORE_PEER_TLS_ROOTCERT_FILE && \
    $QUERY_CMD" 2>&1) || true
    
    if [[ "$INSTRUCTION" == *"does not exist"* || "$INSTRUCTION" == *"Error"* ]]; then
      log "Creating settlement instruction for trade $TRADE_ID"
      
      execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $SETTLEMENT_CHANNEL -n $SETTLEMENT_CC \
        --peerAddresses peer0.maroclear:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
        --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles ${DOCKER_CRYPTO_PATH}/stockmarket/peers/peer0.stockmarket/tls/ca.crt \
        -c '{\"Args\":[\"CreateSettlementInstruction\",\"$TRADE_ID\"]}'" \
        "Failed to create settlement instruction"
      sleep 3
    else
      log "Settlement instruction already exists for trade $TRADE_ID, skipping creation"
    fi
    
    # Step 9.4.3: Execute settlement
    log "Executing settlement for trade $TRADE_ID"
    
    execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $SETTLEMENT_CHANNEL -n $SETTLEMENT_CC \
      --peerAddresses peer0.maroclear:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
      --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles ${DOCKER_CRYPTO_PATH}/stockmarket/peers/peer0.stockmarket/tls/ca.crt \
      -c '{\"Args\":[\"ExecuteSettlement\",\"$INSTRUCTION_ID\"]}'" \
      "Failed to execute settlement"
    sleep 3
    
    # Step 9.4.4: Update trade status to "settled" in trading channel
    log "Updating trade status to settled in trading channel"
    set_peer_env "stockmarket" "StockMarketMSP"
    
    execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $TRADING_CHANNEL -n $ORDER_MATCHING_CC \
      --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
      -c '{\"Args\":[\"UpdateTradeStatus\",\"$TRADE_ID\",\"settled\"]}'" \
      "Failed to update trade status to settled in trading channel"
    sleep 3
  else
    log "Trade $TRADE_ID was not approved in compliance check, skipping settlement"
  fi
  
  log "Completed processing trade: $TRADE_ID"
done

# Step 10: Create additional trades for demonstration
log "Step 10: Creating additional trades for demonstration"

# Create more buy orders
log "Creating additional buy orders from broker1"
set_peer_env "broker1" "Broker1MSP"

execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $TRADING_CHANNEL -n $ORDER_MATCHING_CC \
  --peerAddresses peer0.broker1:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
  -c '{\"Args\":[\"CreateOrder\",\"BUY004\",\"BROKER1\",\"SEC001\",\"buy\",\"150\",\"150.50\"]}'" \
  "Failed to create buy order BUY004"
sleep 2

execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $TRADING_CHANNEL -n $ORDER_MATCHING_CC \
  --peerAddresses peer0.broker1:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
  -c '{\"Args\":[\"CreateOrder\",\"BUY005\",\"BROKER1\",\"SEC002\",\"buy\",\"75\",\"301.00\"]}'" \
  "Failed to create buy order BUY005"
sleep 2

# Create more sell orders
log "Creating additional sell orders from broker2"
set_peer_env "broker2" "Broker2MSP"

execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $TRADING_CHANNEL -n $ORDER_MATCHING_CC \
  --peerAddresses peer0.broker2:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
  -c '{\"Args\":[\"CreateOrder\",\"SELL004\",\"BROKER2\",\"SEC001\",\"sell\",\"150\",\"150.25\"]}'" \
  "Failed to create sell order SELL004"
sleep 2

execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $TRADING_CHANNEL -n $ORDER_MATCHING_CC \
  --peerAddresses peer0.broker2:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
  -c '{\"Args\":[\"CreateOrder\",\"SELL005\",\"BROKER2\",\"SEC002\",\"sell\",\"75\",\"300.80\"]}'" \
  "Failed to create sell order SELL005"
sleep 2

# Match new orders
log "Matching new orders"
set_peer_env "stockmarket" "StockMarketMSP"

execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $TRADING_CHANNEL -n $ORDER_MATCHING_CC \
  --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
  -c '{\"Args\":[\"MatchOrders\",\"SEC001\"]}'" \
  "Failed to match orders for SEC001"
sleep 5

execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $TRADING_CHANNEL -n $ORDER_MATCHING_CC \
  --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
  -c '{\"Args\":[\"MatchOrders\",\"SEC002\"]}'" \
  "Failed to match orders for SEC002"
sleep 5

# Get new trades
log "Getting new trades"
set_peer_env "stockmarket" "StockMarketMSP"

QUERY_CMD="peer chaincode query -C $TRADING_CHANNEL -n $ORDER_MATCHING_CC -c '{\"Args\":[\"GetAllTradesByStatus\",\"pending\"]}'"
NEW_TRADES=$($CLI bash -c "export CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH && \
export CORE_PEER_ADDRESS=$CORE_PEER_ADDRESS && \
export CORE_PEER_LOCALMSPID=$CORE_PEER_LOCALMSPID && \
export CORE_PEER_TLS_ROOTCERT_FILE=$CORE_PEER_TLS_ROOTCERT_FILE && \
$QUERY_CMD")

log "Found new trades: $NEW_TRADES"

# Parse new trades to get trade IDs
NEW_TRADE_IDS=()
while read -r line; do
  if [[ $line =~ \"tradeID\":\"([^\"]+)\" ]]; then
    NEW_TRADE_IDS+=("${BASH_REMATCH[1]}")
  fi
done < <(echo "$NEW_TRADES" | grep -o '"tradeID":"[^"]*')

log "New trade IDs: ${NEW_TRADE_IDS[*]}"

# Process new trades
log "Processing new trades"
for TRADE_ID in "${NEW_TRADE_IDS[@]}"; do
  log "Processing new trade: $TRADE_ID"
  
  # Follow the same process as for the initial trades
  # Get trade details from trading channel
  log "Getting details for new trade $TRADE_ID"
  QUERY_CMD="peer chaincode query -C $TRADING_CHANNEL -n $ORDER_MATCHING_CC -c '{\"Args\":[\"GetTrade\",\"$TRADE_ID\"]}'"
  TRADE_DETAILS=$($CLI bash -c "export CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH && \
  export CORE_PEER_ADDRESS=$CORE_PEER_ADDRESS && \
  export CORE_PEER_LOCALMSPID=$CORE_PEER_LOCALMSPID && \
  export CORE_PEER_TLS_ROOTCERT_FILE=$CORE_PEER_TLS_ROOTCERT_FILE && \
  $QUERY_CMD")
  check_success "Retrieved new trade details from trading channel"
  
  # Extract necessary fields for processing
  BUY_ORDER_ID=$(echo $TRADE_DETAILS | grep -o '"buyOrderID":"[^"]*' | head -1 | cut -d'"' -f4)
  SELL_ORDER_ID=$(echo $TRADE_DETAILS | grep -o '"sellOrderID":"[^"]*' | head -1 | cut -d'"' -f4)
  BUY_BROKER_ID=$(echo $TRADE_DETAILS | grep -o '"buyBrokerID":"[^"]*' | head -1 | cut -d'"' -f4)
  SELL_BROKER_ID=$(echo $TRADE_DETAILS | grep -o '"sellBrokerID":"[^"]*' | head -1 | cut -d'"' -f4)
  SECURITY_ID=$(echo $TRADE_DETAILS | grep -o '"securityID":"[^"]*' | head -1 | cut -d'"' -f4)
  QUANTITY=$(echo $TRADE_DETAILS | grep -o '"quantity":[^,]*' | head -1 | cut -d':' -f2)
  PRICE=$(echo $TRADE_DETAILS | grep -o '"price":[^,]*' | head -1 | cut -d':' -f2)
  STATUS=$(echo $TRADE_DETAILS | grep -o '"status":"[^"]*' | head -1 | cut -d'"' -f4)
  MATCH_TIME=$(echo $TRADE_DETAILS | grep -o '"matchTime":"[^"]*' | head -1 | cut -d'"' -f4)
  
  # Import to regulatory channel
  log "Importing new trade $TRADE_ID to regulatory channel"
  set_peer_env "ammc" "AMMCMSP"
  
  execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $REGULATORY_CHANNEL -n $COMPLIANCE_CC \
    --peerAddresses peer0.ammc:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
    --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles ${DOCKER_CRYPTO_PATH}/stockmarket/peers/peer0.stockmarket/tls/ca.crt \
    -c '{\"Args\":[\"ImportTrade\",\"$TRADE_ID\",\"$BUY_ORDER_ID\",\"$SELL_ORDER_ID\",\"$BUY_BROKER_ID\",\"$SELL_BROKER_ID\",\"$SECURITY_ID\",\"$QUANTITY\",\"$PRICE\",\"$STATUS\",\"$MATCH_TIME\"]}'" \
    "Failed to import new trade to regulatory channel"
  sleep 3
  
  # Perform compliance check
  log "Performing compliance check for new trade $TRADE_ID"
  execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $REGULATORY_CHANNEL -n $COMPLIANCE_CC \
    --peerAddresses peer0.ammc:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
    --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles ${DOCKER_CRYPTO_PATH}/stockmarket/peers/peer0.stockmarket/tls/ca.crt \
    -c '{\"Args\":[\"PerformTradeCheck\",\"$TRADE_ID\",\"REGULATOR1\"]}'" \
    "Failed to perform compliance check for new trade"
  sleep 3
  
  # Get compliance check result
  CHECK_ID="check-$TRADE_ID"
  QUERY_CMD="peer chaincode query -C $REGULATORY_CHANNEL -n $COMPLIANCE_CC -c '{\"Args\":[\"GetComplianceCheck\",\"$CHECK_ID\"]}'"
  COMPLIANCE_CHECK=$($CLI bash -c "export CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH && \
  export CORE_PEER_ADDRESS=$CORE_PEER_ADDRESS && \
  export CORE_PEER_LOCALMSPID=$CORE_PEER_LOCALMSPID && \
  export CORE_PEER_TLS_ROOTCERT_FILE=$CORE_PEER_TLS_ROOTCERT_FILE && \
  $QUERY_CMD")
  
  # Extract compliance status
  COMPLIANCE_STATUS=$(echo $COMPLIANCE_CHECK | grep -o '"status":"[^"]*' | head -1 | cut -d'"' -f4)
  log "New trade compliance check status: $COMPLIANCE_STATUS"
  
  # Process if approved
  if [[ "$COMPLIANCE_STATUS" == "approved" ]]; then
    log "New trade $TRADE_ID was approved, proceeding with settlement"
    
    # Import to settlement channel
    log "Importing new approved trade to settlement channel"
    set_peer_env "maroclear" "MaroclearMSP"
    
    execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $SETTLEMENT_CHANNEL -n $SETTLEMENT_CC \
      --peerAddresses peer0.maroclear:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
      --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles ${DOCKER_CRYPTO_PATH}/stockmarket/peers/peer0.stockmarket/tls/ca.crt \
      -c '{\"Args\":[\"ImportTrade\",\"$TRADE_ID\",\"$BUY_ORDER_ID\",\"$SELL_ORDER_ID\",\"$BUY_BROKER_ID\",\"$SELL_BROKER_ID\",\"$SECURITY_ID\",\"$QUANTITY\",\"$PRICE\",\"$COMPLIANCE_STATUS\",\"$MATCH_TIME\"]}'" \
      "Failed to import new trade to settlement channel"
    sleep 3
    
    # Create settlement instruction
    log "Creating settlement instruction for new trade $TRADE_ID"
    execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $SETTLEMENT_CHANNEL -n $SETTLEMENT_CC \
      --peerAddresses peer0.maroclear:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
      --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles ${DOCKER_CRYPTO_PATH}/stockmarket/peers/peer0.stockmarket/tls/ca.crt \
      -c '{\"Args\":[\"CreateSettlementInstruction\",\"$TRADE_ID\"]}'" \
      "Failed to create settlement instruction for new trade"
    sleep 3
    
    # Execute settlement
    log "Executing settlement for new trade $TRADE_ID"
    execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $SETTLEMENT_CHANNEL -n $SETTLEMENT_CC \
      --peerAddresses peer0.maroclear:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
      --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles ${DOCKER_CRYPTO_PATH}/stockmarket/peers/peer0.stockmarket/tls/ca.crt \
      -c '{\"Args\":[\"ExecuteSettlement\",\"instruction-$TRADE_ID\"]}'" \
      "Failed to execute settlement for new trade"
    sleep 3
    
    # Update trade status in trading channel
    log "Updating new trade status to settled in trading channel"
    set_peer_env "stockmarket" "StockMarketMSP"
    
    execute_peer_command "peer chaincode invoke -o $ORDERER_ADDRESS --tls --cafile $ORDERER_CA -C $TRADING_CHANNEL -n $ORDER_MATCHING_CC \
      --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE \
      -c '{\"Args\":[\"UpdateTradeStatus\",\"$TRADE_ID\",\"settled\"]}'" \
      "Failed to update new trade status to settled in trading channel"
    sleep 3
  else
    log "New trade $TRADE_ID was not approved in compliance check, skipping settlement"
  fi
  
  log "Completed processing new trade: $TRADE_ID"
done

# Step 11: Generate Reports and Summary
log "Step 11: Generating summary of all processed trades"
set_peer_env "stockmarket" "StockMarketMSP"

# Get all settled trades
log "Getting all settled trades from trading channel"
QUERY_CMD="peer chaincode query -C $TRADING_CHANNEL -n $ORDER_MATCHING_CC -c '{\"Args\":[\"GetAllTradesByStatus\",\"settled\"]}'"
SETTLED_TRADES=$($CLI bash -c "export CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH && \
export CORE_PEER_ADDRESS=$CORE_PEER_ADDRESS && \
export CORE_PEER_LOCALMSPID=$CORE_PEER_LOCALMSPID && \
export CORE_PEER_TLS_ROOTCERT_FILE=$CORE_PEER_TLS_ROOTCERT_FILE && \
$QUERY_CMD")

# Count settled trades
SETTLED_COUNT=$(echo "$SETTLED_TRADES" | grep -o '"tradeID"' | wc -l)

# Get all pending trades
QUERY_CMD="peer chaincode query -C $TRADING_CHANNEL -n $ORDER_MATCHING_CC -c '{\"Args\":[\"GetAllTradesByStatus\",\"pending\"]}'"
PENDING_TRADES=$($CLI bash -c "export CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH && \
export CORE_PEER_ADDRESS=$CORE_PEER_ADDRESS && \
export CORE_PEER_LOCALMSPID=$CORE_PEER_LOCALMSPID && \
export CORE_PEER_TLS_ROOTCERT_FILE=$CORE_PEER_TLS_ROOTCERT_FILE && \
$QUERY_CMD")

# Count pending trades
PENDING_COUNT=$(echo "$PENDING_TRADES" | grep -o '"tradeID"' | wc -l)

# Get all rejected trades
QUERY_CMD="peer chaincode query -C $TRADING_CHANNEL -n $ORDER_MATCHING_CC -c '{\"Args\":[\"GetAllTradesByStatus\",\"rejected\"]}'"
REJECTED_TRADES=$($CLI bash -c "export CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH && \
export CORE_PEER_ADDRESS=$CORE_PEER_ADDRESS && \
export CORE_PEER_LOCALMSPID=$CORE_PEER_LOCALMSPID && \
export CORE_PEER_TLS_ROOTCERT_FILE=$CORE_PEER_TLS_ROOTCERT_FILE && \
$QUERY_CMD")

# Count rejected trades
REJECTED_COUNT=$(echo "$REJECTED_TRADES" | grep -o '"tradeID"' | wc -l)

# Display summary
log "============ STOCK MARKET INITIALIZATION SUMMARY ============"
log "Total Settled Trades: $SETTLED_COUNT"
log "Total Pending Trades: $PENDING_COUNT"
log "Total Rejected Trades: $REJECTED_COUNT"
log "==========================================================="

log "✅ All trades have been created, matched, processed through compliance, and settled where approved!"
log "The stock market blockchain network is now populated with sample data."
log ""
log "You can now query the trades, orders, and settlement instructions using the CLI container."
log ""
log "For trades:"
log "$CLI bash -c \"export CORE_PEER_MSPCONFIGPATH=${DOCKER_CRYPTO_PATH}/stockmarket/users/Admin@stockmarket/msp && \\"
log "export CORE_PEER_ADDRESS=peer0.stockmarket:7051 && \\"
log "export CORE_PEER_LOCALMSPID=StockMarketMSP && \\"
log "export CORE_PEER_TLS_ROOTCERT_FILE=${DOCKER_CRYPTO_PATH}/stockmarket/peers/peer0.stockmarket/tls/ca.crt && \\"
log "peer chaincode query -C trading-channel -n order-matching -c '{\\\"Args\\\":[\\\"GetAllTradesByStatus\\\",\\\"settled\\\"]}'\""
log ""
log "For orders:"
log "$CLI bash -c \"export CORE_PEER_MSPCONFIGPATH=${DOCKER_CRYPTO_PATH}/broker1/users/Admin@broker1/msp && \\"
log "export CORE_PEER_ADDRESS=peer0.broker1:7051 && \\"
log "export CORE_PEER_LOCALMSPID=Broker1MSP && \\"
log "export CORE_PEER_TLS_ROOTCERT_FILE=${DOCKER_CRYPTO_PATH}/broker1/peers/peer0.broker1/tls/ca.crt && \\"
log "peer chaincode query -C trading-channel -n order-matching -c '{\\\"Args\\\":[\\\"GetOrder\\\",\\\"BUY001\\\"]}'\""
log ""
log "For settlement instructions:"
log "$CLI bash -c \"export CORE_PEER_MSPCONFIGPATH=${DOCKER_CRYPTO_PATH}/maroclear/users/Admin@maroclear/msp && \\"
log "export CORE_PEER_ADDRESS=peer0.maroclear:7051 && \\"
log "export CORE_PEER_LOCALMSPID=MaroclearMSP && \\"
log "export CORE_PEER_TLS_ROOTCERT_FILE=${DOCKER_CRYPTO_PATH}/maroclear/peers/peer0.maroclear/tls/ca.crt && \\"
log "peer chaincode query -C settlement-channel -n settlement -c '{\\\"Args\\\":[\\\"GetSettlementInstruction\\\",\\\"instruction-trade-BUY001-SELL001-0\\\"]}'\""
log ""
log "For compliance checks:"
log "$CLI bash -c \"export CORE_PEER_MSPCONFIGPATH=${DOCKER_CRYPTO_PATH}/ammc/users/Admin@ammc/msp && \\"
log "export CORE_PEER_ADDRESS=peer0.ammc:7051 && \\"
log "export CORE_PEER_LOCALMSPID=AMMCMSP && \\"
log "export CORE_PEER_TLS_ROOTCERT_FILE=${DOCKER_CRYPTO_PATH}/ammc/peers/peer0.ammc/tls/ca.crt && \\"
log "peer chaincode query -C regulatory-channel -n compliance -c '{\\\"Args\\\":[\\\"GetComplianceCheck\\\",\\\"check-trade-BUY001-SELL001-0\\\"]}'\""