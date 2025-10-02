# 🎮 VNC Gaming Setup for GitHub Codespaces

A complete VNC desktop environment with gaming optimizations, featuring Lunar Client for Minecraft PvP.

## 🚀 Quick Start (Fresh Codespace)

On a brand new GitHub Codespace, just run:

```bash
./setup-fresh-codespace.sh
```

This will:
- ✅ Install VNC server and XFCE desktop
- ✅ Set up Node.js dependencies
- ✅ Extract Lunar Client
- ✅ Create desktop shortcuts
- ✅ Apply gaming optimizations
- ✅ Start all services
- ✅ Verify everything is working

Then access your desktop at: **http://localhost:8080**

## 🎯 Manual Commands

If you prefer to start services manually:

```bash
# Start everything
./start_all.sh

# Or start components individually:
vncserver :1 -localhost=0 --I-KNOW-THIS-IS-INSECURE -geometry 1920x1080 -depth 24 -SecurityTypes None
DISPLAY=:1 nohup xfce4-session > logs/xfce.log 2>&1 &
nohup node vnc_server.js > logs/vnc_server.out 2>&1 &
```

## 🎮 Gaming Features

### Gaming Mouse Controls
- **Ctrl+F** - Enable gaming mouse mode (pointer lock)
- **Esc** - Exit gaming mouse mode
- **Automatic coordinate mapping** for pixel-perfect accuracy
- **Context menu prevention** for right-click gaming

### Optimizations
- Disabled desktop compositing for better performance
- Optimized window manager settings
- 1920x1080 resolution for consistent gaming experience

## 📱 Available Applications

- **Lunar Client** - Minecraft PvP client (desktop shortcut)
- **Firefox** - Web browser with local VNC shortcut
- **Terminal** - Full XFCE terminal access
- **File Manager** - Thunar file manager

## 🔧 Maintenance Commands

```bash
# Restart all services
./start_all.sh

# Kick users without stopping services
./kick_user.sh

# Apply gaming optimizations
./gaming-optimize.sh

# Check service status
ps aux | grep -E "(vnc|node|xfce)"
netstat -tlnp | grep :8080
```

## 📋 Troubleshooting

### Common Issues

1. **"RFB library not loaded"** - The setup script fixes module loading issues
2. **"Connection failed"** - Check if all services are running with the status commands above
3. **Mouse accuracy issues** - Gaming mouse mode (Ctrl+F) provides pixel-perfect accuracy
4. **Performance issues** - Run `./gaming-optimize.sh` to apply performance tweaks

### Log Files
- `logs/vnc_server.out` - Node.js proxy server logs
- `logs/xfce.log` - Desktop session logs  
- `logs/vncserver.log` - VNC server logs

### Port Information
- **5901** - VNC server (internal)
- **8080** - Web interface (public)

## 🎨 Customization

The setup creates a full XFCE desktop environment. You can:
- Install additional software with `sudo apt install`
- Customize XFCE themes and settings
- Add more desktop shortcuts in `~/.local/share/applications/`
- Modify gaming optimizations in `gaming-optimize.sh`

## 📦 What's Included

- **TigerVNC Server** - High-performance VNC server
- **XFCE Desktop** - Lightweight, gaming-friendly desktop environment  
- **Node.js WebSocket Proxy** - Bridges browser to VNC with gaming mouse support
- **Lunar Client** - Pre-configured Minecraft PvP client
- **Gaming Optimizations** - Mouse accuracy, performance tweaks, context menu handling

---

**Ready to game!** 🎮 Access your desktop at http://localhost:8080 and press Ctrl+F for gaming mouse mode.