#!/bin/bash

# manage_vm_services.sh
# Manage VM services during GPU switching
# Usage: ./manage_vm_services.sh <operation> <vm1> [<vm2> ...]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source secure shell library
source "$SCRIPT_DIR/secure_shell_lib.sh"
STATE_DIR="/var/lib/gpu.switch.manager/states"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    secure_log "$level" "[MANAGE_VM] $message"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    secure_error_exit "$1"
}

# Check if virsh is available
check_virsh() {
    if ! command -v virsh &> /dev/null; then
        error_exit "virsh command not found"
    fi

    # Check if libvirt is running
    if ! virsh version &> /dev/null; then
        error_exit "libvirt service is not running"
    fi
}

# Validate operation
validate_operation() {
    local operation="$1"

    case "$operation" in
        start|stop|shutdown|destroy|restart|status|list)
            return 0
            ;;
        *)
            error_exit "Invalid operation: $operation (must be start, stop, shutdown, destroy, restart, status, or list)"
            ;;
    esac
}

# Validate VM name
validate_vm_name() {
    local vm_name="$1"

    if [[ -z "$vm_name" ]]; then
        error_exit "VM name cannot be empty"
    fi

    # Check if VM exists
    if ! virsh list --all | grep -q "^\s*${vm_name}\s"; then
        error_exit "VM not found: $vm_name"
    fi
}

# Get VM state
get_vm_state() {
    local vm_name="$1"
    virsh domstate "$vm_name" 2>/dev/null || echo "unknown"
}

# Get VM GPU configuration
get_vm_gpu_config() {
    local vm_name="$1"

    # Get GPU devices from VM XML
    local gpu_devices=$(virsh dumpxml "$vm_name" 2>/dev/null | grep -A 10 "hostdev" | grep "pci" | grep -oP 'domain="0x[0-9a-f]+"\s+bus="0x[0-9a-f]+"\s+slot="0x[0-9a-f]+"\s+function="0x[0-9a-f]+"' | sed 's/domain="0x//;s/"\s+bus="0x/:/;s/"\s+slot="0x/:/;s/"\s+function="0x/./;s/"//g' | head -1)

    if [[ -n "$gpu_devices" ]]; then
        # Format as PCI address
        local domain=$(echo "$gpu_devices" | cut -d: -f1)
        local bus=$(echo "$gpu_devices" | cut -d: -f2)
        local slot=$(echo "$gpu_devices" | cut -d: -f3)
        local func=$(echo "$gpu_devices" | cut -d: -f4)

        # Pad with zeros
        printf "%04x:%02x:%02x.%01x" "0x$domain" "0x$bus" "0x$slot" "0x$func"
    else
        echo ""
    fi
}

# Start VM
start_vm() {
    local vm_name="$1"
    local current_state=$(get_vm_state "$vm_name")

    log "INFO" "Starting VM: $vm_name (current state: $current_state)"

    if [[ "$current_state" == "shut off" ]] || [[ "$current_state" == "paused" ]]; then
        # Start VM
        if virsh start "$vm_name" &> /dev/null; then
            log "INFO" "VM started successfully: $vm_name"
            echo "running"
        else
            log "ERROR" "Failed to start VM: $vm_name"
            echo "failed"
        fi
    elif [[ "$current_state" == "running" ]]; then
        log "INFO" "VM already running: $vm_name"
        echo "already_running"
    else
        log "WARN" "VM in unexpected state: $vm_name ($current_state)"
        echo "unexpected_state"
    fi
}

# Stop VM gracefully
stop_vm() {
    local vm_name="$1"
    local current_state=$(get_vm_state "$vm_name")

    log "INFO" "Stopping VM: $vm_name (current state: $current_state)"

    if [[ "$current_state" == "running" ]]; then
        # Try graceful shutdown first
        if virsh shutdown "$vm_name" &> /dev/null; then
            log "INFO" "VM shutdown initiated: $vm_name"

            # Wait for shutdown (up to 60 seconds)
            local timeout=60
            local elapsed=0
            while [[ $elapsed -lt $timeout ]]; do
                local new_state=$(get_vm_state "$vm_name")
                if [[ "$new_state" == "shut off" ]]; then
                    log "INFO" "VM shut down successfully: $vm_name"
                    echo "stopped"
                    return 0
                fi
                sleep 2
                ((elapsed+=2))
            done

            # If still running, force stop
            log "WARN" "VM did not shut down gracefully, forcing: $vm_name"
            if virsh destroy "$vm_name" &> /dev/null; then
                log "INFO" "VM forced to stop: $vm_name"
                echo "forced_stopped"
            else
                log "ERROR" "Failed to force stop VM: $vm_name"
                echo "failed"
            fi
        else
            log "ERROR" "Failed to initiate VM shutdown: $vm_name"
            echo "failed"
        fi
    elif [[ "$current_state" == "shut off" ]]; then
        log "INFO" "VM already stopped: $vm_name"
        echo "already_stopped"
    else
        log "WARN" "VM in unexpected state: $vm_name ($current_state)"
        echo "unexpected_state"
    fi
}

