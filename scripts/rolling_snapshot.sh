#!/bin/bash

# Rolling Snapshot Helper - Filesystem state preservation
# Part of the Ultimate Persistent VNC Desktop Setup

set -euo pipefail

# Configuration
CONTAINER_NAME="${1:-minecraft-novnc}"
IMAGE_PREFIX="${2:-vnc_snapshot}"
OUTPUT_DIR="${3:-/var/backups}"
SNAPSHOT_INTERVAL_MINUTES="${4:-10}"
LOG_FILE="/var/log/rolling_snapshot.log"

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [rolling-snapshot] $*" | tee -a "$LOG_FILE"
}

cleanup_old_snapshots() {
    log "Cleaning up old snapshots..."
    
    # Remove snapshots older than 2 hours
    find "$OUTPUT_DIR" -name "${IMAGE_PREFIX}_*" -type f -mmin +120 -delete 2>/dev/null || true
    
    # Remove old Docker images
    docker images --filter "reference=${IMAGE_PREFIX}*" --format "table {{.Repository}}:{{.Tag}}\t{{.CreatedAt}}" | \
    tail -n +2 | \
    while read -r image_tag created_at; do
        # Convert created time and check if older than 2 hours
        local created_timestamp=$(date -d "$created_at" +%s 2>/dev/null || echo 0)
        local current_timestamp=$(date +%s)
        local age_seconds=$((current_timestamp - created_timestamp))
        
        if [ $age_seconds -gt 7200 ]; then  # 2 hours = 7200 seconds
            log "Removing old Docker image: $image_tag"
            docker rmi "$image_tag" 2>/dev/null || true
        fi
    done
}

create_snapshot() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local snapshot_name="${IMAGE_PREFIX}_${timestamp}"
    local tar_file="${OUTPUT_DIR}/${snapshot_name}.tar"
    
    log "Creating snapshot: $snapshot_name"
    
    # Check if container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log "WARNING: Container $CONTAINER_NAME is not running, skipping snapshot"
        return 1
    fi
    
    # Commit container to image
    if docker commit "$CONTAINER_NAME" "$snapshot_name" >/dev/null; then
        log "Created Docker image: $snapshot_name"
    else
        log "ERROR: Failed to create Docker image"
        return 1
    fi
    
    # Export image to tar file
    if docker save "$snapshot_name" > "$tar_file"; then
        local file_size=$(du -h "$tar_file" | cut -f1)
        log "Exported snapshot to $tar_file (size: $file_size)"
    else
        log "ERROR: Failed to export image to tar file"
        docker rmi "$snapshot_name" 2>/dev/null || true
        return 1
    fi
    
    # Clean up the Docker image (keep only tar file)
    docker rmi "$snapshot_name" 2>/dev/null || true
    
    log "Snapshot creation completed successfully"
    return 0
}

get_container_state() {
    if docker ps --format '{{.Names}}\t{{.Status}}' | grep -q "^${CONTAINER_NAME}"; then
        echo "running"
    elif docker ps -a --format '{{.Names}}\t{{.Status}}' | grep -q "^${CONTAINER_NAME}"; then
        echo "stopped"
    else
        echo "not_found"
    fi
}

restore_latest_snapshot() {
    log "Restoring from latest snapshot..."
    
    # Find the latest snapshot tar file
    local latest_snapshot=$(find "$OUTPUT_DIR" -name "${IMAGE_PREFIX}_*.tar" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)
    
    if [ -z "$latest_snapshot" ]; then
        log "ERROR: No snapshots found in $OUTPUT_DIR"
        return 1
    fi
    
    log "Found latest snapshot: $(basename "$latest_snapshot")"
    
    # Load the snapshot image
    local snapshot_image=$(basename "$latest_snapshot" .tar)
    if docker load < "$latest_snapshot" >/dev/null; then
        log "Loaded snapshot image: $snapshot_image"
    else
        log "ERROR: Failed to load snapshot image"
        return 1
    fi
    
    # Stop current container if running
    local container_state=$(get_container_state)
    if [ "$container_state" = "running" ]; then
        log "Stopping current container: $CONTAINER_NAME"
        docker stop "$CONTAINER_NAME" || true
    fi
    
    # Remove current container
    if [ "$container_state" != "not_found" ]; then
        log "Removing current container: $CONTAINER_NAME"
        docker rm "$CONTAINER_NAME" || true
    fi
    
    # Create new container from snapshot
    log "Creating new container from snapshot..."
    # Note: This is a basic restore - you may need to adjust ports, volumes, etc.
    if docker run -d \
        --name "$CONTAINER_NAME" \
        -p 8080:8080 \
        -p 5901:5901 \
        "$snapshot_image"; then
        log "Successfully restored container from snapshot"
        return 0
    else
        log "ERROR: Failed to create container from snapshot"
        return 1
    fi
}

