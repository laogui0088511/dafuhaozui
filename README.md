# dafuhaozui

Petrel 游戏系统 / Petrel Gaming Platform

## 重要架构说明 / Architecture Notice

**Lobby 服务使用双重注册机制：**
1. ✅ 使用 Nacos 作为**配置中心**和**服务发现客户端**（调用其他服务）
2. ✅ 通过 **Zebra RPC** 注册到 **Register 服务** (7180)，不在 Nacos 中注册
3. ✅ 游戏客户端通过 Zebra 协议连接 Lobby

详细说明请查看：[架构澄清-Lobby服务注册机制.md](./架构澄清-Lobby服务注册机制.md)

## 快速开始 / Quick Start

### 中文文档
- **[架构澄清-Lobby服务注册机制.md](./架构澄清-Lobby服务注册机制.md)** - 正确的架构理解（必读）
- **[部署指南](./部署指南.md)** - 完整的部署流程和配置说明
- **[分析报告-lobby模块注册问题.md](./分析报告-lobby模块注册问题.md)** - 原始问题分析

## 部署 / Deployment

### 前置要求 / Prerequisites
- Java 8+
- MySQL 5.7+
- Redis 5.0+
- **Nacos** - Lobby 需要 Nacos 作为配置中心和服务发现

### 快速启动 / Quick Start

#### 方式 1: 使用改进的启动脚本（推荐）
```bash
cd petrel
./start-all-improved.sh

# 这将按正确顺序启动所有服务
```

#### 方式 2: 手动启动
```bash
# 1. 启动 Nacos
cd nacos/bin
./startup.sh -m standalone
sleep 60

# 2. 启动 Register 服务（Zebra 注册中心）
cd petrel
./start.sh start register
sleep 30

# 3. 启动其他核心服务
./start.sh start user
./start.sh start game
sleep 15

# 4. 启动 Lobby（会通过 Zebra 注册到 Register）
./start.sh start lobby
sleep 15
```

#### 关闭所有服务
```bash
cd petrel
./stop-all-improved.sh
```

### 服务架构 / Service Architecture
```
MySQL + Redis + Nacos (配置 + 服务发现)
    ↓
核心服务层（在 Nacos 中注册）
├── Register Service (7180) - Zebra RPC 注册中心
├── User Service (8719)
└── Game Service
    ↓ (Nacos 服务发现)    ↑ (Zebra RPC 注册)
游戏服务层（通过 Zebra 注册到 Register）
├── Lobby Service (9879) - 使用 Nacos + Zebra
├── Slots Service (9527)
└── Chess Service (9637)
```

## 重要提示 / Important Notes

### Lobby 服务的特殊性
✅ **需要 Nacos** - 作为配置中心和服务发现客户端  
✅ **不在 Nacos 注册** - 正常现象，通过 Zebra 注册到 Register  
✅ **双重机制** - Nacos (服务消费者) + Zebra (服务提供者)  

### 验证 Lobby 部署
```bash
# 1. Lobby 不应该在 Nacos 中（这是正常的）
curl 'http://127.0.0.1:6878/nacos/v1/ns/instance/list?serviceName=petrel-game-lobby'
# 应该返回空

# 2. 检查 Lobby 服务状态
curl http://127.0.0.1:9879/actuator/health

# 3. 查看 Lobby 日志确认注册成功
tail -f petrel/logs/petrel-game-lobby/info_9879.txt
# 应该看到 "Server serverOnline server process server online lobby:..."
```

## 文档 / Documentation

- [架构澄清-Lobby服务注册机制.md](./架构澄清-Lobby服务注册机制.md) - **必读** - 正确的架构理解
- [部署指南 (Deployment Guide)](./部署指南.md) - 完整部署流程
- [问题分析 (Issue Analysis)](./分析报告-lobby模块注册问题.md) - 原始问题分析

## 问题排查 / Troubleshooting

### Lobby 服务问题排查

1. **Lobby 启动失败**
   ```bash
   # 确认 Nacos 正在运行（Lobby 需要它）
   curl http://127.0.0.1:6878/nacos/
   
   # 确认 MySQL 和 Redis 可访问
   netstat -tlnp | grep -E "3306|6379"
   
   # 查看日志
   tail -f petrel/logs/petrel-game-lobby/info_9879.txt
   ```

2. **Lobby 无法注册到 Register**
   ```bash
   # 确认 Register 服务正在运行
   netstat -tlnp | grep 7180
   
   # 查看 Register 日志
   tail -f petrel/logs/petrel-kernel-register/info_7180.log
   # 应该看到 "Register receive registry msg ServerRegistryRequest(serverId=lobby:..."
   ```

3. **Lobby 无法调用其他服务**
   - 确认 Nacos 正在运行
   - 确认其他服务（User、Game）在 Nacos 中注册
   - 检查 Lobby 日志中的 Ribbon/Feign 错误

### 正常现象（不是问题）
❌ Lobby 不在 Nacos 服务列表中 - **这是正常的设计**  
❌ Lobby 日志显示 Nacos 警告 - **可以忽略，只要能连接 Nacos 即可**  

详细的问题排查步骤请参考部署指南。/ See deployment guide for detailed troubleshooting.
