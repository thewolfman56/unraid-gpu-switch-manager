#!/bin/bash

# validate_service_operation.sh
# Validate service operations before execution
# Usage: ./validate_service_operation.sh <operation_type> <service_type> <service1> [<service2> ...]

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
    secure_log "$level" "[VALIDATE_SERVICE_OP] $message"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    secure_error_exit "$1"
}

# Validate operation type
validate_operation_type() {
    local operation_type="$1"

    case "$operation_type" in
        start|stop|restart|shutdown|destroy)
            return 0
            ;;
        *)
            error_exit "Invalid operation type: $operation_type (must be start, stop, restart, shutdown, or destroy)"
            ;;
    esac
}

# Validate service type
validate_service_type() {
    local service_type="$1"

    case "$service_type" in
        docker|vm)
            return 0
            ;;
        *)
            error_exit "Invalid service type: $service_type (must be docker or vm)"
            ;;
    esac
}

# Check if Docker is available
check_docker() {
    command -v docker &> /dev/null && docker info &> /dev/null
}

# Check if virsh is available
check_virsh() {
    command -v virsh &> /dev/null && virsh version &> /dev/null
}

# Validate Docker container operation
validate_docker_operation() {
    local operation_type="$1"
    local container_name="$2"

    # Check if container exists
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        echo '{"valid":false,"reason":"Container not found","service_name":"'"$container_name"'"}'
        return
    fi

    # Get current state
    local current_state=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "unknown")

    # Validate operation compatibility with current state
    local valid=true
    local reason=""

    case "$operation_type" in
        start)
            if [[ "$current_state" == "running" ]]; then
                valid=false
                reason="Container is already running"
            elif [[ "$current_state" == "paused" ]]; then
                valid=false
                reason="Container is paused, cannot start"
            fi
            ;;
        stop)
            if [[ "$current_state" == "exited" ]] || [[ "$current_state" == "created" ]]; then
                valid=false
                reason="Container is already stopped"
            fi
            ;;
        restart)
            if [[ "$current_state" == "paused" ]]; then
                valid=false
                reason="Container is paused, cannot restart"
            fi
            ;;
        shutdown|destroy)
            # These operations are not applicable to containers
            valid=false
            reason="Operation not applicable to containers"
            ;;
    esac

    echo '{"valid":'"$valid"',"reason":"'"$reason"'","service_name":"'"$container_name"'","current_state":"'"$current_state"'"}'
}

# Validate VM operation
validate_vm_operation() {
    local operation_type="$1"
    local vm_name="$2"

    # Check if VM exists
    if ! virsh list --all | grep -q "^\s*${vm_name}\s"; then
        echo '{"valid":false,"reason":"VM not found","service_name":"'"$vm_name"'"}'
        return
    fi

    # Get current state
    local current_state=$(virsh domstate "$vm_name" 2>/dev/null || echo "unknown")

    # Validate operation compatibility with current state
    local valid=true
    local reason=""

    case "$operation_type" in
        start)
            if [[ "$current_state" == "running" ]]; then
                valid=false
                reason="VM is already running"
            elif [[ "$current_state" == "paused" ]]; then
                valid=false
                reason="VM is paused, cannot start"
            fi
            ;;
        stop|shutdown)
            if [[ "$current_state" == "shut off" ]]; then
                valid=false
                reason="VM is already stopped"
            fi
            ;;
        destroy)
            if [[ "$current_state" == "shut off" ]]; then
                valid=false
                reason="VM is already stopped"
            fi
            ;;
        restart)
            if [[ "$current_state" == "paused" ]]; then
                valid=false
                reason="VM is paused, cannot restart"
            fi
            ;;
    esac

    echo '{"valid":'"$valid"',"reason":"'"$reason"'","service_name":"'"$vm_name"'","current_state":"'"$current_state"'"}'
}

# Check for resource conflicts
check_resource_conflicts() {
    local service_type="$1"
    shift
    local services=("$@")

    local conflicts_json="["

    # Check for GPU conflicts
    if [[ "$service_type" == "docker" ]] && check_docker; then
        for service_name in "${services[@]}"; do
            # Check if container uses GPU
            local gpu_usage=$(docker inspect --format='{{range .HostConfig.DeviceRequests}}{{.DeviceIDs}}{{end}}' "$service_name" 2>/dev/null || echo "")

            if [[ -n "$gpu_usage" ]]; then
                conflicts_json+="{\"type\":\"gpu_conflict\",\"service_name\":\"$service_name\",\"gpu_usage\":\"$gpu_usage\"},"
            fi
        done
    elif [[ "$service_type" == "vm" ]] && check_virsh; then
        for service_name in "${services[@]}"; do
            # Check if VM uses GPU
            local gpu_config=$(virsh dumpxml "$service_name" 2>/dev/null | grep -A 10 "hostdev" | grep "pci" | grep -oP 'domain="0x[0-9a-f]+"\s+bus="0x[0-9a-f]+"\s+slot="0x[0-9a-f]+"\s+function="0x[0-9a-f]+"' | sed 's/domain="0x//;s/"\s+bus="0x/:/;s/"\s+slot="0x/:/;s/"\s+function="0x/./;s/"//g' | head -1)

            if [[ -n "$gpu_config" ]]; then
                conflicts_json+="{\"type\":\"gpu_conflict\",\"service_name\":\"$service_name\",\"gpu_config\":\"$gpu_config\"},"
            fi
        done
    fi

    # Remove trailing comma if present
    conflicts_json="${conflicts_json%,}"
    conflicts_json+="]"

    echo "$conflicts_json"
}

