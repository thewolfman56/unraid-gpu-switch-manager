#!/bin/bash

# manage_docker_containers.sh
# Manage Docker containers during GPU switching
# Usage: ./manage_docker_containers.sh <operation> <container1> [<container2> ...]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source secure shell library
source "$SCRIPT_DIR/secure_shell_lib.sh"
STATE_DIR="/var/lib/gpu.switch.manager/states"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    secure_log "$level" "[MANAGE_DOCKER] $message"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    secure_error_exit "$1"
}

# Check if Docker is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        error_exit "Docker command not found"
    fi

    if ! docker info &> /dev/null; then
        error_exit "Docker daemon is not running"
    fi
}

# Validate operation
validate_operation() {
    local operation="$1"

    case "$operation" in
        start|stop|restart|status|list)
            return 0
            ;;
        *)
            error_exit "Invalid operation: $operation (must be start, stop, restart, status, or list)"
            ;;
    esac
}

# Validate container name
validate_container_name() {
    local container_name="$1"

    if [[ -z "$container_name" ]]; then
        error_exit "Container name cannot be empty"
    fi

    # Check if container exists
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        error_exit "Container not found: $container_name"
    fi
}

# Get container state
get_container_state() {
    local container_name="$1"
    docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "unknown"
}

# Get container GPU usage
get_container_gpu_usage() {
    local container_name="$1"

    # Check for GPU devices in container config
    local gpu_devices=$(docker inspect --format='{{range .HostConfig.DeviceRequests}}{{.DeviceIDs}}{{end}}' "$container_name" 2>/dev/null || echo "")

    if [[ -n "$gpu_devices" ]]; then
        echo "$gpu_devices"
    else
        # Check for NVIDIA runtime
        local runtime=$(docker inspect --format='{{.HostConfig.Runtime}}' "$container_name" 2>/dev/null || echo "")
        if [[ "$runtime" == "nvidia" ]]; then
            echo "nvidia-runtime"
        else
            echo ""
        fi
    fi
}

# Stop container
stop_container() {
    local container_name="$1"
    local current_state=$(get_container_state "$container_name")

    log "INFO" "Stopping container: $container_name (current state: $current_state)"

    if [[ "$current_state" == "running" ]]; then
        # Stop container gracefully
        if docker stop "$container_name" &> /dev/null; then
            log "INFO" "Container stopped successfully: $container_name"
            echo "stopped"
        else
            log "ERROR" "Failed to stop container: $container_name"
            echo "failed"
        fi
    elif [[ "$current_state" == "exited" ]]; then
        log "INFO" "Container already stopped: $container_name"
        echo "already_stopped"
    else
        log "WARN" "Container in unexpected state: $container_name ($current_state)"
        echo "unexpected_state"
    fi
}

# Start container
start_container() {
    local container_name="$1"
    local current_state=$(get_container_state "$container_name")

    log "INFO" "Starting container: $container_name (current state: $current_state)"

    if [[ "$current_state" == "exited" ]] || [[ "$current_state" == "created" ]]; then
        # Start container
        if docker start "$container_name" &> /dev/null; then
            log "INFO" "Container started successfully: $container_name"
            echo "running"
        else
            log "ERROR" "Failed to start container: $container_name"
            echo "failed"
        fi
    elif [[ "$current_state" == "running" ]]; then
        log "INFO" "Container already running: $container_name"
        echo "already_running"
    else
        log "WARN" "Container in unexpected state: $container_name ($current_state)"
        echo "unexpected_state"
    fi
}

# Restart container
restart_container() {
    local container_name="$1"

    log "INFO" "Restarting container: $container_name"

    # Stop container first
    local stop_result=$(stop_container "$container_name")

    if [[ "$stop_result" == "stopped" ]] || [[ "$stop_result" == "already_stopped" ]]; then
        # Start container
        local start_result=$(start_container "$container_name")

        if [[ "$start_result" == "running" ]]; then
            echo "restarted"
        else
            echo "failed"
        fi
    else
        echo "failed"
    fi
}

# Get container status
get_container_status() {
    local container_name="$1"
    local state=$(get_container_state "$container_name")
    local gpu_usage=$(get_container_gpu_usage "$container_name")

    # Get additional info
    local created=$(docker inspect --format='{{.Created}}' "$container_name" 2>/dev/null || echo "")
    local image=$(docker inspect --format='{{.Config.Image}}' "$container_name" 2>/dev/null || echo "")

    echo "state:$state|gpu:$gpu_usage|created:$created|image:$image"
}

