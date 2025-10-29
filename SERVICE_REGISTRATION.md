# 服务注册架构说明

## 重要问题：服务注册逻辑

当前系统有两个可能的注册中心：

### 1. Nacos (端口 6878)
- 阿里巴巴的服务发现和配置中心
- 位于 `nacos/` 目录

### 2. Petrel-Kernel-Register (可能的独立注册中心)
- JAR: `petrel-kernel-register-1.0-SNAPSHOT-boot.jar`
- 可能是 Eureka、Consul 或自定义的注册中心

## 当前配置状态

### 已移除 Nacos 注册配置的服务：
- **petrel-kernel-register** - 可能本身就是注册中心，不应注册到 Nacos

### 仍配置 Nacos 注册的服务：
- **petrel-kernel-user** - 用户服务
- **petrel-kernel-game** - 游戏核心服务  
- **petrel-game-lobby** - 大厅服务
- **petrel-game-slots** - 老虎机服务
- **petrel-cms-web** - Web 管理后台

## 需要确认的问题

**请确认以下服务的注册逻辑：**

1. **petrel-kernel-register 是什么？**
   - [ ] 它是一个独立的注册中心（如 Eureka）
   - [ ] 它需要注册到 Nacos
   - [ ] 它是其他类型的服务

2. **其他服务应该注册到哪里？**
   - [ ] 注册到 Nacos (6878端口)
   - [ ] 注册到 petrel-kernel-register
   - [ ] 两者都注册
   - [ ] 都不注册（直接配置服务地址）

3. **Nacos 的作用是什么？**
   - [ ] 只用于配置管理（不做服务发现）
   - [ ] 用于服务发现和配置管理
   - [ ] 备用注册中心

## 原始配置（参考）

原始的 start.sh 中，**所有服务都没有任何注册中心配置**：
```bash
java -jar petrel-kernel-register-1.0-SNAPSHOT-boot.jar --spring.profiles.active=prod
java -jar petrel-kernel-user-1.0-SNAPSHOT-boot.jar --spring.profiles.active=prod
java -jar petrel-kernel-game-1.0-SNAPSHOT-boot.jar --spring.profiles.active=prod
# ... 等等
```

这意味着：
- 服务可能通过配置文件中的固定地址相互调用
- 或者使用 JAR 包内部配置的注册中心地址
- 或者根本不需要服务发现

## 建议的配置方案

### 方案 A：Nacos 作为主注册中心
```bash
# Register 服务不连接 Nacos（它可能是独立的）
# 其他所有服务连接 Nacos
--spring.cloud.nacos.discovery.server-addr=127.0.0.1:6878
--spring.cloud.nacos.config.server-addr=127.0.0.1:6878
```

### 方案 B：Petrel-Register 作为主注册中心
```bash
# 所有服务连接到 petrel-kernel-register
# Nacos 只用于配置管理
--spring.cloud.nacos.config.server-addr=127.0.0.1:6878
# 不配置 discovery
```

### 方案 C：不使用服务发现（当前原始配置）
```bash
# 所有服务只加载配置，通过固定地址互相调用
--spring.config.location=classpath:/,file:./config/
--spring.profiles.active=prod
```

## 当前采用的方案

**目前采用混合方案：**
- `petrel-kernel-register`: 不连接 Nacos（方案 C）
- 其他服务: 连接 Nacos 进行服务发现和配置管理（方案 A）

## 如何检查正确的配置

### 1. 检查 JAR 包内的配置
```bash
# 解压 JAR 查看配置
unzip -p petrel-kernel-register-1.0-SNAPSHOT-boot.jar BOOT-INF/classes/application.yml
unzip -p petrel-kernel-user-1.0-SNAPSHOT-boot.jar BOOT-INF/classes/application.yml
```

### 2. 查看启动日志
```bash
# 启动服务后查看日志中的注册信息
tail -f petrel/logs/petrel-kernel-register/*.log | grep -i "register\|eureka\|nacos\|discovery"
```

### 3. 检查 Nacos 控制台
```
访问: http://localhost:6878/nacos
查看"服务管理" -> "服务列表"
看哪些服务已注册
```

## 注册服务断线的可能原因

如果 `petrel-kernel-register` 一直断线，可能是：

1. **它本身是注册中心**，不应该有客户端注册逻辑
2. **配置冲突**：同时配置了多个注册中心
3. **网络问题**：无法连接到 Nacos
4. **端口冲突**：注册中心端口被占用
5. **配置错误**：Spring Cloud 版本不兼容

## 下一步行动

**请提供以下信息以便正确配置：**

1. petrel-kernel-register 服务的作用是什么？
2. 查看启动日志中的错误信息
3. 原来的系统中服务是如何互相发现的？
4. Nacos 在原系统中扮演什么角色？

**或者直接告诉我：**
- 哪些服务需要注册到 Nacos
- 哪些服务不需要注册到 Nacos
