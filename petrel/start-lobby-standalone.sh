#!/bin/bash

# ============================================
# Lobby 服务独立启动脚本
# 不依赖 Nacos，作为独立服务运行
# ============================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 工作目录
PETREL_DIR="/home/runner/work/dafuhaozui/dafuhaozui/petrel"

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查端口是否监听
check_port_listening() {
    local port=$1
    if netstat -tlnp 2>/dev/null | grep -q ":${port} " || ss -tlnp 2>/dev/null | grep -q ":${port} "; then
        return 0
    else
        return 1
    fi
}

echo "=========================================="
echo "Lobby 服务独立启动脚本"
echo "不注册到 Nacos，作为独立服务运行"
echo "=========================================="
echo ""

cd "$PETREL_DIR" || exit 1

# 检查前置条件
log_info "[1/4] 检查前置条件..."

# 检查 MySQL
if check_port_listening 3306; then
    log_info "✓ MySQL 服务正在运行 (端口 3306)"
else
    log_error "✗ MySQL 服务未运行，请先启动 MySQL"
    exit 1
fi

# 检查 Redis
if check_port_listening 6379; then
    log_info "✓ Redis 服务正在运行 (端口 6379)"
else
    log_error "✗ Redis 服务未运行，请先启动 Redis"
    exit 1
fi

# 检查 JAR 文件
if [ ! -f "petrel-game-lobby-1.0-SNAPSHOT-boot.jar" ]; then
    log_error "找不到 petrel-game-lobby-1.0-SNAPSHOT-boot.jar"
    exit 1
fi

log_info "前置条件检查完成"
echo ""

# 检查 Lobby 是否已运行
log_info "[2/4] 检查 Lobby 服务状态..."

if check_port_listening 9879; then
    log_warn "端口 9879 已被占用，可能 Lobby 服务已在运行"
    read -p "是否停止现有服务并重启? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "停止现有 Lobby 服务..."
        P_ID=$(ps -ef | grep -w "petrel-game-lobby-1.0-SNAPSHOT-boot.jar" | grep -v "grep" | awk '{print $2}')
        if [ "$P_ID" != "" ]; then
            kill -15 "$P_ID"
            sleep 3
            
            # 如果还在运行，强制终止
            P_ID=$(ps -ef | grep -w "petrel-game-lobby-1.0-SNAPSHOT-boot.jar" | grep -v "grep" | awk '{print $2}')
            if [ "$P_ID" != "" ]; then
                kill -9 "$P_ID"
                sleep 2
            fi
            log_info "✓ 现有服务已停止"
        fi
    else
        log_info "保持现有服务运行，退出"
        exit 0
    fi
fi
echo ""

# 获取外部 IP 配置
log_info "[3/4] 配置服务参数..."

# 默认使用 127.0.0.1，也可以从命令行参数获取
ZEBRA_IP_OUT=${1:-127.0.0.1}
ZEBRA_PORT=${2:-9879}

log_info "外部访问 IP: ${ZEBRA_IP_OUT}"
log_info "服务端口: ${ZEBRA_PORT}"
log_info "运行模式: 独立模式 (不注册到 Nacos)"
echo ""

# 启动 Lobby 服务
log_info "[4/4] 启动 Lobby 服务..."

nohup java -jar -Xmn512m -Xms1024m -Xmx1024m \
    petrel-game-lobby-1.0-SNAPSHOT-boot.jar \
    --spring.profiles.active=prod \
    --spring.cloud.nacos.discovery.enabled=false \
    --zebra.ip.out=${ZEBRA_IP_OUT} \
    --zebra.port=${ZEBRA_PORT} \
    > /dev/null 2>&1 &

LOBBY_PID=$!
log_info "Lobby 服务已启动，PID: ${LOBBY_PID}"

# 等待服务启动
log_info "等待服务启动..."
sleep 10

# 验证服务状态
echo ""
log_info "验证服务状态..."

if check_port_listening ${ZEBRA_PORT}; then
    log_info "✓ Lobby 服务端口 ${ZEBRA_PORT} 正在监听"
else
    log_error "✗ Lobby 服务端口 ${ZEBRA_PORT} 未监听"
    log_error "请检查日志: ${PETREL_DIR}/logs/petrel-game-lobby/"
    exit 1
fi

# 检查进程
if ps -p ${LOBBY_PID} > /dev/null; then
    log_info "✓ Lobby 服务进程正在运行 (PID: ${LOBBY_PID})"
else
    log_error "✗ Lobby 服务进程已退出"
    log_error "请检查日志: ${PETREL_DIR}/logs/petrel-game-lobby/"
    exit 1
fi

# 等待额外时间让服务完全启动
log_info "等待服务完全启动..."
sleep 5

echo ""
echo "=========================================="
echo "Lobby 服务启动完成"
echo "=========================================="
echo ""

log_info "服务信息："
echo "  进程 PID:       ${LOBBY_PID}"
echo "  服务端口:       ${ZEBRA_PORT}"
echo "  外部访问 IP:    ${ZEBRA_IP_OUT}"
echo "  运行模式:       独立模式 (不注册到 Nacos)"
echo ""

log_info "服务访问："
echo "  健康检查:       curl http://127.0.0.1:${ZEBRA_PORT}/actuator/health"
echo "  直接访问 API:   http://127.0.0.1:${ZEBRA_PORT}/"
echo ""

log_info "日志位置："
echo "  ${PETREL_DIR}/logs/petrel-game-lobby/"
echo ""

log_info "查看日志："
echo "  tail -f ${PETREL_DIR}/logs/petrel-game-lobby/info_*.log"
echo ""

log_info "停止服务："
echo "  kill ${LOBBY_PID}"
echo "  或使用: ${PETREL_DIR}/stop-all-improved.sh"
echo ""

log_info "注意事项："
echo "  1. Lobby 服务不会在 Nacos 中注册"
echo "  2. 其他服务需要通过 IP:${ZEBRA_PORT} 直接访问"
echo "  3. 服务独立运行，不依赖 Nacos 的可用性"
echo ""

log_info "启动完成！"
echo "=========================================="

# 显示最近的日志
if [ -d "${PETREL_DIR}/logs/petrel-game-lobby" ]; then
    LATEST_LOG=$(ls -t ${PETREL_DIR}/logs/petrel-game-lobby/info_*.log 2>/dev/null | head -1)
    if [ -n "$LATEST_LOG" ]; then
        echo ""
        log_info "最近的日志输出 (${LATEST_LOG}):"
        echo "----------------------------------------"
        tail -30 "$LATEST_LOG"
        echo "----------------------------------------"
    fi
fi
