#!/usr/bin/env bash

set -euo pipefail

USER_HOME=/home/developer
# Ensure .vnc directory exists for log files
mkdir -p "$USER_HOME/.vnc"
export DISPLAY=:1

# Ensure .vnc is owned by the developer user so vncserver can write pid/log files
chown -R developer:developer "$USER_HOME/.vnc" || true
chmod 700 "$USER_HOME/.vnc" || true

# Ensure Minecraft game directories exist and are writable by the developer user.
# Some launchers try to create ~/.minecraft/assets on first run; pre-create and
# chown them so the launcher (running as developer) doesn't hit EACCES.
mkdir -p "$USER_HOME/.minecraft/assets" || true
chown -R developer:developer "$USER_HOME/.minecraft" || true
chmod -R u+rwX,go+rX "$USER_HOME/.minecraft" || true

# Configuration with sensible defaults
NOVNC_LISTEN_PORT=${NOVNC_LISTEN_PORT:-8080}
VNC_HOST=${VNC_HOST:-localhost}
# Default VNC port should prefer TurboVNC (:1 -> 5901) to avoid earlier
# fallbacks binding to 5900 and proxying to the wrong backend.
VNC_PORT=${VNC_PORT:-5901}
NOVNC_TLS=${NOVNC_TLS:-0}
SSL_ARGS=""
# Prefer the Node-based fallback proxy for stability by default. Set to 0 to use Python websockify.
NOVNC_USE_PROXY=${NOVNC_USE_PROXY:-1}

# Screen geometry and performance tuning (can be overridden via env)
# For best smoothness, prefer a lower resolution; lower = faster.
# Use 1024x576 for better responsiveness on constrained hosts.
SCREEN_RES=${SCREEN_RES:-1024x576}
SCREEN_DEPTH=${SCREEN_DEPTH:-16}
# VNC ncache for noVNC/x11vnc fallback (higher = more client-side caching, less bandwidth)
N_CACHE_SIZE=${N_CACHE_SIZE:-1000}
# TurboVNC quality/compression tuning (lower JPEG quality reduces bandwidth and may improve frame rate)
TURBOVNC_JPEG_QUALITY=${TURBOVNC_JPEG_QUALITY:-70}
TURBOVNC_COMPRESSION=${TURBOVNC_COMPRESSION:-1}


# Only use TigerVNC; fail if not present
if command -v tigervncserver >/dev/null 2>&1; then
  VNC_CMD=$(command -v tigervncserver)
  echo "[entrypoint] Using TigerVNC at $VNC_CMD for vncserver."
else
  echo "[entrypoint] ERROR: TigerVNC not found. Please install TigerVNC. Exiting."
  exit 1
fi

# If lunarclient.AppImage exists in the developer home, try to run it.
# If FUSE is unavailable, extract the AppImage and run the extracted AppRun or binary.
if [ -f "$USER_HOME/lunarclient.AppImage" ] || [ -f "$USER_HOME/lunarclient.AppImage" ]; then
  # prefer running the AppImage directly if fusermount is available
  if command -v fusermount >/dev/null 2>&1 || command -v fusermount3 >/dev/null 2>&1; then
    echo "FUSE available; launching lunarclient AppImage" >> /var/log/novnc.log 2>&1 || true
    su - developer -c "nohup $USER_HOME/lunarclient.AppImage > $USER_HOME/lunar_run.log 2>&1 &" || true
  else
    echo "FUSE not available; extracting lunarclient.AppImage to Applications and running extracted binary" >> /var/log/novnc.log 2>&1 || true
    LUNARDIR="$USER_HOME/Applications"
    su - developer -c "mkdir -p $LUNARDIR" || true
    # extract if not already extracted
    if [ ! -d "$USER_HOME/Applications/squashfs-root" ]; then
      su - developer -c "cd $LUNARDIR && $USER_HOME/lunarclient.AppImage --appimage-extract 1>/dev/null 2>/dev/null || true" || true
      # ensure ownership
      chown -R developer:developer "$USER_HOME/Applications" 2>/dev/null || true
    fi
    if [ -d "$USER_HOME/Applications/squashfs-root" ]; then
      # try to run common extracted entrypoints: AppRun or lunarclient
      if [ -x "$USER_HOME/Applications/squashfs-root/AppRun" ]; then
        su - developer -c "nohup $USER_HOME/Applications/squashfs-root/AppRun --no-sandbox > $USER_HOME/lunar_run.log 2>&1 &" || true
      elif [ -x "$USER_HOME/Applications/squashfs-root/lunarclient" ]; then
        su - developer -c "nohup $USER_HOME/Applications/squashfs-root/lunarclient --no-sandbox > $USER_HOME/lunar_run.log 2>&1 &" || true
      else
        echo "Could not find AppRun or lunarclient binary in extracted AppImage" >> /var/log/novnc.log 2>&1 || true
      fi
    fi
  fi
