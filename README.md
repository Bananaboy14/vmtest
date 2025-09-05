# 🖥️ Minecraft VNC Desktop - Ultimate Persistent Setup

A robust, self-healing VNC desktop environment with Minecraft Lunar Client, featuring **automatic reconnection, session persistence, and comprehensive monitoring**. This evolved from a simple noVNC setup into an enterprise-grade persistent desktop solution.

## ✨ Key Features

### 🔄 **Ultimate Persistence & Auto-Recovery**
- **999 automatic reconnection attempts** with intelligent exponential backoff
- **Session state preservation** across disconnections and service restarts  
- **Application auto-restart** for critical programs (Minecraft Lunar Client)
- **VNC server self-healing** with automatic recovery on failures
- **Desktop environment monitoring** and restoration
- **Real-time connection uptime tracking** and health monitoring

### 🎮 **Gaming Optimized** 
- Pre-configured **Minecraft Lunar Client** with automatic startup
- Full **XFCE desktop environment** with window management
- **Clipboard synchronization** between host browser and VNC desktop
- **Mobile-responsive interface** with touch controls
- **Performance tuning** for smooth gameplay

### 🌐 **Advanced Web Interface**
- **Professional HTML5 VNC client** with modern UI
- **Visual progress indicators** during connection attempts
- **Connection statistics panel** with uptime and status
- **Progressive reconnection delays** (1s → 30s maximum)
- **Comprehensive status dashboard** with system health monitoring

### 🛠️ **Self-Healing Architecture**
- **Session keeper daemon** monitors all critical services
- **Automatic service restart** on component failures  
- **Health checks** for VNC server, desktop environment, and applications
- **State persistence** preserves running applications across restarts
- **Port conflict resolution** and service recovery mechanisms

## 🚀 Quick Start

### Launch the Persistent Desktop
```bash
# Start the container with all persistence features
docker-compose up -d

# Check comprehensive system status
docker exec minecraft-novnc /usr/local/bin/vnc-status.sh

# Access the ultimate persistent interface
# Open: http://localhost:8080/vnc.html
```

The interface will **automatically connect and maintain the connection indefinitely** with visual feedback and progress tracking.

## 📡 Access Methods & URLs

| Access Method | URL/Command | Features |
|---------------|-------------|----------|
| **🌟 Persistent Web Interface** | `http://localhost:8080/vnc.html` | Auto-reconnection, status tracking, clipboard sync |
| **📊 System Status Dashboard** | `docker exec minecraft-novnc /usr/local/bin/vnc-status.sh` | Complete health report |
| **🔧 Direct VNC Client** | `localhost:5901` | Traditional VNC (no password required) |
| **📋 Session Management** | Container has session-keeper daemon | Automatic service monitoring |

## 🎯 Problem-Solving Features

This setup solves common VNC issues:

### **❌ "Connections keep dropping"** → **✅ 999 auto-reconnection attempts**
### **❌ "Apps close when disconnected"** → **✅ Session state persistence**  
### **❌ "Interface loads forever"** → **✅ Smart timeouts with progress tracking**
### **❌ "Manual restart required"** → **✅ Self-healing service architecture**

## 🖥️ Enhanced System Architecture

### Core Services
- **TigerVNC Server** - Persistent VNC on port 5901 (no password)
- **XFCE Desktop** - Full-featured desktop with window management
- **Node.js WebSocket Proxy** - Enhanced proxy with health monitoring on port 8080  
- **Session Keeper Daemon** - Comprehensive service monitoring and recovery
- **Enhanced noVNC Client** - HTML5 interface with persistence features

### Monitoring & Recovery Systems
- **VNC Health Monitoring** - Ensures server availability and automatic restart
- **Desktop Process Tracking** - Maintains XFCE session integrity
- **Application State Management** - Preserves and restarts critical applications
- **Connection Pool Management** - Handles multiple simultaneous connections
- **Progressive Retry Logic** - Intelligent backoff prevents server overload

## 🔄 Persistence & Recovery Details

### **Connection Persistence**
- **Automatic Reconnection**: Up to 999 attempts with exponential backoff
- **Connection Statistics**: Real-time uptime tracking and health monitoring  
- **Progressive Delays**: Smart retry timing (1s → 2s → 4s → ... → 30s max)
- **Visual Feedback**: Progress bars and status indicators during connection

### **Session State Persistence**  
- **Application Marking**: Running programs marked for auto-restart
- **Window State Saving**: Desktop layout and window positions preserved
- **Service Dependencies**: VNC server and desktop environment auto-recovery
- **State Restoration**: Applications relaunch automatically after service restart

### **Service Self-Healing**
- **Process Monitoring**: All critical services monitored every 15 seconds
- **Automatic Recovery**: Failed services restarted immediately
- **Health Checks**: Port availability and process health verification
- **Dependency Management**: Services started in proper dependency order

## 🛠️ Advanced Management

Performance tuning (for smoothest gameplay)

