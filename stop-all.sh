#!/bin/bash

#############################################
# Petrel Gaming Platform Shutdown Script
#############################################

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

echo "============================================"
echo "   Petrel Gaming Platform Shutdown"
echo "============================================"
echo ""

# Step 1: Stop all Petrel game services
echo "[Step 1/2] Stopping Petrel Game Services..."
cd "${SCRIPT_DIR}/petrel"
bash start.sh stop ALL
echo ""

# Step 2: Stop Nacos
echo "[Step 2/2] Stopping Nacos..."
cd "${SCRIPT_DIR}/nacos/bin"
bash shutdown.sh
sleep 3
echo "✓ Nacos stopped"
echo ""

echo "============================================"
echo "   Shutdown Complete!"
echo "============================================"
