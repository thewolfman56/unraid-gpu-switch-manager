#!/bin/bash

# docker_event_monitor.sh
# Docker event monitoring daemon for automatic GPU switching
# Usage: ./docker_event_monitor.sh [start|stop|status]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source secure shell library
source "$SCRIPT_DIR/secure_shell_lib.sh"
EVENT_LOG="/var/log/gpu-switch-manager/events.log"
PID_FILE="/var/run/gpu-switch-manager/docker-event-monitor.pid"
EVENT_QUEUE_DIR="/var/run/gpu-switch-manager/events"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    secure_log "$level" "[DOCKER_EVENT_MONITOR] $message"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    secure_error_exit "$1"
}

# Check if Docker is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        error_exit "Docker command not found"
    fi

    if ! docker info &> /dev/null; then
        error_exit "Docker daemon is not accessible"
    fi
}

# Create required directories
create_directories() {
    mkdir -p "$(dirname "$PID_FILE")"
    mkdir -p "$EVENT_QUEUE_DIR"
}

# Check if monitor is running
is_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" &> /dev/null; then
            return 0
        else
            # PID file exists but process is not running
            rm -f "$PID_FILE"
            return 1
        fi
    fi
    return 1
}

# Start the monitor
start_monitor() {
    log "INFO" "Starting Docker event monitor"

    # Check if already running
    if is_running; then
        log "INFO" "Docker event monitor is already running"
        echo '{"success":true,"message":"Docker event monitor is already running","status":"running"}' | jq .
        return 0
    fi

    # Create required directories
    create_directories

    # Start monitor in background
    local monitor_log="/var/log/gpu-switch-manager/docker-event-monitor.log"

    nohup bash -c '
        # Monitor loop
        while true; do
            # Get Docker events
            docker events --format "{{.Status}}|{{.Actor.ID}}|{{.Actor.Attributes.name}}|{{.Time}}" 2>/dev/null | while IFS="|" read -r status container_id container_name timestamp; do
                # Filter for GPU-relevant events
                case "$status" in
                    start|die|stop|restart)
                        # Log the event
                        echo "[$(date +'"'"'%Y-%m-%d %H:%M:%S'"'"')] [EVENT] status=$status, container_id=$container_id, container_name=$container_name" >> "'"$EVENT_LOG"'"

                        # Queue the event for processing
                        local event_file="'"$EVENT_QUEUE_DIR"'/${container_id}_${status}_$(date +%s).json"
                        echo "{\"status\":\"$status\",\"container_id\":\"$container_id\",\"container_name\":\"$container_name\",\"timestamp\":\"$timestamp\"}" > "$event_file"

                        # Process the event
                        case "$status" in
                            start)
                                if [[ -f "'"$SCRIPT_DIR"'/docker_start_handler.sh" ]]; then
                                    "'"$SCRIPT_DIR"'/docker_start_handler.sh" "$container_name" &
                                fi
                                ;;
                            die|stop)
                                if [[ -f "'"$SCRIPT_DIR"'/docker_stop_handler.sh" ]]; then
                                    "'"$SCRIPT_DIR"'/docker_stop_handler.sh" "$container_name" &
                                fi
                                ;;
                            restart)
                                # Handle restart as stop then start
                                if [[ -f "'"$SCRIPT_DIR"'/docker_stop_handler.sh" ]]; then
                                    "'"$SCRIPT_DIR"'/docker_stop_handler.sh" "$container_name" &
                                fi
                                if [[ -f "'"$SCRIPT_DIR"'/docker_start_handler.sh" ]]; then
                                    sleep 2
                                    "'"$SCRIPT_DIR"'/docker_start_handler.sh" "$container_name" &
                                fi
                                ;;
                        esac
                        ;;
                esac
            done

            # If docker events command fails, wait and retry
            sleep 5
        done
    ' > "$monitor_log" 2>&1 &

    local pid=$!
    echo "$pid" > "$PID_FILE"

    log "INFO" "Docker event monitor started with PID: $pid"
    echo '{"success":true,"message":"Docker event monitor started","pid":'"$pid"',"status":"running"}' | jq .
}

