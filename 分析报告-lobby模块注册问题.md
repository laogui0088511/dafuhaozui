# 4-.start-lobby 模块无法正确注册到 2-.start-register 的根本原因分析

## 问题概述
petrel-game-lobby (4-.start-lobby.bat) 无法正确注册到 petrel-kernel-register (2-.start-register.bat) 服务注册中心。

## 根本原因分析

### 1. Nacos 服务注册中心端口配置不一致

#### 问题描述
通过分析两个模块的配置文件，发现了关键的端口配置不一致问题：

**petrel-kernel-register-1.0-SNAPSHOT-boot.jar 的配置：**
- `application-prod.yml` 中 Nacos 配置：
  ```yaml
  spring:
    cloud:
      nacos:
        discovery:
          server-addr: 127.0.0.1:6878
  ```

**petrel-game-lobby-1.0-SNAPSHOT-boot.jar 的配置：**
- `application-prod.yml` 中 Nacos 配置：
  ```yaml
  spring:
    cloud:
      nacos:
        discovery:
          server-addr: 127.0.0.1:6878
  ```

**Nacos 服务器实际配置：**
- `/nacos/conf/application.properties` 中配置：
  ```properties
  server.port=6878
  ```

表面上看端口都是 6878，但需要确认 Nacos 服务是否正常启动。

### 2. 服务启动顺序问题

#### 当前启动脚本分析

**start.sh 中的启动顺序：**
```bash
# 启动顺序（当使用 ALL 参数时）
1. register (注册中心) - sleep 18s
2. user (用户服务) - sleep 8s
3. game (游戏核心服务) - sleep 8s
4. lobby (大厅服务) - sleep 10s
5. slots (老虎机游戏服务) - sleep 10s
6. web (Web服务) - sleep 10s
```

#### 发现的问题
1. **register 服务启动等待时间可能不足**：18秒的等待时间可能不足以让 Nacos 完全初始化并准备好接受服务注册
2. **没有启动前置检查**：脚本没有验证 Nacos 是否真正启动完成
3. **没有启动 Nacos 服务器**：在启动应用服务之前，需要先确保 Nacos 服务器已经运行

### 3. Nacos 服务器未启动

#### 关键发现
系统中包含 Nacos 服务器目录 (`/nacos/`)，但在启动脚本中**没有包含启动 Nacos 的步骤**。

**Nacos 目录结构：**
```
nacos/
├── bin/
│   ├── startup.sh (Nacos启动脚本)
│   └── shutdown.sh (Nacos关闭脚本)
├── conf/
│   └── application.properties (配置端口6878)
└── data/
```

如果 Nacos 服务器没有运行，所有依赖它的服务都无法注册，包括：
- petrel-kernel-register (虽然它本身是注册服务，但也依赖 Nacos)
- petrel-game-lobby
- 其他所有服务

### 4. 数据库和 Redis 依赖

#### 数据库配置
所有服务都依赖 MySQL 数据库：
- 数据库地址：`127.0.0.1:3306`
- 数据库：`petrel_core` 和 `petrel_record`
- 用户名：`root`
- 密码：`Fagp@1908!`

#### Redis 配置
所有服务都依赖 Redis：
- Redis 地址：`127.0.0.1:6379`
- 密码：`Fagp_1908`
- lobby 使用 database: 0
- register 使用 database: 0

## 正确的部署流程

### 前置条件检查
1. ✅ MySQL 数据库已启动 (端口 3306)
2. ✅ Redis 服务已启动 (端口 6379)
3. ✅ 数据库 `petrel_core` 和 `petrel_record` 已创建
4. ✅ 数据库表结构已初始化

### 完整部署步骤

#### 步骤 1：启动 Nacos 服务器
```bash
cd /home/runner/work/dafuhaozui/dafuhaozui/nacos/bin
./startup.sh -m standalone

# 等待 Nacos 完全启动（建议等待 30-60 秒）
sleep 60

# 验证 Nacos 是否启动成功
curl http://127.0.0.1:6878/nacos/
```

