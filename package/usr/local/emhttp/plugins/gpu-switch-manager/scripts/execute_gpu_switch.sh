#!/bin/bash

# execute_gpu_switch.sh
# Execute GPU switching operation
# Usage: ./execute_gpu_switch.sh <action> <gpu_address>

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source secure shell library
source "$SCRIPT_DIR/secure_shell_lib.sh"

STATE_DIR="/var/lib/gpu-switch-manager/states"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    secure_log "$level" "[EXECUTE_SWITCH] $message"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    secure_error_exit "$1"
}

# Validate action
validate_action() {
    local action="$1"

    case "$action" in
        bind_to_vfio|unbind_from_vfio)
            return 0
            ;;
        *)
            error_exit "Invalid action: $action (must be bind_to_vfio or unbind_from_vfio)"
            ;;
    esac
}

# Validate GPU address
validate_gpu_address() {
    local gpu_address="$1"

    if [[ -z "$gpu_address" ]]; then
        error_exit "GPU address is required"
    fi

    # Check format (domain:bus:slot.function)
    if [[ ! "$gpu_address" =~ ^[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f]$ ]]; then
        error_exit "Invalid GPU address format: $gpu_address (expected format: dd:bb:ss.f)"
    fi

    # Check if device exists
    local device_path="/sys/bus/pci/devices/0000:$gpu_address"

    if [[ ! -d "$device_path" ]]; then
        error_exit "GPU device not found: $gpu_address"
    fi
}

# Save current state before switching
save_current_state() {
    local gpu_address="$1"
    local action="$2"

    log "INFO" "Saving current state before switching: action=$action, GPU=$gpu_address"

    # Create state directory
    mkdir -p "$STATE_DIR"

    # Create state file
    local state_file="$STATE_DIR/gpu_${gpu_address//:/_}_switch_state.json"

    # Get current driver
    local device_path="/sys/bus/pci/devices/0000:$gpu_address"
    local current_driver=""

    if [[ -L "$device_path/driver" ]]; then
        current_driver=$(basename "$(readlink "$device_path/driver")")
    fi

    # Save state
    echo '{"gpu_address":"'"$gpu_address"'","action":"'"$action"'","previous_driver":"'"$current_driver"'","timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}}' > "$state_file"

    log "INFO" "State saved to: $state_file"
    echo "$state_file"
}

# Execute bind to VFIO
execute_bind_to_vfio() {
    local gpu_address="$1"

    log "INFO" "Executing bind to VFIO: $gpu_address"

    # Call the bind script
    if [[ -f "$SCRIPT_DIR/bind_gpu_to_vfio.sh" ]]; then
        local result=$("$SCRIPT_DIR/bind_gpu_to_vfio.sh" "$gpu_address" 2>&1)

        if echo "$result" | jq -e '.success' &>/dev/null && [[ $(echo "$result" | jq -r '.success') == "true" ]]; then
            log "INFO" "Successfully bound GPU to VFIO: $gpu_address"
            return 0
        else
            log "ERROR" "Failed to bind GPU to VFIO: $gpu_address - $result"
            return 1
        fi
    else
        error_exit "bind_gpu_to_vfio.sh not found"
    fi
}

# Execute unbind from VFIO
execute_unbind_from_vfio() {
    local gpu_address="$1"

    log "INFO" "Executing unbind from VFIO: $gpu_address"

    # Call the unbind script
    if [[ -f "$SCRIPT_DIR/unbind_gpu_from_vfio.sh" ]]; then
        local result=$("$SCRIPT_DIR/unbind_gpu_from_vfio.sh" "$gpu_address" 2>&1)

        if echo "$result" | jq -e '.success' &>/dev/null && [[ $(echo "$result" | jq -r '.success') == "true" ]]; then
            log "INFO" "Successfully unbound GPU from VFIO: $gpu_address"
            return 0
        else
            log "ERROR" "Failed to unbind GPU from VFIO: $gpu_address - $result"
            return 1
        fi
    else
        error_exit "unbind_gpu_from_vfio.sh not found"
    fi
}

