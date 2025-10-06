#!/bin/bash
# 🚀 Complete VNC Gaming Setup - Clone and Install
# This script clones the repository and sets up everything automatically
# 
# Usage: 
#   curl -sSL https://raw.githubusercontent.com/Bananaboy14/vmtest/main/complete-setup.sh | bash
#   OR
#   wget -qO- https://raw.githubusercontent.com/Bananaboy14/vmtest/main/complete-setup.sh | bash

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_header() {
    echo -e "${CYAN}$1${NC}"
}

log_step() {
    echo -e "${BLUE}📋 $1${NC}"
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

log_info() {
    echo -e "${PURPLE}ℹ️  $1${NC}"
}

# Banner
echo ""
log_header "════════════════════════════════════════════════════════════════"
log_header "🎮          VNC Gaming Desktop - Complete Setup                🎮"
log_header "════════════════════════════════════════════════════════════════"
echo ""
log_info "This script will:"
log_info "  • Clone the VNC Gaming repository"
log_info "  • Download all required dependencies (Lunar Client, etc.)"
log_info "  • Install and configure VNC server + desktop environment"
log_info "  • Set up gaming optimizations and controls"
log_info "  • Start all services automatically"
echo ""

# Check if we're in GitHub Codespaces
if [ -n "$CODESPACES" ]; then
    log_success "Detected GitHub Codespaces environment"
    INSTALL_DIR="/workspaces/vmtest-gaming"
else
    log_info "Detected standard Linux environment"
    INSTALL_DIR="$HOME/vmtest-gaming"
fi

# Configuration options
log_step "Configuration Options"
echo "Choose installation options (press Enter for defaults):"

# Ask for Linux games installation
echo -n "Install additional Linux games? (y/N): "
read -r INSTALL_GAMES
if [[ "$INSTALL_GAMES" =~ ^[Yy]$ ]]; then
    export INSTALL_LINUX_GAMES="true"
    log_info "Will install additional Linux games"
else
    export INSTALL_LINUX_GAMES="false"
    log_info "Will skip additional Linux games"
fi

# Ask for Minecraft server setup
echo -n "Set up local Minecraft server? (y/N): "
read -r SETUP_MC_SERVER
if [[ "$SETUP_MC_SERVER" =~ ^[Yy]$ ]]; then
    SETUP_MINECRAFT_SERVER="true"
    log_info "Will set up Minecraft server"
else
    SETUP_MINECRAFT_SERVER="false"
    log_info "Will skip Minecraft server setup"
fi

echo ""
log_step "Starting installation..."

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install basic requirements if needed
log_step "Checking system requirements"
if ! command_exists git; then
    log_step "Installing git"
    sudo apt update && sudo apt install -y git
fi

if ! command_exists wget; then
    log_step "Installing wget"
    sudo apt update && sudo apt install -y wget
fi

if ! command_exists curl; then
    log_step "Installing curl"
    sudo apt update && sudo apt install -y curl
fi

log_success "System requirements verified"

# Clone or update repository
if [ -d "$INSTALL_DIR" ]; then
    log_warning "Directory $INSTALL_DIR already exists"
    echo -n "Remove existing directory and clone fresh? (y/N): "
    read -r REMOVE_EXISTING
    if [[ "$REMOVE_EXISTING" =~ ^[Yy]$ ]]; then
        log_step "Removing existing directory"
        rm -rf "$INSTALL_DIR"
    else
        log_step "Updating existing repository"
        cd "$INSTALL_DIR"
        git pull origin main
        log_success "Repository updated"
    fi
fi

if [ ! -d "$INSTALL_DIR" ]; then
    log_step "Cloning VNC Gaming repository"
    git clone https://github.com/Bananaboy14/vmtest.git "$INSTALL_DIR"
    log_success "Repository cloned to $INSTALL_DIR"
fi

# Change to installation directory
cd "$INSTALL_DIR"

# Make scripts executable
log_step "Setting up script permissions"
chmod +x *.sh 2>/dev/null || true
chmod +x downloads/*.sh 2>/dev/null || true
log_success "Script permissions set"

# Run the complete setup
log_step "Running automated setup process"
echo ""
log_header "════════════════════════════════════════════════════════════════"
log_header "🚀              Beginning Automated Setup                     🚀"
log_header "════════════════════════════════════════════════════════════════"
echo ""

# Execute the main setup script
if [ -f "setup-fresh-codespace.sh" ]; then
    ./setup-fresh-codespace.sh
else
    log_error "Setup script not found!"
    exit 1
fi

# Optional Minecraft server setup
if [ "$SETUP_MINECRAFT_SERVER" = "true" ] && [ -f "downloads/setup-minecraft-server.sh" ]; then
    echo ""
    log_step "Setting up Minecraft server"
    cd downloads
    ./setup-minecraft-server.sh
    cd ..
    log_success "Minecraft server configured"
fi

# Final setup verification
echo ""
log_header "════════════════════════════════════════════════════════════════"
log_header "🎉                Setup Complete!                             🎉"
log_header "════════════════════════════════════════════════════════════════"
echo ""

# Display access information
if [ -n "$CODESPACES" ]; then
    CODESPACE_NAME=$(echo $CODESPACE_NAME)
    log_success "🌐 VNC Access: https://$CODESPACE_NAME-8080.app.github.dev/"
    log_info "Click the link above to access your gaming desktop!"
else
    log_success "🌐 VNC Access: http://localhost:8080/"
    log_info "Open the link above in your web browser"
fi

echo ""
log_info "🎮 Gaming Controls:"
log_info "   • Press Ctrl+F to enable gaming mouse mode"
log_info "   • Press Esc to exit gaming mouse mode"
log_info "   • Right-click context menus are disabled for gaming"
echo ""

log_info "📁 Installation Directory: $INSTALL_DIR"
log_info "📋 Useful Commands:"
log_info "   • cd $INSTALL_DIR"
log_info "   • ./start_all.sh                    - Restart all services"
log_info "   • ./kick_user.sh                   - Disconnect users"
log_info "   • ./downloads/performance-monitor.sh - Check performance"

if [ "$INSTALL_LINUX_GAMES" = "true" ]; then
    log_info "   • ./downloads/install-linux-games.sh - Install more games"
fi

if [ "$SETUP_MINECRAFT_SERVER" = "true" ]; then
    echo ""
    log_info "🏗️  Minecraft Server:"
    log_info "   • cd $INSTALL_DIR/downloads"
    log_info "   • java -Xmx1024M -Xms1024M -jar minecraft_server.*.jar nogui"
fi

echo ""
log_success "🎮 Ready to game in the cloud! 🚀"

# Open browser automatically if possible
if command_exists python3; then
    echo ""
    log_step "Opening web interface..."
    if [ -n "$CODESPACES" ]; then
        log_info "Use the Ports tab in VS Code to access port 8080"
    else
        python3 -c "import webbrowser; webbrowser.open('http://localhost:8080')" 2>/dev/null || true
    fi
fi