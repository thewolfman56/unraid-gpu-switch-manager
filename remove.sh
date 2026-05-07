#!/bin/bash

# GPU Switch Manager Removal Script
# Version: 1.0.0
# Description: Removes the GPU Switch Manager plugin from Unraid

set -e  # Exit on error
set -u  # Exit on undefined variable

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Plugin information
PLUGIN_NAME="GPU Switch Manager"
PLUGIN_VERSION="2026.05.05"
PLUGIN_DIR="gpu-switch-manager"
CONFIG_DIR="/boot/config/plugins/$PLUGIN_DIR"
RUNTIME_DIR="/usr/local/emhttp/plugins/$PLUGIN_DIR"
LOG_FILE="/var/log/gpu-switch-manager.log"
BACKUP_DIR="/tmp/gpu-switch-manager.backup"

# Function to print colored messages
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to print error and exit
error_exit() {
    print_message "$RED" "ERROR: $1"
    exit 1
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root"
    fi
}

# Function to check if plugin is installed
check_plugin_installed() {
    if [[ ! -d "$RUNTIME_DIR" ]]; then
        error_exit "Plugin is not installed. Runtime directory not found: $RUNTIME_DIR"
    fi
}

# Function to stop running processes
stop_processes() {
    print_message "$YELLOW" "Stopping any running plugin processes..."

    # Stop any running GPU switch manager processes
    local pids=$(pgrep -f "gpu.switch.manager" || true)

    if [[ -n "$pids" ]]; then
        print_message "$YELLOW" "Found running processes: $pids"
        kill $pids 2>/dev/null || true
        sleep 2

        # Force kill if still running
        pids=$(pgrep -f "gpu.switch.manager" || true)
        if [[ -n "$pids" ]]; then
            print_message "$YELLOW" "Force killing remaining processes..."
            kill -9 $pids 2>/dev/null || true
        fi
    fi

    print_message "$GREEN" "All processes stopped"
}

# Function to backup configuration
backup_configuration() {
    print_message "$YELLOW" "Backing up configuration..."

    if [[ ! -d "$CONFIG_DIR" ]]; then
        print_message "$YELLOW" "No configuration directory found, skipping backup"
        return
    fi

    # Create backup directory
    mkdir -p "$BACKUP_DIR"

    # Backup configuration files
    if [[ -f "$CONFIG_DIR/gpu.switch.manager.cfg" ]]; then
        cp "$CONFIG_DIR/gpu.switch.manager.cfg" "$BACKUP_DIR/"
        print_message "$GREEN" "Backed up main configuration"
    fi

    if [[ -f "$CONFIG_DIR/profiles.json" ]]; then
        cp "$CONFIG_DIR/profiles.json" "$BACKUP_DIR/"
        print_message "$GREEN" "Backed up profiles"
    fi

    if [[ -f "$CONFIG_DIR/state.json" ]]; then
        cp "$CONFIG_DIR/state.json" "$BACKUP_DIR/"
        print_message "$GREEN" "Backed up state"
    fi

    # Create backup info file
    cat > "$BACKUP_DIR/backup_info.txt" << EOF
GPU Switch Manager Configuration Backup
========================================
Plugin Version: $PLUGIN_VERSION
Backup Date: $(date '+%Y-%m-%d %H:%M:%S')
Original Location: $CONFIG_DIR

Files Included:
- gpu.switch.manager.cfg (main configuration)
- profiles.json (GPU profiles)
- state.json (runtime state)

To restore, copy these files back to:
$CONFIG_DIR
EOF

    print_message "$GREEN" "Configuration backed up to: $BACKUP_DIR"
}

# Function to ask user about configuration preservation
ask_preserve_config() {
    if [[ ! -d "$CONFIG_DIR" ]]; then
        return 0  # No config to preserve
    fi

    print_message "$YELLOW" "Do you want to preserve your configuration files?"
    echo "Configuration includes:"
    echo "  - GPU profiles"
    echo "  - Custom settings"
    echo "  - Runtime state"
    echo ""
    read -p "Preserve configuration? (Y/n): " preserve

    if [[ "$preserve" == "n" ]] || [[ "$preserve" == "N" ]]; then
        return 1  # User wants to delete config
    else
        return 0  # User wants to preserve config
    fi
}