#### 步骤 2：启动注册中心服务
```bash
cd /home/runner/work/dafuhaozui/dafuhaozui/petrel

# 使用 bat 文件（Windows）
2-.start-register.bat

# 或使用 shell 脚本（Linux）
./start.sh start register

# 等待注册中心完全启动（建议等待 20-30 秒）
sleep 30
```

#### 步骤 3：验证注册中心启动成功
```bash
# 检查进程
ps aux | grep petrel-kernel-register

# 检查端口
netstat -tlnp | grep 7180

# 检查 Nacos 中的服务注册
curl http://127.0.0.1:6878/nacos/v1/ns/instance/list?serviceName=petrel-kernel-register
```

#### 步骤 4：启动用户服务
```bash
cd /home/runner/work/dafuhaozui/dafuhaozui/petrel

# 使用 bat 文件（Windows）
1-.start-user.bat

# 或使用 shell 脚本（Linux）
./start.sh start user

sleep 15
```

#### 步骤 5：启动游戏核心服务
```bash
cd /home/runner/work/dafuhaozui/dafuhaozui/petrel

# 使用 bat 文件（Windows）
3-.start-game.bat

# 或使用 shell 脚本（Linux）
./start.sh start game

sleep 15
```

#### 步骤 6：启动大厅服务（Lobby）
```bash
cd /home/runner/work/dafuhaozui/dafuhaozui/petrel

# 使用 bat 文件（Windows）
4-.start-lobby.bat

# 或使用 shell 脚本（Linux）
./start.sh start lobby

sleep 15
```

#### 步骤 7：验证 Lobby 服务注册成功
```bash
# 检查进程
ps aux | grep petrel-game-lobby

# 检查端口
netstat -tlnp | grep 9879

# 检查 Nacos 中的服务注册
curl http://127.0.0.1:6878/nacos/v1/ns/instance/list?serviceName=petrel-game-lobby

# 检查服务日志
tail -f /home/runner/work/dafuhaozui/dafuhaozui/petrel/logs/petrel-game-lobby/info_*.log
```

#### 步骤 8：启动其他服务（可选）
```bash
# 启动老虎机服务
./start.sh start slots
sleep 15

# 启动 Web 服务
./start.sh start web
sleep 15
```

### 完整启动脚本示例

创建一个改进的启动脚本 `start-all.sh`：

```bash
#!/bin/bash

echo "=========================================="
echo "启动 Petrel 游戏系统"
echo "=========================================="

# 步骤 1: 启动 Nacos
echo "[1/7] 启动 Nacos 服务器..."
cd /home/runner/work/dafuhaozui/dafuhaozui/nacos/bin
./startup.sh -m standalone
echo "等待 Nacos 启动完成..."
sleep 60

# 验证 Nacos
echo "验证 Nacos 状态..."
if curl -s http://127.0.0.1:6878/nacos/ > /dev/null; then
    echo "✓ Nacos 启动成功"
else
    echo "✗ Nacos 启动失败，请检查日志"
    exit 1
fi

cd /home/runner/work/dafuhaozui/dafuhaozui/petrel

# 步骤 2: 启动注册中心
echo "[2/7] 启动注册中心服务..."
./start.sh start register
sleep 30

# 验证注册中心
echo "验证注册中心状态..."
if ps aux | grep -q "[p]etrel-kernel-register"; then
    echo "✓ 注册中心启动成功"
else
    echo "✗ 注册中心启动失败"
    exit 1
fi

# 步骤 3: 启动用户服务
echo "[3/7] 启动用户服务..."
./start.sh start user
sleep 15

# 步骤 4: 启动游戏核心服务
echo "[4/7] 启动游戏核心服务..."
./start.sh start game
sleep 15

# 步骤 5: 启动大厅服务
echo "[5/7] 启动大厅服务..."
./start.sh start lobby
sleep 15

# 验证大厅服务
echo "验证大厅服务状态..."
if ps aux | grep -q "[p]etrel-game-lobby"; then
    echo "✓ 大厅服务启动成功"
else
    echo "✗ 大厅服务启动失败"
    exit 1
fi

# 步骤 6: 启动老虎机服务
echo "[6/7] 启动老虎机服务..."
./start.sh start slots
sleep 15

# 步骤 7: 启动 Web 服务
echo "[7/7] 启动 Web 服务..."
./start.sh start web
sleep 15

echo "=========================================="
echo "所有服务启动完成"
echo "=========================================="

# 显示服务状态
echo ""
echo "服务状态："
echo "----------------------------------------"
echo "Nacos:        http://127.0.0.1:6878/nacos"
echo "注册中心:      端口 7180"
echo "大厅服务:      端口 9879"
echo "----------------------------------------"

# 列出所有运行的服务
echo ""
echo "运行中的服务进程："
ps aux | grep -E "petrel-kernel|petrel-game|petrel-cms" | grep -v grep
```

