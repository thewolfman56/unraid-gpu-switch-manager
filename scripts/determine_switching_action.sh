#!/bin/bash

# determine_switching_action.sh
# Determine GPU switching action from events
# Usage: ./determine_switching_action.sh <event_type> <event_data_json>

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source secure shell library
source "$SCRIPT_DIR/secure_shell_lib.sh"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    secure_log "$level" "[DETERMINE_ACTION] $message"
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
        vm_start|vm_stop|docker_start|docker_stop|manual_switch)
            return 0
            ;;
        *)
            error_exit "Invalid event type: $event_type"
            ;;
    esac
}

# Parse event data JSON
parse_event_data() {
    local event_data_json="$1"

    # Validate JSON
    if ! echo "$event_data_json" | jq . &>/dev/null; then
        error_exit "Invalid event data JSON"
    fi

    echo "$event_data_json"
}

# Get current GPU state
get_current_gpu_state() {
    local gpu_address="$1"

    log "INFO" "Getting current GPU state for: $gpu_address"

    # Get driver in use
    local driver_path="/sys/bus/pci/devices/0000:$gpu_address/driver"
    local driver_name=""

    if [[ -L "$driver_path" ]]; then
        driver_name=$(basename "$(readlink "$driver_path")")
    fi

    local is_vfio=false
    if [[ "$driver_name" == "vfio-pci" ]]; then
        is_vfio=true
    fi

    echo '{"address":"'"$gpu_address"'","driver":"'"$driver_name"'","is_vfio":'"$is_vfio"'}'
}

# Determine action for VM start
determine_vm_start_action() {
    local event_data="$1"

    local vm_name=$(echo "$event_data" | jq -r '.vm_name')

    log "INFO" "Determining action for VM start: $vm_name"

    # Get VM GPU requirements
    if [[ -f "$SCRIPT_DIR/check_vm_gpu_requirements.sh" ]]; then
        local gpu_requirements=$("$SCRIPT_DIR/check_vm_gpu_requirements.sh" "$vm_name" 2>&1)

        if echo "$gpu_requirements" | jq -e '.has_gpu' &>/dev/null && [[ $(echo "$gpu_requirements" | jq -r '.has_gpu') == "true" ]]; then
            local gpu_devices=$(echo "$gpu_requirements" | jq -r '.gpu_devices[].address')

            # For simplicity, use the first GPU device
            local gpu_address=$(echo "$gpu_devices" | head -1)

            if [[ -n "$gpu_address" ]]; then
                # Get current GPU state
                local current_state=$(get_current_gpu_state "$gpu_address")
                local is_vfio=$(echo "$current_state" | jq -r '.is_vfio')

                local action="none"
                if [[ "$is_vfio" != "true" ]]; then
                    action="bind_to_vfio"
                fi

                echo '{"success":true,"action":"'"$action"'","gpu_address":"'"$gpu_address"'","vm_name":"'"$vm_name"'","current_state":'"$current_state"',"reason":"VM requires GPU passthrough"}'
                return
            fi
        fi
    fi

    echo '{"success":true,"action":"none","gpu_address":"","vm_name":"'"$vm_name"'","reason":"VM does not require GPU passthrough"}'
}

# Determine action for VM stop
determine_vm_stop_action() {
    local event_data="$1"

    local vm_name=$(echo "$event_data" | jq -r '.vm_name')

    log "INFO" "Determining action for VM stop: $vm_name"

    # Get VM GPU requirements
    if [[ -f "$SCRIPT_DIR/check_vm_gpu_requirements.sh" ]]; then
        local gpu_requirements=$("$SCRIPT_DIR/check_vm_gpu_requirements.sh" "$vm_name" 2>&1)

        if echo "$gpu_requirements" | jq -e '.has_gpu' &>/dev/null && [[ $(echo "$gpu_requirements" | jq -r '.has_gpu') == "true" ]]; then
            local gpu_devices=$(echo "$gpu_requirements" | jq -r '.gpu_devices[].address')

            # For simplicity, use the first GPU device
            local gpu_address=$(echo "$gpu_devices" | head -1)

            if [[ -n "$gpu_address" ]]; then
                # Get current GPU state
                local current_state=$(get_current_gpu_state "$gpu_address")
                local is_vfio=$(echo "$current_state" | jq -r '.is_vfio')

                local action="none"
                if [[ "$is_vfio" == "true" ]]; then
                    action="unbind_from_vfio"
                fi

                echo '{"success":true,"action":"'"$action"'","gpu_address":"'"$gpu_address"'","vm_name":"'"$vm_name"'","current_state":'"$current_state"',"reason":"VM no longer using GPU"}'
                return
            fi
        fi
    fi

    echo '{"success":true,"action":"none","gpu_address":"","vm_name":"'"$vm_name"'","reason":"VM did not use GPU"}'
}

