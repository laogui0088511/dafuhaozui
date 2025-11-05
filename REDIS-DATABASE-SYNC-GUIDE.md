# Redis-Database 数据同步与云端更新检查指南

## 概述

本文档详细说明了 Petrel 游戏系统中 Redis 缓存与 MySQL 数据库之间的数据同步逻辑，以及云端更新检查机制。

## 1. 系统架构

### 数据流向

```
云端更新服务器 (http://192.168.10.102:8089/dtc_update/)
    ↓
游戏服务 (Lobby, Game, User)
    ↓
Redis 缓存 (127.0.0.1:6379)
    ↔ 双向同步
MySQL 数据库 (202.189.7.196:3306)
```

### 关键组件

1. **Redis**: 用作缓存层，提高读取性能
2. **MySQL**: 持久化存储，主数据源
3. **云端更新服务**: 提供配置文件和游戏数据更新
4. **Nacos**: 配置中心，管理服务配置

## 2. Redis 配置优化

### 2.1 连接池配置

已在以下文件中优化 Redis 连接池配置：

#### `petrel/config/application-prod.yml`

```yaml
spring:
  redis:
    host: 127.0.0.1
    port: 6379
    timeout: 10000
    database: 0
    # Lettuce 连接池（推荐）
    lettuce:
      pool:
        max-active: 50      # 最大活跃连接
        max-idle: 20        # 最大空闲连接
        min-idle: 5         # 最小空闲连接
        max-wait: 10000     # 连接池耗尽时最大等待时间
        time-between-eviction-runs: 30000   # 驱逐检查间隔
        min-evictable-idle-time: 60000      # 最小可驱逐空闲时间
      shutdown-timeout: 100
    # Jedis 连接池（备用）
    jedis:
      pool:
        max-active: 50
        max-idle: 20
        min-idle: 5
        max-wait: 10000
        time-between-eviction-runs: 30000
        min-evictable-idle-time: 60000
        test-on-borrow: true    # 借用时测试连接
        test-on-return: false   # 归还时不测试
        test-while-idle: true   # 空闲时测试连接
```

#### `nacos/data/tenant-config-data/.../data-config.yaml`

```yaml
redis:
  host: 127.0.0.1
  port: 6379
  timeout: 10000
  database: 0
  jedis:
    pool:
      max-active: 50
      max-idle: 20
      min-idle: 5
      max-wait: 10000
      time-between-eviction-runs: 30000
      min-evictable-idle-time: 60000
      test-on-borrow: true
      test-on-return: false
      test-while-idle: true
```

### 2.2 配置说明

| 参数 | 值 | 说明 |
|------|---|------|
| max-active | 50 | 最大活跃连接数，足够支持高并发 |
| max-idle | 20 | 最大空闲连接数，保持连接池活跃 |
| min-idle | 5 | 最小空闲连接数，确保快速响应 |
| max-wait | 10000 | 10秒等待时间，避免无限等待 |
| timeout | 10000 | 10秒超时，平衡性能和可靠性 |
| test-on-borrow | true | 借用时测试，确保连接有效 |
| test-while-idle | true | 空闲时测试，保持连接健康 |

### 2.3 日志配置

已添加 Redis 操作日志：

```yaml
logging:
  level:
    org.springframework.data.redis: INFO
    io.lettuce.core: INFO
    redis.clients.jedis: INFO
```

这些日志帮助监控 Redis 操作和诊断问题。

## 3. 数据同步机制

### 3.1 同步策略

Petrel 系统采用 **Cache-Aside Pattern**（旁路缓存模式）：

1. **读取流程**:
   ```
   应用 → 检查 Redis
      ↓ (缓存未命中)
   应用 → 读取 MySQL
      ↓
   应用 → 写入 Redis
      ↓
   返回数据
   ```

2. **写入流程**:
   ```
   应用 → 写入 MySQL
      ↓
   应用 → 删除/更新 Redis 缓存
      ↓
   返回结果
   ```

