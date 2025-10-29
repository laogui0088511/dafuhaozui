#!/bin/bash

# ============================================
# Petrel 游戏系统完整关闭脚本
# 按照正确顺序关闭所有服务
# ============================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

# 关闭服务函数
stop_service() {
    local service_name=$1
    local jar_name=$2
    
    log_info "关闭 ${service_name}..."
    
    P_ID=$(ps -ef | grep -w "$jar_name" | grep -v "grep" | awk '{print $2}')
    if [ "$P_ID" == "" ]; then
        log_info "  ${service_name} 未运行或已停止"
    else
        kill -15 "$P_ID"  # 先尝试优雅关闭
        sleep 3
        
        # 检查是否还在运行
        P_ID=$(ps -ef | grep -w "$jar_name" | grep -v "grep" | awk '{print $2}')
        if [ "$P_ID" != "" ]; then
            log_warn "  ${service_name} 未响应 SIGTERM，使用 SIGKILL..."
            kill -9 "$P_ID"
            sleep 2
        fi
        
        log_info "  ✓ ${service_name} 已停止"
    fi
}

echo "=========================================="
echo "Petrel 游戏系统关闭脚本"
echo "=========================================="
echo ""

cd "$PETREL_DIR" || exit 1

# 按照与启动相反的顺序关闭服务

log_info "[1/8] 关闭 Web 管理服务..."
stop_service "Web服务" "petrel-cms-web-1.0-SNAPSHOT.war"
echo ""

log_info "[2/8] 关闭老虎机服务..."
stop_service "老虎机服务" "petrel-game-slots-1.0-SNAPSHOT-boot.jar"
echo ""

log_info "[3/8] 关闭大厅服务..."
stop_service "大厅服务" "petrel-game-lobby-1.0-SNAPSHOT-boot.jar"
echo ""

log_info "[4/8] 关闭游戏核心服务..."
stop_service "游戏核心服务" "petrel-kernel-game-1.0-SNAPSHOT-boot.jar"
echo ""

log_info "[5/8] 关闭用户服务..."
stop_service "用户服务" "petrel-kernel-user-1.0-SNAPSHOT-boot.jar"
echo ""

log_info "[6/8] 关闭注册中心服务..."
stop_service "注册中心服务" "petrel-kernel-register-1.0-SNAPSHOT-boot.jar"
echo ""

# 等待所有服务完全停止
log_info "[7/8] 等待所有服务完全停止..."
sleep 5
echo ""

# 关闭 Nacos (可选)
log_info "[8/8] 关闭 Nacos 服务注册中心..."
read -p "是否关闭 Nacos? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd "$NACOS_DIR/bin" || exit 1
    bash shutdown.sh
    log_info "  ✓ Nacos 已停止"
else
    log_info "  保持 Nacos 运行"
fi
echo ""

# 最终检查
echo "=========================================="
echo "服务关闭完成 - 状态检查"
echo "=========================================="
echo ""

REMAINING=$(ps aux | grep -E "petrel-kernel|petrel-game|petrel-cms" | grep -v grep)
if [ -z "$REMAINING" ]; then
    log_info "✓ 所有 Petrel 服务已停止"
else
    log_warn "以下进程仍在运行："
    echo "$REMAINING"
fi

echo ""
log_info "关闭完成！"
echo "=========================================="
