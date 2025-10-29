# 7180/load/initial 接口断线问题修复说明

## 问题描述
- 启动完成后，`7180/load/initial` 接口输出会中断
- 后台登录后立即断开连接

## 根本原因
这通常是由以下几个原因造成的：

1. **数据库连接超时** - 默认连接池设置太小或超时时间太短
2. **HTTP Keep-Alive 超时** - Tomcat 默认配置不适合长连接
3. **连接池耗尽** - 并发请求导致连接池资源不足

## 已实施的修复

### 1. 数据库连接池优化
创建了 `petrel/config/application-prod.yml` 配置文件，包含：

**HikariCP 连接池设置：**
- `minimum-idle: 10` - 最小空闲连接数
- `maximum-pool-size: 50` - 最大连接池大小
- `connection-timeout: 30000` - 连接超时 30 秒
- `max-lifetime: 1800000` - 连接最大生命周期 30 分钟
- `idle-timeout: 600000` - 空闲超时 10 分钟
- `keepalive-time: 300000` - 保活时间 5 分钟

**数据库 URL 参数：**
- `autoReconnect=true` - 自动重连
- `failOverReadOnly=false` - 故障转移不只读
- `maxReconnects=10` - 最大重连次数
- `initialTimeout=30` - 初始超时
- `socketTimeout=60000` - Socket 超时 60 秒

### 2. Tomcat 服务器优化

**连接设置：**
- `connection-timeout: 60000` - 连接超时 60 秒
- `keep-alive-timeout: 60000` - Keep-Alive 超时 60 秒
- `max-keep-alive-requests: 200` - 最大 Keep-Alive 请求数

**线程池设置：**
- `threads.max: 500` - 最大线程数
- `threads.min-spare: 50` - 最小空闲线程数

**连接限制：**
- `max-connections: 10000` - 最大连接数
- `accept-count: 200` - 等待队列大小

### 3. Nacos 配置更新
更新了 `nacos/data/tenant-config-data/.../data-config.yaml`：
- 完整的数据库连接字符串
- 连接池配置
- Redis 超时设置

### 4. 启动脚本更新
所有服务现在使用：
```bash
--spring.config.location=classpath:/,file:./config/
```
这确保外部配置文件被正确加载。

## 验证步骤

### 1. 重启所有服务
```bash
bash stop-all.sh
bash start-all.sh
```

### 2. 检查配置是否生效
查看日志中是否有 HikariCP 初始化信息：
```bash
tail -f petrel/logs/*/$(ls -t petrel/logs/*/ | head -1)
```

应该看到类似：
```
HikariPool-1 - Starting...
HikariPool-1 - Start completed.
```

### 3. 测试接口稳定性
```bash
bash validate-endpoint.sh
```

这将测试 `7180/load/initial` 接口 30 次，每次间隔 5 秒。

### 4. 手动测试
```bash
# 持续测试 10 次
for i in {1..10}; do
  echo "Test $i:"
  curl -v http://localhost:7180/load/initial
  echo ""
  sleep 5
done
```

## 如果问题仍然存在

### 检查日志
1. **查看具体错误：**
```bash
cd petrel/logs
# 找到最新的日志文件
find . -name "*.log" -type f -mmin -10 | xargs grep -i "error\|exception\|timeout"
```

2. **查看数据库连接：**
```bash
# 在日志中查找连接池信息
find . -name "*.log" -type f -mmin -10 | xargs grep -i "hikari\|connection\|pool"
```

### 检查数据库连接
在服务器上测试数据库连接：
```bash
mysql -h 202.189.7.196 -u root -p'Fagp@1908!' -e "SELECT 1"
```

### 检查网络延迟
```bash
ping -c 10 202.189.7.196
```

如果延迟很高（>100ms），可能需要增加超时设置。

### 调整配置（如果需要）

如果数据库在慢速网络上，编辑 `petrel/config/application-prod.yml`：

```yaml
spring:
  datasource:
    hikari:
      connection-timeout: 60000  # 增加到 60 秒
      max-lifetime: 3600000      # 增加到 1 小时
```

然后重启服务。

## 其他可能的问题

### 1. 防火墙
确保以下端口开放：
- 6878 (Nacos)
- 7180 (Web/Backend)
- 3306 (MySQL - 如果需要远程访问)

### 2. Redis 连接
如果使用 Redis，确保 Redis 正在运行：
```bash
redis-cli ping
```

应该返回 `PONG`

### 3. 内存不足
检查 Java 进程内存使用：
```bash
ps aux | grep java
```

如果内存接近上限，增加 JVM 堆大小（在 start.sh 中）。

## 监控建议

### 持续监控接口
创建一个监控脚本：
```bash
#!/bin/bash
while true; do
  response=$(curl -s -w "\n%{http_code}" --max-time 10 http://localhost:7180/load/initial)
  code=$(echo "$response" | tail -n1)
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  
  if [ "$code" = "200" ]; then
    echo "$timestamp - OK"
  else
    echo "$timestamp - FAILED (HTTP $code)"
  fi
  
  sleep 30
done
```

保存为 `monitor.sh` 并运行：
```bash
bash monitor.sh > monitor.log 2>&1 &
```

## 联系支持

如果以上所有步骤都无法解决问题，请收集以下信息：
1. 最近 5 分钟的所有日志文件
2. `bash start.sh status` 的输出
3. `netstat -tlnp | grep 7180` 的输出
4. 数据库连接测试结果
5. `monitor.sh` 的日志（如果运行了）
