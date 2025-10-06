#!/bin/bash
# Debug script to identify the shell compatibility issue

echo "🔍 Shell Debug Information"
echo "========================="
echo "Current shell: $0"
echo "Shell version: $BASH_VERSION"
echo "Shell path: $(which bash)"
echo "Default shell: $SHELL"
echo ""

# Test the problematic line
echo "Testing line 77 syntax..."
INSTALL_GAMES="n"

echo "Testing method 1 (original - may fail):"
if command -v bash >/dev/null 2>&1; then
    if bash -c 'if [[ "n" =~ ^[Yy]$ ]]; then echo "match"; else echo "no match"; fi' 2>/dev/null; then
        echo "✅ Advanced bash syntax works"
    else
        echo "❌ Advanced bash syntax fails - this is the problem!"
    fi
fi

echo "Testing method 2 (fixed version):"
if [ "$INSTALL_GAMES" = "y" ] || [ "$INSTALL_GAMES" = "Y" ]; then
    echo "match"
else
    echo "✅ Simple syntax works - no match (expected)"
fi

echo "Testing method 3 (case statement):"
case "$INSTALL_GAMES" in
    y|Y|yes|YES)
        echo "match"
        ;;
    *)
        echo "✅ Case statement works - no match (expected)"
        ;;
esac

echo ""
echo "🔧 Recommendation:"
echo "Use the ultra-compatible-setup.sh script:"
echo "curl -sSL https://raw.githubusercontent.com/Bananaboy14/vmtest/main/ultra-compatible-setup.sh | bash"