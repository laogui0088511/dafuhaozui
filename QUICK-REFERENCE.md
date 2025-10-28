# Quick Reference: Lobby Service Registration Issue

## Problem Summary
The `4-.start-lobby` module (petrel-game-lobby) fails to register with the `2-.start-register` service registry (petrel-kernel-register).

## Root Cause
**Nacos service registry server is not running before application services are started.**

The system has Nacos installed at `/nacos/` but the startup scripts (`start.sh`, `*.bat` files) do not include steps to start Nacos before launching the application services.

## Architecture Dependencies
```
External Services (Must be running first)
    ↓
Nacos Server :6878 (Service Registry)
    ↓
Register Service :7180 (petrel-kernel-register)
    ↓
Core Services (User, Game)
    ↓
Game Services (Lobby :9879, Slots, etc.)
```

## Quick Fix

### Option 1: Use Improved Script (Recommended)
```bash
cd /path/to/petrel
./start-all-improved.sh [external-ip]
```

### Option 2: Manual Steps
```bash
# 1. Start Nacos
cd /path/to/nacos/bin
./startup.sh -m standalone
sleep 60

# 2. Verify Nacos
curl http://127.0.0.1:6878/nacos/

# 3. Start services in order
cd /path/to/petrel
./start.sh start register  # Wait 30s
./start.sh start user      # Wait 15s
./start.sh start game      # Wait 15s
./start.sh start lobby     # Wait 15s
```

## Verification Checklist
- [ ] Nacos web UI accessible at http://127.0.0.1:6878/nacos/
- [ ] `petrel-kernel-register` shown in Nacos service list
- [ ] `petrel-game-lobby` shown in Nacos service list
- [ ] Port 6878 (Nacos) listening
- [ ] Port 7180 (Register) listening
- [ ] Port 9879 (Lobby) listening
- [ ] No errors in logs

## Key Configuration Points
All services are configured to connect to Nacos at `127.0.0.1:6878` (correct).

### Register Service
- Port: 7180
- Nacos: 127.0.0.1:6878
- Config: application-prod.yml (in JAR)

### Lobby Service
- Port: 9879
- Nacos: 127.0.0.1:6878
- Config: application-prod.yml (in JAR)

## Common Issues

### Issue: Service starts but exits immediately
**Cause**: Database or Redis not available  
**Fix**: Ensure MySQL (3306) and Redis (6379) are running

### Issue: Service doesn't register with Nacos
**Cause**: Nacos not running or wrong address  
**Fix**: Start Nacos first, verify with `ps aux | grep nacos`

### Issue: "Connection refused" to Nacos
**Cause**: Nacos port 6878 not listening  
**Fix**: Check `netstat -tlnp | grep 6878`, restart Nacos if needed

## Files Added/Modified
- ✅ `分析报告-lobby模块注册问题.md` - Detailed analysis (Chinese)
- ✅ `部署指南.md` - Deployment guide (Chinese)
- ✅ `petrel/start-all-improved.sh` - Improved startup script
- ✅ `petrel/stop-all-improved.sh` - Graceful shutdown script

## Next Steps
1. Review the detailed analysis in `分析报告-lobby模块注册问题.md`
2. Follow deployment guide in `部署指南.md`
3. Use improved scripts for reliable service management
4. Verify all services register successfully in Nacos console

---
**Status**: ✅ Analysis Complete | Scripts Ready | Documentation Provided
