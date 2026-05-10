#!/bin/bash

# update_vfio_conf.sh
# Update /etc/modprobe.d/vfio.conf with GPU IDs
# Usage: ./update_vfio_conf.sh <pci_address1> [<pci_address2> ...]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source secure shell library
source "$SCRIPT_DIR/secure_shell_lib.sh"
VFIO_CONF="/etc/modprobe.d/vfio.conf"
VFIO_CONF_BACKUP="/etc/modprobe.d/vfio.conf.backup"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    secure_log "$level" "[UPDATE_VFIO_CONF] $message"
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

# Backup existing configuration
backup_config() {
    if [[ -f "$VFIO_CONF" ]]; then
        log "INFO" "Backing up $VFIO_CONF to $VFIO_CONF_BACKUP"
        cp "$VFIO_CONF" "$VFIO_CONF_BACKUP" 2>/dev/null || {
            log "WARN" "Failed to backup vfio.conf"
        }
    fi
}

# Read existing IDs
read_existing_ids() {
    if [[ -f "$VFIO_CONF" ]]; then
        grep "^options vfio-pci ids=" "$VFIO_CONF" 2>/dev/null | sed 's/options vfio-pci ids=//' || echo ""
    else
        echo ""
    fi
}

# Parse existing IDs into array
parse_ids() {
    local ids_string="$1"
    if [[ -z "$ids_string" ]]; then
        return
    fi

    # Split by comma and output each ID
    IFS=',' read -ra ADDR <<< "$ids_string"
    for id in "${ADDR[@]}"; do
        echo "$id"
    done
}

# Check if ID already exists
id_exists() {
    local existing_ids="$1"
    local new_id="$2"

    # Parse existing IDs
    while IFS= read -r id; do
        if [[ "$id" == "$new_id" ]]; then
            return 0
        fi
    done < <(parse_ids "$existing_ids")

    return 1
}

# Update vfio.conf
update_config() {
    local new_ids="$1"
    local operation="$2"  # "add" or "remove"

    log "INFO" "Updating $VFIO_CONF (operation: $operation)"

    # Read existing IDs
    local existing_ids=$(read_existing_ids)

    # Build new IDs list
    local final_ids=""

    if [[ "$operation" == "add" ]]; then
        # Add new IDs to existing
        if [[ -z "$existing_ids" ]]; then
            final_ids="$new_ids"
        else
            # Check each new ID
            local added_ids=()
            while IFS= read -r new_id; do
                if ! id_exists "$existing_ids" "$new_id"; then
                    added_ids+=("$new_id")
                fi
            done < <(parse_ids "$new_ids")

            # Add new IDs to existing
            if [[ ${#added_ids[@]} -gt 0 ]]; then
                final_ids="$existing_ids,$(IFS=,; echo "${added_ids[*]}")"
            else
                final_ids="$existing_ids"
            fi
        fi
    elif [[ "$operation" == "remove" ]]; then
        # Remove IDs from existing
        if [[ -n "$existing_ids" ]]; then
            local remaining_ids=()
            while IFS= read -r existing_id; do
                local should_remove=false
                while IFS= read -r remove_id; do
                    if [[ "$existing_id" == "$remove_id" ]]; then
                        should_remove=true
                        break
                    fi
                done < <(parse_ids "$new_ids")

                if [[ "$should_remove" == "false" ]]; then
                    remaining_ids+=("$existing_id")
                fi
            done < <(parse_ids "$existing_ids")

            # Join remaining IDs
            if [[ ${#remaining_ids[@]} -gt 0 ]]; then
                final_ids=$(IFS=,; echo "${remaining_ids[*]}")
            else
                final_ids=""
            fi
        else
            final_ids=""
        fi
    fi

    # Write configuration
    if [[ -n "$final_ids" ]]; then
        echo "options vfio-pci ids=$final_ids" > "$VFIO_CONF"
        log "INFO" "Updated vfio.conf with IDs: $final_ids"
    else
        # Remove the line if no IDs left
        if [[ -f "$VFIO_CONF" ]]; then
            sed -i '/^options vfio-pci ids=/d' "$VFIO_CONF" 2>/dev/null || true
            log "INFO" "Removed vfio-pci configuration (no IDs remaining)"
        fi
    fi
}

# Validate configuration
validate_config() {
    if [[ -f "$VFIO_CONF" ]]; then
        # Check for valid format
        local line=$(grep "^options vfio-pci ids=" "$VFIO_CONF" 2>/dev/null || echo "")
        if [[ -n "$line" ]]; then
            # Extract IDs and validate format
            local ids=$(echo "$line" | sed 's/options vfio-pci ids=//')
            if [[ ! "$ids" =~ ^[0-9a-f]{4}:[0-9a-f]{4}(,[0-9a-f]{4}:[0-9a-f]{4})*$ ]]; then
                log "WARN" "vfio.conf has invalid format: $ids"
                return 1
            fi
        fi
    fi
    return 0
}

# Main function
main() {
    # Check arguments
    if [[ $# -lt 1 ]]; then
        error_exit "Usage: $0 <pci_address1> [<pci_address2> ...] [--remove]"
    fi

    local operation="add"
    local pci_addresses=()

    # Parse arguments
    for arg in "$@"; do
        if [[ "$arg" == "--remove" ]]; then
            operation="remove"
        else
            pci_addresses+=("$arg")
        fi
    done

    if [[ ${#pci_addresses[@]} -eq 0 ]]; then
        error_exit "No PCI addresses provided"
    fi

    log "INFO" "Starting vfio.conf update (operation: $operation, addresses: ${pci_addresses[*]})"

    # Validate all PCI addresses and collect IDs
    local all_ids=""
    local first=true

    for pci_address in "${pci_addresses[@]}"; do
        # Validate inputs
        validate_pci_address "$pci_address"
        device_exists "$pci_address"

        # Get vendor/device IDs
        local ids=$(get_vendor_device_ids "$pci_address")
        log "INFO" "PCI address $pci_address -> IDs: $ids"

        # Get audio function IDs
        local audio_address=$(get_audio_function "$pci_address")
        if [[ -n "$audio_address" ]]; then
            local audio_ids=$(get_vendor_device_ids "$audio_address")
            log "INFO" "Audio function $audio_address -> IDs: $audio_ids"
            ids="$ids,$audio_ids"
        fi

        # Add to all IDs
        if [[ "$first" == "true" ]]; then
            all_ids="$ids"
            first=false
        else
            all_ids="$all_ids,$ids"
        fi
    done

    # Backup existing configuration
    backup_config

    # Update configuration
    update_config "$all_ids" "$operation"

    # Validate configuration
    if ! validate_config; then
        log "WARN" "Configuration validation failed, but update completed"
    fi

    # Success
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    log "INFO" "vfio.conf update completed successfully"

    echo '{"success":true,"message":"vfio.conf updated successfully","operation":"'"$operation"'","addresses":['$(IFS=,; echo "\"${pci_addresses[*]}\"")'],"vfio_conf_updated":true,"timestamp":"'"$timestamp"'"}' | jq .
}

# Run main function
main "$@"