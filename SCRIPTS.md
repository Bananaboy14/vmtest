# Enhanced VNC System - Key Scripts Documentation

This document describes the key scripts that make the persistent VNC system work.

## 📋 Core System Scripts

### `/usr/local/bin/session-keeper.sh`
**Purpose**: Main persistence daemon that monitors and maintains all VNC services

**Key Functions**:
- Monitors VNC server health and restarts if needed
- Maintains XFCE desktop environment 
- Tracks application state (especially Minecraft Lunar Client)
- Ensures websocket proxy availability
- Logs all activities for debugging

**Auto-restart Logic**:
```bash
# Applications marked for restart are saved in /tmp/lunar_should_run
# Window positions saved in /tmp/window_list.txt
# Service runs every 15 seconds checking all components
```

### `/usr/local/bin/vnc-status.sh`
**Purpose**: Comprehensive system status reporting

**Provides**:
- VNC server status and process details
- Websocket proxy health and port information
- Desktop environment component status
- Application status (Lunar Client, file manager, terminal)
- Session management daemon status
- System resource usage (CPU, memory, uptime)
- Connection URLs and access information

### `/opt/noVNC/vnc.html`
**Purpose**: Ultimate persistent VNC web interface

**Enhanced Features**:
- 999 automatic reconnection attempts
- Progressive backoff delays (1s → 30s max)
- Real-time connection uptime display
- Visual progress indicators
- Clipboard synchronization controls
- Connection statistics and health monitoring
- Professional UI with status panels

## 🔧 Service Management

### Starting/Stopping Services
```bash
# Check all services status
docker exec minecraft-novnc /usr/local/bin/vnc-status.sh

# Restart session keeper
docker exec minecraft-novnc pkill -f session-keeper
docker exec minecraft-novnc nohup /usr/local/bin/session-keeper.sh > /dev/null 2>&1 &

# Manual VNC server restart
docker exec minecraft-novnc vncserver -kill :1
docker exec minecraft-novnc vncserver :1 -geometry 1920x1080 -SecurityTypes None

# Launch Lunar Client manually
docker exec minecraft-novnc bash -c 'export DISPLAY=:1 && cd /opt/lunarclient && ./lunarclient --no-sandbox &'
```

### Log Monitoring
```bash
# Session keeper logs
docker exec minecraft-novnc tail -f /var/log/session-keeper.log

# VNC server logs  
docker exec minecraft-novnc tail -f ~/.vnc/*.log

# Websocket proxy logs
docker exec minecraft-novnc tail -f /var/log/enhanced_proxy.log
```

## 🎯 How Persistence Works

### Connection Level
1. **Web Interface**: Monitors WebSocket connection health
2. **Retry Logic**: Attempts reconnection up to 999 times
3. **Backoff Strategy**: Progressive delays prevent server overload
4. **Status Tracking**: Real-time uptime and connection statistics

### Service Level  
1. **Session Keeper**: Monitors all critical processes every 15s
2. **Health Checks**: Verifies port availability and process status
3. **Auto Recovery**: Restarts failed services immediately
4. **State Preservation**: Maintains application and window state

### Application Level
1. **State Marking**: Running apps marked in `/tmp/` files
2. **Auto Restart**: Critical applications restarted automatically
3. **Window Management**: Desktop layout preserved across restarts
4. **Dependency Handling**: Services started in proper order

## 🚨 Troubleshooting Guide

### Connection Issues
```bash
# 1. Check VNC server
docker exec minecraft-novnc pgrep -af Xtigervnc
docker exec minecraft-novnc netstat -tlpn | grep 5901

# 2. Check websocket proxy
docker exec minecraft-novnc netstat -tlpn | grep 8080
docker exec minecraft-novnc ps aux | grep node

# 3. Test web interface
curl -I http://localhost:8080/vnc.html
```

### Service Recovery
```bash
# Force restart all services
docker restart minecraft-novnc

# Or manually restart components
docker exec minecraft-novnc /usr/local/bin/session-keeper.sh &
```

### Performance Issues
```bash
# Check resource usage
docker exec minecraft-novnc /usr/local/bin/vnc-status.sh | grep -A5 "System Resources"

# Reduce VNC quality for better performance
docker exec minecraft-novnc vncserver -kill :1
docker exec minecraft-novnc vncserver :1 -geometry 1280x720 -depth 16 -SecurityTypes None
```

## 📊 Monitoring & Metrics

The system provides comprehensive monitoring:
- **Connection uptime** - Time since last successful connection
- **Reconnection attempts** - Number of retry attempts
- **Service health** - Status of all critical components  
- **Resource usage** - CPU, memory, and system utilization
- **Application state** - Which programs are running and marked for restart

All metrics are available through the status dashboard and web interface.
