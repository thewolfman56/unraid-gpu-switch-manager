#!/bin/bash

# get_service_status.sh
# Get current status of all services
# Usage: ./get_service_status.sh <service_type>

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
    secure_log "$level" "[GET_SERVICE_STATUS] $message"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    secure_error_exit "$1"
}

# Validate service type
validate_service_type() {
    local service_type="$1"

    case "$service_type" in
        docker|vm|all)
            return 0
            ;;
        *)
            error_exit "Invalid service type: $service_type (must be docker, vm, or all)"
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

# Get Docker status
get_docker_status() {
    local docker_json='{"available":false,"total_containers":0,"running_containers":0,"stopped_containers":0,"gpu_dependent":[]}'

    if check_docker; then
        local total_containers=$(docker ps -a --format '{{.Names}}' | wc -l)
        local running_containers=$(docker ps --format '{{.Names}}' | wc -l)
        local stopped_containers=$((total_containers - running_containers))

        local gpu_dependent_json="["

        local first=true
        while IFS= read -r line; do
            local name=$(echo "$line" | cut -d'|' -f1)
            local status=$(echo "$line" | cut -d'|' -f2)
            local state=$(echo "$line" | cut -d'|' -f3)

            # Get GPU usage
            local gpu_usage=""
            if docker inspect --format='{{range .HostConfig.DeviceRequests}}{{.DeviceIDs}}{{end}}' "$name" 2>/dev/null | grep -q "."; then
                gpu_usage=$(docker inspect --format='{{range .HostConfig.DeviceRequests}}{{.DeviceIDs}}{{end}}' "$name" 2>/dev/null)
            elif docker inspect --format='{{.HostConfig.Runtime}}' "$name" 2>/dev/null | grep -q "nvidia"; then
                gpu_usage="nvidia-runtime"
            fi

            # Only include if GPU usage detected
            if [[ -n "$gpu_usage" ]]; then
                if [[ "$first" == "true" ]]; then
                    gpu_dependent_json+="{\"name\":\"$name\",\"state\":\"$state\",\"gpu_usage\":\"$gpu_usage\"}"
                    first=false
                else
                    gpu_dependent_json+=",{\"name\":\"$name\",\"state\":\"$state\",\"gpu_usage\":\"$gpu_usage\"}"
                fi
            fi
        done < <(docker ps -a --format "{{.Names}}|{{.Status}}|{{.State}}")

        gpu_dependent_json+="]"

        docker_json='{"available":true,"total_containers":'"$total_containers"',"running_containers":'"$running_containers"',"stopped_containers":'"$stopped_containers"',"gpu_dependent":'"$gpu_dependent_json"'}'
    fi

    echo "$docker_json"
}

# Get VM status
get_vm_status() {
    local vm_json='{"available":false,"total_vms":0,"running_vms":0,"stopped_vms":0,"gpu_dependent":[]}'

    if check_virsh; then
        local total_vms=$(virsh list --all | grep -v "^$" | grep -v "^-" | grep -v "Id" | wc -l)
        local running_vms=$(virsh list | grep -v "^$" | grep -v "^-" | grep -v "Id" | wc -l)
        local stopped_vms=$((total_vms - running_vms))

        local gpu_dependent_json="["

        local first=true
        while IFS= read -r line; do
            local vm_id=$(echo "$line" | awk '{print $1}')
            local vm_name=$(echo "$line" | awk '{print $2}')
            local state=$(echo "$line" | awk '{print $3}')

            # Skip header
            if [[ "$vm_id" == "Id" ]]; then
                continue
            fi

            # Get GPU configuration
            local gpu_config=$(virsh dumpxml "$vm_name" 2>/dev/null | grep -A 10 "hostdev" | grep "pci" | grep -oP 'domain="0x[0-9a-f]+"\s+bus="0x[0-9a-f]+"\s+slot="0x[0-9a-f]+"\s+function="0x[0-9a-f]+"' | sed 's/domain="0x//;s/"\s+bus="0x/:/;s/"\s+slot="0x/:/;s/"\s+function="0x/./;s/"//g' | head -1)

            if [[ -n "$gpu_config" ]]; then
                # Format as PCI address
                local domain=$(echo "$gpu_config" | cut -d: -f1)
                local bus=$(echo "$gpu_config" | cut -d: -f2)
                local slot=$(echo "$gpu_config" | cut -d: -f3)
                local func=$(echo "$gpu_config" | cut -d: -f4)

                local formatted_gpu=$(printf "%04x:%02x:%02x.%01x" "0x$domain" "0x$bus" "0x$slot" "0x$func")
            else
                local formatted_gpu=""
            fi

            # Only include if GPU configuration detected
            if [[ -n "$formatted_gpu" ]]; then
                if [[ "$first" == "true" ]]; then
                    gpu_dependent_json+="{\"name\":\"$vm_name\",\"state\":\"$state\",\"gpu_config\":\"$formatted_gpu\"}"
                    first=false
                else
                    gpu_dependent_json+=",{\"name\":\"$vm_name\",\"state\":\"$state\",\"gpu_config\":\"$formatted_gpu\"}"
                fi
            fi
        done < <(virsh list --all)

        gpu_dependent_json+="]"

        vm_json='{"available":true,"total_vms":'"$total_vms"',"running_vms":'"$running_vms"',"stopped_vms":'"$stopped_vms"',"gpu_dependent":'"$gpu_dependent_json"'}'
    fi

    echo "$vm_json"
}

# Main function
main() {
    # Check arguments
    if [[ $# -ne 1 ]]; then
        error_exit "Usage: $0 <service_type>"
    fi

    local service_type="$1"

    log "INFO" "Getting service status (type: $service_type)"

    # Validate service type
    validate_service_type "$service_type"

    # Build JSON output based on service type
    local json_output='{"success":true,"service_type":"'"$service_type"'","timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ")"'"

    case "$service_type" in
        docker)
            local docker_status=$(get_docker_status)
            json_output+=',"docker":'"$docker_status"'"
            ;;

        vm)
            local vm_status=$(get_vm_status)
            json_output+=',"vm":'"$vm_status"'"
            ;;

        all)
            local docker_status=$(get_docker_status)
            local vm_status=$(get_vm_status)
            json_output+=',"docker":'"$docker_status"',"vm":'"$vm_status"'"
            ;;
    esac

    json_output+='}'

    echo "$json_output" | jq .
}

# Run main function
main "$@"