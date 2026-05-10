#!/bin/bash

# check_service_dependencies.sh
# Check service dependencies before GPU switching
# Usage: ./check_service_dependencies.sh <pci_address>

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
    secure_log "$level" "[CHECK_DEPS] $message"
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

# Check if Docker is available
check_docker() {
    command -v docker &> /dev/null && docker info &> /dev/null
}

# Check if virsh is available
check_virsh() {
    command -v virsh &> /dev/null && virsh version &> /dev/null
}

# Get GPU-dependent containers
get_gpu_dependent_containers() {
    local pci_address="$1"
    local containers_json="["

    if check_docker; then
        local first=true
        while IFS= read -r line; do
            local name=$(echo "$line" | cut -d'|' -f1)
            local status=$(echo "$line" | cut -d'|' -f2)
            local state=$(echo "$line" | cut -d'|' -f3)

            # Check if container is using GPU
            local gpu_usage=""
            if docker inspect --format='{{range .HostConfig.DeviceRequests}}{{.DeviceIDs}}{{end}}' "$name" 2>/dev/null | grep -q "$pci_address"; then
                gpu_usage="$pci_address"
            elif docker inspect --format='{{.HostConfig.Runtime}}' "$name" 2>/dev/null | grep -q "nvidia"; then
                gpu_usage="nvidia-runtime"
            fi

            if [[ -n "$gpu_usage" ]]; then
                if [[ "$first" == "true" ]]; then
                    containers_json+="{\"type\":\"container\",\"name\":\"$name\",\"state\":\"$state\",\"gpu_usage\":\"$gpu_usage\"}"
                    first=false
                else
                    containers_json+=",{\"type\":\"container\",\"name\":\"$name\",\"state\":\"$state\",\"gpu_usage\":\"$gpu_usage\"}"
                fi
            fi
        done < <(docker ps -a --format "{{.Names}}|{{.Status}}|{{.State}}")
    fi

    containers_json+="]"
    echo "$containers_json"
}

# Get GPU-dependent VMs
get_gpu_dependent_vms() {
    local pci_address="$1"
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

                # Check if matches target GPU
                if [[ "$formatted_gpu" == "$pci_address" ]]; then
                    if [[ "$first" == "true" ]]; then
                        vms_json+="{\"type\":\"vm\",\"name\":\"$vm_name\",\"state\":\"$state\",\"gpu_config\":\"$formatted_gpu\"}"
                        first=false
                    else
                        vms_json+=",{\"type\":\"vm\",\"name\":\"$vm_name\",\"state\":\"$state\",\"gpu_config\":\"$formatted_gpu\"}"
                    fi
                fi
            fi
        done < <(virsh list --all)
    fi

    vms_json+="]"
    echo "$vms_json"
}

# Get blocking services
get_blocking_services() {
    local pci_address="$1"
    local blocking_json="["

    # Check GPU-dependent containers
    if check_docker; then
        while IFS= read -r line; do
            local name=$(echo "$line" | cut -d'|' -f1)
            local state=$(echo "$line" | cut -d'|' -f3)

            # Check if container is running and using GPU
            if [[ "$state" == "running" ]]; then
                local gpu_usage=""
                if docker inspect --format='{{range .HostConfig.DeviceRequests}}{{.DeviceIDs}}{{end}}' "$name" 2>/dev/null | grep -q "$pci_address"; then
                    gpu_usage="$pci_address"
                elif docker inspect --format='{{.HostConfig.Runtime}}' "$name" 2>/dev/null | grep -q "nvidia"; then
                    gpu_usage="nvidia-runtime"
                fi

                if [[ -n "$gpu_usage" ]]; then
                    blocking_json+="{\"type\":\"container\",\"name\":\"$name\",\"state\":\"$state\",\"reason\":\"Container is actively using GPU\"},"
                fi
            fi
        done < <(docker ps --format "{{.Names}}|{{.Status}}|{{.State}}")
    fi

    # Check GPU-dependent VMs
    if check_virsh; then
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

                # Check if matches target GPU and is running
                if [[ "$formatted_gpu" == "$pci_address" ]] && [[ "$state" == "running" ]]; then
                    blocking_json+="{\"type\":\"vm\",\"name\":\"$vm_name\",\"state\":\"$state\",\"reason\":\"VM is actively using GPU\"},"
                fi
            fi
        done < <(virsh list --all)
    fi

    # Remove trailing comma if present
    blocking_json="${blocking_json%,}"
    blocking_json+="]"

    echo "$blocking_json"
}

