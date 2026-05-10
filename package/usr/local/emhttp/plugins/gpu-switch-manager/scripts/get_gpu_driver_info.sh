#!/bin/bash

# get_gpu_driver_info.sh
# Get information about available drivers for a GPU
# Usage: ./get_gpu_driver_info.sh <pci_address>

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
    secure_log "$level" "[GET_GPU_DRIVER_INFO] $message"
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

# Get vendor and device IDs
get_vendor_device_ids() {
    local pci_address="$1"
    local vendor_id=$(lspci -nn -s "$pci_address" | grep -oP '\[([0-9a-f]{4}):' | sed 's/\[//;s/://')
    local device_id=$(lspci -nn -s "$pci_address" | grep -oP ':([0-9a-f]{4})\]' | sed 's/://;s/\]//')
    echo "$vendor_id:$device_id"
}

# Get vendor name
get_vendor_name() {
    local vendor_id="$1"

    case "$vendor_id" in
        10de)
            echo "NVIDIA"
            ;;
        1002)
            echo "AMD"
            ;;
        8086)
            echo "Intel"
            ;;
        *)
            echo "Unknown ($vendor_id)"
            ;;
    esac
}

# Get GPU model
get_gpu_model() {
    local pci_address="$1"
    lspci -s "$pci_address" | sed 's/.*: //' | sed 's/ (rev.*//' | sed 's/ .*Controller.*//'
}

# Determine recommended driver
determine_recommended_driver() {
    local vendor_id="$1"

    case "$vendor_id" in
        10de)
            echo "nvidia"
            ;;
        1002)
            echo "amdgpu"
            ;;
        8086)
            echo "i915"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Get available drivers
get_available_drivers() {
    local vendor_id="$1"
    local drivers_json="["

    case "$vendor_id" in
        10de)
            # NVIDIA drivers
            drivers_json+='"nvidia","vfio-pci"'
            if [[ -d "/sys/bus/pci/drivers/nouveau" ]]; then
                drivers_json+=',"nouveau"'
            fi
            ;;
        1002)
            # AMD drivers
            drivers_json+='"amdgpu","vfio-pci"'
            if [[ -d "/sys/bus/pci/drivers/radeon" ]]; then
                drivers_json+=',"radeon"'
            fi
            ;;
        8086)
            # Intel drivers
            drivers_json+='"i915","vfio-pci"'
            ;;
        *)
            # Unknown vendor
            drivers_json+='"vfio-pci"'
            ;;
    esac

    drivers_json+="]"
    echo "$drivers_json"
}

# Check driver availability
check_driver_availability() {
    local driver="$1"

    if [[ -d "/sys/bus/pci/drivers/$driver" ]]; then
        echo "true"
    else
        echo "false"
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

# Determine compatibility
determine_compatibility() {
    local vendor_id="$1"
    local current_driver="$2"
    local recommended_driver="$3"

    # If current driver matches recommended, full compatibility
    if [[ "$current_driver" == "$recommended_driver" ]]; then
        echo "full"
    # If current driver is vfio-pci, it's compatible for passthrough
    elif [[ "$current_driver" == "vfio-pci" ]]; then
        echo "passthrough"
    # If current driver is none, partial compatibility
    elif [[ "$current_driver" == "none" ]]; then
        echo "partial"
    # Otherwise, unknown compatibility
    else
        echo "unknown"
    fi
}

# Main function
main() {
    # Check arguments
    if [[ $# -ne 1 ]]; then
        error_exit "Usage: $0 <pci_address>"
    fi

    local pci_address="$1"

    log "INFO" "Getting driver information for $pci_address"

    # Validate inputs
    validate_pci_address "$pci_address"
    device_exists "$pci_address"
    is_gpu_device "$pci_address"

    # Get vendor and device IDs
    local vendor_device_ids=$(get_vendor_device_ids "$pci_address")
    local vendor_id=$(echo "$vendor_device_ids" | cut -d: -f1)
    local device_id=$(echo "$vendor_device_ids" | cut -d: -f2)

    log "INFO" "Vendor ID: $vendor_id, Device ID: $device_id"

    # Get vendor name
    local vendor_name=$(get_vendor_name "$vendor_id")

    # Get GPU model
    local gpu_model=$(get_gpu_model "$pci_address")

    # Determine recommended driver
    local recommended_driver=$(determine_recommended_driver "$vendor_id")

    # Get available drivers
    local available_drivers=$(get_available_drivers "$vendor_id")

    # Get current driver
    local current_driver=$(get_current_driver "$pci_address")

    # Determine compatibility
    local compatibility=$(determine_compatibility "$vendor_id" "$current_driver" "$recommended_driver")

    # Build JSON output
    local json_output='{"success":true,"pci_address":"'"$pci_address"'","vendor_id":"'"$vendor_id"'","device_id":"'"$device_id"'","vendor":"'"$vendor_name"'","model":"'"$gpu_model"'","recommended_driver":"'"$recommended_driver"'","available_drivers":'"$available_drivers"',"current_driver":"'"$current_driver"'","compatibility":"'"$compatibility"'"}'

    log "INFO" "Driver information: vendor=$vendor_name, model=$gpu_model, recommended=$recommended_driver, current=$current_driver, compatibility=$compatibility"

    echo "$json_output" | jq .
}

# Run main function
main "$@"