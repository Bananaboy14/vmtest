#!/bin/bash

# Session Keeper Daemon - Ultimate Persistence & Auto-Recovery
# Monitors all critical services and maintains session state

set -euo pipefail

# Configuration
DAEMON_NAME="session-keeper"
PID_FILE="/var/run/session-keeper.pid"
LOG_FILE="/var/log/session-keeper.log"
CHECK_INTERVAL=15  # seconds
MAX_RESTART_ATTEMPTS=10
RESTART_WINDOW=300  # 5 minutes
SERVICE_STATE_FILE="/var/lib/session-keeper-state"

# Service definitions
declare -A SERVICES=(
    ["vnc-server"]="tigervnc|Xtigervnc:5901:critical"
    ["websocket-proxy"]="websockify|node.*index.js:8080:critical"
    ["x-server"]="Xvfb|Xvnc|Xtigervnc:-:critical"
    ["desktop-session"]="xterm|xfce4:-:important"
    ["lunar-client"]="lunar:-:application"
)

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")  color="$GREEN" ;;
        "WARN")  color="$YELLOW" ;;
        "ERROR") color="$RED" ;;
        "DEBUG") color="$BLUE" ;;
        *)       color="$NC" ;;
    esac
    
    echo -e "${color}[$timestamp] [$DAEMON_NAME] [$level]${NC} $message" | tee -a "$LOG_FILE"
}

# Check if daemon is already running
check_daemon_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        else
            rm -f "$PID_FILE"
        fi
    fi
    return 1
}

# Create PID file
create_pid_file() {
    echo $$ > "$PID_FILE"
    log "INFO" "Session keeper daemon started with PID $$"
}

# Cleanup function
cleanup() {
    log "INFO" "Session keeper daemon shutting down..."
    rm -f "$PID_FILE"
    exit 0
}

# Signal handlers
trap cleanup SIGTERM SIGINT

# Initialize service state tracking
init_service_state() {
    mkdir -p "$(dirname "$SERVICE_STATE_FILE")"
    if [ ! -f "$SERVICE_STATE_FILE" ]; then
        echo "{}" > "$SERVICE_STATE_FILE"
    fi
}

# Update service state
update_service_state() {
    local service="$1"
    local state="$2"
    local timestamp=$(date +%s)
    
    # Simple JSON-like state tracking
    local temp_file="/tmp/session-keeper-state.tmp"
    {
        echo "{"
        echo "  \"$service\": {"
        echo "    \"state\": \"$state\","
        echo "    \"timestamp\": $timestamp,"
        echo "    \"last_check\": \"$(date)\""
        echo "  }"
        echo "}"
    } > "$temp_file"
    
    mv "$temp_file" "$SERVICE_STATE_FILE"
}

# Check if service is running
check_service() {
    local service_name="$1"
    local service_def="${SERVICES[$service_name]}"
    
    IFS=':' read -r process_pattern port priority <<< "$service_def"
    
    local process_running=false
    local port_listening=true  # Default to true for services without ports
    
    # Check if process is running
    if pgrep -f "$process_pattern" >/dev/null 2>&1; then
        process_running=true
    fi
    
    # Check port if specified
    if [ "$port" != "-" ]; then
        if ! ss -ltn 2>/dev/null | grep -q ":$port "; then
            port_listening=false
        fi
    fi
    
    if $process_running && $port_listening; then
        return 0  # Service is healthy
    else
        return 1  # Service needs attention
    fi
}

