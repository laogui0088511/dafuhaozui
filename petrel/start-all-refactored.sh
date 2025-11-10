#!/bin/bash

# =================================================================================================
# 通用服务启动脚本 (宝塔环境定制版)
#
# 功能:
# 1. 定义并启动一系列微服务.
# 2. 使用指定的JDK和JVM参数.
# 3. 对每个服务进行端口监听检查，确保其成功启动.
# 4. 提供详细的日志输出.
#
# 使用:
# - 将整个 'petrel' 和 'nacos' 文件夹上传到宝塔的 /www/wwwroot/ 目录下.
# - 运行: ./start-all-refactored.sh
#
# 服务定义格式:
# "服务名 JAR文件名 端口号"
#   - 服务名: 用于日志输出和标识.
#   - JAR文件名: 服务的可执行JAR包.
#   - 端口号: 服务监听的端口.
# =================================================================================================

# --- 环境配置 ---
# 请根据您的宝塔实际环境修改以下路径
JAVA_EXEC="/www/server/java/jdk1.8.0_371/bin/java"
BASE_DIR="/www/wwwroot/petrel"
NACOS_DIR="/www/wwwroot/nacos" # 假设nacos放于此目录
LOG_DIR="$BASE_DIR/logs"
CONFIG_BASE_DIR="$BASE_DIR/config"

# JVM 启动参数
JVM_OPTS="-Xmx1024M -Xms256M"

# 确保日志和配置目录存在
mkdir -p "$LOG_DIR"
mkdir -p "$CONFIG_BASE_DIR"

# --- 服务定义 ---
# 格式: "服务名 JAR文件名 端口号"
# 注意: Nacos是特殊服务, 会被优先单独启动.
# game-lobby 和 game-slots 当前启动有问题, 暂时注释掉.
services=(
    "kernel-register petrel-kernel-register-1.0-SNAPSHOT-boot.jar 7180"
    "kernel-user petrel-kernel-user-1.0-SNAPSHOT-boot.jar 8719"
    "kernel-game petrel-kernel-game-1.0-SNAPSHOT-boot.jar 8752"
    "game-chess petrel-game-chess-1.0-SNAPSHOT-boot.jar 9637"
    # "game-lobby petrel-game-lobby-1.0-SNAPSHOT-boot.jar 9879"
    # "game-slots petrel-game-slots-1.0-SNAPSHOT-boot.jar 9527"
)

# =================================================================================================
# 函数定义
# =================================================================================================

# 函数: 检查端口是否在监听
# 参数1: 端口号
# 参数2: 服务名
# 参数3: 超时秒数 (可选, 默认60)
check_port_listening() {
    local port="$1"
    local service_name="$2"
    local timeout="${3:-60}"
    echo "Checking if $service_name is listening on port $port..."
    for ((i=0; i<timeout; i++)); do
        if netstat -tuln | grep ":$port" > /dev/null; then
            echo -e "\n$service_name is now listening on port $port."
            return 0
        fi
        echo -n "."
        sleep 1
    done
    echo -e "\nError: Timeout after $timeout seconds. $service_name did not start listening on port $port."
    return 1
}

# 函数: 启动单个Spring Boot服务
# 参数1: 服务名
# 参数2: JAR文件名
# 参数3: 端口号
start_service() {
    local service_name="$1"
    local jar_file_name="$2"
    local port="$3"

    echo "--------------------------------------------------"
    echo "Starting $service_name..."

    local jar_path="$BASE_DIR/$jar_file_name"
    local config_file="$CONFIG_BASE_DIR/$service_name/application-prod.yml"
    local log_file="$LOG_DIR/${service_name}-startup.log"

    if [ ! -f "$jar_path" ]; then
        echo "Error: JAR file $jar_path not found for service $service_name."
        return 1
    fi

    if [ ! -f "$config_file" ]; then
        echo "Error: Config file $config_file not found for service $service_name."
        return 1
    fi

    # 启动服务
    nohup "$JAVA_EXEC" $JVM_OPTS -jar "$jar_path" --spring.config.location="$config_file" > "$log_file" 2>&1 &
    local pid=$!
    echo "$service_name started with PID: $pid. Log file: $log_file"

    # 检查端口
    check_port_listening "$port" "$service_name"
    if [ $? -ne 0 ]; then
        echo "Error: $service_name failed to start. Check log for details: $log_file"
        # exit 1 # 如果希望任何服务失败时立即退出, 取消此行注释
    fi
    echo "--------------------------------------------------"
}

# =================================================================================================
# 主脚本执行
# =================================================================================================

# 步骤 1: 启动 Nacos (特殊服务)
echo "=================================================="
echo "Step 1: Starting Nacos..."
echo "=================================================="
if [ -d "$NACOS_DIR/bin" ]; then
    cd "$NACOS_DIR/bin" || { echo "Error: Nacos directory $NACOS_DIR/bin not found."; exit 1; }
    nohup sh startup.sh -m standalone > "$LOG_DIR/nacos-startup.log" 2>&1 &
else
    echo "Error: Nacos directory $NACOS_DIR not found. Please check the NACOS_DIR variable."
    exit 1
fi


# 切回主工作目录
cd "$BASE_DIR" || { echo "Error: Base directory $BASE_DIR not found."; exit 1; }

check_port_listening 6878 "Nacos"
if [ $? -ne 0 ]; then
    echo "Fatal: Nacos failed to start. Aborting."
    exit 1
fi
echo "Waiting 10 seconds for Nacos to initialize completely..."
sleep 10

# 步骤 2: 循环启动所有在 'services' 数组中定义的服务
echo "=================================================="
echo "Step 2: Starting application services..."
echo "=================================================="
for service_info in "${services[@]}"; do
    # 解析服务信息
    read -r service_name jar_file port <<< "$service_info"
    start_service "$service_name" "$jar_file" "$port"
done

echo "=================================================="
echo "All services have been launched."
echo "Please check the individual log files in $LOG_DIR for details."
echo "=================================================="
