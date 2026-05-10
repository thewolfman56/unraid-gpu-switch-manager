#!/bin/bash

# rollback_gpu_switch.sh
# Rollback failed GPU switching
# Usage: ./rollback_gpu_switch.sh <action> <gpu_address> [prep_state_file]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source secure shell library
source "$SCRIPT_DIR/secure_shell_lib.sh"

STATE_DIR="/var/lib/gpu-switch-manager/states"
TEMP_DIR="/var/lib/gpu-switch-manager/temp"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    secure_log "$level" "[ROLLBACK_SWITCH] $message"
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

# Get previous driver from state
get_previous_driver() {
    local gpu_address="$1"

    log "INFO" "Getting previous driver for GPU: $gpu_address"

    local state_file="$STATE_DIR/gpu_${gpu_address//:/_}_switch_state.json"

    if [[ -f "$state_file" ]]; then
        local previous_driver=$(jq -r '.previous_driver' "$state_file")
        log "INFO" "Previous driver: $previous_driver"
        echo "$previous_driver"
    else
        log "INFO" "No state file found, cannot determine previous driver"
        echo ""
    fi
}

# Restore previous driver
restore_previous_driver() {
    local gpu_address="$1"
    local previous_driver="$2"

    log "INFO" "Restoring previous driver for GPU: $gpu_address, driver: $previous_driver"

    if [[ -z "$previous_driver" ]] || [[ "$previous_driver" == "null" ]]; then
        log "INFO" "No previous driver to restore"
        echo '{"success":true,"message":"No previous driver to restore"}'
        return
    fi

    # Get current driver
    local device_path="/sys/bus/pci/devices/0000:$gpu_address"
    local current_driver=""

    if [[ -L "$device_path/driver" ]]; then
        current_driver=$(basename "$(readlink "$device_path/driver")")
    fi

    # Check if already at previous driver
    if [[ "$current_driver" == "$previous_driver" ]]; then
        log "INFO" "GPU already at previous driver: $previous_driver"
        echo '{"success":true,"message":"GPU already at previous driver","current_driver":"'"$previous_driver"'"}'
        return
    fi

    # Unbind from current driver
    local unbind_path="$device_path/driver/unbind"

    if [[ -f "$unbind_path" ]]; then
        echo "${gpu_address##*/}" > "$unbind_path"
        log "INFO" "Unbound GPU from current driver: $current_driver"
    fi

    # Bind to previous driver
    local bind_path="/sys/bus/pci/drivers/$previous_driver/bind"

    if [[ -f "$bind_path" ]]; then
        echo "${gpu_address##*/}" > "$bind_path"
        log "INFO" "Bound GPU to previous driver: $previous_driver"
    else
        log "ERROR" "Failed to find bind path for driver: $previous_driver"
        echo '{"success":false,"error":"Failed to find bind path for driver","driver":"'"$previous_driver"'"}'
        return
    fi

    # Verify restoration
    local new_driver=""
    if [[ -L "$device_path/driver" ]]; then
        new_driver=$(basename "$(readlink "$device_path/driver")")
    fi

    if [[ "$new_driver" == "$previous_driver" ]]; then
        log "INFO" "Successfully restored previous driver: $previous_driver"
        echo '{"success":true,"message":"Successfully restored previous driver","previous_driver":"'"$previous_driver"'","current_driver":"'"$new_driver"'"}'
    else
        log "ERROR" "Failed to restore previous driver: expected=$previous_driver, actual=$new_driver"
        echo '{"success":false,"error":"Failed to restore previous driver","expected_driver":"'"$previous_driver"'","actual_driver":"'"$new_driver"'"}'
    fi
}

