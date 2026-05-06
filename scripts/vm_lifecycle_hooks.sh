#!/bin/bash

# vm_lifecycle_hooks.sh
# Install and configure VM lifecycle hooks for automatic GPU switching
# Usage: ./vm_lifecycle_hooks.sh [install|uninstall|status]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source secure shell library
source "$SCRIPT_DIR/secure_shell_lib.sh"

LIBVIRT_HOOKS_DIR="/etc/libvirt/hooks"
LIBVIRT_HOOKS_QEMU_DIR="/etc/libvirt/hooks/qemu.d"
PLUGIN_HOOKS_DIR="/usr/local/emhttp/plugins/gpu-switch-manager/hooks"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    secure_log "$level" "[VM_LIFECYCLE_HOOKS] $message"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    secure_error_exit "$1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root"
    fi
}

# Create hook directories
create_hook_directories() {
    log "INFO" "Creating hook directories"

    mkdir -p "$LIBVIRT_HOOKS_DIR"
    mkdir -p "$LIBVIRT_HOOKS_QEMU_DIR"
    mkdir -p "$PLUGIN_HOOKS_DIR"

    log "INFO" "Hook directories created successfully"
}

# Install libvirt hooks
install_libvirt_hooks() {
    log "INFO" "Installing libvirt hooks"

    # Create main qemu hook
    local qemu_hook="$LIBVIRT_HOOKS_DIR/qemu"

    cat > "$qemu_hook" << 'EOF'
#!/bin/bash

# libvirt qemu hook for GPU switching
# This hook is called by libvirt for VM lifecycle events

# Configuration
SCRIPT_DIR="/usr/local/emhttp/plugins/gpu-switch-manager/scripts"
LOG_FILE="/var/log/gpu.switch.manager.log"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] [LIBVIRT_HOOK] $message" >> "$LOG_FILE"
}

# Get event details
local domain_name="$1"
local operation="$2"
local sub_operation="$3"

log "INFO" "Libvirt hook called: domain=$domain_name, operation=$operation, sub_operation=$sub_operation"

# Handle different operations
case "$operation" in
    prepare)
        # VM is about to start
        log "INFO" "VM prepare event: $domain_name"
        if [[ -f "$SCRIPT_DIR/vm_start_handler.sh" ]]; then
            "$SCRIPT_DIR/vm_start_handler.sh" "$domain_name" &
        fi
        ;;
    start)
        # VM has started
        log "INFO" "VM start event: $domain_name"
        ;;
    stopped)
        # VM has stopped
        log "INFO" "VM stopped event: $domain_name"
        if [[ -f "$SCRIPT_DIR/vm_stop_handler.sh" ]]; then
            "$SCRIPT_DIR/vm_stop_handler.sh" "$domain_name" &
        fi
        ;;
    migrate)
        # VM migration
        log "INFO" "VM migrate event: $domain_name"
        ;;
    restore)
        # VM restore
        log "INFO" "VM restore event: $domain_name"
        ;;
    *)
        log "INFO" "Unknown operation: $operation"
        ;;
esac

exit 0
EOF

    chmod +x "$qemu_hook"
    log "INFO" "Installed libvirt qemu hook: $qemu_hook"

    # Create qemu.d directory structure
    mkdir -p "$LIBVIRT_HOOKS_QEMU_DIR/prepare"
    mkdir -p "$LIBVIRT_HOOKS_QEMU_DIR/start"
    mkdir -p "$LIBVIRT_HOOKS_QEMU_DIR/stopped"

    log "INFO" "Created libvirt hooks.d directory structure"
}

# Install plugin hooks
install_plugin_hooks() {
    log "INFO" "Installing plugin hooks"

    # Create plugin hook directory
    mkdir -p "$PLUGIN_HOOKS_DIR"

    # Create VM start hook
    local vm_start_hook="$PLUGIN_HOOKS_DIR/vm_start.sh"

    cat > "$vm_start_hook" << 'EOF'
#!/bin/bash

# Plugin VM start hook
# This hook is called by the plugin when a VM starts

SCRIPT_DIR="/usr/local/emhttp/plugins/gpu-switch-manager/scripts"
LOG_FILE="/var/log/gpu.switch.manager.log"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S'
    echo "[$timestamp] [$level] [PLUGIN_HOOK] $message" >> "$LOG_FILE"
}

# Get VM name from argument
local vm_name="$1"

log "INFO" "Plugin VM start hook called: $vm_name"

if [[ -f "$SCRIPT_DIR/vm_start_handler.sh" ]]; then
    "$SCRIPT_DIR/vm_start_handler.sh" "$vm_name"
fi

exit 0
EOF

    chmod +x "$vm_start_hook"
    log "INFO" "Installed plugin VM start hook: $vm_start_hook"

    # Create VM stop hook
    local vm_stop_hook="$PLUGIN_HOOKS_DIR/vm_stop.sh"

    cat > "$vm_stop_hook" << 'EOF'
#!/bin/bash

# Plugin VM stop hook
# This hook is called by the plugin when a VM stops

SCRIPT_DIR="/usr/local/emhttp/plugins/gpu-switch-manager/scripts"
LOG_FILE="/var/log/gpu.switch.manager.log"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S'
    echo "[$timestamp] [$level] [PLUGIN_HOOK] $message" >> "$LOG_FILE"
}

