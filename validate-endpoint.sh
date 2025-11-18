#!/bin/bash

#############################################
# 端点验证脚本
# 测试 7180/load/initial 端点
#############################################

ENDPOINT="http://localhost:7180/load/initial"
MAX_ATTEMPTS=30
WAIT_TIME=5

echo "============================================"
echo "   端点验证测试"
echo "============================================"
echo ""
echo "测试端点: $ENDPOINT"
echo "测试次数: $MAX_ATTEMPTS 次，间隔 ${WAIT_TIME}秒"
echo ""

# 检查服务是否运行
echo "检查服务是否运行..."
cd "$(dirname "$0")/petrel"
bash start.sh status
echo ""

# 等待服务准备就绪
echo "等待服务初始化（15秒）..."
sleep 15

# 多次测试端点
echo "运行连接测试..."
echo ""

success_count=0
fail_count=0
response_times=()

for i in $(seq 1 $MAX_ATTEMPTS); do
    timestamp=$(date '+%H:%M:%S')
    echo -n "[$timestamp] 测试 $i/$MAX_ATTEMPTS: "
    
    # 发起请求并测量响应时间
    start_time=$(date +%s%N)
    response=$(curl -s -w "\n%{http_code}\n%{time_total}" --max-time 10 "$ENDPOINT" 2>&1)
    end_time=$(date +%s%N)
    
    http_code=$(echo "$response" | tail -n2 | head -n1)
    response_time=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ]; then
        echo "✓ 成功 (HTTP $http_code, ${response_time}秒)"
        success_count=$((success_count + 1))
        response_times+=("$response_time")
        
        # 首次成功时显示响应数据
        if [ $success_count -eq 1 ]; then
            echo ""
            echo "响应数据示例:"
            echo "$response" | head -n -2 | head -20
            echo "..."
            echo ""
        fi
    else
        echo "✗ 失败 (HTTP $http_code 或超时)"
        fail_count=$((fail_count + 1))
        
        # 记录失败详情
        if [ $fail_count -le 3 ]; then
            echo "   错误详情: $response" | head -3
        fi
    fi
    
    # 请求间等待
    if [ $i -lt $MAX_ATTEMPTS ]; then
        sleep $WAIT_TIME
    fi
done

# 计算统计数据
if [ ${#response_times[@]} -gt 0 ]; then
    total_time=0
    for time in "${response_times[@]}"; do
        total_time=$(echo "$total_time + $time" | bc)
    done
    avg_time=$(echo "scale=3; $total_time / ${#response_times[@]}" | bc)
else
    avg_time="不适用"
fi

echo ""
echo "============================================"
echo "   测试结果"
echo "============================================"
echo "总测试数:           $MAX_ATTEMPTS"
echo "成功次数:           $success_count"
echo "失败次数:           $fail_count"
echo "成功率:             $(( success_count * 100 / MAX_ATTEMPTS ))%"
echo "平均响应时间:       ${avg_time}秒"
echo ""

if [ $success_count -gt 0 ]; then
    echo "✓ 端点正在响应数据"
    
    if [ $fail_count -eq 0 ]; then
        echo "✓ 未检测到断连 - 稳定!"
        echo ""
        echo "状态: ✅ 通过"
        exit 0
    elif [ $fail_count -le 3 ]; then
        echo "⚠ 检测到少量问题 ($fail_count/$MAX_ATTEMPTS 次失败)"
        echo ""
        echo "状态: ⚠️ 基本稳定"
        exit 0
    else
        echo "⚠ 检测到频繁断连 ($fail_count/$MAX_ATTEMPTS)"
        echo ""
        echo "状态: ⚠️ 不稳定"
        echo ""
        echo "建议:"
        echo "1. 检查数据库连接: mysql -h 202.189.7.196 -u root -p"
        echo "2. 检查网络延迟: ping -c 10 202.189.7.196"
        echo "3. 查看日志: find petrel/logs -name '*.log' -mmin -10 -exec tail {} \;"
        echo "4. 重启服务: bash stop-all.sh && bash start-all.sh"
        exit 1
    fi
else
    echo "✗ 端点无响应"
    echo ""
    echo "状态: ❌ 失败"
    echo ""
    echo "故障排查步骤:"
    echo "1. 检查所有服务是否运行: cd petrel && bash start.sh status"
    echo "2. 检查服务日志: ls -la petrel/logs/"
    echo "3. 验证Nacos是否运行: curl http://localhost:6878/nacos/v1/console/health"
    echo "4. 检查端口7180是否监听: netstat -tlnp | grep 7180"
    echo "5. 查看故障排查指南: cat TROUBLESHOOTING.md"
    exit 2
fi
