#!/bin/bash
# 🚀 Ultra-Compatible VNC Gaming Setup
# This version works with any bash version and avoids all advanced features

set -e

echo "🎮 VNC Gaming Desktop - Ultra Compatible Setup"
echo "=============================================="
echo ""

# Detect environment
if test -n "$CODESPACES"; then
    echo "✅ Detected GitHub Codespaces"
    INSTALL_DIR="/workspaces/vmtest-gaming"
else
    echo "✅ Detected standard Linux environment" 
    INSTALL_DIR="$HOME/vmtest-gaming"
fi

# Simple configuration (no advanced bash features)
echo "Configuration options:"
echo ""

echo -n "Install additional Linux games? (y/N): "
read INSTALL_GAMES
case "$INSTALL_GAMES" in
    y|Y|yes|YES)
        INSTALL_LINUX_GAMES="true"
        echo "✅ Will install additional Linux games"
        ;;
    *)
        INSTALL_LINUX_GAMES="false"
        echo "✅ Will skip additional Linux games"
        ;;
esac

echo -n "Set up local Minecraft server? (y/N): "
read SETUP_MC_SERVER  
case "$SETUP_MC_SERVER" in
    y|Y|yes|YES)
        SETUP_MINECRAFT_SERVER="true"
        echo "✅ Will set up Minecraft server"
        ;;
    *)
        SETUP_MINECRAFT_SERVER="false"
        echo "✅ Will skip Minecraft server setup"
        ;;
esac

echo ""
echo "📥 Starting installation..."

# Install requirements
echo "📦 Installing basic requirements..."
sudo apt update > /dev/null 2>&1 || echo "Note: Could not update package list"
sudo apt install -y git wget curl > /dev/null 2>&1 || echo "Note: Some packages may already be installed"

# Handle existing directory  
if test -d "$INSTALL_DIR"; then
    echo "⚠️  Directory $INSTALL_DIR already exists"
    echo -n "Remove and reinstall? (y/N): "
    read REMOVE_EXISTING
    case "$REMOVE_EXISTING" in
        y|Y|yes|YES)
            echo "🗑️  Removing existing directory..."
            rm -rf "$INSTALL_DIR"
            ;;
        *)
            echo "📂 Using existing directory..."
            cd "$INSTALL_DIR"
            git pull origin main > /dev/null 2>&1 || echo "Note: Could not update repository"
            ;;
    esac
fi

# Clone if needed
if test ! -d "$INSTALL_DIR"; then
    echo "📥 Cloning repository..."
    git clone https://github.com/Bananaboy14/vmtest.git "$INSTALL_DIR" > /dev/null 2>&1
    echo "✅ Repository cloned"
fi

# Enter directory
cd "$INSTALL_DIR"

# Set permissions
chmod +x *.sh 2>/dev/null || echo "Note: Setting script permissions"

# Export variables for setup script
export INSTALL_LINUX_GAMES
export SETUP_MINECRAFT_SERVER

# Run main setup
echo ""
echo "🚀 Running main setup process..."
echo "================================"
echo ""

if test -f "setup-fresh-codespace.sh"; then
    ./setup-fresh-codespace.sh
else
    echo "❌ Setup script not found!"
    exit 1
fi

# Success message
echo ""
echo "🎉 Installation Complete!"
echo "========================"
echo ""

if test -n "$CODESPACES"; then
    echo "🌐 Access your gaming desktop:"
    echo "   → Go to the 'Ports' tab in VS Code"
    echo "   → Click on port 8080 to open your desktop"
else
    echo "🌐 Access your gaming desktop at:"
    echo "   → http://localhost:8080"
fi

echo ""
echo "🎮 Gaming Controls:"
echo "   • Press Ctrl+F for gaming mouse mode"
echo "   • Press Esc to exit gaming mode"
echo ""
echo "📁 Installation location: $INSTALL_DIR"
echo ""
echo "🎮 Ready to game in the cloud! 🚀"