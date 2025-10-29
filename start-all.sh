#!/bin/bash

#############################################
# Petrel Gaming Platform Startup Script
# Standardized workflow with Nacos
#############################################

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

echo "============================================"
echo "   Petrel Gaming Platform Startup"
echo "============================================"
echo ""

# Step 1: Start Nacos
echo "[Step 1/3] Starting Nacos Service Discovery..."
cd "${SCRIPT_DIR}/nacos/bin"
bash startup.sh -m standalone
echo "Waiting for Nacos to initialize (30 seconds)..."
sleep 30
echo "✓ Nacos started on port 6878"
echo ""

# Step 2: Start Redis (if needed on Linux)
echo "[Step 2/3] Checking Redis..."
if command -v redis-server &> /dev/null; then
    if ! pgrep redis-server > /dev/null; then
        echo "Starting Redis..."
        redis-server --daemonize yes
        sleep 2
        echo "✓ Redis started"
    else
        echo "✓ Redis is already running"
    fi
else
    echo "Note: Redis executable not found in PATH (may need manual start)"
fi
echo ""

# Step 3: Start all Petrel game services
echo "[Step 3/3] Starting Petrel Game Services..."
cd "${SCRIPT_DIR}/petrel"
bash start.sh start ALL

echo ""
echo "============================================"
echo "   Startup Complete!"
echo "============================================"
echo ""
echo "Service Endpoints:"
echo "  - Nacos Console: http://localhost:6878/nacos"
echo "  - Game Backend:  http://localhost:7180"
echo "  - Initial Load:  http://localhost:7180/load/initial"
echo ""
echo "To check service status:"
echo "  cd ${SCRIPT_DIR}/petrel && bash start.sh status"
echo ""
