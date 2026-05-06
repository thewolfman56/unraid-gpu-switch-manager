#!/bin/bash

# GPU Switch Manager - Primary GPU Detection Script
# Version: 1.0.0
# Description: Identify the primary/boot GPU

set -euo pipefail

# Source secure shell library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/secure_shell_lib.sh"

# Function to check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to get boot GPU from kernel command line
get_boot_gpu() {
    local video_param=$(cat /proc/cmdline | grep -oP 'video=\K[^ ]+' || echo "")

    if [[ -n "$video_param" ]]; then
        # Extract PCI address from video parameter
        local boot_gpu=$(echo "$video_param" | grep -oP '[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f]' || echo "")
        echo "$boot_gpu"
    else
        echo ""
    fi
}

# Function to get first VGA device
get_first_vga() {
    local first_vga=$(lspci -nn | grep -m1 "VGA" | awk '{print $1}' || echo "")
    echo "$first_vga"
}

# Function to check for connected monitors
has_connected_monitors() {
    local pci_address="$1"

    if command_exists xrandr; then
        # Try to get display information
        local displays=$(xrandr --query 2>/dev/null | grep " connected" | wc -l)
        if [[ "$displays" -gt 0 ]]; then
            echo "true"
        else
            echo "false"
        fi
    else
        echo "unknown"
    fi
}

# Function to check display server usage
check_display_server() {
    local display_server="none"
    local display_pid=""

    # Check for Xorg
    if pgrep -x "Xorg" > /dev/null; then
        display_server="Xorg"
        display_pid=$(pgrep -x "Xorg" | head -1)
    fi

    # Check for Wayland compositors
    if pgrep -x "weston" > /dev/null; then
        display_server="weston"
        display_pid=$(pgrep -x "weston" | head -1)
    elif pgrep -x "gnome-shell" > /dev/null; then
        display_server="gnome-shell"
        display_pid=$(pgrep -x "gnome-shell" | head -1)
    elif pgrep -x "kwin" > /dev/null; then
        display_server="kwin"
        display_pid=$(pgrep -x "kwin" | head -1)
    fi

    echo "$display_server|$display_pid"
}

