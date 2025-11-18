#!/bin/bash

# ============================================
# Petrel 游戏系统完整启动脚本
# 包含前置检查、Nacos 启动、服务启动和验证
# ============================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # 无颜色

# 工作目录
PETREL_DIR="/home/runner/work/dafuhaozui/dafuhaozui/petrel"
NACOS_DIR="/home/runner/work/dafuhaozui/dafuhaozui/nacos"

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

# 检查服务是否运行
check_service_running() {
    local service_name=$1
    if ps aux | grep -q "[${service_name:0:1}]${service_name:1}"; then
        return 0
    else
        return 1
    fi
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

# 等待服务端口可用
wait_for_port() {
    local port=$1
    local max_wait=$2
    local elapsed=0
    
    log_info "等待端口 ${port} 可用..."
    while [ $elapsed -lt $max_wait ]; do
        if check_port_listening $port; then
            log_info "端口 ${port} 已就绪"
            return 0
        fi
        sleep 5
        elapsed=$((elapsed + 5))
        echo -n "."
    done
    
    log_error "端口 ${port} 在 ${max_wait} 秒内未就绪"
    return 1
}

# 步骤 0: 前置条件检查
echo "=========================================="
echo "Petrel 游戏系统启动脚本"
echo "=========================================="
echo ""

log_info "[0/7] 检查前置条件..."

# 检查 MySQL
log_info "检查 MySQL 数据库..."
if check_port_listening 3306; then
    log_info "✓ MySQL 服务正在运行 (端口 3306)"
else
    log_error "✗ MySQL 服务未运行，请先启动 MySQL"
    exit 1
fi

# 检查 Redis
log_info "检查 Redis 服务..."
if check_port_listening 6379; then
    log_info "✓ Redis 服务正在运行 (端口 6379)"
else
    log_error "✗ Redis 服务未运行，请先启动 Redis"
    exit 1
fi

# 检查 JAR 文件是否存在
cd "$PETREL_DIR" || exit 1
if [ ! -f "petrel-kernel-register-1.0-SNAPSHOT-boot.jar" ]; then
    log_error "找不到 petrel-kernel-register-1.0-SNAPSHOT-boot.jar"
    exit 1
fi
if [ ! -f "petrel-game-lobby-1.0-SNAPSHOT-boot.jar" ]; then
    log_error "找不到 petrel-game-lobby-1.0-SNAPSHOT-boot.jar"
    exit 1
fi

log_info "前置条件检查完成"
echo ""

# 步骤 1: 启动 Nacos
log_info "[1/7] 启动 Nacos 服务注册中心..."

# 检查 Nacos 是否已经运行
if check_port_listening 6878; then
    log_warn "Nacos 已在运行，跳过启动"
else
    cd "$NACOS_DIR/bin" || exit 1
    
    # 启动 Nacos (standalone 模式)
    bash startup.sh -m standalone
    
    # 等待 Nacos 启动
    if wait_for_port 6878 60; then
        log_info "✓ Nacos 启动成功"
        
        # 额外等待 Nacos 完全初始化
        log_info "等待 Nacos 完全初始化..."
        sleep 15
    else
        log_error "✗ Nacos 启动失败"
        exit 1
    fi
fi

# 验证 Nacos Web 界面
if curl -s "http://127.0.0.1:6878/nacos/" > /dev/null; then
    log_info "✓ Nacos Web 界面可访问"
else
    log_warn "Nacos 端口已开启但 Web 界面暂时无法访问，继续..."
fi

cd "$PETREL_DIR" || exit 1
echo ""

# 步骤 2: 启动注册中心服务
log_info "[2/7] 启动注册中心服务 (petrel-kernel-register)..."

if check_service_running "petrel-kernel-register"; then
    log_warn "注册中心服务已在运行，跳过启动"
else
    nohup java -jar -Xmn200m -Xms400m -Xmx400m petrel-kernel-register-1.0-SNAPSHOT-boot.jar --spring.profiles.active=prod > /dev/null 2>&1 &
    
    if wait_for_port 7180 30; then
        log_info "✓ 注册中心服务启动成功 (端口 7180)"
        sleep 10  # 额外等待服务注册到 Nacos
    else
        log_error "✗ 注册中心服务启动失败"
        exit 1
    fi
fi

# 验证注册中心在 Nacos 中的注册状态
log_info "验证注册中心在 Nacos 中的注册..."
sleep 5
echo ""

# 步骤 3: 启动用户服务
log_info "[3/7] 启动用户服务 (petrel-kernel-user)..."

if check_service_running "petrel-kernel-user"; then
    log_warn "用户服务已在运行，跳过启动"
else
    nohup java -jar -Xmn512m -Xms1024m -Xmx1024m petrel-kernel-user-1.0-SNAPSHOT-boot.jar --spring.profiles.active=prod > /dev/null 2>&1 &
    
    log_info "等待用户服务启动..."
    sleep 15
    
    if check_service_running "petrel-kernel-user"; then
        log_info "✓ 用户服务启动成功"
    else
        log_error "✗ 用户服务启动失败"
        exit 1
    fi
fi
echo ""

# 步骤 4: 启动游戏核心服务
log_info "[4/7] 启动游戏核心服务 (petrel-kernel-game)..."

if check_service_running "petrel-kernel-game"; then
    log_warn "游戏核心服务已在运行，跳过启动"
else
    nohup java -jar -Xmn512m -Xms1024m -Xmx1024m petrel-kernel-game-1.0-SNAPSHOT-boot.jar --spring.profiles.active=prod > /dev/null 2>&1 &
    
    log_info "等待游戏核心服务启动..."
    sleep 15
    
    if check_service_running "petrel-kernel-game"; then
        log_info "✓ 游戏核心服务启动成功"
    else
        log_error "✗ 游戏核心服务启动失败"
        exit 1
    fi
fi
echo ""

# 步骤 5: 启动大厅服务
log_info "[5/7] 启动大厅服务 (petrel-game-lobby)..."

if check_service_running "petrel-game-lobby"; then
    log_warn "大厅服务已在运行，跳过启动"
else
    # 使用配置文件中的默认 zebra.ip.out，或从命令行参数覆盖
    ZEBRA_IP_OUT=${1:-127.0.0.1}
    
    log_info "使用外部 IP: ${ZEBRA_IP_OUT}"
    log_info "注意: Lobby 通过 Zebra RPC 注册到 Register 服务 (7180)"
    
    nohup java -jar -Xmn512m -Xms1024m -Xmx1024m \
        petrel-game-lobby-1.0-SNAPSHOT-boot.jar \
        --spring.profiles.active=prod \
        --zebra.ip.out=${ZEBRA_IP_OUT} \
        > /dev/null 2>&1 &
    
    if wait_for_port 9879 20; then
        log_info "✓ 大厅服务启动成功 (端口 9879)"
        sleep 10  # 等待服务注册到 Register
    else
        log_error "✗ 大厅服务启动失败"
        exit 1
    fi
fi

# 验证大厅服务
log_info "验证大厅服务状态..."
sleep 5
echo ""

# 步骤 6: 启动老虎机服务
log_info "[6/7] 启动老虎机服务 (petrel-game-slots)..."

if check_service_running "petrel-game-slots"; then
    log_warn "老虎机服务已在运行，跳过启动"
else
    ZEBRA_IP_OUT=${1:-127.0.0.1}
    nohup java -jar -Xmn512m -Xms1024m -Xmx1024m petrel-game-slots-1.0-SNAPSHOT-boot.jar --spring.profiles.active=prod --zebra.ip.out=${ZEBRA_IP_OUT} > /dev/null 2>&1 &
    
    log_info "等待老虎机服务启动..."
    sleep 15
    
    if check_service_running "petrel-game-slots"; then
        log_info "✓ 老虎机服务启动成功"
    else
        log_warn "老虎机服务可能启动失败"
    fi
fi
echo ""

# 步骤 7: 启动 Web 服务
log_info "[7/7] 启动 Web 管理服务 (petrel-cms-web)..."

if check_service_running "petrel-cms-web"; then
    log_warn "Web 服务已在运行，跳过启动"
else
    nohup java -jar -Xmn512m -Xms1024m -Xmx1024m petrel-cms-web-1.0-SNAPSHOT.war --spring.profiles.active=prod > /dev/null 2>&1 &
    
    log_info "等待 Web 服务启动..."
    sleep 15
    
    if check_service_running "petrel-cms-web"; then
        log_info "✓ Web 服务启动成功"
    else
        log_warn "Web 服务可能启动失败"
    fi
fi
echo ""

# 最终状态检查
echo "=========================================="
echo "服务启动完成 - 状态摘要"
echo "=========================================="
echo ""

log_info "核心服务端口："
echo "  Nacos 注册中心:    http://127.0.0.1:6878/nacos"
echo "  Register 服务:     端口 7180 (Zebra RPC 注册中心)"
echo "  Lobby 大厅服务:    端口 9879 (通过 Zebra 注册到 Register)"
echo ""

log_info "运行中的 Petrel 服务进程："
ps aux | grep -E "petrel-kernel|petrel-game|petrel-cms" | grep -v grep | awk '{print "  PID:", $2, " ", $11, $12, $13}'
echo ""

log_info "服务验证："
echo "  Nacos 服务列表（Register、User、Game 等）："
echo "    curl 'http://127.0.0.1:6878/nacos/v1/ns/instance/list?serviceName=petrel-kernel-register'"
echo ""
echo "  Lobby 服务健康检查（通过 Zebra RPC 注册到 Register）："
echo "    curl 'http://127.0.0.1:9879/actuator/health'"
echo "    注意: Lobby 不在 Nacos 服务列表中，它通过 Zebra 协议注册到 Register (7180)"
echo ""

log_info "日志位置："
echo "  Nacos:     ${NACOS_DIR}/logs/"
echo "  Services:  ${PETREL_DIR}/logs/"
echo ""

log_info "启动完成！"
echo "=========================================="
