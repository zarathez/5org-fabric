#!/bin/bash

# Exit on first error
set -e

echo "Starting the registration and enrollment process for all organizations..."

# Create a function to register and enroll identities for an organization
function registerEnrollOrg() {
    ORG=$1
    MSP_ID=$2
    CA_PORT=$3
    ORG_TYPE=$4  # New parameter to identify the type of organization

    echo "Processing organization: $ORG (MSP ID: $MSP_ID, CA Port: $CA_PORT, Type: $ORG_TYPE)"

    # Create directories
    mkdir -p organizations/$ORG/
    mkdir -p organizations/$ORG/peers/peer0.$ORG
    mkdir -p organizations/$ORG/users/Admin@$ORG

    # Set the CA client home
    export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/$ORG/ca

    # Get TLS certificates first if they don't exist
    if [ ! -f "${PWD}/organizations/$ORG/ca/tls-cert.pem" ]; then
        echo "Retrieving TLS certificate for $ORG CA..."
        mkdir -p ${PWD}/organizations/$ORG/ca
        cp ${PWD}/organizations/$ORG/ca/ca-cert.pem ${PWD}/organizations/$ORG/ca/tls-cert.pem
    fi

    # Enroll the CA admin
    echo "Enrolling CA admin for $ORG..."
    fabric-ca-client enroll -u https://admin:adminpw@localhost:$CA_PORT --caname ca-$ORG --tls.certfiles ${PWD}/organizations/$ORG/ca/tls-cert.pem

    # Register the org admin and peer
    echo "Registering admin and peer identities for $ORG..."
    fabric-ca-client register --caname ca-$ORG --id.name ${ORG}admin --id.secret ${ORG}adminpw --id.type admin --tls.certfiles ${PWD}/organizations/$ORG/ca/tls-cert.pem
    fabric-ca-client register --caname ca-$ORG --id.name peer0.$ORG --id.secret peer0pw --id.type peer --tls.certfiles ${PWD}/organizations/$ORG/ca/tls-cert.pem

    # If this is a broker, register additional users for client management
    if [ "$ORG_TYPE" == "broker" ]; then
        echo "Registering client manager for broker $ORG..."
        fabric-ca-client register --caname ca-$ORG --id.name ${ORG}client --id.secret ${ORG}clientpw --id.type client --id.attrs "role=client-manager:ecert" --tls.certfiles ${PWD}/organizations/$ORG/ca/tls-cert.pem
    fi

    # If this is the stockmarket, register a trading engine user
    if [ "$ORG_TYPE" == "exchange" ]; then
        echo "Registering trading engine for exchange $ORG..."
        fabric-ca-client register --caname ca-$ORG --id.name ${ORG}engine --id.secret ${ORG}enginepw --id.type client --id.attrs "role=trading-engine:ecert" --tls.certfiles ${PWD}/organizations/$ORG/ca/tls-cert.pem
    fi

    # If this is the Maroclear, register a settlement manager
    if [ "$ORG_TYPE" == "maroclear" ]; then
        echo "Registering settlement manager for $ORG..."
        fabric-ca-client register --caname ca-$ORG --id.name ${ORG}settle --id.secret ${ORG}settlepw --id.type client --id.attrs "role=settlement-manager:ecert" --tls.certfiles ${PWD}/organizations/$ORG/ca/tls-cert.pem
    fi

    # Enroll the org admin
    echo "Enrolling admin identity for $ORG..."
    fabric-ca-client enroll -u https://${ORG}admin:${ORG}adminpw@localhost:$CA_PORT --caname ca-$ORG -M ${PWD}/organizations/$ORG/users/Admin@$ORG/msp --tls.certfiles ${PWD}/organizations/$ORG/ca/tls-cert.pem

    # Enroll the peer identity (msp)
    echo "Enrolling peer identity for $ORG..."
    fabric-ca-client enroll -u https://peer0.$ORG:peer0pw@localhost:$CA_PORT --caname ca-$ORG -M ${PWD}/organizations/$ORG/peers/peer0.$ORG/msp --csr.hosts peer0.$ORG --tls.certfiles ${PWD}/organizations/$ORG/ca/tls-cert.pem

    # Enroll the peer for TLS
    echo "Enrolling peer TLS certificate for $ORG..."
    fabric-ca-client enroll -u https://peer0.$ORG:peer0pw@localhost:$CA_PORT --caname ca-$ORG -M ${PWD}/organizations/$ORG/peers/peer0.$ORG/tls --enrollment.profile tls --csr.hosts peer0.$ORG --csr.hosts localhost --tls.certfiles ${PWD}/organizations/$ORG/ca/tls-cert.pem

    # Enroll any special users based on organization type
    if [ "$ORG_TYPE" == "broker" ]; then
        echo "Enrolling client manager identity for broker $ORG..."
        mkdir -p ${PWD}/organizations/$ORG/users/Client@$ORG
        fabric-ca-client enroll -u https://${ORG}client:${ORG}clientpw@localhost:$CA_PORT --caname ca-$ORG -M ${PWD}/organizations/$ORG/users/Client@$ORG/msp --tls.certfiles ${PWD}/organizations/$ORG/ca/tls-cert.pem
    fi

    if [ "$ORG_TYPE" == "exchange" ]; then
        echo "Enrolling trading engine identity for exchange $ORG..."
        mkdir -p ${PWD}/organizations/$ORG/users/Engine@$ORG
        fabric-ca-client enroll -u https://${ORG}engine:${ORG}enginepw@localhost:$CA_PORT --caname ca-$ORG -M ${PWD}/organizations/$ORG/users/Engine@$ORG/msp --tls.certfiles ${PWD}/organizations/$ORG/ca/tls-cert.pem
    fi

    if [ "$ORG_TYPE" == "maroclear" ]; then
        echo "Enrolling settlement manager identity for $ORG..."
        mkdir -p ${PWD}/organizations/$ORG/users/Settle@$ORG
        fabric-ca-client enroll -u https://${ORG}settle:${ORG}settlepw@localhost:$CA_PORT --caname ca-$ORG -M ${PWD}/organizations/$ORG/users/Settle@$ORG/msp --tls.certfiles ${PWD}/organizations/$ORG/ca/tls-cert.pem
    fi

    # Create MSP config.yaml
    echo "Creating MSP config.yaml for $ORG..."
    cat > ${PWD}/organizations/$ORG/peers/peer0.$ORG/msp/config.yaml << EOF
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/localhost-$CA_PORT-ca-$ORG.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/localhost-$CA_PORT-ca-$ORG.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/localhost-$CA_PORT-ca-$ORG.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/localhost-$CA_PORT-ca-$ORG.pem
    OrganizationalUnitIdentifier: orderer
EOF

    # Copy the config.yaml to admin MSP directory as well
    cp ${PWD}/organizations/$ORG/peers/peer0.$ORG/msp/config.yaml ${PWD}/organizations/$ORG/users/Admin@$ORG/msp/config.yaml

    # Copy to special user directories if they exist
    if [ -d "${PWD}/organizations/$ORG/users/Client@$ORG/msp" ]; then
        cp ${PWD}/organizations/$ORG/peers/peer0.$ORG/msp/config.yaml ${PWD}/organizations/$ORG/users/Client@$ORG/msp/config.yaml
    fi

    if [ -d "${PWD}/organizations/$ORG/users/Engine@$ORG/msp" ]; then
        cp ${PWD}/organizations/$ORG/peers/peer0.$ORG/msp/config.yaml ${PWD}/organizations/$ORG/users/Engine@$ORG/msp/config.yaml
    fi

    if [ -d "${PWD}/organizations/$ORG/users/Settle@$ORG/msp" ]; then
        cp ${PWD}/organizations/$ORG/peers/peer0.$ORG/msp/config.yaml ${PWD}/organizations/$ORG/users/Settle@$ORG/msp/config.yaml
    fi

    # Copy TLS CA cert files to appropriate location
    cp ${PWD}/organizations/$ORG/peers/peer0.$ORG/tls/tlscacerts/* ${PWD}/organizations/$ORG/peers/peer0.$ORG/tls/ca.crt
    cp ${PWD}/organizations/$ORG/peers/peer0.$ORG/tls/signcerts/* ${PWD}/organizations/$ORG/peers/peer0.$ORG/tls/server.crt
    cp ${PWD}/organizations/$ORG/peers/peer0.$ORG/tls/keystore/* ${PWD}/organizations/$ORG/peers/peer0.$ORG/tls/server.key

    # Copy peer org's CA cert to peers/tlscacerts directory
    mkdir -p ${PWD}/organizations/$ORG/peers/peer0.$ORG/tlscacerts
    cp ${PWD}/organizations/$ORG/peers/peer0.$ORG/tls/tlscacerts/* ${PWD}/organizations/$ORG/peers/peer0.$ORG/tlscacerts/ca.crt

    # Copy peer org's CA cert to users/tlscacerts directory
    mkdir -p ${PWD}/organizations/$ORG/users/Admin@$ORG/tlscacerts
    cp ${PWD}/organizations/$ORG/peers/peer0.$ORG/tls/tlscacerts/* ${PWD}/organizations/$ORG/users/Admin@$ORG/tlscacerts/ca.crt

    # Create organization-level MSP structure
    echo "Creating organization-level MSP structure for $ORG..."
    mkdir -p ${PWD}/organizations/$ORG/msp/cacerts
    mkdir -p ${PWD}/organizations/$ORG/msp/tlscacerts
    mkdir -p ${PWD}/organizations/$ORG/msp/admincerts
    mkdir -p ${PWD}/organizations/$ORG/msp/signcerts

    # Copy certificates to the organization-level MSP
    cp ${PWD}/organizations/$ORG/peers/peer0.$ORG/msp/cacerts/* ${PWD}/organizations/$ORG/msp/cacerts/
    cp ${PWD}/organizations/$ORG/peers/peer0.$ORG/tls/tlscacerts/* ${PWD}/organizations/$ORG/msp/tlscacerts/
    cp ${PWD}/organizations/$ORG/users/Admin@$ORG/msp/signcerts/* ${PWD}/organizations/$ORG/msp/admincerts/

    # Copy config.yaml to organization-level MSP
    cp ${PWD}/organizations/$ORG/peers/peer0.$ORG/msp/config.yaml ${PWD}/organizations/$ORG/msp/

    echo "✅ Registration and enrollment completed for $ORG"
}

# Register and enroll for Orderer
function registerEnrollOrderer() {
    ORG="orderer"
    MSP_ID="OrdererMSP"
    CA_PORT=12054

    echo "Processing ordering organization: $ORG (MSP ID: $MSP_ID, CA Port: $CA_PORT)"

    # Create directories
    mkdir -p organizations/$ORG/
    mkdir -p organizations/$ORG/orderers/orderer0.orderer
    mkdir -p organizations/$ORG/orderers/orderer1.orderer
    mkdir -p organizations/$ORG/orderers/orderer2.orderer
    mkdir -p organizations/$ORG/users/Admin@$ORG

    # Set the CA client home
    export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/$ORG/ca

    # Get TLS certificates first if they don't exist
    if [ ! -f "${PWD}/organizations/$ORG/ca/tls-cert.pem" ]; then
        echo "Retrieving TLS certificate for $ORG CA..."
        mkdir -p ${PWD}/organizations/$ORG/ca
        cp ${PWD}/organizations/$ORG/ca/ca-cert.pem ${PWD}/organizations/$ORG/ca/tls-cert.pem
    fi

    # Enroll the CA admin
    echo "Enrolling CA admin for $ORG..."
    fabric-ca-client enroll -u https://admin:adminpw@localhost:$CA_PORT --caname ca-$ORG --tls.certfiles ${PWD}/organizations/$ORG/ca/tls-cert.pem

    # Register the org admin and orderers
    echo "Registering admin and orderer identities for $ORG..."
    fabric-ca-client register --caname ca-$ORG --id.name ${ORG}admin --id.secret ${ORG}adminpw --id.type admin --tls.certfiles ${PWD}/organizations/$ORG/ca/tls-cert.pem
    
    # Register orderer nodes
    fabric-ca-client register --caname ca-$ORG --id.name orderer0.orderer --id.secret ordererpw --id.type orderer --tls.certfiles ${PWD}/organizations/$ORG/ca/tls-cert.pem
    fabric-ca-client register --caname ca-$ORG --id.name orderer1.orderer --id.secret ordererpw --id.type orderer --tls.certfiles ${PWD}/organizations/$ORG/ca/tls-cert.pem
    fabric-ca-client register --caname ca-$ORG --id.name orderer2.orderer --id.secret ordererpw --id.type orderer --tls.certfiles ${PWD}/organizations/$ORG/ca/tls-cert.pem

    # Enroll the org admin
    echo "Enrolling admin identity for $ORG..."
    fabric-ca-client enroll -u https://${ORG}admin:${ORG}adminpw@localhost:$CA_PORT --caname ca-$ORG -M ${PWD}/organizations/$ORG/users/Admin@$ORG/msp --tls.certfiles ${PWD}/organizations/$ORG/ca/tls-cert.pem

    # Enroll orderer nodes
    # For orderer0
    echo "Enrolling orderer0 identity for $ORG..."
    fabric-ca-client enroll -u https://orderer0.orderer:ordererpw@localhost:$CA_PORT --caname ca-$ORG -M ${PWD}/organizations/$ORG/orderers/orderer0.orderer/msp --csr.hosts orderer0.orderer --csr.hosts localhost --tls.certfiles ${PWD}/organizations/$ORG/ca/tls-cert.pem
    
    echo "Enrolling orderer0 TLS certificate for $ORG..."
    fabric-ca-client enroll -u https://orderer0.orderer:ordererpw@localhost:$CA_PORT --caname ca-$ORG -M ${PWD}/organizations/$ORG/orderers/orderer0.orderer/tls --enrollment.profile tls --csr.hosts orderer0.orderer --csr.hosts localhost --tls.certfiles ${PWD}/organizations/$ORG/ca/tls-cert.pem

    # For orderer1
    echo "Enrolling orderer1 identity for $ORG..."
    fabric-ca-client enroll -u https://orderer1.orderer:ordererpw@localhost:$CA_PORT --caname ca-$ORG -M ${PWD}/organizations/$ORG/orderers/orderer1.orderer/msp --csr.hosts orderer1.orderer --csr.hosts localhost --tls.certfiles ${PWD}/organizations/$ORG/ca/tls-cert.pem
    
    echo "Enrolling orderer1 TLS certificate for $ORG..."
    fabric-ca-client enroll -u https://orderer1.orderer:ordererpw@localhost:$CA_PORT --caname ca-$ORG -M ${PWD}/organizations/$ORG/orderers/orderer1.orderer/tls --enrollment.profile tls --csr.hosts orderer1.orderer --csr.hosts localhost --tls.certfiles ${PWD}/organizations/$ORG/ca/tls-cert.pem

    # For orderer2
    echo "Enrolling orderer2 identity for $ORG..."
    fabric-ca-client enroll -u https://orderer2.orderer:ordererpw@localhost:$CA_PORT --caname ca-$ORG -M ${PWD}/organizations/$ORG/orderers/orderer2.orderer/msp --csr.hosts orderer2.orderer --csr.hosts localhost --tls.certfiles ${PWD}/organizations/$ORG/ca/tls-cert.pem
    
    echo "Enrolling orderer2 TLS certificate for $ORG..."
    fabric-ca-client enroll -u https://orderer2.orderer:ordererpw@localhost:$CA_PORT --caname ca-$ORG -M ${PWD}/organizations/$ORG/orderers/orderer2.orderer/tls --enrollment.profile tls --csr.hosts orderer2.orderer --csr.hosts localhost --tls.certfiles ${PWD}/organizations/$ORG/ca/tls-cert.pem

    # Create MSP config.yaml
    echo "Creating MSP config.yaml for $ORG..."
    cat > ${PWD}/organizations/$ORG/orderers/orderer0.orderer/msp/config.yaml << EOF
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/localhost-$CA_PORT-ca-$ORG.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/localhost-$CA_PORT-ca-$ORG.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/localhost-$CA_PORT-ca-$ORG.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/localhost-$CA_PORT-ca-$ORG.pem
    OrganizationalUnitIdentifier: orderer
EOF
    echo "successfully created the config file"
    # Copy the config.yaml to other orderers
    cp ${PWD}/organizations/$ORG/orderers/orderer0.orderer/msp/config.yaml ${PWD}/organizations/$ORG/orderers/orderer1.orderer/msp/config.yaml
    cp ${PWD}/organizations/$ORG/orderers/orderer0.orderer/msp/config.yaml ${PWD}/organizations/$ORG/orderers/orderer2.orderer/msp/config.yaml
    cp ${PWD}/organizations/$ORG/orderers/orderer0.orderer/msp/config.yaml ${PWD}/organizations/$ORG/users/Admin@$ORG/msp/config.yaml
    
    
    # Process TLS certificates for each orderer
    for ORDERER in orderer0.orderer orderer1.orderer orderer2.orderer; do
        cp ${PWD}/organizations/$ORG/orderers/$ORDERER/tls/tlscacerts/* ${PWD}/organizations/$ORG/orderers/$ORDERER/tls/ca.crt
        cp ${PWD}/organizations/$ORG/orderers/$ORDERER/tls/signcerts/* ${PWD}/organizations/$ORG/orderers/$ORDERER/tls/server.crt
        cp ${PWD}/organizations/$ORG/orderers/$ORDERER/tls/keystore/* ${PWD}/organizations/$ORG/orderers/$ORDERER/tls/server.key
        
        # Create RAFT TLS folder structure
        mkdir -p ${PWD}/organizations/$ORG/orderers/$ORDERER/msp/tlscacerts
        cp ${PWD}/organizations/$ORG/orderers/$ORDERER/tls/tlscacerts/* ${PWD}/organizations/$ORG/orderers/$ORDERER/msp/tlscacerts/ca.crt
    done
    
    # Copy orderer org's CA cert to users/tlscacerts directory
    mkdir -p ${PWD}/organizations/$ORG/users/Admin@$ORG/tlscacerts
    cp ${PWD}/organizations/$ORG/orderers/orderer0.orderer/tls/tlscacerts/* ${PWD}/organizations/$ORG/users/Admin@$ORG/tlscacerts/ca.crt

    # Create organization-level MSP structure for OrdererMSP
    echo "Creating organization-level MSP structure for $ORG..."
    mkdir -p ${PWD}/organizations/$ORG/msp/cacerts
    mkdir -p ${PWD}/organizations/$ORG/msp/tlscacerts
    mkdir -p ${PWD}/organizations/$ORG/msp/admincerts
    mkdir -p ${PWD}/organizations/$ORG/msp/signcerts

    # Copy certificates to the organization-level MSP
    cp ${PWD}/organizations/$ORG/orderers/orderer0.orderer/msp/cacerts/* ${PWD}/organizations/$ORG/msp/cacerts/
    cp ${PWD}/organizations/$ORG/orderers/orderer0.orderer/tls/tlscacerts/* ${PWD}/organizations/$ORG/msp/tlscacerts/
    cp ${PWD}/organizations/$ORG/users/Admin@$ORG/msp/signcerts/* ${PWD}/organizations/$ORG/msp/admincerts/

    # Copy config.yaml to organization-level MSP
    cp ${PWD}/organizations/$ORG/orderers/orderer0.orderer/msp/config.yaml ${PWD}/organizations/$ORG/msp/

    echo "✅ Registration and enrollment completed for ordering organization"
}

# Register and enroll for all organizations
# Organizations with their specific types
echo "================ StockMarket (Exchange) ================"
registerEnrollOrg "stockmarket" "StockMarketMSP" "7054" "exchange"

echo "================ Maroclear (Central Depository) ================"
registerEnrollOrg "maroclear" "MaroclearMSP" "8054" "maroclear"

echo "================ Broker1 ================"
registerEnrollOrg "broker1" "Broker1MSP" "9054" "broker"

echo "================ Broker2 ================"
registerEnrollOrg "broker2" "Broker2MSP" "10054" "broker"

echo "================ Orderer Organization ================"
registerEnrollOrderer

echo "All organizations have been registered and enrolled successfully!"

# Set proper permissions for MSP directories to ensure they're accessible
echo "Setting appropriate permissions on MSP directories..."
for ORG in stockmarket maroclear broker1 broker2 orderer; do
  chmod -R 755 ${PWD}/organizations/${ORG}/users/Admin@${ORG}/msp
  echo "Set permissions for ${ORG} admin MSP"
  
  # Set permissions for special users if they exist
  if [ -d "${PWD}/organizations/${ORG}/users/Client@${ORG}/msp" ]; then
    chmod -R 755 ${PWD}/organizations/${ORG}/users/Client@${ORG}/msp
    echo "Set permissions for ${ORG} client manager MSP"
  fi
  
  if [ -d "${PWD}/organizations/${ORG}/users/Engine@${ORG}/msp" ]; then
    chmod -R 755 ${PWD}/organizations/${ORG}/users/Engine@${ORG}/msp
    echo "Set permissions for ${ORG} trading engine MSP"
  fi
  
  if [ -d "${PWD}/organizations/${ORG}/users/Settle@${ORG}/msp" ]; then
    chmod -R 755 ${PWD}/organizations/${ORG}/users/Settle@${ORG}/msp
    echo "Set permissions for ${ORG} settlement manager MSP"
  fi
done

# Create channel and chaincode directories with enhanced context for specific org types
echo "Creating channel-specific structure..."
mkdir -p ${PWD}/chaincode-context/trading
mkdir -p ${PWD}/chaincode-context/settlement

# Create organization-context files to help with deployment
cat > ${PWD}/chaincode-context/trading/context.json << EOF
{
  "channel": "trading-channel",
  "chaincode": "order-matching",
  "primary_orgs": ["StockMarketMSP", "Broker1MSP", "Broker2MSP"],
  "endorsement_policy": "OR('StockMarketMSP.peer','Broker1MSP.peer','Broker2MSP.peer')",
  "functions": [
    "createOrder",
    "cancelOrder",
    "matchOrders",
    "getOrder",
    "getMatchedTrade"
  ]
}
EOF

cat > ${PWD}/chaincode-context/settlement/context.json << EOF
{
  "channel": "settlement-channel",
  "chaincode": "settlement",
  "primary_orgs": ["MaroclearMSP", "StockMarketMSP", "Broker1MSP", "Broker2MSP"],
  "endorsement_policy": "AND('MaroclearMSP.peer',OR('StockMarketMSP.peer','Broker1MSP.peer','Broker2MSP.peer'))",
  "functions": [
    "createBrokerAccount",
    "createClientAccount",
    "createSettlementInstruction",
    "settleTrade",
    "depositFunds",
    "withdrawFunds"
  ]
}
EOF

echo "All organizations have been registered, enrolled, and permissions set successfully!"
echo "Channel context files created to support new workflow deployment."