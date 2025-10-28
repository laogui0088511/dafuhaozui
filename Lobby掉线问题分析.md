# Lobby 服务掉线问题分析与解决方案

## 问题描述

用户报告两个相关问题：

1. **注册后仍然掉线**：Lobby 服务注册到 Register（7180）后，连接不稳定，会掉线
2. **后台访问导致掉线**：访问后台管理系统（petrel-cms-web）时，特别是查看"房间设置"，Lobby 服务会掉线

## 问题分析

### 1. Register-Lobby 连接机制

从生产日志分析，Register 和 Lobby 之间通过 **Zebra RPC** 建立长连接：

```
# Register 端
Register send msg to server RegisterUrlVO(serverId=lobby:127.0.0.1:9879...)
Register Connection channel active: 127.0.0.1:9879

# Lobby 端
Server serverOnline server process server online lobby:127.0.0.1:9879
Connection channel active: 127.0.0.1:53208
```

这是一个**持久化 TCP 连接**，需要：
- 心跳机制保持连接活跃
- 合理的超时配置
- 网络稳定性

### 2. 可能导致掉线的原因

#### 原因 1：心跳超时（最可能）

Zebra RPC 框架使用心跳机制保持连接。如果心跳失败或超时，连接会断开。

**触发场景**：
- Lobby 服务处理大量请求时，无法及时响应心跳
- 网络延迟导致心跳超时
- Lobby 服务 GC（垃圾回收）暂停时间过长

#### 原因 2：后台管理系统的大量请求

后台管理系统（petrel-cms-web）通过以下方式访问 Lobby：

1. **通过 Nacos 服务发现**调用 Lobby 的 HTTP 接口
2. **直接连接 Lobby 的 Zebra RPC 端口**（9879）

**问题场景**：
- 后台查询"房间设置"时，可能会：
  - 向 Lobby 发送大量请求
  - 查询所有房间状态
  - 长时间占用 Lobby 的工作线程
  - 导致 Lobby 无法及时响应 Register 的心跳

#### 原因 3：资源不足

**内存压力**：
```bash
# 当前 Lobby 启动参数
-Xmn512m -Xms1024m -Xmx1024m
```

如果：
- 在线玩家数量多
- 房间数量多
- 后台同时查询
- 可能导致内存不足，触发频繁 GC，影响心跳响应

**线程池耗尽**：
- Zebra 框架默认工作线程池大小：64
- 如果后台管理系统发送大量请求，可能耗尽线程池
- 导致心跳无法处理

#### 原因 4：网络问题

- 防火墙规则
- 网络拥塞
- TCP 连接被中断

## 解决方案

### 方案 1：优化心跳配置（推荐）

检查并调整 Zebra RPC 的心跳配置。

#### 1.1 增加心跳间隔和超时时间

在 Lobby 的配置中（如果支持）：

```yaml
zebra:
  heartbeat:
    interval: 10000    # 心跳间隔 10 秒
    timeout: 30000     # 心跳超时 30 秒
  connection:
    idleTimeout: 60000 # 连接空闲超时 60 秒
```

#### 1.2 确保心跳优先级

心跳处理应该有最高优先级，不应被业务请求阻塞。

### 方案 2：增加 Lobby 服务资源

#### 2.1 增加内存

修改启动脚本，增加 JVM 内存：

```bash
# 原配置
-Xmn512m -Xms1024m -Xmx1024m

# 建议配置（根据服务器实际内存调整）
-Xmn1024m -Xms2048m -Xmx2048m
```

#### 2.2 优化 GC 配置

添加 GC 日志和优化 GC 参数：

```bash
java -jar -Xmn1024m -Xms2048m -Xmx2048m \
  -XX:+UseG1GC \
  -XX:MaxGCPauseMillis=200 \
  -XX:+PrintGCDetails \
  -XX:+PrintGCDateStamps \
  -Xloggc:logs/gc.log \
  petrel-game-lobby-1.0-SNAPSHOT-boot.jar \
  --spring.profiles.active=prod \
  --zebra.ip.out=YOUR_IP
```

#### 2.3 增加 Zebra 线程池大小

如果配置支持：

```yaml
zebra:
  size: 128  # 从 64 增加到 128
```

