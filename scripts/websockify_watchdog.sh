#!/bin/bash

# WebSocket Watchdog - More aggressive monitoring and recovery
# Part of the Ultimate Persistent VNC Desktop Setup

set -euo pipefail

LOG_FILE="/var/log/websockify_watchdog.log"
PID_FILE="/var/run/websockify_watchdog.pid"
CHECK_INTERVAL=5  # More frequent checks
HEALTH_CHECK_TIMEOUT=3

# Configuration
NOVNC_PORT="${NOVNC_PORT:-8080}"
VNC_HOST="${VNC_HOST:-localhost}"
VNC_PORT="${VNC_PORT:-5901}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [websockify-watchdog] $*" | tee -a "$LOG_FILE"
}

# Advanced health check
check_websocket_health() {
    # Check if port is listening
    if ! ss -ltn 2>/dev/null | grep -q ":$NOVNC_PORT "; then
        log "HEALTH: Port $NOVNC_PORT is not listening"
        return 1
    fi
    
    # Try to make a basic HTTP connection
    if ! curl -s --connect-timeout $HEALTH_CHECK_TIMEOUT "http://localhost:$NOVNC_PORT/" >/dev/null 2>&1; then
        log "HEALTH: HTTP connection to port $NOVNC_PORT failed"
        return 1
    fi
    
    # Check if VNC backend is reachable
    if ! nc -z -w $HEALTH_CHECK_TIMEOUT "$VNC_HOST" "$VNC_PORT" 2>/dev/null; then
        log "HEALTH: VNC backend ${VNC_HOST}:${VNC_PORT} is not reachable"
        return 2  # Different return code for backend issues
    fi
    
    return 0
}

# Aggressive restart function
restart_websocket_service() {
    log "RESTART: Performing aggressive WebSocket service restart"
    
    # Kill all websockify processes
    pkill -f websockify 2>/dev/null || true
    
    # Kill Node.js proxy if running
    pkill -f "node.*index.js" 2>/dev/null || true
    
    # Wait for processes to die
    sleep 3
    
    # Force kill if needed
    pkill -9 -f websockify 2>/dev/null || true
    pkill -9 -f "node.*index.js" 2>/dev/null || true
    
    # Clean up stale sockets/files
    find /tmp -name "*websockify*" -type f -delete 2>/dev/null || true
    find /tmp -name "*novnc*" -type f -delete 2>/dev/null || true
    
    sleep 2
    
    # Start the appropriate proxy based on configuration
    if [ "${NOVNC_USE_PROXY:-1}" = "1" ] && [ -f "/workspaces/vmtest/novnc_proxy/index.js" ]; then
        log "RESTART: Starting Node.js WebSocket proxy"
        cd /workspaces/vmtest/novnc_proxy
        nohup node index.js >> /var/log/novnc_proxy.log 2>&1 &
        local proxy_pid=$!
        log "RESTART: Started Node.js proxy with PID $proxy_pid"
    else
        log "RESTART: Starting Python websockify"
        cd /opt/noVNC
        nohup python3 -m websockify --web /opt/noVNC "$NOVNC_PORT" "${VNC_HOST}:${VNC_PORT}" >> /var/log/novnc.log 2>&1 &
        local proxy_pid=$!
        log "RESTART: Started Python websockify with PID $proxy_pid"
    fi
    
    # Wait for service to start
    local attempts=0
    while [ $attempts -lt 20 ]; do
        if check_websocket_health; then
            log "RESTART: WebSocket service successfully restarted"
            return 0
        fi
        sleep 1
        ((attempts++))
    done
    
    log "ERROR: WebSocket service failed to restart"
    return 1
}

# Main watchdog loop
watchdog_loop() {
    log "Starting WebSocket watchdog loop (check interval: ${CHECK_INTERVAL}s)"
    
    local consecutive_failures=0
    local total_restarts=0
    local last_restart_time=0
    
    while true; do
        local health_status=0
        check_websocket_health || health_status=$?
        
        case $health_status in
            0)
                # Service is healthy
                if [ $consecutive_failures -gt 0 ]; then
                    log "HEALTH: Service recovered after $consecutive_failures failures"
                fi
                consecutive_failures=0
                ;;
            1)
                # WebSocket service issues
                consecutive_failures=$((consecutive_failures + 1))
                log "HEALTH: WebSocket service failure #$consecutive_failures"
                
                if [ $consecutive_failures -ge 2 ]; then
                    log "WATCHDOG: Triggering aggressive restart after $consecutive_failures consecutive failures"
                    
                    if restart_websocket_service; then
                        total_restarts=$((total_restarts + 1))
                        last_restart_time=$(date +%s)
                        consecutive_failures=0
                        log "WATCHDOG: Successfully restarted service (total restarts: $total_restarts)"
                    else
                        log "WATCHDOG: Failed to restart service"
                    fi
                fi
                ;;
            2)
                # VNC backend issues - don't restart WebSocket, log for monitoring
                log "HEALTH: VNC backend issue detected, WebSocket service is healthy"
                consecutive_failures=0
                ;;
        esac
        
        # Log periodic statistics
        if [ $(($(date +%s) % 300)) -eq 0 ]; then  # Every 5 minutes
            local uptime_seconds=$(($(date +%s) - $(stat -c %Y /proc/$$ 2>/dev/null || date +%s)))
            log "STATS: Watchdog uptime: ${uptime_seconds}s, total_restarts: $total_restarts, consecutive_failures: $consecutive_failures"
        fi
        
        sleep $CHECK_INTERVAL
    done
}

# Handle command line arguments
case "${1:-start}" in
    "start")
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo "WebSocket watchdog is already running"
            exit 1
        fi
        
        echo $$ > "$PID_FILE"
        log "WebSocket watchdog started with PID $$"
        
        trap "rm -f $PID_FILE; exit 0" SIGTERM SIGINT
        
        watchdog_loop
        ;;
    "stop")
        if [ -f "$PID_FILE" ]; then
            local pid=$(cat "$PID_FILE")
            if kill -TERM "$pid" 2>/dev/null; then
                echo "WebSocket watchdog stopped"
            else
                echo "Failed to stop watchdog or watchdog not running"
            fi
            rm -f "$PID_FILE"
        else
            echo "WebSocket watchdog is not running"
        fi
        ;;
    "status")
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo "WebSocket watchdog is running (PID: $(cat "$PID_FILE"))"
            
            local health_status=0
            check_websocket_health || health_status=$?
            
            case $health_status in
                0) echo "WebSocket service is HEALTHY" ;;
                1) echo "WebSocket service has ISSUES" ;;
                2) echo "WebSocket service OK, VNC backend has ISSUES" ;;
            esac
            
            if [ -f "$LOG_FILE" ]; then
                echo "Recent log entries:"
                tail -10 "$LOG_FILE"
            fi
        else
            echo "WebSocket watchdog is not running"
        fi
        ;;
    "test")
        echo "Running health check test..."
        local health_status=0
        check_websocket_health || health_status=$?
        
        case $health_status in
            0) echo "✅ WebSocket service is HEALTHY" ;;
            1) echo "❌ WebSocket service has ISSUES" ;;
            2) echo "⚠️  WebSocket service OK, VNC backend has ISSUES" ;;
        esac
        exit $health_status
        ;;
    *)
        echo "Usage: $0 {start|stop|status|test}"
        exit 1
        ;;
esac
