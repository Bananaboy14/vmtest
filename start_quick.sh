#!/bin/bash
# Quick startup script for new codespaces
# This will start all necessary services for the VNC desktop

echo "🚀 Quick VNC Desktop Startup"
echo "=========================================="

# Check if services are already running
if pgrep -f "Xtigervnc" > /dev/null; then
    echo "✅ VNC Server already running"
else
    echo "🔧 Starting VNC Server..."
    vncserver :1 -localhost=0 --I-KNOW-THIS-IS-INSECURE -geometry 1920x1080 -depth 24 -SecurityTypes None
    sleep 2
fi

if pgrep -f "xfce4-session" > /dev/null; then
    echo "✅ XFCE Desktop already running"
else
    echo "🖥️  Starting XFCE Desktop..."
    DISPLAY=:1 nohup xfce4-session > /dev/null 2>&1 &
    sleep 3
fi

if pgrep -f "vnc_server.js" > /dev/null; then
    echo "✅ VNC Web Server already running"
else
    echo "🌐 Starting VNC Web Server on port 8080..."
    nohup node vnc_server.js > vnc_server.out 2>&1 &
    sleep 2
fi

# Optional: Start Lunar Client if not running
if pgrep -f "lunarclient" > /dev/null; then
    echo "✅ Lunar Client already running"
else
    echo "🎮 Starting Lunar Client..."
    # Extract AppImage if needed
    if [ ! -f "squashfs-root/AppRun" ]; then
        echo "📦 Extracting Lunar Client AppImage..."
        "/workspaces/vmtest/Lunar Client-3.4.11-ow.AppImage" --appimage-extract
        sleep 2
    fi
    
    # Ensure lunarclient binary exists (fix nested extraction)
    if [ ! -f "squashfs-root/lunarclient" ] && [ -f "squashfs-root/squashfs-root-old/lunarclient" ]; then
        echo "🔧 Fixing nested AppImage extraction..."
        cp squashfs-root/squashfs-root-old/lunarclient squashfs-root/
    fi
    
    # Start Lunar Client
    if [ -f "squashfs-root/AppRun" ]; then
        DISPLAY=:1 nohup ./squashfs-root/AppRun --no-sandbox > /dev/null 2>&1 &
        sleep 2
    else
        echo "❌ Failed to extract Lunar Client AppImage"
    fi
fi

echo ""
echo "✅ Status Check:"
echo "   VNC Server (port 5901): $(pgrep -f Xtigervnc > /dev/null && echo '✅ Running' || echo '❌ Not running')"
echo "   XFCE Desktop: $(pgrep -f xfce4-session > /dev/null && echo '✅ Running' || echo '❌ Not running')"
echo "   Web Server (port 8080): $(pgrep -f vnc_server.js > /dev/null && echo '✅ Running' || echo '❌ Not running')"
echo "   Lunar Client: $(pgrep -f lunarclient > /dev/null && echo '✅ Running' || echo '❌ Not running')"

echo ""
echo "🌐 Access your VNC desktop at:"
echo "   http://localhost:8080/"
echo ""
echo "🎯 The Remote Desktop Pro interface will load automatically!"
echo "   - Press Ctrl+F to enter gaming mode for Minecraft"
echo "   - Use the clipboard panel for copy/paste"
echo "   - Right-click is prevented for clean VNC interaction"