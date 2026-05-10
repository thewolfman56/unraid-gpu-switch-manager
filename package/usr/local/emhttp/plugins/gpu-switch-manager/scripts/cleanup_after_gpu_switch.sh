#!/bin/bash

# cleanup_after_gpu_switch.sh
# Cleanup after GPU switching
# Usage: ./cleanup_after_gpu_switch.sh <action> <gpu_address> [prep_state_file]

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
    secure_log "$level" "[CLEANUP_SWITCH] $message"
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
}

# Restore service states
restore_service_states() {
    local gpu_address="$1"
    local action="$2"

    log "INFO" "Restoring service states for GPU: $gpu_address, action: $action"

    local restored_services='[]'

    # Only restore services for unbind_from_vfio action
    if [[ "$action" == "unbind_from_vfio" ]]; then
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
            error_exit "restore_service_states.sh not found"
        fi
    fi

    echo '{"restored_services":'"$restored_services"'}'
}

# Restart affected services
restart_affected_services() {
    local gpu_address="$1"
    local action="$2"

    log "INFO" "Restarting affected services for GPU: $gpu_address, action: $action"

    local restarted_services='[]'

    # Only restart services for unbind_from_vfio action
    if [[ "$action" == "unbind_from_vfio" ]]; then
        # Get GPU-dependent services
        if [[ -f "$SCRIPT_DIR/check_service_dependencies.sh" ]]; then
            local dependencies=$("$SCRIPT_DIR/check_service_dependencies.sh" "$gpu_address" 2>&1)

            # Restart Docker containers
            if echo "$dependencies" | jq -e '.gpu_dependent_containers' &>/dev/null; then
                local containers=$(echo "$dependencies" | jq -r '.gpu_dependent_containers[]')

                while IFS= read -r container; do
                    if [[ -n "$container" ]]; then
                        log "INFO" "Restarting container: $container"

                        if [[ -f "$SCRIPT_DIR/manage_docker_containers.sh" ]]; then
                            local result=$("$SCRIPT_DIR/manage_docker_containers.sh" start "$container" 2>&1)

                            if echo "$result" | jq -e '.success' &>/dev/null && [[ $(echo "$result" | jq -r '.success') == "true" ]]; then
                                restarted_services=$(echo "$restarted_services" | jq --arg container "$container" --arg type "docker" '. + [{service_name: $container, service_type: $type, action: "start", success: true}]')
                            else
                                restarted_services=$(echo "$restarted_services" | jq --arg container "$container" --arg type "docker" '. + [{service_name: $container, service_type: $type, action: "start", success: false}]')
                            fi
                        fi
                    fi
                done <<< "$containers"
            fi

            # Restart VMs
            if echo "$dependencies" | jq -e '.gpu_dependent_vms' &>/dev/null; then
                local vms=$(echo "$dependencies" | jq -r '.gpu_dependent_vms[]')

                while IFS= read -r vm; do
                    if [[ -n "$vm" ]]; then
                        log "INFO" "Restarting VM: $vm"

                        if [[ -f "$SCRIPT_DIR/manage_vm_services.sh" ]]; then
                            local result=$("$SCRIPT_DIR/manage_vm_services.sh" start "$vm" 2>&1)

                            if echo "$result" | jq -e '.success' &>/dev/null && [[ $(echo "$result" | jq -r '.success') == "true" ]]; then
                                restarted_services=$(echo "$restarted_services" | jq --arg vm "$vm" --arg type "vm" '. + [{service_name: $vm, service_type: $type, action: "start", success: true}]')
                            else
                                restarted_services=$(echo "$restarted_services" | jq --arg vm "$vm" --arg type "vm" '. + [{service_name: $vm, service_type: $type, action: "start", success: false}]')
                            fi
                        fi
                    fi
                done <<< "$vms"
            fi
        fi
    fi

    echo '{"restarted_services":'"$restarted_services"'}'
}

