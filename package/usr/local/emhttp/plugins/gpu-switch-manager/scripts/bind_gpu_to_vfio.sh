#!/bin/bash

# bind_gpu_to_vfio.sh
# Bind a GPU to the vfio-pci driver for VM passthrough
# Usage: ./bind_gpu_to_vfio.sh <pci_address>

set -euo pipefail

# Source secure shell library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/secure_shell_lib.sh"

# Configuration
VFIO_CONF="/etc/modprobe.d/vfio.conf"
VFIO_CONF_BACKUP="/etc/modprobe.d/vfio.conf.backup"

# Check if device exists
device_exists() {
    local pci_address="$1"
    local device_path="/sys/bus/pci/devices/$pci_address"
    if [[ ! -d "$device_path" ]]; then
        secure_error_exit "Device not found: $pci_address"
    fi
}

# Check if device is a GPU
is_gpu_device() {
    local pci_address="$1"
    local class=$(lspci -s "$pci_address" -n | awk '{print $2}')
    if [[ ! "$class" =~ ^03 ]]; then
        secure_error_exit "Device is not a GPU: $pci_address (class: $class)"
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

# Check if GPU is in use
check_gpu_usage() {
    local pci_address="$1"
    local current_driver=$(get_current_driver "$pci_address")

    # Check for NVIDIA GPU usage
    if [[ "$current_driver" == "nvidia" ]]; then
        if command -v nvidia-smi &> /dev/null; then
            local usage=$(nvidia-smi --query-compute-apps=pid --format=csv,noheader 2>/dev/null | wc -l)
            if [[ "$usage" -gt 0 ]]; then
                secure_error_exit "GPU is in use by $usage process(es)"
            fi
        fi
    fi

    # Check for file handles
    local handles=$(lsof "/dev/dri/by-path/pci-$pci_address" 2>/dev/null | wc -l)
    if [[ "$handles" -gt 0 ]]; then
        secure_error_exit "GPU has $handles open file handle(s)"
    fi
}

# Get vendor and device IDs
get_vendor_device_ids() {
    local pci_address="$1"
    local vendor_id=$(lspci -nn -s "$pci_address" | grep -oP '\[([0-9a-f]{4}):' | sed 's/\[//;s/://')
    local device_id=$(lspci -nn -s "$pci_address" | grep -oP ':([0-9a-f]{4})\]' | sed 's/://;s/\]//')
    echo "$vendor_id:$device_id"
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

# Unbind from current driver
unbind_driver() {
    local pci_address="$1"
    local current_driver="$2"

    if [[ "$current_driver" != "none" ]]; then
        secure_log "INFO" "Unbinding $pci_address from $current_driver"

        local unbind_path="/sys/bus/pci/devices/$pci_address/driver/unbind"
        if [[ -w "$unbind_path" ]]; then
            echo "$pci_address" > "$unbind_path" 2>/dev/null || {
                secure_error_exit "Failed to unbind from $current_driver"
            }
        else
            secure_error_exit "Cannot unbind from $current_driver (no write permission)"
        fi
    fi
}

# Bind to vfio-pci
bind_to_vfio() {
    local pci_address="$1"
    local vendor_device_ids="$2"

    secure_log "INFO" "Binding $pci_address to vfio-pci ($vendor_device_ids)"

    # Add device ID to vfio-pci
    local vendor_id=$(echo "$vendor_device_ids" | cut -d: -f1)
    local device_id=$(echo "$vendor_device_ids" | cut -d: -f2)

    echo "$vendor_id $device_id" > /sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null || {
        secure_error_exit "Failed to add device ID to vfio-pci"
    }

    # Bind device
    echo "$pci_address" > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null || {
        secure_error_exit "Failed to bind device to vfio-pci"
    }
}

# Bind audio function to vfio-pci
bind_audio_function() {
    local audio_address="$1"

    if [[ -z "$audio_address" ]]; then
        secure_log "INFO" "No audio function to bind"
        return 0
    fi

    secure_log "INFO" "Binding audio function $audio_address to vfio-pci"

    # Get current driver
    local current_driver=$(get_current_driver "$audio_address")

    # Unbind from current driver
    if [[ "$current_driver" != "none" ]]; then
        echo "$audio_address" > "/sys/bus/pci/devices/$audio_address/driver/unbind" 2>/dev/null || {
            secure_log "WARN" "Failed to unbind audio from $current_driver"
        }
    fi

    # Get audio vendor/device IDs
    local audio_ids=$(get_vendor_device_ids "$audio_address")

    # Add to vfio-pci
    local audio_vendor_id=$(echo "$audio_ids" | cut -d: -f1)
    local audio_device_id=$(echo "$audio_ids" | cut -d: -f2)

    echo "$audio_vendor_id $audio_device_id" > /sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null || {
        secure_log "WARN" "Failed to add audio device ID to vfio-pci"
        return 0
    }

    # Bind audio device
    echo "$audio_address" > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null || {
        secure_log "WARN" "Failed to bind audio device to vfio-pci"
        return 0
    }

    secure_log "INFO" "Audio function bound successfully"
}

# Update vfio.conf
update_vfio_conf() {
    local pci_address="$1"
    local vendor_device_ids="$2"

    secure_log "INFO" "Updating $VFIO_CONF"

    # Backup existing configuration
    if [[ -f "$VFIO_CONF" ]]; then
        cp "$VFIO_CONF" "$VFIO_CONF_BACKUP" 2>/dev/null || {
            secure_log "WARN" "Failed to backup vfio.conf"
        }
    fi

    # Read existing IDs
    local existing_ids=""
    if [[ -f "$VFIO_CONF" ]]; then
        existing_ids=$(grep "^options vfio-pci ids=" "$VFIO_CONF" 2>/dev/null | sed 's/options vfio-pci ids=//' || echo "")
    fi

    # Add new IDs if not already present
    if [[ -z "$existing_ids" ]]; then
        echo "options vfio-pci ids=$vendor_device_ids" > "$VFIO_CONF"
    elif [[ ! "$existing_ids" =~ $vendor_device_ids ]]; then
        echo "options vfio-pci ids=$existing_ids,$vendor_device_ids" > "$VFIO_CONF"
    fi

    secure_log "INFO" "vfio.conf updated successfully"
}

# Verify binding
verify_binding() {
    local pci_address="$1"
    local new_driver=$(get_current_driver "$pci_address")

    if [[ "$new_driver" != "vfio-pci" ]]; then
        secure_error_exit "Binding verification failed: current driver is $new_driver"
    fi

    secure_log "INFO" "Binding verified: $pci_address is bound to vfio-pci"
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

    secure_log "INFO" "Starting VFIO binding for $pci_address"

    # Validate inputs
    device_exists "$pci_address"
    is_gpu_device "$pci_address"

    # Get current state
    local current_driver=$(get_current_driver "$pci_address")
    secure_log "INFO" "Current driver: $current_driver"

    # Check if already bound to vfio-pci
    if [[ "$current_driver" == "vfio-pci" ]]; then
        secure_log "INFO" "GPU already bound to vfio-pci"

        # Secure JSON output
        local escaped_address=$(secure_json_escape "$pci_address")
        local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
        echo "{\"success\":true,\"message\":\"GPU already bound to vfio-pci\",\"pci_address\":\"$escaped_address\",\"current_driver\":\"vfio-pci\",\"already_bound\":true,\"timestamp\":\"$timestamp\"}"
        exit 0
    fi

    # Check usage
    check_gpu_usage "$pci_address"

    # Get vendor/device IDs
    local vendor_device_ids=$(get_vendor_device_ids "$pci_address")
    secure_log "INFO" "Vendor/Device IDs: $vendor_device_ids"

    # Get audio function
    local audio_address=$(get_audio_function "$pci_address")
    if [[ -n "$audio_address" ]]; then
        secure_log "INFO" "Audio function: $audio_address"
    fi

    # Unbind from current driver
    unbind_driver "$pci_address" "$current_driver"

    # Bind to vfio-pci
    bind_to_vfio "$pci_address" "$vendor_device_ids"

    # Bind audio function
    bind_audio_function "$audio_address"

    # Update vfio.conf
    update_vfio_conf "$pci_address" "$vendor_device_ids"

    # Verify binding
    verify_binding "$pci_address"

    # Success
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    secure_log "INFO" "VFIO binding completed successfully for $pci_address"

    # Secure JSON output
    local escaped_address=$(secure_json_escape "$pci_address")
    local escaped_previous=$(secure_json_escape "$current_driver")
    local escaped_audio=$(secure_json_escape "${audio_address:-}")
    local audio_bound="false"
    if [[ -n "$audio_address" ]]; then
        audio_bound="true"
    fi

    echo "{\"success\":true,\"message\":\"GPU successfully bound to vfio-pci\",\"pci_address\":\"$escaped_address\",\"previous_driver\":\"$escaped_previous\",\"current_driver\":\"vfio-pci\",\"audio_bound\":$audio_bound,\"audio_address\":\"$escaped_audio\",\"vfio_conf_updated\":true,\"timestamp\":\"$timestamp\"}"
}

# Run main function
main "$@"