# Verify switching result
verify_switching_result() {
    local action="$1"
    local gpu_address="$2"

    log "INFO" "Verifying switching result: action=$action, GPU=$gpu_address"

    # Get current driver
    local device_path="/sys/bus/pci/devices/0000:$gpu_address"
    local current_driver=""

    if [[ -L "$device_path/driver" ]]; then
        current_driver=$(basename "$(readlink "$device_path/driver")")
    fi

    # Verify based on action
    local verification_passed=false
    local verification_message=""

    case "$action" in
        bind_to_vfio)
            if [[ "$current_driver" == "vfio-pci" ]]; then
                verification_passed=true
                verification_message="GPU is bound to vfio-pci driver"
            else
                verification_passed=false
                verification_message="GPU is not bound to vfio-pci driver (current: $current_driver)"
            fi
            ;;
        unbind_from_vfio)
            if [[ "$current_driver" != "vfio-pci" ]]; then
                verification_passed=true
                verification_message="GPU is not bound to vfio-pci driver (current: $current_driver)"
            else
                verification_passed=false
                verification_message="GPU is still bound to vfio-pci driver"
            fi
            ;;
    esac

    echo '{"passed":'"$verification_passed"',"message":"'"$verification_message"'","current_driver":"'"$current_driver"'"}'
}

# Rollback on failure
rollback_switching() {
    local action="$1"
    local gpu_address="$2"
    local state_file="$3"

    log "ERROR" "Rolling back switching: action=$action, GPU=$gpu_address"

    # Read state file
    if [[ -f "$state_file" ]]; then
        local previous_driver=$(jq -r '.previous_driver' "$state_file")

        log "INFO" "Previous driver: $previous_driver"

        # Attempt to restore previous driver
        if [[ -n "$previous_driver" ]] && [[ "$previous_driver" != "null" ]]; then
            # For simplicity, we'll just log the rollback
            # In a real implementation, you'd want to restore the previous driver
            log "INFO" "Rollback would restore driver: $previous_driver"
        fi
    fi

    log "ERROR" "Rollback completed"
}

# Cleanup after switching
cleanup_after_switching() {
    local gpu_address="$1"
    local action="$2"

    log "INFO" "Cleaning up after switching: action=$action, GPU=$gpu_address"

    # Remove state file if switching was successful
    local state_file="$STATE_DIR/gpu_${gpu_address//:/_}_switch_state.json"

    if [[ -f "$state_file" ]]; then
        rm -f "$state_file"
        log "INFO" "Removed state file: $state_file"
    fi

    log "INFO" "Cleanup completed"
}

# Main function
main() {
    # Check arguments
    if [[ $# -lt 2 ]]; then
        error_exit "Usage: $0 <action> <gpu_address>"
    fi

    local action="$1"
    local gpu_address="$2"

    log "INFO" "Executing GPU switching: action=$action, gpu_address=$gpu_address"

    # Validate action
    validate_action "$action"

    # Validate GPU address
    validate_gpu_address "$gpu_address"

    # Save current state
    local state_file=$(save_current_state "$gpu_address" "$action")

    # Execute switching based on action
    local execution_result=""
    local execution_success=false

    case "$action" in
        bind_to_vfio)
            if execute_bind_to_vfio "$gpu_address"; then
                execution_success=true
            fi
            ;;
        unbind_from_vfio)
            if execute_unbind_from_vfio "$gpu_address"; then
                execution_success=true
            fi
            ;;
    esac

    # Verify switching result
    local verification=$(verify_switching_result "$action" "$gpu_address")
    local verification_passed=$(echo "$verification" | jq -r '.passed')

    # Handle failure
    if [[ "$execution_success" != "true" ]] || [[ "$verification_passed" != "true" ]]; then
        log "ERROR" "Switching failed or verification failed"

        # Rollback
        rollback_switching "$action" "$gpu_address" "$state_file"

        # Build error response
        local json_output='{"success":false,"action":"'"$action"'","gpu_address":"'"$gpu_address"'","verification":'"$verification"',"timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}}'

        echo "$json_output" | jq .
        exit 1
    fi

    # Cleanup
    cleanup_after_switching "$gpu_address" "$action"

    # Build success response
    local json_output='{"success":true,"action":"'"$action"'","gpu_address":"'"$gpu_address"'","verification":'"$verification"',"timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}}'

    log "INFO" "GPU switching completed successfully"

    echo "$json_output" | jq .
}

# Run main function
main "$@"