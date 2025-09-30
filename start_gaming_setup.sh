#!/bin/bash

echo "🚀 Starting VNC Gaming Setup with your preferred port configuration..."
echo "📊 Port Layout:"
echo "   🖥️  VNC Server:      8080"
echo "   🌐 Python Server:   5901 (serving web files)"
echo "   🔗 WebSocket Proxy: 3000 (bridges client to VNC)"

# Kill any existing processes
echo "🧹 Cleaning up existing processes..."
sudo pkill -f "Xtigervnc" 2>/dev/null || true
pkill -f "python3 -m http.server" 2>/dev/null || true
pkill -f "websocket_proxy.js" 2>/dev/null || true
pkill -f "startxfce4" 2>/dev/null || true
sudo rm -f /tmp/.X*-lock /tmp/.X11-unix/X* 2>/dev/null || true

sleep 2

# Start VNC Server on port 8080
echo "🖥️  Starting VNC Server on port 8080..."
Xtigervnc :2 -SecurityTypes None -BlacklistThreshold 0 -BlacklistTimeout 0 -geometry 1920x1080 -depth 24 -rfbport 8080 -localhost=0 > /tmp/vnc.log 2>&1 &
sleep 3

# Start Desktop Environment
echo "🖱️  Starting XFCE Desktop Environment..."
export DISPLAY=:2
export XDG_RUNTIME_DIR=/tmp/runtime-vscode
mkdir -p $XDG_RUNTIME_DIR
dbus-launch --exit-with-session startxfce4 > /tmp/xfce.log 2>&1 &
sleep 3

# Start Lunar Client
echo "🌙 Starting Lunar Client..."
DISPLAY=:2 nohup /workspaces/vmtest/lunarclient.AppImage --no-sandbox > /tmp/lunar.log 2>&1 &
sleep 2

# Start Python HTTP Server on port 5901
echo "🐍 Starting Python HTTP Server on port 5901..."
cd /workspaces/vmtest
python3 -m http.server 5901 > /tmp/http_server.log 2>&1 &
sleep 1

# Start WebSocket Proxy on port 3000
echo "🔗 Starting WebSocket Proxy on port 3000..."
node /workspaces/vmtest/websocket_proxy.js > /tmp/websocket_proxy.log 2>&1 &
sleep 2

echo "✅ All services started!"
echo ""
echo "🌐 Access your VNC client at:"
echo "   http://localhost:5901/vnc.html"
echo ""
echo "📊 Service Status:"
echo "   VNC Server (8080):      $(pgrep -f 'Xtigervnc.*8080' > /dev/null && echo '✅ Running' || echo '❌ Stopped')"
echo "   Python Server (5901):   $(pgrep -f 'python3.*5901' > /dev/null && echo '✅ Running' || echo '❌ Stopped')"
echo "   WebSocket Proxy (3000): $(pgrep -f 'websocket_proxy.js' > /dev/null && echo '✅ Running' || echo '❌ Stopped')"
echo "   Desktop Environment:    $(pgrep -f 'startxfce4' > /dev/null && echo '✅ Running' || echo '❌ Stopped')"
echo "   Lunar Client:           $(pgrep -f 'lunarclient.AppImage' > /dev/null && echo '✅ Running' || echo '❌ Stopped')"
echo ""
echo "🎮 Ready for gaming! Your mouse will be locked when you click in the VNC window."
