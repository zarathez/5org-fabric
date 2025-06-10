#!/bin/bash

# Exit on first error
set -e

# Variables
CHANNEL_NAME1="main-channel"
CHANNEL_NAME2="regulatory-channel"
CHANNEL_NAME3="settlement-channel"
ORDERER_CA="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererorg/orderers/orderer0.orderer/tls/ca.crt"
ORDERER_ADDRESS="orderer0.orderer:7050"

echo "Creating and joining channels..."

# Create main channel
echo "Creating main channel..."
peer channel create -o ${ORDERER_ADDRESS} -c ${CHANNEL_NAME1} \
  -f ./channel-artifacts/${CHANNEL_NAME1}.tx --tls \
  --cafile ${ORDERER_CA}
echo "✅ Main channel created"

# Create regulatory channel
echo "Creating regulatory channel..."
peer channel create -o ${ORDERER_ADDRESS} -c ${CHANNEL_NAME2} \
  -f ./channel-artifacts/${CHANNEL_NAME2}.tx --tls \
  --cafile ${ORDERER_CA}
echo "✅ Regulatory channel created"

# Create settlement channel
echo "Creating settlement channel..."
peer channel create -o ${ORDERER_ADDRESS} -c ${CHANNEL_NAME3} \
  -f ./channel-artifacts/${CHANNEL_NAME3}.tx --tls \
  --cafile ${ORDERER_CA}
echo "✅ Settlement channel created"

echo "Joining peers to channels..."

# Join StockMarket peer to main channel
echo "Joining StockMarket peer to main channel..."
export CORE_PEER_MSPCONFIGPATH=./organizations/stockmarket/users/Admin@stockmarket/msp
export CORE_PEER_ADDRESS=peer0.stockmarket:7051
export CORE_PEER_LOCALMSPID=StockMarketMSP
export CORE_PEER_TLS_ROOTCERT_FILE=./organizations/stockmarket/peers/peer0.stockmarket/tls/ca.crt
peer channel join -b ./${CHANNEL_NAME1}.block

# Join Maroclear peer to main channel
echo "Joining Maroclear peer to main channel..."
export CORE_PEER_MSPCONFIGPATH=./organizations/maroclear/users/Admin@maroclear/msp
export CORE_PEER_ADDRESS=peer0.maroclear:7051
export CORE_PEER_LOCALMSPID=MaroclearMSP
export CORE_PEER_TLS_ROOTCERT_FILE=./organizations/maroclear/peers/peer0.maroclear/tls/ca.crt
peer channel join -b ./${CHANNEL_NAME1}.block

# Join Broker1 peer to main channel
echo "Joining Broker1 peer to main channel..."
export CORE_PEER_MSPCONFIGPATH=./organizations/broker1/users/Admin@broker1/msp
export CORE_PEER_ADDRESS=peer0.broker1:7051
export CORE_PEER_LOCALMSPID=Broker1MSP
export CORE_PEER_TLS_ROOTCERT_FILE=./organizations/broker1/peers/peer0.broker1/tls/ca.crt
peer channel join -b ./${CHANNEL_NAME1}.block

# Join Broker2 peer to main channel
echo "Joining Broker2 peer to main channel..."
export CORE_PEER_MSPCONFIGPATH=./organizations/broker2/users/Admin@broker2/msp
export CORE_PEER_ADDRESS=peer0.broker2:7051
export CORE_PEER_LOCALMSPID=Broker2MSP
export CORE_PEER_TLS_ROOTCERT_FILE=./organizations/broker2/peers/peer0.broker2/tls/ca.crt
peer channel join -b ./${CHANNEL_NAME1}.block

# Join StockMarket peer to regulatory channel
echo "Joining StockMarket peer to regulatory channel..."
export CORE_PEER_MSPCONFIGPATH=./organizations/stockmarket/users/Admin@stockmarket/msp
export CORE_PEER_ADDRESS=peer0.stockmarket:7051
export CORE_PEER_LOCALMSPID=StockMarketMSP
export CORE_PEER_TLS_ROOTCERT_FILE=./organizations/stockmarket/peers/peer0.stockmarket/tls/ca.crt
peer channel join -b ./${CHANNEL_NAME2}.block

# Join AMMC peer to regulatory channel
echo "Joining AMMC peer to regulatory channel..."
export CORE_PEER_MSPCONFIGPATH=./organizations/ammc/users/Admin@ammc/msp
export CORE_PEER_ADDRESS=peer0.ammc:7051
export CORE_PEER_LOCALMSPID=AMMCMSP
export CORE_PEER_TLS_ROOTCERT_FILE=./organizations/ammc/peers/peer0.ammc/tls/ca.crt
peer channel join -b ./${CHANNEL_NAME2}.block

# Join Maroclear peer to settlement channel
echo "Joining Maroclear peer to settlement channel..."
export CORE_PEER_MSPCONFIGPATH=./organizations/maroclear/users/Admin@maroclear/msp
export CORE_PEER_ADDRESS=peer0.maroclear:7051
export CORE_PEER_LOCALMSPID=MaroclearMSP
export CORE_PEER_TLS_ROOTCERT_FILE=./organizations/maroclear/peers/peer0.maroclear/tls/ca.crt
peer channel join -b ./${CHANNEL_NAME3}.block