# Restore service states
restore_service_states() {
    local gpu_address="$1"

    log "INFO" "Restoring service states for GPU: $gpu_address"

    local restored_services='[]'

    # Call the state restorer
    if [[ -f "$SCRIPT_DIR/restore_service_states.sh" ]]; then
        local result=$("$SCRIPT_DIR/restore_service_states.sh" "$gpu_address" 2>&1)

        if echo "$result" | jq -e '.success' &>/dev/null && [[ $(echo "$result" | jq -r '.success') == "true" ]]; then
            log "INFO" "Service states restored successfully"

            # Get restored services from result
            if echo "$result" | jq -e '.restored_services' &>/dev/null; then
                restored_services=$(echo "$result" | jq -c '.restored_services')
            fi
        else
            log "ERROR" "Failed to restore service states: $result"
        fi
    else
        log "ERROR" "restore_service_states.sh not found"
    fi

    echo '{"restored_services":'"$restored_services"'}'
}

# Restart stopped services
restart_stopped_services() {
    local prep_state_file="$1"

    log "INFO" "Restarting stopped services from preparation state"

    local restarted_services='[]'

    if [[ -f "$prep_state_file" ]]; then
        local stopped_services=$(jq -c '.stopped_services[]' "$prep_state_file")

        while IFS= read -r service; do
            if [[ -n "$service" ]]; then
                local service_name=$(echo "$service" | jq -r '.service_name')
                local service_type=$(echo "$service" | jq -r '.service_type')

                log "INFO" "Restarting service: $service_name ($service_type)"

                local result=""
                local success=false

                case "$service_type" in
                    docker)
                        if [[ -f "$SCRIPT_DIR/manage_docker_containers.sh" ]]; then
                            result=$("$SCRIPT_DIR/manage_docker_containers.sh" start "$service_name" 2>&1)

                            if echo "$result" | jq -e '.success' &>/dev/null && [[ $(echo "$result" | jq -r '.success') == "true" ]]; then
                                success=true
                            fi
                        fi
                        ;;
                    vm)
                        if [[ -f "$SCRIPT_DIR/manage_vm_services.sh" ]]; then
                            result=$("$SCRIPT_DIR/manage_vm_services.sh" start "$service_name" 2>&1)

                            if echo "$result" | jq -e '.success' &>/dev/null && [[ $(echo "$result" | jq -r '.success') == "true" ]]; then
                                success=true
                            fi
                        fi
                        ;;
                esac

                restarted_services=$(echo "$restarted_services" | jq --arg service_name "$service_name" --arg service_type "$service_type" --argjson success "$success" '. + [{service_name: $service_name, service_type: $service_type, success: $success}]')
            fi
        done <<< "$stopped_services"
    fi

    echo '{"restarted_services":'"$restarted_services"'}'
}

# Clean up temporary files
cleanup_temporary_files() {
    local gpu_address="$1"

    log "INFO" "Cleaning up temporary files for GPU: $gpu_address"

    local cleaned_files='[]'

    # Clean up temporary VFIO config
    local temp_vfio_config="$TEMP_DIR/vfio_${gpu_address//:/_}.conf"

    if [[ -f "$temp_vfio_config" ]]; then
        rm -f "$temp_vfio_config"
        cleaned_files=$(echo "$cleaned_files" | jq --arg file "$temp_vfio_config" '. + [{file: $file, type: "vfio_config"}]')
        log "INFO" "Removed temporary VFIO config: $temp_vfio_config"
    fi

    # Clean up temporary state files
    local temp_state_pattern="$TEMP_DIR/gpu_${gpu_address//:/_}_*.tmp"

    if ls $temp_state_pattern &>/dev/null; then
        for temp_file in $temp_state_pattern; do
            if [[ -f "$temp_file" ]]; then
                rm -f "$temp_file"
                cleaned_files=$(echo "$cleaned_files" | jq --arg file "$temp_file" '. + [{file: $file, type: "state_file"}]')
                log "INFO" "Removed temporary state file: $temp_file"
            fi
        done
    fi

    echo '{"cleaned_files":'"$cleaned_files"'}'
}

