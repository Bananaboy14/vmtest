#!/bin/bash
# Complete VNC Desktop Startup Script
# This script starts all processes needed for the VNC desktop environment

echo "🚀 Starting Complete VNC Desktop Environment..."

# Kill any existing processes to start fresh
echo "🔄 Cleaning up existing processes..."
pkill -f "Xtigervnc" 2>/dev/null || true
pkill -f "vncserver" 2>/dev/null || true
pkill -f "node.*index.js" 2>/dev/null || true
pkill -f "xfce4-session" 2>/dev/null || true
pkill -f "lunarclient" 2>/dev/null || true
sleep 3

# Ensure VNC config is set up correctly
echo "⚙️  Setting up VNC configuration..."
mkdir -p ~/.vnc
cat > ~/.vnc/tigervnc.conf << EOF
\$SecurityTypes = "None";
\$localhost = "no";
\$geometry = "1920x1080";
\$depth = 24;
EOF

# Start VNC Server
echo "🖥️  Starting VNC Server (1920x1080, 24-bit)..."
vncserver :1 -localhost=0 --I-KNOW-THIS-IS-INSECURE -geometry 1920x1080 -depth 24 -SecurityTypes None
sleep 2

# Set up desktop background
echo "🎨 Setting up desktop background..."
DISPLAY=:1 xsetroot -solid "#000000"
sleep 1

# Start XFCE Desktop Environment
echo "🖱️  Starting XFCE Desktop Environment..."
DISPLAY=:1 nohup xfce4-session > /dev/null 2>&1 &
sleep 3

# Start WebSocket Proxy
echo "🌐 Starting WebSocket Proxy on port 8081..."
cd /workspaces/vmtest/novnc_proxy
nohup node index.js > proxy.log 2>&1 &
PROXY_PID=$!
sleep 3

# Verify WebSocket proxy is running
if ! netstat -tlnp | grep :8081 > /dev/null; then
    echo "⚠️  WebSocket proxy didn't start on 8081, trying 8080..."
    pkill -f "node.*index.js" 2>/dev/null || true
    sleep 2
    NOVNC_PORT=8080 nohup node index.js > proxy.log 2>&1 &
    sleep 3
fi

# Check which port the proxy is using
if netstat -tlnp | grep :8081 > /dev/null; then
    PROXY_PORT=8081
elif netstat -tlnp | grep :8080 > /dev/null; then
    PROXY_PORT=8080
else
    echo "❌ Failed to start WebSocket proxy!"
    exit 1
fi

# Start Lunar Client
echo "🎮 Starting Lunar Client..."
cd /workspaces/vmtest
if [ -f "squashfs-root/AppRun" ]; then
    DISPLAY=:1 nohup ./squashfs-root/AppRun > /dev/null 2>&1 &
else
    echo "📦 Extracting Lunar Client..."
    "./Lunar Client-3.4.11-ow.AppImage" --appimage-extract
    DISPLAY=:1 nohup ./squashfs-root/AppRun > /dev/null 2>&1 &
fi
sleep 2

# Display status
echo ""
echo "✅ VNC Desktop Environment Started Successfully!"
echo "📊 Process Status:"
echo "   VNC Server: $(pgrep -f Xtigervnc >/dev/null && echo "✅ Running on :1 (port 5901)" || echo "❌ Not running")"
echo "   XFCE Desktop: $(pgrep -f xfce4-session >/dev/null && echo "✅ Running" || echo "❌ Not running")"
echo "   WebSocket Proxy: $(netstat -tlnp | grep :$PROXY_PORT >/dev/null && echo "✅ Running on port $PROXY_PORT" || echo "❌ Not running")"
echo "   Lunar Client: $(pgrep -f lunarclient >/dev/null && echo "✅ Running" || echo "❌ Not running")"
echo ""
echo "🌐 Access URLs:"
echo "   🎯 Professional Glass UI: http://localhost:$PROXY_PORT/vnc_glass.html"
echo "   📱 Alternative Client: http://localhost:$PROXY_PORT/vnc_pro.html"
echo "   🔧 Health Check: http://localhost:$PROXY_PORT/health"
echo ""
echo "🎯 Instructions:"
echo "   1. Open the VNC Client URL in your browser"
echo "   2. The connection will start automatically"
echo "   3. Click the desktop to lock mouse for gaming"
echo "   4. Press ESC to unlock mouse"
echo ""
echo "🔥 Everything is ready! Enjoy your VNC desktop with Lunar Client!"