### 3.2 缓存失效策略

- **TTL (Time-To-Live)**: 为缓存数据设置过期时间
- **LRU (Least Recently Used)**: Redis 内存不足时自动驱逐最少使用的数据
- **主动失效**: 数据更新时主动删除相关缓存

### 3.3 数据一致性保证

1. **强一致性场景**（如金币转账、VIP 状态）:
   - 直接操作数据库
   - 删除 Redis 缓存
   - 下次读取时重新加载

2. **最终一致性场景**（如游戏配置、排行榜）:
   - 允许短时间内不一致
   - 定期刷新缓存
   - 使用 TTL 自动过期

## 4. 监控工具

### 4.1 Redis-Database 同步监控脚本

**脚本**: `monitor-redis-db-sync.sh`

**功能**:
- 检查 Redis 连接状态
- 检查 MySQL 连接状态
- 监控 Redis 内存使用
- 统计 Redis 键数量
- 检查 Redis 持久化配置
- 计算缓存命中率
- 分析性能指标

**使用方法**:

```bash
# 运行一次检查
./monitor-redis-db-sync.sh

# 定期监控（每5分钟）
watch -n 300 ./monitor-redis-db-sync.sh

# 后台持续监控
nohup bash -c 'while true; do ./monitor-redis-db-sync.sh; sleep 300; done' > monitor.log 2>&1 &
```

**输出示例**:

```
==========================================
Redis-Database Synchronization Monitor
2025-11-05 03:30:00
==========================================

[INFO] Checking Redis connection...
[INFO] ✓ Redis is running and responding
[INFO] Redis memory usage: 2.5M
[INFO] Total keys in Redis: 1523
[INFO] Cache hit rate: 87.34%
[INFO] ✓ MySQL is running and responding
[INFO] Number of tables in petrel_core: 45
[INFO] Database size: 256.78 MB
==========================================
```

### 4.2 云端更新检查脚本

**脚本**: `check-cloud-updates.sh`

**功能**:
- 检查云端更新服务器可用性
- 获取最新更新信息
- 验证更新数据完整性
- 检查本地配置文件
- 生成同步报告

**使用方法**:

```bash
# 完整检查
./check-cloud-updates.sh

# 仅检查端点可用性
./check-cloud-updates.sh --check

# 仅生成报告
./check-cloud-updates.sh --report

# 查看帮助
./check-cloud-updates.sh --help

# 定期检查（每6小时）
0 */6 * * * /path/to/check-cloud-updates.sh >> /path/to/cloud-check.log 2>&1
```

**云端地址**:
- 更新服务: `http://192.168.10.102:8089/dtc_update/`
- Roller 配置: `http://192.168.10.102:8555/chfs/shared/java`

## 5. 故障排查

### 5.1 Redis 连接失败

**症状**:
- 应用日志显示 Redis 连接超时
- 缓存未命中率突然升高
- 应用响应变慢

**排查步骤**:

```bash
# 1. 检查 Redis 是否运行
redis-cli ping
# 应该返回 PONG

# 2. 检查 Redis 端口
netstat -tlnp | grep 6379
ss -tlnp | grep 6379

# 3. 检查 Redis 连接数
redis-cli info clients | grep connected_clients

# 4. 检查 Redis 日志
tail -100 /path/to/redis/logs/redis.log

# 5. 测试连接性能
redis-cli --latency

# 6. 检查内存使用
redis-cli info memory
```

**解决方案**:

1. **连接数超限**:
   ```bash
   # 增加最大连接数
   redis-cli config set maxclients 10000
   ```

2. **内存不足**:
   ```bash
   # 增加最大内存
   redis-cli config set maxmemory 2gb
   # 设置驱逐策略
   redis-cli config set maxmemory-policy allkeys-lru
   ```