# Function to remove runtime files
remove_runtime_files() {
    print_message "$YELLOW" "Removing runtime files..."

    if [[ -d "$RUNTIME_DIR" ]]; then
        rm -rf "$RUNTIME_DIR"
        print_message "$GREEN" "Runtime files removed"
    else
        print_message "$YELLOW" "No runtime files found"
    fi
}

# Function to remove configuration files
remove_config_files() {
    print_message "$YELLOW" "Removing configuration files..."

    if [[ -d "$CONFIG_DIR" ]]; then
        rm -rf "$CONFIG_DIR"
        print_message "$GREEN" "Configuration files removed"
    else
        print_message "$YELLOW" "No configuration files found"
    fi
}

# Function to remove log files
remove_log_files() {
    print_message "$YELLOW" "Removing log files..."

    if [[ -f "$LOG_FILE" ]]; then
        rm -f "$LOG_FILE"
        print_message "$GREEN" "Log files removed"
    else
        print_message "$YELLOW" "No log files found"
    fi
}

# Function to create final log entry
create_final_log_entry() {
    if [[ -f "$LOG_FILE" ]]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[$timestamp] GPU Switch Manager v$PLUGIN_VERSION uninstalled" >> "$LOG_FILE"
    fi
}

# Function to display removal summary
display_summary() {
    print_message "$GREEN" "=========================================="
    print_message "$GREEN" "Removal Complete!"
    print_message "$GREEN" "=========================================="
    echo ""
    echo "Plugin: $PLUGIN_NAME"
    echo "Version: $PLUGIN_VERSION"
    echo ""

    if [[ -d "$BACKUP_DIR" ]]; then
        print_message "$YELLOW" "Configuration preserved at: $BACKUP_DIR"
        echo "To restore configuration, copy files back to: $CONFIG_DIR"
        echo ""
    fi

    print_message "$YELLOW" "Thank you for using $PLUGIN_NAME!"
    print_message "$YELLOW" "Feedback: https://github.com/yourname/unraid-gpu-switch-manager/issues"
}

# Function to display warning
display_warning() {
    print_message "$RED" "=========================================="
    print_message "$RED" "WARNING: Plugin Removal"
    print_message "$RED" "=========================================="
    echo ""
    print_message "$YELLOW" "You are about to remove the $PLUGIN_NAME plugin."
    echo ""
    print_message "$YELLOW" "This will:"
    echo "  - Stop all plugin processes"
    echo "  - Remove all plugin files"
    echo "  - Remove log files"
    echo "  - Optionally remove configuration files"
    echo ""
    print_message "$RED" "This action cannot be easily undone!"
    echo ""
    read -p "Are you sure you want to continue? (y/N): " confirm

    if [[ "$confirm" != "y" ]] && [[ "$confirm" != "Y" ]]; then
        print_message "$YELLOW" "Removal cancelled by user"
        exit 0
    fi
}

# Main removal process
main() {
    print_message "$GREEN" "=========================================="
    print_message "$GREEN" "$PLUGIN_NAME v$PLUGIN_VERSION"
    print_message "$GREEN" "Removal Script"
    print_message "$GREEN" "=========================================="
    echo ""

    # Run pre-removal checks
    check_root
    check_plugin_installed

    # Display warning and get confirmation
    display_warning

    echo ""

    # Stop running processes
    stop_processes

    # Ask about configuration preservation
    if ask_preserve_config; then
        backup_configuration
    fi

    echo ""

    # Remove files
    remove_runtime_files

    if ! ask_preserve_config; then
        remove_config_files
    fi

    remove_log_files

    # Create final log entry (if log file still exists)
    create_final_log_entry

    echo ""

    # Display summary
    display_summary

    print_message "$GREEN" "Removal completed successfully!"
}

# Run main function
main "$@"