show_snapshots() {
    echo "Available snapshots in $OUTPUT_DIR:"
    find "$OUTPUT_DIR" -name "${IMAGE_PREFIX}_*.tar" -type f -printf '%TY-%Tm-%Td %TH:%TM:%TS %s %p\n' | sort | while read -r date time size path; do
        local size_human=$(numfmt --to=iec --suffix=B "$size")
        echo "  $date $time - $(basename "$path") ($size_human)"
    done
}

# Main rolling snapshot loop
rolling_snapshot_loop() {
    log "Starting rolling snapshot service"
    log "Container: $CONTAINER_NAME, Interval: ${SNAPSHOT_INTERVAL_MINUTES}m, Output: $OUTPUT_DIR"
    
    while true; do
        # Check disk space before creating snapshot
        local available_space=$(df "$OUTPUT_DIR" --output=avail | tail -1)
        local required_space=1048576  # 1GB in KB
        
        if [ "$available_space" -lt "$required_space" ]; then
            log "WARNING: Low disk space (${available_space}KB available), cleaning up old snapshots"
            cleanup_old_snapshots
        fi
        
        # Create snapshot
        if create_snapshot; then
            log "Snapshot cycle completed successfully"
        else
            log "WARNING: Snapshot cycle failed"
        fi
        
        # Clean up old snapshots
        cleanup_old_snapshots
        
        # Wait for next interval
        log "Waiting ${SNAPSHOT_INTERVAL_MINUTES} minutes until next snapshot..."
        sleep $((SNAPSHOT_INTERVAL_MINUTES * 60))
    done
}

# Handle command line arguments
case "${5:-start}" in
    "start")
        if [ $# -lt 4 ]; then
            echo "Usage: $0 <container_name> <image_prefix> <output_dir> <interval_minutes> [start]"
            echo "Example: $0 minecraft-novnc vnc_snapshot /var/backups 10"
            exit 1
        fi
        
        log "Rolling snapshot service starting..."
        rolling_snapshot_loop
        ;;
    "snapshot")
        if [ $# -lt 3 ]; then
            echo "Usage: $0 <container_name> <image_prefix> <output_dir> [snapshot]"
            exit 1
        fi
        
        create_snapshot
        ;;
    "restore")
        if [ $# -lt 3 ]; then
            echo "Usage: $0 <container_name> <image_prefix> <output_dir> [restore]"
            exit 1
        fi
        
        restore_latest_snapshot
        ;;
    "list")
        if [ $# -lt 3 ]; then
            echo "Usage: $0 <container_name> <image_prefix> <output_dir> [list]"
            exit 1
        fi
        
        show_snapshots
        ;;
    "cleanup")
        if [ $# -lt 3 ]; then
            echo "Usage: $0 <container_name> <image_prefix> <output_dir> [cleanup]"
            exit 1
        fi
        
        cleanup_old_snapshots
        ;;
    *)
        echo "Rolling Snapshot Helper - Filesystem state preservation"
        echo ""
        echo "Usage: $0 <container_name> <image_prefix> <output_dir> <interval_minutes> [command]"
        echo ""
        echo "Commands:"
        echo "  start     - Start rolling snapshot service (default)"
        echo "  snapshot  - Create a single snapshot now"
        echo "  restore   - Restore from latest snapshot"
        echo "  list      - List available snapshots"
        echo "  cleanup   - Clean up old snapshots"
        echo ""
        echo "Example: $0 minecraft-novnc vnc_snapshot /var/backups 10 start"
        exit 1
        ;;
esac