### 方案 3：优化后台管理系统访问模式

#### 3.1 限制后台查询频率

在后台管理系统中：

```java
// 添加请求限流
@RateLimiter(value = 10, timeout = 1000) // 每秒最多 10 个请求
public List<Room> getRoomSettings() {
    // ...
}
```

#### 3.2 使用缓存

后台查询房间设置时使用缓存：

```java
@Cacheable(value = "roomSettings", key = "#root.methodName")
public List<Room> getRoomSettings() {
    // 从 Lobby 获取数据
}
```

缓存有效期设置为 30-60 秒，避免频繁查询。

#### 3.3 异步查询

后台查询改为异步方式，避免阻塞：

```java
@Async
public CompletableFuture<List<Room>> getRoomSettingsAsync() {
    // 异步查询
}
```

#### 3.4 分页查询

如果房间数量多，使用分页：

```java
public Page<Room> getRoomSettings(int page, int size) {
    // 分页查询，避免一次查询大量数据
}
```

### 方案 4：监控和告警

#### 4.1 添加连接状态监控

创建监控脚本 `monitor-lobby-connection.sh`：

```bash
#!/bin/bash

# 检查 Lobby 到 Register 的连接
check_lobby_connection() {
    # 检查 Lobby 日志中的最新心跳或连接活动
    if tail -100 /path/to/logs/petrel-game-lobby/info_9879.txt | \
       grep -q "Connection channel active\|heartbeat"; then
        return 0
    else
        return 1
    fi
}

# 检查 Register 端的 Lobby 连接
check_register_connection() {
    if tail -100 /path/to/logs/petrel-kernel-register/info_7180.log | \
       grep -q "lobby:127.0.0.1:9879.*active"; then
        return 0
    else
        return 1
    fi
}

if ! check_lobby_connection || ! check_register_connection; then
    echo "WARNING: Lobby connection may be lost"
    # 发送告警
    # 尝试重启 Lobby
fi
```

#### 4.2 记录后台访问日志

在后台管理系统中添加日志，记录对 Lobby 的访问：

```java
@Aspect
public class LobbyAccessLogger {
    @Around("execution(* com.petrel.web.controller.*.*Lobby*(..))")
    public Object logLobbyAccess(ProceedingJoinPoint pjp) throws Throwable {
        long start = System.currentTimeMillis();
        try {
            return pjp.proceed();
        } finally {
            long elapsed = System.currentTimeMillis() - start;
            log.info("Lobby access: {} took {}ms", 
                     pjp.getSignature(), elapsed);
            
            if (elapsed > 5000) {
                log.warn("Slow Lobby access detected: {}ms", elapsed);
            }
        }
    }
}
```

#### 4.3 JVM 监控

添加 JVM 监控参数：

```bash
-Dcom.sun.management.jmxremote \
-Dcom.sun.management.jmxremote.port=9010 \
-Dcom.sun.management.jmxremote.authenticate=false \
-Dcom.sun.management.jmxremote.ssl=false
```

使用 JConsole 或 VisualVM 监控：
- 堆内存使用
- GC 频率和时间
- 线程数量
- CPU 使用率

### 方案 5：网络优化

#### 5.1 检查防火墙规则

确保 Register 和 Lobby 之间的连接不会被防火墙中断：

```bash
# 允许 7180 和 9879 端口的长连接
iptables -A INPUT -p tcp --dport 7180 -j ACCEPT
iptables -A INPUT -p tcp --dport 9879 -j ACCEPT

# 设置 TCP keepalive
echo 60 > /proc/sys/net/ipv4/tcp_keepalive_time
echo 10 > /proc/sys/net/ipv4/tcp_keepalive_intvl
echo 6 > /proc/sys/net/ipv4/tcp_keepalive_probes
```

#### 5.2 调整 TCP 参数

```bash
# 增加 TCP 缓冲区
sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216
sysctl -w net.ipv4.tcp_rmem='4096 87380 16777216'
sysctl -w net.ipv4.tcp_wmem='4096 65536 16777216'
```

### 方案 6：实现自动重连机制

如果 Lobby 掉线，实现自动重新注册：

#### 6.1 在 Lobby 端添加重连逻辑

