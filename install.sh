#!/bin/bash

# GPU Switch Manager Installation Script
# Version: 1.0.0
# Description: Installs the GPU Switch Manager plugin for Unraid

set -e  # Exit on error
set -u  # Exit on undefined variable

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Plugin information
PLUGIN_NAME="GPU Switch Manager"
PLUGIN_VERSION="1.0.0"
PLUGIN_DIR="gpu.switch.manager"
CONFIG_DIR="/boot/config/plugins/$PLUGIN_DIR"
RUNTIME_DIR="/usr/local/emhttp/plugins/$PLUGIN_DIR"
LOG_FILE="/var/log/gpu.switch.manager.log"

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

# Function to validate Unraid version
check_unraid_version() {
    print_message "$YELLOW" "Checking Unraid version..."

    if [[ ! -f /etc/unraid-version ]]; then
        error_exit "Unraid version file not found. Are you running on Unraid?"
    fi

    local unraid_version=$(cat /etc/unraid-version)
    print_message "$GREEN" "Found Unraid version: $unraid_version"

    # Check for minimum version 6.12.0
    # This is a basic check - can be enhanced for more precise version comparison
    if [[ ! "$unraid_version" =~ "6.12" ]] && [[ ! "$unraid_version" =~ "6.13" ]] && [[ ! "$unraid_version" =~ "7." ]]; then
        print_message "$YELLOW" "Warning: This plugin requires Unraid 6.12.0 or higher"
        read -p "Continue anyway? (y/N): " confirm
        if [[ "$confirm" != "y" ]] && [[ "$confirm" != "Y" ]]; then
            error_exit "Installation cancelled"
        fi
    fi
}