# Shutdown VM (alias for stop)
shutdown_vm() {
    stop_vm "$@"
}

# Destroy VM (force stop)
destroy_vm() {
    local vm_name="$1"
    local current_state=$(get_vm_state "$vm_name")

    log "INFO" "Destroying VM: $vm_name (current state: $current_state)"

    if [[ "$current_state" == "running" ]] || [[ "$current_state" == "paused" ]]; then
        # Force stop VM
        if virsh destroy "$vm_name" &> /dev/null; then
            log "INFO" "VM destroyed successfully: $vm_name"
            echo "destroyed"
        else
            log "ERROR" "Failed to destroy VM: $vm_name"
            echo "failed"
        fi
    elif [[ "$current_state" == "shut off" ]]; then
        log "INFO" "VM already stopped: $vm_name"
        echo "already_stopped"
    else
        log "WARN" "VM in unexpected state: $vm_name ($current_state)"
        echo "unexpected_state"
    fi
}

# Restart VM
restart_vm() {
    local vm_name="$1"

    log "INFO" "Restarting VM: $vm_name"

    # Stop VM first
    local stop_result=$(stop_vm "$vm_name")

    if [[ "$stop_result" == "stopped" ]] || [[ "$stop_result" == "forced_stopped" ]] || [[ "$stop_result" == "already_stopped" ]]; then
        # Start VM
        local start_result=$(start_vm "$vm_name")

        if [[ "$start_result" == "running" ]]; then
            echo "restarted"
        else
            echo "failed"
        fi
    else
        echo "failed"
    fi
}

# Get VM status
get_vm_status() {
    local vm_name="$1"
    local state=$(get_vm_state "$vm_name")
    local gpu_config=$(get_vm_gpu_config "$vm_name")

    # Get additional info
    local memory=$(virsh dominfo "$vm_name" 2>/dev/null | grep "Max memory" | awk '{print $3}' || echo "")
    local vcpus=$(virsh dominfo "$vm_name" 2>/dev/null | grep "CPU(s)" | awk '{print $2}' || echo "")

    echo "state:$state|gpu:$gpu_config|memory:$memory|vcpus:$vcpus"
}

# List all VMs
list_vms() {
    log "INFO" "Listing all VMs"

    local vms_json="["

    local first=true
    while IFS= read -r line; do
        local vm_id=$(echo "$line" | awk '{print $1}')
        local vm_name=$(echo "$line" | awk '{print $2}')
        local state=$(echo "$line" | awk '{print $3}')

        # Skip header
        if [[ "$vm_id" == "Id" ]]; then
            continue
        fi

        # Get GPU configuration
        local gpu_config=$(get_vm_gpu_config "$vm_name")

        if [[ "$first" == "true" ]]; then
            vms_json+="{\"id\":\"$vm_id\",\"name\":\"$vm_name\",\"state\":\"$state\",\"gpu_config\":\"$gpu_config\"}"
            first=false
        else
            vms_json+=",{\"id\":\"$vm_id\",\"name\":\"$vm_name\",\"state\":\"$state\",\"gpu_config\":\"$gpu_config\"}"
        fi
    done < <(virsh list --all)

    vms_json+="]"
    echo "$vms_json"
}

