#!/bin/bash

# ============================================
# Petrel 游戏系统正确的启动脚本
# 基于 2022 年生产日志分析的最佳实践
# ============================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 工作目录
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PETREL_DIR="$SCRIPT_DIR"
NACOS_DIR=$(cd "$SCRIPT_DIR/../nacos" && pwd)
# 每个服务现在将直接引用其特定的配置文件路径
# CONFIG_FILE_PATH="${PETREL_DIR}/config/application-prod.yml"

# JAR 文件
REGISTER_JAR="petrel-kernel-register-1.0-SNAPSHOT-boot.jar"
USER_JAR="petrel-kernel-user-1.0-SNAPSHOT-boot.jar"
GAME_JAR="petrel-kernel-game-1.0-SNAPSHOT-boot.jar"
LOBBY_JAR="petrel-game-lobby-1.0-SNAPSHOT-boot.jar"
SLOTS_JAR="petrel-game-slots-1.0-SNAPSHOT-boot.jar"
CHESS_JAR="petrel-game-chess-1.0-SNAPSHOT-boot.jar"

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 清理旧进程函数
cleanup_processes() {
    log_step "[-] 清理残留的 Java 进程..."
    
    # 查找并终止 Nacos 进程
    NACOS_PIDS=$(ps aux | grep 'nacos-server' | grep -v grep | awk '{print $2}')
    if [ -n "$NACOS_PIDS" ]; then
        log_info "发现残留的 Nacos 进程: $NACOS_PIDS. 正在终止..."
        kill -9 $NACOS_PIDS
        sleep 2
        log_info "Nacos 进程已清理."
    else
        log_info "没有发现残留的 Nacos 进程."
    fi

    # 查找并终止 Petrel 进程
    PETREL_PIDS=$(ps aux | grep 'petrel-' | grep -v grep | awk '{print $2}')
    if [ -n "$PETREL_PIDS" ]; then
        log_info "发现残留的 Petrel 游戏服务进程: $PETREL_PIDS. 正在终止..."
        kill -9 $PETREL_PIDS
        sleep 2
        log_info "Petrel 进程已清理."
    else
        log_info "没有发现残留的 Petrel 游戏服务进程."
    fi
    echo ""
}

# 检查服务是否运行
check_service_running() {
    local jar_name=$1
    if ps aux | grep -q "[${jar_name:0:1}]${jar_name:1}"; then
        return 0
    else
        return 1
    fi
}

# 检查端口是否监听
check_port_listening() {
    local port=$1
    local max_attempts=${2:-30}
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if netstat -tlnp 2>/dev/null | grep -q ":${port} " || ss -tlnp 2>/dev/null | grep -q ":${port} "; then
            return 0
        fi
        sleep 1
        attempt=$((attempt + 1))
    done
    return 1
}

# 等待 HTTP 端点可用
check_http_endpoint() {
    local url=$1
    local max_attempts=${2:-30}
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s -f "$url" > /dev/null 2>&1; then
            return 0
        fi
        sleep 1
        attempt=$((attempt + 1))
    done
    return 1
}

echo "=========================================="
echo "Petrel 游戏系统正确启动脚本"
echo "基于 2022-12-18 生产日志分析"
echo "=========================================="
echo ""

# 调用清理函数
cleanup_processes

cd "$PETREL_DIR" || exit 1

# 创建日志目录
log_info "确保日志目录存在..."
mkdir -p "${PETREL_DIR}/logs"
echo ""

# ==========================================
# 步骤 0: 前置条件检查 (已禁用)
# ==========================================
# log_step "[0/7] 检查前置条件..."

# 检查 MySQL
# if check_port_listening 3306 5; then
#     log_info "✓ MySQL 服务正在运行 (端口 3306)"
# else
#     log_error "✗ MySQL 服务未运行，请先启动 MySQL"
#     exit 1
# fi

