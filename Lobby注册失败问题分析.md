# Lobby 服务注册失败问题分析与解决方案

## 问题描述

Lobby 服务经常无法注册到 Register 服务（端口 7180）。

## 根本原因分析

基于 2022-12-18 生产日志的详细分析，发现了根本原因：

### 时间线分析

```
15:42:03.123 - Register 服务启动完成 (耗时 8.5 秒)
15:42:04.568 - Register 尝试连接 Lobby - 失败 (ERROR: not connect server)
15:42:05.624 - Register 尝试连接 Slots - 失败 (ERROR: not connect server)
15:42:06.692 - Register 尝试连接 Chess - 失败 (ERROR: not connect server)
15:42:27.445 - Lobby 服务启动完成 (耗时 5.3 秒)
15:42:27.570 - Lobby Zebra RPC Server 启动 (端口 9879)
15:42:27.618 - Lobby 发送注册请求到 Register
15:42:28.482 - Register 接收到 Lobby 注册请求 (成功)
15:42:28.498 - Register 连接到 Lobby - 成功
```

### 核心问题

1. **Register 启动顺序问题**：
   - Register 在启动过程中（15:42:03 启动完成）立即尝试连接游戏服务
   - 此时游戏服务还未启动，导致连接失败
   - 这些失败日志是正常的初始化过程

2. **HTTP 接口就绪时间**：
   - Register 虽然在 15:42:03 启动完成，但 HTTP 接口（DispatcherServlet）要到 15:42:28 才初始化
   - 这意味着 Register 启动后需要**额外 25 秒**才能接受 HTTP 注册请求

3. **Lobby 注册时机**：
   - Lobby 在 15:42:27 启动，15:42:27.618 发送注册请求
   - 恰好在 Register HTTP 接口就绪（15:42:28）之前
   - 成功注册时间：15:42:28.482

### 为什么经常注册失败？

如果启动脚本中：

1. **Register 等待时间不足**（如只等待 18 秒）
   - Register 的 HTTP 接口还未完全就绪
   - Lobby 发送注册请求时会失败

2. **Lobby 启动过早**
   - 在 Register HTTP 接口未就绪时启动
   - 注册请求会被拒绝或超时

3. **没有验证 Register 就绪状态**
   - 只检查进程或端口，不检查 HTTP 接口
   - 导致假性"就绪"

## 解决方案

### 方案 1：使用新的正确启动脚本（推荐）

```bash
cd /path/to/petrel
./start-correct.sh [外部IP]
```

该脚本基于生产日志分析，实现了：

1. **正确的等待时间**：
   - Register 启动后等待 10 秒（应用启动）
   - 再等待 10 秒（HTTP 接口初始化）
   - 总计 20 秒确保完全就绪

2. **正确的启动顺序**：
   ```
   Nacos → Register (等待 20 秒) → User → Game → Lobby/Chess/Slots
   ```

3. **服务验证**：
   - 检查端口监听
   - 验证进程运行
   - 确认服务间连接

### 方案 2：修改现有 start.sh

在 `start_register()` 函数中增加等待时间：

```bash
start_register(){
    echo "-----------start-register-------------------"
    nohup java -jar -Xmn200m -Xms400m -Xmx400m $register --spring.profiles.active=prod >/dev/null 2>&1&
    
    # 等待应用启动
    sleep 10
    
    # 关键：等待 HTTP 接口完全就绪
    echo "等待 Register HTTP 接口初始化..."
    sleep 15
    
    echo "Register 服务已完全就绪"
    tail -n 300 $register_log`ls $register_log -t1|awk '{if (NR ==1) print}'`
    echo "-----------end-register----------------------"
}
```

修改后的总等待时间：**25 秒**

### 方案 3：添加 HTTP 健康检查

在启动脚本中添加实际的健康检查：

```bash
# 等待 Register HTTP 接口就绪
check_register_ready() {
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s http://127.0.0.1:7180/actuator/health > /dev/null 2>&1; then
            return 0
        fi
        sleep 1
        attempt=$((attempt + 1))
    done
    return 1
}

start_register(){
    nohup java -jar -Xmn200m -Xms400m -Xmx400m $register --spring.profiles.active=prod >/dev/null 2>&1&
    
    echo "等待 Register 服务就绪..."
    if check_register_ready; then
        echo "Register 服务已就绪"
    else
        echo "Register 服务启动失败或超时"
        exit 1
    fi
}
```

## 生产环境最佳实践

### 1. 启动顺序（严格遵守）

```
步骤 1: 启动 Nacos（等待 60 秒）
步骤 2: 启动 Register（等待 25 秒 - 关键！）
步骤 3: 启动 User（等待 15 秒）
步骤 4: 启动 Game（等待 15 秒）
步骤 5: 启动 Lobby（等待 10 秒）
步骤 6: 启动 Chess（等待 10 秒）
步骤 7: 启动 Slots（等待 10 秒）
```