# Restart VNC server
restart_vnc_server() {
    log "INFO" "Restarting VNC server..."
    
    # Kill existing VNC processes
    pkill -f "tigervnc\\|Xtigervnc" 2>/dev/null || true
    sleep 2
    
    # Clean up stale files
    rm -f /home/developer/.vnc/*.pid 2>/dev/null || true
    rm -f /tmp/.X*-lock 2>/dev/null || true
    
    # Start TigerVNC as developer user
    su - developer -c "
        export DISPLAY=:1
        tigervncserver :1 \
            -geometry ${SCREEN_RES:-1600x900} \
            -depth ${SCREEN_DEPTH:-24} \
            -SecurityTypes None \
            >> /var/log/vncserver.log 2>&1
    " || {
        log "ERROR" "Failed to start VNC server"
        return 1
    }
    
    # Wait for VNC server to start
    local attempts=0
    while [ $attempts -lt 30 ]; do
        if ss -ltn 2>/dev/null | grep -q ":5901 "; then
            log "INFO" "VNC server restarted successfully"
            return 0
        fi
        sleep 1
        ((attempts++))
    done
    
    log "ERROR" "VNC server failed to start after restart"
    return 1
}

# Restart WebSocket proxy
restart_websocket_proxy() {
    log "INFO" "Restarting WebSocket proxy..."
    
    # Kill existing proxy processes
    pkill -f "websockify\\|node.*index.js" 2>/dev/null || true
    sleep 2
    
    # Start appropriate proxy based on configuration
    if [ "${NOVNC_USE_PROXY:-1}" = "1" ] && [ -f "/workspaces/vmtest/novnc_proxy/index.js" ]; then
        # Start Node.js proxy
        cd /workspaces/vmtest/novnc_proxy
        nohup node index.js >> /var/log/novnc_proxy.log 2>&1 &
        log "INFO" "Started Node.js WebSocket proxy"
    else
        # Start Python websockify
        cd /opt/noVNC
        nohup python3 -m websockify --web /opt/noVNC 8080 localhost:5901 >> /var/log/novnc.log 2>&1 &
        log "INFO" "Started Python WebSocket proxy"
    fi
    
    # Wait for proxy to start
    local attempts=0
    while [ $attempts -lt 20 ]; do
        if ss -ltn 2>/dev/null | grep -q ":8080 "; then
            log "INFO" "WebSocket proxy restarted successfully"
            return 0
        fi
        sleep 1
        ((attempts++))
    done
    
    log "ERROR" "WebSocket proxy failed to start after restart"
    return 1
}

# Restart X server
restart_x_server() {
    log "INFO" "Restarting X server..."
    
    # This is more complex as it affects other services
    # For now, we'll try to restart the display
    pkill -f "Xvfb" 2>/dev/null || true
    sleep 2
    
    # Start Xvfb as developer user
    su - developer -c "
        export DISPLAY=:1
        Xvfb :1 -screen 0 ${SCREEN_RES:-1600x900}x${SCREEN_DEPTH:-24} -nolisten tcp >> /var/log/xvfb.log 2>&1 &
    " || {
        log "ERROR" "Failed to restart X server"
        return 1
    }
    
    sleep 2
    log "INFO" "X server restarted successfully"
    return 0
}

# Restart desktop session
restart_desktop_session() {
    log "INFO" "Restarting desktop session..."
    
    # Kill existing desktop processes
    pkill -f "xterm\\|xfce4" 2>/dev/null || true
    sleep 2
    
    # Start minimal desktop session
    su - developer -c "
        export DISPLAY=:1
        nohup xterm >> /var/log/xterm.log 2>&1 &
    " || {
        log "ERROR" "Failed to restart desktop session"
        return 1
    }
    
    log "INFO" "Desktop session restarted successfully"
    return 0
}

# Restart application
restart_application() {
    local app_name="$1"
    log "INFO" "Restarting application: $app_name"
    
    case "$app_name" in
        "lunar-client")
            if [ -f "/home/developer/lunarclient.AppImage" ] || [ -f "/home/developer/Lunar.AppImage" ]; then
                pkill -f "lunar" 2>/dev/null || true
                sleep 2
                
                # Find the Lunar client file
                local lunar_client=""
                for candidate in "/home/developer/lunarclient.AppImage" "/home/developer/Lunar.AppImage"; do
                    if [ -f "$candidate" ]; then
                        lunar_client="$candidate"
                        break
                    fi
                done
                
                if [ -n "$lunar_client" ]; then
                    su - developer -c "
                        export DISPLAY=:1
                        nohup '$lunar_client' --no-sandbox >> /home/developer/lunar_run.log 2>&1 &
                    " || {
                        log "ERROR" "Failed to restart Lunar client"
                        return 1
                    }
                    log "INFO" "Lunar client restarted successfully"
                fi
            fi
            ;;
        *)
            log "WARN" "Unknown application: $app_name"
            ;;
    esac
}

# Restart service based on type
restart_service() {
    local service_name="$1"
    
    case "$service_name" in
        "vnc-server")
            restart_vnc_server
            ;;
        "websocket-proxy")
            restart_websocket_proxy
            ;;
        "x-server")
            restart_x_server
            ;;
        "desktop-session")
            restart_desktop_session
            ;;
        "lunar-client")
            restart_application "lunar-client"
            ;;
        *)
            log "ERROR" "Unknown service: $service_name"
            return 1
            ;;
    esac
}

# Main monitoring loop
monitor_services() {
    log "INFO" "Starting service monitoring loop (check interval: ${CHECK_INTERVAL}s)"
    
    declare -A restart_counts
    declare -A last_restart_time
    
    while true; do
        for service_name in "${!SERVICES[@]}"; do
            local service_def="${SERVICES[$service_name]}"
            IFS=':' read -r process_pattern port priority <<< "$service_def"
            
            if ! check_service "$service_name"; then
                log "WARN" "Service $service_name is not healthy"
                update_service_state "$service_name" "unhealthy"
                
                # Check restart limits
                local current_time=$(date +%s)
                local last_restart=${last_restart_time[$service_name]:-0}
                local restart_count=${restart_counts[$service_name]:-0}
                
                # Reset restart count if outside the restart window
                if [ $((current_time - last_restart)) -gt $RESTART_WINDOW ]; then
                    restart_count=0
                fi
                
                if [ $restart_count -lt $MAX_RESTART_ATTEMPTS ]; then
                    log "INFO" "Attempting to restart $service_name (attempt $((restart_count + 1))/$MAX_RESTART_ATTEMPTS)"
                    
                    if restart_service "$service_name"; then
                        log "INFO" "Successfully restarted $service_name"
                        update_service_state "$service_name" "healthy"
                        restart_counts[$service_name]=0
                    else
                        restart_counts[$service_name]=$((restart_count + 1))
                        last_restart_time[$service_name]=$current_time
                        log "ERROR" "Failed to restart $service_name"
                        
                        if [ ${restart_counts[$service_name]} -ge $MAX_RESTART_ATTEMPTS ]; then
                            if [ "$priority" = "critical" ]; then
                                log "ERROR" "Critical service $service_name has failed too many times"
                                # Could implement additional alerting here
                            fi
                        fi
                    fi
                else
                    log "ERROR" "Service $service_name has exceeded maximum restart attempts"
                fi
            else
                # Service is healthy
                update_service_state "$service_name" "healthy"
                restart_counts[$service_name]=0
            fi
        done
        
        sleep $CHECK_INTERVAL
    done
}

# Save and restore application state
save_application_state() {
    log "INFO" "Saving application state..."
    
    local state_file="/var/lib/application-state"
    {
        echo "# Application state saved at $(date)"
        echo "RUNNING_APPLICATIONS="
        
        # Check for running applications
        if pgrep -f "lunar" >/dev/null 2>&1; then
            echo "lunar-client"
        fi
        
        if pgrep -f "PrismLauncher" >/dev/null 2>&1; then
            echo "prism-launcher"
        fi
    } > "$state_file"
}

# Restore application state
restore_application_state() {
    local state_file="/var/lib/application-state"
    
    if [ -f "$state_file" ]; then
        log "INFO" "Restoring application state..."
        
        # Simple state restoration
        if grep -q "lunar-client" "$state_file"; then
            log "INFO" "Restoring Lunar client..."
            restart_application "lunar-client"
        fi
    fi
}

# Main function
main() {
    # Check if already running
    if check_daemon_running; then
        echo "Session keeper daemon is already running"
        exit 1
    fi
    
    # Initialize
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$(dirname "$PID_FILE")"
    
    create_pid_file
    init_service_state
    
    log "INFO" "Session Keeper Daemon v1.0 - Ultimate Persistence & Auto-Recovery"
    log "INFO" "Monitoring ${#SERVICES[@]} services with ${CHECK_INTERVAL}s intervals"
    
    # Save current application state
    save_application_state
    
    # Start monitoring
    monitor_services
}

# Handle command line arguments
case "${1:-start}" in
    "start")
        main
        ;;
    "stop")
        if [ -f "$PID_FILE" ]; then
            local pid=$(cat "$PID_FILE")
            if kill -TERM "$pid" 2>/dev/null; then
                echo "Session keeper daemon stopped"
            else
                echo "Failed to stop daemon or daemon not running"
                rm -f "$PID_FILE"
            fi
        else
            echo "Session keeper daemon is not running"
        fi
        ;;
    "status")
        if check_daemon_running; then
            local pid=$(cat "$PID_FILE")
            echo "Session keeper daemon is running (PID: $pid)"
            if [ -f "$LOG_FILE" ]; then
                echo "Recent log entries:"
                tail -10 "$LOG_FILE"
            fi
        else
            echo "Session keeper daemon is not running"
        fi
        ;;
    "restart")
        $0 stop
        sleep 2
        $0 start
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart}"
        exit 1
        ;;
esac
