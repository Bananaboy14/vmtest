# 🚀 VNC Gaming Desktop - Installation Guide

## Quick Install (Recommended)

**Copy and paste this single command:**

```bash
curl -sSL https://raw.githubusercontent.com/Bananaboy14/vmtest/main/minimal-setup.sh | bash
```

**If you get syntax errors, try alternatives:**
```bash
# Ultra-compatible version
curl -sSL https://raw.githubusercontent.com/Bananaboy14/vmtest/main/ultra-compatible-setup.sh | bash

# Manual installation
git clone https://github.com/Bananaboy14/vmtest.git && cd vmtest && ./setup-fresh-codespace.sh
```

That's it! The script will:
1. Clone the repository
2. Download Lunar Client and all dependencies
3. Install VNC server and XFCE desktop
4. Configure gaming optimizations
5. Start all services
6. Open your gaming desktop at `http://localhost:8080`

## What You Get

- 🎮 **Complete Minecraft Setup** - Lunar Client ready to play
- 🖥️ **Full Linux Desktop** - XFCE with file manager, terminal, Firefox
- 🎯 **Gaming Mouse Controls** - Press `Ctrl+F` for gaming mode
- 📋 **Clipboard Sync** - Copy/paste between browser and desktop
- 🔧 **Auto-Recovery** - Self-healing system if connections fail

## System Requirements

- GitHub Codespaces (or Ubuntu 24.04+)
- Modern web browser
- Internet connection for downloads
- Mouse recommended for gaming

## Troubleshooting

If the installation fails:
```bash
# Try the recovery script
./recovery-fallback.sh

# Or re-download everything
./download-dependencies.sh
```

## Manual Installation

If you prefer to install manually:

```bash
# 1. Clone repository
git clone https://github.com/Bananaboy14/vmtest.git
cd vmtest

# 2. Run setup
./setup-fresh-codespace.sh

# 3. Access desktop
# Open: http://localhost:8080
```

## Gaming Controls

| Action | Control | Purpose |
|--------|---------|---------|
| **Enter Gaming Mode** | `Ctrl+F` | Fullscreen + mouse lock |
| **Exit Gaming Mode** | `ESC` | Return to desktop |
| **Clipboard** | Click 📋 | Copy/paste text |

## Advanced Options

During installation, you can choose:
- Install additional Linux games (y/N)
- Set up local Minecraft server (y/N)

## Support

If you encounter issues:
1. Check the full README.md for detailed documentation
2. Run `./recovery-fallback.sh` for automated recovery
3. Report issues on GitHub

---

**Ready to game in the cloud? Run the install command above! 🎮**