## 问题总结

### 主要原因排序
1. **Nacos 服务器未启动** - 最根本原因
2. **启动顺序和等待时间不合理** - 服务可能在依赖服务未就绪时启动
3. **缺少启动验证机制** - 无法确认服务是否真正启动成功
4. **缺少前置条件检查** - 未检查数据库和 Redis 是否可用

### 配置一致性检查
✅ Nacos 端口配置一致 (6878)
✅ Redis 配置一致
✅ 数据库配置一致
✅ 服务名称配置正确

## 建议改进

1. **创建统一的启动脚本**：包含完整的启动顺序和验证步骤
2. **添加健康检查**：在启动下一个服务前验证前置服务已就绪
3. **增加日志监控**：实时监控服务启动日志，及时发现问题
4. **配置文档化**：明确记录所有服务的端口和依赖关系
5. **添加错误处理**：启动失败时自动回滚或提示

## 验证清单

部署完成后，使用以下清单验证所有服务正常：

- [ ] Nacos 控制台可访问 (http://127.0.0.1:6878/nacos)
- [ ] 在 Nacos 中可以看到 petrel-kernel-register 服务
- [ ] 在 Nacos 中可以看到 petrel-game-lobby 服务
- [ ] 在 Nacos 中可以看到 petrel-kernel-user 服务
- [ ] 在 Nacos 中可以看到 petrel-kernel-game 服务
- [ ] 所有服务日志没有异常错误
- [ ] 可以通过 Redis 客户端连接到 Redis
- [ ] 可以通过 MySQL 客户端连接到数据库

## 附录：服务端口映射

| 服务名称 | JAR 文件 | 端口 | 用途 |
|---------|---------|------|------|
| Nacos | nacos | 6878 | 服务注册与配置中心 |
| Register | petrel-kernel-register | 7180 | 注册中心服务 |
| User | petrel-kernel-user | ? | 用户服务 |
| Game | petrel-kernel-game | ? | 游戏核心服务 |
| Lobby | petrel-game-lobby | 9879 | 大厅服务 |
| Chess | petrel-game-chess | ? | 棋牌游戏服务 |
| Slots | petrel-game-slots | ? | 老虎机游戏服务 |
| Web | petrel-cms-web | ? | Web 管理服务 |

## 结论

**4-.start-lobby 模块无法注册的根本原因是：Nacos 服务注册中心未启动。**

即使配置文件中的 Nacos 地址配置正确 (127.0.0.1:6878)，如果 Nacos 服务器进程本身没有运行，所有依赖它的服务都无法完成服务注册，包括 petrel-game-lobby。

**解决方案：严格按照本文档中的"正确的部署流程"执行，特别是确保先启动 Nacos 服务器，然后依次启动各个应用服务。**
