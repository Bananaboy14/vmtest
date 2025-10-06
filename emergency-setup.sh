#!/bin/sh
# 🚀 Emergency VNC Setup - Bare Minimum
# Gets VNC working with minimal dependencies

echo "🚨 Emergency VNC Setup - Bare Minimum"
echo "===================================="
echo ""

# Basic error handling
set -e

# Update system
echo "📦 Updating system packages..."
sudo apt update

# Install absolute minimum
echo "📦 Installing VNC and desktop..."
sudo apt install -y tigervnc-standalone-server xfce4-session xfce4-panel xfce4-desktop firefox-esr

# Create VNC config
echo "🔧 Setting up VNC..."
mkdir -p ~/.vnc

# Simple VNC startup script
cat > ~/.vnc/xstartup << 'EOF'
#!/bin/sh
startxfce4 &
EOF

chmod +x ~/.vnc/xstartup

# Start VNC server
echo "🚀 Starting VNC server..."
vncserver :1 -geometry 1920x1080 -SecurityTypes None -localhost=0

echo ""
echo "✅ Basic VNC setup complete!"
echo ""
echo "🌐 Access methods:"
echo "1. VNC Viewer: localhost:5901"
echo "2. If you have a VNC web client, connect to port 5901"
echo ""
echo "🎮 To add Lunar Client manually:"
echo "1. Download from: https://www.lunarclient.com/"
echo "2. Make executable: chmod +x Lunar*.AppImage"
echo "3. Run: ./Lunar*.AppImage"
echo ""
echo "🔧 To stop VNC server:"
echo "   vncserver -kill :1"
echo ""
echo "📋 VNC server is running on display :1 (port 5901)"
echo ""

# Check if port is listening
if netstat -tlnp 2>/dev/null | grep -q :5901; then
    echo "✅ VNC server is listening on port 5901"
else
    echo "⚠️  VNC server may not be listening properly"
fi

echo ""
echo "🎉 Emergency setup complete! VNC should be working now."