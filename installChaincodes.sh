#!/bin/bash

# Exit on first error
set -e

# Variables
TRADING_CHANNEL="trading-channel"
SETTLEMENT_CHANNEL="settlement-channel"
ORDERER_ADDR="orderer0.orderer:7050"
ORDERER_CA="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/orderer/orderers/orderer0.orderer/tls/ca.crt"

# Define the endorsement policies with single quotes to avoid shell interpretation issues
POLICY_TRADING='OR("StockMarketMSP.peer","Broker1MSP.peer","Broker2MSP.peer")'
POLICY_SETTLEMENT='AND("MaroclearMSP.peer",OR("StockMarketMSP.peer","Broker1MSP.peer","Broker2MSP.peer"))'

# Create packages directory if it doesn't exist
mkdir -p ./packages

echo "Setting up go modules for chaincodes..."

# Setup proper Go modules for each chaincode
for CC_DIR in order-matching settlement; do
  echo "Preparing $CC_DIR chaincode..."
  
  # Create proper go.mod file with Go 1.17
  cat > ./chaincodes/$CC_DIR/go.mod << EOF
module github.com/hyperledger/fabric-samples/chaincode/$CC_DIR

go 1.17

require github.com/hyperledger/fabric-contract-api-go v1.2.1

require (
	github.com/go-openapi/jsonpointer v0.19.5 // indirect
	github.com/go-openapi/jsonreference v0.20.0 // indirect
	github.com/go-openapi/spec v0.20.8 // indirect
	github.com/go-openapi/swag v0.21.1 // indirect
	github.com/gobuffalo/envy v1.10.1 // indirect
	github.com/gobuffalo/packd v1.0.1 // indirect
	github.com/gobuffalo/packr v1.30.1 // indirect
	github.com/golang/protobuf v1.5.2 // indirect
	github.com/hyperledger/fabric-chaincode-go v0.0.0-20230228194215-b84622ba6a7a // indirect
	github.com/hyperledger/fabric-protos-go v0.3.0 // indirect
	github.com/joho/godotenv v1.4.0 // indirect
	github.com/josharian/intern v1.0.0 // indirect
	github.com/mailru/easyjson v0.7.7 // indirect
	github.com/rogpeppe/go-internal v1.9.0 // indirect
	github.com/xeipuuv/gojsonpointer v0.0.0-20190905194746-02993c407bfb // indirect
	github.com/xeipuuv/gojsonreference v0.0.0-20180127040603-bd5ef7bd5415 // indirect
	github.com/xeipuuv/gojsonschema v1.2.0 // indirect
	golang.org/x/net v0.7.0 // indirect
	golang.org/x/sys v0.5.0 // indirect
	golang.org/x/text v0.7.0 // indirect
	google.golang.org/genproto v0.0.0-20230110181048-76db0878b65f // indirect
	google.golang.org/grpc v1.53.0 // indirect
	google.golang.org/protobuf v1.28.1 // indirect
	gopkg.in/yaml.v2 v2.4.0 // indirect
)
EOF

  # Go into the chaincode directory and run go mod tidy and vendor
  (cd ./chaincodes/$CC_DIR && go mod tidy && go mod vendor)
done

echo "Go modules setup complete."

echo "Packaging chaincodes..."

# Package order-matching chaincode (Trading channel)
if [ ! -f "./packages/order-matching.tar.gz" ]; then
  echo "Creating order-matching package..."
  peer lifecycle chaincode package ./packages/order-matching.tar.gz --path ./chaincodes/order-matching --lang golang --label order-matching_1
fi

# Package settlement chaincode (Settlement channel)
if [ ! -f "./packages/settlement.tar.gz" ]; then
  echo "Creating settlement package..."
  peer lifecycle chaincode package ./packages/settlement.tar.gz --path ./chaincodes/settlement --lang golang --label settlement_1
fi

echo "✅ Chaincodes packaged"

# Copy packages to CLI container
echo "Copying packages to CLI container..."
docker cp ./packages/order-matching.tar.gz cli:/opt/gopath/src/github.com/hyperledger/fabric/peer/
docker cp ./packages/settlement.tar.gz cli:/opt/gopath/src/github.com/hyperledger/fabric/peer/

