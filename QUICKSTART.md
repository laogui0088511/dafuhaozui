# 快速启动指南 (Quick Start Guide)

## 一键启动所有服务

```bash
bash start-all.sh
```

这将按顺序启动：
1. Nacos (端口 6878)
2. Redis (如果需要)
3. 所有 Petrel 游戏服务

## 验证部署

### 1. 检查服务状态
```bash
cd petrel
bash start.sh status
```

### 2. 测试后台接口
```bash
# 手动测试
curl http://localhost:7180/load/initial

# 自动化测试（30次，检测稳定性）
bash validate-endpoint.sh
```

### 3. 访问 Nacos 控制台
```
http://localhost:6878/nacos
用户名: nacos
密码: nacos
```

## 停止所有服务

```bash
bash stop-all.sh
```

## 重启服务

```bash
bash stop-all.sh
bash start-all.sh
```

或者重启单个服务：
```bash
cd petrel
bash start.sh stop web
bash start.sh start web
```

## 常见命令

### 启动单个服务
```bash
cd petrel
bash start.sh start register    # 注册服务
bash start.sh start user         # 用户服务
bash start.sh start game         # 游戏核心
bash start.sh start lobby        # 大厅服务
bash start.sh start slots        # 老虎机服务
bash start.sh start web          # Web服务 (7180端口)
```

### 查看日志
```bash
# 查看最新日志
tail -f petrel/logs/petrel-cms-web/$(ls -t petrel/logs/petrel-cms-web/ | head -1)

# 查看错误
find petrel/logs -name "*.log" -mmin -10 -exec grep -i "error" {} +
```

## 配置文件位置

- **Nacos 配置**: `nacos/conf/application.properties`
- **Petrel 外部配置**: `petrel/config/application-prod.yml`
- **Nacos 数据配置**: `nacos/data/tenant-config-data/.../data-config.yaml`

## 数据库配置

已配置连接到：
- **地址**: 202.189.7.196:3306
- **用户名**: root
- **密码**: Fagp@1908!
- **数据库**: nacos, petrel_core, petrel_record

## 关键端口

- **6878**: Nacos 服务发现
- **7180**: Petrel Web 后台
- **3306**: MySQL 数据库
- **6379**: Redis (可选)

## 故障排查

如果遇到问题：

1. **服务无法启动**
   ```bash
   # 检查 Java 版本
   java -version
   
   # 检查端口占用
   netstat -tlnp | grep -E "6878|7180"
   ```

2. **7180/load/initial 接口断线**
   - 查看 `TROUBLESHOOTING.md` 获取详细调试步骤
   - 检查数据库连接: `mysql -h 202.189.7.196 -u root -p`
   - 重启服务: `bash stop-all.sh && bash start-all.sh`

3. **查看详细日志**
   ```bash
   cd petrel/logs
   find . -name "*.log" -mmin -5 -exec tail -50 {} +
   ```

## 监控和维护

### 持续监控接口
```bash
watch -n 5 'curl -s http://localhost:7180/load/initial | head -20'
```

### 定期检查服务
```bash
# 添加到 crontab 每5分钟检查一次
*/5 * * * * cd /path/to/dafuhaozui/petrel && bash start.sh status
```

## 文档

- **部署说明**: `DEPLOYMENT.md`
- **故障排查**: `TROUBLESHOOTING.md`
- **本指南**: `QUICKSTART.md`

## 技术支持

如需帮助，请提供：
1. `bash start.sh status` 的输出
2. 最近5分钟的日志文件
3. 错误截图或描述

---
**注意**: 首次启动后，请运行 `bash validate-endpoint.sh` 确保所有接口正常且稳定。
