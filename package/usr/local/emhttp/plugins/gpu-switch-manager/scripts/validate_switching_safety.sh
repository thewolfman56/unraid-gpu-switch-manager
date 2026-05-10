#!/bin/bash

# validate_switching_safety.sh
# Validate GPU switching safety before execution
# Usage: ./validate_switching_safety.sh <action> <gpu_address>

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
    secure_log "$level" "[VALIDATE_SAFETY] $message"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    secure_error_exit "$1"
}

# Validate action
validate_action() {
    local action="$1"

    case "$action" in
        bind_to_vfio|unbind_from_vfio)
            return 0
            ;;
        *)
            error_exit "Invalid action: $action (must be bind_to_vfio or unbind_from_vfio)"
            ;;
    esac
}

# Validate GPU address
validate_gpu_address() {
    local gpu_address="$1"

    if [[ -z "$gpu_address" ]]; then
        error_exit "GPU address is required"
    fi

    # Check format (domain:bus:slot.function)
    if [[ ! "$gpu_address" =~ ^[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f]$ ]]; then
        error_exit "Invalid GPU address format: $gpu_address (expected format: dd:bb:ss.f)"
    fi

    # Check if device exists
    local device_path="/sys/bus/pci/devices/0000:$gpu_address"

    if [[ ! -d "$device_path" ]]; then
        error_exit "GPU device not found: $gpu_address"
    fi
}

# Check for active GPU usage
check_active_gpu_usage() {
    local gpu_address="$1"

    log "INFO" "Checking for active GPU usage: $gpu_address"

    local in_use=false
    local usage_details='[]'

    # Check for GPU-dependent Docker containers
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        local containers=$(docker ps --format '{{.Names}}' 2>/dev/null || echo "")

        while IFS= read -r container; do
            if [[ -n "$container" ]]; then
                # Check if container uses GPU
                local gpu_usage=$(docker inspect --format='{{range .HostConfig.DeviceRequests}}{{.DeviceIDs}}{{end}}' "$container" 2>/dev/null || echo "")

                if [[ -n "$gpu_usage" ]]; then
                    in_use=true
                    usage_details=$(echo "$usage_details" | jq --arg container "$container" --arg type "docker" '. + [{"service_name": $container, "type": $type}]')
                fi
            fi
        done <<< "$containers"
    fi

    # Check for running VMs using GPU
    if command -v virsh &> /dev/null; then
        local vms=$(virsh list --name --state-running 2>/dev/null || echo "")

        while IFS= read -r vm; do
            if [[ -n "$vm" ]]; then
                # Check if VM uses GPU
                if [[ -f "$SCRIPT_DIR/check_vm_gpu_requirements.sh" ]]; then
                    local vm_gpu=$("$SCRIPT_DIR/check_vm_gpu_requirements.sh" "$vm" 2>&1)

                    if echo "$vm_gpu" | jq -e '.has_gpu' &>/dev/null && [[ $(echo "$vm_gpu" | jq -r '.has_gpu') == "true" ]]; then
                        local vm_gpu_devices=$(echo "$vm_gpu" | jq -r '.gpu_devices[].address')

                        if echo "$vm_gpu_devices" | grep -q "^${gpu_address}$"; then
                            in_use=true
                            usage_details=$(echo "$usage_details" | jq --arg vm "$vm" --arg type "vm" '. + [{"service_name": $vm, "type": $type}]')
                        fi
                    fi
                fi
            fi
        done <<< "$vms"
    fi

    echo '{"in_use":'"$in_use"',"usage_details":'"$usage_details"'}'
}

# Check service dependencies
check_service_dependencies() {
    local gpu_address="$1"
    local action="$2"

    log "INFO" "Checking service dependencies for action: $action, GPU: $gpu_address"

    local has_dependencies=false
    local dependency_details='[]'

    # Check for GPU-dependent services
    if [[ -f "$SCRIPT_DIR/check_service_dependencies.sh" ]]; then
        local dependencies=$("$SCRIPT_DIR/check_service_dependencies.sh" "$gpu_address" 2>&1)

        if echo "$dependencies" | jq -e '.gpu_dependent_containers' &>/dev/null; then
            local container_count=$(echo "$dependencies" | jq -r '.gpu_dependent_containers | length')

            if [[ "$container_count" -gt 0 ]]; then
                has_dependencies=true
                dependency_details=$(echo "$dependencies" | jq '.gpu_dependent_containers | map({service_name: ., type: "docker"})')
            fi
        fi

        if echo "$dependencies" | jq -e '.gpu_dependent_vms' &>/dev/null; then
            local vm_count=$(echo "$dependencies" | jq -r '.gpu_dependent_vms | length')

            if [[ "$vm_count" -gt 0 ]]; then
                has_dependencies=true
                local vm_details=$(echo "$dependencies" | jq '.gpu_dependent_vms | map({service_name: ., type: "vm"})')
                dependency_details=$(echo "$dependency_details" | jq --argjson vm_details "$vm_details" '. + $vm_details')
            fi
        fi
    fi

    echo '{"has_dependencies":'"$has_dependencies"',"dependency_details":'"$dependency_details"'}'
}

