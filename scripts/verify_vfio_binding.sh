#!/bin/bash

# verify_vfio_binding.sh
# Verify that VFIO binding is working correctly
# Usage: ./verify_vfio_binding.sh <pci_address>

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
    secure_log "$level" "[VERIFY_VFIO_BINDING] $message"
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

# Check if device exists
device_exists() {
    local pci_address="$1"
    local device_path="/sys/bus/pci/devices/$pci_address"
    if [[ ! -d "$device_path" ]]; then
        error_exit "Device not found: $pci_address"
    fi
}

# Check if device is a GPU
is_gpu_device() {
    local pci_address="$1"
    local class=$(lspci -s "$pci_address" -n | awk '{print $2}')
    if [[ ! "$class" =~ ^03 ]]; then
        error_exit "Device is not a GPU: $pci_address (class: $class)"
    fi
}

# Get current driver
get_current_driver() {
    local pci_address="$1"
    local driver_path="/sys/bus/pci/devices/$pci_address/driver"
    if [[ -L "$driver_path" ]]; then
        basename "$(readlink "$driver_path")"
    else
        echo "none"
    fi
}

# Check vfio-pci module status
check_vfio_module() {
    if lsmod | grep -q "^vfio_pci "; then
        echo "loaded"
    elif lsmod | grep -q "vfio_pci "; then
        echo "loaded"
    else
        echo "not_loaded"
    fi
}

# Check device in vfio-pci group
check_device_group() {
    local pci_address="$1"
    local current_driver=$(get_current_driver "$pci_address")

    if [[ "$current_driver" == "vfio-pci" ]]; then
        echo "in_vfio_group"
    else
        echo "not_in_vfio_group"
    fi
}

# Test device accessibility
test_device_accessibility() {
    local pci_address="$1"
    local device_path="/sys/bus/pci/devices/$pci_address"

    # Check if device directory exists and is readable
    if [[ ! -r "$device_path" ]]; then
        echo "not_accessible"
        return
    fi

    # Check if config file is readable
    if [[ ! -r "$device_path/config" ]]; then
        echo "not_accessible"
        return
    fi

    # Try to read config
    local config=$(cat "$device_path/config" 2>/dev/null || echo "")
    if [[ -z "$config" ]]; then
        echo "not_accessible"
        return
    fi

    echo "accessible"
}

# Check IOMMU groups
check_iommu_groups() {
    local pci_address="$1"
    local device_path="/sys/bus/pci/devices/$pci_address"
    local iommu_group_path="$device_path/iommu_group"

    if [[ -d "$iommu_group_path" ]]; then
        # Get IOMMU group number
        local group_number=$(basename "$(readlink "$iommu_group_path")" 2>/dev/null || echo "unknown")

        # Count devices in group
        local device_count=$(ls "$iommu_group_path/devices" 2>/dev/null | wc -l)

        echo "enabled|$group_number|$device_count"
    else
        echo "not_enabled||"
    fi
}

# Get IOMMU group devices
get_iommu_group_devices() {
    local pci_address="$1"
    local device_path="/sys/bus/pci/devices/$pci_address"
    local iommu_group_path="$device_path/iommu_group"

    if [[ -d "$iommu_group_path" ]]; then
        local devices_json="["

        local first=true
        for device in "$iommu_group_path/devices"/*; do
            if [[ -d "$device" ]]; then
                local device_addr=$(basename "$device")
                local device_name=$(lspci -s "$device_addr" | sed 's/.*: //' | sed 's/ (rev.*//')

                if [[ "$first" == "true" ]]; then
                    devices_json+="{\"address\":\"$device_addr\",\"name\":\"$device_addr\"}"
                    first=false
                else
                    devices_json+=",{\"address\":\"$device_addr\",\"name\":\"$device_addr\"}"
                fi
            fi
        done

        devices_json+="]"
        echo "$devices_json"
    else
        echo "[]"
    fi
}

