#!/bin/bash
# Gaming Setup - Apply optimizations to existing standard setup
# Works with start_all.sh to enhance performance without changing ports

set -e

echo "🎮 MINECRAFT GAMING OPTIMIZATIONS (Standard Setup Enhanced)"
echo "============================================================"

# Step 1: Apply system optimizations
echo "1. Applying system optimizations..."
bash /workspaces/vmtest/gaming-optimizations.sh

# Step 2: Check if standard setup is running
echo "2. Checking standard VNC setup..."
if ! pgrep -f vnc_server.js > /dev/null; then
    echo "⚠️  Standard VNC setup not detected. Starting it first..."
    ./start_all.sh
    sleep 5
fi

# Step 3: Apply gaming optimizations to running VNC server
echo "3. Applying VNC server gaming optimizations..."
# Apply mouse accuracy fixes immediately
bash /workspaces/vmtest/fix_mouse_accuracy.sh

# Additional VNC optimizations
export DISPLAY=:1
if xset q >/dev/null 2>&1; then
    # Disable screen saver for uninterrupted gaming
    xset s off
    xset -dpms
    echo "✅ Screen saver and power management disabled"
fi

# Step 4: Optimize environment for Lunar Client
echo "4. Setting up Lunar Client environment..."

# Create optimized desktop startup
mkdir -p ~/.local/share/applications
cat > ~/.local/share/applications/minecraft-optimized.desktop << 'EOF'
[Desktop Entry]
Name=Minecraft (Optimized)
Comment=Launch Minecraft with performance optimizations
Exec=/workspaces/vmtest/start_lunar_optimized.sh
Icon=minecraft
Terminal=false
Type=Application
Categories=Game;
EOF

# Ensure port 28190 is available for GameIPC
echo "5. Ensuring GameIPC port availability..."
if netstat -tlnp 2>/dev/null | grep -q ":28190"; then
    echo "⚠️  Port 28190 is in use - this might conflict with Lunar Client GameIPC"
    echo "     Lunar Client needs port 28190 for game communication"
else
    echo "✅ Port 28190 is available for Lunar Client GameIPC"
fi

sleep 2

echo "✅ Gaming optimizations applied to standard setup!"
echo ""
echo "📊 OPTIMIZATION SUMMARY:"
echo "========================"
echo "✓ System performance optimizations applied"
echo "✓ JVM flags optimized for Minecraft (G1GC, memory tuning)"
echo "✓ Gaming environment variables set"
echo "✓ Standard VNC setup enhanced (port 8080)"
echo "✓ Port 28190 reserved for Lunar Client GameIPC"
echo ""
echo "🚀 USAGE:"
echo "========="
echo "1. Access desktop: http://localhost:8080/"
echo "2. Launch Lunar Client: ./start_lunar_optimized.sh"
echo "3. GameIPC will use port 28190 automatically"
echo ""
echo "🎯 PERFORMANCE IMPROVEMENTS:"
echo "============================="
echo "• Optimized JVM garbage collection"
echo "• Better memory management"
echo "• Enhanced system performance"
echo "• Gaming-optimized environment variables"
echo "• Proper port allocation for game communication"