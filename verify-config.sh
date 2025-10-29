#!/bin/bash

#############################################
# 完整配置验证脚本
# Comprehensive Configuration Verification
#############################################

echo "=============================================="
echo "   配置验证检查 (Configuration Verification)"
echo "=============================================="
echo ""

ERRORS=0
WARNINGS=0

# Function to check file exists
check_file() {
    local file=$1
    local desc=$2
    if [ -f "$file" ]; then
        echo "✓ $desc: $file"
        return 0
    else
        echo "✗ $desc: $file (文件不存在)"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

# Function to check directory exists
check_dir() {
    local dir=$1
    local desc=$2
    if [ -d "$dir" ]; then
        echo "✓ $desc: $dir"
        return 0
    else
        echo "✗ $desc: $dir (目录不存在)"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

# Function to check configuration value
check_config() {
    local file=$1
    local pattern=$2
    local desc=$3
    if grep -q "$pattern" "$file" 2>/dev/null; then
        echo "✓ $desc"
        return 0
    else
        echo "✗ $desc (配置缺失)"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

echo "1. 检查核心文件和目录"
echo "-----------------------------------"
check_file "start-all.sh" "主启动脚本"
check_file "stop-all.sh" "停止脚本"
check_file "validate-endpoint.sh" "验证脚本"
check_file "DEPLOYMENT.md" "部署文档"
check_file "TROUBLESHOOTING.md" "故障排查文档"
check_file "QUICKSTART.md" "快速启动文档"
echo ""

echo "2. 检查 Nacos 配置"
echo "-----------------------------------"
check_dir "nacos" "Nacos 目录"
check_dir "nacos/bin" "Nacos bin 目录"
check_file "nacos/bin/startup.sh" "Nacos 启动脚本"
check_file "nacos/bin/shutdown.sh" "Nacos 停止脚本"
check_file "nacos/conf/application.properties" "Nacos 配置文件"

if [ -f "nacos/conf/application.properties" ]; then
    check_config "nacos/conf/application.properties" "db.url.0=jdbc:mysql://202.189.7.196:3306" "Nacos 数据库地址"
    check_config "nacos/conf/application.properties" "db.user=root" "Nacos 数据库用户"
    check_config "nacos/conf/application.properties" "db.password=Fagp@1908!" "Nacos 数据库密码"
    check_config "nacos/conf/application.properties" "server.port=6878" "Nacos 端口配置"
fi
echo ""

echo "3. 检查 Petrel 配置"
echo "-----------------------------------"
check_dir "petrel" "Petrel 目录"
check_file "petrel/start.sh" "Petrel 启动脚本"
check_dir "petrel/config" "Petrel 配置目录"
check_file "petrel/config/application-prod.yml" "Petrel 生产环境配置"

if [ -f "petrel/config/application-prod.yml" ]; then
    check_config "petrel/config/application-prod.yml" "url: jdbc:mysql://202.189.7.196:3306/petrel_core" "Petrel 数据库地址"
    check_config "petrel/config/application-prod.yml" "username: root" "Petrel 数据库用户"
    check_config "petrel/config/application-prod.yml" "password: Fagp@1908!" "Petrel 数据库密码"
    check_config "petrel/config/application-prod.yml" "minimum-idle: 10" "HikariCP 最小连接数"
    check_config "petrel/config/application-prod.yml" "maximum-pool-size: 50" "HikariCP 最大连接数"
    check_config "petrel/config/application-prod.yml" "connection-timeout: 30000" "数据库连接超时"
    check_config "petrel/config/application-prod.yml" "keepalive-time: 300000" "连接保活时间"
    check_config "petrel/config/application-prod.yml" "keep-alive-timeout: 60000" "Tomcat Keep-Alive"
fi

if [ -f "petrel/start.sh" ]; then
    check_config "petrel/start.sh" "spring.config.location=classpath:/,file:./config/" "外部配置加载"
    check_config "petrel/start.sh" "spring.cloud.nacos.discovery.server-addr=127.0.0.1:6878" "Nacos 服务发现配置"
fi
echo ""

echo "4. 检查 Petrel JAR 文件"
echo "-----------------------------------"
check_file "petrel/petrel-kernel-register-1.0-SNAPSHOT-boot.jar" "Register 服务"
check_file "petrel/petrel-kernel-user-1.0-SNAPSHOT-boot.jar" "User 服务"
check_file "petrel/petrel-kernel-game-1.0-SNAPSHOT-boot.jar" "Game 服务"
check_file "petrel/petrel-game-lobby-1.0-SNAPSHOT-boot.jar" "Lobby 服务"
check_file "petrel/petrel-game-slots-1.0-SNAPSHOT-boot.jar" "Slots 服务"
check_file "petrel/petrel-cms-web-1.0-SNAPSHOT.war" "Web 服务"
echo ""

echo "5. 检查 Nacos 数据配置"
echo "-----------------------------------"
NACOS_DATA_CONFIG="nacos/data/tenant-config-data/0ec4577c-dbf8-49e0-8bef-adf2e80aa837/DEFAULT_GROUP/data-config.yaml"
if [ -f "$NACOS_DATA_CONFIG" ]; then
    check_config "$NACOS_DATA_CONFIG" "jdbc:mysql://202.189.7.196:3306/petrel_core" "Nacos 数据配置中的数据库地址"
    check_config "$NACOS_DATA_CONFIG" "username: root" "Nacos 数据配置中的用户名"
    check_config "$NACOS_DATA_CONFIG" "password: Fagp@1908!" "Nacos 数据配置中的密码"
    echo "✓ Nacos 数据配置文件存在并已更新"
else
    echo "⚠ Nacos 数据配置文件不存在 (首次启动时会创建)"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

echo "6. 检查脚本可执行权限"
echo "-----------------------------------"
if [ -x "start-all.sh" ]; then
    echo "✓ start-all.sh 可执行"
else
    echo "⚠ start-all.sh 不可执行 (运行: chmod +x start-all.sh)"
    WARNINGS=$((WARNINGS + 1))
fi

if [ -x "stop-all.sh" ]; then
    echo "✓ stop-all.sh 可执行"
else
    echo "⚠ stop-all.sh 不可执行 (运行: chmod +x stop-all.sh)"
    WARNINGS=$((WARNINGS + 1))
fi

if [ -x "validate-endpoint.sh" ]; then
    echo "✓ validate-endpoint.sh 可执行"
else
    echo "⚠ validate-endpoint.sh 不可执行 (运行: chmod +x validate-endpoint.sh)"
    WARNINGS=$((WARNINGS + 1))
fi

if [ -x "petrel/start.sh" ]; then
    echo "✓ petrel/start.sh 可执行"
else
    echo "⚠ petrel/start.sh 不可执行 (运行: chmod +x petrel/start.sh)"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

echo "7. 检查 Java 环境"
echo "-----------------------------------"
if command -v java &> /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | head -n 1)
    echo "✓ Java 已安装: $JAVA_VERSION"
else
    echo "✗ Java 未安装或不在 PATH 中"
    ERRORS=$((ERRORS + 1))
fi
echo ""

echo "8. 检查网络连接"
echo "-----------------------------------"
echo "测试数据库连接 (202.189.7.196:3306)..."
if timeout 5 bash -c "cat < /dev/null > /dev/tcp/202.189.7.196/3306" 2>/dev/null; then
    echo "✓ 数据库端口 3306 可访问"
else
    echo "⚠ 数据库端口 3306 无法连接 (可能是防火墙或网络问题)"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

echo "=============================================="
echo "   验证结果汇总"
echo "=============================================="
echo ""
echo "错误数: $ERRORS"
echo "警告数: $WARNINGS"
echo ""

if [ $ERRORS -eq 0 ]; then
    if [ $WARNINGS -eq 0 ]; then
        echo "✓✓✓ 所有配置验证通过！系统已正确配置。"
        echo ""
        echo "下一步操作："
        echo "1. 启动所有服务: bash start-all.sh"
        echo "2. 验证接口稳定性: bash validate-endpoint.sh"
        echo "3. 查看服务状态: cd petrel && bash start.sh status"
        exit 0
    else
        echo "⚠ 配置基本正确，但有 $WARNINGS 个警告需要注意。"
        echo "可以继续部署，但建议检查警告项。"
        exit 0
    fi
else
    echo "✗ 发现 $ERRORS 个错误，请修复后再部署。"
    exit 1
fi