# Verify passthrough readiness
verify_passthrough_readiness() {
    local pci_address="$1"
    local current_driver=$(get_current_driver "$pci_address")
    local vfio_module=$(check_vfio_module)
    local device_group=$(check_device_group "$pci_address")
    local accessibility=$(test_device_accessibility "$pci_address")
    local iommu_status=$(check_iommu_groups "$pci_address")

    # Parse IOMMU status
    local iommu_enabled=$(echo "$iommu_status" | cut -d| -f1)
    local iommu_group=$(echo "$iommu_status" | cut -d| -f2)
    local iommu_device_count=$(echo "$iommu_status" | cut -d| -f3)

    # Determine readiness
    local ready=true
    local reasons=()

    if [[ "$vfio_module" != "loaded" ]]; then
        ready=false
        reasons+=("vfio-pci module not loaded")
    fi

    if [[ "$device_group" != "in_vfio_group" ]]; then
        ready=false
        reasons+=("device not in vfio-pci group")
    fi

    if [[ "$accessibility" != "accessible" ]]; then
        ready=false
        reasons+=("device not accessible")
    fi

    if [[ "$iommu_enabled" != "enabled" ]]; then
        ready=false
        reasons+=("IOMMU not enabled")
    fi

    # Build reasons JSON
    local reasons_json="["
    local first=true
    for reason in "${reasons[@]}"; do
        if [[ "$first" == "true" ]]; then
            reasons_json+='"'"$reason"'"'
            first=false
        else
            reasons_json+=',"'"$reason"'"'
        fi
    done
    reasons_json+="]"

    echo "$ready|$reasons_json"
}

# Main function
main() {
    # Check arguments
    if [[ $# -ne 1 ]]; then
        error_exit "Usage: $0 <pci_address>"
    fi

    local pci_address="$1"

    log "INFO" "Verifying VFIO binding for $pci_address"

    # Validate inputs
    validate_pci_address "$pci_address"
    device_exists "$pci_address"
    is_gpu_device "$pci_address"

    # Get current driver
    local current_driver=$(get_current_driver "$pci_address")
    log "INFO" "Current driver: $current_driver"

    # Check vfio-pci module
    local vfio_module=$(check_vfio_module)
    log "INFO" "VFIO module status: $vfio_module"

    # Check device group
    local device_group=$(check_device_group "$pci_address")
    log "INFO" "Device group status: $device_group"

    # Test accessibility
    local accessibility=$(test_device_accessibility "$pci_address")
    log "INFO" "Device accessibility: $accessibility"

    # Check IOMMU groups
    local iommu_status=$(check_iommu_groups "$pci_address")
    local iommu_enabled=$(echo "$iommu_status" | cut -d| -f1)
    local iommu_group=$(echo "$iommu_status" | cut -d| -f2)
    local iommu_device_count=$(echo "$iommu_status" | cut -d| -f3)
    log "INFO" "IOMMU status: enabled=$iommu_enabled, group=$iommu_group, devices=$iommu_device_count"

    # Get IOMMU group devices
    local iommu_devices=$(get_iommu_group_devices "$pci_address")

    # Verify passthrough readiness
    local passthrough_status=$(verify_passthrough_readiness "$pci_address")
    local passthrough_ready=$(echo "$passthrough_status" | cut -d| -f1)
    local passthrough_reasons=$(echo "$passthrough_status" | cut -d| -f2)

    # Build JSON output
    local json_output='{"success":true,"pci_address":"'"$pci_address"'","current_driver":"'"$current_driver"'","vfio_module_loaded":'"$([ "$vfio_module" == "loaded" ] && echo "true" || echo "false")"',"device_in_vfio_group":'"$([ "$device_group" == "in_vfio_group" ] && echo "true" || echo "false")"',"device_accessible":'"$([ "$accessibility" == "accessible" ] && echo "true" || echo "false")"',"iommu_enabled":'"$([ "$iommu_enabled" == "enabled" ] && echo "true" || echo "false")"',"iommu_group":"'"$iommu_group"'","iommu_group_devices":'"$iommu_devices"'","iommu_group_device_count":'"$iommu_device_count"'","passthrough_ready":'"$passthrough_ready"',"passthrough_reasons":'"$passthrough_reasons"'}'

    log "INFO" "VFIO binding verification: passthrough_ready=$passthrough_ready"

    echo "$json_output" | jq .
}

# Run main function
main "$@"