# 检查 Redis
# if check_port_listening 6379 5; then
#     log_info "✓ Redis 服务正在运行 (端口 6379)"
# else
#     log_error "✗ Redis 服务未运行，请先启动 Redis"
#     exit 1
# fi

# echo ""

# ==========================================
# 步骤 1: 启动 Nacos
# ==========================================
log_step "[1/7] 启动 Nacos 服务注册中心..."

if check_port_listening 6878 5; then
    log_warn "Nacos 已在运行 (端口 6878)，跳过启动"
else
    cd "$NACOS_DIR/bin" || exit 1
    log_info "启动 Nacos (standalone 模式)..."
    bash startup.sh -m standalone
    
    log_info "等待 Nacos 端口 6878 可用..."
    if check_port_listening 6878 60; then
        log_info "✓ Nacos 端口已开启"
    else
        log_error "✗ Nacos 启动失败，端口 6878 未监听"
        exit 1
    fi
    
    # 等待 Nacos HTTP 服务完全启动
    log_info "等待 Nacos HTTP 服务就绪..."
    sleep 20
    
    if check_http_endpoint "http://127.0.0.1:6878/nacos/" 30; then
        log_info "✓ Nacos HTTP 服务已就绪"
    else
        log_warn "Nacos HTTP 服务响应慢，继续启动..."
    fi
fi

cd "$PETREL_DIR" || exit 1
echo ""

# ==========================================
# 步骤 2: 启动 Register 服务 (关键：Zebra 注册中心)
# ==========================================
log_step "[2/7] 启动 Register 服务 (Zebra RPC 注册中心，端口 7180)..."

if check_service_running "$REGISTER_JAR"; then
    log_warn "Register 服务已在运行，跳过启动"
else
    # Start Register
    echo "Starting Register service..."
    REGISTER_JAR=$(find "$PETREL_DIR" -name "petrel-kernel-register-*.jar" | head -n 1)
    if [ -z "$REGISTER_JAR" ]; then
        echo "Error: petrel-kernel-register JAR not found."
        exit 1
    fi

    # --- BEGIN DIAGNOSTICS ---
    echo "--- Diagnosing Register service startup ---"
    echo "Working directory: $(pwd)"
    echo "Petrel directory: ${PETREL_DIR}"
    CONFIG_FILE="${PETREL_DIR}/config/kernel-register/application-prod.yml"
    echo "Config file path variable: ${CONFIG_FILE}"
    echo "Checking file existence and permissions:"
    ls -l "${CONFIG_FILE}"
    echo "Contents of the configuration file:"
    cat "${CONFIG_FILE}"
    echo "--- End Diagnostics ---"

    nohup java -jar \
        -Dapp.name=petrel-register \
        -Xmn200m -Xms400m -Xmx400m \
        "$REGISTER_JAR" \
        --spring.config.location="file:${CONFIG_FILE}" \
        > "${PETREL_DIR}/logs/register-startup.log" 2>&1 &
    REGISTER_PID=$!
    echo "Register service started with PID: $REGISTER_PID"

    # Wait for Register service to be healthy
    # (Adding a simple sleep for now, a proper health check is better)
    echo "Waiting for Register service to start..."
    sleep 30
    
    log_info "检查 Register 端口 7180..."
    if check_port_listening 7180 30; then
        log_info "✓ Register 端口 7180 已监听"
    else
        log_error "✗ Register 启动失败. 正在显示启动日志..."
        echo -e "${RED}==================== REGISTER STARTUP LOG ====================${NC}"
        cat "${PETREL_DIR}/logs/register-startup.log"
        echo -e "${RED}=============================================================="${NC}
        exit 1
    fi
    
    # 关键：等待 Register 的 HTTP 接口完全就绪
    # 根据日志，Register 启动后需要额外时间初始化 DispatcherServlet
    log_info "等待 Register HTTP 接口完全就绪 (额外 10 秒)..."
    sleep 10
    
    log_info "✓ Register 服务已完全启动并准备接受注册请求"
