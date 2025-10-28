# Lobby 服务独立部署方案（不通过注册中心）

## 需求说明

**新需求**：4-.start-lobby（petrel-game-lobby）服务应该作为独立服务运行，不需要注册到 Nacos 服务注册中心。

## 当前问题分析

### 现状
1. lobby 服务的 JAR 包中包含了 `spring-cloud-starter-alibaba-nacos-discovery` 依赖
2. 配置文件 `application-prod.yml` 中配置了 Nacos 地址：
   ```yaml
   spring:
     cloud:
       nacos:
         discovery:
           server-addr: 127.0.0.1:6878
   ```
3. 这导致 lobby 服务启动时会尝试连接 Nacos 并注册

### 问题
- 如果 Nacos 未启动，lobby 服务会报错或启动失败
- lobby 服务依赖于 Nacos 的可用性
- 增加了不必要的依赖关系

## 解决方案

有两种方式可以让 lobby 服务独立运行，不注册到 Nacos：

### 方案 1：通过启动参数禁用服务注册（推荐，无需修改 JAR）

在启动 lobby 服务时添加参数禁用 Nacos 服务注册：

```bash
java -jar -Xmn512m -Xms1024m -Xmx1024m \
  petrel-game-lobby-1.0-SNAPSHOT-boot.jar \
  --spring.profiles.active=prod \
  --spring.cloud.nacos.discovery.enabled=false \
  --zebra.ip.out=127.0.0.1
```

**优点**：
- ✅ 不需要重新打包 JAR 文件
- ✅ 可以随时切换是否启用注册
- ✅ 部署简单，立即生效

**缺点**：
- ⚠️ 需要修改启动脚本
- ⚠️ 服务间通信需要直接使用 IP 和端口

### 方案 2：修改配置文件并重新打包 JAR

从 JAR 包中提取配置文件，修改后重新打包：

```bash
# 1. 提取配置文件
unzip petrel-game-lobby-1.0-SNAPSHOT-boot.jar BOOT-INF/classes/application-prod.yml

# 2. 修改配置文件，添加：
spring:
  cloud:
    nacos:
      discovery:
        enabled: false

# 3. 更新 JAR 文件
zip -u petrel-game-lobby-1.0-SNAPSHOT-boot.jar BOOT-INF/classes/application-prod.yml
```

**优点**：
- ✅ 配置永久生效
- ✅ 启动脚本简单

**缺点**：
- ❌ 需要修改和重新打包 JAR
- ❌ 维护成本较高

## 推荐实施方案

### 实施方案 1：修改启动脚本（最简单）

#### 1. 修改 `4-.start-lobby.bat` (Windows)

```batch
title lobby
java -jar -Xmn512m -Xms1024m -Xmx1024m petrel-game-lobby-1.0-SNAPSHOT-boot.jar --spring.profiles.active=prod --spring.cloud.nacos.discovery.enabled=false --zebra.ip.out=116.62.162.42
```

#### 2. 修改 `start.sh` 中的 `start_lobby()` 函数 (Linux)

```bash
start_lobby(){
    echo "-----------start-lobby-------------------"
    nohup java -jar -Xmn512m -Xms1024m -Xmx1024m $lobby \
        --spring.profiles.active=prod \
        --spring.cloud.nacos.discovery.enabled=false \
        --zebra.ip.out=122.114.55.213 \
        --zebra.port=8989 \
        >/dev/null 2>&1&
    sleep 10s
    tail -n 300 $lobby_log`ls $lobby_log -t1|awk '{if (NR ==1) print}'`
    echo "-----------end-lobby----------------------"
}
```

#### 3. 修改改进的启动脚本 `start-all-improved.sh`

在第 5 步启动大厅服务部分，修改为：

```bash
# 步骤 5: 启动大厅服务 (独立服务，不注册到 Nacos)
log_info "[5/7] 启动大厅服务 (petrel-game-lobby - 独立模式)..."

if check_service_running "petrel-game-lobby"; then
    log_warn "大厅服务已在运行，跳过启动"
else
    ZEBRA_IP_OUT=${1:-127.0.0.1}
    
    log_info "使用外部 IP: ${ZEBRA_IP_OUT}"
    log_info "注意: Lobby 服务运行在独立模式，不注册到 Nacos"
    
    nohup java -jar -Xmn512m -Xms1024m -Xmx1024m \
        petrel-game-lobby-1.0-SNAPSHOT-boot.jar \
        --spring.profiles.active=prod \
        --spring.cloud.nacos.discovery.enabled=false \
        --zebra.ip.out=${ZEBRA_IP_OUT} \
        > /dev/null 2>&1 &
    
    if wait_for_port 9879 20; then
        log_info "✓ 大厅服务启动成功 (端口 9879) - 独立模式"
    else
        log_error "✗ 大厅服务启动失败"
        exit 1
    fi
fi
```

## 服务间通信调整

### 问题：其他服务如何调用 Lobby？

如果 Lobby 不注册到 Nacos，其他服务无法通过服务发现机制找到它。需要进行以下调整：

#### 选项 A：使用固定 IP 和端口（推荐）

在调用 Lobby 服务的地方，直接使用 IP 和端口：

```java
// 不使用服务名
// String url = "http://petrel-game-lobby/api/xxx";

// 改为直接使用 IP 和端口
String url = "http://127.0.0.1:9879/api/xxx";
```

