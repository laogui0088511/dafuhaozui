#!/bin/bash

# ============================================
# Redis-Database Synchronization Monitor
# Monitors data synchronization between Redis cache and MySQL database
# ============================================
#
# Usage:
#   Basic check: ./monitor-redis-db-sync.sh
#   
#   With MySQL password:
#     export MYSQL_PASS='your_password'
#     ./monitor-redis-db-sync.sh
#
#   Custom configuration via environment variables:
#     export REDIS_HOST='192.168.1.100'
#     export MYSQL_HOST='192.168.1.200'
#     export MYSQL_USER='admin'
#     export MYSQL_PASS='password'
#     ./monitor-redis-db-sync.sh
# ============================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REDIS_HOST="${REDIS_HOST:-127.0.0.1}"
REDIS_PORT="${REDIS_PORT:-6379}"
MYSQL_HOST="${MYSQL_HOST:-202.189.7.196}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASS="${MYSQL_PASS:-}"  # Set via environment variable for security
MYSQL_DB="${MYSQL_DB:-petrel_core}"

LOG_FILE="redis-db-sync-monitor.log"

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

# Check if Redis is running
check_redis_connection() {
    log_info "Checking Redis connection..."
    
    if command -v redis-cli &> /dev/null; then
        if redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping > /dev/null 2>&1; then
            log_info "✓ Redis is running and responding"
            return 0
        else
            log_error "✗ Redis is not responding at ${REDIS_HOST}:${REDIS_PORT}"
            return 1
        fi
    else
        log_warn "redis-cli not found, skipping Redis connection check"
        return 2
    fi
}

# Check MySQL connection
check_mysql_connection() {
    log_info "Checking MySQL connection..."
    
    if [ -z "$MYSQL_PASS" ]; then
        log_warn "MYSQL_PASS not set. Set environment variable to enable MySQL checks."
        log_warn "Example: export MYSQL_PASS='your_password'"
        return 2
    fi
    
    if command -v mysql &> /dev/null; then
        if mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SELECT 1" > /dev/null 2>&1; then
            log_info "✓ MySQL is running and responding"
            return 0
        else
            log_error "✗ MySQL is not responding at ${MYSQL_HOST}:${MYSQL_PORT}"
            return 1
        fi
    else
        log_warn "mysql client not found, skipping MySQL connection check"
        return 2
    fi
}

# Check Redis memory usage
check_redis_memory() {
    if command -v redis-cli &> /dev/null; then
        log_info "Checking Redis memory usage..."
        
        local memory_info=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" info memory 2>/dev/null | grep "used_memory_human" | cut -d: -f2 | tr -d '\r\n ')
        local max_memory=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" config get maxmemory 2>/dev/null | tail -1)
        
        if [ -n "$memory_info" ]; then
            log_info "Redis memory usage: ${memory_info}"
            if [ "$max_memory" != "0" ]; then
                log_info "Redis max memory: $(numfmt --to=iec $max_memory 2>/dev/null || echo $max_memory)"
            else
                log_info "Redis max memory: unlimited"
            fi
        fi
    fi
}

# Check Redis key statistics
check_redis_keys() {
    if command -v redis-cli &> /dev/null; then
        log_info "Checking Redis key statistics..."
        
        local db_size=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" dbsize 2>/dev/null | tr -d '\r\n ')
        local expired=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" info stats 2>/dev/null | grep "expired_keys" | cut -d: -f2 | tr -d '\r\n ')
        local evicted=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" info stats 2>/dev/null | grep "evicted_keys" | cut -d: -f2 | tr -d '\r\n ')
        
        if [ -n "$db_size" ]; then
            log_info "Total keys in Redis: ${db_size}"
            log_info "Expired keys: ${expired:-0}"
            log_info "Evicted keys: ${evicted:-0}"
            
            # Warn if eviction is happening
            if [ -n "$evicted" ] && [ "$evicted" -gt 0 ]; then
                log_warn "Keys are being evicted! Consider increasing maxmemory or enabling persistence"
            fi
        fi
    fi
}

