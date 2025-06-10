#!/bin/bash

# Exit on first error
set -e

# Variables
CHANNEL_NAME1="trading-channel"
CHANNEL_NAME2="regulatory-channel"
CHANNEL_NAME3="settlement-channel"
ORDERER_CA="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/orderer/orderers/orderer0.orderer/tls/ca.crt"
ORDERER_ADDRESS="orderer0.orderer:7050"

echo "Creating and joining channels..."

# Create trading channel
echo "Creating trading channel..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/users/Admin@stockmarket/msp && \
export CORE_PEER_ADDRESS=peer0.stockmarket:7051 && \
export CORE_PEER_LOCALMSPID=StockMarketMSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/peers/peer0.stockmarket/tls/ca.crt && \
peer channel create -o ${ORDERER_ADDRESS} -c ${CHANNEL_NAME1} -f channel-artifacts/${CHANNEL_NAME1}.tx --tls --cafile ${ORDERER_CA}"
echo "✅ Trading channel created"

# Create regulatory channel
echo "Creating regulatory channel..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/users/Admin@stockmarket/msp && \
export CORE_PEER_ADDRESS=peer0.stockmarket:7051 && \
export CORE_PEER_LOCALMSPID=StockMarketMSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/peers/peer0.stockmarket/tls/ca.crt && \
peer channel create -o ${ORDERER_ADDRESS} -c ${CHANNEL_NAME2} -f channel-artifacts/${CHANNEL_NAME2}.tx --tls --cafile ${ORDERER_CA}"
echo "✅ Regulatory channel created"

# Create settlement channel
echo "Creating settlement channel..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/users/Admin@stockmarket/msp && \
export CORE_PEER_ADDRESS=peer0.stockmarket:7051 && \
export CORE_PEER_LOCALMSPID=StockMarketMSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/peers/peer0.stockmarket/tls/ca.crt && \
peer channel create -o ${ORDERER_ADDRESS} -c ${CHANNEL_NAME3} -f channel-artifacts/${CHANNEL_NAME3}.tx --tls --cafile ${ORDERER_CA}"
echo "✅ Settlement channel created"

echo "Joining peers to channels..."

# Join StockMarket peer to trading channel
echo "Joining StockMarket peer to trading channel..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/users/Admin@stockmarket/msp && \
export CORE_PEER_ADDRESS=peer0.stockmarket:7051 && \
export CORE_PEER_LOCALMSPID=StockMarketMSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/peers/peer0.stockmarket/tls/ca.crt && \
peer channel join -b ./${CHANNEL_NAME1}.block"

# Join Broker1 peer to trading channel
echo "Joining Broker1 peer to trading channel..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker1/users/Admin@broker1/msp && \
export CORE_PEER_ADDRESS=peer0.broker1:7051 && \
export CORE_PEER_LOCALMSPID=Broker1MSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker1/peers/peer0.broker1/tls/ca.crt && \
peer channel join -b ./${CHANNEL_NAME1}.block"

# Join Broker2 peer to trading channel
echo "Joining Broker2 peer to trading channel..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker2/users/Admin@broker2/msp && \
export CORE_PEER_ADDRESS=peer0.broker2:7051 && \
export CORE_PEER_LOCALMSPID=Broker2MSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker2/peers/peer0.broker2/tls/ca.crt && \
peer channel join -b ./${CHANNEL_NAME1}.block"

# Join AMMC peer to trading channel
echo "Joining AMMC peer to trading channel..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ammc/users/Admin@ammc/msp && \
export CORE_PEER_ADDRESS=peer0.ammc:7051 && \
export CORE_PEER_LOCALMSPID=AMMCMSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ammc/peers/peer0.ammc/tls/ca.crt && \
peer channel join -b ./${CHANNEL_NAME1}.block"

# Join StockMarket peer to regulatory channel
echo "Joining StockMarket peer to regulatory channel..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/users/Admin@stockmarket/msp && \
export CORE_PEER_ADDRESS=peer0.stockmarket:7051 && \
export CORE_PEER_LOCALMSPID=StockMarketMSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/peers/peer0.stockmarket/tls/ca.crt && \
peer channel join -b ./${CHANNEL_NAME2}.block"

