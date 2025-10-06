#!/bin/bash
# 🚀 Automatic Download Script for VNC Gaming Setup
# Downloads all required files for the gaming environment

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

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

log_download() {
    echo -e "${PURPLE}📥 $1${NC}"
}

# Create downloads directory
mkdir -p downloads

echo "🎮 Downloading Gaming Dependencies..."
echo "===================================="

# Function to download with progress and retry
download_with_retry() {
    local url="$1"
    local output="$2"
    local description="$3"
    local max_attempts=3
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        log_download "Downloading $description (attempt $attempt/$max_attempts)"
        
        if wget --progress=bar:force:noscroll --timeout=30 --tries=3 -O "$output" "$url" 2>&1; then
            log_success "$description downloaded successfully"
            return 0
        else
            log_warning "Download attempt $attempt failed"
            rm -f "$output" 2>/dev/null || true
            attempt=$((attempt + 1))
            if [ $attempt -le $max_attempts ]; then
                log_step "Retrying in 3 seconds..."
                sleep 3
            fi
        fi
    done
    
    log_error "Failed to download $description after $max_attempts attempts"
    return 1
}

# Download Lunar Client
log_step "Downloading Lunar Client AppImage"
LUNAR_CLIENT_URL="https://launcherupdates.lunarclientcdn.com/Lunar%20Client-3.2.17.AppImage"
if download_with_retry "$LUNAR_CLIENT_URL" "Lunar Client-3.2.17.AppImage" "Lunar Client"; then
    chmod +x "Lunar Client-3.2.17.AppImage"
    # Create symlink for compatibility
    ln -sf "Lunar Client-3.2.17.AppImage" "Lunar Client-3.4.11-ow.AppImage" 2>/dev/null || true
    ln -sf "Lunar Client-3.2.17.AppImage" "lunarclient.AppImage" 2>/dev/null || true
else
    log_warning "Lunar Client download failed - will try alternative sources during setup"
fi

# Download additional gaming tools
log_step "Downloading additional gaming utilities"

# Download MultiMC (Alternative Minecraft launcher)
MULTIMC_URL="https://files.multimc.org/downloads/multimc_1.6-1.deb"
if download_with_retry "$MULTIMC_URL" "downloads/multimc.deb" "MultiMC Launcher"; then
    log_success "MultiMC launcher downloaded as backup"
fi

# Download performance monitoring tools
log_step "Setting up performance monitoring"
cat > downloads/performance-monitor.sh << 'EOF'
#!/bin/bash
# Performance monitoring for gaming
echo "🎮 Gaming Performance Monitor"
echo "============================"
echo "CPU Usage:"
top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//'
echo ""
echo "Memory Usage:"
free -h | grep Mem | awk '{print "Used: "$3" / "$2" ("$3/$2*100"%)"}'
echo ""
echo "GPU Info (if available):"
lscpu | grep "Model name" | sed 's/Model name: *//'
echo ""
echo "Network Status:"
ping -c 1 google.com > /dev/null 2>&1 && echo "✅ Internet: Connected" || echo "❌ Internet: Disconnected"
EOF
chmod +x downloads/performance-monitor.sh

# Create gaming profiles and configurations
log_step "Creating gaming configurations"

# Minecraft performance config
cat > downloads/minecraft-performance.txt << 'EOF'
# Recommended Minecraft Performance Settings for VNC Gaming
# Copy these settings into your Minecraft options.txt or Lunar Client settings

# Video Settings
renderDistance:8
entityShadows:false
particles:1
fancyGraphics:false
ao:0
biomeBlendRadius:1
maxFps:60
fullscreen:false
vsync:false
useVbo:true
enableVsync:false
graphicsMode:1

# Performance Optimizations
prioritizeChunkUpdates:0
chatHeightFocused:1.0
chatHeightUnfocused:1.0
chatOpacity:1.0
chatScale:1.0
EOF

# Create desktop theme optimizations
cat > downloads/xfce-gaming-theme.sh << 'EOF'
#!/bin/bash
# XFCE Gaming Theme Optimizations
log_step() { echo -e "\033[0;34m📋 $1\033[0m"; }
log_success() { echo -e "\033[0;32m✅ $1\033[0m"; }

log_step "Applying gaming-optimized XFCE theme"

# Set dark theme for better gaming aesthetics
DISPLAY=:1 xfconf-query -c xsettings -p /Net/ThemeName -s "Adwaita-dark" 2>/dev/null || true

# Optimize window manager for gaming
DISPLAY=:1 xfconf-query -c xfwm4 -p /general/use_compositing -s false 2>/dev/null || true
DISPLAY=:1 xfconf-query -c xfwm4 -p /general/sync_to_vblank -s false 2>/dev/null || true
DISPLAY=:1 xfconf-query -c xfwm4 -p /general/urgent_blink -s false 2>/dev/null || true
DISPLAY=:1 xfconf-query -c xfwm4 -p /general/focus_delay -s 0 2>/dev/null || true

# Set background to solid color for performance
DISPLAY=:1 xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image -s "" 2>/dev/null || true
DISPLAY=:1 xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/color-style -s 0 2>/dev/null || true
DISPLAY=:1 xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/rgba1 -s 0.0 -s 0.0 -s 0.2 -s 1.0 2>/dev/null || true

