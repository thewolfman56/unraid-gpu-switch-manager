#!/bin/bash

# vm_stop_handler.sh
# VM stop event handler for automatic GPU switching
# Usage: ./vm_stop_handler.sh <vm_name>

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
    secure_log "$level" "[VM_STOP_HANDLER] $message"
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

# Unbind GPU from VFIO
unbind_gpu_from_vfio() {
    local gpu_address="$1"

    log "INFO" "Unbinding GPU from VFIO: $gpu_address"

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

# Restore Docker containers
restore_docker_containers() {
    local gpu_address="$1"

    log "INFO" "Restoring Docker containers for GPU: $gpu_address"

    # Call the state restorer
    if [[ -f "$SCRIPT_DIR/restore_service_states.sh" ]]; then
        local result=$("$SCRIPT_DIR/restore_service_states.sh" "$gpu_address" 2>&1)

        if echo "$result" | jq -e '.success' &>/dev/null && [[ $(echo "$result" | jq -r '.success') == "true" ]]; then
            log "INFO" "Successfully restored Docker containers for GPU: $gpu_address"
            return 0
        else
            log "ERROR" "Failed to restore Docker containers for GPU: $gpu_address - $result"
            return 1
        fi
    else
        error_exit "restore_service_states.sh not found"
    fi
}

# Restore service states
restore_service_states() {
    local gpu_address="$1"

    log "INFO" "Restoring service states for GPU: $gpu_address"

    # Call the state restorer
    if [[ -f "$SCRIPT_DIR/restore_service_states.sh" ]]; then
        local result=$("$SCRIPT_DIR/restore_service_states.sh" "$gpu_address" 2>&1)

        if echo "$result" | jq -e '.success' &>/dev/null && [[ $(echo "$result" | jq -r '.success') == "true" ]]; then
            log "INFO" "Successfully restored service states for GPU: $gpu_address"
            return 0
        else
            log "ERROR" "Failed to restore service states for GPU: $gpu_address - $result"
            return 1
        fi
    else
        error_exit "restore_service_states.sh not found"
    fi
}

# Cleanup temporary files
cleanup_temporary_files() {
    local gpu_address="$1"

    log "INFO" "Cleaning up temporary files for GPU: $gpu_address"

    # Remove state file
    local state_file="$STATE_DIR/gpu_${gpu_address//:/_}_state.json"

    if [[ -f "$state_file" ]]; then
        rm -f "$state_file"
        log "INFO" "Removed state file: $state_file"
    fi

    # Clean up any other temporary files
    local temp_pattern="$STATE_DIR/gpu_${gpu_address//:/_}_*.tmp"

    if ls $temp_pattern &>/dev/null; then
        rm -f $temp_pattern
        log "INFO" "Removed temporary files matching: $temp_pattern"
    fi
}

# Main function
main() {
    # Check arguments
    if [[ $# -lt 1 ]]; then
        error_exit "Usage: $0 <vm_name>"
    fi

    local vm_name="$1"

    log "INFO" "VM stop handler triggered for: $vm_name"

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

    log "INFO" "VM required GPU passthrough for devices: $gpu_devices"

    # Process each GPU device
    local all_success=true
    local processed_gpus=()

    while IFS= read -r gpu_address; do
        if [[ -n "$gpu_address" ]]; then
            log "INFO" "Processing GPU device: $gpu_address"

            # Check current binding state
            local binding_state=$(check_gpu_binding_state "$gpu_address")
            local is_vfio=$(echo "$binding_state" | jq -r '.is_vfio')

            if [[ "$is_vfio" != "true" ]]; then
                log "INFO" "GPU not bound to VFIO: $gpu_address, skipping unbind"
                processed_gpus+=("$gpu_address")
                continue
            fi

            # Unbind GPU from VFIO
            if unbind_gpu_from_vfio "$gpu_address"; then
                log "INFO" "Successfully unbound GPU from VFIO: $gpu_address"

                # Restore Docker containers
                restore_docker_containers "$gpu_address"

                # Restore service states
                restore_service_states "$gpu_address"

                # Cleanup temporary files
                cleanup_temporary_files "$gpu_address"

                processed_gpus+=("$gpu_address")
            else
                log "ERROR" "Failed to unbind GPU from VFIO: $gpu_address"
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

    log "INFO" "VM stop handler completed: success=$all_success"

    echo "$json_output" | jq .
}

# Run main function
main "$@"