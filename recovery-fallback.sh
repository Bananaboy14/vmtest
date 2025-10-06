#!/bin/bash
# 🔧 Fallback and Recovery System for VNC Gaming Setup
# This script handles failures and provides alternative solutions

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Alternative download sources for Lunar Client
LUNAR_CLIENT_MIRRORS=(
    "https://launcherupdates.lunarclientcdn.com/Lunar%20Client-3.2.17.AppImage"
    "https://github.com/LunarClient/Launcher/releases/download/v3.2.17/Lunar-Client-3.2.17.AppImage"
    "https://launcherupdates.lunarclientcdn.com/Lunar%20Client-3.2.16.AppImage"
)

# Function to try multiple download sources
download_with_fallback() {
    local filename="$1"
    local description="$2"
    shift 2
    local urls=("$@")
    
    for url in "${urls[@]}"; do
        log_step "Trying to download $description from: ${url##*/}"
        if wget --timeout=30 --tries=2 -O "$filename" "$url" 2>/dev/null; then
            log_success "$description downloaded successfully"
            return 0
        else
            log_warning "Download failed, trying next source..."
            rm -f "$filename" 2>/dev/null || true
        fi
    done
    
    log_error "All download sources failed for $description"
    return 1
}

# Recovery function for corrupted VNC setup
recover_vnc_setup() {
    log_step "Attempting VNC recovery"
    
    # Kill all VNC processes
    pkill -f vnc 2>/dev/null || true
    pkill -f xfce 2>/dev/null || true
    
    # Clean VNC configuration
    rm -rf ~/.vnc 2>/dev/null || true
    
    # Recreate VNC setup
    log_step "Recreating VNC configuration"
    mkdir -p ~/.vnc
    
    cat > ~/.vnc/xstartup << 'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
startxfce4 &
EOF
    
    chmod +x ~/.vnc/xstartup
    
    # Try to restart VNC
    vncserver :1 -localhost=0 --I-KNOW-THIS-IS-INSECURE -geometry 1920x1080 -depth 24 -SecurityTypes None
    log_success "VNC recovery completed"
}

# Alternative Minecraft setup if Lunar Client fails
setup_alternative_minecraft() {
    log_step "Setting up alternative Minecraft options"
    
    # Try to install Minetest as alternative
    if command -v apt >/dev/null 2>&1; then
        log_step "Installing Minetest as Minecraft alternative"
        sudo apt update && sudo apt install -y minetest
        log_success "Minetest installed as backup"
    fi
    
    # Create web-based Minecraft classic launcher
    cat > minecraft-classic-launcher.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Minecraft Classic Launcher</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            text-align: center; 
            background: #2e2e2e; 
            color: white; 
            padding: 50px; 
        }
        .launcher { 
            background: #444; 
            padding: 30px; 
            border-radius: 10px; 
            max-width: 600px; 
            margin: 0 auto; 
        }
        button { 
            background: #4CAF50; 
            color: white; 
            border: none; 
            padding: 15px 30px; 
            font-size: 16px; 
            border-radius: 5px; 
            cursor: pointer; 
            margin: 10px; 
        }
        button:hover { background: #45a049; }
        iframe { 
            width: 100%; 
            height: 400px; 
            border: none; 
            margin-top: 20px; 
        }
    </style>
</head>
<body>
    <div class="launcher">
        <h1>🎮 Minecraft Gaming Hub</h1>
        <p>Alternative Minecraft experiences when Lunar Client isn't available</p>
        
        <button onclick="loadClassic()">Launch Minecraft Classic</button>
        <button onclick="loadMinetest()">Open Minetest</button>
        <button onclick="loadAlternatives()">Browse Alternatives</button>
        
        <div id="game-area"></div>
    </div>
    
    <script>
        function loadClassic() {
            document.getElementById('game-area').innerHTML = 
                '<iframe src="https://classic.minecraft.net/"></iframe>';
        }
        
        function loadMinetest() {
            alert('Launch Minetest from the desktop or run: minetest');
        }
        
        function loadAlternatives() {
            window.open('downloads/web-games.html', '_blank');
        }
    </script>
</body>
</html>
EOF
    
    log_success "Alternative Minecraft setup created"
}

# Network connectivity test
test_network() {
    log_step "Testing network connectivity"
    
    # Test basic connectivity
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_success "Internet connectivity: OK"
    else
        log_error "No internet connectivity detected"
        return 1
    fi
    
    # Test DNS resolution
    if nslookup github.com >/dev/null 2>&1; then
        log_success "DNS resolution: OK"
    else
        log_warning "DNS resolution issues detected"
    fi
    
    # Test HTTPS connectivity
    if curl -s https://github.com >/dev/null 2>&1; then
        log_success "HTTPS connectivity: OK"
    else
        log_warning "HTTPS connectivity issues detected"
    fi
}

# Port availability check
check_ports() {
    log_step "Checking port availability"
    
    local ports=(5901 8080 25565)
    for port in "${ports[@]}"; do
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            log_warning "Port $port is already in use"
        else
            log_success "Port $port is available"
        fi
    done
}

# System resources check
check_system_resources() {
    log_step "Checking system resources"
    
    # Check available memory
    local available_memory=$(free -m | awk 'NR==2{printf "%.0f", $7}')
    if [ "$available_memory" -gt 1000 ]; then
        log_success "Available memory: ${available_memory}MB (sufficient)"
    else
        log_warning "Available memory: ${available_memory}MB (may be limited for gaming)"
    fi
    
    # Check disk space
    local available_disk=$(df . | awk 'NR==2{printf "%.0f", $4/1024}')
    if [ "$available_disk" -gt 2000 ]; then
        log_success "Available disk space: ${available_disk}MB (sufficient)"
    else
        log_warning "Available disk space: ${available_disk}MB (may be limited)"
    fi
    
    # Check CPU cores
    local cpu_cores=$(nproc)
    log_success "CPU cores available: $cpu_cores"
}

# Main recovery function
main_recovery() {
    echo "🔧 VNC Gaming Setup - Recovery and Fallback System"
    echo "=================================================="
    
    test_network
    check_ports
    check_system_resources
    
    # Ask what to recover
    echo ""
    echo "What would you like to recover/setup?"
    echo "1) VNC Server and Desktop"
    echo "2) Download Lunar Client with fallbacks"
    echo "3) Setup alternative Minecraft options"
    echo "4) Complete system diagnosis"
    echo -n "Enter choice (1-4): "
    
    read -r choice
    case $choice in
        1)
            recover_vnc_setup
            ;;
        2)
            download_with_fallback "Lunar Client-3.2.17.AppImage" "Lunar Client" "${LUNAR_CLIENT_MIRRORS[@]}"
            ;;
        3)
            setup_alternative_minecraft
            ;;
        4)
            log_step "Running complete system diagnosis"
            test_network
            check_ports
            check_system_resources
            
            log_step "Checking running processes"
            ps aux | grep -E "(vnc|xfce|node)" | grep -v grep || log_warning "No VNC processes found"
            
            log_step "Checking installed packages"
            dpkg -l | grep -E "(vnc|xfce)" || log_warning "VNC/XFCE packages not found"
            ;;
        *)
            log_error "Invalid choice"
            ;;
    esac
}

# Run recovery if called directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main_recovery
fi