# Clean up temporary files
cleanup_temporary_files() {
    local gpu_address="$1"
    local action="$2"

    log "INFO" "Cleaning up temporary files for GPU: $gpu_address, action: $action"

    local cleaned_files='[]'

    # Clean up temporary VFIO config
    if [[ "$action" == "bind_to_vfio" ]]; then
        local temp_vfio_config="$TEMP_DIR/vfio_${gpu_address//:/_}.conf"

        if [[ -f "$temp_vfio_config" ]]; then
            rm -f "$temp_vfio_config"
            cleaned_files=$(echo "$cleaned_files" | jq --arg file "$temp_vfio_config" '. + [{file: $file, type: "vfio_config"}]')
            log "INFO" "Removed temporary VFIO config: $temp_vfio_config"
        fi
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

# Update GPU usage tracking
update_gpu_usage_tracking() {
    local gpu_address="$1"
    local action="$2"

    log "INFO" "Updating GPU usage tracking for GPU: $gpu_address, action: $action"

    # Create tracking directory
    local tracking_dir="/var/lib/gpu-switch-manager/tracking"
    mkdir -p "$tracking_dir"

    # Update tracking file
    local tracking_file="$tracking_dir/gpu_${gpu_address//:/_}_usage.json"

    local current_usage='{"gpu_address":"'"$gpu_address"'","current_driver":"","in_use_by":[],"last_action":"'"$action"'","last_action_time":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}}'

    # Get current driver
    local device_path="/sys/bus/pci/devices/0000:$gpu_address"
    local current_driver=""

    if [[ -L "$device_path/driver" ]]; then
        current_driver=$(basename "$(readlink "$device_path/driver")")
    fi

    current_usage=$(echo "$current_usage" | jq --arg driver "$current_driver" '.current_driver = $driver')

    # Get current usage
    local in_use_by='[]'

    if [[ "$action" == "bind_to_vfio" ]]; then
        # Check for running VMs using GPU
        if command -v virsh &> /dev/null; then
            local running_vms=$(virsh list --name --state-running 2>/dev/null || echo "")

            while IFS= read -r vm; do
                if [[ -n "$vm" ]]; then
                    if [[ -f "$SCRIPT_DIR/check_vm_gpu_requirements.sh" ]]; then
                        local vm_gpu=$("$SCRIPT_DIR/check_vm_gpu_requirements.sh" "$vm" 2>&1)

                        if echo "$vm_gpu" | jq -e '.has_gpu' &>/dev/null && [[ $(echo "$vm_gpu" | jq -r '.has_gpu') == "true" ]]; then
                            local vm_gpu_devices=$(echo "$vm_gpu" | jq -r '.gpu_devices[].address')

                            if echo "$vm_gpu_devices" | grep -q "^${gpu_address}$"; then
                                in_use_by=$(echo "$in_use_by" | jq --arg vm "$vm" --arg type "vm" '. + [{service_name: $vm, service_type: $type}]')
                            fi
                        fi
                    fi
                fi
            done <<< "$running_vms"
        fi
    elif [[ "$action" == "unbind_from_vfio" ]]; then
        # Check for running Docker containers using GPU
        if command -v docker &> /dev/null && docker info &> /dev/null; then
            local containers=$(docker ps --format '{{.Names}}' 2>/dev/null || echo "")

            while IFS= read -r container; do
                if [[ -n "$container" ]]; then
                    local gpu_usage=$(docker inspect --format='{{range .HostConfig.DeviceRequests}}{{.DeviceIDs}}{{end}}' "$container" 2>/dev/null || echo "")

                    if [[ -n "$gpu_usage" ]]; then
                        in_use_by=$(echo "$in_use_by" | jq --arg container "$container" --arg type "docker" '. + [{service_name: $container, service_type: $type}]')
                    fi
                fi
            done <<< "$containers"
        fi
    fi

    current_usage=$(echo "$current_usage" | jq --argjson in_use "$in_use_by" '.in_use_by = $in_use')

    # Write tracking file
    echo "$current_usage" > "$tracking_file"

    log "INFO" "GPU usage tracking updated: $tracking_file"
}

# Remove preparation state
remove_preparation_state() {
    local prep_state_file="$1"

    log "INFO" "Removing preparation state: $prep_state_file"

    if [[ -f "$prep_state_file" ]]; then
        rm -f "$prep_state_file"
        log "INFO" "Removed preparation state file: $prep_state_file"
    fi
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

    log "INFO" "Cleaning up after GPU switching: action=$action, gpu_address=$gpu_address"

    # Validate action
    validate_action "$action"

    # Validate GPU address
    validate_gpu_address "$gpu_address"

    # Restore service states
    local restored_services=$(restore_service_states "$gpu_address" "$action")

    # Restart affected services
    local restarted_services=$(restart_affected_services "$gpu_address" "$action")

    # Clean up temporary files
    local cleaned_files=$(cleanup_temporary_files "$gpu_address" "$action")

    # Update GPU usage tracking
    update_gpu_usage_tracking "$gpu_address" "$action"

    # Remove preparation state if provided
    if [[ -n "$prep_state_file" ]]; then
        remove_preparation_state "$prep_state_file"
    fi

    # Build JSON output
    local json_output='{"success":true,"action":"'"$action"'","gpu_address":"'"$gpu_address"'","restored_services":'"$restored_services"',"restarted_services":'"$restarted_services"',"cleaned_files":'"$cleaned_files"',"timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}}'

    log "INFO" "Cleanup completed successfully"

    echo "$json_output" | jq .
}

# Run main function
main "$@"