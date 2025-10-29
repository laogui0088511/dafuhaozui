# Petrel Gaming Platform - 部署说明

## 系统要求
- Java 8 或更高版本
- MySQL 数据库
- Redis (可选)
- Linux/Unix 系统

## 数据库配置
数据库连接信息已配置为:
- 服务器: `202.189.7.196`
- 用户名: `root`
- 密码: `Fagp@1908!`
- 数据库: `nacos`, `petrel_core`, `petrel_record`

## 部署步骤

### 1. 完整启动 (推荐)
```bash
bash start-all.sh
```

这个脚本会按照正确的顺序启动所有服务:
1. Nacos 服务发现 (端口 6878)
2. Redis (如果需要)
3. 所有 Petrel 游戏服务

### 2. 单独管理服务

#### 启动 Nacos
```bash
cd nacos/bin
bash startup.sh -m standalone
```

#### 启动游戏服务
```bash
cd petrel
bash start.sh start ALL           # 启动所有服务
bash start.sh start register      # 只启动注册服务
bash start.sh start user          # 只启动用户服务
bash start.sh start game          # 只启动游戏核心
bash start.sh start lobby         # 只启动大厅服务
bash start.sh start slots         # 只启动老虎机服务
bash start.sh start web           # 只启动Web服务
```

#### 停止服务
```bash
bash stop-all.sh                  # 停止所有服务

# 或单独停止
cd petrel
bash start.sh stop ALL            # 停止所有Petrel服务
bash start.sh stop register       # 停止单个服务
```

#### 查看服务状态
```bash
cd petrel
bash start.sh status
```

### 3. 验证部署

#### 检查 Nacos 控制台
```
http://localhost:6878/nacos
默认用户名/密码: nacos/nacos
```

#### 检查游戏后台接口
```
http://localhost:7180/load/initial
```
此接口应该返回初始化数据，且不会断线。

## 服务架构

```
┌─────────────┐
│   Nacos     │ (端口: 6878) - 服务发现和配置中心
└─────────────┘
       │
       ├── Register Service   (注册服务)
       ├── User Service       (用户服务)
       ├── Game Kernel        (游戏核心)
       ├── Lobby Service      (大厅服务) 
       ├── Slots Service      (老虎机服务)
       └── Web Service        (Web管理后台) - 端口 7180
```

## 服务启动顺序

重要: 服务必须按以下顺序启动以确保 Nacos 注册正确:

1. **Nacos** - 必须首先启动 (等待30秒初始化)
2. **Register Service** - 注册中心 (等待18秒)
3. **User Service** - 用户服务 (等待8秒)
4. **Game Kernel** - 游戏核心 (等待8秒)
5. **Lobby Service** - 大厅服务 (等待10秒)
6. **Slots Service** - 老虎机服务 (等待10秒)
7. **Web Service** - Web服务 (等待10秒)

所有服务都会自动注册到 Nacos。

## 配置说明

### Nacos 配置
- 配置文件: `nacos/conf/application.properties`
- 端口: 6878
- 模式: standalone (单机模式)
- 数据库连接已更新为远程数据库

### Petrel 服务配置
- 所有服务使用 `--spring.profiles.active=prod` 生产环境配置
- 所有服务配置 Nacos 地址: `127.0.0.1:6878`
- 服务自动从 Nacos 获取配置

## 常见问题

### 1. 端口 7180/load/initial 无数据
- 确保 Nacos 已启动并健康运行
- 确保所有服务已注册到 Nacos
- 检查数据库连接是否正常
- 查看日志: `petrel/logs/`

### 2. 服务无法启动
- 检查 Java 是否已安装: `java -version`
- 确保端口未被占用
- 查看对应的日志文件

### 3. 服务频繁断线
- 检查数据库连接超时设置 (已设置为 10秒连接，30秒socket超时)
- 确保网络连接稳定
- 检查 Nacos 心跳配置

## 日志位置

- Nacos 日志: `nacos/logs/`
- Petrel 服务日志: `petrel/logs/`

## 技术支持

如有问题，请查看日志文件或联系系统管理员。
