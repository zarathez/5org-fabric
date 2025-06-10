#!/bin/bash

echo "Starting all UI components..."

# Stock market UI server
cd ui/server
sudo npm run dev &

# Stock market UI client
cd ../client
npm start &

# Broker UI server
cd ../../broker-ui/server
sudo npm run dev &

# Broker UI client
cd ../client
npm start &

# Wait for all background jobs to finish (optional)
wait

