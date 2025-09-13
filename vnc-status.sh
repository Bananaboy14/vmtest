#!/bin/bash

# VNC Status Script - Comprehensive System Health Monitoring
# Part of the Ultimate Persistent VNC Desktop Setup

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Unicode symbols
CHECK_MARK="✅"
CROSS_MARK="❌"
WARNING="⚠️"
INFO="ℹ️"
ROCKET="🚀"
DESKTOP="🖥️"
NETWORK="🌐"
HEALTH="🏥"
TIMER="⏱️"

echo -e "${WHITE}${HEALTH} VNC Desktop Health Report${NC}"
echo -e "${WHITE}===============================================${NC}"
echo -e "${CYAN}$(date)${NC}"
echo ""

# Function to check if a service is running
check_service() {
    local service_name="$1"
    local process_pattern="$2"
    local port="$3"
    
    echo -ne "${WHITE}${service_name}:${NC} "
    
    local process_running=false
    local port_listening=false
    
    # Check if process is running
    if pgrep -f "$process_pattern" >/dev/null 2>&1; then
        process_running=true
    fi
    
    # Check if port is listening (if port specified)
    if [ "$port" != "-" ]; then
        if ss -ltn 2>/dev/null | grep -q ":$port "; then
            port_listening=true
        fi
    else
        port_listening=true  # No port to check
    fi
    
    # Determine status
    if $process_running && $port_listening; then
        echo -e "${GREEN}${CHECK_MARK} Running${NC}"
        return 0
    elif $process_running; then
        echo -e "${YELLOW}${WARNING} Process running but port not listening${NC}"
        return 1
    elif $port_listening; then
        echo -e "${YELLOW}${WARNING} Port listening but process not found${NC}"
        return 1
    else
        echo -e "${RED}${CROSS_MARK} Not running${NC}"
        return 2
    fi
}

# Function to check system resource usage
check_resources() {
    echo -e "${WHITE}${INFO} System Resources:${NC}"
    
    # Memory usage
    local mem_info=$(free -h | grep "Mem:")
    local mem_used=$(echo $mem_info | awk '{print $3}')
    local mem_total=$(echo $mem_info | awk '{print $2}')
    local mem_percent=$(free | grep "Mem:" | awk '{printf("%.1f"), ($3/$2) * 100.0}')
    echo -e "  Memory: ${CYAN}${mem_used}${NC}/${CYAN}${mem_total}${NC} (${mem_percent}%)"
    
    # CPU load
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ *//')
    echo -e "  Load Average: ${CYAN}${load_avg}${NC}"
    
    # Disk usage for important directories
    echo -e "  Disk Usage:"
    df -h / | tail -1 | awk '{printf("    Root: %s/%s (%s)\n", $3, $2, $5)}'
    if [ -d /home/developer ]; then
        du -sh /home/developer 2>/dev/null | awk '{printf("    Developer Home: %s\n", $1)}' || echo "    Developer Home: N/A"
    fi
    if [ -d /tmp ]; then
        du -sh /tmp 2>/dev/null | awk '{printf("    /tmp: %s\n", $1)}' || echo "    /tmp: N/A"
    fi
}

