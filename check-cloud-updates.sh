#!/bin/bash

# ============================================
# Cloud Update Checker
# Checks for updates from cloud endpoint and validates data
# ============================================
#
# Usage:
#   Basic check: ./check-cloud-updates.sh
#   
#   With custom URLs:
#     export CLOUD_UPDATE_URL='http://your-server:8089/dtc_update/'
#     export ROLLER_URL='http://your-server:8555/chfs/shared/java'
#     ./check-cloud-updates.sh
#
#   With custom paths:
#     export LOCAL_EXTERNAL_DIR='/path/to/petrel/external'
#     ./check-cloud-updates.sh
#
#   Generate report only:
#     ./check-cloud-updates.sh --report
#
#   Check endpoints only:
#     ./check-cloud-updates.sh --check
# ============================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration - Read from Nacos config or environment variables
CLOUD_UPDATE_URL="${CLOUD_UPDATE_URL:-http://192.168.10.102:8089/dtc_update/}"
ROLLER_URL="${ROLLER_URL:-http://192.168.10.102:8555/chfs/shared/java}"
LOCAL_EXTERNAL_DIR="${LOCAL_EXTERNAL_DIR:-$(pwd)/petrel/external}"
LOG_FILE="${LOG_FILE:-cloud-update-check.log}"
UPDATE_CACHE_FILE="/tmp/cloud-update-cache.json"
MAX_RETRIES=3
RETRY_DELAY=5

# Function to log messages
log_message() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

log_info() {
    log_message "${GREEN}INFO${NC}" "$@"
}

log_warn() {
    log_message "${YELLOW}WARN${NC}" "$@"
}

log_error() {
    log_message "${RED}ERROR${NC}" "$@"
}

log_step() {
    log_message "${BLUE}STEP${NC}" "$@"
}

# Check if cloud endpoint is accessible
check_cloud_endpoint() {
    local url=$1
    local retry_count=0
    
    log_info "Checking cloud endpoint: $url"
    
    while [ $retry_count -lt $MAX_RETRIES ]; do
        if curl -s -f -m 10 "$url" > /dev/null 2>&1; then
            log_info "✓ Cloud endpoint is accessible"
            return 0
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $MAX_RETRIES ]; then
                log_warn "Cloud endpoint not accessible, retry $retry_count/$MAX_RETRIES in ${RETRY_DELAY}s..."
                sleep $RETRY_DELAY
            fi
        fi
    done
    
    log_error "✗ Cloud endpoint is not accessible after $MAX_RETRIES retries"
    return 1
}

# Fetch cloud update information
fetch_cloud_updates() {
    local url=$1
    local output_file=$2
    
    log_info "Fetching cloud updates from: $url"
    
    local response=$(curl -s -w "\n%{http_code}" -m 30 "$url" 2>&1)
    local http_code=$(echo "$response" | tail -n1)
    local content=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "200" ]; then
        echo "$content" > "$output_file"
        log_info "✓ Successfully fetched cloud updates"
        return 0
    else
        log_error "✗ Failed to fetch cloud updates. HTTP status: $http_code"
        return 1
    fi
}

# Parse and validate update data
validate_update_data() {
    local data_file=$1
    
    log_info "Validating update data..."
    
    if [ ! -f "$data_file" ]; then
        log_error "✗ Update data file not found: $data_file"
        return 1
    fi
    
    local file_size
    # Portable way to get file size - try different approaches
    if command -v stat &> /dev/null; then
        # Try BSD/macOS format first
        file_size=$(stat -f%z "$data_file" 2>/dev/null)
        # If that fails, try GNU/Linux format
        if [ -z "$file_size" ]; then
            file_size=$(stat -c%s "$data_file" 2>/dev/null)
        fi
    fi
    
    # Fallback to wc if stat doesn't work
    if [ -z "$file_size" ] && command -v wc &> /dev/null; then
        file_size=$(wc -c < "$data_file" 2>/dev/null)
    fi
    
    if [ -z "$file_size" ] || [ "$file_size" -eq 0 ]; then
        log_error "✗ Update data file is empty"
        return 1
    fi
    
    log_info "✓ Update data file size: $file_size bytes"
    
    # Try to validate JSON if it's JSON format
    if command -v python3 &> /dev/null; then
        if python3 -m json.tool "$data_file" > /dev/null 2>&1; then
            log_info "✓ Update data is valid JSON"
        else
            log_warn "Update data is not JSON or has invalid format"
        fi
    fi
    
    return 0
}

# Check local external files status
check_local_external_files() {
    log_info "Checking local external files..."
    
    if [ ! -d "$LOCAL_EXTERNAL_DIR" ]; then
        log_error "✗ Local external directory not found: $LOCAL_EXTERNAL_DIR"
        return 1
    fi
    
    # Count files in external directory
    local file_count=$(find "$LOCAL_EXTERNAL_DIR" -type f 2>/dev/null | wc -l)
    log_info "Local external files count: $file_count"
    
    # Check roller directory specifically
    local roller_dir="$LOCAL_EXTERNAL_DIR/roller"
    if [ -d "$roller_dir" ]; then
        local roller_count=$(find "$roller_dir" -type f 2>/dev/null | wc -l)
        log_info "Roller configuration files: $roller_count"
        
        # List some key files
        if [ $roller_count -gt 0 ]; then
            log_info "Sample roller files:"
            find "$roller_dir" -type f -name "*.xml" -o -name "*.json" 2>/dev/null | head -5 | while read file; do
                local basename=$(basename "$file")
                # Portable file size detection
                local filesize
                if command -v stat &> /dev/null; then
                    filesize=$(stat -f%z "$file" 2>/dev/null)
                    [ -z "$filesize" ] && filesize=$(stat -c%s "$file" 2>/dev/null)
                fi
                [ -z "$filesize" ] && command -v wc &> /dev/null && filesize=$(wc -c < "$file" 2>/dev/null)
                log_info "  - $basename (${filesize:-unknown} bytes)"
            done
        fi
    else
        log_warn "Roller directory not found: $roller_dir"
    fi
    
    return 0
}

