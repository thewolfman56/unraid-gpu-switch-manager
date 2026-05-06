#!/bin/bash

# GPU Switch Manager - GPU State Detection Script
# Version: 1.0.0
# Description: Get current state of a specific GPU

set -euo pipefail

# Source secure shell library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/secure_shell_lib.sh"

# Function to check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to get current driver
get_current_driver() {
    local pci_address="$1"
    local driver_path="/sys/bus/pci/devices/$pci_address/driver"

    if [[ -L "$driver_path" ]]; then
        basename "$(readlink "$driver_path")"
    else
        echo "none"
    fi
}

# Function to check if VFIO bound
is_vfio_bound() {
    local pci_address="$1"
    local driver=$(get_current_driver "$pci_address")

    if [[ "$driver" == "vfio-pci" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# Function to check if GPU is in use
is_gpu_in_use() {
    local pci_address="$1"
    local driver=$(get_current_driver "$pci_address")

    # Check for NVIDIA GPU usage
    if [[ "$driver" == "nvidia" ]] && command_exists nvidia-smi; then
        local processes=$(nvidia-smi --query-compute-apps=pid --format=csv,noheader 2>/dev/null | wc -l)
        if [[ "$processes" -gt 0 ]]; then
            echo "true"
            return
        fi
    fi

    # Check for AMD GPU usage
    if [[ "$driver" == "amdgpu" ]]; then
        # Check for open file handles on AMD devices
        local gpu_num=$(echo "$pci_address" | cut -d: -f3 | cut -d. -f1)
        if [[ -e "/dev/dri/renderD$((128 + gpu_num))" ]]; then
            if command_exists lsof; then
                local handles=$(lsof "/dev/dri/renderD$((128 + gpu_num))" 2>/dev/null | wc -l)
                if [[ "$handles" -gt 0 ]]; then
                    echo "true"
                    return
                fi
            fi
        fi
    fi

    # Check for Intel GPU usage
    if [[ "$driver" == "i915" ]]; then
        if command_exists lsof; then
            local handles=$(lsof /dev/dri/* 2>/dev/null | wc -l)
            if [[ "$handles" -gt 0 ]]; then
                echo "true"
                return
            fi
        fi
    fi

    echo "false"
}

# Function to get running processes using GPU
get_gpu_processes() {
    local pci_address="$1"
    local driver=$(get_current_driver "$pci_address")

    local processes="[]"

    # Get NVIDIA processes
    if [[ "$driver" == "nvidia" ]] && command_exists nvidia-smi; then
        local nvidia_processes=$(nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader 2>/dev/null)

        if [[ -n "$nvidia_processes" ]]; then
            processes="["
            local first=true
            while IFS=, read -r pid process_name memory; do
                pid=$(echo "$pid" | xargs)
                process_name=$(echo "$process_name" | xargs)
                memory=$(echo "$memory" | xargs)

                if [[ "$first" == "true" ]]; then
                    first=false
                else
                    processes="$processes,"
                fi

                # Get process user
                local user="unknown"
                if [[ -d "/proc/$pid" ]]; then
                    user=$(stat -c "%U" "/proc/$pid" 2>/dev/null || echo "unknown")
                fi

                processes="$processes{\"pid\":$pid,\"command\":\"$process_name\",\"memory\":\"$memory\",\"user\":\"$user\"}"
            done <<< "$nvidia_processes"
            processes="$processes]"
        fi
    fi

    echo "$processes"
}

# Function to get open file handles
get_file_handles() {
    local pci_address="$1"
    local driver=$(get_current_driver "$pci_address")

    local handles="[]"

    # Get NVIDIA file handles
    if [[ "$driver" == "nvidia" ]]; then
        if command_exists lsof; then
            local nvidia_handles=$(lsof /dev/nvidia* 2>/dev/null | tail -n +2)

            if [[ -n "$nvidia_handles" ]]; then
                handles="["
                local first=true
                while IFS= read -r line; do
                    local handle=$(echo "$line" | awk '{print $9}')

                    if [[ "$first" == "true" ]]; then
                        first=false
                    else
                        handles="$handles,"
                    fi

                    handles="$handles\"$handle\""
                done <<< "$nvidia_handles"
                handles="$handles]"
            fi
        fi
    fi

    # Get DRI file handles
    if [[ "$driver" == "amdgpu" ]] || [[ "$driver" == "i915" ]]; then
        if command_exists lsof; then
            local dri_handles=$(lsof /dev/dri/* 2>/dev/null | tail -n +2)

            if [[ -n "$dri_handles" ]]; then
                if [[ "$handles" == "[]" ]]; then
                    handles="["
                else
                    handles="${handles%}],["  # Replace closing bracket
                fi

                local first=true
                while IFS= read -r line; do
                    local handle=$(echo "$line" | awk '{print $9}')

                    if [[ "$first" == "true" ]]; then
                        first=false
                    else
                        handles="$handles,"
                    fi

                    handles="$handles\"$handle\""
                done <<< "$dri_handles"
                handles="$handles]"
            fi
        fi
    fi

    echo "$handles"
}

# Function to check GPU accessibility
is_accessible() {
    local pci_address="$1"
    local driver=$(get_current_driver "$pci_address")

    # Check if device files exist
    if [[ "$driver" == "nvidia" ]]; then
        if [[ ! -e "/dev/nvidia0" ]] || [[ ! -e "/dev/nvidiactl" ]]; then
            echo "false"
            return
        fi
    elif [[ "$driver" == "amdgpu" ]] || [[ "$driver" == "i915" ]]; then
        local gpu_num=$(echo "$pci_address" | cut -d: -f3 | cut -d. -f1)
        if [[ ! -e "/dev/dri/renderD$((128 + gpu_num))" ]]; then
            echo "false"
            return
        fi
    fi

    echo "true"
}

# Function to get last operation info
get_last_operation() {
    local pci_address="$1"
    local state_file="/boot/config/plugins/gpu.switch.manager/state.json"

    if [[ -f "$state_file" ]]; then
        if command_exists jq; then
            local last_op=$(jq -r ".last_operation // \"none\"" "$state_file" 2>/dev/null || echo "none")
            local last_time=$(jq -r ".last_operation_time // \"null\"" "$state_file" 2>/dev/null || echo "null")

            echo "$last_op|$last_time"
        else
            echo "none|null"
        fi
    else
        echo "none|null"
    fi
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

    # Get GPU state information
    local current_driver=$(get_current_driver "$pci_address")
    local vfio_bound=$(is_vfio_bound "$pci_address")
    local in_use=$(is_gpu_in_use "$pci_address")
    local processes=$(get_gpu_processes "$pci_address")
    local file_handles=$(get_file_handles "$pci_address")
    local accessible=$(is_accessible "$pci_address")

    # Get last operation info
    local last_op_info=$(get_last_operation "$pci_address")
    local last_operation=$(echo "$last_op_info" | cut -d'|' -f1)
    local last_operation_time=$(echo "$last_op_info" | cut -d'|' -f2)

    # Secure JSON output
    local escaped_address=$(secure_json_escape "$pci_address")
    local escaped_driver=$(secure_json_escape "$current_driver")
    local escaped_last_op=$(secure_json_escape "$last_operation")
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    cat << EOF
{
    "pci_address": "$escaped_address",
    "current_driver": "$escaped_driver",
    "vfio_bound": $vfio_bound,
    "in_use": $in_use,
    "processes": $processes,
    "file_handles": $file_handles,
    "accessible": $accessible,
    "last_operation": "$escaped_last_op",
    "last_operation_time": $last_operation_time,
    "timestamp": "$timestamp"
}
EOF
}

# Run main function
main "$@"