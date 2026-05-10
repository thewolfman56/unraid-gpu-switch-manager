#!/bin/bash

# check_container_gpu_requirements.sh
# Check container GPU requirements from container configuration
# Usage: ./check_container_gpu_requirements.sh <container_name>

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
    secure_log "$level" "[CONTAINER_GPU_REQUIREMENTS] $message"
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

# Get container GPU device requests
get_gpu_device_requests() {
    local container_name="$1"

    log "INFO" "Getting GPU device requests for container: $container_name"

    # Get device requests
    local device_requests=$(docker inspect --format='{{json .HostConfig.DeviceRequests}}' "$container_name" 2>/dev/null || echo "[]")

    echo "$device_requests"
}

# Get container GPU environment variables
get_gpu_environment_variables() {
    local container_name="$1"

    log "INFO" "Getting GPU environment variables for container: $container_name"

    local gpu_env_vars="[]"

    # Get NVIDIA_VISIBLE_DEVICES
    local nvidia_visible_devices=$(docker inspect --format='{{range .Config.Env}}{{if contains . "NVIDIA_VISIBLE_DEVICES"}}{{.}}{{end}}{{end}}' "$container_name" 2>/dev/null || echo "")

    if [[ -n "$nvidia_visible_devices" ]]; then
        gpu_env_vars='["'"$nvidia_visible_devices"'"]'
    fi

    echo "$gpu_env_vars"
}

# Get container GPU runtime
get_gpu_runtime() {
    local container_name="$1"

    log "INFO" "Getting GPU runtime for container: $container_name"

    local runtime=$(docker inspect --format='{{.HostConfig.Runtime}}' "$container_name" 2>/dev/null || echo "")

    echo "$runtime"
}

# Get container GPU mounts
get_gpu_mounts() {
    local container_name="$1"

    log "INFO" "Getting GPU mounts for container: $container_name"

    local gpu_mounts="[]"

    # Get nvidia driver mounts
    local nvidia_mounts=$(docker inspect --format='{{range .Mounts}}{{if contains .Destination "nvidia"}}{{.Source}}:{{.Destination}}{{end}}{{end}}' "$container_name" 2>/dev/null || echo "")

    if [[ -n "$nvidia_mounts" ]]; then
        gpu_mounts='["'"$nvidia_mounts"'"]'
    fi

    echo "$gpu_mounts"
}

# Determine GPU requirement type
determine_gpu_requirement_type() {
    local device_requests="$1"
    local gpu_env_vars="$2"
    local gpu_runtime="$3"
    local gpu_mounts="$4"

    local requirement_type="none"
    local has_gpu=false

    # Check device requests
    if [[ "$device_requests" != "[]" ]] && [[ "$device_requests" != "null" ]]; then
        requirement_type="device_requests"
        has_gpu=true
    fi

    # Check environment variables
    if [[ "$gpu_env_vars" != "[]" ]] && [[ "$gpu_env_vars" != "null" ]]; then
        if [[ "$requirement_type" == "none" ]]; then
            requirement_type="environment_variables"
        fi
        has_gpu=true
    fi

    # Check runtime
    if [[ "$gpu_runtime" == "nvidia" ]]; then
        if [[ "$requirement_type" == "none" ]]; then
            requirement_type="runtime"
        fi
        has_gpu=true
    fi

    # Check mounts
    if [[ "$gpu_mounts" != "[]" ]] && [[ "$gpu_mounts" != "null" ]]; then
        if [[ "$requirement_type" == "none" ]]; then
            requirement_type="mounts"
        fi
        has_gpu=true
    fi

    echo '{"has_gpu":'"$has_gpu"',"requirement_type":"'"$requirement_type"'"}'
}

# Get container state
get_container_state() {
    local container_name="$1"

    local state=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "unknown")

    echo "$state"
}

# Main function
main() {
    # Check arguments
    if [[ $# -lt 1 ]]; then
        error_exit "Usage: $0 <container_name>"
    fi

    local container_name="$1"

    log "INFO" "Checking GPU requirements for container: $container_name"

    # Validate container name
    validate_container_name "$container_name"

    # Check if Docker is available
    check_docker

    # Check if container exists
    check_container_exists "$container_name"

    # Get container GPU information
    local device_requests=$(get_gpu_device_requests "$container_name")
    local gpu_env_vars=$(get_gpu_environment_variables "$container_name")
    local gpu_runtime=$(get_gpu_runtime "$container_name")
    local gpu_mounts=$(get_gpu_mounts "$container_name")

    # Determine GPU requirement type
    local requirement_type=$(determine_gpu_requirement_type "$device_requests" "$gpu_env_vars" "$gpu_runtime" "$gpu_mounts")

    local has_gpu=$(echo "$requirement_type" | jq -r '.has_gpu')
    local req_type=$(echo "$requirement_type" | jq -r '.requirement_type')

    # Get container state
    local container_state=$(get_container_state "$container_name")

    # Build JSON output
    local json_output='{"success":true,"container_name":"'"$container_name"'","has_gpu":'"$has_gpu"',"requirement_type":"'"$req_type"'","device_requests":'"$device_requests"',"gpu_env_vars":'"$gpu_env_vars"',"gpu_runtime":"'"$gpu_runtime"'","gpu_mounts":'"$gpu_mounts"',"container_state":"'"$container_state"'","timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}}'

    log "INFO" "Container GPU requirements check completed: has_gpu=$has_gpu, requirement_type=$req_type"

    echo "$json_output" | jq .
}

# Run main function
main "$@"