# Check Redis persistence
check_redis_persistence() {
    if command -v redis-cli &> /dev/null; then
        log_info "Checking Redis persistence settings..."
        
        local save_config=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" config get save 2>/dev/null | tail -1)
        local aof_enabled=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" config get appendonly 2>/dev/null | tail -1)
        local last_save=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" lastsave 2>/dev/null)
        
        if [ "$aof_enabled" = "yes" ]; then
            log_info "✓ AOF persistence is enabled"
        else
            log_warn "AOF persistence is disabled"
        fi
        
        if [ -n "$save_config" ] && [ "$save_config" != '""' ]; then
            log_info "✓ RDB persistence is configured: $save_config"
            if [ -n "$last_save" ]; then
                local last_save_time=$(date -d @$last_save '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r $last_save '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
                log_info "Last RDB save: ${last_save_time:-$last_save}"
            fi
        else
            log_warn "RDB persistence is not configured"
        fi
    fi
}

# Check MySQL database size
check_mysql_stats() {
    if [ -z "$MYSQL_PASS" ]; then
        log_warn "Skipping MySQL stats check (MYSQL_PASS not set)"
        return 2
    fi
    
    if command -v mysql &> /dev/null; then
        log_info "Checking MySQL database statistics..."
        
        local table_count=$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASS" -D "$MYSQL_DB" -sN -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$MYSQL_DB'" 2>/dev/null)
        
        if [ -n "$table_count" ]; then
            log_info "Number of tables in ${MYSQL_DB}: ${table_count}"
            
            # Get database size
            local db_size=$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASS" -sN -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) FROM information_schema.tables WHERE table_schema='$MYSQL_DB'" 2>/dev/null)
            if [ -n "$db_size" ]; then
                log_info "Database size: ${db_size} MB"
            fi
        fi
    fi
}

# Monitor for cache misses and slow queries
check_performance_metrics() {
    log_info "Checking performance metrics..."
    
    if command -v redis-cli &> /dev/null; then
        # Check hit rate
        local keyspace_hits=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" info stats 2>/dev/null | grep "keyspace_hits" | cut -d: -f2 | tr -d '\r\n ')
        local keyspace_misses=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" info stats 2>/dev/null | grep "keyspace_misses" | cut -d: -f2 | tr -d '\r\n ')
        
        if [ -n "$keyspace_hits" ] && [ -n "$keyspace_misses" ]; then
            local total=$((keyspace_hits + keyspace_misses))
            if [ $total -gt 0 ]; then
                # Use awk for portable floating point arithmetic
                local hit_rate=$(awk "BEGIN {printf \"%.2f\", ($keyspace_hits / $total) * 100}")
                log_info "Cache hit rate: ${hit_rate}%"
                
                # Use awk for comparison as well
                local is_low=$(awk "BEGIN {print ($hit_rate < 80) ? 1 : 0}")
                if [ "$is_low" -eq 1 ]; then
                    log_warn "Cache hit rate is below 80%. Consider reviewing caching strategy."
                fi
            fi
        fi
        
        # Check for slow commands
        local slowlog_len=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" slowlog len 2>/dev/null)
        if [ -n "$slowlog_len" ] && [ "$slowlog_len" -gt 0 ]; then
            log_warn "Redis slowlog has ${slowlog_len} entries. Check with 'redis-cli slowlog get 10'"
        fi
    fi
}

# Main monitoring function
main() {
    echo "=========================================="
    echo "Redis-Database Synchronization Monitor"
    echo "$(date '+%Y-%m-%d %H:%M:%S')"
    echo "=========================================="
    echo ""
    
    log_info "Starting synchronization check..."
    echo ""
    
    # Check connections
    check_redis_connection
    redis_status=$?
    echo ""
    
    check_mysql_connection
    mysql_status=$?
    echo ""
    
    if [ $redis_status -eq 0 ]; then
        check_redis_memory
        echo ""
        
        check_redis_keys
        echo ""
        
        check_redis_persistence
        echo ""
        
        check_performance_metrics
        echo ""
    fi
    
    if [ $mysql_status -eq 0 ]; then
        check_mysql_stats
        echo ""
    fi
    
    # Final summary
    echo "=========================================="
    if [ $redis_status -eq 0 ] && [ $mysql_status -eq 0 ]; then
        log_info "✓ Both Redis and MySQL are operational"
        log_info "Synchronization monitoring completed successfully"
    else
        log_error "✗ Some services are not available"
        log_error "Please check the errors above"
    fi
    echo "=========================================="
    
    # Return status
    if [ $redis_status -eq 0 ] && [ $mysql_status -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# Run main function
main
exit $?