# Determine action for Docker start
determine_docker_start_action() {
    local event_data="$1"

    local container_name=$(echo "$event_data" | jq -r '.container_name')

    log "INFO" "Determining action for Docker start: $container_name"

    # Get container GPU requirements
    if [[ -f "$SCRIPT_DIR/check_container_gpu_requirements.sh" ]]; then
        local gpu_requirements=$("$SCRIPT_DIR/check_container_gpu_requirements.sh" "$container_name" 2>&1)

        if echo "$gpu_requirements" | jq -e '.has_gpu' &>/dev/null && [[ $(echo "$gpu_requirements" | jq -r '.has_gpu') == "true" ]]; then
            # For simplicity, use default GPU address
            local gpu_address="01:00.0"

            # Get current GPU state
            local current_state=$(get_current_gpu_state "$gpu_address")
            local is_vfio=$(echo "$current_state" | jq -r '.is_vfio')

            local action="none"
            if [[ "$is_vfio" == "true" ]]; then
                action="unbind_from_vfio"
            fi

            echo '{"success":true,"action":"'"$action"'","gpu_address":"'"$gpu_address"'","container_name":"'"$container_name"'","current_state":'"$current_state"',"reason":"Container requires GPU access"}'
            return
        fi
    fi

    echo '{"success":true,"action":"none","gpu_address":"","container_name":"'"$container_name"'","reason":"Container does not require GPU access"}'
}

# Determine action for Docker stop
determine_docker_stop_action() {
    local event_data="$1"

    local container_name=$(echo "$event_data" | jq -r '.container_name')

    log "INFO" "Determining action for Docker stop: $container_name"

    # For Docker stop, we typically don't need to switch GPU binding
    # The GPU can remain in its current state

    echo '{"success":true,"action":"none","gpu_address":"","container_name":"'"$container_name"'","reason":"Container stop does not require GPU switching"}'
}

# Determine action for manual switch
determine_manual_switch_action() {
    local event_data="$1"

    local gpu_address=$(echo "$event_data" | jq -r '.gpu_address')
    local requested_action=$(echo "$event_data" | jq -r '.action')

    log "INFO" "Determining action for manual switch: GPU=$gpu_address, action=$requested_action"

    # Get current GPU state
    local current_state=$(get_current_gpu_state "$gpu_address")
    local is_vfio=$(echo "$current_state" | jq -r '.is_vfio')

    # Validate requested action
    local action="none"
    case "$requested_action" in
        bind_to_vfio|unbind_from_vfio)
            action="$requested_action"
            ;;
        *)
            error_exit "Invalid manual switch action: $requested_action (must be bind_to_vfio or unbind_from_vfio)"
            ;;
    esac

    echo '{"success":true,"action":"'"$action"'","gpu_address":"'"$gpu_address"'","current_state":'"$current_state"',"reason":"Manual switch request"}'
}

# Main function
main() {
    # Check arguments
    if [[ $# -lt 2 ]]; then
        error_exit "Usage: $0 <event_type> <event_data_json>"
    fi

    local event_type="$1"
    local event_data_json="$2"

    log "INFO" "Determining switching action: event_type=$event_type"

    # Validate event type
    validate_event_type "$event_type"

    # Parse event data
    local event_data=$(parse_event_data "$event_data_json")

    # Determine action based on event type
    case "$event_type" in
        vm_start)
            determine_vm_start_action "$event_data"
            ;;
        vm_stop)
            determine_vm_stop_action "$event_data"
            ;;
        docker_start)
            determine_docker_start_action "$event_data"
            ;;
        docker_stop)
            determine_docker_stop_action "$event_data"
            ;;
        manual_switch)
            determine_manual_switch_action "$event_data"
            ;;
    esac
}

# Run main function
main "$@"