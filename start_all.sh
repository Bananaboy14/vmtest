#!/usr/bin/env bash
# Single-command startup for the VNC stack used by this workspace
set -euo pipefail
cd "$(dirname "$0")"

LOGDIR="logs"
mkdir -p "$LOGDIR"

echo "🚀 Starting VNC stack (logs -> $LOGDIR)"

# Kill known processes so we get a fresh start
pkill -f "vnc_server.js" 2>/dev/null || true
pkill -f "express_server.js" 2>/dev/null || true
pkill -f "Xtigervnc|vncserver" 2>/dev/null || true
pkill -f "xfce4-session" 2>/dev/null || true
sleep 2

echo "🔧 Starting VNC server :1 (1920x1080)"
# start TigerVNC (or vncserver) on :1 with no security for local dev
vncserver -kill :1 >/dev/null 2>&1 || true
vncserver :1 -localhost=0 --I-KNOW-THIS-IS-INSECURE -geometry 1920x1080 -depth 24 -SecurityTypes None >> "$LOGDIR/vncserver.log" 2>&1 &
VNC_PID=$!
echo "   PID=$VNC_PID"
sleep 2

echo "🖼️  Starting XFCE session on :1"
DISPLAY=:1 nohup xfce4-session >> "$LOGDIR/xfce.log" 2>&1 &
XFCE_PID=$!
echo "   PID=$XFCE_PID"
sleep 2


PORT=${PORT:-8080}
VNC_PORT=${VNC_PORT:-5901}
echo "🌐 Starting VNC WebSocket server (vnc_server.js) on port ${PORT}"
# Kill any existing vnc_server processes
pkill -f "vnc_server.js" 2>/dev/null || true
sleep 1
nohup node vnc_server.js >> "$LOGDIR/vnc_server.out" 2>&1 &
NODE_PID=$!
echo "   PID=$NODE_PID"
sleep 3

echo "✅ Started components"
echo "   VNC Server PID: $VNC_PID"
echo "   XFCE PID: $XFCE_PID"
echo "   VNC WebSocket Server PID: $NODE_PID"

echo "🔎 Quick status"
sleep 1
pgrep -fl Xtigervnc || true
pgrep -fl xfce4-session || true
pgrep -fl node || true

echo "🌐 Open the UI: http://localhost:${PORT}/"
echo "Logs: $LOGDIR/"

echo "Done."

exit 0