fi

# Allow running without VNC password (insecure). Set to 1 to disable password.
DISABLE_VNC_PASSWORD=${DISABLE_VNC_PASSWORD:-1}


# Ensure SSL_ARGS is always defined (safe default)
SSL_ARGS=${SSL_ARGS:-}

# Start dbus
service dbus start || true

# Allow core dumps for Xvnc so crashes can be diagnosed if they continue
ulimit -c unlimited || true



# Ensure log files exist and are world-writable
mkdir -p /var/log
touch /var/log/novnc.log /var/log/x11vnc.log /var/log/xvfb.log /var/log/xfce.log /var/log/novnc_proxy.log /var/log/vncserver.log /var/log/xterm.log
chown developer:developer /var/log/novnc.log /var/log/x11vnc.log /var/log/xvfb.log /var/log/xfce.log /var/log/novnc_proxy.log /var/log/vncserver.log /var/log/xterm.log || true
chmod 666 /var/log/novnc.log /var/log/x11vnc.log /var/log/xvfb.log /var/log/xfce.log /var/log/novnc_proxy.log /var/log/vncserver.log /var/log/xterm.log || true

# Also ensure VNC and XFCE logs in home directory
touch /home/developer/xvfb.log /home/developer/.vnc/vncserver.log /home/developer/.vnc/tigervnc.log /home/developer/.vnc/Xtigervnc.log
chown developer:developer /home/developer/xvfb.log /home/developer/.vnc/vncserver.log /home/developer/.vnc/tigervnc.log /home/developer/.vnc/Xtigervnc.log || true


# Clean up any stray noVNC/websockify/novnc_proxy processes from previous runs
pkill -f websockify >/dev/null 2>&1 || true
pkill -f novnc_proxy >/dev/null 2>&1 || true
rm -f /tmp/.websockify_* || true
chown developer:developer /var/log/novnc.log || true

# novnc_proxy will be started later after the VNC backend is ready
# to avoid duplicate listeners and port conflicts. start_novnc_after_vnc
# and the supervisor will ensure novnc_proxy/websockify is started once.

# Start websockify supervisor early (run as root so it survives user transitions)
if [ -x /usr/local/bin/scripts/websockify_supervisor.sh ]; then
  echo "[entrypoint] websockify_supervisor present; will start later after display is ready" >> /var/log/novnc.log 2>&1 || true
  # DO NOT start the supervisor here to avoid race conditions where multiple
  # supervisors attempt to start websockify concurrently and produce
  # 'Address already in use' errors. The supervisor is started once later
  # in the script when the display/VNC backend is initialized.
fi

# Tunables (ensure a sensible floor if overwritten elsewhere)
N_CACHE_SIZE=${N_CACHE_SIZE:-400}
X11VNC_NOWF=${X11VNC_NOWF:-1}
X11VNC_NOWCR=${X11VNC_NOWCR:-1}

# VirtualGL runtime helper: if USE_VGL=1 attempt to install or enable vglrun
if [ "${USE_VGL:-0}" = "1" ]; then
  echo "USE_VGL=1 requested: attempting to enable VirtualGL (non-fatal)"
  if ! command -v vglrun >/dev/null 2>&1; then
    echo "VirtualGL (vglrun) not found -- attempting apt-get install virtualgl (may fail)"
    apt-get update || true
    apt-get install -y virtualgl || true
  fi
  if command -v vglrun >/dev/null 2>&1; then
    echo "VirtualGL found; enabling GPU-backed path (will prefer x0vncserver)"
    USE_GPU=1
  else
    echo "VirtualGL still not available; to enable, install VirtualGL inside the container or on the host. See CONTRIBUTING.md for guidance."
  fi
fi