# Check resource availability
check_resource_availability() {
    local gpu_address="$1"
    local action="$2"

    log "INFO" "Checking resource availability for action: $action, GPU: $gpu_address"

    local resources_available=true
    local resource_issues='[]'

    # Check if vfio-pci module is available
    if [[ "$action" == "bind_to_vfio" ]]; then
        if ! lsmod | grep -q "^vfio_pci "; then
            resources_available=false
            resource_issues=$(echo "$resource_issues" | jq '. + [{"type": "module", "message": "vfio-pci module not loaded"}]')
        fi
    fi

    # Check if GPU driver is available
    if [[ "$action" == "unbind_from_vfio" ]]; then
        local device_path="/sys/bus/pci/devices/0000:$gpu_address"
        local vendor_id=$(cat "$device_path/vendor" 2>/dev/null | sed 's/0x//' || echo "unknown")
        local device_id=$(cat "$device_path/device" 2>/dev/null | sed 's/0x//' || echo "unknown")

        # Check for appropriate driver based on vendor
        case "$vendor_id" in
            10de)  # NVIDIA
                if ! lsmod | grep -q "^nvidia "; then
                    resources_available=false
                    resource_issues=$(echo "$resource_issues" | jq '. + [{"type": "driver", "message": "NVIDIA driver not loaded"}]')
                fi
                ;;
            1002)  # AMD
                if ! lsmod | grep -q "^amdgpu "; then
                    resources_available=false
                    resource_issues=$(echo "$resource_issues" | jq '. + [{"type": "driver", "message": "AMDGPU driver not loaded"}]')
                fi
                ;;
            8086)  # Intel
                if ! lsmod | grep -q "^i915 "; then
                    resources_available=false
                    resource_issues=$(echo "$resource_issues" | jq '. + [{"type": "driver", "message": "Intel i915 driver not loaded"}]')
                fi
                ;;
        esac
    fi

    echo '{"resources_available":'"$resources_available"',"resource_issues":'"$resource_issues"'}'
}

# Check for conflicts
check_conflicts() {
    local gpu_address="$1"
    local action="$2"

    log "INFO" "Checking for conflicts for action: $action, GPU: $gpu_address"

    local has_conflicts=false
    local conflict_details='[]'

    # Check for IOMMU group conflicts
    local device_path="/sys/bus/pci/devices/0000:$gpu_address"
    local iommu_group=$(readlink "$device_path/iommu_group" 2>/dev/null | xargs basename 2>/dev/null || echo "")

    if [[ -n "$iommu_group" ]]; then
        local iommu_group_path="/sys/kernel/iommu_groups/$iommu_group/devices"

        if [[ -d "$iommu_group_path" ]]; then
            local device_count=$(find "$iommu_group_path" -maxdepth 1 -type l | wc -l)

            if [[ "$device_count" -gt 1 ]]; then
                # Check if other devices in the group are in use
                local other_devices=$(find "$iommu_group_path" -maxdepth 1 -type l -not -name "0000:$gpu_address" -exec basename {} \;)

                while IFS= read -r other_device; do
                    if [[ -n "$other_device" ]]; then
                        # Check if other device is in use
                        local other_driver_path="/sys/bus/pci/devices/$other_device/driver"

                        if [[ -L "$other_driver_path" ]]; then
                            local other_driver=$(basename "$(readlink "$other_driver_path")")

                            if [[ "$other_driver" != "vfio-pci" ]]; then
                                has_conflicts=true
                                conflict_details=$(echo "$conflict_details" | jq --arg device "$other_device" --arg driver "$other_driver" '. + [{"device": $device, "driver": $driver, "message": "Device in IOMMU group not bound to VFIO"}]')
                            fi
                        fi
                    fi
                done <<< "$other_devices"
            fi
        fi
    fi

    echo '{"has_conflicts":'"$has_conflicts"',"conflict_details":'"$conflict_details"'}'
}