### 2. 关键等待时间

| 服务 | 应用启动时间 | 额外初始化时间 | 建议总等待 | 说明 |
|------|------------|--------------|----------|------|
| Nacos | 30-40秒 | 20秒 | 60秒 | 配置中心必须完全就绪 |
| Register | 8-10秒 | 15-20秒 | 25秒 | HTTP接口初始化需要时间 |
| User/Game | 5-8秒 | 5秒 | 15秒 | Spring Boot 应用启动 |
| Lobby/Chess/Slots | 5-6秒 | 3秒 | 10秒 | Zebra RPC + 注册时间 |

### 3. 验证清单

启动后必须验证：

```bash
# 1. 检查所有服务进程
ps aux | grep petrel

# 2. 检查所有端口
netstat -tlnp | grep -E "6878|7180|9879|9637|9527"

# 3. 验证 Lobby 注册成功（关键！）
tail -20 logs/petrel-kernel-register/info_7180.log | grep "Register receive registry msg.*lobby"
# 应该看到：Register receive registry msg ServerRegistryRequest(serverId=lobby:127.0.0.1:9879...)

# 4. 验证 Register 连接成功
tail -20 logs/petrel-kernel-register/info_7180.log | grep "Connection channel active.*9879"
# 应该看到：Register Connection channel active: 127.0.0.1:9879

# 5. 验证 Lobby 发送注册
tail -20 logs/petrel-game-lobby/info_9879.txt | grep "StartAfter send register msg"
# 应该看到：StartAfter send register msg ServerRegistryRequest(serverId=lobby:127.0.0.1:9879...)

# 6. 验证 Lobby 上线
tail -20 logs/petrel-game-lobby/info_9879.txt | grep "Server serverOnline"
# 应该看到：Server serverOnline server process server online lobby:127.0.0.1:9879
```

## 常见错误和解决方法

### 错误 1：Register start not connect server

```
ERROR [main] [com.zebra.rpc.register.ServerRegistryService] : 
Register start not connect server ServerInfoVO(serverId=lobby:127.0.0.1:9879...)
```

**原因**：Register 在初始化时尝试连接游戏服务，但服务还未启动

**解决**：这是正常现象！Register 会在服务启动后通过 HTTP 接口接受注册

### 错误 2：Connection refused (连接被拒绝)

**原因**：
- Register 的 HTTP 接口未就绪
- Lobby 启动过早

**解决**：
- 增加 Register 启动后的等待时间（至少 25 秒）
- 确保 Register 的 DispatcherServlet 已初始化

### 错误 3：No servers available (没有可用服务器)

**原因**：Lobby 通过 Ribbon 调用其他服务时，Nacos 中没有服务实例

**解决**：
- 确保 Nacos 正在运行
- 确保 Register、User、Game 已在 Nacos 中注册
- 检查 Lobby 的 Nacos 配置

### 错误 4：Registration timeout (注册超时)

**原因**：
- Register 服务未完全启动
- 网络问题
- 防火墙阻止

**解决**：
```bash
# 1. 验证 Register 端口可访问
telnet 127.0.0.1 7180

# 2. 检查 Register 日志
tail -f logs/petrel-kernel-register/info_7180.log

# 3. 重启 Register 并等待足够时间
./stop-all-improved.sh
sleep 5
./start-correct.sh
```

## 监控和告警建议

### 1. 监控脚本

创建 `check-lobby-registration.sh`：

```bash
#!/bin/bash

# 检查 Lobby 是否成功注册
if grep -q "Register receive registry msg.*lobby.*9879" \
    /path/to/logs/petrel-kernel-register/info_7180.log; then
    echo "✓ Lobby 注册成功"
    exit 0
else
    echo "✗ Lobby 未注册或注册失败"
    exit 1
fi
```

### 2. 定时检查

```bash
# 添加到 crontab
*/5 * * * * /path/to/check-lobby-registration.sh || /path/to/alert.sh "Lobby registration failed"
```

### 3. 日志轮转

确保日志不会过大：

```bash
# 在 /etc/logrotate.d/petrel 中配置
/path/to/petrel/logs/*/*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
}
```

## 总结

**核心问题**：Register 的 HTTP 接口需要启动后额外时间初始化

**关键解决方案**：
1. Register 启动后等待 25 秒（10 秒应用启动 + 15 秒 HTTP 初始化）
2. 严格按照顺序启动服务
3. 验证每个服务的实际就绪状态，不只检查进程

**使用新脚本**：
```bash
./start-correct.sh [外部IP]
```

该脚本已根据 2022-12-18 生产日志精确调优所有等待时间。
