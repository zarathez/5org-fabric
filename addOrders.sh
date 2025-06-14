#!/bin/bash

# Script to create alternating buy/sell orders between brokers
# Run this script from the stock-market-network directory

set -e

echo "Creating broker orders for all securities..."

# Channel and chaincode details
CHANNEL_NAME="trading-channel"
CHAINCODE_NAME="order-matching"
ORDERER_CA="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/orderer/orderers/orderer0.orderer/tls/ca.crt"

# Securities array (Symbol, Security ID, Base Price)
declare -a SECURITIES=(
    "IAM:SEC000:90.00"
    "BCP:SEC002:285.00"
    "ATW:SEC003:470.00"
    "CSMR:SEC004:270.00"
    "MNG:SEC006:1900.00"
    "ADH:SEC007:67.00"
    "TMA:SEC008:1250.00"
)

# Function to create buy order
create_buy_order() {
    local broker_org="$1"
    local broker_user="$2"
    local order_id="$3"
    local security_id="$4"
    local symbol="$5"
    local quantity="$6"
    local price="$7"
    
    echo "Creating BUY order: $order_id for $symbol by $broker_org..."
    
    docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/$broker_org/users/$broker_user@$broker_org/msp && \
    export CORE_PEER_ADDRESS=peer0.$broker_org:7051 && \
    export CORE_PEER_LOCALMSPID=${broker_org^}MSP && \
    export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/$broker_org/peers/peer0.$broker_org/tls/ca.crt && \
    peer chaincode invoke -o orderer0.orderer:7050 --tls --cafile \"$ORDERER_CA\" -C \"$CHANNEL_NAME\" -n \"$CHAINCODE_NAME\" \
    -c '{\"function\":\"CreateOrder\",\"Args\":[\"$order_id\",\"$security_id\",\"BUY\",\"$quantity\",\"$price\",\"$broker_user\"]}' \
    --peerAddresses peer0.$broker_org:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/$broker_org/peers/peer0.$broker_org/tls/ca.crt"
    
    if [ $? -eq 0 ]; then
        echo "✅ BUY order created: $order_id ($symbol)"
    else
        echo "❌ Failed to create BUY order: $order_id ($symbol)"
    fi
}

# Function to create sell order
create_sell_order() {
    local broker_org="$1"
    local broker_user="$2"
    local order_id="$3"
    local security_id="$4"
    local symbol="$5"
    local quantity="$6"
    local price="$7"
    
    echo "Creating SELL order: $order_id for $symbol by $broker_org..."
    
    docker exec cli bash -c "export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/$broker_org/users/$broker_user@$broker_org/msp && \
    export CORE_PEER_ADDRESS=peer0.$broker_org:7051 && \
    export CORE_PEER_LOCALMSPID=${broker_org^}MSP && \
    export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/$broker_org/peers/peer0.$broker_org/tls/ca.crt && \
    peer chaincode invoke -o orderer0.orderer:7050 --tls --cafile \"$ORDERER_CA\" -C \"$CHANNEL_NAME\" -n \"$CHAINCODE_NAME\" \
    -c '{\"function\":\"CreateOrder\",\"Args\":[\"$order_id\",\"$security_id\",\"SELL\",\"$quantity\",\"$price\",\"$broker_user\"]}' \
    --peerAddresses peer0.$broker_org:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/$broker_org/peers/peer0.$broker_org/tls/ca.crt"
    
    if [ $? -eq 0 ]; then
        echo "✅ SELL order created: $order_id ($symbol)"
    else
        echo "❌ Failed to create SELL order: $order_id ($symbol)"
    fi
}

# Function to generate random price variation (±5% of base price)
generate_price_variation() {
    local base_price="$1"
    local variation=$(( (RANDOM % 11) - 5 ))  # -5 to +5
    local price_change=$(echo "scale=2; $base_price * $variation / 100" | bc -l)
    local new_price=$(echo "scale=2; $base_price + $price_change" | bc -l)
    echo "$new_price"
}

# Function to generate random quantity between 100 and 10000
generate_quantity() {
    echo $(( 100 + RANDOM % 9901 ))  # 100 to 10000
}

echo "Starting order creation process..."
echo "============================================"

order_counter=1

# Create multiple rounds of orders for each security
for round in {1..3}; do
    echo ""
    echo "--- Round $round ---"
    
    for security in "${SECURITIES[@]}"; do
        IFS=':' read -r symbol security_id base_price <<< "$security"
        
        # Generate order details
        quantity=$(generate_quantity)
        price_variation=$(generate_price_variation "$base_price")
        
        # Determine which broker goes first (alternate by round and security)
        if [ $(( (round + order_counter) % 2 )) -eq 1 ]; then
            # Broker1 BUY, Broker2 SELL
            buy_order_id="ORD$(printf "%04d" $order_counter)"
            sell_order_id="ORD$(printf "%04d" $((order_counter + 1)))"
            
            create_buy_order "broker1" "Admin" "$buy_order_id" "$security_id" "$symbol" "$quantity" "$price_variation"
            sleep 2
            
            # Slightly different price and quantity for sell order
            sell_quantity=$(generate_quantity)
            sell_price=$(generate_price_variation "$base_price")
            create_sell_order "broker2" "Admin" "$sell_order_id" "$security_id" "$symbol" "$sell_quantity" "$sell_price"
        else
            # Broker2 BUY, Broker1 SELL
            buy_order_id="ORD$(printf "%04d" $order_counter)"
            sell_order_id="ORD$(printf "%04d" $((order_counter + 1)))"
            
            create_buy_order "broker2" "Admin" "$buy_order_id" "$security_id" "$symbol" "$quantity" "$price_variation"
            sleep 2
            
            # Slightly different price and quantity for sell order
            sell_quantity=$(generate_quantity)
            sell_price=$(generate_price_variation "$base_price")
            create_sell_order "broker1" "Admin" "$sell_order_id" "$security_id" "$symbol" "$sell_quantity" "$sell_price"
        fi
        
        order_counter=$((order_counter + 2))
        echo ""
        sleep 1
    done
done

echo "============================================"
echo "Order creation process completed!"
echo "Total orders created: $((order_counter - 1))"
echo ""
echo "To view all orders, you can query them using:"
echo "docker exec cli bash -c \"export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/users/Admin@stockmarket/msp && export CORE_PEER_ADDRESS=peer0.stockmarket:7051 && export CORE_PEER_LOCALMSPID=StockMarketMSP && export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/peers/peer0.stockmarket/tls/ca.crt && peer chaincode query -C trading-channel -n order-matching -c '{\\\"function\\\":\\\"GetAllOrders\\\",\\\"Args\\\":[]}'\""
echo ""
echo "To view orders for a specific security (e.g., IAM):"
echo "docker exec cli bash -c \"export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/users/Admin@stockmarket/msp && export CORE_PEER_ADDRESS=peer0.stockmarket:7051 && export CORE_PEER_LOCALMSPID=StockMarketMSP && export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/stockmarket/peers/peer0.stockmarket/tls/ca.crt && peer chaincode query -C trading-channel -n order-matching -c '{\\\"function\\\":\\\"GetOrdersBySecurity\\\",\\\"Args\\\":[\\\"SEC000\\\"]}'\""