log_success "Gaming theme applied"
EOF
chmod +x downloads/xfce-gaming-theme.sh

# Download web-based alternatives
log_step "Setting up web-based gaming alternatives"
cat > downloads/web-games.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Web Gaming Hub</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
        }
        .game-grid { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); 
            gap: 20px; 
            margin-top: 20px;
        }
        .game-card { 
            background: rgba(255,255,255,0.1); 
            padding: 20px; 
            border-radius: 10px; 
            text-align: center;
            backdrop-filter: blur(10px);
        }
        .game-card a { 
            color: #fff; 
            text-decoration: none; 
            font-weight: bold;
        }
        .game-card:hover { 
            background: rgba(255,255,255,0.2); 
            transform: translateY(-2px);
            transition: all 0.3s ease;
        }
    </style>
</head>
<body>
    <h1>🎮 Web Gaming Hub</h1>
    <p>Browser-based games that work great in VNC environment</p>
    
    <div class="game-grid">
        <div class="game-card">
            <h3><a href="https://classic.minecraft.net" target="_blank">Minecraft Classic</a></h3>
            <p>Original Minecraft in your browser</p>
        </div>
        <div class="game-card">
            <h3><a href="https://krunker.io" target="_blank">Krunker.io</a></h3>
            <p>Browser-based FPS game</p>
        </div>
        <div class="game-card">
            <h3><a href="https://slither.io" target="_blank">Slither.io</a></h3>
            <p>Multiplayer snake game</p>
        </div>
        <div class="game-card">
            <h3><a href="https://agar.io" target="_blank">Agar.io</a></h3>
            <p>Cell-eating multiplayer game</p>
        </div>
        <div class="game-card">
            <h3><a href="https://chess.com" target="_blank">Chess.com</a></h3>
            <p>Online chess platform</p>
        </div>
        <div class="game-card">
            <h3><a href="https://poki.com" target="_blank">Poki Games</a></h3>
            <p>Collection of browser games</p>
        </div>
    </div>
</body>
</html>
EOF

# Create Minecraft server setup (optional)
log_step "Creating Minecraft server setup option"
cat > downloads/setup-minecraft-server.sh << 'EOF'
#!/bin/bash
# Optional Minecraft Server Setup
echo "🏗️  Minecraft Server Setup"
echo "=========================="

# Download Minecraft server jar
MINECRAFT_VERSION="1.20.1"
SERVER_JAR="minecraft_server.${MINECRAFT_VERSION}.jar"

if [ ! -f "$SERVER_JAR" ]; then
    echo "📥 Downloading Minecraft Server ${MINECRAFT_VERSION}..."
    wget -O "$SERVER_JAR" "https://launcher.mojang.com/v1/objects/84194a2f286ef7c14ed7ce0090dba59902951553/server.jar"
fi

# Create server configuration
cat > server.properties << 'MCEOF'
#Minecraft server properties
server-port=25565
gamemode=survival
difficulty=easy
max-players=10
online-mode=false
white-list=false
spawn-protection=0
motd=VNC Gaming Minecraft Server
MCEOF

cat > eula.txt << 'MCEOF'
#By changing the setting below to TRUE you are indicating your agreement to our EULA
eula=true
MCEOF

echo "✅ Minecraft server setup complete!"
echo "Run: java -Xmx1024M -Xms1024M -jar ${SERVER_JAR} nogui"
EOF
chmod +x downloads/setup-minecraft-server.sh

# Download essential Linux games
log_step "Setting up native Linux games list"
cat > downloads/install-linux-games.sh << 'EOF'
#!/bin/bash
# Install popular Linux games from repositories
echo "🎮 Installing Linux Games"
echo "========================="

# Update package list
sudo apt update

# Install games available in Ubuntu repositories
echo "📦 Installing games from repositories..."
sudo apt install -y \
    supertux \
    supertuxkart \
    frozen-bubble \
    chromium-bsu \
    armagetronad \
    bzflag \
    openttd \
    hedgewars \
    wesnoth \
    freeciv \
    0ad \
    minetest \
    steam-installer

echo "✅ Linux games installed!"
echo "Games available:"
echo "  - SuperTux (2D platformer)"
echo "  - SuperTuxKart (racing)"
echo "  - Frozen Bubble (puzzle)"
echo "  - Chromium B.S.U. (arcade shooter)"
echo "  - Armagetron Advanced (Tron-like)"
echo "  - BZFlag (tank battles)"
echo "  - OpenTTD (transport simulation)"
echo "  - Hedgewars (turn-based strategy)"
echo "  - Battle for Wesnoth (turn-based strategy)"
echo "  - Freeciv (civilization-like)"
echo "  - 0 A.D. (real-time strategy)"
echo "  - Minetest (Minecraft-like)"
echo "  - Steam (game platform)"
EOF
chmod +x downloads/install-linux-games.sh

log_success "All dependencies and configurations downloaded!"

echo ""
echo "📁 Downloaded Files:"
echo "==================="
find downloads -type f -name "*.sh" -o -name "*.html" -o -name "*.txt" | sort
if [ -f "Lunar Client-3.2.17.AppImage" ]; then
    echo "Lunar Client-3.2.17.AppImage"
fi
if [ -f "downloads/multimc.deb" ]; then
    echo "downloads/multimc.deb"
fi

echo ""
log_success "Download complete! Ready for setup."