```java
@Scheduled(fixedDelay = 30000) // 每 30 秒检查一次
public void checkAndReconnect() {
    if (!isConnectedToRegister()) {
        log.warn("Lost connection to Register, attempting to reconnect...");
        try {
            registerToServer();
            log.info("Reconnected to Register successfully");
        } catch (Exception e) {
            log.error("Failed to reconnect to Register", e);
        }
    }
}
```

#### 6.2 在 Register 端添加重连逻辑

如果检测到 Lobby 掉线，主动尝试重新连接：

```java
@Scheduled(fixedDelay = 60000)
public void checkAndReconnectGameServers() {
    for (ServerInfo server : registeredServers) {
        if (!isConnected(server)) {
            log.warn("Lost connection to {}, attempting to reconnect...", 
                     server.getServerId());
            tryReconnect(server);
        }
    }
}
```

## 立即行动项

### 第一步：增加日志记录

在启动脚本中添加详细日志：

```bash
# 修改 start-correct.sh 中 Lobby 启动部分
nohup java -jar -Xmn1024m -Xms2048m -Xmx2048m \
    -XX:+PrintGCDetails \
    -XX:+PrintGCDateStamps \
    -Xloggc:logs/lobby-gc.log \
    "$LOBBY_JAR" \
    --spring.profiles.active=prod \
    --zebra.ip.out=${ZEBRA_IP_OUT} \
    --logging.level.com.zebra=DEBUG \
    > logs/lobby-stdout.log 2>&1 &
```

### 第二步：监控现有日志

持续监控 Lobby 和 Register 的日志：

```bash
# 终端 1：监控 Lobby
tail -f /path/to/logs/petrel-game-lobby/info_9879.txt | \
  grep -E "inactive|offline|heartbeat|error"

# 终端 2：监控 Register
tail -f /path/to/logs/petrel-kernel-register/info_7180.log | \
  grep -E "lobby.*inactive|lobby.*offline|serverOffline"

# 终端 3：监控后台访问
tail -f /path/to/logs/petrel-cms-web/info_721.log
```

### 第三步：重现问题

1. 启动所有服务
2. 等待 Lobby 成功注册
3. 访问后台管理系统的"房间设置"页面
4. 观察日志，记录：
   - 后台发送了多少请求到 Lobby
   - Lobby 的响应时间
   - 是否出现连接断开
   - GC 日志（如果有）

### 第四步：根据日志调整

根据实际观察到的问题，选择对应的解决方案。

## 快速修复建议

如果需要立即解决问题，建议：

1. **增加 Lobby 内存**（最快）：
   ```bash
   # 修改启动脚本
   -Xmn1024m -Xms2048m -Xmx2048m
   ```

2. **后台添加缓存**（避免频繁查询）：
   - 房间设置查询结果缓存 60 秒
   - 减少对 Lobby 的请求压力

3. **添加连接监控**：
   - 定时检查连接状态
   - 连接断开时自动重连

4. **限制后台并发**：
   - 同一时间只允许一个后台管理员查询房间设置
   - 使用队列机制排队处理

## 验证方案

修改后验证：

```bash
# 1. 启动服务
./start-correct.sh

# 2. 等待注册成功
tail -20 logs/petrel-kernel-register/info_7180.log | \
  grep "Register receive registry msg.*lobby"

# 3. 监控连接 30 分钟
watch -n 10 'tail -20 logs/petrel-kernel-register/info_7180.log | \
  grep "lobby.*9879" | tail -5'

# 4. 访问后台房间设置多次，观察是否掉线

# 5. 检查 GC 日志（如果启用）
tail -100 logs/lobby-gc.log
```

## 总结

Lobby 掉线问题可能是多个因素综合导致的：

1. **主要原因**：心跳超时或响应延迟
2. **触发因素**：后台管理系统的频繁查询
3. **加重因素**：资源不足（内存、线程）

**推荐的综合解决方案**：
1. 增加 Lobby 服务内存和线程池
2. 优化 GC 配置，减少暂停时间
3. 后台查询使用缓存和限流
4. 添加自动重连机制
5. 持续监控连接状态

这样可以大幅降低掉线频率，即使偶尔掉线也能自动恢复。
