#!/bin/bash
# Script to kick users off VNC without shutting down services

echo "🚨 Kicking users off VNC desktop..."

# Method 1: Restart web server (disconnects web clients)
echo "📡 Restarting VNC web server..."
pkill -f "vnc_server.js"
sleep 2
nohup node vnc_server.js > vnc_server.out 2>&1 &
echo "✅ VNC web server restarted - web clients disconnected"

# Method 2: Send a message to the desktop (if someone is watching)
if command -v zenity >/dev/null 2>&1; then
    DISPLAY=:1 zenity --info --text="⚠️ Session will be refreshed in 10 seconds\nPlease save your work!" --timeout=10 2>/dev/null &
fi

# Method 3: Lock and unlock the screen (gentle disruption)
if command -v xflock4 >/dev/null 2>&1; then
    echo "🔒 Locking screen briefly..."
    DISPLAY=:1 xflock4 &
    sleep 2
    # Unlock it programmatically if possible
    DISPLAY=:1 pkill -f xflock4 2>/dev/null || true
fi

echo "🎯 User kick completed! Services remain running."
echo "📱 Web interface: http://localhost:8080"