#!/bin/bash

# GPU Switch Manager - PCI Address Validation Script
# Version: 1.0.0
# Description: Validate GPU PCI address format and existence

set -euo pipefail

# Source secure shell library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/secure_shell_lib.sh"

# Function to check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to validate PCI address format
validate_format() {
    local pci_address="$1"

    # Check format: domain:bus:device.function
    if [[ ! "$pci_address" =~ ^[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f]$ ]]; then
        return 1
    fi

    return 0
}

# Function to validate PCI address ranges
validate_ranges() {
    local pci_address="$1"

    # Extract components
    local domain=$(echo "$pci_address" | cut -d: -f1)
    local bus=$(echo "$pci_address" | cut -d: -f2)
    local device=$(echo "$pci_address" | cut -d. -f1 | cut -d: -f3)
    local function=$(echo "$pci_address" | cut -d. -f2)

    # Convert to decimal for range checking
    local domain_dec=$((16#$domain))
    local bus_dec=$((16#$bus))
    local device_dec=$((16#$device))
    local function_dec=$((16#$function))

    # Validate ranges
    # Domain: 0x0000-0xffff
    if [[ $domain_dec -lt 0 ]] || [[ $domain_dec -gt 65535 ]]; then
        return 1
    fi

    # Bus: 0x00-0xff
    if [[ $bus_dec -lt 0 ]] || [[ $bus_dec -gt 255 ]]; then
        return 1
    fi

    # Device: 0x00-0x1f
    if [[ $device_dec -lt 0 ]] || [[ $device_dec -gt 31 ]]; then
        return 1
    fi

    # Function: 0x0-0x7
    if [[ $function_dec -lt 0 ]] || [[ $function_dec -gt 7 ]]; then
        return 1
    fi

    return 0
}

# Function to check if device exists
device_exists() {
    local pci_address="$1"

    if [[ -d "/sys/bus/pci/devices/$pci_address" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check if device is a GPU
is_gpu_device() {
    local pci_address="$1"

    # Check device class
    local class_file="/sys/bus/pci/devices/$pci_address/class"
    if [[ -f "$class_file" ]]; then
        local class=$(cat "$class_file")

        # VGA controller: 0x0300
        # 3D controller: 0x0302
        # Display controller: 0x0380
        if [[ "$class" == "0x0300" ]] || [[ "$class" == "0x0302" ]] || [[ "$class" == "0x0380" ]]; then
            return 0
        fi
    fi

    # Check lspci output as fallback
    if command_exists lspci; then
        local device_info=$(lspci -s "$pci_address" 2>/dev/null || echo "")
        if [[ "$device_info" =~ (VGA|3D|Display) ]]; then
            return 0
        fi
    fi

    return 1
}

# Function to get detailed error message
get_error_message() {
    local pci_address="$1"
    local error_type="$2"

    case "$error_type" in
        "format")
            echo "Invalid PCI address format. Expected format: XXXX:XX:XX.X (e.g., 0000:01:00.0)"
            ;;
        "range")
            echo "PCI address component out of valid range"
            ;;
        "existence")
            echo "PCI device does not exist: $pci_address"
            ;;
        "gpu_type")
            echo "Device is not a GPU: $pci_address"
            ;;
        *)
            echo "Unknown validation error"
            ;;
    esac
}

# Function to get device details
get_device_details() {
    local pci_address="$1"

    local details="{}"

    if [[ -d "/sys/bus/pci/devices/$pci_address" ]]; then
        # Get vendor ID
        local vendor_id="unknown"
        if [[ -f "/sys/bus/pci/devices/$pci_address/vendor" ]]; then
            vendor_id=$(cat "/sys/bus/pci/devices/$pci_address/vendor" | sed 's/0x//')
        fi

        # Get device ID
        local device_id="unknown"
        if [[ -f "/sys/bus/pci/devices/$pci_address/device" ]]; then
            device_id=$(cat "/sys/bus/pci/devices/$pci_address/device" | sed 's/0x//')
        fi

        # Get class
        local class="unknown"
        if [[ -f "/sys/bus/pci/devices/$pci_address/class" ]]; then
            class=$(cat "/sys/bus/pci/devices/$pci_address/class" | sed 's/0x//')
        fi

        details=$(cat << EOF
{
    "vendor_id": "$vendor_id",
    "device_id": "$device_id",
    "class": "$class"
}
EOF
)
    fi

    echo "$details"
}

# Main function
main() {
    # Check arguments
    if [[ $# -ne 1 ]]; then
        secure_error_exit "Usage: $0 <pci_address>"
    fi

    local pci_address="$1"

    # Validate and normalize PCI address
    pci_address=$(validate_pci_address "$pci_address")

    # Check if GPU device
    if ! is_gpu_device "$pci_address"; then
        local error_msg=$(get_error_message "$pci_address" "gpu_type")
        local escaped_msg=$(secure_json_escape "$error_msg")
        echo "{\"valid\":false,\"error\":\"$escaped_msg\",\"error_type\":\"gpu_type\"}"
        exit 1
    fi

    # Get device details
    local device_details=$(get_device_details "$pci_address")

    # Secure JSON output
    local escaped_address=$(secure_json_escape "$pci_address")
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    cat << EOF
{
    "valid": true,
    "pci_address": "$escaped_address",
    "device_details": $device_details,
    "timestamp": "$timestamp"
}
EOF
}

# Run main function
main "$@"