fi

echo ""

# ==========================================
# 步骤 3: 启动 User 服务
# ==========================================
log_step "[3/7] 启动 User 服务 (端口 8719)..."

if check_service_running "$USER_JAR"; then
    log_warn "User 服务已在运行，跳过启动"
else
    log_info "启动 User 服务..."
    CONFIG_FILE="${PETREL_DIR}/config/kernel-user/application-prod.yml"
    nohup java -jar \
        -Dapp.name=petrel-user \
        -Xmn512m -Xms1024m -Xmx1024m \
        "$USER_JAR" \
        --spring.config.location="file:${CONFIG_FILE}" \
        > "${PETREL_DIR}/logs/user-startup.log" 2>&1 &

    log_info "等待 User 服务启动..."
    sleep 15
    
    if check_service_running "$USER_JAR"; then
        log_info "✓ User 服务已启动"
    else
        log_error "✗ User 服务启动失败. 正在显示启动日志..."
        echo -e "${RED}==================== USER STARTUP LOG ====================${NC}"
        cat "${PETREL_DIR}/logs/user-startup.log"
        echo -e "${RED}============================================================"${NC}
        exit 1
    fi
fi

echo ""

# ==========================================
# 步骤 4: 启动 Game 服务
# ==========================================
log_step "[4/7] 启动 Game 服务..."

if check_service_running "$GAME_JAR"; then
    log_warn "Game 服务已在运行，跳过启动"
else
    log_info "启动 Game 服务..."
    CONFIG_FILE="${PETREL_DIR}/config/kernel-game/application-prod.yml"
    nohup java -jar \
        -Dapp.name=petrel-game \
        -Xmn512m -Xms1024m -Xmx1024m \
        "$GAME_JAR" \
        --spring.config.location="file:${CONFIG_FILE}" \
        > "${PETREL_DIR}/logs/game-startup.log" 2>&1 &
    
    log_info "等待 Game 服务启动..."
    sleep 15
    
    if check_service_running "$GAME_JAR"; then
        log_info "✓ Game 服务已启动"
    else
        log_error "✗ Game 服务启动失败. 正在显示启动日志..."
        echo -e "${RED}==================== GAME STARTUP LOG ====================${NC}"
        cat "${PETREL_DIR}/logs/game-startup.log"
        echo -e "${RED}============================================================"${NC}
        exit 1
    fi
fi

echo ""

# ==========================================
# 步骤 5: 启动 Lobby 服务
# 关键：确保在 Register 完全就绪后启动
# 增加内存以避免频繁 GC 导致心跳超时
# ==========================================
log_step "[5/7] 启动 Lobby 服务 (端口 9879) - 优化配置防止掉线..."

if check_service_running "$LOBBY_JAR"; then
    log_warn "Lobby 服务已在运行，跳过启动"
else
    log_info "启动 Lobby 服务..."
    CONFIG_FILE="${PETREL_DIR}/config/game-lobby/application-prod.yml"
    nohup java -jar \
        -Dapp.name=petrel-lobby \
        -Xmn512m -Xms1024m -Xmx1024m \
        "$LOBBY_JAR" \
        --spring.config.location="file:${CONFIG_FILE}" \
        > "${PETREL_DIR}/logs/lobby-startup.log" 2>&1 &

    log_info "等待 Lobby 服务启动..."
    sleep 15
    
    if check_service_running "$LOBBY_JAR"; then
        log_info "✓ Lobby 服务已启动"
    else
        log_error "✗ Lobby 服务启动失败. 正在显示启动日志..."
        echo -e "${RED}==================== LOBBY STARTUP LOG ====================${NC}"
        cat "${PETREL_DIR}/logs/lobby-startup.log"
        echo -e "${RED}============================================================"${NC}
        exit 1
    fi
fi

echo ""

