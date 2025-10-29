#!/bin/bash

#############################################
# Endpoint Validation Script
# Tests 7180/load/initial endpoint
#############################################

ENDPOINT="http://localhost:7180/load/initial"
MAX_ATTEMPTS=30
WAIT_TIME=5

echo "============================================"
echo "   Endpoint Validation Test"
echo "============================================"
echo ""
echo "Testing endpoint: $ENDPOINT"
echo "Tests: $MAX_ATTEMPTS attempts with ${WAIT_TIME}s intervals"
echo ""

# Check if services are running
echo "Checking if services are running..."
cd "$(dirname "$0")/petrel"
bash start.sh status
echo ""

# Wait for services to be ready
echo "Waiting for services to initialize (15 seconds)..."
sleep 15

# Test the endpoint multiple times
echo "Running connectivity tests..."
echo ""

success_count=0
fail_count=0
response_times=()

for i in $(seq 1 $MAX_ATTEMPTS); do
    timestamp=$(date '+%H:%M:%S')
    echo -n "[$timestamp] Test $i/$MAX_ATTEMPTS: "
    
    # Make request with timeout and measure response time
    start_time=$(date +%s%N)
    response=$(curl -s -w "\n%{http_code}\n%{time_total}" --max-time 10 "$ENDPOINT" 2>&1)
    end_time=$(date +%s%N)
    
    http_code=$(echo "$response" | tail -n2 | head -n1)
    response_time=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ]; then
        echo "✓ SUCCESS (HTTP $http_code, ${response_time}s)"
        success_count=$((success_count + 1))
        response_times+=("$response_time")
        
        # Show response data on first success
        if [ $success_count -eq 1 ]; then
            echo ""
            echo "Sample response data:"
            echo "$response" | head -n -2 | head -20
            echo "..."
            echo ""
        fi
    else
        echo "✗ FAILED (HTTP $http_code or timeout)"
        fail_count=$((fail_count + 1))
        
        # Log failure details
        if [ $fail_count -le 3 ]; then
            echo "   Error details: $response" | head -3
        fi
    fi
    
    # Wait between requests
    if [ $i -lt $MAX_ATTEMPTS ]; then
        sleep $WAIT_TIME
    fi
done

# Calculate statistics
if [ ${#response_times[@]} -gt 0 ]; then
    total_time=0
    for time in "${response_times[@]}"; do
        total_time=$(echo "$total_time + $time" | bc)
    done
    avg_time=$(echo "scale=3; $total_time / ${#response_times[@]}" | bc)
else
    avg_time="N/A"
fi

echo ""
echo "============================================"
echo "   Test Results"
echo "============================================"
echo "Total tests:         $MAX_ATTEMPTS"
echo "Successful:          $success_count"
echo "Failed:              $fail_count"
echo "Success rate:        $(( success_count * 100 / MAX_ATTEMPTS ))%"
echo "Avg response time:   ${avg_time}s"
echo ""

if [ $success_count -gt 0 ]; then
    echo "✓ Endpoint is responding with data"
    
    if [ $fail_count -eq 0 ]; then
        echo "✓ No disconnections detected - STABLE!"
        echo ""
        echo "Status: ✅ PASSED"
        exit 0
    elif [ $fail_count -le 3 ]; then
        echo "⚠ Minor issues detected ($fail_count/$MAX_ATTEMPTS failures)"
        echo ""
        echo "Status: ⚠️ MOSTLY STABLE"
        exit 0
    else
        echo "⚠ Frequent disconnections detected ($fail_count/$MAX_ATTEMPTS)"
        echo ""
        echo "Status: ⚠️ UNSTABLE"
        echo ""
        echo "Recommendations:"
        echo "1. Check database connection: mysql -h 202.189.7.196 -u root -p"
        echo "2. Check network latency: ping -c 10 202.189.7.196"
        echo "3. Review logs: find petrel/logs -name '*.log' -mmin -10 -exec tail {} \;"
        echo "4. Restart services: bash stop-all.sh && bash start-all.sh"
        exit 1
    fi
else
    echo "✗ Endpoint not responding"
    echo ""
    echo "Status: ❌ FAILED"
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Check if all services are running: cd petrel && bash start.sh status"
    echo "2. Check service logs: ls -la petrel/logs/"
    echo "3. Verify Nacos is running: curl http://localhost:6878/nacos/v1/console/health"
    echo "4. Check if port 7180 is listening: netstat -tlnp | grep 7180"
    echo "5. Review troubleshooting guide: cat TROUBLESHOOTING.md"
    exit 2
fi