# Optional: install TurboVNC at runtime if requested (non-fatal)
if [ "${INSTALL_TURBOVNC:-0}" = "1" ]; then
  echo "INSTALL_TURBOVNC=1 requested: attempting to download & install TurboVNC"
  set +e
  PR_URL=$(curl -s https://api.github.com/repos/TurboVNC/turbovnc/releases/latest | grep "browser_download_url" | grep amd64.deb | head -n1 | cut -d '"' -f4 || true)
  if [ -n "$PR_URL" ]; then
    echo "Downloading TurboVNC from $PR_URL"
    wget -qO /tmp/turbovnc.deb "$PR_URL" || true
    if [ -f /tmp/turbovnc.deb ]; then
      dpkg -i /tmp/turbovnc.deb || apt-get -f install -y || true
    fi
  else
    echo "Could not find TurboVNC release via GitHub API"
  fi
  set -e
fi



# Helpers to manage X display and avoid stale-lock/start races
clean_stale_x_locks() {
  LOCK_FILE="/tmp/.X${DISPLAY#:}-lock"
  if [ -f "$LOCK_FILE" ]; then
    # If lock exists but no X process for this display, remove it
    pid=$(sed -n '1p' "$LOCK_FILE" 2>/dev/null || true)
    if [ -n "$pid" ] && ps -p "$pid" >/dev/null 2>&1; then
      echo "Found X server process $pid for ${DISPLAY}, keeping lock"
    else
      echo "Removing stale X lock $LOCK_FILE"
      rm -f "$LOCK_FILE" || true
    fi
  fi
  # also remove socket leftover if any but no process
  if [ -S "/tmp/.X11-unix/X${DISPLAY#:}" ]; then
    # check if there is a process using display
    if ! pgrep -f "X .* ${DISPLAY}" >/dev/null 2>&1 && ! pgrep -f "Xvfb ${DISPLAY}" >/dev/null 2>&1; then
      echo "Removing stale X socket for ${DISPLAY}"
      rm -f "/tmp/.X11-unix/X${DISPLAY#:}" || true
    fi
  fi
}

start_xvfb_if_missing() {
  # aggressively clean previous X processes and locks for this display to avoid "server already running"
  echo "Killing any previous X processes for ${DISPLAY} and cleaning locks"
  pkill -f "Xvfb ${DISPLAY}" >/dev/null 2>&1 || true
  pkill -f "X .* ${DISPLAY}" >/dev/null 2>&1 || true
  clean_stale_x_locks
  sleep 0.5
  echo "Starting Xvfb ${DISPLAY} as developer"
  # run Xvfb as the developer user so .Xauthority is created in their home
  su - developer -c "mkdir -p $USER_HOME; Xvfb ${DISPLAY} -screen 0 ${SCREEN_RES}x${SCREEN_DEPTH} -nolisten tcp >> /var/log/xvfb.log 2>&1 &" || true
  # give it a moment to create sockets
  sleep 1
}

# Start the XFCE desktop session when needed
start_xfce_if_missing() {
  if pgrep -f xterm >/dev/null 2>&1; then
    echo "xterm already running"
    return 0
  fi
  echo "Starting xterm session as developer (test mode)"
  su - developer -c "export DISPLAY=${DISPLAY}; nohup xterm >> /var/log/xterm.log 2>&1 &" || true
  sleep 2
}

# If TurboVNC (vncserver) is available, start a vncserver :1 session and prefer it
start_turbovnc_if_missing() {
  if ! command -v vncserver >/dev/null 2>&1; then
    return 1
  fi
  # if a vncserver is already listening on 5901 (display :1), do nothing
  if ss -ltnp 2>/dev/null | egrep -q ":5901 \b"; then
    echo "TurboVNC already listening on 5901"
    VNC_PORT=5901
    export VNC_PORT
    export DISPLAY=:1
    return 0
  fi
  echo "Preparing to start TurboVNC (vncserver :1) as developer"
  # Clean any stale locks/sockets for this display before attempting to start vncserver
  clean_stale_x_locks

  echo "Starting TurboVNC (vncserver :1) as developer"
  # ensure a default VNC password exists to allow non-interactive start
  if [ "${DISABLE_VNC_PASSWORD:-0}" = "1" ]; then
    echo "DISABLE_VNC_PASSWORD=1: not creating VNC passwd file; starting vncserver with no authentication" >> /var/log/novnc.log 2>&1 || true
  else
    if [ ! -f "$USER_HOME/.vnc/passwd" ]; then
      echo "password" | su - developer -c "mkdir -p $USER_HOME/.vnc && vncpasswd -f > $USER_HOME/.vnc/passwd && chmod 600 $USER_HOME/.vnc/passwd" || true
      chown developer:developer "$USER_HOME/.vnc/passwd" || true
    fi
  fi

  # Try starting TurboVNC multiple times if it doesn't open the port; allow longer backoff to survive transient load
  attempts=${TURBOVNC_START_ATTEMPTS:-8}
  for attempt in $(seq 1 $attempts); do
    echo "[entrypoint] TurboVNC start attempt ${attempt}/${attempts}"
    # Remove stale PID files for this display (safe cleanup)
    rm -f $USER_HOME/.vnc/*.pid || true
    # Use chosen vncserver binary if available
    if [ -n "${VNC_CMD:-}" ] && [ -x "${VNC_CMD}" ]; then
      # Use TurboVNC with tuned quality/compression if available
      if [ "${DISABLE_VNC_PASSWORD:-0}" = "1" ]; then
        # start without VNC authentication
  su - developer -c "${VNC_CMD} :1 -geometry ${SCREEN_RES} -depth ${SCREEN_DEPTH} -securitytypes none >> /var/log/vncserver.log 2>&1" || true
      else
  su - developer -c "${VNC_CMD} :1 -geometry ${SCREEN_RES} -depth ${SCREEN_DEPTH} -securitytypes vnc >> /var/log/vncserver.log 2>&1" || true
      fi
    else
      if [ "${DISABLE_VNC_PASSWORD:-0}" = "1" ]; then
  su - developer -c "vncserver :1 -geometry ${SCREEN_RES} -depth ${SCREEN_DEPTH} -SecurityTypes none >> /var/log/vncserver.log 2>&1" || true
      else
  su - developer -c "vncserver :1 -geometry ${SCREEN_RES} -depth ${SCREEN_DEPTH} >> /var/log/vncserver.log 2>&1" || true
      fi
    fi

    # prefer TurboVNC port
    VNC_PORT=5901
    export VNC_PORT
    export DISPLAY=:1

  # wait longer for port (120s) to accommodate slower startups under load
  retries=${TURBOVNC_START_WAIT:-120}
    while [ $retries -gt 0 ]; do
      if ss -ltnp 2>/dev/null | egrep -q ":${VNC_PORT} \b"; then
        echo "TurboVNC listening on ${VNC_PORT}"
        return 0
      fi
      sleep 1
      retries=$((retries-1))
    done

    echo "TurboVNC did not open port ${VNC_PORT} in time on attempt ${attempt}"
    # try to clean up a failed server before next attempt
    su - developer -c "vncserver -kill :1" >/dev/null 2>&1 || true
    sleep 1
  done

  echo "TurboVNC failed to start after ${attempts} attempts"
  return 1
}

wait_for_display() {
  retries=30
  while [ $retries -gt 0 ]; do
    if [ -S "/tmp/.X11-unix/X${DISPLAY#:}" ]; then
      return 0
    fi
    sleep 1
    retries=$((retries-1))
  done
  return 1
}


# Robustly supervise TigerVNC server
supervise_tigervnc() {
  while true; do
    if ! pgrep -f Xtigervnc >/dev/null 2>&1; then
      echo "[entrypoint] TigerVNC not running, starting..." >> /var/log/vncserver.log
      start_turbovnc_if_missing
    fi
    sleep 5
  done
}

supervise_tigervnc &

# Start desktop session (needed by either TurboVNC or x11vnc)
start_xfce_if_missing

## Wait for X session to create an X authority file (so x11vnc can authenticate)
wait_for_xauthority() {
  retries=30
  while [ $retries -gt 0 ]; do
    # prefer developer Xauthority
    if [ -f "$USER_HOME/.Xauthority" ]; then
      echo "Found developer Xauthority"
      return 0
    fi
    # root or display manager auth as fallback
    if [ -f "/root/.Xauthority" ]; then
      echo "Found root Xauthority"
      return 0
    fi
    sleep 1
    retries=$((retries-1))
  done
  echo "No Xauthority file detected; will try -auth guess as fallback"
  return 1
}

start_x11vnc_root() {
  if pgrep -f x11vnc >/dev/null 2>&1; then
    echo "x11vnc already running"
    return 0
  fi

  # If developer's Xauthority is missing, try to generate one now that X is running and XFCE started
  if [ ! -f "$USER_HOME/.Xauthority" ]; then
    echo "No developer .Xauthority found; attempting to generate one"
    su - developer -c "export DISPLAY=${DISPLAY}; xauth generate ${DISPLAY} . trusted || true"
    chown developer:developer "$USER_HOME/.Xauthority" 2>/dev/null || true
  fi

  # Start x11vnc as developer using their Xauthority
  # Prefer x0vncserver (TigerVNC) if present — it's generally faster than x11vnc
  if command -v x0vncserver >/dev/null 2>&1; then
    echo "x0vncserver found — starting x0vncserver to serve ${DISPLAY}"
    su - developer -c "nohup x0vncserver -display ${DISPLAY} -rfbport ${VNC_PORT} >/var/log/x11vnc.log 2>&1 &" || true
  else
    if [ -f "$USER_HOME/.Xauthority" ]; then
      echo "Starting x11vnc as developer using $USER_HOME/.Xauthority (tuned for low latency)"
    su - developer -c "nohup x11vnc -display ${DISPLAY} -auth $USER_HOME/.Xauthority -nopw -forever -shared -rfbport ${VNC_PORT} \
        -ncache ${N_CACHE_SIZE} -ncache_cr -nowf >/var/log/x11vnc.log 2>&1 &" || true
    else
      echo "Starting x11vnc as developer using -auth guess (fallback, tuned)"
      su - developer -c "nohup x11vnc -display ${DISPLAY} -auth guess -nopw -forever -shared -rfbport ${VNC_PORT} \
          -ncache ${N_CACHE_SIZE} -ncache_cr -nowf >/var/log/x11vnc.log 2>&1 &" || true
    fi
  fi

  # wait for x11vnc to open socket
  retries=30
  while [ $retries -gt 0 ]; do
    if ss -ltnp 2>/dev/null | egrep -q ":${VNC_PORT} \b"; then
      echo "x11vnc is listening on port ${VNC_PORT}"
      return 0
    fi
    sleep 1
    retries=$((retries-1))
  done
  return 1
}

start_novnc_after_vnc() {
  # Start novnc only after VNC port is ready
  # Allow a longer wait because TurboVNC can take time to initialize
  retries=90
  while [ $retries -gt 0 ]; do
    if ss -ltnp 2>/dev/null | egrep -q ":${VNC_PORT} \b"; then
      echo "VNC backend available, starting noVNC proxy"
      # ensure noVNC requests pointer lock on click (improves mouse capture for games)
      if [ -f /opt/noVNC/vnc.html ] && ! grep -q "<!-- pointer-lock-injected -->" /opt/noVNC/vnc.html 2>/dev/null; then
        echo "Injecting pointer-lock helper and stability patches into noVNC vnc.html"
        cat >> /opt/noVNC/vnc.html <<'HTML'
<!-- pointer-lock-injected -->
<style>
#pv_lock_overlay {position:absolute; z-index:9999; top:8px; right:8px; background:rgba(0,0,0,0.5); color:#fff; padding:6px 8px; border-radius:4px; font-size:12px;}
</style>
<div id="pv_lock_overlay" aria-hidden="true">Click to lock mouse</div>
<script>
function requestPointerLockOnCanvas(){
  const canvas = document.querySelector('canvas#noVNC_canvas');
  const overlay = document.getElementById('pv_lock_overlay');
  if(!canvas || !overlay) return;
  overlay.style.display='block';
  overlay.onclick = () => {
    if(document.pointerLockElement !== canvas){
      canvas.requestPointerLock && canvas.requestPointerLock();
      overlay.textContent = 'Locked';
    }
  };
  // re-request lock on visibility/focus if it drops
  document.addEventListener('pointerlockchange', () => {
    if(document.pointerLockElement !== canvas){
      overlay.textContent = 'Click to lock mouse';
    } else {
      overlay.textContent = 'Locked';
    }
  });
  window.addEventListener('focus', () => setTimeout(()=>{ if(document.pointerLockElement!==canvas){ overlay.textContent='Click to lock mouse'; } }, 200));
}
document.addEventListener('DOMContentLoaded', requestPointerLockOnCanvas);
</script>
<script>
// Prevent client-initiated desktop resize requests which can trigger instability in some Xvnc/TurboVNC builds.
(function disableClientResize(){
  function safePatch(){
    try{
      if(window.RFB && RFB.prototype){
        // ignore ext_desktop_size handlers and client-side resize sends if present
        if(RFB.prototype._handle_ext_desktop_size){
          RFB.prototype._handle_ext_desktop_size = function(){ console.log('novnc: ext_desktop_size ignored'); };
        }
        if(RFB.prototype._sendResize){
          RFB.prototype._sendResize = function(){ console.log('novnc: sendResize ignored'); };
        }
      }
    }catch(e){ console.error('novnc resize patch failed',e); }
  }
  document.addEventListener('DOMContentLoaded', safePatch);
  window.addEventListener('load', safePatch);
  setTimeout(safePatch, 3000);
})();
</script>
HTML
      fi
  # ensure no stale proxy is running
  pkill -f websockify >/dev/null 2>&1 || true
  pkill -f novnc_proxy >/dev/null 2>&1 || true
  sleep 0.2
  cd /opt/noVNC
  # Prefer running the stable Python websockify module directly (avoids wrapper script exit)
  mkdir -p /home/developer/.local/share/novnc || true
  cd /opt/noVNC
          # Delegate websockify startup to a helper which handles retries/logging and starts it as the developer user
          if [ "${NOVNC_USE_PROXY}" = "1" ]; then
            echo "NOVNC_USE_PROXY=1: skipping python websockify start; using novnc_proxy instead" >> /var/log/novnc.log 2>&1 || true
            # Do not start Python websockify when NOVNC_USE_PROXY=1
          else
            if [ -x /usr/local/bin/scripts/start_websockify.sh ]; then
              /usr/local/bin/scripts/start_websockify.sh >> /var/log/novnc.log 2>&1 || true
            else
              # Only start Python websockify when NOVNC_USE_PROXY is not 1
              if [ "${NOVNC_USE_PROXY:-1}" != "1" ]; then
                # Fallback: try starting directly as developer
                su - developer -c "nohup python3 -m websockify --verbose --web /opt/noVNC ${NOVNC_LISTEN_PORT} ${VNC_HOST}:${VNC_PORT} > /var/log/novnc.log 2>&1 & echo \$! > /tmp/novnc_debug.pid" || true
              else
                echo "[entrypoint] NOVNC_USE_PROXY=1: skipping python websockify in start_novnc_after_vnc fallback" >> /var/log/novnc.log 2>&1 || true
              fi
            fi
          fi
      # if helper started websockify it will have created /tmp/novnc_debug.pid; return anyway
      return 0
    fi
    sleep 1
    retries=$((retries-1))
  done
  echo "VNC backend did not become available; starting novnc proxy anyway" >> /var/log/novnc.log 2>&1 || true
  cd /opt/noVNC
  pkill -f websockify >/dev/null 2>&1 || true
  sleep 0.2
  # Only start Python websockify when NOVNC_USE_PROXY is not 1
  if [ "${NOVNC_USE_PROXY:-1}" != "1" ]; then
    # Fallback direct start as developer user
    su - developer -c "nohup python3 -m websockify --verbose --web /opt/noVNC ${NOVNC_LISTEN_PORT} ${VNC_HOST}:${VNC_PORT} > /var/log/novnc.log 2>&1 & echo \$! > /tmp/novnc_debug.pid" || true
    sleep 0.2
    pgrep -f websockify > /tmp/novnc_debug.pid 2>/dev/null || true
  else
    echo "[entrypoint] NOVNC_USE_PROXY=1: skipping python websockify in start_novnc_after_vnc final fallback" >> /var/log/novnc.log 2>&1 || true
  fi
}

# Ensure we have an Xauthority if possible before starting x11vnc
# We try to detect Xauthority but run x11vnc as root using -auth guess which is more reliable in container
wait_for_xauthority || true

# Only start x11vnc if TurboVNC isn't in use
if [ "${USE_TURBOVNC:-0}" -eq 0 ]; then
  if start_x11vnc_root; then
    echo "x11vnc started successfully"
  else
    echo "x11vnc failed to start; check /var/log/x11vnc.log"
  fi
else
  echo "TurboVNC in use; skipping x11vnc startup"
fi

# Start novnc only after VNC backend is ready
echo "[entrypoint-debug] about to call start_novnc_after_vnc (DISPLAY=${DISPLAY}, VNC_PORT=${VNC_PORT})"
start_time=$(date +%s)
echo "[entrypoint-debug] calling start_novnc_after_vnc at ${start_time}"
start_novnc_after_vnc
echo "[entrypoint-debug] returned from start_novnc_after_vnc (elapsed=$(( $(date +%s) - start_time ))s)"

# If for some reason websockify isn't listening after the helper returned, attempt a direct start (helps in odd container environments)
if ! ss -ltnp 2>/dev/null | grep -q ":${NOVNC_LISTEN_PORT} \b"; then
  echo "[entrypoint] websockify not detected after start_novnc_after_vnc; deciding fallback" >> /var/log/novnc.log 2>&1 || true
  # Respect NOVNC_USE_PROXY: if set, we intentionally skip starting the
  # legacy Python websockify fallback to avoid port binding races with the
  # Node-based novnc_proxy. This prevents repeated OSError: [Errno 98].
  if [ "${NOVNC_USE_PROXY:-0}" = "1" ]; then
    echo "[entrypoint] NOVNC_USE_PROXY=1: skipping python websockify fallback (using novnc_proxy)" >> /var/log/novnc.log 2>&1 || true
    # Do not start Python websockify when NOVNC_USE_PROXY=1 to avoid port conflicts
  else
    python3 -m websockify --daemon --verbose --web /opt/noVNC ${NOVNC_LISTEN_PORT} ${VNC_HOST}:${VNC_PORT} >> /var/log/novnc.log 2>&1 || true
    sleep 1
    if ss -ltnp 2>/dev/null | grep -q ":${NOVNC_LISTEN_PORT} \b"; then
      echo "[entrypoint] websockify started by fallback path" >> /var/log/novnc.log 2>&1 || true
    else
      echo "[entrypoint] fallback websockify start failed; manual start may be required" >> /var/log/novnc.log 2>&1 || true
    fi
  fi
fi

# Lightweight supervisor: restart x11vnc or novnc if they exit
supervisor_loop() {
  # Track TurboVNC restart attempts to avoid tight restart loops. If TurboVNC
  # repeatedly fails, fall back to Xvfb + x11vnc to keep a persistent desktop
  # and prevent noVNC from losing its proxy target.
  turbo_restarts=0
  turbo_window_secs=60
  last_turbo_restart_ts=0

  while true; do
    # Manage x11vnc only when TurboVNC is not used
    if [ "${USE_TURBOVNC:-0}" -eq 0 ]; then
      if ! pgrep -f x11vnc >/dev/null 2>&1; then
        echo "x11vnc died, restarting..."
        start_x11vnc_root || true
      fi
    fi

    # Ensure TurboVNC server is running
    if ! netstat -ln | grep -q ":5901.*LISTEN"; then
      echo "[supervisor] TurboVNC server not listening on 5901, restarting..." >> /var/log/novnc.log 2>&1 || true
      # Kill any existing VNC processes
      pkill -f "tigervncserver" 2>/dev/null || true
      pkill -f "Xtigervnc" 2>/dev/null || true
      sleep 2
      # Restart TurboVNC as developer user
      su - developer -c "tigervncserver :1 -geometry ${SCREEN_RES:-1024x768} -depth ${SCREEN_DEPTH:-24} -SecurityTypes None" 2>/dev/null || true
      sleep 3
    fi



    # Ensure noVNC proxy is running
    if [ "${NOVNC_USE_PROXY:-1}" = "1" ]; then
      # Check Node.js proxy when NOVNC_USE_PROXY=1 - check both process and port
      if ! pgrep -f "node.*index.js" >/dev/null 2>&1 && ! netstat -ln | grep -q ":8080.*LISTEN"; then
        echo "[supervisor] Node.js proxy not running, restarting..." >> /var/log/novnc.log 2>&1 || true
        # Kill any existing proxy processes first
        pkill -f "node.*index.js" 2>/dev/null || true
        sleep 2
        cd /workspaces/vmtest/novnc_proxy 2>/dev/null || true
        nohup node index.js >> /var/log/novnc_proxy.log 2>&1 &
      fi
    else
      # Check Python websockify when NOVNC_USE_PROXY=0
      if ! pgrep -f websockify >/dev/null 2>&1; then
        echo "[supervisor] Python websockify not running, restarting via start_novnc_after_vnc" >> /var/log/novnc.log 2>&1 || true
        start_novnc_after_vnc || true
      fi
    fi

    sleep 5
  done
}

# run supervisor in background
supervisor_loop &

# Start a persistent websockify watchdog or supervisor to ensure the web proxy stays running.
# Prefer the watchdog (stronger restart behavior); fall back to the supervisor for compatibility.
if [ -x /usr/local/bin/scripts/websockify_watchdog.sh ]; then
  if [ "${NOVNC_USE_PROXY}" = "1" ]; then
    echo "NOVNC_USE_PROXY=1: not starting websockify_watchdog (using novnc_proxy)" >> /var/log/novnc.log 2>&1 || true
  else
    echo "[entrypoint] starting websockify_watchdog" >> /var/log/novnc.log 2>&1 || true
    su - developer -c "nohup /usr/local/bin/scripts/websockify_watchdog.sh > /var/log/novnc_supervisor.log 2>&1 &" || true
  fi
elif [ -x /usr/local/bin/scripts/websockify_supervisor.sh ]; then
  if [ "${NOVNC_USE_PROXY}" = "1" ]; then
    echo "NOVNC_USE_PROXY=1: not starting websockify_supervisor (using novnc_proxy)" >> /var/log/novnc.log 2>&1 || true
  else
    echo "[entrypoint] starting websockify_supervisor" >> /var/log/novnc.log 2>&1 || true
    su - developer -c "nohup /usr/local/bin/scripts/websockify_supervisor.sh > /var/log/novnc_supervisor.log 2>&1 &" || true
  fi
fi
# Periodically attempt to collect cores if present (background)
## Start core collector as root so it can access /core* and system crash locations
if [ -x /usr/local/bin/scripts/collect_core.sh ]; then
  echo "[entrypoint] starting collect_core.sh monitor as root" >> /var/log/novnc.log 2>&1 || true
  nohup /usr/local/bin/scripts/collect_core.sh > /var/log/collect_core.log 2>&1 &
fi

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

## novnc is started from start_novnc_after_vnc to ensure the VNC backend is available
if [ "${NOVNC_TLS}" = "1" ]; then
  echo "noVNC (wss) web UI will be available at https://<container-ip>:${NOVNC_LISTEN_PORT}/vnc.html"
else
  echo "noVNC web UI will be available at http://<container-ip>:${NOVNC_LISTEN_PORT}/vnc.html"
fi

# If PrismLauncher.AppImage exists, make it runnable
if [ -f "$USER_HOME/PrismLauncher.AppImage" ]; then
  chown developer:developer "$USER_HOME/PrismLauncher.AppImage"
  chmod +x "$USER_HOME/PrismLauncher.AppImage"
  echo "PrismLauncher AppImage found at $USER_HOME/PrismLauncher.AppImage"
fi

# Start the persistent novnc monitor if present. This writes regular snapshots to
# /var/log/novnc_monitor.log (helpful for post-mortem when the desktop or proxy
# disconnects). Run as root so it can see sockets and processes.
if [ -x /workspaces/vmtest/scripts/novnc_monitor.sh ]; then
  if ! pgrep -f novnc_monitor.sh >/dev/null 2>&1; then
    echo "[entrypoint] starting novnc_monitor.sh" >> /var/log/novnc.log 2>&1 || true
    nohup /workspaces/vmtest/scripts/novnc_monitor.sh > /var/log/novnc_monitor.log 2>&1 &
  else
    echo "[entrypoint] novnc_monitor already running" >> /var/log/novnc.log 2>&1 || true
  fi
fi

# If Lunar.AppImage exists, make it runnable and try to launch it as developer
if [ -f "$USER_HOME/Lunar.AppImage" ]; then
  chown developer:developer "$USER_HOME/Lunar.AppImage"
  chmod +x "$USER_HOME/Lunar.AppImage"
  echo "Lunar AppImage found at $USER_HOME/Lunar.AppImage; will attempt to run on startup"
  # launch in background as developer using conservative JVM options to limit memory and prefer lower-latency GC
  # _JAVA_OPTIONS is a safe way to provide JVM flags to the embedded Java runtime inside the AppImage
  su - developer -c "env _JAVA_OPTIONS='-Xmx2G -XX:+UseG1GC -XX:+UseStringDeduplication' DISPLAY=${DISPLAY} nohup $USER_HOME/Lunar.AppImage > $USER_HOME/lunar_run.log 2>&1 &" || true
fi

# If the workspace contains a Lunar.AppImage (for example you added it to the codespace),
# copy it into the developer home so it will be launched above. This allows the host
# workspace to provide the AppImage without rebuilding the image.
for candidate in /workspaces/vmtest/Lunar.AppImage /workspaces/vmtest/lunar.AppImage /workspaces/vmtest/lunarclient.AppImage /workspaces/vmtest/LunarClient.AppImage; do
  if [ -f "$candidate" ] && [ ! -f "$USER_HOME/$(basename "$candidate")" ]; then
    echo "Found $candidate -> copying into $USER_HOME"
    cp "$candidate" "$USER_HOME/" || true
    chown developer:developer "$USER_HOME/$(basename "$candidate")" || true
    chmod +x "$USER_HOME/$(basename "$candidate")" || true
    echo "Copied $(basename "$candidate") into $USER_HOME"
    # launch it (best-effort) so the launcher is open on session start
    su - developer -c "env _JAVA_OPTIONS='-Xmx2G -XX:+UseG1GC -XX:+UseStringDeduplication' DISPLAY=${DISPLAY} nohup $USER_HOME/$(basename "$candidate") > $USER_HOME/lunar_run.log 2>&1 &" || true
    break
  fi
done

# If a lightweight Node-based novnc proxy is present in the workspace,
# start it when NOVNC_USE_PROXY=1 instead of Python websockify.
if [ -f /workspaces/vmtest/novnc_proxy/index.js ] && command -v node >/dev/null 2>&1; then
  if [ "${NOVNC_USE_PROXY:-1}" = "1" ]; then
    echo "[entrypoint] starting novnc_proxy as primary proxy (NOVNC_USE_PROXY=1)" >> /var/log/novnc.log 2>&1 || true
    # Start Node.js proxy in background with proper logging
    cd /workspaces/vmtest/novnc_proxy
    nohup node index.js >> /var/log/novnc_proxy.log 2>&1 &
    NOVNC_PROXY_PID=$!
    echo "Started Node.js proxy with PID $NOVNC_PROXY_PID" >> /var/log/novnc.log 2>&1 || true
  else
    echo "[entrypoint] starting novnc_proxy as fallback (NOVNC_USE_PROXY=0)" >> /var/log/novnc.log 2>&1 || true
    su - developer -c "nohup node /workspaces/vmtest/novnc_proxy/index.js >> /var/log/novnc_proxy.log 2>&1 &" || true
  fi
fi

# If PrismLauncher.AppImage exists, try to run it. If FUSE is not available in
# the container (common in Docker), extract the AppImage and run the extracted
# AppRun so the launcher can start without requiring kernel FUSE.
if [ -f "$USER_HOME/PrismLauncher.AppImage" ]; then
  # prefer running the AppImage directly if fusermount is available
  if command -v fusermount >/dev/null 2>&1 || command -v fusermount3 >/dev/null 2>&1; then
    echo "FUSE available; launching PrismLauncher AppImage"
    su - developer -c "nohup $USER_HOME/PrismLauncher.AppImage > $USER_HOME/prism_run.log 2>&1 &" || true
  else
    echo "FUSE not available; extracting PrismLauncher AppImage to AppDir and running extracted AppRun"
    APPDIR="$USER_HOME/PrismLauncher.AppDir"
    if [ ! -d "$APPDIR" ]; then
      # extract AppImage to a temporary folder then move to APPDIR
      su - developer -c "cd $USER_HOME && /bin/sh -c '$USER_HOME/PrismLauncher.AppImage --appimage-extract'" || true
      # extraction creates ./squashfs-root
      if [ -d "$USER_HOME/squashfs-root" ]; then
        mv "$USER_HOME/squashfs-root" "$APPDIR" || true
        chown -R developer:developer "$APPDIR" || true
      fi
    fi
    if [ -x "$APPDIR/AppRun" ]; then
      su - developer -c "nohup $APPDIR/AppRun > $USER_HOME/prism_run.log 2>&1 &" || true
    else
      echo "Could not find extracted AppRun; consider installing FUSE in the host or container" >> $USER_HOME/prism_run.log || true
    fi
  fi
fi

tail -f /var/log/novnc.log /var/log/x11vnc.log || true