3. **重启 Redis**:
   ```bash
   # 保存数据
   redis-cli save
   # 重启服务
   systemctl restart redis
   # 或
   /path/to/redis/bin/redis-server /path/to/redis.conf
   ```

### 5.2 MySQL 连接失败

**症状**:
- 应用日志显示数据库连接超时
- HikariCP 连接池耗尽
- 数据无法持久化

**排查步骤**:

```bash
# 1. 测试数据库连接（使用环境变量存储密码）
export MYSQL_PASS='your_password'
mysql -h 202.189.7.196 -P 3306 -u root -p"$MYSQL_PASS" -e "SELECT 1"

# 2. 检查网络延迟
ping -c 10 202.189.7.196

# 3. 检查数据库状态
mysql -h 202.189.7.196 -P 3306 -u root -p"$MYSQL_PASS" -e "SHOW PROCESSLIST"

# 4. 查看应用日志中的连接池信息
grep -i "HikariPool\|connection" petrel/logs/*/info_*.log | tail -50
```

**解决方案**:

1. **增加连接超时**（已在配置中）:
   ```yaml
   connection-timeout: 30000
   socket-timeout: 60000
   ```

2. **增加连接池大小**:
   ```yaml
   maximum-pool-size: 100  # 从50增加到100
   ```

3. **检查数据库慢查询**:
   ```sql
   -- 查看慢查询
   SHOW VARIABLES LIKE 'slow_query_log';
   SHOW VARIABLES LIKE 'long_query_time';
   
   -- 查看当前查询
   SHOW FULL PROCESSLIST;
   ```

### 5.3 缓存命中率低

**症状**:
- 监控显示缓存命中率 < 80%
- 数据库负载高
- 应用响应慢

**排查步骤**:

```bash
# 1. 查看缓存统计
redis-cli info stats | grep keyspace

# 2. 查看热点键
redis-cli --hotkeys

# 3. 查看键的 TTL 分布
redis-cli --scan | while read key; do 
    ttl=$(redis-cli ttl "$key")
    echo "$key: $ttl"
done | sort -t: -k2 -n | tail -20

# 4. 分析慢查询
redis-cli slowlog get 10
```

**解决方案**:

1. **优化缓存策略**:
   - 增加常用数据的缓存时间
   - 预加载热点数据
   - 使用 Redis Pipeline 批量操作

2. **调整 TTL**:
   ```
   # 用户信息: 30分钟
   # 游戏配置: 1小时
   # 排行榜: 5分钟
   # 房间状态: 实时（不缓存或极短TTL）
   ```

3. **监控和告警**:
   - 设置命中率告警阈值（< 80%）
   - 监控驱逐键数量
   - 跟踪慢查询

### 5.4 云端更新失败

**症状**:
- 游戏配置未更新
- Roller 文件版本旧
- 更新检查脚本失败

**排查步骤**:

```bash
# 1. 检查云端服务器可达性
curl -I http://192.168.10.102:8089/dtc_update/
curl -I http://192.168.10.102:8555/chfs/shared/java

# 2. 检查网络连接
ping 192.168.10.102
traceroute 192.168.10.102

# 3. 查看更新日志
cat cloud-update-check.log | tail -50

# 4. 检查本地文件
ls -lah petrel/external/roller/
```

**解决方案**:

1. **配置代理**（如需要）:
   ```bash
   export http_proxy="http://proxy:port"
   export https_proxy="http://proxy:port"
   ```

2. **手动下载更新**:
   ```bash
   # 创建备份
   tar -czf external-backup-$(date +%Y%m%d).tar.gz petrel/external/
   
   # 下载新文件
   wget -r -np -nd -P petrel/external/roller/ http://192.168.10.102:8555/chfs/shared/java/
   ```

3. **使用备用服务器**（如有）:
   修改 `nacos/data/config-data/DEFAULT_GROUP/petrel-game-config.yaml`:
   ```yaml
   host:
     url: http://backup-server:8089/dtc_update/
   ```

## 6. 最佳实践

