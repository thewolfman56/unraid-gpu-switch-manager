#!/bin/bash

# check_vfio_binding.sh
# Check if a GPU is currently bound to vfio-pci
# Usage: ./check_vfio_binding.sh <pci_address>

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
    secure_log "$level" "[CHECK_VFIO_BINDING] $message"
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

# Check device accessibility
check_device_accessibility() {
    local pci_address="$1"
    local device_path="/sys/bus/pci/devices/$pci_address"

    # Check if device directory exists and is readable
    if [[ ! -r "$device_path" ]]; then
        echo "false"
        return
    fi

    # Check if device is in a valid state
    local config=$(cat "$device_path/config" 2>/dev/null || echo "")
    if [[ -z "$config" ]]; then
        echo "false"
        return
    fi

    echo "true"
}

# Get audio function address
get_audio_function() {
    local gpu_address="$1"
    local bus=$(echo "$gpu_address" | cut -d: -f2)
    local device=$(echo "$gpu_address" | cut -d: -f3 | cut -d. -f1)

    # Audio function is typically function 1
    local audio_address="0000:$bus:$device.1"

    # Check if audio function exists
    if lspci -s "$audio_address" | grep -q "Audio"; then
        echo "$audio_address"
    else
        echo ""
    fi
}

# Get bound functions
get_bound_functions() {
    local gpu_address="$1"
    local audio_address=$(get_audio_function "$gpu_address")

    local functions_json="["

    # Add GPU function
    local gpu_driver=$(get_current_driver "$gpu_address")
    functions_json+="{\"type\":\"GPU\",\"address\":\"$gpu_address\",\"driver\":\"$gpu_driver\"}"

    # Add audio function if exists
    if [[ -n "$audio_address" ]]; then
        local audio_driver=$(get_current_driver "$audio_address")
        functions_json+=",{\"type\":\"Audio\",\"address\":\"$audio_address\",\"driver\":\"$audio_driver\"}"
    fi

    functions_json+="]"
    echo "$functions_json"
}

# Get binding timestamp
get_binding_timestamp() {
    local pci_address="$1"
    local driver_path="/sys/bus/pci/devices/$pci_address/driver"

    if [[ -L "$driver_path" ]]; then
        # Get modification time of driver symlink
        local timestamp=$(stat -c %Y "$driver_path" 2>/dev/null || echo "0")
        if [[ "$timestamp" != "0" ]]; then
            date -d "@$timestamp" -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo ""
        else
            echo ""
        fi
    else
        echo ""
    fi
}

# Main function
main() {
    # Check arguments
    if [[ $# -ne 1 ]]; then
        error_exit "Usage: $0 <pci_address>"
    fi

    local pci_address="$1"

    log "INFO" "Checking VFIO binding status for $pci_address"

    # Validate inputs
    validate_pci_address "$pci_address"
    device_exists "$pci_address"
    is_gpu_device "$pci_address"

    # Get current driver
    local current_driver=$(get_current_driver "$pci_address")
    log "INFO" "Current driver: $current_driver"

    # Check VFIO binding status
    local vfio_bound=false
    if [[ "$current_driver" == "vfio-pci" ]]; then
        vfio_bound=true
    fi

    # Check device accessibility
    local accessible=$(check_device_accessibility "$pci_address")

    # Get bound functions
    local bound_functions=$(get_bound_functions "$pci_address")

    # Get binding timestamp
    local binding_timestamp=$(get_binding_timestamp "$pci_address")

    # Build JSON output
    local json_output='{"success":true,"pci_address":"'"$pci_address"'","current_driver":"'"$current_driver"'","vfio_bound":'$vfio_bound',"accessible":'$accessible',"bound_functions":'"$bound_functions"'

    # Add binding timestamp if available
    if [[ -n "$binding_timestamp" ]]; then
        json_output+=',"binding_timestamp":"'"$binding_timestamp"'"
    fi

    json_output+='}'

    log "INFO" "VFIO binding status: vfio_bound=$vfio_bound, driver=$current_driver"

    echo "$json_output" | jq .
}

# Run main function
main "$@"