# dafuhaozui

Petrel 游戏系统 / Petrel Gaming Platform

## ⚠️ 重要问题解决方案

### 1. Lobby 注册失败问题

如果遇到 Lobby 服务无法注册到 Register（7180）的问题，请使用新的正确启动脚本：

```bash
cd petrel
./start-correct.sh [外部IP]
```

详细说明：[Lobby注册失败问题分析.md](./Lobby注册失败问题分析.md)

### 2. Lobby 注册后掉线问题

如果 Lobby 注册成功后仍然掉线，特别是访问后台管理系统时：

**原因**：
- GC（垃圾回收）暂停时间过长导致心跳超时
- 后台管理系统频繁查询占用资源
- 内存不足触发频繁 GC

**解决方案**：
1. 使用优化的启动脚本（已增加内存到 2GB）
2. 启用 GC 监控日志
3. 后台查询使用缓存

详细分析：[Lobby掉线问题分析.md](./Lobby掉线问题分析.md)

### 3. Redis-Database 数据同步

系统采用 Redis 作为缓存层提高性能，MySQL 作为持久化存储。

**关键特性**：
- Redis 连接池优化（最大50连接，空闲20连接）
- 自动重连和健康检查
- 云端更新检查机制
- 数据同步监控工具

**监控工具**：
```bash
# 检查 Redis-MySQL 同步状态
./monitor-redis-db-sync.sh

# 检查云端更新
./check-cloud-updates.sh
```

详细说明：[Redis-Database同步指南](./REDIS-DATABASE-SYNC-GUIDE.md)

## 重要架构说明 / Architecture Notice

**Lobby 服务使用双重注册机制：**
1. ✅ 使用 Nacos 作为**配置中心**和**服务发现客户端**（调用其他服务）
2. ✅ 通过 **Zebra RPC** 注册到 **Register 服务** (7180)，不在 Nacos 中注册
3. ✅ 游戏客户端通过 Zebra 协议连接 Lobby

详细说明请查看：[架构澄清-Lobby服务注册机制.md](./架构澄清-Lobby服务注册机制.md)

## 快速开始 / Quick Start

### 中文文档
- **[Redis-Database同步指南](./REDIS-DATABASE-SYNC-GUIDE.md)** - Redis缓存与数据库同步机制（新增）
- **[Lobby掉线问题分析.md](./Lobby掉线问题分析.md)** - Lobby 掉线问题的原因和解决方案
- **[Lobby注册失败问题分析.md](./Lobby注册失败问题分析.md)** - 注册问题根本原因和解决方案
- **[架构澄清-Lobby服务注册机制.md](./架构澄清-Lobby服务注册机制.md)** - 正确的架构理解
- **[部署指南](./部署指南.md)** - 完整的部署流程和配置说明
- **[分析报告-lobby模块注册问题.md](./分析报告-lobby模块注册问题.md)** - 原始问题分析

## 部署 / Deployment

### 前置要求 / Prerequisites
- Java 8+
- MySQL 5.7+
- Redis 5.0+
- **Nacos** - Lobby 需要 Nacos 作为配置中心和服务发现

### 快速启动 / Quick Start

#### 方式 1: 使用正确的启动脚本（强烈推荐）
```bash
cd petrel
./start-correct.sh [外部IP]

# 这是基于 2022 年生产日志分析的正确启动脚本
# 已解决 Lobby 注册失败问题
```

**关键改进**：
- ✅ Register 启动后等待 25 秒（确保 HTTP 接口完全就绪）
- ✅ 正确的服务启动顺序
- ✅ 每个服务都有充足的启动时间
- ✅ 包含端口和健康检查验证

#### 方式 2: 使用改进的启动脚本
```bash
cd petrel
./start-all-improved.sh [外部IP]
```

#### 方式 3: 手动启动（需要严格遵守等待时间）
```bash
# 1. 启动 Nacos
cd nacos/bin
./startup.sh -m standalone
sleep 60  # 必须等待 60 秒

# 2. 启动 Register 服务（关键）
cd petrel
./start.sh start register
sleep 25  # 必须等待 25 秒！（不是 18 秒）

# 3. 启动其他核心服务
./start.sh start user
sleep 15
./start.sh start game
sleep 15

# 4. 启动 Lobby（确保 Register 完全就绪）
./start.sh start lobby
sleep 10
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
│   ⚠️ 启动后需要 25 秒才能接受注册！
├── User Service (8719)
└── Game Service
    ↓ (Nacos 服务发现)    ↑ (Zebra RPC 注册)
游戏服务层（通过 Zebra 注册到 Register）
├── Lobby Service (9879) - 使用 Nacos + Zebra
├── Slots Service (9527)
└── Chess Service (9637)
```

## 重要提示 / Important Notes

### ⚠️ Lobby 注册失败的常见原因

1. **Register 启动等待时间不足**（最常见）
   - 问题：只等待 18 秒，HTTP 接口未就绪
   - 解决：必须等待至少 25 秒

2. **Lobby 启动过早**
   - 问题：在 Register HTTP 接口初始化前启动
   - 解决：确保 Register 完全就绪后再启动 Lobby