# ==========================================
# 步骤 6: 启动 Chess 服务
# ==========================================
log_step "[6/7] 启动 Chess 服务 (端口 9637)..."

if [ -f "$CHESS_JAR" ]; then
    if check_service_running "$CHESS_JAR"; then
        log_warn "Chess 服务已在运行，跳过启动"
    else
        ZEBRA_IP_OUT=${1:-127.0.0.1}
        
        log_info "启动 Chess 服务..."
        CONFIG_FILE="${PETREL_DIR}/config/game-chess/application-prod.yml"
        nohup java -jar \
            -Xmn512m -Xms1024m -Xmx1024m \
            "$CHESS_JAR" \
            --spring.config.location="file:${CONFIG_FILE}" \
            --zebra.ip.out=${ZEBRA_IP_OUT} \
            > "${PETREL_DIR}/logs/chess-startup.log" 2>&1 &
        
        log_info "等待 Chess 服务启动..."
        sleep 10
        
        if check_port_listening 9637 30; then
            log_info "✓ Chess 服务已启动 (端口 9637)"
            sleep 3
        else
            log_warn "Chess 服务可能启动失败"
        fi
    fi
else
    log_warn "Chess JAR 文件不存在，跳过"
fi

echo ""

# ==========================================
# 步骤 7: 启动 Slots 服务
# ==========================================
log_step "[7/7] 启动 Slots 服务 (端口 9527)..."

if [ -f "$SLOTS_JAR" ]; then
    if check_service_running "$SLOTS_JAR"; then
        log_warn "Slots 服务已在运行，跳过启动"
    else
        ZEBRA_IP_OUT=${1:-127.0.0.1}
        
        log_info "启动 Slots 服务..."
        CONFIG_FILE="${PETREL_DIR}/config/game-slots/application-prod.yml"
        nohup java -jar \
            -Xmn512m -Xms1024m -Xmx1024m \
            "$SLOTS_JAR" \
            --spring.config.location="file:${CONFIG_FILE}" \
            --zebra.ip.out=${ZEBRA_IP_OUT} \
            > "${PETREL_DIR}/logs/slots-startup.log" 2>&1 &
        
        log_info "等待 Slots 服务启动..."
        sleep 10
        
        if check_port_listening 9527 30; then
            log_info "✓ Slots 服务已启动 (端口 9527)"
            sleep 3
        else
            log_warn "Slots 服务可能启动失败"
        fi
    fi
else
    log_warn "Slots JAR 文件不存在，跳过"
fi

echo ""

# ==========================================
# 可选: 启动 CMS Web 后台管理系统
# ==========================================
CMS_WAR="petrel-cms-web-1.0-SNAPSHOT.war"
if [ -f "$CMS_WAR" ]; then
    if check_service_running "$CMS_WAR"; then
        log_warn "CMS Web 已在运行，跳过启动"
    else
        log_step "[CMS] 启动 CMS Web 后台管理系统..."
        nohup java -jar \
            -Dapp.name=petrel-cms-web \
            -Xmn256m -Xms512m -Xmx512m \
            "$CMS_WAR" \
            > "${PETREL_DIR}/logs/petrel-cms-web.log" 2>&1 &
        log_info "等待 CMS Web 启动..."
        sleep 10
        if check_service_running "$CMS_WAR"; then
            log_info "\u2713 CMS Web 已启动"
        else
            log_warn "CMS Web 启动可能失败，请查看 ${PETREL_DIR}/logs/petrel-cms-web.log"
        fi
    fi
else
    log_warn "未找到 CMS Web WAR 文件 ($CMS_WAR)，跳过启动"
fi

echo ""

# ==========================================
# 最终验证
# ==========================================
echo "=========================================="
echo "服务启动完成 - 验证状态"
echo "=========================================="
echo ""

log_info "运行中的 Petrel 服务："
ps aux | grep -E "petrel-kernel|petrel-game" | grep -v grep | awk '{print "  ", $11, $12, $13, $14}'
echo ""