# Validate system stability
validate_system_stability() {
    log "INFO" "Validating system stability"

    local system_stable=true
    local stability_issues='[]'

    # Check system load
    local load_avg=$(cat /proc/loadavg | awk '{print $1}')
    local cpu_count=$(nproc)
    local load_threshold=$((cpu_count * 2))

    if (( $(echo "$load_avg > $load_threshold" | bc -l) )); then
        system_stable=false
        stability_issues=$(echo "$stability_issues" | jq --arg load "$load_avg" --arg threshold "$load_threshold" '. + [{"type": "load", "message": "System load too high: '"$load_avg"' (threshold: '"$load_threshold"')"}]')
    fi

    # Check available memory
    local available_mem=$(free -m | awk '/^Mem:/ {print $7}')
    local min_mem=512  # Minimum 512MB

    if [[ "$available_mem" -lt "$min_mem" ]]; then
        system_stable=false
        stability_issues=$(echo "$stability_issues" | jq --arg mem "$available_mem" --arg min "$min_mem" '. + [{"type": "memory", "message": "Low available memory: '"$available_mem"'MB (minimum: '"$min_mem"'MB)"}]')
    fi

    echo '{"system_stable":'"$system_stable"',"stability_issues":'"$stability_issues"'}'
}

# Main function
main() {
    # Check arguments
    if [[ $# -lt 2 ]]; then
        error_exit "Usage: $0 <action> <gpu_address>"
    fi

    local action="$1"
    local gpu_address="$2"

    log "INFO" "Validating switching safety: action=$action, gpu_address=$gpu_address"

    # Validate action
    validate_action "$action"

    # Validate GPU address
    validate_gpu_address "$gpu_address"

    # Check active GPU usage
    local active_usage=$(check_active_gpu_usage "$gpu_address")
    local in_use=$(echo "$active_usage" | jq -r '.in_use')

    # Check service dependencies
    local dependencies=$(check_service_dependencies "$gpu_address" "$action")
    local has_dependencies=$(echo "$dependencies" | jq -r '.has_dependencies')

    # Check resource availability
    local resources=$(check_resource_availability "$gpu_address" "$action")
    local resources_available=$(echo "$resources" | jq -r '.resources_available')

    # Check for conflicts
    local conflicts=$(check_conflicts "$gpu_address" "$action")
    local has_conflicts=$(echo "$conflicts" | jq -r '.has_conflicts')

    # Validate system stability
    local stability=$(validate_system_stability)
    local system_stable=$(echo "$stability" | jq -r '.system_stable')

    # Determine overall safety
    local is_safe=true
    local safety_issues='[]'

    if [[ "$in_use" == "true" ]]; then
        is_safe=false
        safety_issues=$(echo "$safety_issues" | jq --argjson usage "$active_usage" '. + $usage.usage_details | map({type: "active_usage", service_name: .service_name, service_type: .type})')
    fi

    if [[ "$has_dependencies" == "true" ]]; then
        is_safe=false
        safety_issues=$(echo "$safety_issues" | jq --argjson deps "$dependencies" '. + $deps.dependency_details | map({type: "dependency", service_name: .service_name, service_type: .type})')
    fi

    if [[ "$resources_available" != "true" ]]; then
        is_safe=false
        safety_issues=$(echo "$safety_issues" | jq --argjson res "$resources" '. + $res.resource_issues | map({type: "resource", message: .message})')
    fi

    if [[ "$has_conflicts" == "true" ]]; then
        is_safe=false
        safety_issues=$(echo "$safety_issues" | jq --argjson conf "$conflicts" '. + $conf.conflict_details | map({type: "conflict", device: .device, message: .message})')
    fi

    if [[ "$system_stable" != "true" ]]; then
        is_safe=false
        safety_issues=$(echo "$safety_issues" | jq --argjson stab "$stability" '. + $stab.stability_issues | map({type: "stability", message: .message})')
    fi

    # Build JSON output
    local json_output='{"success":true,"is_safe":'"$is_safe"',"action":"'"$action"'","gpu_address":"'"$gpu_address"'","checks":{'
    json_output+='"active_usage":'"$active_usage"','
    json_output+='"service_dependencies":'"$dependencies"','
    json_output+='"resource_availability":'"$resources"','
    json_output+='"conflicts":'"$conflicts"','
    json_output+='"system_stability":'"$stability"
    json_output+='},"safety_issues":'"$safety_issues"',"timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}}'

    log "INFO" "Switching safety validation completed: is_safe=$is_safe"

    echo "$json_output" | jq .
}

# Run main function
main "$@"