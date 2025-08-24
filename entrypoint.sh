#!/usr/bin/env bash
set -euo pipefail

USER_HOME=/home/developer
export DISPLAY=:1

# Configuration with sensible defaults
NOVNC_LISTEN_PORT=${NOVNC_LISTEN_PORT:-8080}
VNC_HOST=${VNC_HOST:-localhost}
VNC_PORT=${VNC_PORT:-5900}
NOVNC_TLS=${NOVNC_TLS:-0}

# Start dbus
service dbus start || true

# Start Xvfb
Xvfb ${DISPLAY} -screen 0 1280x720x24 &

sleep 1

# Start a simple X session with xfce
su - developer -c "mkdir -p $USER_HOME/.config; export DISPLAY=${DISPLAY}; xfce4-session &" || true

sleep 2

# Start x11vnc to expose X server
nohup x11vnc -display ${DISPLAY} -nopw -forever -shared -rfbport ${VNC_PORT} >/var/log/x11vnc.log 2>&1 &

# Prepare TLS if requested
if [ "${NOVNC_TLS}" = "1" ]; then
  mkdir -p /etc/novnc/certs
  if [ ! -f /etc/novnc/certs/self.pem ]; then
    echo "Generating self-signed certificate for noVNC..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout /etc/novnc/certs/self.key -out /etc/novnc/certs/self.crt \
      -subj "/CN=novnc.local" >/dev/null 2>&1 || true
    cat /etc/novnc/certs/self.key /etc/novnc/certs/self.crt > /etc/novnc/certs/self.pem
  fi
  SSL_ARGS="--cert /etc/novnc/certs/self.pem --ssl-only"
else
  SSL_ARGS=""
fi

# Start websockify/noVNC binding to 0.0.0.0 so external hosts can reach it
cd /opt/noVNC
./utils/novnc_proxy --vnc ${VNC_HOST}:${VNC_PORT} --listen ${NOVNC_LISTEN_PORT} ${SSL_ARGS} >/var/log/novnc.log 2>&1 &

if [ "${NOVNC_TLS}" = "1" ]; then
  echo "noVNC (wss) web UI available at https://<container-ip>:${NOVNC_LISTEN_PORT}/vnc.html"
else
  echo "noVNC web UI available at http://<container-ip>:${NOVNC_LISTEN_PORT}/vnc.html"
fi

# If PrismLauncher.AppImage exists, make it runnable
if [ -f "$USER_HOME/PrismLauncher.AppImage" ]; then
  chown developer:developer "$USER_HOME/PrismLauncher.AppImage"
  chmod +x "$USER_HOME/PrismLauncher.AppImage"
  echo "PrismLauncher AppImage found at $USER_HOME/PrismLauncher.AppImage"
fi

tail -f /var/log/novnc.log /var/log/x11vnc.log || true
