#!/bin/sh
# 🔍 VNC Gaming Setup - Troubleshoot Script
# This will help identify exactly what's failing

echo "🔍 VNC Gaming Setup Troubleshooter"
echo "=================================="
echo ""

# Check basic system info
echo "📋 System Information:"
echo "OS: $(uname -s)"
echo "Kernel: $(uname -r)"
echo "Shell: $0"
echo "User: $(whoami)"
echo "Home: $HOME"
echo "PWD: $(pwd)"
echo ""

# Check if we're in codespaces
if [ -n "$CODESPACES" ]; then
    echo "✅ GitHub Codespaces detected"
    echo "Codespace name: $CODESPACE_NAME"
else
    echo "ℹ️  Standard Linux environment"
fi
echo ""

# Test basic commands
echo "📋 Command Availability:"
commands="git wget curl sudo apt node npm bash sh"
for cmd in $commands; do
    if command -v $cmd > /dev/null 2>&1; then
        echo "✅ $cmd: Available"
    else
        echo "❌ $cmd: Missing"
    fi
done
echo ""

# Test basic operations
echo "📋 Basic Operations Test:"

# Test sudo
echo -n "Testing sudo access... "
if sudo -n true 2>/dev/null; then
    echo "✅ OK"
else
    echo "❌ Failed - may need password"
fi

# Test apt
echo -n "Testing apt... "
if sudo apt update > /dev/null 2>&1; then
    echo "✅ OK"
else
    echo "❌ Failed"
fi

# Test directory creation
echo -n "Testing directory creation... "
test_dir="/tmp/vnc-test-$$"
if mkdir "$test_dir" 2>/dev/null; then
    echo "✅ OK"
    rmdir "$test_dir"
else
    echo "❌ Failed"
fi

# Test network
echo -n "Testing internet connectivity... "
if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
    echo "✅ OK"
else
    echo "❌ Failed"
fi

echo ""
echo "📋 Now let's try the installation step by step..."
echo ""

# Step 1: Try to install basic packages
echo "Step 1: Installing basic packages"
echo "Command: sudo apt install -y git wget curl"
if sudo apt install -y git wget curl; then
    echo "✅ Step 1 completed successfully"
else
    echo "❌ Step 1 failed - package installation issue"
    exit 1
fi

echo ""
echo "Step 2: Installing VNC and desktop packages"
echo "Command: sudo apt install -y tigervnc-standalone-server xfce4"
if sudo apt install -y tigervnc-standalone-server xfce4; then
    echo "✅ Step 2 completed successfully"
else
    echo "❌ Step 2 failed - VNC/desktop installation issue"
    echo ""
    echo "🔧 Trying alternative VNC installation..."
    if sudo apt install -y tightvncserver xfce4; then
        echo "✅ Alternative VNC server installed"
    else
        echo "❌ Both VNC servers failed to install"
        exit 1
    fi
fi

echo ""
echo "Step 3: Testing VNC server startup"
echo "Command: vncserver :1 -geometry 1024x768"
if vncserver :1 -geometry 1024x768 -SecurityTypes None > /dev/null 2>&1; then
    echo "✅ Step 3 completed - VNC server started"
    vncserver -kill :1 > /dev/null 2>&1 || true
else
    echo "❌ Step 3 failed - VNC server startup issue"
    echo ""
    echo "🔧 VNC server error details:"
    vncserver :1 -geometry 1024x768 -SecurityTypes None || true
fi

echo ""
echo "Step 4: Installing Node.js components"
if [ -f "package.json" ]; then
    echo "Found package.json, installing Node.js dependencies..."
    if npm install; then
        echo "✅ Step 4 completed - Node.js dependencies installed"
    else
        echo "❌ Step 4 failed - npm install issue"
    fi
else
    echo "ℹ️  No package.json found, skipping npm install"
fi

echo ""
echo "🎉 Basic troubleshooting complete!"
echo ""
echo "Next steps:"
echo "1. If all steps passed, try running the main setup:"
echo "   ./setup-fresh-codespace.sh"
echo ""
echo "2. If any step failed, that's the issue to fix first"
echo ""
echo "3. For manual setup, run these working commands:"
echo "   sudo apt update"
echo "   sudo apt install -y tigervnc-standalone-server xfce4 firefox nodejs npm"
echo "   npm install (if package.json exists)"
echo "   vncserver :1 -geometry 1920x1080 -SecurityTypes None"
echo "   node vnc_server.js (if available)"
echo ""