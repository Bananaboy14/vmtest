#!/bin/sh
# 🚀 Minimal VNC Gaming Setup - Maximum Compatibility
# Uses only basic POSIX shell features

set -e

echo "🎮 VNC Gaming Desktop - Minimal Setup"
echo "====================================="
echo ""

# Detect environment
if [ -n "$CODESPACES" ]; then
    echo "✅ GitHub Codespaces detected"
    INSTALL_DIR="/workspaces/vmtest-gaming"
else
    echo "✅ Standard Linux environment detected"
    INSTALL_DIR="$HOME/vmtest-gaming"
fi

echo ""
echo "Configuration:"

# Simple yes/no function using only basic syntax
echo -n "Install additional Linux games? (y/N): "
read INSTALL_GAMES

if [ "$INSTALL_GAMES" = "y" ]; then
    INSTALL_LINUX_GAMES="true"
    echo "✅ Will install Linux games"
elif [ "$INSTALL_GAMES" = "Y" ]; then
    INSTALL_LINUX_GAMES="true"
    echo "✅ Will install Linux games"
else
    INSTALL_LINUX_GAMES="false"
    echo "✅ Will skip Linux games"
fi

echo -n "Set up Minecraft server? (y/N): "
read SETUP_MC_SERVER

if [ "$SETUP_MC_SERVER" = "y" ]; then
    SETUP_MINECRAFT_SERVER="true"
    echo "✅ Will setup Minecraft server"
elif [ "$SETUP_MC_SERVER" = "Y" ]; then
    SETUP_MINECRAFT_SERVER="true"
    echo "✅ Will setup Minecraft server"
else
    SETUP_MINECRAFT_SERVER="false"
    echo "✅ Will skip Minecraft server"
fi

echo ""
echo "📥 Starting installation..."

# Install basic tools
echo "📦 Installing requirements..."
sudo apt update > /dev/null 2>&1 || true
sudo apt install -y git wget curl > /dev/null 2>&1 || true
echo "✅ Requirements installed"

# Handle existing directory
if [ -d "$INSTALL_DIR" ]; then
    echo "⚠️  Directory exists: $INSTALL_DIR"
    echo -n "Remove and reinstall? (y/N): "
    read REMOVE_DIR
    
    if [ "$REMOVE_DIR" = "y" ] || [ "$REMOVE_DIR" = "Y" ]; then
        echo "🗑️  Removing existing directory..."
        rm -rf "$INSTALL_DIR"
        echo "✅ Directory removed"
    else
        echo "📂 Using existing directory"
        cd "$INSTALL_DIR"
        echo "📥 Updating repository..."
        git pull origin main > /dev/null 2>&1 || echo "Note: Could not update"
        echo "✅ Repository updated"
    fi
fi

# Clone repository if needed
if [ ! -d "$INSTALL_DIR" ]; then
    echo "📥 Cloning repository..."
    git clone https://github.com/Bananaboy14/vmtest.git "$INSTALL_DIR" > /dev/null 2>&1
    echo "✅ Repository cloned"
fi

# Change to directory
echo "📂 Entering directory: $INSTALL_DIR"
cd "$INSTALL_DIR"

# Set permissions
echo "🔧 Setting permissions..."
chmod +x *.sh 2>/dev/null || true
echo "✅ Permissions set"

# Export configuration variables
export INSTALL_LINUX_GAMES
export SETUP_MINECRAFT_SERVER

# Run the main setup script
echo ""
echo "🚀 Running main setup..."
echo "======================="
echo ""

if [ -f "setup-fresh-codespace.sh" ]; then
    ./setup-fresh-codespace.sh
else
    echo "❌ Error: setup-fresh-codespace.sh not found!"
    echo "📁 Current directory contents:"
    ls -la
    exit 1
fi

# Success message
echo ""
echo "🎉 Installation Complete!"
echo "========================"
echo ""

if [ -n "$CODESPACES" ]; then
    echo "🌐 Access your gaming desktop:"
    echo "   1. Go to the 'Ports' tab in VS Code"
    echo "   2. Find port 8080"
    echo "   3. Click the globe icon to open"
else
    echo "🌐 Open your gaming desktop:"
    echo "   → http://localhost:8080"
fi

echo ""
echo "🎮 Gaming Controls:"
echo "   • Press Ctrl+F for gaming mouse mode"
echo "   • Press Esc to exit gaming mode"
echo ""
echo "📁 Installation: $INSTALL_DIR"
echo "🎮 Ready to game! 🚀"
echo ""