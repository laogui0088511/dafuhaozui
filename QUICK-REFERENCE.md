# Quick Reference: Lobby Service Standalone Mode

## Updated Requirement
**Lobby service should NOT register with Nacos service registry.**

## Solution Implemented
Lobby service now runs in **standalone mode** with Nacos discovery disabled.

## Quick Start

### Option 1: Start All Services (Recommended)
```bash
cd petrel
./start-all-improved.sh [external-ip]

# Lobby will automatically start in standalone mode
```

### Option 2: Start Lobby Only
```bash
cd petrel
./start-lobby-standalone.sh [external-ip] [port]

# Default usage (127.0.0.1:9879)
./start-lobby-standalone.sh
```

### Option 3: Use Original Scripts
```bash
# Windows
cd petrel
4-.start-lobby.bat

# Linux
cd petrel
./start.sh start lobby
```

## Architecture

```
Prerequisites (Required)
├── MySQL :3306
└── Redis :6379

Lobby Service (Standalone)
└── petrel-game-lobby :9879
    ├── Does NOT register to Nacos
    ├── Direct access via IP
    └── Independent operation

Other Services (Optional)
├── Nacos :6878
├── Register :7180
├── User
└── Game
```

## Key Configuration

All lobby startup commands now include:
```bash
--spring.cloud.nacos.discovery.enabled=false
```

**Modified Files:**
- `petrel/4-.start-lobby.bat`
- `petrel/start.sh`
- `petrel/start-all-improved.sh`

**New File:**
- `petrel/start-lobby-standalone.sh`

## Verification

```bash
# 1. Check process
ps aux | grep petrel-game-lobby

# 2. Check port
netstat -tlnp | grep 9879

# 3. Health check
curl http://127.0.0.1:9879/actuator/health

# 4. View logs
tail -f petrel/logs/petrel-game-lobby/info_*.log
```

## Important Notes

### ✅ Expected Behavior
- Lobby service will NOT appear in Nacos service list (this is correct)
- Lobby can start without Nacos running
- Direct access via `http://127.0.0.1:9879`

### ⚠️ Considerations

**Service Communication:**
Other services must use fixed IP to call Lobby:
```java
// DON'T use service name
// String url = "http://petrel-game-lobby/api/xxx";

// DO use fixed IP
String url = "http://127.0.0.1:9879/api/xxx";
```

**Configuration example:**
```yaml
service:
  lobby:
    url: http://127.0.0.1:9879
```

**Load Balancing:**
- Multiple instances require external load balancer (e.g., Nginx)
- Cannot use Ribbon/Spring Cloud load balancing

## Benefits

✅ **Independent Operation** - Runs without Nacos  
✅ **Simple Deployment** - One less dependency  
✅ **Higher Availability** - Nacos failures don't affect Lobby  
✅ **Direct Access** - Via IP:9879  
✅ **Faster Startup** - No service registration delay  

## Troubleshooting

### Issue: Lobby fails to start
**Check:**
```bash
# MySQL running?
netstat -tlnp | grep 3306

# Redis running?
netstat -tlnp | grep 6379

# Port 9879 available?
netstat -tlnp | grep 9879

# Check logs
tail -100 petrel/logs/petrel-game-lobby/error_*.log
```

### Issue: Other services cannot reach Lobby
**Solution:**
1. Verify Lobby is running: `ps aux | grep petrel-game-lobby`
2. Check network: `telnet 127.0.0.1 9879`
3. Verify other services use correct IP configuration
4. Check firewall rules

### NOT Issues
❌ Lobby not in Nacos service list - **This is expected**  
❌ Nacos connection warnings in logs - **Can be ignored**  
❌ Cannot find service by name - **Use IP instead**

## Documentation

Detailed information in Chinese:
- **[Lobby独立部署方案.md](./Lobby独立部署方案.md)** - Comprehensive standalone deployment guide
- **[解决方案总结.md](./解决方案总结.md)** - Solution summary
- **[部署指南.md](./部署指南.md)** - Complete deployment guide

## Summary

**Core Change:** Added `--spring.cloud.nacos.discovery.enabled=false` parameter

**Result:**
- ✅ Lobby runs standalone
- ✅ No Nacos dependency
- ✅ Direct access via IP:9879
- ✅ Simpler deployment

**No Need For:**
- ❌ Modifying JAR files
- ❌ Recompiling code
- ❌ Starting Nacos
- ❌ Service registration

---
**Status**: ✅ Implemented | ✅ Scripts Updated | ✅ Documentation Complete