# Get VM name from argument
local vm_name="$1"

log "INFO" "Plugin VM stop hook called: $vm_name"

if [[ -f "$SCRIPT_DIR/vm_stop_handler.sh" ]]; then
    "$SCRIPT_DIR/vm_stop_handler.sh" "$vm_name"
fi

exit 0
EOF

    chmod +x "$vm_stop_hook"
    log "INFO" "Installed plugin VM stop hook: $vm_stop_hook"
}

# Configure hook permissions
configure_hook_permissions() {
    log "INFO" "Configuring hook permissions"

    # Set libvirt hooks directory permissions
    chmod 755 "$LIBVIRT_HOOKS_DIR"
    chmod 755 "$LIBVIRT_HOOKS_QEMU_DIR"

    # Set plugin hooks directory permissions
    chmod 755 "$PLUGIN_HOOKS_DIR"

    # Set hook file permissions
    find "$LIBVIRT_HOOKS_DIR" -type f -exec chmod 755 {} \;
    find "$LIBVIRT_HOOKS_QEMU_DIR" -type f -exec chmod 755 {} \;
    find "$PLUGIN_HOOKS_DIR" -type f -exec chmod 755 {} \;

    log "INFO" "Hook permissions configured successfully"
}

# Test hook functionality
test_hooks() {
    log "INFO" "Testing hook functionality"

    # Test libvirt hook
    if [[ -x "$LIBVIRT_HOOKS_DIR/qemu" ]]; then
        log "INFO" "Libvirt hook is executable"
    else
        log "ERROR" "Libvirt hook is not executable"
        return 1
    fi

    # Test plugin hooks
    if [[ -x "$PLUGIN_HOOKS_DIR/vm_start.sh" ]]; then
        log "INFO" "Plugin VM start hook is executable"
    else
        log "ERROR" "Plugin VM start hook is not executable"
        return 1
    fi

    if [[ -x "$PLUGIN_HOOKS_DIR/vm_stop.sh" ]]; then
        log "INFO" "Plugin VM stop hook is executable"
    else
        log "ERROR" "Plugin VM stop hook is not executable"
        return 1
    fi

    log "INFO" "Hook functionality test passed"
    return 0
}

# Uninstall hooks
uninstall_hooks() {
    log "INFO" "Uninstalling hooks"

    # Remove libvirt hooks
    if [[ -f "$LIBVIRT_HOOKS_DIR/qemu" ]]; then
        rm -f "$LIBVIRT_HOOKS_DIR/qemu"
        log "INFO" "Removed libvirt qemu hook"
    fi

    # Remove plugin hooks
    if [[ -f "$PLUGIN_HOOKS_DIR/vm_start.sh" ]]; then
        rm -f "$PLUGIN_HOOKS_DIR/vm_start.sh"
        log "INFO" "Removed plugin VM start hook"
    fi

    if [[ -f "$PLUGIN_HOOKS_DIR/vm_stop.sh" ]]; then
        rm -f "$PLUGIN_HOOKS_DIR/vm_stop.sh"
        log "INFO" "Removed plugin VM stop hook"
    fi

    log "INFO" "Hooks uninstalled successfully"
}

# Get hook status
get_hook_status() {
    log "INFO" "Getting hook status"

    local libvirt_hook_installed=false
    local plugin_hooks_installed=false

    if [[ -f "$LIBVIRT_HOOKS_DIR/qemu" ]]; then
        libvirt_hook_installed=true
    fi

    if [[ -f "$PLUGIN_HOOKS_DIR/vm_start.sh" ]] && [[ -f "$PLUGIN_HOOKS_DIR/vm_stop.sh" ]]; then
        plugin_hooks_installed=true
    fi

    echo '{"libvirt_hook_installed":'"$libvirt_hook_installed"',"plugin_hooks_installed":'"$plugin_hooks_installed"',"libvirt_hooks_dir":"'"$LIBVIRT_HOOKS_DIR"'","plugin_hooks_dir":"'"$PLUGIN_HOOKS_DIR"'","timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}}' | jq .
}

# Main function
main() {
    # Check arguments
    if [[ $# -lt 1 ]]; then
        error_exit "Usage: $0 [install|uninstall|status]"
    fi

    local action="$1"

    log "INFO" "VM lifecycle hooks action: $action"

    case "$action" in
        install)
            check_root
            create_hook_directories
            install_libvirt_hooks
            install_plugin_hooks
            configure_hook_permissions
            test_hooks

            if [[ $? -eq 0 ]]; then
                echo '{"success":true,"message":"VM lifecycle hooks installed successfully","action":"install"}' | jq .
            else
                error_exit "Hook functionality test failed"
            fi
            ;;
        uninstall)
            check_root
            uninstall_hooks
            echo '{"success":true,"message":"VM lifecycle hooks uninstalled successfully","action":"uninstall"}' | jq .
            ;;
        status)
            get_hook_status
            ;;
        *)
            error_exit "Unknown action: $action (must be install, uninstall, or status)"
            ;;
    esac
}

# Run main function
main "$@"