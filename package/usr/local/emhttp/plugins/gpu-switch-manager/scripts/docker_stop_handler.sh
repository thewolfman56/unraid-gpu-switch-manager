#!/bin/bash

# docker_stop_handler.sh
# Docker container stop event handler for automatic GPU switching
# Usage: ./docker_stop_handler.sh <container_name>

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
    secure_log "$level" "[DOCKER_STOP_HANDLER] $message"
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

# Check if GPU can be switched
check_gpu_switching_possible() {
    local gpu_address="$1"

    log "INFO" "Checking if GPU switching is possible for: $gpu_address"

    # Check if there are other GPU-dependent containers running
    local other_containers=false

    if [[ -f "$SCRIPT_DIR/check_service_dependencies.sh" ]]; then
        local dependencies=$("$SCRIPT_DIR/check_service_dependencies.sh" "$gpu_address" 2>&1)

        if echo "$dependencies" | jq -e '.gpu_dependent_containers' &>/dev/null; then
            local container_count=$(echo "$dependencies" | jq -r '.gpu_dependent_containers | length')

            if [[ "$container_count" -gt 0 ]]; then
                other_containers=true
                log "INFO" "Found $container_count other GPU-dependent containers"
            fi
        fi
    fi

    # Check if there are running VMs using the GPU
    local running_vms=false

    if command -v virsh &> /dev/null; then
        local vm_dependencies=$(virsh list --name --state-running 2>/dev/null || echo "")

        if [[ -n "$vm_dependencies" ]]; then
            running_vms=true
            log "INFO" "Found running VMs"
        fi
    fi

    local can_switch=false
    if [[ "$other_containers" == "false" ]] && [[ "$running_vms" == "false" ]]; then
        can_switch=true
    fi

    echo '{"can_switch":'"$can_switch"',"other_containers":'"$other_containers"',"running_vms":'"$running_vms"'}'
}

# Update GPU usage tracking
update_gpu_usage_tracking() {
    local container_name="$1"
    local gpu_address="$2"

    log "INFO" "Updating GPU usage tracking for container: $container_name, GPU: $gpu_address"

    # Create tracking directory
    local tracking_dir="/var/lib/gpu-switch-manager/tracking"
    mkdir -p "$tracking_dir"

    # Remove container from GPU tracking
    local tracking_file="$tracking_dir/gpu_${gpu_address//:/_}_containers.json"

    if [[ -f "$tracking_file" ]]; then
        # Remove container from tracking file
        local updated_tracking=$(jq 'del(.containers[] | select(.name == "'"$container_name"'"))' "$tracking_file")
        echo "$updated_tracking" > "$tracking_file"
        log "INFO" "Removed container from GPU tracking: $container_name"
    fi

    log "INFO" "GPU usage tracking updated"
}

# Main function
main() {
    # Check arguments
    if [[ $# -lt 1 ]]; then
        error_exit "Usage: $0 <container_name>"
    fi

    local container_name="$1"

    log "INFO" "Docker stop handler triggered for: $container_name"

    # Validate container name
    validate_container_name "$container_name"

    # Check if Docker is available
    check_docker

    # Get container GPU requirements
    local gpu_requirements=$(get_container_gpu_requirements "$container_name")
    local has_gpu=$(echo "$gpu_requirements" | jq -r '.has_gpu')

    if [[ "$has_gpu" != "true" ]]; then
        log "INFO" "Container did not require GPU access, skipping GPU switching"
        echo '{"success":true,"message":"Container did not require GPU access","container_name":"'"$container_name"'","gpu_switching_required":false}' | jq .
        exit 0
    fi

    log "INFO" "Container required GPU access"

    # For simplicity, we'll use the default GPU address
    local gpu_address="01:00.0"

    # Update GPU usage tracking
    update_gpu_usage_tracking "$container_name" "$gpu_address"

    # Check if GPU switching is possible
    local switching_check=$(check_gpu_switching_possible "$gpu_address")
    local can_switch=$(echo "$switching_check" | jq -r '.can_switch')

    if [[ "$can_switch" == "true" ]]; then
        log "INFO" "GPU switching is possible, but no action needed for container stop"
        echo '{"success":true,"message":"GPU switching is possible, no action needed","container_name":"'"$container_name"'","gpu_address":"'"$gpu_address"'","can_switch":true}' | jq .
    else
        local other_containers=$(echo "$switching_check" | jq -r '.other_containers')
        local running_vms=$(echo "$switching_check" | jq -r '.running_vms')

        log "INFO" "GPU switching not possible: other_containers=$other_containers, running_vms=$running_vms"
        echo '{"success":true,"message":"GPU switching not possible due to other usage","container_name":"'"$container_name"'","gpu_address":"'"$gpu_address"'","can_switch":false,"other_containers":'"$other_containers"',"running_vms":'"$running_vms"'}' | jq .
    fi

    exit 0
}

# Run main function
main "$@"