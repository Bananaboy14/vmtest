#!/bin/bash
# 🚀 Complete VNC Gaming Setup for GitHub Codespaces
# Run this on a fresh codespace to get everything working

set -e  # Exit on any error

echo "🎮 Starting VNC Gaming Setup for GitHub Codespaces..."
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_step() {
    echo -e "${BLUE}📋 Step: $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Create logs directory
mkdir -p logs

log_step "Updating system packages"
sudo apt update

log_step "Installing VNC server and desktop environment"
sudo apt install -y \
    tigervnc-standalone-server \
    tigervnc-common \
    xfce4 \
    xfce4-goodies \
    xfce4-terminal \
    firefox-esr \
    dbus-x11 \
    x11-xserver-utils \
    x11-utils \
    wget \
    curl \
    unzip \
    htop \
    nano \
    git

log_success "System packages installed"

log_step "Installing Node.js dependencies"
if [ -f "package.json" ]; then
    npm install
    log_success "Node.js dependencies installed"
else
    log_warning "No package.json found, skipping npm install"
fi

log_step "Setting up VNC server configuration"
mkdir -p ~/.vnc

# Create VNC startup script
cat > ~/.vnc/xstartup << 'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
/etc/X11/xinit/xinitrc
[ -x /etc/vnc/xstartup ] && exec /etc/vnc/xstartup
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources
xsetroot -solid grey
# Start XFCE desktop
startxfce4 &
EOF

chmod +x ~/.vnc/xstartup
log_success "VNC configuration created"

log_step "Setting up Lunar Client"
if [ -f "Lunar Client-3.4.11-ow.AppImage" ]; then
    log_step "Extracting Lunar Client AppImage"
    chmod +x "Lunar Client-3.4.11-ow.AppImage"
    if [ ! -d "squashfs-root" ]; then
        ./"Lunar Client-3.4.11-ow.AppImage" --appimage-extract
        log_success "Lunar Client extracted"
    else
        log_success "Lunar Client already extracted"
    fi
else
    log_warning "Lunar Client AppImage not found - you may need to download it"
fi

log_step "Creating desktop shortcuts"
mkdir -p ~/.local/share/applications

# Create Lunar Client desktop entry
if [ -d "squashfs-root" ]; then
    cat > ~/.local/share/applications/lunarclient.desktop << EOF
[Desktop Entry]
Name=Lunar Client
Comment=Minecraft PvP Client
Exec=/workspaces/vmtest/squashfs-root/lunarclient
Icon=/workspaces/vmtest/squashfs-root/lunarclient.png
Terminal=false
Type=Application
Categories=Game;
EOF
    log_success "Lunar Client desktop shortcut created"
fi

# Create Firefox desktop entry for easy web access
cat > ~/.local/share/applications/firefox-local.desktop << 'EOF'
[Desktop Entry]
Name=Firefox (Local)
Comment=Open local VNC interface
Exec=firefox-esr http://localhost:8080
Icon=firefox-esr
Terminal=false
Type=Application
Categories=Network;WebBrowser;
EOF

log_step "Setting up gaming optimizations"
# Create gaming optimization script
cat > gaming-optimize.sh << 'EOF'
#!/bin/bash
# Gaming optimizations for VNC
echo "🎮 Applying gaming optimizations..."

# Disable compositing for better performance
DISPLAY=:1 xfconf-query -c xfwm4 -p /general/use_compositing -s false 2>/dev/null || true

# Set window manager settings for gaming
DISPLAY=:1 xfconf-query -c xfwm4 -p /general/sync_to_vblank -s false 2>/dev/null || true
DISPLAY=:1 xfconf-query -c xfwm4 -p /general/urgent_blink -s false 2>/dev/null || true

echo "✅ Gaming optimizations applied"
EOF

chmod +x gaming-optimize.sh
log_success "Gaming optimization script created"

log_step "Testing VNC server startup"
# Kill any existing VNC processes
vncserver -kill :1 2>/dev/null || true
pkill -f "vnc_server.js" 2>/dev/null || true
pkill -f "xfce4-session" 2>/dev/null || true
sleep 2

# Start VNC server
log_step "Starting VNC server on display :1"
vncserver :1 -localhost=0 --I-KNOW-THIS-IS-INSECURE -geometry 1920x1080 -depth 24 -SecurityTypes None
log_success "VNC server started on port 5901"

# Start XFCE session
log_step "Starting XFCE desktop session"
DISPLAY=:1 nohup xfce4-session > logs/xfce.log 2>&1 &
sleep 3
log_success "XFCE desktop session started"

# Start Node.js VNC proxy
if [ -f "vnc_server.js" ]; then
    log_step "Starting VNC web proxy server"
    nohup node vnc_server.js > logs/vnc_server.out 2>&1 &
    sleep 2
    log_success "VNC web proxy started on port 8080"
else
    log_error "vnc_server.js not found - web interface may not work"
fi

# Apply gaming optimizations
log_step "Applying gaming optimizations"
./gaming-optimize.sh

log_step "Verifying setup"
echo "Checking running processes..."
pgrep -fl Xtigervnc && log_success "VNC server running" || log_error "VNC server not running"
pgrep -fl xfce4-session && log_success "XFCE session running" || log_error "XFCE session not running"
pgrep -fl node && log_success "Node.js proxy running" || log_error "Node.js proxy not running"

# Check if port 8080 is listening
if netstat -tlnp | grep -q :8080; then
    log_success "Web interface available on port 8080"
else
    log_warning "Port 8080 not listening - web interface may not be available"
fi

echo ""
echo "🎉 SETUP COMPLETE! 🎉"
echo "===================="
echo ""
echo "🌐 VNC Web Interface: http://localhost:8080/"
echo "🎮 Gaming Controls:"
echo "   • Press Ctrl+F to enable gaming mouse mode"
echo "   • Press Esc to exit gaming mouse mode"
echo "   • Right-click context menus are disabled for gaming"
echo ""
echo "🚀 Lunar Client should be available on the desktop"
echo "📱 Firefox shortcut available for easy web access"
echo ""
echo "📋 Useful commands:"
echo "   • ./start_all.sh          - Restart all services"
echo "   • ./kick_user.sh          - Disconnect users without stopping services"
echo "   • ./gaming-optimize.sh    - Apply gaming optimizations"
echo ""
echo "🔧 Troubleshooting:"
echo "   • Check logs/ directory for error messages"
echo "   • Run 'ps aux | grep vnc' to check VNC processes"
echo "   • Run 'netstat -tlnp | grep 8080' to check web server"
echo ""
log_success "Ready to game! 🎮"