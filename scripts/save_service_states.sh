#!/bin/bash

# save_service_states.sh
# Save current service states before GPU switching
# Usage: ./save_service_states.sh <pci_address>

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
    secure_log "$level" "[SAVE_STATES] $message"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    secure_error_exit "$1"
}

# Validate PCI address format
validate_pci_address() {
    local pci_address="$1"
    if [[ ! "$pci_address" =~ ^[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-7]$ ]]; then
        error_exit "Invalid PCI address format: $pci_address"
    fi
}

# Create state directory
create_state_dir() {
    if [[ ! -d "$STATE_DIR" ]]; then
        mkdir -p "$STATE_DIR" 2>/dev/null || {
            error_exit "Failed to create state directory: $STATE_DIR"
        }
        log "INFO" "Created state directory: $STATE_DIR"
    fi
}

# Check if Docker is available
check_docker() {
    command -v docker &> /dev/null && docker info &> /dev/null
}

# Check if virsh is available
check_virsh() {
    command -v virsh &> /dev/null && virsh version &> /dev/null
}

# Get container states
get_container_states() {
    local containers_json="["

    if check_docker; then
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

            if [[ "$first" == "true" ]]; then
                containers_json+="{\"name\":\"$name\",\"status\":\"$status\",\"state\":\"$state\",\"gpu_usage\":\"$gpu_usage\"}"
                first=false
            else
                containers_json+=",{\"name\":\"$name\",\"status\":\"$status\",\"state\":\"$state\",\"gpu_usage\":\"$gpu_usage\"}"
            fi
        done < <(docker ps -a --format "{{.Names}}|{{.Status}}|{{.State}}")
    fi

    containers_json+="]"
    echo "$containers_json"
}

# Get VM states
get_vm_states() {
    local vms_json="["

    if check_virsh; then
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

            if [[ "$first" == "true" ]]; then
                vms_json+="{\"name\":\"$vm_name\",\"state\":\"$state\",\"gpu_config\":\"$formatted_gpu\"}"
                first=false
            else
                vms_json+=",{\"name\":\"$vm_name\",\"state\":\"$state\",\"gpu_config\":\"$formatted_gpu\"}"
            fi
        done < <(virsh list --all)
    fi

    vms_json+="]"
    echo "$vms_json"
}

# Save state to file
save_state_file() {
    local pci_address="$1"
    local container_states="$2"
    local vm_states="$3"

    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    local state_file="$STATE_DIR/service_state_${timestamp}.json"

    # Create state JSON
    local state_json='{"timestamp":"'"$timestamp"'","gpu_address":"'"$pci_address"'","containers":'"$container_states"',"vms":'"$vm_states"'}'

    # Write to file
    echo "$state_json" > "$state_file" 2>/dev/null || {
        error_exit "Failed to write state file: $state_file"
    }

    log "INFO" "Saved service states to: $state_file"
    echo "$state_file"
}

# Main function
main() {
    # Check arguments
    if [[ $# -ne 1 ]]; then
        error_exit "Usage: $0 <pci_address>"
    fi

    local pci_address="$1"

    log "INFO" "Saving service states for GPU: $pci_address"

    # Validate PCI address
    validate_pci_address "$pci_address"

    # Create state directory
    create_state_dir

    # Get container states
    log "INFO" "Getting container states"
    local container_states=$(get_container_states)

    # Get VM states
    log "INFO" "Getting VM states"
    local vm_states=$(get_vm_states)

    # Save state to file
    local state_file=$(save_state_file "$pci_address" "$container_states" "$vm_states")

    # Count services
    local container_count=$(echo "$container_states" | jq 'length')
    local vm_count=$(echo "$vm_states" | jq 'length')

    # Success
    echo '{"success":true,"message":"Service states saved successfully","gpu_address":"'"$pci_address"'","state_file":"'"$state_file"'","container_count":'"$container_count"',"vm_count":'"$vm_count"',"timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}}' | jq .
}

# Run main function
main "$@"