# List all containers
list_containers() {
    log "INFO" "Listing all containers"

    local containers_json="["

    local first=true
    while IFS= read -r line; do
        local name=$(echo "$line" | cut -d'|' -f1)
        local status=$(echo "$line" | cut -d'|' -f2)
        local state=$(echo "$line" | cut -d'|' -f3)

        # Get GPU usage
        local gpu_usage=$(get_container_gpu_usage "$name")

        if [[ "$first" == "true" ]]; then
            containers_json+="{\"name\":\"$name\",\"status\":\"$status\",\"state\":\"$state\",\"gpu_usage\":\"$gpu_usage\"}"
            first=false
        else
            containers_json+=",{\"name\":\"$name\",\"status\":\"$status\",\"state\":\"$state\",\"gpu_usage\":\"$gpu_usage\"}"
        fi
    done < <(docker ps -a --format "{{.Names}}|{{.Status}}|{{.State}}")

    containers_json+="]"
    echo "$containers_json"
}

# List GPU-dependent containers
list_gpu_containers() {
    log "INFO" "Listing GPU-dependent containers"

    local gpu_containers_json="["

    local first=true
    while IFS= read -r line; do
        local name=$(echo "$line" | cut -d'|' -f1)
        local status=$(echo "$line" | cut -d'|' -f2)
        local state=$(echo "$line" | cut -d'|' -f3)

        # Get GPU usage
        local gpu_usage=$(get_container_gpu_usage "$name")

        # Only include if GPU usage detected
        if [[ -n "$gpu_usage" ]]; then
            if [[ "$first" == "true" ]]; then
                gpu_containers_json+="{\"name\":\"$name\",\"status\":\"$status\",\"state\":\"$state\",\"gpu_usage\":\"$gpu_usage\"}"
                first=false
            else
                gpu_containers_json+=",{\"name\":\"$name\",\"status\":\"$status\",\"state\":\"$state\",\"gpu_usage\":\"$gpu_usage\"}"
            fi
        fi
    done < <(docker ps -a --format "{{.Names}}|{{.Status}}|{{.State}}")

    gpu_containers_json+="]"
    echo "$gpu_containers_json"
}

# Main function
main() {
    # Check arguments
    if [[ $# -lt 1 ]]; then
        error_exit "Usage: $0 <operation> [container1] [container2] ..."
    fi

    local operation="$1"
    shift

    # Validate operation
    validate_operation "$operation"

    # Check Docker availability
    check_docker

    log "INFO" "Starting Docker container management (operation: $operation)"

    # Handle different operations
    case "$operation" in
        list)
            local containers=$(list_containers)
            echo '{"success":true,"operation":"list","containers":'"$containers"',"timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}' | jq .
            ;;

        status)
            if [[ $# -eq 0 ]]; then
                error_exit "Usage: $0 status <container_name>"
            fi

            local container_name="$1"
            validate_container_name "$container_name"

            local status_info=$(get_container_status "$container_name")
            local state=$(echo "$status_info" | cut -d'|' -f1 | cut -d: -f2)
            local gpu_usage=$(echo "$status_info" | cut -d'|' -f2 | cut -d: -f2)
            local created=$(echo "$status_info" | cut -d'|' -f3 | cut -d: -f2)
            local image=$(echo "$status_info" | cut -d'|' -f4 | cut -d: -f2)

            echo '{"success":true,"operation":"status","container":{"name":"'"$container_name"'","state":"'"$state"'","gpu_usage":"'"$gpu_usage"'","created":"'"$created"'","image":"'"$image"'"},"timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}' | jq .
            ;;

        start|stop|restart)
            if [[ $# -eq 0 ]]; then
                error_exit "Usage: $0 $operation <container1> [container2] ..."
            fi

            local containers_json="["
            local first=true
            local successful=0
            local failed=0

            for container_name in "$@"; do
                validate_container_name "$container_name"

                local previous_state=$(get_container_state "$container_name")
                local result=""

                case "$operation" in
                    start)
                        result=$(start_container "$container_name")
                        ;;
                    stop)
                        result=$(stop_container "$container_name")
                        ;;
                    restart)
                        result=$(restart_container "$container_name")
                        ;;
                esac

                local current_state=$(get_container_state "$container_name")
                local operation_success=false

                if [[ "$result" == "running" ]] || [[ "$result" == "stopped" ]] || [[ "$result" == "restarted" ]]; then
                    operation_success=true
                    ((successful++))
                elif [[ "$result" == "already_running" ]] || [[ "$result" == "already_stopped" ]]; then
                    operation_success=true
                    ((successful++))
                else
                    ((failed++))
                fi

                if [[ "$first" == "true" ]]; then
                    containers_json+="{\"name\":\"$container_name\",\"previous_state\":\"$previous_state\",\"current_state\":\"$current_state\",\"operation_success\":$operation_success}"
                    first=false
                else
                    containers_json+=",{\"name\":\"$container_name\",\"previous_state\":\"$previous_state\",\"current_state\":\"$current_state\",\"operation_success\":$operation_success}"
                fi
            done

            containers_json+="]"

            local total=$(($successful + $failed))
            echo '{"success":true,"operation":"'"$operation"'","containers":'"$containers_json"',"total_containers":'"$total"',"successful_operations":'"$successful"',"failed_operations":'"$failed"',"timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}' | jq .
            ;;

        *)
            error_exit "Unknown operation: $operation"
            ;;
    esac
}

# Run main function
main "$@"