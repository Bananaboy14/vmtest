#!/bin/bash
# Gaming system optimizations script

echo "🎮 Applying gaming optimizations..."

# CPU performance optimizations
echo "Setting CPU governor to performance mode..."
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null || echo "CPU governor setting not available"

# Memory optimizations
echo "Optimizing memory settings..."
echo 1 | sudo tee /proc/sys/vm/drop_caches 2>/dev/null || true
echo 10 | sudo tee /proc/sys/vm/swappiness 2>/dev/null || true

# Network optimizations for lower latency
echo "Optimizing network settings..."
echo 1 | sudo tee /proc/sys/net/ipv4/tcp_low_latency 2>/dev/null || true

# X11 optimizations
echo "Setting X11 environment variables for gaming..."
export XSECURELOCK_BLANK_TIMEOUT=0
export XSECURELOCK_BLANK_DPMS_STATE=off
export __GL_SYNC_TO_VBLANK=0
export __GL_SYNC_DISPLAY_DEVICE=""
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_OVERRIDE_CPU_CAPS="sse4.1"

# Mouse accuracy fix for gaming
echo "Fixing mouse accuracy for gaming..."
if [ -f "/workspaces/vmtest/fix_mouse_accuracy.sh" ]; then
    bash /workspaces/vmtest/fix_mouse_accuracy.sh
else
    echo "⚠️ Mouse accuracy fix script not found, applying manual fixes..."
    export DISPLAY=${DISPLAY:-:1}
    if xset q >/dev/null 2>&1; then
        xset m 1/1 0
        if xinput list | grep -q "TigerVNC pointer"; then
            xinput set-prop "TigerVNC pointer" "Device Accel Profile" -1
            xinput set-prop "TigerVNC pointer" "Device Accel Velocity Scaling" 1
            echo "✅ Mouse acceleration disabled for TigerVNC"
        fi
    fi
fi

# Java/JVM optimizations for Minecraft
echo "Setting JVM optimizations..."
export _JAVA_OPTIONS="-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1"

echo "✅ Gaming optimizations applied!"
echo "📊 System Info:"
echo "  CPU Cores: $(nproc)"
echo "  Memory: $(free -h | grep '^Mem:' | awk '{print $2}')"
echo "  Java Version: $(java -version 2>&1 | head -1)"

# Create desktop startup script for Lunar Client
cat > /tmp/start_lunar.sh << 'EOF'
#!/bin/bash
export DISPLAY=:1

# Apply JVM optimizations specifically for Minecraft
export JAVA_OPTS="-Xmx4G -Xms2G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1"

# Start Lunar Client with optimizations
cd /workspaces/vmtest
./lunarclient.AppImage --no-sandbox --disable-gpu-sandbox --disable-software-rasterizer --enable-features=VaapiVideoDecoder --use-gl=swiftshader
EOF

chmod +x /tmp/start_lunar.sh
echo "🚀 Lunar Client startup script created at /tmp/start_lunar.sh"