############################################################
# INSTALL AND APPROVE ORDER-MATCHING CHAINCODE ON TRADING CHANNEL
############################################################
echo "Installing order-matching chaincode for the Trading channel..."

# Install on StockMarket peer
echo "Installing on StockMarket peer..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/users/Admin@stockmarket/msp && \
export CORE_PEER_ADDRESS=peer0.stockmarket:7051 && \
export CORE_PEER_LOCALMSPID=StockMarketMSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/peers/peer0.stockmarket/tls/ca.crt && \
peer lifecycle chaincode install /opt/gopath/src/github.com/hyperledger/fabric/peer/order-matching.tar.gz && \
PACKAGE_ID=\$(peer lifecycle chaincode queryinstalled | grep 'order-matching_1' | awk '{print \$3}' | sed 's/,//') && \
echo \$PACKAGE_ID > /opt/gopath/src/github.com/hyperledger/fabric/peer/package_id_stockmarket.txt"
PACKAGE_ID_STOCKMARKET=$(docker exec cli cat /opt/gopath/src/github.com/hyperledger/fabric/peer/package_id_stockmarket.txt)

# Install on Broker1 peer
echo "Installing on Broker1 peer..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker1/users/Admin@broker1/msp && \
export CORE_PEER_ADDRESS=peer0.broker1:7051 && \
export CORE_PEER_LOCALMSPID=Broker1MSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker1/peers/peer0.broker1/tls/ca.crt && \
peer lifecycle chaincode install /opt/gopath/src/github.com/hyperledger/fabric/peer/order-matching.tar.gz && \
PACKAGE_ID=\$(peer lifecycle chaincode queryinstalled | grep 'order-matching_1' | awk '{print \$3}' | sed 's/,//') && \
echo \$PACKAGE_ID > /opt/gopath/src/github.com/hyperledger/fabric/peer/package_id_broker1.txt"
PACKAGE_ID_BROKER1=$(docker exec cli cat /opt/gopath/src/github.com/hyperledger/fabric/peer/package_id_broker1.txt)

# Install on Broker2 peer
echo "Installing on Broker2 peer..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker2/users/Admin@broker2/msp && \
export CORE_PEER_ADDRESS=peer0.broker2:7051 && \
export CORE_PEER_LOCALMSPID=Broker2MSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker2/peers/peer0.broker2/tls/ca.crt && \
peer lifecycle chaincode install /opt/gopath/src/github.com/hyperledger/fabric/peer/order-matching.tar.gz && \
PACKAGE_ID=\$(peer lifecycle chaincode queryinstalled | grep 'order-matching_1' | awk '{print \$3}' | sed 's/,//') && \
echo \$PACKAGE_ID > /opt/gopath/src/github.com/hyperledger/fabric/peer/package_id_broker2.txt"
PACKAGE_ID_BROKER2=$(docker exec cli cat /opt/gopath/src/github.com/hyperledger/fabric/peer/package_id_broker2.txt)

echo "✅ Order-matching chaincode installed on peers for Trading channel"

echo "Approving order-matching chaincode for all organizations..."

# Approve chaincode for StockMarket
echo "Approving for StockMarket..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/users/Admin@stockmarket/msp && \
export CORE_PEER_ADDRESS=peer0.stockmarket:7051 && \
export CORE_PEER_LOCALMSPID=StockMarketMSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/peers/peer0.stockmarket/tls/ca.crt && \
peer lifecycle chaincode approveformyorg -o $ORDERER_ADDR --channelID $TRADING_CHANNEL --name order-matching --version 1.0 --package-id $PACKAGE_ID_STOCKMARKET --sequence 1 --signature-policy '$POLICY_TRADING' --tls --cafile $ORDERER_CA"

