#!/bin/bash

# check_vm_gpu_requirements.sh
# Check VM GPU requirements from VM configuration
# Usage: ./check_vm_gpu_requirements.sh <vm_name>

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
    secure_log "$level" "[VM_GPU_REQUIREMENTS] $message"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    secure_error_exit "$1"
}

# Validate VM name
validate_vm_name() {
    local vm_name="$1"

    if [[ -z "$vm_name" ]]; then
        error_exit "VM name is required"
    fi

    # Check for valid characters
    if [[ ! "$vm_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        error_exit "Invalid VM name: $vm_name (only alphanumeric, underscore, and hyphen allowed)"
    fi
}

# Check if virsh is available
check_virsh() {
    if ! command -v virsh &> /dev/null; then
        error_exit "virsh command not found"
    fi

    if ! virsh version &> /dev/null; then
        error_exit "virsh is not accessible"
    fi
}

# Check if VM exists
check_vm_exists() {
    local vm_name="$1"

    if ! virsh list --all | grep -q "^\s*${vm_name}\s"; then
        error_exit "VM not found: $vm_name"
    fi
}

# Get VM XML configuration
get_vm_xml() {
    local vm_name="$1"

    local vm_xml=$(virsh dumpxml "$vm_name" 2>/dev/null || echo "")

    if [[ -z "$vm_xml" ]]; then
        error_exit "Failed to get VM XML for: $vm_name"
    fi

    echo "$vm_xml"
}

# Extract GPU devices from VM XML
extract_gpu_devices() {
    local vm_xml="$1"

    # Extract PCI hostdev devices (GPU passthrough)
    local gpu_devices=$(echo "$vm_xml" | grep -A 10 "<hostdev" | grep "pci" | grep -oP 'domain="0x[0-9a-f]+"\s+bus="0x[0-9a-f]+"\s+slot="0x[0-9a-f]+"\s+function="0x[0-9a-f]+"' | sed 's/domain="0x//;s/"\s+bus="0x/:/;s/"\s+slot="0x/:/;s/"\s+function="0x/./;s/"//g' || echo "")

    echo "$gpu_devices"
}

# Extract audio function for GPU
extract_audio_function() {
    local vm_xml="$1"
    local gpu_address="$2"

    # Parse GPU address components
    local domain=$(echo "$gpu_address" | cut -d: -f1)
    local bus=$(echo "$gpu_address" | cut -d: -f2)
    local slot=$(echo "$gpu_address" | cut -d: -f3)
    local function=$(echo "$gpu_address" | cut -d: -f4)

    # Look for audio function on same bus/slot
    local audio_address=$(echo "$vm_xml" | grep -A 10 "<hostdev" | grep "pci" | grep -oP 'domain="0x[0-9a-f]+"\s+bus="0x[0-9a-f]+"\s+slot="0x[0-9a-f]+"\s+function="0x[0-9a-f]+"' | sed 's/domain="0x//;s/"\s+bus="0x/:/;s/"\s+slot="0x/:/;s/"\s+function="0x/./;s/"//g' | grep "^${domain}:${bus}:${slot}:" | grep -v "^${gpu_address}$" | head -1)

    echo "$audio_address"
}

# Get GPU device information
get_gpu_device_info() {
    local gpu_address="$1"

    local device_path="/sys/bus/pci/devices/0000:$gpu_address"

    if [[ ! -d "$device_path" ]]; then
        echo '{"address":"'"$gpu_address"'","exists":false}'
        return
    fi

    # Get vendor ID
    local vendor_id=$(cat "$device_path/vendor" 2>/dev/null | sed 's/0x//' || echo "unknown")

    # Get device ID
    local device_id=$(cat "$device_path/device" 2>/dev/null | sed 's/0x//' || echo "unknown")

    # Get class
    local class=$(cat "$device_path/class" 2>/dev/null | sed 's/0x//' || echo "unknown")

    # Get driver
    local driver=""
    if [[ -L "$device_path/driver" ]]; then
        driver=$(basename "$(readlink "$device_path/driver")")
    fi

    echo '{"address":"'"$gpu_address"'","exists":true,"vendor_id":"'"$vendor_id"'","device_id":"'"$device_id"'","class":"'"$class"'","driver":"'"$driver"'"}'
}

# Determine VFIO binding requirement
determine_vfio_requirement() {
    local gpu_address="$1"
    local device_info="$2"

    local class=$(echo "$device_info" | jq -r '.class')
    local driver=$(echo "$device_info" | jq -r '.driver')

    # Check if device is a GPU (class 0x030000 for VGA, 0x038000 for 3D controller)
    local is_gpu=false
    if [[ "$class" == "030000" ]] || [[ "$class" == "038000" ]]; then
        is_gpu=true
    fi

    # Check if device is audio (class 0x040300)
    local is_audio=false
    if [[ "$class" == "040300" ]]; then
        is_audio=true
    fi

    # Determine if VFIO binding is required
    local requires_vfio=false
    if [[ "$is_gpu" == "true" ]] || [[ "$is_audio" == "true" ]]; then
        requires_vfio=true
    fi

    echo '{"address":"'"$gpu_address"'","is_gpu":'"$is_gpu"',"is_audio":'"$is_audio"',"requires_vfio":'"$requires_vfio"'}'
}

# Main function
main() {
    # Check arguments
    if [[ $# -lt 1 ]]; then
        error_exit "Usage: $0 <vm_name>"
    fi

    local vm_name="$1"

    log "INFO" "Checking GPU requirements for VM: $vm_name"

    # Validate VM name
    validate_vm_name "$vm_name"

    # Check if virsh is available
    check_virsh

    # Check if VM exists
    check_vm_exists "$vm_name"

    # Get VM XML
    local vm_xml=$(get_vm_xml "$vm_name")

    # Extract GPU devices
    local gpu_devices=$(extract_gpu_devices "$vm_xml")

    if [[ -z "$gpu_devices" ]]; then
        log "INFO" "No GPU devices found in VM configuration"
        echo '{"success":true,"vm_name":"'"$vm_name"'","has_gpu":false,"gpu_devices":[],"audio_devices":[],"requires_vfio":false,"timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}}' | jq .
        exit 0
    fi

    log "INFO" "Found GPU devices: $gpu_devices"

    # Process each GPU device
    local gpu_json='['
    local audio_json='['
    local first_gpu=true
    local first_audio=true
    local requires_vfio=false

    while IFS= read -r gpu_address; do
        if [[ -n "$gpu_address" ]]; then
            log "INFO" "Processing GPU device: $gpu_address"

            # Get device information
            local device_info=$(get_gpu_device_info "$gpu_address")

            # Determine VFIO requirement
            local vfio_requirement=$(determine_vfio_requirement "$gpu_address" "$device_info")

            local is_gpu=$(echo "$vfio_requirement" | jq -r '.is_gpu')
            local is_audio=$(echo "$vfio_requirement" | jq -r '.is_audio')
            local device_requires_vfio=$(echo "$vfio_requirement" | jq -r '.requires_vfio')

            if [[ "$device_requires_vfio" == "true" ]]; then
                requires_vfio=true
            fi

            # Build device JSON
            local device_json='{"address":"'"$gpu_address"'",'
            device_json+='"device_info":'"$device_info"','
            device_json+='"vfio_requirement":'"$vfio_requirement"'}'

            # Add to appropriate array
            if [[ "$is_gpu" == "true" ]]; then
                if [[ "$first_gpu" == "true" ]]; then
                    gpu_json+="$device_json"
                    first_gpu=false
                else
                    gpu_json+=",$device_json"
                fi
            elif [[ "$is_audio" == "true" ]]; then
                if [[ "$first_audio" == "true" ]]; then
                    audio_json+="$device_json"
                    first_audio=false
                else
                    audio_json+=",$device_json"
                fi
            fi
        fi
    done <<< "$gpu_devices"

    gpu_json+=']'
    audio_json+=']'

    # Build final JSON output
    local json_output='{"success":true,"vm_name":"'"$vm_name"'","has_gpu":true,"gpu_devices":'"$gpu_json"',"audio_devices":'"$audio_json"',"requires_vfio":'"$requires_vfio"',"timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}}'

    log "INFO" "GPU requirements check completed: requires_vfio=$requires_vfio"

    echo "$json_output" | jq .
}

# Run main function
main "$@"