#!/bin/bash

# ============================================
# Redis-数据库同步监控脚本
# 监控Redis缓存和MySQL数据库之间的数据同步
# ============================================
#
# 使用方法:
#   基础检查: ./monitor-redis-db-sync.sh
#   
#   使用MySQL密码:
#     export MYSQL_PASS='your_password'
#     ./monitor-redis-db-sync.sh
#
#   通过环境变量自定义配置:
#     export REDIS_HOST='192.168.1.100'
#     export MYSQL_HOST='192.168.1.200'
#     export MYSQL_USER='admin'
#     export MYSQL_PASS='password'
#     ./monitor-redis-db-sync.sh
# ============================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置项
REDIS_HOST="${REDIS_HOST:-127.0.0.1}"
REDIS_PORT="${REDIS_PORT:-6379}"
MYSQL_HOST="${MYSQL_HOST:-202.189.7.196}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASS="${MYSQL_PASS:-}"
MYSQL_DB="${MYSQL_DB:-petrel_core}"

LOG_FILE="redis-db-sync-monitor.log"

# 日志记录函数
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

# 检查Redis连接
check_redis_connection() {
    log_info "检查Redis连接..."
    
    if command -v redis-cli &> /dev/null; then
        if redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping > /dev/null 2>&1; then
            log_info "✓ Redis正在运行并响应"
            return 0
        else
            log_error "✗ Redis未响应 ${REDIS_HOST}:${REDIS_PORT}"
            return 1
        fi
    else
        log_warn "未找到redis-cli，跳过Redis连接检查"
        return 2
    fi
}

# 检查MySQL连接
check_mysql_connection() {
    log_info "检查MySQL连接..."
    
    if [ -z "$MYSQL_PASS" ]; then
        log_warn "未设置MYSQL_PASS。请设置环境变量以启用MySQL检查。"
        log_warn "示例: export MYSQL_PASS='your_password'"
        return 2
    fi
    
    if command -v mysql &> /dev/null; then
        # 创建临时MySQL配置文件以安全传递密码
        local mysql_config=$(mktemp)
        cat > "$mysql_config" << EOF
[client]
password=$MYSQL_PASS
EOF
        chmod 600 "$mysql_config"
        
        if mysql --defaults-file="$mysql_config" -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -e "SELECT 1" > /dev/null 2>&1; then
            log_info "✓ MySQL正在运行并响应"
            rm -f "$mysql_config"
            return 0
        else
            log_error "✗ MySQL未响应 ${MYSQL_HOST}:${MYSQL_PORT}"
            rm -f "$mysql_config"
            return 1
        fi
    else
        log_warn "未找到mysql客户端，跳过MySQL连接检查"
        return 2
    fi
}

# 检查Redis内存使用
check_redis_memory() {
    if command -v redis-cli &> /dev/null; then
        log_info "检查Redis内存使用..."
        
        local memory_info=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" info memory 2>/dev/null | grep "used_memory_human" | cut -d: -f2 | tr -d '\r\n ')
        local max_memory=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" config get maxmemory 2>/dev/null | tail -1)
        
        if [ -n "$memory_info" ]; then
            log_info "Redis内存使用: ${memory_info}"
            if [ "$max_memory" != "0" ]; then
                log_info "Redis最大内存: $(numfmt --to=iec $max_memory 2>/dev/null || echo $max_memory)"
            else
                log_info "Redis最大内存: 无限制"
            fi
        fi
    fi
}

# 检查Redis键统计
check_redis_keys() {
    if command -v redis-cli &> /dev/null; then
        log_info "检查Redis键统计..."
        
        local db_size=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" dbsize 2>/dev/null | tr -d '\r\n ')
        local expired=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" info stats 2>/dev/null | grep "expired_keys" | cut -d: -f2 | tr -d '\r\n ')
        local evicted=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" info stats 2>/dev/null | grep "evicted_keys" | cut -d: -f2 | tr -d '\r\n ')
        
        if [ -n "$db_size" ]; then
            log_info "Redis中的总键数: ${db_size}"
            log_info "过期键数: ${expired:-0}"
            log_info "驱逐键数: ${evicted:-0}"
            
            # 如果发生驱逐则发出警告
            if [ -n "$evicted" ] && [ "$evicted" -gt 0 ]; then
                log_warn "键正在被驱逐！考虑增加maxmemory或启用持久化"
            fi
        fi
    fi
}