# Approve chaincode for Broker1
echo "Approving for Broker1..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker1/users/Admin@broker1/msp && \
export CORE_PEER_ADDRESS=peer0.broker1:7051 && \
export CORE_PEER_LOCALMSPID=Broker1MSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker1/peers/peer0.broker1/tls/ca.crt && \
peer lifecycle chaincode approveformyorg -o $ORDERER_ADDR --channelID $TRADING_CHANNEL --name order-matching --version 1.0 --package-id $PACKAGE_ID_BROKER1 --sequence 1 --signature-policy '$POLICY_TRADING' --tls --cafile $ORDERER_CA"

# Approve chaincode for Broker2
echo "Approving for Broker2..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker2/users/Admin@broker2/msp && \
export CORE_PEER_ADDRESS=peer0.broker2:7051 && \
export CORE_PEER_LOCALMSPID=Broker2MSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker2/peers/peer0.broker2/tls/ca.crt && \
peer lifecycle chaincode approveformyorg -o $ORDERER_ADDR --channelID $TRADING_CHANNEL --name order-matching --version 1.0 --package-id $PACKAGE_ID_BROKER2 --sequence 1 --signature-policy '$POLICY_TRADING' --tls --cafile $ORDERER_CA"

echo "✅ Order-matching chaincode approved by all organizations"

# Check commit readiness
echo "Checking commit readiness for order-matching chaincode..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/users/Admin@stockmarket/msp && \
export CORE_PEER_ADDRESS=peer0.stockmarket:7051 && \
export CORE_PEER_LOCALMSPID=StockMarketMSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/peers/peer0.stockmarket/tls/ca.crt && \
peer lifecycle chaincode checkcommitreadiness --channelID $TRADING_CHANNEL --name order-matching --version 1.0 --sequence 1 --signature-policy '$POLICY_TRADING' --tls --cafile $ORDERER_CA --output json"

# Commit the chaincode definition
echo "Committing order-matching chaincode on Trading channel..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/users/Admin@stockmarket/msp && \
export CORE_PEER_ADDRESS=peer0.stockmarket:7051 && \
export CORE_PEER_LOCALMSPID=StockMarketMSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/peers/peer0.stockmarket/tls/ca.crt && \
peer lifecycle chaincode commit -o $ORDERER_ADDR --channelID $TRADING_CHANNEL --name order-matching --version 1.0 --sequence 1 --signature-policy '$POLICY_TRADING' --tls --cafile $ORDERER_CA \
    --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/peers/peer0.stockmarket/tls/ca.crt \
    --peerAddresses peer0.broker1:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker1/peers/peer0.broker1/tls/ca.crt \
    --peerAddresses peer0.broker2:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker2/peers/peer0.broker2/tls/ca.crt"

echo "✅ Order-matching chaincode committed on Trading channel"

# Query committed to confirm
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/users/Admin@stockmarket/msp && \
export CORE_PEER_ADDRESS=peer0.stockmarket:7051 && \
export CORE_PEER_LOCALMSPID=StockMarketMSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/peers/peer0.stockmarket/tls/ca.crt && \
peer lifecycle chaincode querycommitted --channelID $TRADING_CHANNEL --name order-matching --cafile $ORDERER_CA"

############################################################
# INSTALL AND APPROVE SETTLEMENT CHAINCODE ON SETTLEMENT CHANNEL
############################################################
echo "Installing settlement chaincode for the Settlement channel..."

# Install on Maroclear peer
echo "Installing on Maroclear peer..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/maroclear/users/Admin@maroclear/msp && \
export CORE_PEER_ADDRESS=peer0.maroclear:7051 && \
export CORE_PEER_LOCALMSPID=MaroclearMSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/maroclear/peers/peer0.maroclear/tls/ca.crt && \
peer lifecycle chaincode install /opt/gopath/src/github.com/hyperledger/fabric/peer/settlement.tar.gz && \
PACKAGE_ID=\$(peer lifecycle chaincode queryinstalled | grep 'settlement_1' | awk '{print \$3}' | sed 's/,//') && \
echo \$PACKAGE_ID > /opt/gopath/src/github.com/hyperledger/fabric/peer/package_id_maroclear_settle.txt"
PACKAGE_ID_MAROCLEAR_SETTLE=$(docker exec cli cat /opt/gopath/src/github.com/hyperledger/fabric/peer/package_id_maroclear_settle.txt)