# Join AMMC peer to regulatory channel
echo "Joining AMMC peer to regulatory channel..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ammc/users/Admin@ammc/msp && \
export CORE_PEER_ADDRESS=peer0.ammc:7051 && \
export CORE_PEER_LOCALMSPID=AMMCMSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ammc/peers/peer0.ammc/tls/ca.crt && \
peer channel join -b ./${CHANNEL_NAME2}.block"

# Join peers to settlement channel
echo "Joining Maroclear peer to settlement channel..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/maroclear/users/Admin@maroclear/msp && \
export CORE_PEER_ADDRESS=peer0.maroclear:7051 && \
export CORE_PEER_LOCALMSPID=MaroclearMSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/maroclear/peers/peer0.maroclear/tls/ca.crt && \
peer channel join -b ./${CHANNEL_NAME3}.block"

echo "Joining StockMarket peer to settlement channel..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/users/Admin@stockmarket/msp && \
export CORE_PEER_ADDRESS=peer0.stockmarket:7051 && \
export CORE_PEER_LOCALMSPID=StockMarketMSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/peers/peer0.stockmarket/tls/ca.crt && \
peer channel join -b ./${CHANNEL_NAME3}.block"

echo "Joining Broker1 peer to settlement channel..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker1/users/Admin@broker1/msp && \
export CORE_PEER_ADDRESS=peer0.broker1:7051 && \
export CORE_PEER_LOCALMSPID=Broker1MSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker1/peers/peer0.broker1/tls/ca.crt && \
peer channel join -b ./${CHANNEL_NAME3}.block"

echo "Joining Broker2 peer to settlement channel..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker2/users/Admin@broker2/msp && \
export CORE_PEER_ADDRESS=peer0.broker2:7051 && \
export CORE_PEER_LOCALMSPID=Broker2MSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker2/peers/peer0.broker2/tls/ca.crt && \
peer channel join -b ./${CHANNEL_NAME3}.block"

echo "Joining AMMC peer to settlement channel..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ammc/users/Admin@ammc/msp && \
export CORE_PEER_ADDRESS=peer0.ammc:7051 && \
export CORE_PEER_LOCALMSPID=AMMCMSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ammc/peers/peer0.ammc/tls/ca.crt && \
peer channel join -b ./${CHANNEL_NAME3}.block"

echo "Updating anchor peers..."

# Update anchor peers for trading channel
echo "Updating anchor peers for trading channel..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/users/Admin@stockmarket/msp && \
export CORE_PEER_ADDRESS=peer0.stockmarket:7051 && \
export CORE_PEER_LOCALMSPID=StockMarketMSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/peers/peer0.stockmarket/tls/ca.crt && \
peer channel update -o ${ORDERER_ADDRESS} -c ${CHANNEL_NAME1} -f channel-artifacts/StockMarketMSPanchors_${CHANNEL_NAME1}.tx --tls --cafile ${ORDERER_CA}"

docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker1/users/Admin@broker1/msp && \
export CORE_PEER_ADDRESS=peer0.broker1:7051 && \
export CORE_PEER_LOCALMSPID=Broker1MSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker1/peers/peer0.broker1/tls/ca.crt && \
peer channel update -o ${ORDERER_ADDRESS} -c ${CHANNEL_NAME1} -f channel-artifacts/Broker1MSPanchors_${CHANNEL_NAME1}.tx --tls --cafile ${ORDERER_CA}"

docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker2/users/Admin@broker2/msp && \
export CORE_PEER_ADDRESS=peer0.broker2:7051 && \
export CORE_PEER_LOCALMSPID=Broker2MSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker2/peers/peer0.broker2/tls/ca.crt && \
peer channel update -o ${ORDERER_ADDRESS} -c ${CHANNEL_NAME1} -f channel-artifacts/Broker2MSPanchors_${CHANNEL_NAME1}.tx --tls --cafile ${ORDERER_CA}"

docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ammc/users/Admin@ammc/msp && \
export CORE_PEER_ADDRESS=peer0.ammc:7051 && \
export CORE_PEER_LOCALMSPID=AMMCMSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ammc/peers/peer0.ammc/tls/ca.crt && \
peer channel update -o ${ORDERER_ADDRESS} -c ${CHANNEL_NAME1} -f channel-artifacts/AMMCMSPanchors_${CHANNEL_NAME1}.tx --tls --cafile ${ORDERER_CA}"

# Update anchor peers for regulatory channel
echo "Updating anchor peers for regulatory channel..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/users/Admin@stockmarket/msp && \
export CORE_PEER_ADDRESS=peer0.stockmarket:7051 && \
export CORE_PEER_LOCALMSPID=StockMarketMSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/peers/peer0.stockmarket/tls/ca.crt && \
peer channel update -o ${ORDERER_ADDRESS} -c ${CHANNEL_NAME2} -f channel-artifacts/StockMarketMSPanchors_${CHANNEL_NAME2}.tx --tls --cafile ${ORDERER_CA}"

docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ammc/users/Admin@ammc/msp && \
export CORE_PEER_ADDRESS=peer0.ammc:7051 && \
export CORE_PEER_LOCALMSPID=AMMCMSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ammc/peers/peer0.ammc/tls/ca.crt && \
peer channel update -o ${ORDERER_ADDRESS} -c ${CHANNEL_NAME2} -f channel-artifacts/AMMCMSPanchors_${CHANNEL_NAME2}.tx --tls --cafile ${ORDERER_CA}"

# Update anchor peers for settlement channel
echo "Updating anchor peers for settlement channel..."
docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/maroclear/users/Admin@maroclear/msp && \
export CORE_PEER_ADDRESS=peer0.maroclear:7051 && \
export CORE_PEER_LOCALMSPID=MaroclearMSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/maroclear/peers/peer0.maroclear/tls/ca.crt && \
peer channel update -o ${ORDERER_ADDRESS} -c ${CHANNEL_NAME3} -f channel-artifacts/MaroclearMSPanchors_${CHANNEL_NAME3}.tx --tls --cafile ${ORDERER_CA}"

docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/users/Admin@stockmarket/msp && \
export CORE_PEER_ADDRESS=peer0.stockmarket:7051 && \
export CORE_PEER_LOCALMSPID=StockMarketMSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/peers/peer0.stockmarket/tls/ca.crt && \
peer channel update -o ${ORDERER_ADDRESS} -c ${CHANNEL_NAME3} -f channel-artifacts/StockMarketMSPanchors_${CHANNEL_NAME3}.tx --tls --cafile ${ORDERER_CA}"

docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker1/users/Admin@broker1/msp && \
export CORE_PEER_ADDRESS=peer0.broker1:7051 && \
export CORE_PEER_LOCALMSPID=Broker1MSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker1/peers/peer0.broker1/tls/ca.crt && \
peer channel update -o ${ORDERER_ADDRESS} -c ${CHANNEL_NAME3} -f channel-artifacts/Broker1MSPanchors_${CHANNEL_NAME3}.tx --tls --cafile ${ORDERER_CA}"

docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker2/users/Admin@broker2/msp && \
export CORE_PEER_ADDRESS=peer0.broker2:7051 && \
export CORE_PEER_LOCALMSPID=Broker2MSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/broker2/peers/peer0.broker2/tls/ca.crt && \
peer channel update -o ${ORDERER_ADDRESS} -c ${CHANNEL_NAME3} -f channel-artifacts/Broker2MSPanchors_${CHANNEL_NAME3}.tx --tls --cafile ${ORDERER_CA}"

docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ammc/users/Admin@ammc/msp && \
export CORE_PEER_ADDRESS=peer0.ammc:7051 && \
export CORE_PEER_LOCALMSPID=AMMCMSP && \
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ammc/peers/peer0.ammc/tls/ca.crt && \
peer channel update -o ${ORDERER_ADDRESS} -c ${CHANNEL_NAME3} -f channel-artifacts/AMMCMSPanchors_${CHANNEL_NAME3}.tx --tls --cafile ${ORDERER_CA}"

echo "✅ All channels created, peers joined, and anchor peers updated successfully!"