#!/bin/bash

# docker_start_handler.sh
# Docker container start event handler for automatic GPU switching
# Usage: ./docker_start_handler.sh <container_name>

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
    secure_log "$level" "[DOCKER_START_HANDLER] $message"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    secure_error_exit "$1"
}

# Validate container name
validate_container_name() {
    local container_name="$1"

    if [[ -z "$container_name" ]]; then
        error_exit "Container name is required"
    fi

    # Check for valid characters
    if [[ ! "$container_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        error_exit "Invalid container name: $container_name (only alphanumeric, underscore, and hyphen allowed)"
    fi
}

# Check if Docker is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        error_exit "Docker command not found"
    fi

    if ! docker info &> /dev/null; then
        error_exit "Docker daemon is not accessible"
    fi
}

# Check if container exists
check_container_exists() {
    local container_name="$1"

    if ! docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        error_exit "Container not found: $container_name"
    fi
}

# Get container GPU requirements
get_container_gpu_requirements() {
    local container_name="$1"

    log "INFO" "Getting GPU requirements for container: $container_name"

    # Get container GPU device requests
    local gpu_devices=$(docker inspect --format='{{range .HostConfig.DeviceRequests}}{{.DeviceIDs}}{{end}}' "$container_name" 2>/dev/null || echo "")

    # Get container GPU usage from environment variables
    local gpu_env=$(docker inspect --format='{{range .Config.Env}}{{if contains . "NVIDIA_VISIBLE_DEVICES"}}{{.}}{{end}}{{end}}' "$container_name" 2>/dev/null || echo "")

    # Get container GPU usage from runtime
    local gpu_runtime=$(docker inspect --format='{{.HostConfig.Runtime}}' "$container_name" 2>/dev/null || echo "")

    local has_gpu=false
    local gpu_info='{"devices":"'"$gpu_devices"'","env":"'"$gpu_env"'","runtime":"'"$gpu_runtime"'"}'

    if [[ -n "$gpu_devices" ]] || [[ -n "$gpu_env" ]] || [[ "$gpu_runtime" == "nvidia" ]]; then
        has_gpu=true
    fi

    echo '{"container_name":"'"$container_name"'","has_gpu":'"$has_gpu"',"gpu_info":'"$gpu_info"'}'
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

# Check for VM conflicts
check_vm_conflicts() {
    local gpu_address="$1"

    log "INFO" "Checking for VM conflicts for GPU: $gpu_address"

    # Check if virsh is available
    if ! command -v virsh &> /dev/null; then
        log "INFO" "virsh not available, skipping VM conflict check"
        echo '{"has_conflicts":false,"conflicting_vms":[]}'
        return
    fi

    # Get running VMs
    local running_vms=$(virsh list --name --state-running 2>/dev/null || echo "")

    if [[ -z "$running_vms" ]]; then
        log "INFO" "No running VMs found"
        echo '{"has_conflicts":false,"conflicting_vms":[]}'
        return
    fi

    # Check each running VM for GPU usage
    local conflicting_vms_json="["
    local first=true
    local has_conflicts=false

    while IFS= read -r vm_name; do
        if [[ -n "$vm_name" ]]; then
            # Get VM GPU requirements
            if [[ -f "$SCRIPT_DIR/check_vm_gpu_requirements.sh" ]]; then
                local vm_gpu_requirements=$("$SCRIPT_DIR/check_vm_gpu_requirements.sh" "$vm_name" 2>&1)

                if echo "$vm_gpu_requirements" | jq -e '.has_gpu' &>/dev/null && [[ $(echo "$vm_gpu_requirements" | jq -r '.has_gpu') == "true" ]]; then
                    local vm_gpu_devices=$(echo "$vm_gpu_requirements" | jq -r '.gpu_devices[].address')

                    # Check if VM uses the same GPU
                    if echo "$vm_gpu_devices" | grep -q "^${gpu_address}$"; then
                        has_conflicts=true

                        if [[ "$first" == "true" ]]; then
                            conflicting_vms_json+="{\"vm_name\":\"$vm_name\",\"gpu_address\":\"$gpu_address\"}"
                            first=false
                        else
                            conflicting_vms_json+=",{\"vm_name\":\"$vm_name\",\"gpu_address\":\"$gpu_address\"}"
                        fi
                    fi
                fi
            fi
        fi
    done <<< "$running_vms"

    conflicting_vms_json+="]"

    echo '{"has_conflicts":'"$has_conflicts"',"conflicting_vms":'"$conflicting_vms_json"'}}'
}

# Unbind GPU from VFIO if needed
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

# Main function
main() {
    # Check arguments
    if [[ $# -lt 1 ]]; then
        error_exit "Usage: $0 <container_name>"
    fi

    local container_name="$1"

    log "INFO" "Docker start handler triggered for: $container_name"

    # Validate container name
    validate_container_name "$container_name"

    # Check if Docker is available
    check_docker

    # Check if container exists
    check_container_exists "$container_name"

    # Get container GPU requirements
    local gpu_requirements=$(get_container_gpu_requirements "$container_name")
    local has_gpu=$(echo "$gpu_requirements" | jq -r '.has_gpu')

    if [[ "$has_gpu" != "true" ]]; then
        log "INFO" "Container does not require GPU access, skipping GPU switching"
        echo '{"success":true,"message":"Container does not require GPU access","container_name":"'"$container_name"'","gpu_switching_required":false}' | jq .
        exit 0
    fi

    log "INFO" "Container requires GPU access"

    # For simplicity, we'll check the first GPU device
    # In a real implementation, you'd want to handle multiple GPUs
    local gpu_address="01:00.0"  # Default GPU address

    # Check current GPU binding state
    local binding_state=$(check_gpu_binding_state "$gpu_address")
    local is_vfio=$(echo "$binding_state" | jq -r '.is_vfio')

    if [[ "$is_vfio" != "true" ]]; then
        log "INFO" "GPU not bound to VFIO, no action needed"
        echo '{"success":true,"message":"GPU not bound to VFIO, no action needed","container_name":"'"$container_name"'","gpu_address":"'"$gpu_address"'","gpu_switching_required":false}' | jq .
        exit 0
    fi

    # Check for VM conflicts
    local vm_conflicts=$(check_vm_conflicts "$gpu_address")
    local has_conflicts=$(echo "$vm_conflicts" | jq -r '.has_conflicts')

    if [[ "$has_conflicts" == "true" ]]; then
        local conflicting_vms=$(echo "$vm_conflicts" | jq -r '.conflicting_vms[].vm_name')
        log "ERROR" "GPU is in use by running VMs: $conflicting_vms"
        echo '{"success":false,"error":"GPU is in use by running VMs","container_name":"'"$container_name"'","gpu_address":"'"$gpu_address"'","conflicting_vms":'"$(echo "$vm_conflicts" | jq -c '.conflicting_vms')'}' | jq .
        exit 1
    fi

    # Unbind GPU from VFIO
    if unbind_gpu_from_vfio "$gpu_address"; then
        log "INFO" "Successfully unbound GPU from VFIO for container: $container_name"
        echo '{"success":true,"message":"Successfully unbound GPU from VFIO","container_name":"'"$container_name"'","gpu_address":"'"$gpu_address"'","gpu_switching_required":true}' | jq .
        exit 0
    else
        log "ERROR" "Failed to unbind GPU from VFIO for container: $container_name"
        echo '{"success":false,"error":"Failed to unbind GPU from VFIO","container_name":"'"$container_name"'","gpu_address":"'"$gpu_address"'"}' | jq .
        exit 1
    fi
}

# Run main function
main "$@"