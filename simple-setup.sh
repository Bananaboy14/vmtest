#!/bin/bash
# 🚀 Simple VNC Gaming Setup - Compatible Version
# This is a simplified version that avoids advanced bash features

set -e  # Exit on any error

# Simple colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo_step() {
    echo -e "${BLUE}📋 $1${NC}"
}

echo_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

echo_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo_error() {
    echo -e "${RED}❌ $1${NC}"
}

echo ""
echo "🎮 VNC Gaming Desktop - Simple Setup"
echo "===================================="
echo ""

# Check if we're in GitHub Codespaces
if [ -n "$CODESPACES" ]; then
    echo_success "Detected GitHub Codespaces environment"
    INSTALL_DIR="/workspaces/vmtest-gaming"
else
    echo_success "Detected standard Linux environment"
    INSTALL_DIR="$HOME/vmtest-gaming"
fi

# Simple yes/no function
ask_yes_no() {
    echo -n "$1 (y/N): "
    read -r answer
    case "$answer" in
        [Yy]|[Yy][Ee][Ss])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Configuration
if ask_yes_no "Install additional Linux games?"; then
    INSTALL_LINUX_GAMES="true"
    echo_success "Will install additional Linux games"
else
    INSTALL_LINUX_GAMES="false"
    echo_success "Will skip additional Linux games"
fi

if ask_yes_no "Set up local Minecraft server?"; then
    SETUP_MINECRAFT_SERVER="true"
    echo_success "Will set up Minecraft server"
else
    SETUP_MINECRAFT_SERVER="false"
    echo_success "Will skip Minecraft server setup"
fi

echo ""
echo_step "Starting installation..."

# Install basic tools
echo_step "Installing basic requirements"
sudo apt update >/dev/null 2>&1 || true
sudo apt install -y git wget curl >/dev/null 2>&1 || true

# Handle existing directory
if [ -d "$INSTALL_DIR" ]; then
    echo_warning "Directory $INSTALL_DIR already exists"
    if ask_yes_no "Remove existing directory and clone fresh?"; then
        echo_step "Removing existing directory"
        rm -rf "$INSTALL_DIR"
    else
        echo_step "Updating existing repository"
        cd "$INSTALL_DIR"
        git pull origin main >/dev/null 2>&1 || true
        echo_success "Repository updated"
    fi
fi

# Clone repository if needed
if [ ! -d "$INSTALL_DIR" ]; then
    echo_step "Cloning VNC Gaming repository"
    git clone https://github.com/Bananaboy14/vmtest.git "$INSTALL_DIR" >/dev/null 2>&1
    echo_success "Repository cloned"
fi

# Change to directory
cd "$INSTALL_DIR"

# Make scripts executable
chmod +x *.sh 2>/dev/null || true

# Export configuration
export INSTALL_LINUX_GAMES
export SETUP_MINECRAFT_SERVER

# Run setup
echo ""
echo_step "Running main setup script..."
if [ -f "setup-fresh-codespace.sh" ]; then
    ./setup-fresh-codespace.sh
else
    echo_error "Setup script not found!"
    exit 1
fi

# Final message
echo ""
echo "🎉 Setup Complete! 🎉"
echo "===================="
echo ""

if [ -n "$CODESPACES" ]; then
    echo_success "🌐 Access your gaming desktop through the Ports tab (port 8080)"
else
    echo_success "🌐 Access your gaming desktop at: http://localhost:8080"
fi

echo ""
echo_success "🎮 Gaming Controls:"
echo "   • Press Ctrl+F for gaming mouse mode"
echo "   • Press Esc to exit gaming mode"
echo ""
echo_success "📁 Installation directory: $INSTALL_DIR"
echo_success "🎮 Ready to game in the cloud!"