#!/bin/bash
# Fix Mouse Accuracy for Gaming - Disable all mouse acceleration and smoothing

echo "🖱️ Fixing mouse accuracy for gaming..."

# Set DISPLAY if not already set
export DISPLAY=${DISPLAY:-:1}

# Check if X server is running
if ! xset q >/dev/null 2>&1; then
    echo "❌ X server not running on $DISPLAY"
    exit 1
fi

echo "✅ Applying mouse accuracy fixes to $DISPLAY"

# 1. Disable mouse acceleration completely
echo "  • Disabling mouse acceleration..."
xset m 1/1 0

# 2. Configure TigerVNC pointer for raw input
echo "  • Configuring TigerVNC pointer..."
if xinput list | grep -q "TigerVNC pointer"; then
    # Disable acceleration profile completely (-1 = none)
    xinput set-prop "TigerVNC pointer" "Device Accel Profile" -1
    
    # Set all deceleration/acceleration values to 1 (no change)
    xinput set-prop "TigerVNC pointer" "Device Accel Constant Deceleration" 1
    xinput set-prop "TigerVNC pointer" "Device Accel Adaptive Deceleration" 1
    xinput set-prop "TigerVNC pointer" "Device Accel Velocity Scaling" 1
    
    echo "  • TigerVNC pointer configured for raw input"
else
    echo "  ⚠️ TigerVNC pointer not found"
fi

# 3. Verify settings
echo "  • Verifying mouse settings..."
ACCEL_INFO=$(xset q | grep "acceleration:" | awk '{print $2 " " $4}')
echo "    Mouse acceleration: $ACCEL_INFO"

if xinput list | grep -q "TigerVNC pointer"; then
    PROFILE=$(xinput list-props "TigerVNC pointer" | grep "Device Accel Profile" | awk '{print $NF}')
    VELOCITY=$(xinput list-props "TigerVNC pointer" | grep "Device Accel Velocity Scaling" | awk '{print $NF}')
    echo "    TigerVNC profile: $PROFILE (should be -1)"
    echo "    TigerVNC velocity: $VELOCITY (should be 1.000000)"
fi

echo "✅ Mouse accuracy fixed for gaming!"
echo ""
echo "📊 CURRENT SETTINGS:"
echo "• Mouse acceleration: DISABLED (1:1 ratio, 0 threshold)"
echo "• TigerVNC acceleration profile: DISABLED"
echo "• Mouse velocity scaling: 1:1 (raw input)"
echo "• All deceleration: DISABLED"
echo ""
echo "🎮 Your mouse should now have perfect 1:1 accuracy for gaming!"