# Install on StockMarket peer
echo "Installing on StockMarket peer for settlement channel..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/users/Admin@stockmarket/msp && \
export CORE_PEER_ADDRESS=peer0.stockmarket:7051 && \
export CORE_PEER_LOCALMSPID=StockMarketMSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/peers/peer0.stockmarket/tls/ca.crt && \
peer lifecycle chaincode install /opt/gopath/src/github.com/hyperledger/fabric/peer/settlement.tar.gz && \
PACKAGE_ID=\$(peer lifecycle chaincode queryinstalled | grep 'settlement_1' | awk '{print \$3}' | sed 's/,//') && \
echo \$PACKAGE_ID > /opt/gopath/src/github.com/hyperledger/fabric/peer/package_id_stockmarket_settle.txt"
PACKAGE_ID_STOCKMARKET_SETTLE=$(docker exec cli cat /opt/gopath/src/github.com/hyperledger/fabric/peer/package_id_stockmarket_settle.txt)

# Install on Broker1 peer
echo "Installing on Broker1 peer for settlement channel..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker1/users/Admin@broker1/msp && \
export CORE_PEER_ADDRESS=peer0.broker1:7051 && \
export CORE_PEER_LOCALMSPID=Broker1MSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker1/peers/peer0.broker1/tls/ca.crt && \
peer lifecycle chaincode install /opt/gopath/src/github.com/hyperledger/fabric/peer/settlement.tar.gz && \
PACKAGE_ID=\$(peer lifecycle chaincode queryinstalled | grep 'settlement_1' | awk '{print \$3}' | sed 's/,//') && \
echo \$PACKAGE_ID > /opt/gopath/src/github.com/hyperledger/fabric/peer/package_id_broker1_settle.txt"
PACKAGE_ID_BROKER1_SETTLE=$(docker exec cli cat /opt/gopath/src/github.com/hyperledger/fabric/peer/package_id_broker1_settle.txt)

# Install on Broker2 peer
echo "Installing on Broker2 peer for settlement channel..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker2/users/Admin@broker2/msp && \
export CORE_PEER_ADDRESS=peer0.broker2:7051 && \
export CORE_PEER_LOCALMSPID=Broker2MSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker2/peers/peer0.broker2/tls/ca.crt && \
peer lifecycle chaincode install /opt/gopath/src/github.com/hyperledger/fabric/peer/settlement.tar.gz && \
PACKAGE_ID=\$(peer lifecycle chaincode queryinstalled | grep 'settlement_1' | awk '{print \$3}' | sed 's/,//') && \
echo \$PACKAGE_ID > /opt/gopath/src/github.com/hyperledger/fabric/peer/package_id_broker2_settle.txt"
PACKAGE_ID_BROKER2_SETTLE=$(docker exec cli cat /opt/gopath/src/github.com/hyperledger/fabric/peer/package_id_broker2_settle.txt)

echo "✅ Settlement chaincode installed on peers for settlement channel"

echo "Approving settlement chaincode for organizations..."

# Approve chaincode for Maroclear
echo "Approving for Maroclear..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/maroclear/users/Admin@maroclear/msp && \
export CORE_PEER_ADDRESS=peer0.maroclear:7051 && \
export CORE_PEER_LOCALMSPID=MaroclearMSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/maroclear/peers/peer0.maroclear/tls/ca.crt && \
peer lifecycle chaincode approveformyorg -o $ORDERER_ADDR --channelID $SETTLEMENT_CHANNEL --name settlement --version 1.0 --package-id $PACKAGE_ID_MAROCLEAR_SETTLE --sequence 1 --signature-policy '$POLICY_SETTLEMENT' --tls --cafile $ORDERER_CA"