# Function to check for required tools
check_required_tools() {
    print_message "$YELLOW" "Checking for required tools..."

    local required_tools=("bash" "mkdir" "chmod" "chown" "cat" "grep" "sed")
    local missing_tools=()

    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        error_exit "Missing required tools: ${missing_tools[*]}"
    fi

    # Check for optional but recommended tools
    local optional_tools=("lspci" "virsh" "docker")
    local missing_optional=()

    for tool in "${optional_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_optional+=("$tool")
        fi
    done

    if [[ ${#missing_optional[@]} -gt 0 ]]; then
        print_message "$YELLOW" "Warning: Missing optional tools: ${missing_optional[*]}"
        print_message "$YELLOW" "Some features may not work without these tools"
    fi

    print_message "$GREEN" "All required tools found"
}

# Function to check disk space
check_disk_space() {
    print_message "$YELLOW" "Checking disk space..."

    local required_space_mb=10
    local available_space_mb=$(df -m /boot | tail -1 | awk '{print $4}')

    if [[ $available_space_mb -lt $required_space_mb ]]; then
        error_exit "Insufficient disk space. Required: ${required_space_mb}MB, Available: ${available_space_mb}MB"
    fi

    print_message "$GREEN" "Sufficient disk space available"
}

# Function to create directory structure
create_directories() {
    print_message "$YELLOW" "Creating directory structure..."

    # Create runtime directory
    mkdir -p "$RUNTIME_DIR"/{scripts,event,include,javascript,styles,templates,assets}

    # Create web plugins directory
    mkdir -p /usr/local/emhttp/webplugins/gpu-switch-manager

    # Create settings directory
    mkdir -p /usr/local/emhttp/websettings/gpu-switch-manager

    # Create config directory
    mkdir -p "$CONFIG_DIR"

    # Create log file
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"

    print_message "$GREEN" "Directory structure created"
}

# Function to copy plugin files
copy_plugin_files() {
    print_message "$YELLOW" "Copying plugin files..."

    # Get script directory
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Copy include files
    if [[ -d "$script_dir/include" ]]; then
        cp -r "$script_dir/include/"* "$RUNTIME_DIR/include/"
        print_message "$GREEN" "Copied include files"
    fi

    # Copy scripts
    if [[ -d "$script_dir/scripts" ]]; then
        cp -r "$script_dir/scripts/"* "$RUNTIME_DIR/scripts/"
        print_message "$GREEN" "Copied scripts"
    fi

    # Copy event handlers
    if [[ -d "$script_dir/event" ]]; then
        cp -r "$script_dir/event/"* "$RUNTIME_DIR/event/"
        print_message "$GREEN" "Copied event handlers"
    fi

    # Copy web interface files
    if [[ -d "$script_dir/web" ]]; then
        cp -r "$script_dir/web/"* /usr/local/emhttp/webplugins/gpu-switch-manager/
        print_message "$GREEN" "Copied web interface files"
    fi

    # Copy assets
    if [[ -d "$script_dir/assets" ]]; then
        cp -r "$script_dir/assets/"* "$RUNTIME_DIR/assets/"
        cp -r "$script_dir/assets/"* /usr/local/emhttp/webplugins/gpu-switch-manager/assets/
        print_message "$GREEN" "Copied assets"
    fi

    # Copy settings page
    if [[ -f "$script_dir/settings/gpu-switch-manager.php" ]]; then
        cp "$script_dir/settings/gpu-switch-manager.php" /usr/local/emhttp/websettings/gpu-switch-manager.php
        print_message "$GREEN" "Copied settings page"
    fi

    # Copy main plugin file
    if [[ -f "$script_dir/gpu-switch-manager.php" ]]; then
        cp "$script_dir/gpu-switch-manager.php" "$RUNTIME_DIR/gpu-switch-manager.php"
        print_message "$GREEN" "Copied main plugin file"
    fi

    # Copy documentation
    if [[ -f "$script_dir/README.md" ]]; then
        cp "$script_dir/README.md" "$RUNTIME_DIR/"
    fi

    if [[ -f "$script_dir/SECURITY-HARDENING-SUMMARY.md" ]]; then
        cp "$script_dir/SECURITY-HARDENING-SUMMARY.md" "$RUNTIME_DIR/"
    fi

    print_message "$GREEN" "All plugin files copied"
}

# Function to set file permissions
set_permissions() {
    print_message "$YELLOW" "Setting file permissions..."

    # Set runtime directory permissions
    chmod -R 755 "$RUNTIME_DIR"

    # Set config directory permissions
    chmod -R 755 "$CONFIG_DIR"

    # Make scripts executable
    find "$RUNTIME_DIR/scripts" -type f -name "*.sh" -exec chmod 755 {} \; 2>/dev/null || true

    # Make event scripts executable
    find "$RUNTIME_DIR/event" -type f -exec chmod 755 {} \; 2>/dev/null || true

    print_message "$GREEN" "File permissions set"
}

# Function to initialize configuration files
initialize_config() {
    print_message "$YELLOW" "Initializing configuration files..."

    # Create main config file if it doesn't exist
    if [[ ! -f "$CONFIG_DIR/gpu.switch.manager.cfg" ]]; then
        cat > "$CONFIG_DIR/gpu.switch.manager.cfg" << 'EOF'
# GPU Switch Manager Configuration File
# Version: 1.0.0

# General Settings
ENABLED=true
DEBUG=false
LOG_LEVEL=info

# Operation Settings
AUTO_START_VM=false
VERIFY_BINDING=true
TIMEOUT_SECONDS=30

# Safety Settings
PROTECT_PRIMARY_GPU=true
REQUIRE_CONFIRMATION=true
BACKUP_CONFIG=true

# Dashboard Settings
REFRESH_INTERVAL=5
SHOW_TEMPERATURES=true
SHOW_UTILIZATION=true
EOF
        print_message "$GREEN" "Created main configuration file"
    else
        print_message "$YELLOW" "Configuration file already exists, preserving existing settings"
    fi

    # Create empty profiles.json if it doesn't exist
    if [[ ! -f "$CONFIG_DIR/profiles.json" ]]; then
        echo '{"version":"1.0","profiles":{}}' > "$CONFIG_DIR/profiles.json"
        print_message "$GREEN" "Created profiles file"
    else
        print_message "$YELLOW" "Profiles file already exists, preserving existing profiles"
    fi

    # Create empty state.json if it doesn't exist
    if [[ ! -f "$CONFIG_DIR/state.json" ]]; then
        echo '{"version":"1.0","last_operation":null,"last_operation_time":null,"active_profile":null,"saved_container_states":{}}' > "$CONFIG_DIR/state.json"
        print_message "$GREEN" "Created state file"
    else
        print_message "$YELLOW" "State file already exists, preserving existing state"
    fi
}

# Function to create log entry
create_log_entry() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] GPU Switch Manager v$PLUGIN_VERSION installed successfully" >> "$LOG_FILE"
}

# Function to display installation summary
display_summary() {
    print_message "$GREEN" "=========================================="
    print_message "$GREEN" "Installation Complete!"
    print_message "$GREEN" "=========================================="
    echo ""
    echo "Plugin: $PLUGIN_NAME"
    echo "Version: $PLUGIN_VERSION"
    echo "Runtime Directory: $RUNTIME_DIR"
    echo "Config Directory: $CONFIG_DIR"
    echo "Log File: $LOG_FILE"
    echo ""
    print_message "$YELLOW" "Access Points:"
    echo "  Settings Page: http://[server-ip]/settings/gpu-switch-manager"
    echo "  Main Interface: http://[server-ip]/gpu-switch-manager/"
    echo "  GPU Management: http://[server-ip]/gpu-switch-manager/gpu.php"
    echo "  Profile Management: http://[server-ip]/gpu-switch-manager/profiles.php"
    echo ""
    print_message "$YELLOW" "Next Steps:"
    echo "1. Access the Settings page to configure the plugin"
    echo "2. Configure your GPU profiles"
    echo "3. Set up Docker containers and VMs for GPU switching"
    echo "4. Test the GPU binding functionality"
    echo "5. Check the dashboard for real-time GPU stats"
    echo ""
    print_message "$YELLOW" "Documentation: https://github.com/thewolfman56/unraid-gpu-switch-manager"
    print_message "$YELLOW" "Support: https://forums.unraid.net/"
}

# Main installation process
main() {
    print_message "$GREEN" "=========================================="
    print_message "$GREEN" "$PLUGIN_NAME v$PLUGIN_VERSION"
    print_message "$GREEN" "Installation Script"
    print_message "$GREEN" "=========================================="
    echo ""

    # Run pre-installation checks
    check_root
    check_unraid_version
    check_required_tools
    check_disk_space

    echo ""

    # Create directory structure
    create_directories

    # Copy plugin files
    copy_plugin_files

    # Set permissions
    set_permissions

    # Initialize configuration
    initialize_config

    # Create log entry
    create_log_entry

    echo ""

    # Display summary
    display_summary

    print_message "$GREEN" "Installation completed successfully!"
}

# Run main function
main "$@"