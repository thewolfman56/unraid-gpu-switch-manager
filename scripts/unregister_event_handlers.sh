#!/bin/bash

# unregister_event_handlers.sh
# Unregister event handlers from Unraid
# Usage: ./unregister_event_handlers.sh

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source secure shell library
source "$SCRIPT_DIR/secure_shell_lib.sh"
UNRAID_EVENT_DIR="/usr/local/emhttp/webGui/event_handlers"
PLUGIN_EVENT_DIR="/usr/local/emhttp/plugins/gpu-switch-manager/event_handlers"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S'
    secure_log "$level" "[UNREGISTER_HANDLERS] $message"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    secure_error_exit "$1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root"
    fi
}

# Unregister array start handler
unregister_array_start_handler() {
    log "INFO" "Unregistering array start handler"

    local handler_file="$UNRAID_EVENT_DIR/gpu-switch-array-start"

    if [[ -f "$handler_file" ]]; then
        rm -f "$handler_file"
        log "INFO" "Unregistered array start handler: $handler_file"
    else
        log "INFO" "Array start handler not found, skipping"
    fi
}

# Unregister array stop handler
unregister_array_stop_handler() {
    log "INFO" "Unregistering array stop handler"

    local handler_file="$UNRAID_EVENT_DIR/gpu-switch-array-stop"

    if [[ -f "$handler_file" ]]; then
        rm -f "$handler_file"
        log "INFO" "Unregistered array stop handler: $handler_file"
    else
        log "INFO" "Array stop handler not found, skipping"
    fi
}

# Unregister Docker service start handler
unregister_docker_start_handler() {
    log "INFO" "Unregistering Docker service start handler"

    local handler_file="$UNRAID_EVENT_DIR/gpu-switch-docker-start"

    if [[ -f "$handler_file" ]]; then
        rm -f "$handler_file"
        log "INFO" "Unregistered Docker service start handler: $handler_file"
    else
        log "INFO" "Docker service start handler not found, skipping"
    fi
}

# Unregister Docker service stop handler
unregister_docker_stop_handler() {
    log "INFO" "Unregistering Docker service stop handler"

    local handler_file="$UNRAID_EVENT_DIR/gpu-switch-docker-stop"

    if [[ -f "$handler_file" ]]; then
        rm -f "$handler_file"
        log "INFO" "Unregistered Docker service stop handler: $handler_file"
    else
        log "INFO" "Docker service stop handler not found, skipping"
    fi
}

# Unregister VM service start handler
unregister_vm_start_handler() {
    log "INFO" "Unregistering VM service start handler"

    local handler_file="$UNRAID_EVENT_DIR/gpu-switch-vm-start"

    if [[ -f "$handler_file" ]]; then
        rm -f "$handler_file"
        log "INFO" "Unregistered VM service start handler: $handler_file"
    else
        log "INFO" "VM service start handler not found, skipping"
    fi
}

# Unregister VM service stop handler
unregister_vm_stop_handler() {
    log "INFO" "Unregistering VM service stop handler"

    local handler_file="$UNRAID_EVENT_DIR/gpu-switch-vm-stop"

    if [[ -f "$handler_file" ]]; then
        rm -f "$handler_file"
        log "INFO" "Unregistered VM service stop handler: $handler_file"
    else
        log "INFO" "VM service stop handler not found, skipping"
    fi
}

# Clean up plugin event directory
cleanup_plugin_event_directory() {
    log "INFO" "Cleaning up plugin event directory"

    if [[ -d "$PLUGIN_EVENT_DIR" ]]; then
        # Remove configuration files
        rm -f "$PLUGIN_EVENT_DIR/priority.conf"
        rm -f "$PLUGIN_EVENT_DIR/filter.conf"

        # Remove directory if empty
        if [[ -z "$(ls -A "$PLUGIN_EVENT_DIR")" ]]; then
            rmdir "$PLUGIN_EVENT_DIR"
            log "INFO" "Removed empty plugin event directory: $PLUGIN_EVENT_DIR"
        else
            log "INFO" "Plugin event directory not empty, keeping: $PLUGIN_EVENT_DIR"
        fi
    else
        log "INFO" "Plugin event directory not found, skipping"
    fi
}

# Verify handler removal
verify_handler_removal() {
    log "INFO" "Verifying handler removal"

    local all_removed=true
    local remaining_handlers='[]'

    # Check array start handler
    if [[ -f "$UNRAID_EVENT_DIR/gpu-switch-array-start" ]]; then
        all_removed=false
        remaining_handlers=$(echo "$remaining_handlers" | jq '. + ["array_start"]')
        log "ERROR" "Array start handler still exists"
    fi

    # Check array stop handler
    if [[ -f "$UNRAID_EVENT_DIR/gpu-switch-array-stop" ]]; then
        all_removed=false
        remaining_handlers=$(echo "$remaining_handlers" | jq '. + ["array_stop"]')
        log "ERROR" "Array stop handler still exists"
    fi

    # Check Docker start handler
    if [[ -f "$UNRAID_EVENT_DIR/gpu-switch-docker-start" ]]; then
        all_removed=false
        remaining_handlers=$(echo "$remaining_handlers" | jq '. + ["docker_start"]')
        log "ERROR" "Docker start handler still exists"
    fi

    # Check Docker stop handler
    if [[ -f "$UNRAID_EVENT_DIR/gpu-switch-docker-stop" ]]; then
        all_removed=false
        remaining_handlers=$(echo "$remaining_handlers" | jq '. + ["docker_stop"]')
        log "ERROR" "Docker stop handler still exists"
    fi

    # Check VM start handler
    if [[ -f "$UNRAID_EVENT_DIR/gpu-switch-vm-start" ]]; then
        all_removed=false
        remaining_handlers=$(echo "$remaining_handlers" | jq '. + ["vm_start"]')
        log "ERROR" "VM start handler still exists"
    fi

    # Check VM stop handler
    if [[ -f "$UNRAID_EVENT_DIR/gpu-switch-vm-stop" ]]; then
        all_removed=false
        remaining_handlers=$(echo "$remaining_handlers" | jq '. + ["vm_stop"]')
        log "ERROR" "VM stop handler still exists"
    fi

    echo '{"all_removed":'"$all_removed"',"remaining_handlers":'"$remaining_handlers"'}'
}

# Main function
main() {
    log "INFO" "Unregistering event handlers"

    # Check if running as root
    check_root

    # Unregister handlers
    unregister_array_start_handler
    unregister_array_stop_handler
    unregister_docker_start_handler
    unregister_docker_stop_handler
    unregister_vm_start_handler
    unregister_vm_stop_handler

    # Clean up plugin event directory
    cleanup_plugin_event_directory

    # Verify handler removal
    local test_result=$(verify_handler_removal)
    local all_removed=$(echo "$test_result" | jq -r '.all_removed')

    if [[ "$all_removed" == "true" ]]; then
        log "INFO" "All event handlers unregistered successfully"
        echo '{"success":true,"message":"All event handlers unregistered successfully","test_result":'"$test_result"'}' | jq .
    else
        log "ERROR" "Some event handlers failed to unregister"
        echo '{"success":false,"message":"Some event handlers failed to unregister","test_result":'"$test_result"'}' | jq .
        exit 1
    fi
}

# Run main function
main "$@"