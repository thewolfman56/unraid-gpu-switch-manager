#!/bin/bash

# register_event_handlers.sh
# Register event handlers with Unraid
# Usage: ./register_event_handlers.sh

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source secure shell library
source "$SCRIPT_DIR/secure_shell_lib.sh"
UNRAID_EVENT_DIR="/usr/local/emhttp/webGui/event_handlers"
PLUGIN_EVENT_DIR="/usr/local/emhttp/plugins/gpu-switch-manager/event_handlers"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S'
    secure_log "$level" "[REGISTER_HANDLERS] $message"
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

# Create event handler directories
create_event_directories() {
    log "INFO" "Creating event handler directories"

    mkdir -p "$UNRAID_EVENT_DIR"
    mkdir -p "$PLUGIN_EVENT_DIR"

    log "INFO" "Event handler directories created successfully"
}

# Register array start handler
register_array_start_handler() {
    log "INFO" "Registering array start handler"

    local handler_file="$UNRAID_EVENT_DIR/gpu-switch-array-start"

    cat > "$handler_file" << 'EOF'
#!/bin/bash

# GPU Switch Manager - Array Start Event Handler
SCRIPT_DIR="/usr/local/emhttp/plugins/gpu-switch-manager/scripts"

if [[ -f "$SCRIPT_DIR/unraid_event_handler.sh" ]]; then
    "$SCRIPT_DIR/unraid_event_handler.sh" array_start
fi

exit 0
EOF

    chmod +x "$handler_file"
    log "INFO" "Registered array start handler: $handler_file"
}

# Register array stop handler
register_array_stop_handler() {
    log "INFO" "Registering array stop handler"

    local handler_file="$UNRAID_EVENT_DIR/gpu-switch-array-stop"

    cat > "$handler_file" << 'EOF'
#!/bin/bash

# GPU Switch Manager - Array Stop Event Handler
SCRIPT_DIR="/usr/local/emhttp/plugins/gpu-switch-manager/scripts"

if [[ -f "$SCRIPT_DIR/unraid_event_handler.sh" ]]; then
    "$SCRIPT_DIR/unraid_event_handler.sh" array_stop
fi

exit 0
EOF

    chmod +x "$handler_file"
    log "INFO" "Registered array stop handler: $handler_file"
}

# Register Docker service start handler
register_docker_start_handler() {
    log "INFO" "Registering Docker service start handler"

    local handler_file="$UNRAID_EVENT_DIR/gpu-switch-docker-start"

    cat > "$handler_file" << 'EOF'
#!/bin/bash

# GPU Switch Manager - Docker Service Start Event Handler
SCRIPT_DIR="/usr/local/emhttp/plugins/gpu-switch-manager/scripts"

if [[ -f "$SCRIPT_DIR/unraid_event_handler.sh" ]]; then
    "$SCRIPT_DIR/unraid_event_handler.sh" docker_start
fi

exit 0
EOF

    chmod +x "$handler_file"
    log "INFO" "Registered Docker service start handler: $handler_file"
}

# Register Docker service stop handler
register_docker_stop_handler() {
    log "INFO" "Registering Docker service stop handler"

    local handler_file="$UNRAID_EVENT_DIR/gpu-switch-docker-stop"

    cat > "$handler_file" << 'EOF'
#!/bin/bash

# GPU Switch Manager - Docker Service Stop Event Handler
SCRIPT_DIR="/usr/local/emhttp/plugins/gpu-switch-manager/scripts"

if [[ -f "$SCRIPT_DIR/unraid_event_handler.sh" ]]; then
    "$SCRIPT_DIR/unraid_event_handler.sh" docker_stop
fi

exit 0
EOF

    chmod +x "$handler_file"
    log "INFO" "Registered Docker service stop handler: $handler_file"
}

# Register VM service start handler
register_vm_start_handler() {
    log "INFO" "Registering VM service start handler"

    local handler_file="$UNRAID_EVENT_DIR/gpu-switch-vm-start"

    cat > "$handler_file" << 'EOF'
#!/bin/bash

# GPU Switch Manager - VM Service Start Event Handler
SCRIPT_DIR="/usr/local/emhttp/plugins/gpu-switch-manager/scripts"

if [[ -f "$SCRIPT_DIR/unraid_event_handler.sh" ]]; then
    "$SCRIPT_DIR/unraid_event_handler.sh" vm_start
fi

exit 0
EOF

    chmod +x "$handler_file"
    log "INFO" "Registered VM service start handler: $handler_file"
}

# Register VM service stop handler
register_vm_stop_handler() {
    log "INFO" "Registering VM service stop handler"

    local handler_file="$UNRAID_EVENT_DIR/gpu-switch-vm-stop"

    cat > "$handler_file" << 'EOF'
#!/bin/bash

# GPU Switch Manager - VM Service Stop Event Handler
SCRIPT_DIR="/usr/local/emhttp/plugins/gpu-switch-manager/scripts"

if [[ -f "$SCRIPT_DIR/unraid_event_handler.sh" ]]; then
    "$SCRIPT_DIR/unraid_event_handler.sh" vm_stop
fi

exit 0
EOF

    chmod +x "$handler_file"
    log "INFO" "Registered VM service stop handler: $handler_file"
}