3. **Nacos 未完全启动**
   - 问题：Lobby 需要 Nacos 进行服务发现
   - 解决：Nacos 启动后等待 60 秒

### 关键等待时间（基于生产日志）

| 服务 | 启动时间 | HTTP初始化 | 建议等待 | 说明 |
|------|---------|----------|---------|------|
| Nacos | 30-40秒 | 20秒 | **60秒** | 配置中心 |
| Register | 8-10秒 | 15-20秒 | **25秒** | ⚠️ 关键！ |
| User/Game | 5-8秒 | 5秒 | **15秒** | 核心服务 |
| Lobby/Chess/Slots | 5-6秒 | 3秒 | **10秒** | 游戏服务 |

### 验证 Lobby 注册成功
```bash
# 1. 检查 Lobby 服务状态
curl http://127.0.0.1:9879/actuator/health

# 2. 验证 Register 接收到注册（关键！）
tail -20 petrel/logs/petrel-kernel-register/info_7180.log | grep "Register receive registry msg.*lobby"
# 应该看到：Register receive registry msg ServerRegistryRequest(serverId=lobby:127.0.0.1:9879...)

# 3. 验证 Lobby 发送了注册
tail -20 petrel/logs/petrel-game-lobby/info_9879.txt | grep "StartAfter send register msg"
# 应该看到：StartAfter send register msg ServerRegistryRequest(serverId=lobby:127.0.0.1:9879...)

# 4. 验证连接建立
tail -20 petrel/logs/petrel-kernel-register/info_7180.log | grep "Connection channel active.*9879"
# 应该看到：Register Connection channel active: 127.0.0.1:9879
```

## 文档 / Documentation

- **[Lobby注册失败问题分析.md](./Lobby注册失败问题分析.md)** - **必读** - 注册失败的根本原因和解决方案
- [架构澄清-Lobby服务注册机制.md](./架构澄清-Lobby服务注册机制.md) - 正确的架构理解
- [部署指南 (Deployment Guide)](./部署指南.md) - 完整部署流程
- [问题分析 (Issue Analysis)](./分析报告-lobby模块注册问题.md) - 原始问题分析

## 问题排查 / Troubleshooting

### Lobby 服务问题排查

1. **Lobby 无法注册到 Register**
   ```bash
   # 检查 Register 是否完全启动（等待至少 25 秒）
   netstat -tlnp | grep 7180
   
   # 检查 Register 日志
   tail -f petrel/logs/petrel-kernel-register/info_7180.log
   # 看是否有 "Register receive registry msg"
   
   # 检查 Lobby 日志
   tail -f petrel/logs/petrel-game-lobby/info_9879.txt
   # 看是否有 "StartAfter send register msg"
   ```

2. **Register start not connect server 错误**
   - 这是**正常现象**！Register 启动时会尝试连接服务
   - 服务稍后通过 HTTP 接口注册即可
   - 不需要担心这个初始错误

3. **Lobby 启动失败**
   ```bash
   # 确认 Nacos 正在运行（Lobby 需要它）
   curl http://127.0.0.1:6878/nacos/
   
   # 确认 MySQL 和 Redis 可访问
   netstat -tlnp | grep -E "3306|6379"
   
   # 查看详细日志
   tail -100 petrel/logs/petrel-game-lobby/error_9879.txt
   ```

详细的问题排查步骤请参考 [Lobby注册失败问题分析.md](./Lobby注册失败问题分析.md)

### Redis-Database 同步问题排查

1. **Redis 连接失败**
   ```bash
   # 检查 Redis 运行状态
   redis-cli ping
   
   # 监控 Redis-MySQL 同步
   ./monitor-redis-db-sync.sh
   ```

2. **缓存命中率低**
   ```bash
   # 查看缓存统计
   redis-cli info stats | grep keyspace
   
   # 检查性能指标
   ./monitor-redis-db-sync.sh
   ```

3. **云端更新失败**
   ```bash
   # 检查云端服务可用性
   ./check-cloud-updates.sh --check
   
   # 生成完整报告
   ./check-cloud-updates.sh --report
   ```

详细排查指南请参考 [Redis-Database同步指南](./REDIS-DATABASE-SYNC-GUIDE.md)

## 脚本说明 / Scripts

| 脚本 | 用途 | 推荐程度 | 说明 |
|------|------|---------|------|
| `start-correct.sh` | 正确的启动脚本 | ⭐⭐⭐⭐⭐ | **强烈推荐** - 基于生产日志优化 |
| `start-all-improved.sh` | 改进的启动脚本 | ⭐⭐⭐⭐ | 可用但等待时间可能不足 |
| `start.sh` | 原始启动脚本 | ⭐⭐ | 需要手动修改等待时间 |
| `stop-all-improved.sh` | 停止所有服务 | ⭐⭐⭐⭐⭐ | 优雅关闭 |
| `monitor-redis-db-sync.sh` | Redis-MySQL 同步监控 | ⭐⭐⭐⭐⭐ | **新增** - 监控数据同步状态 |
| `check-cloud-updates.sh` | 云端更新检查 | ⭐⭐⭐⭐⭐ | **新增** - 检查和验证云端更新 |
