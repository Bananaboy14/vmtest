#!/bin/bash
# Lunar Client High-Performance Launcher
# Optimized for maximum FPS and reduced latency

echo "🌙 Starting Lunar Client with Performance Optimizations"

# Set display
export DISPLAY=:1

# Create optimized Minecraft directory if it doesn't exist
mkdir -p /workspaces/vmtest/data/minecraft/{saves,screenshots,resourcepacks,shaderpacks,mods,logs}

# JVM Flags optimized for Minecraft performance
export JAVA_OPTS="
-Xmx6G 
-Xms3G
-XX:+UseG1GC
-XX:+ParallelRefProcEnabled
-XX:MaxGCPauseMillis=100
-XX:+UnlockExperimentalVMOptions
-XX:+DisableExplicitGC
-XX:+AlwaysPreTouch
-XX:G1NewSizePercent=40
-XX:G1MaxNewSizePercent=50
-XX:G1HeapRegionSize=16M
-XX:G1ReservePercent=15
-XX:G1HeapWastePercent=5
-XX:G1MixedGCCountTarget=4
-XX:InitiatingHeapOccupancyPercent=20
-XX:G1MixedGCLiveThresholdPercent=90
-XX:G1RSetUpdatingPauseTimePercent=5
-XX:SurvivorRatio=32
-XX:+PerfDisableSharedMem
-XX:MaxTenuringThreshold=1
-Dusing.aikars.flags=https://mcflags.emc.gs
-Daikars.new.flags=true
-XX:+UseStringDeduplication
-XX:+UseFastUnorderedTimeStamps
-XX:+UseAES
-XX:+UseAESIntrinsics
-XX:UseAVX=2
-XX:+UseFMA
-XX:+OptimizeStringConcat
-XX:+UseCompressedOops
-XX:+UseCompressedClassPointers
-Dfml.ignorePatchDiscrepancies=true
-Dfml.ignoreInvalidMinecraftCertificates=true
-Duser.language=en
-Duser.country=US
-Djava.net.preferIPv4Stack=true
-Djava.awt.headless=false
"

# Performance environment variables
export MALLOC_ARENA_MAX=4
export LIBGL_ALWAYS_SOFTWARE=1
export __GL_SYNC_TO_VBLANK=0
export __GL_THREADED_OPTIMIZATIONS=1
export RADV_PERFTEST=aco
export mesa_glthread=true

# Create Lunar Client config for optimal settings
mkdir -p ~/.lunarclient/settings
cat > ~/.lunarclient/settings/game_settings.json << 'EOF'
{
  "maxFramerate": 165,
  "enableVsync": false,
  "renderDistance": 8,
  "entityDistanceScaling": 75,
  "particles": "MINIMAL",
  "smoothLighting": "OFF",
  "biomeBlendRadius": 0,
  "maxShadowDistance": 4,
  "entityShadows": false,
  "fullscreen": false,
  "enableFog": false,
  "clouds": "OFF",
  "weather": false,
  "sky": true,
  "stars": false,
  "sun": false,
  "moon": false,
  "vignette": false,
  "bobbing": false,
  "autosave": 20000,
  "simulationDistance": 6,
  "prioritizeChunkUpdates": 0,
  "chunkBuilderThreads": 4,
  "mipmap": 0,
  "anisotropicFiltering": 1,
  "antialiasing": false,
  "guiScale": 2,
  "chatHeightFocused": 1.0,
  "chatHeightUnfocused": 0.44366195797920227,
  "chatOpacity": 1.0,
  "chatWidth": 1.0,
  "hideServerAddress": false,
  "advancedItemTooltips": false,
  "pauseOnLostFocus": false,
  "overrideWidth": 1920,
  "overrideHeight": 1080,
  "heldItemTooltips": true,
  "chatColors": true,
  "chatLinks": true,
  "chatLinksPrompt": true,
  "discreteMouseScroll": false,
  "invertYMouse": false,
  "realmsNotifications": false,
  "reducedDebugInfo": true,
  "showSubtitles": false,
  "directConnect": true,
  "allowServerListing": false,
  "soundCategory_master": 0.5,
  "soundCategory_music": 0.0,
  "soundCategory_record": 1.0,
  "soundCategory_weather": 0.2,
  "soundCategory_block": 0.8,
  "soundCategory_hostile": 0.8,
  "soundCategory_neutral": 0.8,
  "soundCategory_player": 0.8,
  "soundCategory_ambient": 0.4,
  "soundCategory_voice": 1.0
}
EOF

echo "📁 Created optimized game settings"

# Launch Lunar Client with all optimizations
echo "🚀 Launching Lunar Client..."
cd /workspaces/vmtest

# Add additional launch flags for performance
export LUNAR_OPTS="
--no-sandbox
--disable-gpu-sandbox
--disable-software-rasterizer
--enable-features=VaapiVideoDecoder
--use-gl=swiftshader
--disable-background-timer-throttling
--disable-renderer-backgrounding
--disable-backgrounding-occluded-windows
--disable-frame-rate-limit
--max-gum-fps=165
--enable-accelerated-2d-canvas
--enable-gpu-rasterization
--enable-oop-rasterization
--enable-zero-copy
--enable-native-gpu-memory-buffers
--num-raster-threads=4
--enable-checker-imaging
"

# Start Lunar Client
exec ./lunarclient.AppImage $LUNAR_OPTS "$@"