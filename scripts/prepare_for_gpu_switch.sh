#!/bin/bash

# prepare_for_gpu_switch.sh
# Prepare system for GPU switching
# Usage: ./prepare_for_gpu_switch.sh <action> <gpu_address>

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
    secure_log "$level" "[PREPARE_SWITCH] $message"
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

# Create required directories
create_directories() {
    log "INFO" "Creating required directories"

    mkdir -p "$STATE_DIR"
    mkdir -p "$TEMP_DIR"

    log "INFO" "Directories created successfully"
}

# Stop conflicting services
stop_conflicting_services() {
    local gpu_address="$1"
    local action="$2"

    log "INFO" "Stopping conflicting services for GPU: $gpu_address, action: $action"

    local stopped_services='[]'

    # Only stop services for bind_to_vfio action
    if [[ "$action" == "bind_to_vfio" ]]; then
        # Get GPU-dependent services
        if [[ -f "$SCRIPT_DIR/check_service_dependencies.sh" ]]; then
            local dependencies=$("$SCRIPT_DIR/check_service_dependencies.sh" "$gpu_address" 2>&1)

            # Stop Docker containers
            if echo "$dependencies" | jq -e '.gpu_dependent_containers' &>/dev/null; then
                local containers=$(echo "$dependencies" | jq -r '.gpu_dependent_containers[]')

                while IFS= read -r container; do
                    if [[ -n "$container" ]]; then
                        log "INFO" "Stopping container: $container"

                        if [[ -f "$SCRIPT_DIR/manage_docker_containers.sh" ]]; then
                            local result=$("$SCRIPT_DIR/manage_docker_containers.sh" stop "$container" 2>&1)

                            if echo "$result" | jq -e '.success' &>/dev/null && [[ $(echo "$result" | jq -r '.success') == "true" ]]; then
                                stopped_services=$(echo "$stopped_services" | jq --arg container "$container" --arg type "docker" '. + [{service_name: $container, service_type: $type, action: "stop", success: true}]')
                            else
                                stopped_services=$(echo "$stopped_services" | jq --arg container "$container" --arg type "docker" '. + [{service_name: $container, service_type: $type, action: "stop", success: false}]')
                            fi
                        fi
                    fi
                done <<< "$containers"
            fi

            # Stop VMs
            if echo "$dependencies" | jq -e '.gpu_dependent_vms' &>/dev/null; then
                local vms=$(echo "$dependencies" | jq -r '.gpu_dependent_vms[]')

                while IFS= read -r vm; do
                    if [[ -n "$vm" ]]; then
                        log "INFO" "Stopping VM: $vm"

                        if [[ -f "$SCRIPT_DIR/manage_vm_services.sh" ]]; then
                            local result=$("$SCRIPT_DIR/manage_vm_services.sh" shutdown "$vm" 2>&1)

                            if echo "$result" | jq -e '.success' &>/dev/null && [[ $(echo "$result" | jq -r '.success') == "true" ]]; then
                                stopped_services=$(echo "$stopped_services" | jq --arg vm "$vm" --arg type "vm" '. + [{service_name: $vm, service_type: $type, action: "shutdown", success: true}]')
                            else
                                stopped_services=$(echo "$stopped_services" | jq --arg vm "$vm" --arg type "vm" '. + [{service_name: $vm, service_type: $type, action: "shutdown", success: false}]')
                            fi
                        fi
                    fi
                done <<< "$vms"
            fi
        fi
    fi

    echo '{"stopped_services":'"$stopped_services"'}'
}

# Save service states
save_service_states() {
    local gpu_address="$1"

    log "INFO" "Saving service states for GPU: $gpu_address"

    # Call the state saver
    if [[ -f "$SCRIPT_DIR/save_service_states.sh" ]]; then
        local result=$("$SCRIPT_DIR/save_service_states.sh" "$gpu_address" 2>&1)

        if echo "$result" | jq -e '.success' &>/dev/null && [[ $(echo "$result" | jq -r '.success') == "true" ]]; then
            local state_file=$(echo "$result" | jq -r '.state_file')
            log "INFO" "Service states saved to: $state_file"
            echo "$state_file"
            return 0
        else
            log "ERROR" "Failed to save service states: $result"
            return 1
        fi
    else
        error_exit "save_service_states.sh not found"
    fi
}

# Create temporary configurations
create_temporary_configurations() {
    local gpu_address="$1"
    local action="$2"

    log "INFO" "Creating temporary configurations for GPU: $gpu_address, action: $action"

    local temp_configs='[]'

    # Create temporary VFIO config if binding to VFIO
    if [[ "$action" == "bind_to_vfio" ]]; then
        local temp_vfio_config="$TEMP_DIR/vfio_${gpu_address//:/_}.conf"

        # Get GPU vendor and device IDs
        local device_path="/sys/bus/pci/devices/0000:$gpu_address"
        local vendor_id=$(cat "$device_path/vendor" 2>/dev/null | sed 's/0x//' || echo "")
        local device_id=$(cat "$device_path/device" 2>/dev/null | sed 's/0x//' || echo "")

        if [[ -n "$vendor_id" ]] && [[ -n "$device_id" ]]; then
            echo "vfio-pci ids=$vendor_id:$device_id" > "$temp_vfio_config"
            temp_configs=$(echo "$temp_configs" | jq --arg config "$temp_vfio_config" --arg type "vfio" '. + [{config_file: $config, config_type: $type}]')
            log "INFO" "Created temporary VFIO config: $temp_vfio_config"
        fi
    fi

    echo '{"temporary_configurations":'"$temp_configs"'}'
}