# Determine if safe to switch
determine_safe_to_switch() {
    local pci_address="$1"
    local blocking_services=$(get_blocking_services "$pci_address")

    # Parse blocking services count
    local blocking_count=$(echo "$blocking_services" | jq 'length')

    if [[ "$blocking_count" -gt 0 ]]; then
        echo "false"
    else
        echo "true"
    fi
}

# Generate recommendations
generate_recommendations() {
    local pci_address="$1"
    local recommendations_json="["

    local first=true

    # Check GPU-dependent containers
    if check_docker; then
        while IFS= read -r line; do
            local name=$(echo "$line" | cut -d'|' -f1)
            local state=$(echo "$line" | cut -d'|' -f3)

            # Check if container is using GPU
            local gpu_usage=""
            if docker inspect --format='{{range .HostConfig.DeviceRequests}}{{.DeviceIDs}}{{end}}' "$name" 2>/dev/null | grep -q "$pci_address"; then
                gpu_usage="$pci_address"
            elif docker inspect --format='{{.HostConfig.Runtime}}' "$name" 2>/dev/null | grep -q "nvidia"; then
                gpu_usage="nvidia-runtime"
            fi

            if [[ -n "$gpu_usage" ]]; then
                if [[ "$state" == "running" ]]; then
                    if [[ "$first" == "true" ]]; then
                        recommendations_json+='"Stop '"$name"' container before switching GPU"'
                        first=false
                    else
                        recommendations_json+=',"Stop '"$name"' container before switching GPU"'
                    fi
                else
                    if [[ "$first" == "true" ]]; then
                        recommendations_json+='"'"$name"' container is not running, no action needed"'
                        first=false
                    else
                        recommendations_json+=',"'"$name"' container is not running, no action needed"'
                    fi
                fi
            fi
        done < <(docker ps -a --format "{{.Names}}|{{.Status}}|{{.State}}")
    fi

    # Check GPU-dependent VMs
    if check_virsh; then
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

                # Check if matches target GPU
                if [[ "$formatted_gpu" == "$pci_address" ]]; then
                    if [[ "$state" == "running" ]]; then
                        if [[ "$first" == "true" ]]; then
                            recommendations_json+='"Stop '"$vm_name"' VM before switching GPU"'
                            first=false
                        else
                            recommendations_json+=',"Stop '"$vm_name"' VM before switching GPU"'
                        fi
                    else
                        if [[ "$first" == "true" ]]; then
                            recommendations_json+='"'"$vm_name"' VM is not running, no action needed"'
                            first=false
                        else
                            recommendations_json+=',"'"$vm_name"' VM is not running, no action needed"'
                        fi
                    fi
                fi
            fi
        done < <(virsh list --all)
    fi

    recommendations_json+="]"
    echo "$recommendations_json"
}

# Main function
main() {
    # Check arguments
    if [[ $# -ne 1 ]]; then
        error_exit "Usage: $0 <pci_address>"
    fi

    local pci_address="$1"

    log "INFO" "Checking service dependencies for GPU: $pci_address"

    # Validate PCI address
    validate_pci_address "$pci_address"

    # Get dependent services
    local dependent_containers=$(get_gpu_dependent_containers "$pci_address")
    local dependent_vms=$(get_gpu_dependent_vms "$pci_address")

    # Get blocking services
    local blocking_services=$(get_blocking_services "$pci_address")

    # Determine if safe to switch
    local safe_to_switch=$(determine_safe_to_switch "$pci_address")

    # Generate recommendations
    local recommendations=$(generate_recommendations "$pci_address")

    # Build JSON output
    local json_output='{"success":true,"gpu_address":"'"$pci_address"'","safe_to_switch":'"$safe_to_switch"',"blocking_services":'"$blocking_services"',"dependent_services":['

    # Combine dependent services
    local first=true
    if [[ "$dependent_containers" != "[]" ]]; then
        json_output+="$dependent_containers"
        first=false
    fi

    if [[ "$dependent_vms" != "[]" ]]; then
        if [[ "$first" == "true" ]]; then
            json_output+="$dependent_vms"
        else
            json_output+=",$dependent_vms"
        fi
    fi

    json_output+="],\"recommendations\":$recommendations,\"timestamp\":\""$(date -u '+%Y-%m-%dT%H:%M:%SZ')"\"}"

    log "INFO" "Service dependency check: safe_to_switch=$safe_to_switch"

    echo "$json_output" | jq .
}

# Run main function
main "$@"