#!/bin/bash

# auto_gpu_switch.sh
# Automatic GPU switching logic based on events
# Usage: ./auto_gpu_switch.sh <event_type> <event_data>

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source secure shell library
source "$SCRIPT_DIR/secure_shell_lib.sh"

LOG_FILE="/var/log/gpu.switch.manager.log"
EVENT_LOG="/var/log/gpu-switch-manager/events.log"
SWITCHING_DIR="/var/run/gpu-switch-manager/switching"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    secure_log "$level" "[AUTO_GPU_SWITCH] $message"
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
            error_exit "Invalid event type: $event_type (must be vm_start, vm_stop, docker_start, docker_stop, or manual_switch)"
            ;;
    esac
}

# Parse event data
parse_event_data() {
    local event_type="$1"
    shift
    local event_data=("$@")

    case "$event_type" in
        vm_start|vm_stop)
            if [[ ${#event_data[@]} -lt 1 ]]; then
                error_exit "VM event requires vm_name parameter"
            fi
            echo '{"event_type":"'"$event_type"'","vm_name":"'"${event_data[0]}"'"}'
            ;;
        docker_start|docker_stop)
            if [[ ${#event_data[@]} -lt 1 ]]; then
                error_exit "Docker event requires container_name parameter"
            fi
            echo '{"event_type":"'"$event_type"'","container_name":"'"${event_data[0]}"'"}'
            ;;
        manual_switch)
            if [[ ${#event_data[@]} -lt 2 ]]; then
                error_exit "Manual switch requires gpu_address and action parameters"
            fi
            echo '{"event_type":"'"$event_type"'","gpu_address":"'"${event_data[0]}"'","action":"'"${event_data[1]}"'"}'
            ;;
    esac
}

# Determine switching action
determine_switching_action() {
    local event_type="$1"
    local event_data="$2"

    log "INFO" "Determining switching action for event: $event_type"

    # Call the determine action script
    if [[ -f "$SCRIPT_DIR/determine_switching_action.sh" ]]; then
        local result=$("$SCRIPT_DIR/determine_switching_action.sh" "$event_type" "$event_data" 2>&1)

        if echo "$result" | jq -e '.success' &>/dev/null && [[ $(echo "$result" | jq -r '.success') == "true" ]]; then
            log "INFO" "Switching action determined: $result"
            echo "$result"
            return 0
        else
            log "ERROR" "Failed to determine switching action: $result"
            echo '{"success":false,"error":"Failed to determine switching action"}'
            return 1
        fi
    else
        error_exit "determine_switching_action.sh not found"
    fi
}

# Validate switching safety
validate_switching_safety() {
    local action="$1"
    local gpu_address="$2"

    log "INFO" "Validating switching safety for action: $action, GPU: $gpu_address"

    # Call the validate safety script
    if [[ -f "$SCRIPT_DIR/validate_switching_safety.sh" ]]; then
        local result=$("$SCRIPT_DIR/validate_switching_safety.sh" "$action" "$gpu_address" 2>&1)

        if echo "$result" | jq -e '.success' &>/dev/null && [[ $(echo "$result" | jq -r '.success') == "true" ]]; then
            local is_safe=$(echo "$result" | jq -r '.is_safe')

            if [[ "$is_safe" == "true" ]]; then
                log "INFO" "Switching is safe: $result"
                echo "$result"
                return 0
            else
                log "ERROR" "Switching is not safe: $result"
                echo "$result"
                return 1
            fi
        else
            log "ERROR" "Failed to validate switching safety: $result"
            echo '{"success":false,"error":"Failed to validate switching safety"}'
            return 1
        fi
    else
        error_exit "validate_switching_safety.sh not found"
    fi
}

# Execute GPU switching
execute_gpu_switch() {
    local action="$1"
    local gpu_address="$2"

    log "INFO" "Executing GPU switching for action: $action, GPU: $gpu_address"

    # Create switching directory
    mkdir -p "$SWITCHING_DIR"

    # Create switching operation file
    local operation_id="switch_$(date +%s)_$RANDOM"
    local operation_file="$SWITCHING_DIR/${operation_id}.json"

    echo '{"operation_id":"'"$operation_id"'","action":"'"$action"'","gpu_address":"'"$gpu_address"'","status":"in_progress","start_time":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"","end_time":null}' > "$operation_file"

    # Call the execute switch script
    if [[ -f "$SCRIPT_DIR/execute_gpu_switch.sh" ]]; then
        local result=$("$SCRIPT_DIR/execute_gpu_switch.sh" "$action" "$gpu_address" 2>&1)

        # Update operation file
        local end_time=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
        local operation_status="completed"

        if echo "$result" | jq -e '.success' &>/dev/null && [[ $(echo "$result" | jq -r '.success') == "true" ]]; then
            log "INFO" "GPU switching completed successfully: $result"
        else
            log "ERROR" "GPU switching failed: $result"
            operation_status="failed"
        fi

        # Update operation file
        local updated_operation=$(jq --arg status "$operation_status" --arg end_time "$end_time" '.status = $status | .end_time = $end_time' "$operation_file")
        echo "$updated_operation" > "$operation_file"

        # Add operation ID to result
        local final_result=$(echo "$result" | jq --arg operation_id "$operation_id" '. + {"operation_id": $operation_id}')

        echo "$final_result"
        return 0
    else
        error_exit "execute_gpu_switch.sh not found"
    fi
}

# Handle VM start event
handle_vm_start_event() {
    local vm_name="$1"

    log "INFO" "Handling VM start event: $vm_name"

    # Call VM start handler
    if [[ -f "$SCRIPT_DIR/vm_start_handler.sh" ]]; then
        local result=$("$SCRIPT_DIR/vm_start_handler.sh" "$vm_name" 2>&1)

        if echo "$result" | jq -e '.success' &>/dev/null && [[ $(echo "$result" | jq -r '.success') == "true" ]]; then
            log "INFO" "VM start event handled successfully: $result"
            echo "$result"
            return 0
        else
            log "ERROR" "Failed to handle VM start event: $result"
            echo "$result"
            return 1
        fi
    else
        error_exit "vm_start_handler.sh not found"
    fi
}

# Handle VM stop event
handle_vm_stop_event() {
    local vm_name="$1"

    log "INFO" "Handling VM stop event: $vm_name"

    # Call VM stop handler
    if [[ -f "$SCRIPT_DIR/vm_stop_handler.sh" ]]; then
        local result=$("$SCRIPT_DIR/vm_stop_handler.sh" "$vm_name" 2>&1)

        if echo "$result" | jq -e '.success' &>/dev/null && [[ $(echo "$result" | jq -r '.success') == "true" ]]; then
            log "INFO" "VM stop event handled successfully: $result"
            echo "$result"
            return 0
        else
            log "ERROR" "Failed to handle VM stop event: $result"
            echo "$result"
            return 1
        fi
    else
        error_exit "vm_stop_handler.sh not found"
    fi
}

# Handle Docker start event
handle_docker_start_event() {
    local container_name="$1"

    log "INFO" "Handling Docker start event: $container_name"

    # Call Docker start handler
    if [[ -f "$SCRIPT_DIR/docker_start_handler.sh" ]]; then
        local result=$("$SCRIPT_DIR/docker_start_handler.sh" "$container_name" 2>&1)

        if echo "$result" | jq -e '.success' &>/dev/null && [[ $(echo "$result" | jq -r '.success') == "true" ]]; then
            log "INFO" "Docker start event handled successfully: $result"
            echo "$result"
            return 0
        else
            log "ERROR" "Failed to handle Docker start event: $result"
            echo "$result"
            return 1
        fi
    else
        error_exit "docker_start_handler.sh not found"
    fi
}

# Handle Docker stop event
handle_docker_stop_event() {
    local container_name="$1"

    log "INFO" "Handling Docker stop event: $container_name"

    # Call Docker stop handler
    if [[ -f "$SCRIPT_DIR/docker_stop_handler.sh" ]]; then
        local result=$("$SCRIPT_DIR/docker_stop_handler.sh" "$container_name" 2>&1)

        if echo "$result" | jq -e '.success' &>/dev/null && [[ $(echo "$result" | jq -r '.success') == "true" ]]; then
            log "INFO" "Docker stop event handled successfully: $result"
            echo "$result"
            return 0
        else
            log "ERROR" "Failed to handle Docker stop event: $result"
            echo "$result"
            return 1
        fi
    else
        error_exit "docker_stop_handler.sh not found"
    fi
}

# Main function
main() {
    # Check arguments
    if [[ $# -lt 1 ]]; then
        secure_error_exit "Usage: $0 <event_type> [event_data...]"
    fi

    local event_type="$1"
    shift
    local event_data=("$@")

    log "INFO" "Auto GPU switch triggered: event_type=$event_type, event_data=${event_data[*]}"

    # Validate event type
    validate_event_type "$event_type"

    # Parse event data
    local parsed_data=$(parse_event_data "$event_type" "${event_data[@]}")

    # Handle event based on type
    case "$event_type" in
        vm_start)
            local vm_name=$(echo "$parsed_data" | jq -r '.vm_name')
            handle_vm_start_event "$vm_name"
            ;;
        vm_stop)
            local vm_name=$(echo "$parsed_data" | jq -r '.vm_name')
            handle_vm_stop_event "$vm_name"
            ;;
        docker_start)
            local container_name=$(echo "$parsed_data" | jq -r '.container_name')
            handle_docker_start_event "$container_name"
            ;;
        docker_stop)
            local container_name=$(echo "$parsed_data" | jq -r '.container_name')
            handle_docker_stop_event "$container_name"
            ;;
        manual_switch)
            local gpu_address=$(echo "$parsed_data" | jq -r '.gpu_address')
            local action=$(echo "$parsed_data" | jq -r '.action')

            # Determine switching action
            local action_result=$(determine_switching_action "$event_type" "$parsed_data")

            if [[ $(echo "$action_result" | jq -r '.success') != "true" ]]; then
                echo "$action_result"
                exit 1
            fi

            # Validate switching safety
            local safety_result=$(validate_switching_safety "$action" "$gpu_address")

            if [[ $(echo "$safety_result" | jq -r '.is_safe') != "true" ]]; then
                echo "$safety_result"
                exit 1
            fi

            # Execute GPU switching
            execute_gpu_switch "$action" "$gpu_address"
            ;;
    esac
}

# Run main function
main "$@"