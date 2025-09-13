#!/bin/bash

# WebSocket Supervisor Script - Enhanced monitoring and restart capabilities
# Part of the Ultimate Persistent VNC Desktop Setup

set -euo pipefail

LOG_FILE="/var/log/websockify_supervisor.log"
PID_FILE="/var/run/websockify_supervisor.pid"
WEBSOCKIFY_PID_FILE="/var/run/websockify.pid"
CHECK_INTERVAL=10
MAX_RESTART_ATTEMPTS=50
RESTART_WINDOW=300  # 5 minutes

# Configuration
NOVNC_DIR="/opt/noVNC"
NOVNC_PORT="${NOVNC_PORT:-8080}"
VNC_HOST="${VNC_HOST:-localhost}"
VNC_PORT="${VNC_PORT:-5901}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [websockify-supervisor] $*" | tee -a "$LOG_FILE"
}

check_websockify_running() {
    if [ -f "$WEBSOCKIFY_PID_FILE" ]; then
        local pid=$(cat "$WEBSOCKIFY_PID_FILE" 2>/dev/null || echo "")
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    
    # Also check if process is running by name
    if pgrep -f "websockify.*$NOVNC_PORT" >/dev/null 2>&1; then
        return 0
    fi
    
    return 1
}

check_port_listening() {
    ss -ltn 2>/dev/null | grep -q ":$NOVNC_PORT " && return 0 || return 1
}

start_websockify() {
    log "Starting websockify..."
    
    # Clean up any stale processes
    pkill -f "websockify.*$NOVNC_PORT" 2>/dev/null || true
    sleep 2
    
    cd "$NOVNC_DIR"
    
    # Start websockify as developer user
    su - developer -c "
        cd '$NOVNC_DIR'
        nohup python3 -m websockify \
            --verbose \
            --web '$NOVNC_DIR' \
            '$NOVNC_PORT' \
            '$VNC_HOST:$VNC_PORT' \
            > /var/log/websockify.log 2>&1 & 
        echo \$! > '$WEBSOCKIFY_PID_FILE'
    " || {
        log "ERROR: Failed to start websockify"
        return 1
    }
    
    # Wait for websockify to start
    local attempts=0
    while [ $attempts -lt 30 ]; do
        if check_port_listening; then
            log "INFO: WebSocket proxy started successfully on port $NOVNC_PORT"
            return 0
        fi
        sleep 1
        ((attempts++))
    done
    
    log "ERROR: WebSocket proxy failed to start"
    return 1
}

supervisor_loop() {
    log "Starting WebSocket supervisor loop (check interval: ${CHECK_INTERVAL}s)"
    
    declare -A restart_counts
    declare -A last_restart_time
    local service_name="websockify"
    
    while true; do
        if ! check_websockify_running || ! check_port_listening; then
            log "WARN: WebSocket proxy is not running or port not listening"
            
            # Check restart limits
            local current_time=$(date +%s)
            local last_restart=${last_restart_time[$service_name]:-0}
            local restart_count=${restart_counts[$service_name]:-0}
            
            # Reset restart count if outside the restart window
            if [ $((current_time - last_restart)) -gt $RESTART_WINDOW ]; then
                restart_count=0
            fi
            
            if [ $restart_count -lt $MAX_RESTART_ATTEMPTS ]; then
                log "INFO: Attempting to restart WebSocket proxy (attempt $((restart_count + 1))/$MAX_RESTART_ATTEMPTS)"
                
                if start_websockify; then
                    log "INFO: Successfully restarted WebSocket proxy"
                    restart_counts[$service_name]=0
                else
                    restart_counts[$service_name]=$((restart_count + 1))
                    last_restart_time[$service_name]=$current_time
                    log "ERROR: Failed to restart WebSocket proxy"
                fi
            else
                log "ERROR: WebSocket proxy has exceeded maximum restart attempts ($MAX_RESTART_ATTEMPTS)"
                # Wait longer before trying again
                sleep 60
            fi
        else
            # Service is healthy - reset restart count
            restart_counts[$service_name]=0
        fi
        
        sleep $CHECK_INTERVAL
    done
}

# Handle command line arguments
case "${1:-start}" in
    "start")
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo "WebSocket supervisor is already running"
            exit 1
        fi
        
        echo $$ > "$PID_FILE"
        log "WebSocket supervisor started with PID $$"
        
        trap "rm -f $PID_FILE; exit 0" SIGTERM SIGINT
        
        supervisor_loop
        ;;
    "stop")
        if [ -f "$PID_FILE" ]; then
            local pid=$(cat "$PID_FILE")
            if kill -TERM "$pid" 2>/dev/null; then
                echo "WebSocket supervisor stopped"
            else
                echo "Failed to stop supervisor or supervisor not running"
            fi
            rm -f "$PID_FILE"
        else
            echo "WebSocket supervisor is not running"
        fi
        ;;
    "status")
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo "WebSocket supervisor is running (PID: $(cat "$PID_FILE"))"
            
            if check_websockify_running && check_port_listening; then
                echo "WebSocket proxy is healthy"
            else
                echo "WebSocket proxy is NOT healthy"
            fi
            
            if [ -f "$LOG_FILE" ]; then
                echo "Recent log entries:"
                tail -10 "$LOG_FILE"
            fi
        else
            echo "WebSocket supervisor is not running"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|status}"
        exit 1
        ;;
esac