# Approve chaincode for StockMarket
echo "Approving for StockMarket on settlement channel..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/users/Admin@stockmarket/msp && \
export CORE_PEER_ADDRESS=peer0.stockmarket:7051 && \
export CORE_PEER_LOCALMSPID=StockMarketMSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/peers/peer0.stockmarket/tls/ca.crt && \
peer lifecycle chaincode approveformyorg -o $ORDERER_ADDR --channelID $SETTLEMENT_CHANNEL --name settlement --version 1.0 --package-id $PACKAGE_ID_STOCKMARKET_SETTLE --sequence 1 --signature-policy '$POLICY_SETTLEMENT' --tls --cafile $ORDERER_CA"

# Approve chaincode for Broker1
echo "Approving for Broker1 on settlement channel..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker1/users/Admin@broker1/msp && \
export CORE_PEER_ADDRESS=peer0.broker1:7051 && \
export CORE_PEER_LOCALMSPID=Broker1MSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker1/peers/peer0.broker1/tls/ca.crt && \
peer lifecycle chaincode approveformyorg -o $ORDERER_ADDR --channelID $SETTLEMENT_CHANNEL --name settlement --version 1.0 --package-id $PACKAGE_ID_BROKER1_SETTLE --sequence 1 --signature-policy '$POLICY_SETTLEMENT' --tls --cafile $ORDERER_CA"

# Approve chaincode for Broker2
echo "Approving for Broker2 on settlement channel..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker2/users/Admin@broker2/msp && \
export CORE_PEER_ADDRESS=peer0.broker2:7051 && \
export CORE_PEER_LOCALMSPID=Broker2MSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker2/peers/peer0.broker2/tls/ca.crt && \
peer lifecycle chaincode approveformyorg -o $ORDERER_ADDR --channelID $SETTLEMENT_CHANNEL --name settlement --version 1.0 --package-id $PACKAGE_ID_BROKER2_SETTLE --sequence 1 --signature-policy '$POLICY_SETTLEMENT' --tls --cafile $ORDERER_CA"

echo "✅ Settlement chaincode approved by all organizations"

# Check commit readiness
echo "Checking commit readiness for settlement chaincode..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/maroclear/users/Admin@maroclear/msp && \
export CORE_PEER_ADDRESS=peer0.maroclear:7051 && \
export CORE_PEER_LOCALMSPID=MaroclearMSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/maroclear/peers/peer0.maroclear/tls/ca.crt && \
peer lifecycle chaincode checkcommitreadiness --channelID $SETTLEMENT_CHANNEL --name settlement --version 1.0 --sequence 1 --signature-policy '$POLICY_SETTLEMENT' --tls --cafile $ORDERER_CA --output json"

# Commit the chaincode definition
echo "Committing settlement chaincode on settlement channel..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/maroclear/users/Admin@maroclear/msp && \
export CORE_PEER_ADDRESS=peer0.maroclear:7051 && \
export CORE_PEER_LOCALMSPID=MaroclearMSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/maroclear/peers/peer0.maroclear/tls/ca.crt && \
peer lifecycle chaincode commit -o $ORDERER_ADDR --channelID $SETTLEMENT_CHANNEL --name settlement --version 1.0 --sequence 1 --signature-policy '$POLICY_SETTLEMENT' --tls --cafile $ORDERER_CA \
   --peerAddresses peer0.maroclear:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/maroclear/peers/peer0.maroclear/tls/ca.crt \
   --peerAddresses peer0.stockmarket:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/peers/peer0.stockmarket/tls/ca.crt \
   --peerAddresses peer0.broker1:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker1/peers/peer0.broker1/tls/ca.crt \
   --peerAddresses peer0.broker2:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker2/peers/peer0.broker2/tls/ca.crt"

echo "✅ Settlement chaincode committed on settlement channel"

# Query committed to confirm
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/maroclear/users/Admin@maroclear/msp && \
export CORE_PEER_ADDRESS=peer0.maroclear:7051 && \
export CORE_PEER_LOCALMSPID=MaroclearMSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/maroclear/peers/peer0.maroclear/tls/ca.crt && \
peer lifecycle chaincode querycommitted --channelID $SETTLEMENT_CHANNEL --name settlement --cafile $ORDERER_CA"

echo "✅ All chaincodes have been successfully installed, approved and committed on their respective channels!"