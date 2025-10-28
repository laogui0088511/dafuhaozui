# dafuhaozui

Petrel 游戏系统 / Petrel Gaming Platform

## 重要说明 / Important Notice

⚠️ **Lobby 服务以独立模式运行，不注册到 Nacos 服务注册中心**

⚠️ **Lobby service runs in standalone mode, NOT registered to Nacos registry**

## 快速开始 / Quick Start

### 中文文档
- **[部署指南](./部署指南.md)** - 完整的部署流程和配置说明
- **[Lobby 独立部署方案](./Lobby独立部署方案.md)** - Lobby 服务独立运行方案（推荐）
- **[问题分析报告](./分析报告-lobby模块注册问题.md)** - 原始问题分析（已解决）

### English Documentation
- **[Quick Reference](./QUICK-REFERENCE.md)** - Quick reference guide

## 部署 / Deployment

### 前置要求 / Prerequisites
- Java 8+
- MySQL 5.7+
- Redis 5.0+
- **注意**: Lobby 服务不需要 Nacos

### 快速启动 / Quick Start

#### 方式 1: 启动所有服务（推荐）
```bash
cd petrel
./start-all-improved.sh

# Lobby 服务将以独立模式启动，不注册到 Nacos
```

#### 方式 2: 仅启动 Lobby 服务（独立模式）
```bash
cd petrel
./start-lobby-standalone.sh [外部IP] [端口]

# 示例：使用默认配置
./start-lobby-standalone.sh

# 示例：指定外部 IP 和端口
./start-lobby-standalone.sh 192.168.1.100 9879
```

#### 关闭所有服务
```bash
cd petrel
./stop-all-improved.sh
```

### 服务架构 / Service Architecture
```
MySQL (3306) + Redis (6379)
    ↓
┌──────────────────────────────────────┐
│ Lobby Service (独立服务)             │
│ - 不注册到 Nacos                     │
│ - 端口: 9879                         │
│ - 直接通过 IP 访问                   │
└──────────────────────────────────────┘

Nacos (6878) (可选，用于其他服务)
    ↓
Register Service (7180)
    ↓
User Service + Game Service
    ↓
其他需要服务发现的服务
```

## 重要提示 / Important Notes

### Lobby 服务特点
✅ **独立运行** - 不依赖 Nacos，可以单独启动  
✅ **直接访问** - 通过 IP:9879 直接访问  
✅ **配置简单** - 启动参数已配置 `--spring.cloud.nacos.discovery.enabled=false`  
✅ **高可用性** - Nacos 故障不影响 Lobby 服务  

### 如何访问 Lobby 服务
```bash
# 健康检查
curl http://127.0.0.1:9879/actuator/health

# 直接 API 调用（其他服务）
# 使用固定 IP 和端口，而不是服务名
String lobbyUrl = "http://127.0.0.1:9879/api/xxx";
```

### 其他服务如何调用 Lobby
在其他服务的配置中，使用固定 IP 和端口：
```yaml
service:
  lobby:
    url: http://127.0.0.1:9879
```

## 文档 / Documentation

- [Lobby 独立部署方案](./Lobby独立部署方案.md) - **推荐阅读** - 详细的独立部署方案
- [部署指南 (Deployment Guide)](./部署指南.md) - 完整部署流程
- [问题分析 (Issue Analysis)](./分析报告-lobby模块注册问题.md) - 原始问题根本原因分析
- [快速参考 (Quick Reference)](./QUICK-REFERENCE.md) - English quick reference

## 问题排查 / Troubleshooting

### Lobby 服务问题排查

1. **Lobby 服务启动失败**
   ```bash
   # 检查 MySQL 和 Redis
   netstat -tlnp | grep -E "3306|6379"
   
   # 查看日志
   tail -f petrel/logs/petrel-game-lobby/info_*.log
   ```

2. **Lobby 服务端口被占用**
   ```bash
   # 检查端口 9879
   netstat -tlnp | grep 9879
   
   # 停止占用端口的进程
   kill $(lsof -t -i:9879)
   ```

3. **其他服务无法访问 Lobby**
   - 确认 Lobby 服务正在运行：`ps aux | grep petrel-game-lobby`
   - 确认端口可访问：`telnet 127.0.0.1 9879`
   - 确认其他服务配置了正确的 Lobby IP 和端口

### 不需要检查的问题
❌ Lobby 服务不在 Nacos 中 - **这是正常的，Lobby 以独立模式运行**  
❌ Nacos 连接错误 - **Lobby 不使用 Nacos，可以忽略相关错误**

详细的问题排查步骤请参考部署指南。/ See deployment guide for detailed troubleshooting.

## 验证部署 / Verify Deployment

```bash
# 1. 检查 Lobby 服务进程
ps aux | grep petrel-game-lobby

# 2. 检查 Lobby 服务端口
netstat -tlnp | grep 9879

# 3. 健康检查
curl http://127.0.0.1:9879/actuator/health

# 4. 查看日志
tail -f petrel/logs/petrel-game-lobby/info_*.log
```

## 脚本说明 / Scripts

| 脚本 | 用途 | 说明 |
|------|------|------|
| `start-all-improved.sh` | 启动所有服务 | Lobby 以独立模式启动 |
| `start-lobby-standalone.sh` | 仅启动 Lobby | Lobby 独立启动脚本 |
| `stop-all-improved.sh` | 停止所有服务 | 优雅关闭 |
| `4-.start-lobby.bat` | Windows 启动 Lobby | 已配置独立模式 |
| `start.sh` | Linux 启动脚本 | 已配置独立模式 |
