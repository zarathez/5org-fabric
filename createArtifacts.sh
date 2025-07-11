#!/bin/bash

# Exit on first error
set -e

# Create directories if they don't exist
mkdir -p ./system-genesis-block
mkdir -p ./channel-artifacts

# Print the current directory and step for debugging
echo "Creating channel artifacts in $(pwd)"

# Generate system channel genesis block
echo "Generating system channel genesis block..."
configtxgen -profile OrdererGenesis -channelID system-channel -outputBlock ./system-genesis-block/genesis.block
echo "✅ System channel genesis block created"

# Generate TradingChannel transaction
echo "Generating TradingChannel transaction..."
configtxgen -profile TradingChannel -outputCreateChannelTx ./channel-artifacts/trading-channel.tx -channelID trading-channel
echo "✅ TradingChannel transaction created"

# Generate SettlementChannel transaction
echo "Generating SettlementChannel transaction..."
configtxgen -profile SettlementChannel -outputCreateChannelTx ./channel-artifacts/settlement-channel.tx -channelID settlement-channel
echo "✅ SettlementChannel transaction created"

echo "Generating anchor peer updates for TradingChannel..."
# Generate anchor peer updates for TradingChannel
configtxgen -profile TradingChannel -outputAnchorPeersUpdate ./channel-artifacts/StockMarketMSPanchors_trading-channel.tx -channelID trading-channel -asOrg StockMarketMSP
configtxgen -profile TradingChannel -outputAnchorPeersUpdate ./channel-artifacts/Broker1MSPanchors_trading-channel.tx -channelID trading-channel -asOrg Broker1MSP
configtxgen -profile TradingChannel -outputAnchorPeersUpdate ./channel-artifacts/Broker2MSPanchors_trading-channel.tx -channelID trading-channel -asOrg Broker2MSP
echo "✅ TradingChannel anchor peer updates created"

echo "Generating anchor peer updates for SettlementChannel..."
# Generate anchor peer updates for SettlementChannel
configtxgen -profile SettlementChannel -outputAnchorPeersUpdate ./channel-artifacts/StockMarketMSPanchors_settlement-channel.tx -channelID settlement-channel -asOrg StockMarketMSP
configtxgen -profile SettlementChannel -outputAnchorPeersUpdate ./channel-artifacts/MaroclearMSPanchors_settlement-channel.tx -channelID settlement-channel -asOrg MaroclearMSP
configtxgen -profile SettlementChannel -outputAnchorPeersUpdate ./channel-artifacts/Broker1MSPanchors_settlement-channel.tx -channelID settlement-channel -asOrg Broker1MSP
configtxgen -profile SettlementChannel -outputAnchorPeersUpdate ./channel-artifacts/Broker2MSPanchors_settlement-channel.tx -channelID settlement-channel -asOrg Broker2MSP
echo "✅ SettlementChannel anchor peer updates created"

echo "Channel artifacts generation completed successfully!"