### 6.1 性能优化

1. **Redis 持久化**:
   ```conf
   # redis.conf
   # AOF 持久化（推荐）
   appendonly yes
   appendfsync everysec
   
   # RDB 快照（备份）
   save 900 1
   save 300 10
   save 60 10000
   ```

2. **连接复用**:
   - 使用连接池（已配置）
   - 避免频繁创建/销毁连接
   - 设置合理的超时时间

3. **批量操作**:
   ```java
   // 使用 Pipeline 批量操作
   redisTemplate.executePipelined(new RedisCallback<Object>() {
       @Override
       public Object doInRedis(RedisConnection connection) {
           for (String key : keys) {
               connection.get(key.getBytes());
           }
           return null;
       }
   });
   ```

### 6.2 安全建议

1. **Redis 访问控制**:
   ```conf
   # redis.conf
   requirepass your_strong_password
   bind 127.0.0.1
   protected-mode yes
   ```

2. **数据库连接**:
   - 使用强密码
   - 限制远程访问
   - 使用 SSL/TLS（生产环境）

3. **定期备份**:
   ```bash
   # 自动备份脚本
   #!/bin/bash
   DATE=$(date +%Y%m%d-%H%M%S)
   # Redis 备份
   redis-cli save
   cp /var/lib/redis/dump.rdb /backup/redis-$DATE.rdb
   # MySQL 备份（使用环境变量存储密码）
   export MYSQL_PASS='your_password'
   mysqldump -h 202.189.7.196 -u root -p"$MYSQL_PASS" petrel_core > /backup/mysql-$DATE.sql
   ```

### 6.3 监控和告警

1. **设置监控指标**:
   - Redis 内存使用率 > 80%
   - 缓存命中率 < 80%
   - 连接池使用率 > 80%
   - MySQL 慢查询数量
   - 云端更新检查失败

2. **配置告警**:
   ```bash
   # 添加到 crontab
   */5 * * * * /path/to/monitor-redis-db-sync.sh | grep ERROR && /path/to/send-alert.sh
   0 */6 * * * /path/to/check-cloud-updates.sh || /path/to/send-alert.sh
   ```

3. **日志分析**:
   - 定期分析应用日志
   - 监控异常和错误
   - 跟踪性能趋势

## 7. 维护计划

### 7.1 日常维护

**每天**:
- 检查 Redis/MySQL 运行状态
- 查看错误日志
- 监控缓存命中率

**每周**:
- 运行同步监控脚本
- 检查云端更新
- 分析性能数据
- 清理过期日志

**每月**:
- 数据库优化（ANALYZE、OPTIMIZE）
- Redis 内存清理
- 更新配置文件
- 完整备份

### 7.2 定期检查清单

- [ ] Redis 服务运行正常
- [ ] MySQL 服务运行正常
- [ ] 缓存命中率 > 80%
- [ ] 连接池无泄漏
- [ ] 云端更新服务可访问
- [ ] 本地配置文件最新
- [ ] 日志文件大小合理
- [ ] 备份文件完整

## 8. 相关文档

- [README.md](README.md) - 项目概述和快速开始
- [DEPLOYMENT.md](DEPLOYMENT.md) - 部署指南
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - 问题排查
- [Lobby掉线问题分析.md](Lobby掉线问题分析.md) - Lobby 服务问题
- [架构澄清-Lobby服务注册机制.md](架构澄清-Lobby服务注册机制.md) - 服务架构

## 9. 技术支持

如遇问题，请按以下步骤操作：

1. 查看本文档的故障排查章节
2. 运行监控脚本收集信息
3. 检查应用日志和系统日志
4. 准备以下信息联系技术支持：
   - 问题描述和发生时间
   - 错误日志和堆栈跟踪
   - 监控脚本输出
   - 系统资源使用情况

---

**最后更新**: 2025-11-05  
**版本**: 1.0  
**维护**: Petrel 开发团队