# Function to get GPU used by display server
get_display_gpu() {
    local display_server_info=$(check_display_server)
    local display_server=$(echo "$display_server_info" | cut -d'|' -f1)
    local display_pid=$(echo "$display_server_info" | cut -d'|' -f2)

    if [[ "$display_server" == "none" ]]; then
        echo ""
        return
    fi

    # Check which GPU the display server is using
    if [[ -n "$display_pid" ]] && [[ -d "/proc/$display_pid" ]]; then
        # Check opened files for GPU devices
        local gpu_device=$(lsof -p "$display_pid" 2>/dev/null | grep -E "/dev/nvidia|/dev/dri" | head -1 | awk '{print $9}')

        if [[ -n "$gpu_device" ]]; then
            # Try to map device to PCI address
            if [[ "$gpu_device" =~ /dev/nvidia([0-9]+) ]]; then
                local nvidia_num="${BASH_REMATCH[1]}"
                # Map NVIDIA device number to PCI address
                # This is simplified - actual mapping may vary
                local gpu_address=$(nvidia-smi --query-gpu=pci.bus_id --format=csv,noheader 2>/dev/null | sed "${nvidia_num}q;d" | tail -1 | sed 's/0000://')
                echo "$gpu_address"
            elif [[ "$gpu_device" =~ /dev/dri/(renderD[0-9]+) ]]; then
                # Map DRI device to PCI address
                local dri_num="${BASH_REMATCH[1]}"
                local gpu_num=$((${dri_num#renderD} - 128))
                # This is simplified - actual mapping may vary
                echo "unknown"
            else
                echo "unknown"
            fi
        else
            echo ""
        fi
    else
        echo ""
    fi
}

# Function to determine primary GPU
determine_primary_gpu() {
    local boot_gpu=$(get_boot_gpu)
    local first_vga=$(get_first_vga)
    local display_gpu=$(get_display_gpu)

    # Priority: boot GPU > display GPU > first VGA
    if [[ -n "$boot_gpu" ]]; then
        echo "$boot_gpu"
    elif [[ -n "$display_gpu" ]]; then
        echo "$display_gpu"
    elif [[ -n "$first_vga" ]]; then
        echo "$first_vga"
    else
        echo ""
    fi
}

# Function to get GPU count
get_gpu_count() {
    local gpu_count=$(lspci -nn | grep -E "VGA|3D|Display" | wc -l)
    echo "$gpu_count"
}

# Function to assess switching safety
assess_safety() {
    local primary_gpu="$1"
    local gpu_count="$2"

    if [[ -z "$primary_gpu" ]]; then
        echo "safe|No primary GPU detected"
        return
    fi

    if [[ "$gpu_count" -eq 1 ]]; then
        echo "unsafe|Only one GPU available - switching primary GPU will leave system without display"
        return
    fi

    # Check if display server is running
    local display_server_info=$(check_display_server)
    local display_server=$(echo "$display_server_info" | cut -d'|' -f1)

    if [[ "$display_server" != "none" ]]; then
        echo "caution|Display server is running - ensure secondary display is available before switching"
        return
    fi

    echo "safe|Multiple GPUs available - switching should be safe"
}

# Function to get recommendations
get_recommendations() {
    local primary_gpu="$1"
    local gpu_count="$2"
    local safety_assessment=$(assess_safety "$primary_gpu" "$gpu_count")
    local safety_level=$(echo "$safety_assessment" | cut -d'|' -f1)
    local safety_reason=$(echo "$safety_assessment" | cut -d'|' -f2)

    local recommendations="[]"

    if [[ "$safety_level" == "unsafe" ]]; then
        recommendations='["Do not switch the primary GPU","Install a secondary GPU for display","Use headless operation if possible"]'
    elif [[ "$safety_level" == "caution" ]]; then
        recommendations='["Verify secondary display is connected","Test switching with display server stopped","Ensure remote access is available"]'
    else
        recommendations='["Switching is safe","Monitor system after switching","Have recovery plan ready"]'
    fi

    echo "$recommendations"
}

# Main function
main() {
    # Check for required tools
    if ! command_exists lspci; then
        secure_error_exit "lspci command not found. Please install pciutils."
    fi

    # Get GPU information
    local boot_gpu=$(get_boot_gpu)
    local first_vga=$(get_first_vga)
    local display_gpu=$(get_display_gpu)
    local primary_gpu=$(determine_primary_gpu)
    local gpu_count=$(get_gpu_count)

    # Get display server info
    local display_server_info=$(check_display_server)
    local display_server=$(echo "$display_server_info" | cut -d'|' -f1)
    local display_pid=$(echo "$display_server_info" | cut -d'|' -f2)

    # Get safety assessment
    local safety_assessment=$(assess_safety "$primary_gpu" "$gpu_count")
    local safety_level=$(echo "$safety_assessment" | cut -d'|' -f1)
    local safety_reason=$(echo "$safety_assessment" | cut -d'|' -f2)

    # Get recommendations
    local recommendations=$(get_recommendations "$primary_gpu" "$gpu_count")

    # Secure JSON output
    local escaped_boot=$(secure_json_escape "$boot_gpu")
    local escaped_first=$(secure_json_escape "$first_vga")
    local escaped_display=$(secure_json_escape "$display_gpu")
    local escaped_primary=$(secure_json_escape "$primary_gpu")
    local escaped_server=$(secure_json_escape "$display_server")
    local escaped_level=$(secure_json_escape "$safety_level")
    local escaped_reason=$(secure_json_escape "$safety_reason")
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    cat << EOF
{
    "boot_gpu": "$escaped_boot",
    "first_vga": "$escaped_first",
    "display_gpu": "$escaped_display",
    "primary_gpu": "$escaped_primary",
    "gpu_count": $gpu_count,
    "display_server": "$escaped_server",
    "display_pid": "$display_pid",
    "safety_level": "$escaped_level",
    "safety_reason": "$escaped_reason",
    "recommendations": $recommendations,
    "timestamp": "$timestamp"
}
EOF
}

# Run main function
main "$@"