log_info "端口监听状态："
echo "  Nacos:     6878 - $(netstat -tlnp 2>/dev/null | grep -q ':6878 ' && echo '✓ 运行中' || echo '✗ 未运行')"
echo "  Register:  7180 - $(netstat -tlnp 2>/dev/null | grep -q ':7180 ' && echo '✓ 运行中' || echo '✗ 未运行')"
echo "  Lobby:     9879 - $(netstat -tlnp 2>/dev/null | grep -q ':9879 ' && echo '✓ 运行中' || echo '✗ 未运行')"
echo "  Chess:     9637 - $(netstat -tlnp 2>/dev/null | grep -q ':9637 ' && echo '✓ 运行中' || echo '✗ 未运行')"
echo "  tail -20 ${PETREL_DIR}/logs/petrel-kernel-register/info_7180.log | grep 'Register receive registry msg.*lobby'"
echo ""
echo "  查看 Lobby 日志确认连接："
echo "  tail -20 ${PETREL_DIR}/logs/petrel-game-lobby/info_9879.txt | grep 'StartAfter send register msg'"
echo ""

log_info "监控 Lobby 连接稳定性（防止掉线）："
echo "  持续监控连接状态："
echo "  watch -n 10 'tail -5 ${PETREL_DIR}/logs/petrel-kernel-register/info_7180.log | grep lobby'"
echo ""
echo "  监控 GC 情况（防止 GC 暂停导致心跳超时）："
echo "  tail -f ${PETREL_DIR}/logs/gc/lobby-gc-*.log"
echo ""
echo "  如果发现 Lobby 掉线："
echo "  1. 检查 GC 日志，查看是否有长时间暂停"
echo "  2. 检查是否有大量后台管理系统的查询"
echo "  3. 考虑进一步增加内存或优化后台查询缓存"
echo "  4. 查看详细分析: Lobby掉线问题分析.md"
echo ""

log_info "关键时间点说明（基于 2022-12-18 生产日志）："
echo "  1. Register 启动需要:      8-10 秒"
echo "  2. Register HTTP 就绪:     启动后额外 10 秒"
echo "  3. Lobby 启动需要:         5-6 秒"
echo "  4. Lobby 发送注册:         启动后 0.2 秒"
echo "  5. Register 接收注册:      Lobby 发送后 0.8 秒"
echo "  6. 总时间（Register → Lobby 注册完成）: 约 25-30 秒"
echo ""

log_info "Lobby 优化配置："
echo "  内存:    堆 2GB (从 1GB 增加，减少 GC 频率)"
echo "  GC:      G1GC 最大暂停 200ms (减少心跳超时风险)"
echo "  日志:    启用 GC 日志监控"
echo "  目的:    防止 GC 暂停和内存不足导致掉线"
echo ""

log_info "常见问题排查："
echo "  如果 Lobby 注册失败："
echo "  1. 确认 Register 服务完全启动（检查端口 7180）"
echo "  2. 确认 Register HTTP 接口就绪（启动后等待至少 20 秒）"
echo "  3. 确认 Nacos 服务正常运行"
echo "  4. 查看 Register 日志: tail -f logs/petrel-kernel-register/info_7180.log"
echo "  5. 查看 Lobby 日志: tail -f logs/petrel-game-lobby/info_9879.txt"
echo ""
echo "  如果 Lobby 注册后掉线："
echo "  1. 检查 GC 日志: tail -f logs/gc/lobby-gc-*.log"
echo "  2. 监控连接: watch -n 10 'tail -5 logs/petrel-kernel-register/info_7180.log'"
echo "  3. 查看后台访问日志: tail -f logs/petrel-cms-web/info_721.log"
echo "  4. 参考详细分析: Lobby掉线问题分析.md"
echo ""

log_info "启动完成！"
echo "=========================================="
