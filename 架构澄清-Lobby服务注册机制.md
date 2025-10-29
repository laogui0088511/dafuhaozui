# 正确的架构理解 - Lobby 服务注册机制

## 问题澄清

经过查看 2022 年的实际运行日志，现在明确了 Lobby 服务的真实架构：

## Lobby 服务的双重角色

### 1. 作为服务消费者（使用 Nacos）

Lobby 服务**需要 Nacos**来：
- **获取配置**：从 Nacos 配置中心读取 `petrel-lobby-user-config.yaml`、`petrel-lobby-gold-config.yaml` 等配置
- **服务发现**：通过 Ribbon + Nacos 发现并调用其他服务
  - `petrel-kernel-register` (7180) - Register 服务
  - `petrel-kernel-user` (8719) - User 服务
  - `petrel-kernel-game` - Game 服务

从日志可见：
```
DynamicServerListLoadBalancer for client petrel-kernel-register initialized: 
DynamicServerListLoadBalancer:{NFLoadBalancer:name=petrel-kernel-register,
current list of Servers=[172.19.48.88:7180],...
ServerList:com.alibaba.cloud.nacos.ribbon.NacosServerList@5f7f2382
```

### 2. 作为游戏服务提供者（使用 Zebra RPC）

Lobby 服务**不在 Nacos 中注册**，而是使用自定义的 **Zebra RPC 框架**：

#### Lobby 的注册流程：

1. **启动 Zebra RPC Server**（端口 9879）
   ```
   Server started on port 9879
   ```

2. **主动注册到 Register 服务**（HTTP 请求到 7180）
   ```
   StartAfter send register msg ServerRegistryRequest(
     serverId=lobby:127.0.0.1:9879, 
     appName=petrel-game-lobby, 
     inIp=127.0.0.1, 
     port=9879, 
     vfx=LOBBY, 
     gameType=0, 
     outIp=116.62.162.42, 
     weight=50
   )
   ```

3. **Register 服务反向连接 Lobby**（通过 Zebra 协议）
   ```
   Register send msg to server RegisterUrlVO(
     serverId=lobby:127.0.0.1:9879, 
     path=127.0.0.1, 
     port=9879, 
     lobby=1
   )
   
   Connection channel active: 127.0.0.1:53208
   Server serverOnline server process server online lobby:127.0.0.1:9879
   ```

## 架构图

```
┌─────────────────────────────────────────────────────────────┐
│                     基础服务层                               │
│  ┌──────────┐  ┌──────────┐  ┌─────────────────────────┐  │
│  │  MySQL   │  │  Redis   │  │  Nacos (配置+服务发现)  │  │
│  │  :3306   │  │  :6379   │  │      :6878              │  │
│  └──────────┘  └──────────┘  └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│                  核心服务层（在 Nacos 中注册）               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ petrel-kernel-register (7180)                        │  │
│  │ - 在 Nacos 中注册                                     │  │
│  │ - Zebra RPC 游戏服务注册中心                         │  │
│  │ - 管理 Lobby/Slots/Chess 等游戏服务                  │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ petrel-kernel-user (8719)                            │  │
│  │ - 在 Nacos 中注册                                     │  │
│  │ - 用户服务                                            │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ petrel-kernel-game                                   │  │
│  │ - 在 Nacos 中注册                                     │  │
│  │ - 游戏核心服务                                        │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
          ↓ (通过 Nacos 服务发现)       ↑ (通过 Zebra RPC 注册)
┌─────────────────────────────────────────────────────────────┐
│              游戏服务层（通过 Zebra 注册到 Register）         │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ petrel-game-lobby (9879)                             │  │
│  │ - 使用 Nacos：配置中心 + 服务发现（调用其他服务）    │  │
│  │ - 不在 Nacos 注册：通过 Zebra 注册到 Register        │  │
│  │ - 客户端通过 Zebra 协议连接                          │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ petrel-game-slots (9527)                             │  │
│  │ - 同 Lobby 架构                                       │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ petrel-game-chess (9637)                             │  │
│  │ - 同 Lobby 架构                                       │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## 为什么是这样的架构？

### 1. 两种不同的注册机制

**Nacos 服务注册**（用于内部微服务通信）：
- Register、User、Game 等核心服务在 Nacos 中注册
- 这些服务之间通过 HTTP/Feign 调用
- 使用 Spring Cloud 的服务发现机制

**Zebra RPC 注册**（用于游戏客户端连接）：
- Lobby、Slots、Chess 等游戏服务通过 Zebra 注册到 Register
- 使用自定义的 TCP 长连接协议（Netty）
- 专为游戏场景优化（低延迟、高并发）

### 2. Lobby 的特殊定位

Lobby 既是**服务消费者**又是**游戏服务提供者**：

作为消费者：
- 需要调用 User 服务进行用户认证
- 需要调用 Register 服务进行服务注册
- 需要调用 Game 服务获取游戏信息

作为提供者：
- 需要接受游戏客户端的 TCP 连接
- 需要处理游戏逻辑请求
- 需要被 Register 统一管理和路由

## 正确的部署流程

### 1. 启动基础服务
```bash
# 启动 MySQL (3306)
# 启动 Redis (6379)
# 启动 Nacos (6878)
cd /path/to/nacos/bin
./startup.sh -m standalone
sleep 60
```

### 2. 启动核心服务（会在 Nacos 中注册）
```bash
cd /path/to/petrel