# List GPU-dependent VMs
list_gpu_vms() {
    log "INFO" "Listing GPU-dependent VMs"

    local gpu_vms_json="["

    local first=true
    while IFS= read -r line; do
        local vm_id=$(echo "$line" | awk '{print $1}')
        local vm_name=$(echo "$line" | awk '{print $2}')
        local state=$(echo "$line" | awk '{print $3}')

        # Skip header
        if [[ "$vm_id" == "Id" ]]; then
            continue
        fi

        # Get GPU configuration
        local gpu_config=$(get_vm_gpu_config "$vm_name")

        # Only include if GPU configuration detected
        if [[ -n "$gpu_config" ]]; then
            if [[ "$first" == "true" ]]; then
                gpu_vms_json+="{\"id\":\"$vm_id\",\"name\":\"$vm_name\",\"state\":\"$state\",\"gpu_config\":\"$gpu_config\"}"
                first=false
            else
                gpu_vms_json+=",{\"id\":\"$vm_id\",\"name\":\"$vm_name\",\"state\":\"$state\",\"gpu_config\":\"$gpu_config\"}"
            fi
        fi
    done < <(virsh list --all)

    gpu_vms_json+="]"
    echo "$gpu_vms_json"
}

# Main function
main() {
    # Check arguments
    if [[ $# -lt 1 ]]; then
        error_exit "Usage: $0 <operation> [vm1] [vm2] ..."
    fi

    local operation="$1"
    shift

    # Validate operation
    validate_operation "$operation"

    # Check virsh availability
    check_virsh

    log "INFO" "Starting VM service management (operation: $operation)"

    # Handle different operations
    case "$operation" in
        list)
            local vms=$(list_vms)
            echo '{"success":true,"operation":"list","vms":'"$vms"',"timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}' | jq .
            ;;

        status)
            if [[ $# -eq 0 ]]; then
                error_exit "Usage: $0 status <vm_name>"
            fi

            local vm_name="$1"
            validate_vm_name "$vm_name"

            local status_info=$(get_vm_status "$vm_name")
            local state=$(echo "$status_info" | cut -d'|' -f1 | cut -d: -f2)
            local gpu_config=$(echo "$status_info" | cut -d'|' -f2 | cut -d: -f2)
            local memory=$(echo "$status_info" | cut -d'|' -f3 | cut -d: -f2)
            local vcpus=$(echo "$status_info" | cut -d'|' -f4 | cut -d: -f2)

            echo '{"success":true,"operation":"status","vm":{"name":"'"$vm_name"'","state":"'"$state"'","gpu_config":"'"$gpu_config"'","memory":"'"$memory"'","vcpus":"'"$vcpus"'"},"timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}' | jq .
            ;;

        start|stop|shutdown|destroy|restart)
            if [[ $# -eq 0 ]]; then
                error_exit "Usage: $0 $operation <vm1> [vm2] ..."
            fi

            local vms_json="["
            local first=true
            local successful=0
            local failed=0

            for vm_name in "$@"; do
                validate_vm_name "$vm_name"

                local previous_state=$(get_vm_state "$vm_name")
                local gpu_config=$(get_vm_gpu_config "$vm_name")
                local result=""

                case "$operation" in
                    start)
                        result=$(start_vm "$vm_name")
                        ;;
                    stop)
                        result=$(stop_vm "$vm_name")
                        ;;
                    shutdown)
                        result=$(shutdown_vm "$vm_name")
                        ;;
                    destroy)
                        result=$(destroy_vm "$vm_name")
                        ;;
                    restart)
                        result=$(restart_vm "$vm_name")
                        ;;
                esac

                local current_state=$(get_vm_state "$vm_name")
                local operation_success=false

                if [[ "$result" == "running" ]] || [[ "$result" == "stopped" ]] || [[ "$result" == "destroyed" ]] || [[ "$result" == "restarted" ]]; then
                    operation_success=true
                    ((successful++))
                elif [[ "$result" == "already_running" ]] || [[ "$result" == "already_stopped" ]]; then
                    operation_success=true
                    ((successful++))
                else
                    ((failed++))
                fi

                if [[ "$first" == "true" ]]; then
                    vms_json+="{\"name\":\"$vm_name\",\"previous_state\":\"$previous_state\",\"current_state\":\"$current_state\",\"gpu_config\":\"$gpu_config\",\"operation_success\":$operation_success}"
                    first=false
                else
                    vms_json+=",{\"name\":\"$vm_name\",\"previous_state\":\"$previous_state\",\"current_state\":\"$current_state\",\"gpu_config\":\"$gpu_config\",\"operation_success\":$operation_success}"
                fi
            done

            vms_json+="]"

            local total=$(($successful + $failed))
            echo '{"success":true,"operation":"'"$operation"'","vms":'"$vms_json"',"total_vms":'"$total"',"successful_operations":'"$successful"',"failed_operations":'"$failed"',"timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}' | jq .
            ;;

        *)
            error_exit "Unknown operation: $operation"
            ;;
    esac
}

# Run main function
main "$@"