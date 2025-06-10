#!/bin/bash

# Create go.mod files for each chaincode
echo "Creating Go module files for chaincodes..."

# Order Matching chaincode
cat > ./chaincodes/order-matching/go.mod << EOF
module github.com/hyperledger/fabric-samples/chaincode/order-matching

go 1.16

require (
	github.com/hyperledger/fabric-chaincode-go v0.0.0-20230228194215-b84622ba6a7a
	github.com/hyperledger/fabric-contract-api-go v1.2.1
)
EOF

# Compliance chaincode
cat > ./chaincodes/compliance/go.mod << EOF
module github.com/hyperledger/fabric-samples/chaincode/compliance

go 1.16

require (
	github.com/hyperledger/fabric-chaincode-go v0.0.0-20230228194215-b84622ba6a7a
	github.com/hyperledger/fabric-contract-api-go v1.2.1
)
EOF

# Settlement chaincode
cat > ./chaincodes/settlement/go.mod << EOF
module github.com/hyperledger/fabric-samples/chaincode/settlement

go 1.16

require (
	github.com/hyperledger/fabric-chaincode-go v0.0.0-20230228194215-b84622ba6a7a
	github.com/hyperledger/fabric-contract-api-go v1.2.1
)
EOF

echo "Go module files created successfully"