# Function to check VNC-specific details
check_vnc_details() {
    echo -e "${WHITE}${DESKTOP} VNC Server Details:${NC}"
    
    # Check for VNC server processes
    local vnc_processes=$(ps aux | grep -E "(Xvnc|Xtigervnc|x11vnc)" | grep -v grep | wc -l)
    echo -e "  Active VNC processes: ${CYAN}${vnc_processes}${NC}"
    
    # List VNC sessions
    if [ -d /home/developer/.vnc ]; then
        echo -e "  VNC session files:"
        for session_file in /home/developer/.vnc/*.pid; do
            if [ -f "$session_file" ]; then
                local display=$(basename "$session_file" .pid)
                local pid=$(cat "$session_file" 2>/dev/null || echo "N/A")
                if [ "$pid" != "N/A" ] && kill -0 "$pid" 2>/dev/null; then
                    echo -e "    ${GREEN}${CHECK_MARK}${NC} $display (PID: $pid)"
                else
                    echo -e "    ${RED}${CROSS_MARK}${NC} $display (stale)"
                fi
            fi
        done
    fi
    
    # Check VNC ports
    echo -e "  VNC ports in use:"
    ss -ltn | grep -E ":(590[0-9]|5901)" | while read line; do
        local port=$(echo "$line" | awk '{print $4}' | cut -d':' -f2)
        echo -e "    ${GREEN}${CHECK_MARK}${NC} Port $port"
    done
    
    # Display information
    if [ -n "${DISPLAY:-}" ]; then
        echo -e "  Current DISPLAY: ${CYAN}${DISPLAY}${NC}"
    else
        echo -e "  Current DISPLAY: ${RED}Not set${NC}"
    fi
    
    # X authority
    if [ -f "/home/developer/.Xauthority" ]; then
        echo -e "  X Authority: ${GREEN}${CHECK_MARK} Present${NC}"
    else
        echo -e "  X Authority: ${YELLOW}${WARNING} Missing${NC}"
    fi
}

# Function to check network connectivity
check_network() {
    echo -e "${WHITE}${NETWORK} Network Status:${NC}"
    
    # Check if we can resolve DNS
    if nslookup google.com >/dev/null 2>&1; then
        echo -e "  DNS Resolution: ${GREEN}${CHECK_MARK} Working${NC}"
    else
        echo -e "  DNS Resolution: ${RED}${CROSS_MARK} Failed${NC}"
    fi
    
    # Check external connectivity
    if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        echo -e "  External Connectivity: ${GREEN}${CHECK_MARK} Working${NC}"
    else
        echo -e "  External Connectivity: ${RED}${CROSS_MARK} Failed${NC}"
    fi
    
    # Show listening ports
    echo -e "  Listening ports:"
    ss -ltn | grep -E ":(8080|590[0-9]|5901)" | while read line; do
        local port=$(echo "$line" | awk '{print $4}' | cut -d':' -f2)
        local addr=$(echo "$line" | awk '{print $4}' | cut -d':' -f1)
        if [ "$addr" = "0.0.0.0" ] || [ "$addr" = "*" ]; then
            echo -e "    ${GREEN}${CHECK_MARK}${NC} Port $port (all interfaces)"
        else
            echo -e "    ${CYAN}${INFO}${NC} Port $port ($addr)"
        fi
    done
}

# Function to check logs for errors
check_logs() {
    echo -e "${WHITE}📋 Recent Log Activity:${NC}"
    
    local log_files=(
        "/var/log/novnc.log"
        "/var/log/vncserver.log"
        "/var/log/x11vnc.log"
        "/var/log/novnc_proxy.log"
        "/home/developer/.vnc/*.log"
    )
    
    for log_pattern in "${log_files[@]}"; do
        for log_file in $log_pattern; do
            if [ -f "$log_file" ]; then
                local log_name=$(basename "$log_file")
                local error_count=$(grep -i error "$log_file" 2>/dev/null | tail -5 | wc -l)
                local recent_entries=$(tail -5 "$log_file" 2>/dev/null | wc -l)
                
                if [ "$error_count" -gt 0 ]; then
                    echo -e "  ${RED}${WARNING}${NC} $log_name: $error_count recent errors, $recent_entries total entries"
                    echo -e "    ${RED}Recent errors:${NC}"
                    grep -i error "$log_file" 2>/dev/null | tail -3 | sed 's/^/      /' || true
                else
                    echo -e "  ${GREEN}${CHECK_MARK}${NC} $log_name: No recent errors, $recent_entries total entries"
                fi
            fi
        done
    done
}

# Function to check application status
check_applications() {
    echo -e "${WHITE}🎮 Application Status:${NC}"
    
    # Check for Minecraft/Lunar Client
    if pgrep -f "lunar" >/dev/null 2>&1; then
        echo -e "  Lunar Client: ${GREEN}${CHECK_MARK} Running${NC}"
    elif [ -f "/home/developer/lunarclient.AppImage" ] || [ -f "/home/developer/Lunar.AppImage" ]; then
        echo -e "  Lunar Client: ${YELLOW}${WARNING} Available but not running${NC}"
    else
        echo -e "  Lunar Client: ${CYAN}${INFO} Not installed${NC}"
    fi
    
    # Check for Prism Launcher
    if pgrep -f "PrismLauncher" >/dev/null 2>&1; then
        echo -e "  Prism Launcher: ${GREEN}${CHECK_MARK} Running${NC}"
    elif [ -f "/home/developer/PrismLauncher.AppImage" ]; then
        echo -e "  Prism Launcher: ${YELLOW}${WARNING} Available but not running${NC}"
    else
        echo -e "  Prism Launcher: ${CYAN}${INFO} Not installed${NC}"
    fi
    
    # Check for desktop environment
    if pgrep -f "xfce4" >/dev/null 2>&1; then
        echo -e "  XFCE Desktop: ${GREEN}${CHECK_MARK} Running${NC}"
    elif pgrep -f "xterm" >/dev/null 2>&1; then
        echo -e "  Desktop Session: ${GREEN}${CHECK_MARK} Running (minimal)${NC}"
    else
        echo -e "  Desktop Session: ${RED}${CROSS_MARK} Not running${NC}"
    fi
}

# Function to show uptime and performance
check_uptime() {
    echo -e "${WHITE}${TIMER} System Uptime & Performance:${NC}"
    
    local uptime_info=$(uptime -p)
    echo -e "  System Uptime: ${CYAN}${uptime_info}${NC}"
    
    # Container uptime (approximate)
    if [ -f "/proc/1/stat" ]; then
        local container_start=$(stat -c %Y /proc/1/stat 2>/dev/null || echo "0")
        local current_time=$(date +%s)
        local container_uptime=$((current_time - container_start))
        local container_uptime_human=$(date -d @$container_uptime -u +%H:%M:%S)
        echo -e "  Container Uptime: ${CYAN}~${container_uptime_human}${NC}"
    fi
    
    # VNC session uptime (if VNC server is running)
    if pgrep -f "Xvnc\\|Xtigervnc" >/dev/null 2>&1; then
        local vnc_pid=$(pgrep -f "Xvnc\\|Xtigervnc" | head -1)
        if [ -n "$vnc_pid" ]; then
            local vnc_uptime=$(ps -o etime= -p "$vnc_pid" 2>/dev/null | tr -d ' ' || echo "unknown")
            echo -e "  VNC Session Uptime: ${CYAN}${vnc_uptime}${NC}"
        fi
    fi
}

# Main execution
echo -e "${WHITE}${ROCKET} Core Services Status:${NC}"

# Check core services
service_status=0

check_service "VNC Server (TigerVNC)" "tigervnc\\|Xtigervnc" "5901" || service_status=$?
check_service "WebSocket Proxy" "websockify\\|novnc_proxy\\|node.*index.js" "8080" || service_status=$?
check_service "X11 Server" "Xvfb\\|Xvnc\\|Xtigervnc" "-" || service_status=$?

echo ""

# Additional checks
check_resources
echo ""

check_vnc_details
echo ""

check_network
echo ""

check_applications
echo ""

check_uptime
echo ""

check_logs
echo ""

# Overall health summary
echo -e "${WHITE}===============================================${NC}"
if [ $service_status -eq 0 ]; then
    echo -e "${GREEN}${HEALTH} Overall System Health: EXCELLENT${NC}"
    echo -e "${GREEN}All critical services are running normally.${NC}"
    exit_code=0
elif [ $service_status -eq 1 ]; then
    echo -e "${YELLOW}${HEALTH} Overall System Health: WARNING${NC}"
    echo -e "${YELLOW}Some services have minor issues but system is functional.${NC}"
    exit_code=1
else
    echo -e "${RED}${HEALTH} Overall System Health: CRITICAL${NC}"
    echo -e "${RED}Critical services are not running. Manual intervention required.${NC}"
    exit_code=2
fi

echo -e "${CYAN}Run this script again anytime: docker exec minecraft-novnc vnc-status.sh${NC}"
echo ""

exit $exit_code
