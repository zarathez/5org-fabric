#!/bin/bash

# Stop all containers
docker-compose -f docker-compose-ca.yaml -f docker-compose-net.yaml down --volumes --remove-orphans

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