echo "Updating anchor peers..."

# Update anchor peers for main channel
echo "Updating StockMarket anchor peer in main channel..."
export CORE_PEER_MSPCONFIGPATH=./organizations/stockmarket/users/Admin@stockmarket/msp
export CORE_PEER_ADDRESS=peer0.stockmarket:7051
export CORE_PEER_LOCALMSPID=StockMarketMSP
export CORE_PEER_TLS_ROOTCERT_FILE=./organizations/stockmarket/peers/peer0.stockmarket/tls/ca.crt
peer channel update -o ${ORDERER_ADDRESS} -c ${CHANNEL_NAME1} \
  -f ./channel-artifacts/StockMarketMSPanchors_${CHANNEL_NAME1}.tx --tls \
  --cafile ${ORDERER_CA}

echo "Updating Maroclear anchor peer in main channel..."
export CORE_PEER_MSPCONFIGPATH=./organizations/maroclear/users/Admin@maroclear/msp
export CORE_PEER_ADDRESS=peer0.maroclear:7051
export CORE_PEER_LOCALMSPID=MaroclearMSP
export CORE_PEER_TLS_ROOTCERT_FILE=./organizations/maroclear/peers/peer0.maroclear/tls/ca.crt
peer channel update -o ${ORDERER_ADDRESS} -c ${CHANNEL_NAME1} \
  -f ./channel-artifacts/MaroclearMSPanchors_${CHANNEL_NAME1}.tx --tls \
  --cafile ${ORDERER_CA}

echo "Updating Broker1 anchor peer in main channel..."
export CORE_PEER_MSPCONFIGPATH=./organizations/broker1/users/Admin@broker1/msp
export CORE_PEER_ADDRESS=peer0.broker1:7051
export CORE_PEER_LOCALMSPID=Broker1MSP
export CORE_PEER_TLS_ROOTCERT_FILE=./organizations/broker1/peers/peer0.broker1/tls/ca.crt
peer channel update -o ${ORDERER_ADDRESS} -c ${CHANNEL_NAME1} \
  -f ./channel-artifacts/Broker1MSPanchors_${CHANNEL_NAME1}.tx --tls \
  --cafile ${ORDERER_CA}

echo "Updating Broker2 anchor peer in main channel..."
export CORE_PEER_MSPCONFIGPATH=./organizations/broker2/users/Admin@broker2/msp
export CORE_PEER_ADDRESS=peer0.broker2:7051
export CORE_PEER_LOCALMSPID=Broker2MSP
export CORE_PEER_TLS_ROOTCERT_FILE=./organizations/broker2/peers/peer0.broker2/tls/ca.crt
peer channel update -o ${ORDERER_ADDRESS} -c ${CHANNEL_NAME1} \
  -f ./channel-artifacts/Broker2MSPanchors_${CHANNEL_NAME1}.tx --tls \
  --cafile ${ORDERER_CA}

# Update anchor peers for regulatory channel
echo "Updating StockMarket anchor peer in regulatory channel..."
export CORE_PEER_MSPCONFIGPATH=./organizations/stockmarket/users/Admin@stockmarket/msp
export CORE_PEER_ADDRESS=peer0.stockmarket:7051
export CORE_PEER_LOCALMSPID=StockMarketMSP
export CORE_PEER_TLS_ROOTCERT_FILE=./organizations/stockmarket/peers/peer0.stockmarket/tls/ca.crt
peer channel update -o ${ORDERER_ADDRESS} -c ${CHANNEL_NAME2} \
  -f ./channel-artifacts/StockMarketMSPanchors_${CHANNEL_NAME2}.tx --tls \
  --cafile ${ORDERER_CA}

echo "Updating AMMC anchor peer in regulatory channel..."
export CORE_PEER_MSPCONFIGPATH=./organizations/ammc/users/Admin@ammc/msp
export CORE_PEER_ADDRESS=peer0.ammc:7051
export CORE_PEER_LOCALMSPID=AMMCMSP
export CORE_PEER_TLS_ROOTCERT_FILE=./organizations/ammc/peers/peer0.ammc/tls/ca.crt
peer channel update -o ${ORDERER_ADDRESS} -c ${CHANNEL_NAME2} \
  -f ./channel-artifacts/AMMCMSPanchors_${CHANNEL_NAME2}.tx --tls \
  --cafile ${ORDERER_CA}

# Update anchor peers for settlement channel
echo "Updating Maroclear anchor peer in settlement channel..."
export CORE_PEER_MSPCONFIGPATH=./organizations/maroclear/users/Admin@maroclear/msp
export CORE_PEER_ADDRESS=peer0.maroclear:7051
export CORE_PEER_LOCALMSPID=MaroclearMSP
export CORE_PEER_TLS_ROOTCERT_FILE=./organizations/maroclear/peers/peer0.maroclear/tls/ca.crt
peer channel update -o ${ORDERER_ADDRESS} -c ${CHANNEL_NAME3} \
  -f ./channel-artifacts/MaroclearMSPanchors_${CHANNEL_NAME3}.tx --tls \
  --cafile ${ORDERER_CA}

echo "✅ All channels created, peers joined, and anchor peers updated successfully!"