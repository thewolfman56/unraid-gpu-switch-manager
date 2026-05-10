#!/bin/bash

# vm_start_handler.sh
# VM start event handler for automatic GPU switching
# Usage: ./vm_start_handler.sh <vm_name>

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source secure shell library
source "$SCRIPT_DIR/secure_shell_lib.sh"
STATE_DIR="/var/lib/gpu-switch-manager/states"
EVENT_LOG="/var/log/gpu-switch-manager/events.log"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    secure_log "$level" "[VM_START_HANDLER] $message"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    secure_error_exit "$1"
}

# Validate VM name
validate_vm_name() {
    local vm_name="$1"

    if [[ -z "$vm_name" ]]; then
        error_exit "VM name is required"
    fi

    # Check for valid characters
    if [[ ! "$vm_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        error_exit "Invalid VM name: $vm_name (only alphanumeric, underscore, and hyphen allowed)"
    fi
}

# Check if virsh is available
check_virsh() {
    if ! command -v virsh &> /dev/null; then
        error_exit "virsh command not found"
    fi

    if ! virsh version &> /dev/null; then
        error_exit "virsh is not accessible"
    fi
}

# Get VM GPU requirements
get_vm_gpu_requirements() {
    local vm_name="$1"

    log "INFO" "Getting GPU requirements for VM: $vm_name"

    # Get VM XML
    local vm_xml=$(virsh dumpxml "$vm_name" 2>/dev/null || echo "")

    if [[ -z "$vm_xml" ]]; then
        error_exit "Failed to get VM XML for: $vm_name"
    fi

    # Extract GPU devices
    local gpu_devices=$(echo "$vm_xml" | grep -A 10 "<hostdev" | grep "pci" | grep -oP 'domain="0x[0-9a-f]+"\s+bus="0x[0-9a-f]+"\s+slot="0x[0-9a-f]+"\s+function="0x[0-9a-f]+"' | sed 's/domain="0x//;s/"\s+bus="0x/:/;s/"\s+slot="0x/:/;s/"\s+function="0x/./;s/"//g' || echo "")

    if [[ -z "$gpu_devices" ]]; then
        log "INFO" "No GPU devices found in VM configuration"
        echo '{"gpu_devices":[],"has_gpu":false}'
        return
    fi

    # Build JSON output
    local gpu_json='{"gpu_devices":['
    local first=true

    while IFS= read -r gpu_address; do
        if [[ -n "$gpu_address" ]]; then
            if [[ "$first" == "true" ]]; then
                gpu_json+="{\"address\":\"$gpu_address\"}"
                first=false
            else
                gpu_json+=",{\"address\":\"$gpu_address\"}"
            fi
        fi
    done <<< "$gpu_devices"

    gpu_json+='],"has_gpu":true}'

    log "INFO" "VM GPU requirements: $gpu_json"
    echo "$gpu_json"
}

# Check current GPU binding state
check_gpu_binding_state() {
    local gpu_address="$1"

    log "INFO" "Checking GPU binding state for: $gpu_address"

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

# Bind GPU to VFIO
bind_gpu_to_vfio() {
    local gpu_address="$1"

    log "INFO" "Binding GPU to VFIO: $gpu_address"

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

# Stop conflicting Docker containers
stop_conflicting_containers() {
    local gpu_address="$1"

    log "INFO" "Stopping conflicting Docker containers for GPU: $gpu_address"

    # Call the dependency checker
    if [[ -f "$SCRIPT_DIR/check_service_dependencies.sh" ]]; then
        local result=$("$SCRIPT_DIR/check_service_dependencies.sh" "$gpu_address" 2>&1)

        if echo "$result" | jq -e '.gpu_dependent_containers' &>/dev/null; then
            local containers=$(echo "$result" | jq -r '.gpu_dependent_containers[]')

            if [[ -n "$containers" ]]; then
                log "INFO" "Found GPU-dependent containers: $containers"

                # Stop each container
                while IFS= read -r container; do
                    if [[ -n "$container" ]]; then
                        log "INFO" "Stopping container: $container"

                        if [[ -f "$SCRIPT_DIR/manage_docker_containers.sh" ]]; then
                            local stop_result=$("$SCRIPT_DIR/manage_docker_containers.sh" stop "$container" 2>&1)

                            if echo "$stop_result" | jq -e '.success' &>/dev/null && [[ $(echo "$stop_result" | jq -r '.success') == "true" ]]; then
                                log "INFO" "Successfully stopped container: $container"
                            else
                                log "ERROR" "Failed to stop container: $container - $stop_result"
                            fi
                        fi
                    fi
                done <<< "$containers"
            else
                log "INFO" "No GPU-dependent containers found"
            fi
        fi
    fi
}

# Save service states
save_service_states() {
    local gpu_address="$1"

    log "INFO" "Saving service states for GPU: $gpu_address"

    # Create state directory
    mkdir -p "$STATE_DIR"

    # Call the state saver
    if [[ -f "$SCRIPT_DIR/save_service_states.sh" ]]; then
        local result=$("$SCRIPT_DIR/save_service_states.sh" "$gpu_address" 2>&1)

        if echo "$result" | jq -e '.success' &>/dev/null && [[ $(echo "$result" | jq -r '.success') == "true" ]]; then
            local state_file=$(echo "$result" | jq -r '.state_file')
            log "INFO" "Successfully saved service states to: $state_file"
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

# Main function
main() {
    # Check arguments
    if [[ $# -lt 1 ]]; then
        error_exit "Usage: $0 <vm_name>"
    fi

    local vm_name="$1"

    log "INFO" "VM start handler triggered for: $vm_name"

    # Validate VM name
    validate_vm_name "$vm_name"

    # Check if virsh is available
    check_virsh

    # Get VM GPU requirements
    local gpu_requirements=$(get_vm_gpu_requirements "$vm_name")
    local has_gpu=$(echo "$gpu_requirements" | jq -r '.has_gpu')

    if [[ "$has_gpu" != "true" ]]; then
        log "INFO" "VM does not require GPU passthrough, skipping GPU switching"
        echo '{"success":true,"message":"VM does not require GPU passthrough","vm_name":"'"$vm_name"'","gpu_switching_required":false}'
        exit 0
    fi

    # Get GPU devices
    local gpu_devices=$(echo "$gpu_requirements" | jq -r '.gpu_devices[].address')

    log "INFO" "VM requires GPU passthrough for devices: $gpu_devices"

    # Process each GPU device
    local all_success=true
    local processed_gpus=()

    while IFS= read -r gpu_address; do
        if [[ -n "$gpu_address" ]]; then
            log "INFO" "Processing GPU device: $gpu_address"

            # Check current binding state
            local binding_state=$(check_gpu_binding_state "$gpu_address")
            local is_vfio=$(echo "$binding_state" | jq -r '.is_vfio')

            if [[ "$is_vfio" == "true" ]]; then
                log "INFO" "GPU already bound to VFIO: $gpu_address"
                processed_gpus+=("$gpu_address")
                continue
            fi

            # Save service states
            local state_file=$(save_service_states "$gpu_address")
            if [[ $? -ne 0 ]]; then
                log "ERROR" "Failed to save service states for GPU: $gpu_address"
                all_success=false
                continue
            fi

            # Stop conflicting containers
            stop_conflicting_containers "$gpu_address"

            # Bind GPU to VFIO
            if bind_gpu_to_vfio "$gpu_address"; then
                log "INFO" "Successfully bound GPU to VFIO: $gpu_address"
                processed_gpus+=("$gpu_address")
            else
                log "ERROR" "Failed to bind GPU to VFIO: $gpu_address"
                all_success=false
            fi
        fi
    done <<< "$gpu_devices"

    # Build JSON output
    local json_output='{"success":'"$all_success"',"vm_name":"'"$vm_name"'","gpu_switching_required":true,"processed_gpus":['

    local first=true
    for gpu in "${processed_gpus[@]}"; do
        if [[ "$first" == "true" ]]; then
            json_output+="{\"address\":\"$gpu\"}"
            first=false
        else
            json_output+=",{\"address\":\"$gpu\"}"
        fi
    done

    json_output+='],"timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}}'

    log "INFO" "VM start handler completed: success=$all_success"

    echo "$json_output" | jq .
}

# Run main function
main "$@"