# Check if update is needed
check_update_needed() {
    log_info "Checking if updates are needed..."
    
    # Compare timestamps or versions if available
    local current_time=$(date +%s)
    local last_check_file="/tmp/last_cloud_check.txt"
    
    if [ -f "$last_check_file" ]; then
        local last_check=$(cat "$last_check_file")
        local time_diff=$((current_time - last_check))
        local hours=$((time_diff / 3600))
        
        log_info "Last check was $hours hours ago"
        
        if [ $time_diff -lt 3600 ]; then
            log_info "Recent check performed, update check may not be necessary"
        fi
    else
        log_info "No previous check record found"
    fi
    
    # Record current check time
    echo "$current_time" > "$last_check_file"
}

# Sync external data files
sync_external_data() {
    log_info "Checking for external data synchronization..."
    
    # Check roller URL
    if check_cloud_endpoint "$ROLLER_URL"; then
        log_info "Roller data endpoint is accessible"
        
        # List available files (if endpoint supports directory listing)
        log_info "To sync roller data, manually download from: $ROLLER_URL"
    else
        log_warn "Roller data endpoint is not accessible"
    fi
}

# Generate sync report
generate_sync_report() {
    log_info "Generating synchronization report..."
    
    local report_file="cloud-sync-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
========================================
Cloud Update Synchronization Report
Generated: $(date '+%Y-%m-%d %H:%M:%S')
========================================

Cloud Endpoints:
- Update URL: $CLOUD_UPDATE_URL
- Roller URL: $ROLLER_URL

Local Configuration:
- External Directory: $LOCAL_EXTERNAL_DIR

Status:
EOF

    if check_cloud_endpoint "$CLOUD_UPDATE_URL" &>> "$report_file"; then
        echo "- Cloud Update Endpoint: ✓ Accessible" >> "$report_file"
    else
        echo "- Cloud Update Endpoint: ✗ Not Accessible" >> "$report_file"
    fi
    
    if check_cloud_endpoint "$ROLLER_URL" &>> "$report_file"; then
        echo "- Roller Endpoint: ✓ Accessible" >> "$report_file"
    else
        echo "- Roller Endpoint: ✗ Not Accessible" >> "$report_file"
    fi
    
    if [ -d "$LOCAL_EXTERNAL_DIR" ]; then
        local file_count=$(find "$LOCAL_EXTERNAL_DIR" -type f 2>/dev/null | wc -l)
        echo "- Local Files: $file_count files present" >> "$report_file"
    else
        echo "- Local Files: Directory not found" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    echo "Recommendations:" >> "$report_file"
    echo "1. Verify cloud endpoints are accessible from production environment" >> "$report_file"
    echo "2. Ensure Redis and MySQL are synchronized" >> "$report_file"
    echo "3. Monitor cache hit rates for optimal performance" >> "$report_file"
    echo "4. Schedule regular update checks (recommended: every 6-12 hours)" >> "$report_file"
    echo "" >> "$report_file"
    echo "========================================" >> "$report_file"
    
    log_info "Report generated: $report_file"
    cat "$report_file"
}

# Main function
main() {
    echo "=========================================="
    echo "Cloud Update Checker"
    echo "$(date '+%Y-%m-%d %H:%M:%S')"
    echo "=========================================="
    echo ""
    
    log_step "[1/6] Checking cloud update endpoint..."
    check_cloud_endpoint "$CLOUD_UPDATE_URL"
    cloud_status=$?
    echo ""
    
    log_step "[2/6] Checking if updates are needed..."
    check_update_needed
    echo ""
    
    if [ $cloud_status -eq 0 ]; then
        log_step "[3/6] Fetching cloud updates..."
        fetch_cloud_updates "$CLOUD_UPDATE_URL" "$UPDATE_CACHE_FILE"
        fetch_status=$?
        echo ""
        
        if [ $fetch_status -eq 0 ]; then
            log_step "[4/6] Validating update data..."
            validate_update_data "$UPDATE_CACHE_FILE"
            echo ""
        else
            log_warn "Skipping validation due to fetch failure"
            echo ""
        fi
    else
        log_warn "Skipping fetch due to endpoint unavailability"
        echo ""
    fi
    
    log_step "[5/6] Checking local external files..."
    check_local_external_files
    echo ""
    
    log_step "[6/6] Checking external data sync..."
    sync_external_data
    echo ""
    
    # Generate report
    echo ""
    generate_sync_report
    
    echo ""
    echo "=========================================="
    log_info "Cloud update check completed"
    echo "=========================================="
    
    return 0
}

# Parse command line arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --report       Generate report only"
        echo "  --check        Check endpoints only"
        echo ""
        echo "This script checks for cloud updates and validates data synchronization."
        exit 0
        ;;
    --report)
        generate_sync_report
        exit 0
        ;;
    --check)
        check_cloud_endpoint "$CLOUD_UPDATE_URL"
        check_cloud_endpoint "$ROLLER_URL"
        exit 0
        ;;
    *)
        main
        exit $?
        ;;
esac
