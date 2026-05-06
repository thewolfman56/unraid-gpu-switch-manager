#!/bin/bash

# unraid_event_handler.sh
# Unraid event handler for GPU switching
# Usage: ./unraid_event_handler.sh <event_type> [event_data...]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source secure shell library
source "$SCRIPT_DIR/secure_shell_lib.sh"
EVENT_LOG="/var/log/gpu-switch-manager/events.log"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S'
    secure_log "$level" "[UNRAID_EVENT_HANDLER] $message"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    secure_error_exit "$1"
}

# Validate event type
validate_event_type() {
    local event_type="$1"

    case "$event_type" in
        array_start|array_stop|docker_start|docker_stop|vm_start|vm_stop|custom)
            return 0
            ;;
        *)
            error_exit "Invalid event type: $event_type (must be array_start, array_stop, docker_start, docker_stop, vm_start, vm_stop, or custom)"
            ;;
    esac
}

# Parse event data
parse_event_data() {
    local event_type="$1"
    shift
    local event_data=("$@")

    case "$event_type" in
        array_start|array_stop)
            echo '{"event_type":"'"$event_type"'","timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}}'
            ;;
        docker_start|docker_stop)
            if [[ ${#event_data[@]} -lt 1 ]]; then
                echo '{"event_type":"'"$event_type"'","container_name":"","timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}}'
            else
                echo '{"event_type":"'"$event_type"'","container_name":"'"${event_data[0]}"'","timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}}'
            fi
            ;;
        vm_start|vm_stop)
            if [[ ${#event_data[@]} -lt 1 ]]; then
                echo '{"event_type":"'"$event_type"'","vm_name":"","timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}}'
            else
                echo '{"event_type":"'"$event_type"'","vm_name":"'"${event_data[0]}"'","timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}}'
            fi
            ;;
        custom)
            if [[ ${#event_data[@]} -lt 1 ]]; then
                echo '{"event_type":"custom","custom_event":"","timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}}'
            else
                echo '{"event_type":"custom","custom_event":"'"${event_data[0]}"'","timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}}'
            fi
            ;;
    esac
}

# Handle array start event
handle_array_start() {
    local event_data="$1"

    log "INFO" "Handling array start event"

    # Start Docker event monitor
    if [[ -f "$SCRIPT_DIR/docker_event_monitor.sh" ]]; then
        log "INFO" "Starting Docker event monitor"
        "$SCRIPT_DIR/docker_event_monitor.sh" start &
    fi

    # Install VM lifecycle hooks
    if [[ -f "$SCRIPT_DIR/vm_lifecycle_hooks.sh" ]]; then
        log "INFO" "Installing VM lifecycle hooks"
        "$SCRIPT_DIR/vm_lifecycle_hooks.sh" install &
    fi

    echo '{"success":true,"message":"Array start event handled","event_type":"array_start"}'
}

# Handle array stop event
handle_array_stop() {
    local event_data="$1"

    log "INFO" "Handling array stop event"

    # Stop Docker event monitor
    if [[ -f "$SCRIPT_DIR/docker_event_monitor.sh" ]]; then
        log "INFO" "Stopping Docker event monitor"
        "$SCRIPT_DIR/docker_event_monitor.sh" stop &
    fi

    # Uninstall VM lifecycle hooks
    if [[ -f "$SCRIPT_DIR/vm_lifecycle_hooks.sh" ]]; then
        log "INFO" "Uninstalling VM lifecycle hooks"
        "$SCRIPT_DIR/vm_lifecycle_hooks.sh" uninstall &
    fi

    echo '{"success":true,"message":"Array stop event handled","event_type":"array_stop"}'
}

# Handle Docker start event
handle_docker_start() {
    local event_data="$1"

    local container_name=$(echo "$event_data" | jq -r '.container_name')

    log "INFO" "Handling Docker start event: $container_name"

    # Call Docker start handler
    if [[ -f "$SCRIPT_DIR/docker_start_handler.sh" ]]; then
        local result=$("$SCRIPT_DIR/docker_start_handler.sh" "$container_name" 2>&1)
        echo "$result"
    else
        error_exit "docker_start_handler.sh not found"
    fi
}

# Handle Docker stop event
handle_docker_stop() {
    local event_data="$1"

    local container_name=$(echo "$event_data" | jq -r '.container_name')

    log "INFO" "Handling Docker stop event: $container_name"

    # Call Docker stop handler
    if [[ -f "$SCRIPT_DIR/docker_stop_handler.sh" ]]; then
        local result=$("$SCRIPT_DIR/docker_stop_handler.sh" "$container_name" 2>&1)
        echo "$result"
    else
        error_exit "docker_stop_handler.sh not found"
    fi
}

# Handle VM start event
handle_vm_start() {
    local event_data="$1"

    local vm_name=$(echo "$event_data" | jq -r '.vm_name')

    log "INFO" "Handling VM start event: $vm_name"

    # Call VM start handler
    if [[ -f "$SCRIPT_DIR/vm_start_handler.sh" ]]; then
        local result=$("$SCRIPT_DIR/vm_start_handler.sh" "$vm_name" 2>&1)
        echo "$result"
    else
        error_exit "vm_start_handler.sh not found"
    fi
}

# Handle VM stop event
handle_vm_stop() {
    local event_data="$1"

    local vm_name=$(echo "$event_data" | jq -r '.vm_name')

    log "INFO" "Handling VM stop event: $vm_name"

    # Call VM stop handler
    if [[ -f "$SCRIPT_DIR/vm_stop_handler.sh" ]]; then
        local result=$("$SCRIPT_DIR/vm_stop_handler.sh" "$vm_name" 2>&1)
        echo "$result"
    else
        error_exit "vm_stop_handler.sh not found"
    fi
}

# Handle custom event
handle_custom() {
    local event_data="$1"

    local custom_event=$(echo "$event_data" | jq -r '.custom_event')

    log "INFO" "Handling custom event: $custom_event"

    # For custom events, we just log them
    echo '{"success":true,"message":"Custom event logged","event_type":"custom","custom_event":"'"$custom_event"'"}'
}

# Main function
main() {
    # Check arguments
    if [[ $# -lt 1 ]]; then
        error_exit "Usage: $0 <event_type> [event_data...]"
    fi

    local event_type="$1"
    shift
    local event_data=("$@")

    log "INFO" "Unraid event handler triggered: event_type=$event_type, event_data=${event_data[*]}"

    # Validate event type
    validate_event_type "$event_type"

    # Parse event data
    local parsed_data=$(parse_event_data "$event_type" "${event_data[@]}")

    # Handle event based on type
    case "$event_type" in
        array_start)
            handle_array_start "$parsed_data"
            ;;
        array_stop)
            handle_array_stop "$parsed_data"
            ;;
        docker_start)
            handle_docker_start "$parsed_data"
            ;;
        docker_stop)
            handle_docker_stop "$parsed_data"
            ;;
        vm_start)
            handle_vm_start "$parsed_data"
            ;;
        vm_stop)
            handle_vm_stop "$parsed_data"
            ;;
        custom)
            handle_custom "$parsed_data"
            ;;
    esac
}

# Run main function
main "$@"