# Register 服务（7180） - Zebra 注册中心
./start.sh start register
sleep 30

# User 服务（8719）
./start.sh start user
sleep 15

# Game 服务
./start.sh start game
sleep 15
```

### 3. 启动游戏服务（会通过 Zebra 注册到 Register）
```bash
# Lobby 服务（9879）
./start.sh start lobby
sleep 15

# Slots 服务（9527）
./start.sh start slots
sleep 15

# Chess 服务（9637）
# 等等...
```

## 验证部署

### 1. 验证 Nacos 注册
```bash
# Register 应该在 Nacos 中
curl 'http://127.0.0.1:6878/nacos/v1/ns/instance/list?serviceName=petrel-kernel-register'

# User 应该在 Nacos 中
curl 'http://127.0.0.1:6878/nacos/v1/ns/instance/list?serviceName=petrel-kernel-user'

# Lobby 不应该在 Nacos 中（这是正常的）
curl 'http://127.0.0.1:6878/nacos/v1/ns/instance/list?serviceName=petrel-game-lobby'
# 应该返回空或不存在
```

### 2. 验证 Lobby 服务
```bash
# Lobby 端口监听
netstat -tlnp | grep 9879

# Lobby 健康检查
curl http://127.0.0.1:9879/actuator/health

# 查看 Lobby 日志确认注册成功
tail -f /path/to/petrel/logs/petrel-game-lobby/info_9879.txt
# 应该看到：
# "StartAfter send register msg ServerRegistryRequest..."
# "Server serverOnline server process server online lobby:..."
```

### 3. 验证 Register 连接
```bash
# 查看 Register 日志
tail -f /path/to/petrel/logs/petrel-kernel-register/info_7180.log
# 应该看到：
# "Register receive registry msg ServerRegistryRequest(serverId=lobby:..."
# "Connection channel active: 127.0.0.1:9879"
```

## 常见误解

### ❌ 错误理解 1
"Lobby 不需要 Nacos"

**正确**：Lobby 需要 Nacos 作为配置中心和服务发现客户端

### ❌ 错误理解 2
"Lobby 应该在 Nacos 中注册"

**正确**：Lobby 通过 Zebra RPC 注册到 Register，不在 Nacos 中注册

### ❌ 错误理解 3
"应该禁用 Lobby 的 Nacos 服务发现"

**正确**：不应该禁用，Lobby 需要通过 Nacos 发现其他服务

### ✅ 正确理解
Lobby 服务：
- ✅ 需要连接 Nacos（配置 + 服务发现）
- ✅ 不在 Nacos 中注册自己
- ✅ 通过 Zebra RPC 注册到 Register (7180)
- ✅ 可以正常调用 Nacos 中的其他服务

## 总结

之前的分析和修改是**错误的**。正确的架构是：

1. **Nacos 是必需的**，用于配置管理和服务发现
2. **Lobby 不在 Nacos 中注册**，这是正常的设计
3. **Lobby 通过 Zebra RPC 框架注册到 Register 服务**
4. **这是一个双注册中心的混合架构**：
   - Nacos：用于微服务间的 HTTP 调用
   - Zebra Register：用于游戏客户端的 TCP 连接

## 参考日志

Register 服务日志（2022-12-18）：
```
12-18 15:42:28.482 INFO Register receive registry msg ServerRegistryRequest(serverId=lobby:127.0.0.1:9879...)
12-18 15:42:28.498 INFO Connection channel active: 127.0.0.1:9879
```

Lobby 服务日志（2022-12-18）：
```
12-18 15:42:27.618 INFO StartAfter send register msg ServerRegistryRequest(serverId=lobby:127.0.0.1:9879...)
12-18 15:42:28.136 INFO DynamicServerListLoadBalancer for client petrel-kernel-register initialized...
12-18 15:42:28.529 INFO Server serverOnline server process server online lobby:127.0.0.1:9879
```

这些日志清楚地展示了 Lobby 的双重角色。