# Check for dependency conflicts
check_dependency_conflicts() {
    local service_type="$1"
    shift
    local services=("$@")

    local conflicts_json="["

    # Check for service dependencies
    if [[ "$service_type" == "docker" ]] && check_docker; then
        for service_name in "${services[@]}"; do
            # Check if container has dependencies
            local depends_on=$(docker inspect --format='{{range .Config.Env}}{{if contains . \"DEPENDS_ON="}}{{.}}{{end}}{{end}}' "$service_name" 2>/dev/null || echo "")

            if [[ -n "$depends_on" ]]; then
                conflicts_json+="{\"type\":\"dependency_conflict\",\"service_name\":\"$service_name\",\"depends_on\":\"$depends_on\"},"
            fi
        done
    fi

    # Remove trailing comma if present
    conflicts_json="${conflicts_json%,}"
    conflicts_json+="]"

    echo "$conflicts_json"
}

# Check for safety concerns
check_safety_concerns() {
    local operation_type="$1"
    local service_type="$2"
    shift
    local services=("$@")

    local concerns_json="["

    # Check for safety concerns based on operation type
    case "$operation_type" in
        stop|shutdown|destroy)
            # Check if services are in use
            if [[ "$service_type" == "docker" ]] && check_docker; then
                for service_name in "${services[@]}"; do
                    local current_state=$(docker inspect --format='{{.State.Status}}' "$service_name" 2>/dev/null || echo "unknown")

                    if [[ "$current_state" == "running" ]]; then
                        concerns_json+="{\"type\":\"service_in_use\",\"service_name\":\"$service_name\",\"current_state\":\"$current_state\",\"message\":\"Service is currently running and will be stopped\"},"
                    fi
                done
            elif [[ "$service_type" == "vm" ]] && check_virsh; then
                for service_name in "${services[@]}"; do
                    local current_state=$(virsh domstate "$service_name" 2>/dev/null || echo "unknown")

                    if [[ "$current_state" == "running" ]]; then
                        concerns_json+="{\"type\":\"service_in_use\",\"service_name\":\"$service_name\",\"current_state\":\"$current_state\",\"message\":\"VM is currently running and will be stopped\"},"
                    fi
                done
            fi
            ;;
    esac

    # Remove trailing comma if present
    concerns_json="${concerns_json%,}"
    concerns_json+="]"

    echo "$concerns_json"
}

# Main function
main() {
    # Check arguments
    if [[ $# -lt 3 ]]; then
        error_exit "Usage: $0 <operation_type> <service_type> <service1> [service2] ..."
    fi

    local operation_type="$1"
    local service_type="$2"
    shift 2
    local services=("$@")

    log "INFO" "Validating service operation (operation: $operation_type, type: $service_type, services: ${services[*]})"

    # Validate operation type
    validate_operation_type "$operation_type"

    # Validate service type
    validate_service_type "$service_type"

    # Validate each service
    local services_json="["
    local first=true
    local all_valid=true

    for service_name in "${services[@]}"; do
        local validation_result=""

        if [[ "$service_type" == "docker" ]]; then
            validation_result=$(validate_docker_operation "$operation_type" "$service_name")
        else
            validation_result=$(validate_vm_operation "$operation_type" "$service_name")
        fi

        local valid=$(echo "$validation_result" | jq -r '.valid')

        if [[ "$valid" == "false" ]]; then
            all_valid=false
        fi

        if [[ "$first" == "true" ]]; then
            services_json+="$validation_result"
            first=false
        else
            services_json+=",$validation_result"
        fi
    done

    services_json+="]"

    # Check for resource conflicts
    local resource_conflicts=$(check_resource_conflicts "$service_type" "${services[@]}")

    # Check for dependency conflicts
    local dependency_conflicts=$(check_dependency_conflicts "$service_type" "${services[@]}")

    # Check for safety concerns
    local safety_concerns=$(check_safety_concerns "$operation_type" "$service_type" "${services[@]}")

    # Build JSON output
    local json_output='{"success":true,"operation_type":"'"$operation_type"'","service_type":"'"$service_type"'","all_valid":'"$all_valid"',"services":'"$services_json"',"resource_conflicts":'"$resource_conflicts"',"dependency_conflicts":'"$dependency_conflicts"',"safety_concerns":'"$safety_concerns"',"timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}}'

    log "INFO" "Service operation validation: all_valid=$all_valid"

    echo "$json_output" | jq .
}

# Run main function
main "$@"