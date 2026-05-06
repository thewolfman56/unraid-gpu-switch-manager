#!/bin/bash

# GPU Switch Manager - GPU Discovery Script
# Version: 1.0.0
# Description: Enumerate all available GPUs on the system

set -euo pipefail

# Source secure shell library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/secure_shell_lib.sh"

# Function to check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to get GPU vendor name
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
            echo "Unknown"
            ;;
    esac
}

# Function to get GPU model from lspci
get_gpu_model() {
    local pci_address="$1"

    local model=$(lspci -s "$pci_address" | sed 's/.*: //' | sed 's/ (.*//')
    echo "$model"
}

# Function to get current driver for GPU
get_current_driver() {
    local pci_address="$1"
    local driver_path="/sys/bus/pci/devices/$pci_address/driver"

    if [[ -L "$driver_path" ]]; then
        local driver_name=$(basename "$(readlink "$driver_path")")
        echo "$driver_name"
    else
        echo "none"
    fi
}

# Function to get audio function for GPU
get_audio_function() {
    local pci_address="$1"

    # Extract domain, bus, device, function
    local domain=$(echo "$pci_address" | cut -d: -f1)
    local bus=$(echo "$pci_address" | cut -d: -f2)
    local device=$(echo "$pci_address" | cut -d. -f1 | cut -d: -f3)
    local function=$(echo "$pci_address" | cut -d. -f2)

    # Audio function is typically function 1
    local audio_address="${domain}:${bus}:${device}.1"

    # Check if audio function exists
    if [[ -d "/sys/bus/pci/devices/$audio_address" ]]; then
        # Verify it's an audio device
        local class=$(cat "/sys/bus/pci/devices/$audio_address/class" 2>/dev/null || echo "")
        if [[ "$class" == "0x040300" ]]; then
            echo "$audio_address"
        else
            echo ""
        fi
    else
        echo ""
    fi
}

# Function to check if GPU is primary (boot display)
is_primary_gpu() {
    local pci_address="$1"

    # Check kernel command line for video parameter
    local video_param=$(cat /proc/cmdline | grep -oP 'video=\K[^ ]+' || echo "")

    if [[ -n "$video_param" ]]; then
        # Extract PCI address from video parameter
        local boot_gpu=$(echo "$video_param" | grep -oP '[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f]' || echo "")

        if [[ "$boot_gpu" == "$pci_address" ]]; then
            echo "true"
            return
        fi
    fi

    # Check if this is the first VGA device
    local first_vga=$(lspci -nn | grep -m1 "VGA" | awk '{print $1}')
    if [[ "$first_vga" == "$pci_address" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# Function to check if GPU can be switched
can_switch_gpu() {
    local pci_address="$1"
    local is_primary="$2"
    local gpu_count="$3"

    # Primary GPU protection
    if [[ "$is_primary" == "true" ]]; then
        if [[ "$gpu_count" -eq 1 ]]; then
            echo "false"
            echo "Primary GPU - no secondary GPU available"
            return
        fi
    fi

    # Check if GPU is in use
    local current_driver=$(get_current_driver "$pci_address")
    if [[ "$current_driver" != "none" ]] && [[ "$current_driver" != "vfio-pci" ]]; then
        # Check for running processes
        if command_exists nvidia-smi && [[ "$current_driver" == "nvidia" ]]; then
            local processes=$(nvidia-smi --query-compute-apps=pid --format=csv,noheader 2>/dev/null | wc -l)
            if [[ "$processes" -gt 0 ]]; then
                echo "false"
                echo "GPU has active processes"
                return
            fi
        fi
    fi

    echo "true"
    echo ""
}

# Function to get GPU details
get_gpu_details() {
    local pci_address="$1"
    local gpu_count="$2"

    # Get PCI device details
    local vendor_id=$(lspci -nn -s "$pci_address" | grep -oP '\[10de\]|\[1002\]|\[8086\]' | sed 's/\[//g' | sed 's/\]//g' || echo "unknown")
    local device_id=$(lspci -nn -s "$pci_address" | grep -oP '\[([0-9a-f]{4})\]' | sed 's/\[//g' | sed 's/\]//g' | head -1 || echo "unknown")

    # Get vendor name
    local vendor=$(get_vendor_name "$vendor_id")

    # Get GPU model
    local model=$(get_gpu_model "$pci_address")

    # Get current driver
    local driver=$(get_current_driver "$pci_address")

    # Get audio function
    local audio_function=$(get_audio_function "$pci_address")

    # Check if primary GPU
    local is_primary=$(is_primary_gpu "$pci_address")

    # Check if can switch
    local switch_result=$(can_switch_gpu "$pci_address" "$is_primary" "$gpu_count")
    local can_switch=$(echo "$switch_result" | head -1)
    local switch_reason=$(echo "$switch_result" | tail -n +2)

    # Secure JSON output
    local escaped_address=$(secure_json_escape "$pci_address")
    local escaped_vendor_id=$(secure_json_escape "$vendor_id")
    local escaped_device_id=$(secure_json_escape "$device_id")
    local escaped_vendor=$(secure_json_escape "$vendor")
    local escaped_model=$(secure_json_escape "$model")
    local escaped_driver=$(secure_json_escape "$driver")
    local escaped_audio=$(secure_json_escape "$audio_function")
    local escaped_reason=$(secure_json_escape "$switch_reason")

    cat << EOF
{
    "pci_address": "$escaped_address",
    "vendor_id": "$escaped_vendor_id",
    "device_id": "$escaped_device_id",
    "vendor": "$escaped_vendor",
    "model": "$escaped_model",
    "driver": "$escaped_driver",
    "audio_function": "$escaped_audio",
    "is_primary": $is_primary,
    "is_available": true,
    "can_switch": $can_switch,
    "switch_reason": "$escaped_reason"
}
EOF
}

# Main function
main() {
    # Check for required tools
    if ! command_exists lspci; then
        secure_error_exit "lspci command not found. Please install pciutils."
    fi

    # Get all GPU devices
    local gpus=$(lspci -nn | grep -E "VGA|3D|Display" | awk '{print $1}')

    if [[ -z "$gpus" ]]; then
        secure_error_exit "No GPUs detected on this system"
    fi

    local gpu_count=$(echo "$gpus" | wc -l)

    # Start JSON array
    echo "{"
    echo "    \"version\": \"1.0\","
    echo "    \"gpu_count\": $gpu_count,"
    echo "    \"gpus\": ["

    local first=true
    while IFS= read -r gpu_address; do
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo ","
        fi

        # Get GPU details
        get_gpu_details "$gpu_address" "$gpu_count"
    done <<< "$gpus"

    # End JSON array
    echo ""
    echo "    ]"
    echo "}"
}

# Run main function
main "$@"