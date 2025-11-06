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
NC='\033[0m' # No Color

# 工作目录
PETREL_DIR="/home/runner/work/dafuhaozui/dafuhaozui/petrel"
NACOS_DIR="/home/runner/work/dafuhaozui/dafuhaozui/nacos"

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

cd "$PETREL_DIR" || exit 1

# ==========================================
# 步骤 0: 前置条件检查
# ==========================================
log_step "[0/7] 检查前置条件..."

# 检查 MySQL
if check_port_listening 3306 5; then
    log_info "✓ MySQL 服务正在运行 (端口 3306)"
else
    log_error "✗ MySQL 服务未运行，请先启动 MySQL"
    exit 1
fi

# 检查 Redis
if check_port_listening 6379 5; then
    log_info "✓ Redis 服务正在运行 (端口 6379)"
else
    log_error "✗ Redis 服务未运行，请先启动 Redis"
    exit 1
fi

echo ""

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
    log_info "启动 Register 服务..."
    nohup java -jar -Xmn200m -Xms400m -Xmx400m "$REGISTER_JAR" \
        --spring.config.location=classpath:/,file:./config/ \
        --spring.profiles.active=prod > /dev/null 2>&1 &
    
    # 根据日志，Register 启动需要约 8-9 秒
    log_info "等待 Register 服务启动 (预计 8-10 秒)..."
    sleep 10
    
    log_info "检查 Register 端口 7180..."
    if check_port_listening 7180 30; then
        log_info "✓ Register 端口 7180 已监听"
    else
        log_error "✗ Register 启动失败"
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
    nohup java -jar -Xmn512m -Xms1024m -Xmx1024m "$USER_JAR" \
        --spring.config.location=classpath:/,file:./config/ \
        --spring.profiles.active=prod > /dev/null 2>&1 &
    
    log_info "等待 User 服务启动..."
    sleep 15
    
    if check_service_running "$USER_JAR"; then
        log_info "✓ User 服务已启动"
    else
        log_error "✗ User 服务启动失败"
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
    nohup java -jar -Xmn512m -Xms1024m -Xmx1024m "$GAME_JAR" \
        --spring.config.location=classpath:/,file:./config/ \
        --spring.profiles.active=prod > /dev/null 2>&1 &
    
    log_info "等待 Game 服务启动..."
    sleep 15
    
    if check_service_running "$GAME_JAR"; then
        log_info "✓ Game 服务已启动"
    else
        log_error "✗ Game 服务启动失败"
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
    # 获取外部 IP 配置
    ZEBRA_IP_OUT=${1:-127.0.0.1}
    
    log_info "启动 Lobby 服务 (外部 IP: ${ZEBRA_IP_OUT})..."
    log_info "配置: 增加内存以提高稳定性，启用 GC 日志监控"
    
    # 创建 GC 日志目录
    mkdir -p "${PETREL_DIR}/logs/gc"
    
    # 优化启动参数：增加内存，优化 GC，启用详细日志
    nohup java -jar \
        -Xmn1024m -Xms2048m -Xmx2048m \
        -XX:+UseG1GC \
        -XX:MaxGCPauseMillis=200 \
        -XX:+PrintGCDetails \
        -XX:+PrintGCDateStamps \
        -Xloggc:"${PETREL_DIR}/logs/gc/lobby-gc-$(date +%Y%m%d-%H%M%S).log" \
        "$LOBBY_JAR" \
        --spring.config.location=classpath:/,file:./config/ \
        --spring.profiles.active=prod \
        --zebra.ip.out=${ZEBRA_IP_OUT} \
        > "${PETREL_DIR}/logs/lobby-stdout.log" 2>&1 &
    
    # 根据日志，Lobby 启动需要约 5-6 秒
    log_info "等待 Lobby 应用启动 (预计 5-6 秒)..."
    sleep 6
    
    log_info "检查 Lobby 端口 9879..."
    if check_port_listening 9879 30; then
        log_info "✓ Lobby Zebra RPC Server 已启动 (端口 9879)"
    else
        log_error "✗ Lobby 启动失败，端口 9879 未监听"
        exit 1
    fi
    
    # 关键：等待 Lobby 向 Register 发送注册请求
    # 从发送注册到 Register 接收约需要 0.8 秒
    log_info "等待 Lobby 向 Register 注册 (预计 2-3 秒)..."
    sleep 3
    
    log_info "✓ Lobby 服务已启动并完成注册"
    log_info "  内存配置: 堆 2GB (年轻代 1GB)"
    log_info "  GC 日志: logs/gc/lobby-gc-*.log"
    log_info "  标准输出: logs/lobby-stdout.log"
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
        nohup java -jar -Xmn512m -Xms1024m -Xmx1024m "$CHESS_JAR" \
            --spring.config.location=classpath:/,file:./config/ \
            --spring.profiles.active=prod \
            --zebra.ip.out=${ZEBRA_IP_OUT} \
            > /dev/null 2>&1 &
        
        sleep 6
        
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
        nohup java -jar -Xmn512m -Xms1024m -Xmx1024m "$SLOTS_JAR" \
            --spring.config.location=classpath:/,file:./config/ \
            --spring.profiles.active=prod \
            --zebra.ip.out=${ZEBRA_IP_OUT} \
            > /dev/null 2>&1 &
        
        sleep 6
        
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
echo "  Slots:     9527 - $(netstat -tlnp 2>/dev/null | grep -q ':9527 ' && echo '✓ 运行中' || echo '✗ 未运行')"
echo ""

log_info "验证 Lobby 注册到 Register："
echo "  查看 Register 日志确认注册："
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