#### 选项 B：在配置文件中指定 Lobby 地址

在其他服务的配置文件中添加：

```yaml
service:
  lobby:
    url: http://127.0.0.1:9879
```

然后在代码中读取配置：

```java
@Value("${service.lobby.url}")
private String lobbyUrl;
```

#### 选项 C：配置静态服务列表（Ribbon）

如果其他服务使用 Ribbon 负载均衡，可以配置静态服务列表：

```yaml
petrel-game-lobby:
  ribbon:
    listOfServers: 127.0.0.1:9879
    NIWSServerListClassName: com.netflix.loadbalancer.ConfigurationBasedServerList
```

## 独立部署的优势

1. **降低依赖**：Lobby 服务不再依赖 Nacos，可以独立启动
2. **简化架构**：如果 Lobby 只需要被其他服务直接调用，不需要服务发现
3. **提高稳定性**：Nacos 故障不会影响 Lobby 服务
4. **部署灵活**：可以独立部署在不同的服务器上

## 独立部署的注意事项

### 1. 健康检查
需要配置健康检查端点：

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info
  endpoint:
    health:
      show-details: always
```

访问：`http://127.0.0.1:9879/actuator/health`

### 2. 服务监控
由于不在 Nacos 中注册，需要单独配置监控：

```bash
# 检查 Lobby 服务状态
curl http://127.0.0.1:9879/actuator/health

# 检查进程
ps aux | grep petrel-game-lobby

# 检查端口
netstat -tlnp | grep 9879
```

### 3. 负载均衡
如果需要多实例部署，需要配置外部负载均衡器（如 Nginx）：

```nginx
upstream lobby-backend {
    server 127.0.0.1:9879;
    server 127.0.0.1:9880;
    server 127.0.0.1:9881;
}

server {
    listen 8080;
    
    location /lobby/ {
        proxy_pass http://lobby-backend/;
    }
}
```

### 4. 配置管理
如果使用 Nacos 作为配置中心，需要决定是否继续使用：

- **保留配置中心**：只禁用服务发现
  ```bash
  --spring.cloud.nacos.discovery.enabled=false
  --spring.cloud.nacos.config.enabled=true
  ```

- **完全独立**：同时禁用服务发现和配置中心
  ```bash
  --spring.cloud.nacos.discovery.enabled=false
  --spring.cloud.nacos.config.enabled=false
  ```

## 更新后的部署流程

### 快速启动（独立 Lobby 模式）

```bash
# 1. 启动前置服务（MySQL, Redis）
# 确保 MySQL (3306) 和 Redis (6379) 已启动

# 2. 启动 Lobby 服务（独立模式，不需要 Nacos）
cd /path/to/petrel
java -jar -Xmn512m -Xms1024m -Xmx1024m \
    petrel-game-lobby-1.0-SNAPSHOT-boot.jar \
    --spring.profiles.active=prod \
    --spring.cloud.nacos.discovery.enabled=false \
    --zebra.ip.out=127.0.0.1 &

# 3. 验证服务启动
sleep 15
curl http://127.0.0.1:9879/actuator/health

# 4. 如果需要，启动其他服务（需要 Nacos）
cd /path/to/nacos/bin
./startup.sh -m standalone
sleep 60

cd /path/to/petrel
./start.sh start register
./start.sh start user
./start.sh start game
```

### 更新后的架构图

```
MySQL (3306) + Redis (6379)
    ↓
┌─────────────────────────────────────┐
│  Lobby Service (独立)               │
│  - 不注册到 Nacos                   │
│  - 端口: 9879                       │
│  - 直接通过 IP 访问                 │
└─────────────────────────────────────┘

Nacos (6878) (可选，用于其他服务)
    ↓
Register Service (7180)
    ↓
User Service + Game Service
    ↓
其他需要服务发现的服务
```

## 验证清单

### Lobby 独立模式验证
- [ ] Lobby 服务能够在没有 Nacos 的情况下启动
- [ ] Lobby 服务端口 9879 正常监听
- [ ] 健康检查接口可访问：`http://127.0.0.1:9879/actuator/health`
- [ ] 日志中没有 Nacos 连接错误
- [ ] 可以直接通过 IP 访问 Lobby 服务的 API
- [ ] 其他服务能够通过固定 IP 调用 Lobby 服务

### 系统整体验证
- [ ] MySQL 和 Redis 正常运行
- [ ] Lobby 服务独立运行正常
- [ ] 如果需要，其他服务在 Nacos 中正常注册
- [ ] 服务间通信正常

## 总结

**推荐方案**：通过启动参数 `--spring.cloud.nacos.discovery.enabled=false` 禁用 Nacos 服务注册，使 Lobby 服务独立运行。

**关键配置**：
```bash
--spring.cloud.nacos.discovery.enabled=false
```

**优点**：
1. ✅ 无需修改 JAR 包
2. ✅ 部署简单快速
3. ✅ Lobby 服务可以独立启动和运行
4. ✅ 不依赖 Nacos 的可用性
5. ✅ 可以通过固定 IP 和端口访问

**需要注意**：
1. ⚠️ 其他服务需要通过固定 IP 调用 Lobby
2. ⚠️ 多实例部署需要外部负载均衡
3. ⚠️ 需要独立的健康检查和监控方案