# 检查Redis持久化
check_redis_persistence() {
    if command -v redis-cli &> /dev/null; then
        log_info "检查Redis持久化设置..."
        
        local save_config=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" config get save 2>/dev/null | tail -1)
        local aof_enabled=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" config get appendonly 2>/dev/null | tail -1)
        local last_save=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" lastsave 2>/dev/null)
        
        if [ "$aof_enabled" = "yes" ]; then
            log_info "✓ AOF持久化已启用"
        else
            log_warn "AOF持久化已禁用"
        fi
        
        if [ -n "$save_config" ] && [ "$save_config" != '""' ]; then
            log_info "✓ RDB持久化已配置: $save_config"
            if [ -n "$last_save" ]; then
                local last_save_time=$(date -d @$last_save '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r $last_save '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
                log_info "上次RDB保存: ${last_save_time:-$last_save}"
            fi
        else
            log_warn "RDB持久化未配置"
        fi
    fi
}

# 检查MySQL数据库大小
check_mysql_stats() {
    if [ -z "$MYSQL_PASS" ]; then
        log_warn "跳过MySQL统计检查（未设置MYSQL_PASS）"
        return 2
    fi
    
    if command -v mysql &> /dev/null; then
        log_info "检查MySQL数据库统计..."
        
        # 创建临时MySQL配置文件以安全传递密码
        local mysql_config=$(mktemp)
        cat > "$mysql_config" << EOF
[client]
password=$MYSQL_PASS
EOF
        chmod 600 "$mysql_config"
        
        local table_count=$(mysql --defaults-file="$mysql_config" -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -D "$MYSQL_DB" -sN -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$MYSQL_DB'" 2>/dev/null)
        
        if [ -n "$table_count" ]; then
            log_info "${MYSQL_DB}中的表数量: ${table_count}"
            
            # 获取数据库大小
            local db_size=$(mysql --defaults-file="$mysql_config" -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -sN -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) FROM information_schema.tables WHERE table_schema='$MYSQL_DB'" 2>/dev/null)
            if [ -n "$db_size" ]; then
                log_info "数据库大小: ${db_size} MB"
            fi
        fi
        
        rm -f "$mysql_config"
    fi
}

# 监控缓存未命中和慢查询
check_performance_metrics() {
    log_info "检查性能指标..."
    
    if command -v redis-cli &> /dev/null; then
        # 检查命中率
        local keyspace_hits=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" info stats 2>/dev/null | grep "keyspace_hits" | cut -d: -f2 | tr -d '\r\n ')
        local keyspace_misses=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" info stats 2>/dev/null | grep "keyspace_misses" | cut -d: -f2 | tr -d '\r\n ')
        
        if [ -n "$keyspace_hits" ] && [ -n "$keyspace_misses" ]; then
            local total=$((keyspace_hits + keyspace_misses))
            if [ $total -gt 0 ]; then
                # 使用awk进行可移植的浮点运算
                local hit_rate=$(awk "BEGIN {printf \"%.2f\", ($keyspace_hits / $total) * 100}")
                log_info "缓存命中率: ${hit_rate}%"
                
                # 使用awk进行比较
                local is_low=$(awk "BEGIN {print ($hit_rate < 80) ? 1 : 0}")
                if [ "$is_low" -eq 1 ]; then
                    log_warn "缓存命中率低于80%。考虑审查缓存策略。"
                fi
            fi
        fi
        
        # 检查慢命令
        local slowlog_len=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" slowlog len 2>/dev/null)
        if [ -n "$slowlog_len" ] && [ "$slowlog_len" -gt 0 ]; then
            log_warn "Redis慢日志有${slowlog_len}条记录。使用'redis-cli slowlog get 10'查看"
        fi
    fi
}

# 主监控函数
main() {
    echo "=========================================="
    echo "Redis-数据库同步监控"
    echo "$(date '+%Y-%m-%d %H:%M:%S')"
    echo "=========================================="
    echo ""
    
    log_info "开始同步检查..."
    echo ""
    
    # 检查连接
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
    
    # 最终摘要
    echo "=========================================="
    if [ $redis_status -eq 0 ] && [ $mysql_status -eq 0 ]; then
        log_info "✓ Redis和MySQL都正常运行"
        log_info "同步监控成功完成"
    else
        log_error "✗ 某些服务不可用"
        log_error "请检查上述错误"
    fi
    echo "=========================================="
    
    # 返回状态
    if [ $redis_status -eq 0 ] && [ $mysql_status -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# 运行主函数
main
exit $?
