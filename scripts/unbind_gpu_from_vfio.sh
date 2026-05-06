#!/bin/bash

# unbind_gpu_from_vfio.sh
# Unbind a GPU from vfio-pci and restore normal driver
# Usage: ./unbind_gpu_from_vfio.sh <pci_address>

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/gpu.switch.manager.log"
VFIO_CONF="/etc/modprobe.d/vfio.conf"
VFIO_CONF_BACKUP="/etc/modprobe.d/vfio.conf.backup"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    echo '{"success":false,"error":"'"$1"'"}' | jq .
    exit 1
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

# Determine appropriate driver
determine_driver() {
    local pci_address="$1"
    local vendor_id=$(lspci -nn -s "$pci_address" | grep -oP '\[([0-9a-f]{4}):' | sed 's/\[//;s/://')

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

# Check if driver is available
driver_available() {
    local driver="$1"
    if [[ -d "/sys/bus/pci/drivers/$driver" ]]; then
        return 0
    else
        return 1
    fi
}

# Unbind from vfio-pci
unbind_from_vfio() {
    local pci_address="$1"
    local vendor_device_ids="$2"

    log "INFO" "Unbinding $pci_address from vfio-pci"

    # Remove device ID from vfio-pci
    local vendor_id=$(echo "$vendor_device_ids" | cut -d: -f1)
    local device_id=$(echo "$vendor_device_ids" | cut -d: -f2)

    echo "$vendor_id $device_id" > /sys/bus/pci/drivers/vfio-pci/remove_id 2>/dev/null || {
        log "WARN" "Failed to remove device ID from vfio-pci"
    }

    # Unbind device
    echo "$pci_address" > /sys/bus/pci/drivers/vfio-pci/unbind 2>/dev/null || {
        error_exit "Failed to unbind device from vfio-pci"
    }
}

# Bind to appropriate driver
bind_to_driver() {
    local pci_address="$1"
    local driver="$2"

    log "INFO" "Binding $pci_address to $driver"

    # Check if driver is available
    if ! driver_available "$driver"; then
        error_exit "Driver $driver is not available"
    fi

    # Bind device
    echo "$pci_address" > "/sys/bus/pci/drivers/$driver/bind" 2>/dev/null || {
        error_exit "Failed to bind device to $driver"
    }
}

# Unbind audio function from vfio-pci
unbind_audio_function() {
    local audio_address="$1"

    if [[ -z "$audio_address" ]]; then
        log "INFO" "No audio function to unbind"
        return 0
    fi

    log "INFO" "Unbinding audio function $audio_address from vfio-pci"

    # Get current driver
    local current_driver=$(get_current_driver "$audio_address")

    # Only unbind if bound to vfio-pci
    if [[ "$current_driver" == "vfio-pci" ]]; then
        # Get audio vendor/device IDs
        local audio_ids=$(get_vendor_device_ids "$audio_address")

        # Remove from vfio-pci
        local audio_vendor_id=$(echo "$audio_ids" | cut -d: -f1)
        local audio_device_id=$(echo "$audio_ids" | cut -d: -f2)

        echo "$audio_vendor_id $audio_device_id" > /sys/bus/pci/drivers/vfio-pci/remove_id 2>/dev/null || {
            log "WARN" "Failed to remove audio device ID from vfio-pci"
        }

        # Unbind audio device
        echo "$audio_address" > /sys/bus/pci/drivers/vfio-pci/unbind 2>/dev/null || {
            log "WARN" "Failed to unbind audio device from vfio-pci"
            return 0
        }

        log "INFO" "Audio function unbound successfully"
    else
        log "INFO" "Audio function not bound to vfio-pci (current: $current_driver)"
    fi
}

# Update vfio.conf
update_vfio_conf() {
    local pci_address="$1"
    local vendor_device_ids="$2"

    log "INFO" "Updating $VFIO_CONF"

    # Backup existing configuration
    if [[ -f "$VFIO_CONF" ]]; then
        cp "$VFIO_CONF" "$VFIO_CONF_BACKUP" 2>/dev/null || {
            log "WARN" "Failed to backup vfio.conf"
        }
    fi

    # Read existing IDs
    local existing_ids=""
    if [[ -f "$VFIO_CONF" ]]; then
        existing_ids=$(grep "^options vfio-pci ids=" "$VFIO_CONF" 2>/dev/null | sed 's/options vfio-pci ids=//' || echo "")
    fi

    # Remove IDs if present
    if [[ -n "$existing_ids" ]]; then
        # Remove the specific IDs
        local new_ids=$(echo "$existing_ids" | sed "s/$vendor_device_ids,//g" | sed "s/,$vendor_device_ids//g" | sed "s/$vendor_device_ids//g")

        # Update or remove line
        if [[ -n "$new_ids" ]]; then
            echo "options vfio-pci ids=$new_ids" > "$VFIO_CONF"
        else
            # Remove the line if no IDs left
            sed -i '/^options vfio-pci ids=/d' "$VFIO_CONF" 2>/dev/null || true
        fi
    fi

    log "INFO" "vfio.conf updated successfully"
}

# Verify unbinding
verify_unbinding() {
    local pci_address="$1"
    local expected_driver="$2"
    local new_driver=$(get_current_driver "$pci_address")

    if [[ "$new_driver" != "$expected_driver" ]]; then
        error_exit "Unbinding verification failed: current driver is $new_driver, expected $expected_driver"
    fi

    log "INFO" "Unbinding verified: $pci_address is bound to $expected_driver"
}

# Main function
main() {
    # Check arguments
    if [[ $# -ne 1 ]]; then
        error_exit "Usage: $0 <pci_address>"
    fi

    local pci_address="$1"

    log "INFO" "Starting VFIO unbinding for $pci_address"

    # Validate inputs
    validate_pci_address "$pci_address"
    device_exists "$pci_address"
    is_gpu_device "$pci_address"

    # Get current state
    local current_driver=$(get_current_driver "$pci_address")
    log "INFO" "Current driver: $current_driver"

    # Check if not bound to vfio-pci
    if [[ "$current_driver" != "vfio-pci" ]]; then
        log "INFO" "GPU not bound to vfio-pci (current: $current_driver)"
        echo '{"success":true,"message":"GPU not bound to vfio-pci","pci_address":"'"$pci_address"'","current_driver":"'"$current_driver"'","already_unbound":true}' | jq .
        exit 0
    fi

    # Get vendor/device IDs
    local vendor_device_ids=$(get_vendor_device_ids "$pci_address")
    log "INFO" "Vendor/Device IDs: $vendor_device_ids"

    # Get audio function
    local audio_address=$(get_audio_function "$pci_address")
    if [[ -n "$audio_address" ]]; then
        log "INFO" "Audio function: $audio_address"
    fi

    # Determine appropriate driver
    local target_driver=$(determine_driver "$pci_address")
    log "INFO" "Target driver: $target_driver"

    # Check if driver is available
    if ! driver_available "$target_driver"; then
        error_exit "Target driver $target_driver is not available"
    fi

    # Unbind from vfio-pci
    unbind_from_vfio "$pci_address" "$vendor_device_ids"

    # Unbind audio function
    unbind_audio_function "$audio_address"

    # Bind to appropriate driver
    bind_to_driver "$pci_address" "$target_driver"

    # Update vfio.conf
    update_vfio_conf "$pci_address" "$vendor_device_ids"

    # Verify unbinding
    verify_unbinding "$pci_address" "$target_driver"

    # Success
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    log "INFO" "VFIO unbinding completed successfully for $pci_address"

    echo '{"success":true,"message":"GPU successfully unbound from vfio-pci","pci_address":"'"$pci_address"'","previous_driver":"vfio-pci","current_driver":"'"$target_driver"'","audio_unbound":'"${audio_address:+true}"',"audio_address":"'"${audio_address:-}"'","vfio_conf_updated":true,"timestamp":"'"$timestamp"'"}' | jq .
}

# Run main function
main "$@"