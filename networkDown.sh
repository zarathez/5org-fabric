#!/bin/bash

# Stop all containers via docker-compose
docker-compose -f docker-compose-ca.yaml -f docker-compose-net.yaml down --volumes --remove-orphans

# Safety net: Explicitly remove any remaining containers by name pattern
echo "Cleaning up any remaining containers..."
docker rm -f $(docker ps -aq --filter "name=ca_") 2>/dev/null || true
docker rm -f $(docker ps -aq --filter "name=couchdb.") 2>/dev/null || true  
docker rm -f $(docker ps -aq --filter "name=orderer") 2>/dev/null || true
docker rm -f $(docker ps -aq --filter "name=peer0.") 2>/dev/null || true
docker rm -f $(docker ps -aq --filter "name=cli") 2>/dev/null || true


# Remove any generated artifacts
rm -rf organizations/*/ca/*
rm -rf organizations/*/peers/*
rm -rf organizations/*/orderers/*
rm -rf organizations/*/users/*
rm -rf system-genesis-block/*
rm -rf channel-artifacts/*
rm -rf packages/*
rm -rf ./*.block

# Also remove any package ID files that might have been created
rm -rf package_id_*.txt

echo "Network down and all artifacts cleaned up successfully!!"