- Lower the resolution for best FPS:
	- `SCREEN_RES=1280x720` (default) or `SCREEN_RES=1600x900` for a balance of quality and speed.
- Increase VNC cache for noVNC/x11vnc fallback:
	- `N_CACHE_SIZE=200` (default)
- TurboVNC JPEG quality and compression:
	- `TURBOVNC_JPEG_QUALITY=90` (default, max 100)
	- `TURBOVNC_COMPRESSION=0` (default, 0=best quality, 9=smallest bandwidth)

Example for fastest, smoothest experience:

```bash
SCREEN_RES=1280x720 N_CACHE_SIZE=200 TURBOVNC_JPEG_QUALITY=90 TURBOVNC_COMPRESSION=0 docker compose up --build -d
```

In the noVNC web UI:
- Click inside the window to enable pointer lock (mouse capture for Minecraft/Lunar).
- Use Chrome/Chromium for best performance.

If you want to experiment, try lowering `SCREEN_RES` further or increasing `TURBOVNC_JPEG_QUALITY` for sharper visuals.

Change screen resolution

You can control the virtual display size with environment variables. By default the container now uses 1920x1080x24. To override when starting with docker-compose:

```bash
# start with a 1280x720 display
SCREEN_RES=1280x720 SCREEN_DEPTH=24 docker compose up --build -d
```

2. Open your browser to `http://localhost:8080/vnc.html`.

3. If Prism Launcher did not download at build time, copy the AppImage into the running container or into `data/` before starting:

```bash
# download locally and copy into container
wget -O PrismLauncher.AppImage "<url-from-github-release>"
docker cp PrismLauncher.AppImage novnc-ubuntu:/home/developer/PrismLauncher.AppImage
docker exec -it novnc-ubuntu chown developer:developer /home/developer/PrismLauncher.AppImage
```

4. From the noVNC desktop, open a terminal and run:

```bash
./PrismLauncher.AppImage
```

Troubleshooting server connection

- If the Minecraft client inside the container cannot connect to a server running on your host machine, use `host.docker.internal` as the server address (Docker maps this to the host gateway):

```text
server address: host.docker.internal
port: 25565
```

- Quick in-container test (run in a terminal inside the noVNC session):

```bash
# check DNS/resolution
getent hosts host.docker.internal

# test TCP reachability to a Minecraft port on the host
bash -c 'cat < /dev/null > /dev/tcp/host.docker.internal/25565' && echo "ok" || echo "failed"
```

- If you plan to install Lunar Client instead of using Prism, simply copy the Lunar installer or client files into `/home/developer` (or use the noVNC desktop browser to download within the container). The container now extracts AppImages automatically when FUSE is not available.

Use this code to start lunar client (run it in this terminal not the novnc)
docker exec -u developer novnc-ubuntu bash -lc 'export DISPLAY=:1; export XAUTHORITY=/home/developer/.Xauthority; export LD_LIBRARY_PATH=/home/developer/Applications/squashfs-root:$LD_LIBRARY_PATH; export XDG_DATA_DIRS=/home/developer/Applications/squashfs-root/share:$XDG_DATA_DIRS; export LIBGL_ALWAYS_SOFTWARE=1; nohup /home/developer/Applications/squashfs-root/lunarclient --no-sandbox --disable-gpu > /home/developer/lunar_run.log 2>&1 &'

Rolling snapshot helper
-----------------------
If the container may disconnect unexpectedly, a rolling snapshot helper is provided that keeps a short-lived filesystem image of the running container and deletes it after 10 minutes.

Scripts:

- `scripts/rolling_snapshot.sh` — runs continuously, commits the running container to an image, saves a tar, waits 10 minutes, then deletes the image and tar and repeats. Use this if you want a short grace window to recover after an unexpected disconnect.

Run it (example):

```bash
# run in background (nohup) and log to /var/log/rolling_snapshot.log
nohup /workspaces/vmtest/scripts/rolling_snapshot.sh novnc-ubuntu novnc_rolling /var/backups 1 &
```

Notes:

- The helper commits filesystem state only (not in-memory process state). Restoring the image will preserve files and installed apps, but running processes will be restarted from image startup.
- The script may use notable disk space while saving tars; ensure `/var/backups` (or the chosen out_dir) has enough space and clean old backups if necessary.
- For true in-memory checkpoint/restore you'd need CRIU on the host and Docker support; contact me if you want a CRIU plan.

Sharing this repository

1. Push this repo to GitHub (example):

```bash
# create remote
git remote add origin git@github.com:<your-username>/vmtest.git
git push -u origin main
```

2. Your friends can then clone and run:

```bash
git clone https://github.com/<your-username>/vmtest.git
cd vmtest
docker compose up --build -d
open http://localhost:8080/vnc.html
```

Notes and caveats:
- This image runs a headless X server provided by Xvfb. It may not provide full GPU acceleration; performance depends on the host.
- For better OpenGL support, consider mapping the host GPU devices or using a docker image with GPU passthrough.
- The container runs a non-root user `developer`.
# vmtest