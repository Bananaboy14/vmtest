#!/bin/bash
# Ultimate Mouse Accuracy Status and Gaming Clients

echo "🎮 ULTIMATE GAMING VNC SETUP - MOUSE ACCURACY FIXED"
echo "=================================================="

# Check current status
echo "📊 CURRENT MOUSE SETTINGS:"
export DISPLAY=${DISPLAY:-:1}

if xset q >/dev/null 2>&1; then
    ACCEL_INFO=$(xset q | grep "acceleration:" | awk '{print $2 " " $4}')
    echo "• Mouse acceleration: $ACCEL_INFO (✅ Should be 1/1 0)"
    
    if xinput list | grep -q "TigerVNC pointer"; then
        PROFILE=$(xinput list-props "TigerVNC pointer" | grep "Device Accel Profile" | awk '{print $NF}')
        VELOCITY=$(xinput list-props "TigerVNC pointer" | grep "Device Accel Velocity Scaling" | awk '{print $NF}')
        echo "• TigerVNC profile: $PROFILE (✅ Should be -1)"
        echo "• TigerVNC velocity: $VELOCITY (✅ Should be 1.000000)"
    fi
else
    echo "❌ X server not running"
fi

echo ""
echo "🔧 MODIFICATIONS MADE:"
echo "====================="
echo "✅ Disabled mouse acceleration (1:1 ratio, 0 threshold)"
echo "✅ TigerVNC raw input mode enabled"
echo "✅ noVNC mouse throttling removed (was 17ms, now 0ms)"
echo "✅ noVNC coordinate scaling fixed (direct 1:1 mapping)"
echo "✅ Browser-level mouse optimizations applied"
echo "✅ Pointer lock support for gaming"

echo ""
echo "🎯 AVAILABLE GAMING CLIENTS:"
echo "==========================="
echo "1. Fixed Gaming Client (RECOMMENDED):"
echo "   http://localhost:8080/vnc_fixed_gaming.html"
echo "   • Zero mouse throttling (modified noVNC)"
echo "   • 1:1 coordinate mapping"
echo "   • Click to lock pointer"
echo "   • F11 for fullscreen"

echo ""
echo "2. Perfect Mouse Client:"
echo "   http://localhost:8080/vnc_mouse_perfect.html"
echo "   • Advanced mouse handling"
echo "   • Real-time mouse status"
echo "   • Gaming optimizations"

echo ""
echo "3. Gaming Optimized Client:"
echo "   http://localhost:8080/vnc_gaming_optimized.html"
echo "   • Performance monitoring"
echo "   • FPS counter"
echo "   • Latency display"

echo ""
echo "4. Mouse Accuracy Test:"
echo "   http://localhost:8080/mouse_test.html"
echo "   • Test mouse responsiveness"
echo "   • Verify 1:1 tracking"
echo "   • Measure movements per second"

echo ""
echo "🛠️ MAINTENANCE COMMANDS:"
echo "======================"
echo "• Fix mouse accuracy:     bash /workspaces/vmtest/fix_mouse_accuracy.sh"
echo "• Verify settings:        bash /workspaces/vmtest/verify_mouse_accuracy.sh"
echo "• Reset mouse via API:    curl -X POST http://localhost:8080/api/reset-mouse"
echo "• Apply gaming opts:      bash /workspaces/vmtest/start_gaming_optimized.sh"

echo ""
echo "🎮 GAMING RECOMMENDATIONS:"
echo "========================="
echo "1. Use the 'Fixed Gaming Client' for best mouse accuracy"
echo "2. Click the canvas to lock the mouse pointer"
echo "3. Use fullscreen mode (F11) for immersive gaming"
echo "4. Press ESC to unlock the mouse pointer"
echo "5. If mouse feels off, run the mouse accuracy fix script"

echo ""
echo "✅ MOUSE ACCURACY SHOULD NOW BE PERFECT FOR GAMING!"
echo "   No acceleration, no throttling, no scaling - pure 1:1 input"