# Verify system readiness
verify_system_readiness() {
    local gpu_address="$1"
    local action="$2"

    log "INFO" "Verifying system readiness for GPU: $gpu_address, action: $action"

    local ready=true
    local readiness_issues='[]'

    # Check if vfio-pci module is loaded for bind_to_vfio
    if [[ "$action" == "bind_to_vfio" ]]; then
        if ! lsmod | grep -q "^vfio_pci "; then
            ready=false
            readiness_issues=$(echo "$readiness_issues" | jq '. + [{type: "module", message: "vfio-pci module not loaded"}]')
        fi
    fi

    # Check if GPU is accessible
    local device_path="/sys/bus/pci/devices/0000:$gpu_address"

    if [[ ! -d "$device_path" ]]; then
        ready=false
        readiness_issues=$(echo "$readiness_issues" | jq '. + [{type: "device", message: "GPU device not accessible"}]')
    fi

    # Check if there are no conflicting services
    if [[ "$action" == "bind_to_vfio" ]]; then
        if [[ -f "$SCRIPT_DIR/check_service_dependencies.sh" ]]; then
            local dependencies=$("$SCRIPT_DIR/check_service_dependencies.sh" "$gpu_address" 2>&1)

            local container_count=$(echo "$dependencies" | jq -r '.gpu_dependent_containers | length')
            local vm_count=$(echo "$dependencies" | jq -r '.gpu_dependent_vms | length')

            if [[ "$container_count" -gt 0 ]] || [[ "$vm_count" -gt 0 ]]; then
                ready=false
                readiness_issues=$(echo "$readiness_issues" | jq --arg containers "$container_count" --arg vms "$vm_count" '. + [{type: "conflicts", message: "Conflicting services still running: '"$containers"' containers, '"$vms"' VMs"}]')
            fi
        fi
    fi

    echo '{"ready":'"$ready"',"readiness_issues":'"$readiness_issues"'}'
}

# Save preparation state
save_preparation_state() {
    local gpu_address="$1"
    local action="$2"
    local stopped_services="$3"
    local state_file="$4"
    local temp_configs="$5"

    log "INFO" "Saving preparation state"

    # Create state directory
    mkdir -p "$STATE_DIR"

    # Create preparation state file
    local prep_state_file="$STATE_DIR/prep_${gpu_address//:/_}_${action}_$(date +%s).json"

    echo '{"gpu_address":"'"$gpu_address"'","action":"'"$action"'","stopped_services":'"$stopped_services"',"state_file":"'"$state_file"'","temporary_configurations":'"$temp_configs"',"timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}}' > "$prep_state_file"

    log "INFO" "Preparation state saved to: $prep_state_file"
    echo "$prep_state_file"
}

# Main function
main() {
    # Check arguments
    if [[ $# -lt 2 ]]; then
        error_exit "Usage: $0 <action> <gpu_address>"
    fi

    local action="$1"
    local gpu_address="$2"

    log "INFO" "Preparing for GPU switching: action=$action, gpu_address=$gpu_address"

    # Validate action
    validate_action "$action"

    # Validate GPU address
    validate_gpu_address "$gpu_address"

    # Create required directories
    create_directories

    # Stop conflicting services
    local stopped_services=$(stop_conflicting_services "$gpu_address" "$action")

    # Save service states
    local state_file=""
    if save_service_states "$gpu_address"; then
        state_file=$(save_service_states "$gpu_address")
    fi

    # Create temporary configurations
    local temp_configs=$(create_temporary_configurations "$gpu_address" "$action")

    # Verify system readiness
    local readiness=$(verify_system_readiness "$gpu_address" "$action")
    local ready=$(echo "$readiness" | jq -r '.ready')

    if [[ "$ready" != "true" ]]; then
        log "ERROR" "System not ready for GPU switching"
        echo '{"success":false,"action":"'"$action"'","gpu_address":"'"$gpu_address"'","readiness":'"$readiness"',"timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}}' | jq .
        exit 1
    fi

    # Save preparation state
    local prep_state_file=$(save_preparation_state "$gpu_address" "$action" "$(echo "$stopped_services" | jq -c '.stopped_services')" "$state_file" "$(echo "$temp_configs" | jq -c '.temporary_configurations')")

    # Build JSON output
    local json_output='{"success":true,"action":"'"$action"'","gpu_address":"'"$gpu_address"'","stopped_services":'"$stopped_services"',"state_file":"'"$state_file"'","temporary_configurations":'"$temp_configs"',"readiness":'"$readiness"',"prep_state_file":"'"$prep_state_file"'","timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}}'

    log "INFO" "Preparation completed successfully"

    echo "$json_output" | jq .
}

# Run main function
main "$@"