# Remove state files
remove_state_files() {
    local gpu_address="$1"

    log "INFO" "Removing state files for GPU: $gpu_address"

    local removed_files='[]'

    # Remove switch state file
    local switch_state_file="$STATE_DIR/gpu_${gpu_address//:/_}_switch_state.json"

    if [[ -f "$switch_state_file" ]]; then
        rm -f "$switch_state_file"
        removed_files=$(echo "$removed_files" | jq --arg file "$switch_state_file" '. + [{file: $file, type: "switch_state"}]')
        log "INFO" "Removed switch state file: $switch_state_file"
    fi

    # Remove preparation state files
    local prep_state_pattern="$STATE_DIR/prep_${gpu_address//:/_}_*.json"

    if ls $prep_state_pattern &>/dev/null; then
        for prep_file in $prep_state_pattern; do
            if [[ -f "$prep_file" ]]; then
                rm -f "$prep_file"
                removed_files=$(echo "$removed_files" | jq --arg file "$prep_file" '. + [{file: $file, type: "prep_state"}]')
                log "INFO" "Removed preparation state file: $prep_file"
            fi
        done
    fi

    echo '{"removed_files":'"$removed_files"'}'
}

# Log rollback details
log_rollback_details() {
    local action="$1"
    local gpu_address="$2"
    local previous_driver="$3"
    local driver_restoration="$4"
    local service_restoration="$5"
    local service_restart="$6"
    local temp_cleanup="$7"
    local state_cleanup="$8"

    log "INFO" "Rollback details:"
    log "INFO" "  Action: $action"
    log "INFO" "  GPU: $gpu_address"
    log "INFO" "  Previous driver: $previous_driver"
    log "INFO" "  Driver restoration: $(echo "$driver_restoration" | jq -c '.success')"
    log "INFO" "  Service restoration: $(echo "$service_restoration" | jq -c '.restored_services | length') services"
    log "INFO" "  Service restart: $(echo "$service_restart" | jq -c '.restarted_services | length') services"
    log "INFO" "  Temp cleanup: $(echo "$temp_cleanup" | jq -c '.cleaned_files | length') files"
    log "INFO" "  State cleanup: $(echo "$state_cleanup" | jq -c '.removed_files | length') files"
}

# Main function
main() {
    # Check arguments
    if [[ $# -lt 2 ]]; then
        error_exit "Usage: $0 <action> <gpu_address> [prep_state_file]"
    fi

    local action="$1"
    local gpu_address="$2"
    local prep_state_file="${3:-}"

    log "ERROR" "Rolling back GPU switching: action=$action, gpu_address=$gpu_address"

    # Validate action
    validate_action "$action"

    # Validate GPU address
    validate_gpu_address "$gpu_address"

    # Get previous driver
    local previous_driver=$(get_previous_driver "$gpu_address")

    # Restore previous driver
    local driver_restoration=$(restore_previous_driver "$gpu_address" "$previous_driver")

    # Restore service states
    local service_restoration=$(restore_service_states "$gpu_address")

    # Restart stopped services
    local service_restart='{"restarted_services":[]}'

    if [[ -n "$prep_state_file" ]]; then
        service_restart=$(restart_stopped_services "$prep_state_file")
    fi

    # Clean up temporary files
    local temp_cleanup=$(cleanup_temporary_files "$gpu_address")

    # Remove state files
    local state_cleanup=$(remove_state_files "$gpu_address")

    # Log rollback details
    log_rollback_details "$action" "$gpu_address" "$previous_driver" "$driver_restoration" "$service_restoration" "$service_restart" "$temp_cleanup" "$state_cleanup"

    # Build JSON output
    local json_output='{"success":true,"action":"'"$action"'","gpu_address":"'"$gpu_address"'","previous_driver":"'"$previous_driver"'","driver_restoration":'"$driver_restoration"',"service_restoration":'"$service_restoration"',"service_restart":'"$service_restart"',"temp_cleanup":'"$temp_cleanup"',"state_cleanup":'"$state_cleanup"',"timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}}'

    log "ERROR" "Rollback completed"

    echo "$json_output" | jq .
}

# Run main function
main "$@"