# Configure event priorities
configure_event_priorities() {
    log "INFO" "Configuring event priorities"

    # GPU Switch Manager handlers should run after system handlers
    # but before user handlers

    # Create priority configuration file
    local priority_file="$PLUGIN_EVENT_DIR/priority.conf"

    cat > "$priority_file" << 'EOF'
# GPU Switch Manager Event Handler Priorities
# Lower numbers = higher priority (run first)

# System handlers (priority 0-10)
# GPU Switch Manager handlers (priority 20-30)
# User handlers (priority 40-50)

array_start: 25
array_stop: 25
docker_start: 25
docker_stop: 25
vm_start: 25
vm_stop: 25
EOF

    log "INFO" "Event priorities configured: $priority_file"
}

# Configure event filtering
configure_event_filtering() {
    log "INFO" "Configuring event filtering"

    # Create filtering configuration file
    local filter_file="$PLUGIN_EVENT_DIR/filter.conf"

    cat > "$filter_file" << 'EOF'
# GPU Switch Manager Event Handler Filtering
# Only process events that are relevant to GPU switching

# Enable/disable specific event types
array_start: true
array_stop: true
docker_start: true
docker_stop: true
vm_start: true
vm_stop: true
custom: false

# Filter by container/VM names (optional)
# container_filter: ""
# vm_filter: ""
EOF

    log "INFO" "Event filtering configured: $filter_file"
}

# Test handler registration
test_handler_registration() {
    log "INFO" "Testing handler registration"

    local all_registered=true
    local registered_handlers='[]'

    # Test array start handler
    if [[ -x "$UNRAID_EVENT_DIR/gpu-switch-array-start" ]]; then
        registered_handlers=$(echo "$registered_handlers" | jq '. + ["array_start"]')
    else
        all_registered=false
        log "ERROR" "Array start handler not registered"
    fi

    # Test array stop handler
    if [[ -x "$UNRAID_EVENT_DIR/gpu-switch-array-stop" ]]; then
        registered_handlers=$(echo "$registered_handlers" | jq '. + ["array_stop"]')
    else
        all_registered=false
        log "ERROR" "Array stop handler not registered"
    fi

    # Test Docker start handler
    if [[ -x "$UNRAID_EVENT_DIR/gpu-switch-docker-start" ]]; then
        registered_handlers=$(echo "$registered_handlers" | jq '. + ["docker_start"]')
    else
        all_registered=false
        log "ERROR" "Docker start handler not registered"
    fi

    # Test Docker stop handler
    if [[ -x "$UNRAID_EVENT_DIR/gpu-switch-docker-stop" ]]; then
        registered_handlers=$(echo "$registered_handlers" | jq '. + ["docker_stop"]')
    else
        all_registered=false
        log "ERROR" "Docker stop handler not registered"
    fi

    # Test VM start handler
    if [[ -x "$UNRAID_EVENT_DIR/gpu-switch-vm-start" ]]; then
        registered_handlers=$(echo "$registered_handlers" | jq '. + ["vm_start"]')
    else
        all_registered=false
        log "ERROR" "VM start handler not registered"
    fi

    # Test VM stop handler
    if [[ -x "$UNRAID_EVENT_DIR/gpu-switch-vm-stop" ]]; then
        registered_handlers=$(echo "$registered_handlers" | jq '. + ["vm_stop"]')
    else
        all_registered=false
        log "ERROR" "VM stop handler not registered"
    fi

    echo '{"all_registered":'"$all_registered"',"registered_handlers":'"$registered_handlers"'}'
}

# Main function
main() {
    log "INFO" "Registering event handlers"

    # Check if running as root
    check_root

    # Create event handler directories
    create_event_directories

    # Register handlers
    register_array_start_handler
    register_array_stop_handler
    register_docker_start_handler
    register_docker_stop_handler
    register_vm_start_handler
    register_vm_stop_handler

    # Configure priorities and filtering
    configure_event_priorities
    configure_event_filtering

    # Test handler registration
    local test_result=$(test_handler_registration)
    local all_registered=$(echo "$test_result" | jq -r '.all_registered')

    if [[ "$all_registered" == "true" ]]; then
        log "INFO" "All event handlers registered successfully"
        echo '{"success":true,"message":"All event handlers registered successfully","test_result":'"$test_result"'}' | jq .
    else
        log "ERROR" "Some event handlers failed to register"
        echo '{"success":false,"message":"Some event handlers failed to register","test_result":'"$test_result"'}' | jq .
        exit 1
    fi
}

# Run main function
main "$@"