# Stop the monitor
stop_monitor() {
    log "INFO" "Stopping Docker event monitor"

    if ! is_running; then
        log "INFO" "Docker event monitor is not running"
        echo '{"success":true,"message":"Docker event monitor is not running","status":"stopped"}' | jq .
        return 0
    fi

    local pid=$(cat "$PID_FILE")
    kill "$pid" 2>/dev/null || true

    # Wait for process to stop
    local count=0
    while ps -p "$pid" &> /dev/null && [[ $count -lt 10 ]]; do
        sleep 1
        count=$((count + 1))
    done

    # Force kill if still running
    if ps -p "$pid" &> /dev/null; then
        kill -9 "$pid" 2>/dev/null || true
    fi

    rm -f "$PID_FILE"

    log "INFO" "Docker event monitor stopped"
    echo '{"success":true,"message":"Docker event monitor stopped","status":"stopped"}' | jq .
}

# Get monitor status
get_status() {
    local running=false
    local pid=""

    if is_running; then
        running=true
        pid=$(cat "$PID_FILE")
    fi

    # Get event queue size
    local event_queue_size=0
    if [[ -d "$EVENT_QUEUE_DIR" ]]; then
        event_queue_size=$(find "$EVENT_QUEUE_DIR" -type f | wc -l)
    fi

    echo '{"running":'"$running"',"pid":"'"$pid"'","event_queue_size":'"$event_queue_size"',"pid_file":"'"$PID_FILE"'","event_queue_dir":"'"$EVENT_QUEUE_DIR"'","timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}}' | jq .
}

# Process queued events
process_queued_events() {
    log "INFO" "Processing queued events"

    if [[ ! -d "$EVENT_QUEUE_DIR" ]]; then
        log "INFO" "No event queue directory found"
        echo '{"success":true,"message":"No events to process","processed":0}' | jq .
        return 0
    fi

    local processed=0

    for event_file in "$EVENT_QUEUE_DIR"/*.json; do
        if [[ -f "$event_file" ]]; then
            # Process event
            local event_data=$(cat "$event_file")
            local status=$(echo "$event_data" | jq -r '.status')
            local container_name=$(echo "$event_data" | jq -r '.container_name')

            log "INFO" "Processing queued event: status=$status, container=$container_name"

            # Remove event file
            rm -f "$event_file"
            processed=$((processed + 1))
        fi
    done

    log "INFO" "Processed $processed queued events"
    echo '{"success":true,"message":"Processed queued events","processed":'"$processed"'}' | jq .
}

# Clean up old event files
cleanup_old_events() {
    log "INFO" "Cleaning up old event files"

    if [[ ! -d "$EVENT_QUEUE_DIR" ]]; then
        return 0
    fi

    # Remove event files older than 1 hour
    find "$EVENT_QUEUE_DIR" -type f -mmin +60 -delete

    log "INFO" "Cleaned up old event files"
    echo '{"success":true,"message":"Cleaned up old event files"}' | jq .
}

# Main function
main() {
    # Check arguments
    if [[ $# -lt 1 ]]; then
        error_exit "Usage: $0 [start|stop|status|process|cleanup]"
    fi

    local action="$1"

    log "INFO" "Docker event monitor action: $action"

    case "$action" in
        start)
            check_docker
            start_monitor
            ;;
        stop)
            stop_monitor
            ;;
        status)
            get_status
            ;;
        process)
            process_queued_events
            ;;
        cleanup)
            cleanup_old_events
            ;;
        *)
            error_exit "Unknown action: $action (must be start, stop, status, process, or cleanup)"
            ;;
    esac
}

# Run main function
main "$@"