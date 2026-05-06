#!/bin/bash

# restore_service_states.sh
# Restore service states after GPU switching
# Usage: ./restore_service_states.sh <state_file>

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
    secure_log "$level" "[RESTORE_STATES] $message"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    secure_error_exit "$1"
}

# Validate state file
validate_state_file() {
    local state_file="$1"

    if [[ ! -f "$state_file" ]]; then
        error_exit "State file not found: $state_file"
    fi

    if [[ ! -r "$state_file" ]]; then
        error_exit "State file not readable: $state_file"
    fi

    # Validate JSON format
    if ! jq empty "$state_file" 2>/dev/null; then
        error_exit "State file has invalid JSON format: $state_file"
    fi
}

# Check if Docker is available
check_docker() {
    command -v docker &> /dev/null && docker info &> /dev/null
}

# Check if virsh is available
check_virsh() {
    command -v virsh &> /dev/null && virsh version &> /dev/null
}

# Restore container states
restore_container_states() {
    local container_states="$1"
    local containers_json="["
    local first=true
    local successful=0
    local failed=0

    if check_docker; then
        while IFS= read -r container; do
            local name=$(echo "$container" | jq -r '.name')
            local saved_state=$(echo "$container" | jq -r '.state')
            local gpu_usage=$(echo "$container" | jq -r '.gpu_usage')

            # Get current state
            local current_state=$(docker inspect --format='{{.State.Status}}' "$name" 2>/dev/null || echo "unknown")

            local operation_success=false
            local result=""

            # Determine what to do based on saved state
            if [[ "$saved_state" == "running" ]] && [[ "$current_state" != "running" ]]; then
                # Start container
                if docker start "$name" &> /dev/null; then
                    result="started"
                    operation_success=true
                    ((successful++))
                    log "INFO" "Started container: $name"
                else
                    result="failed_to_start"
                    operation_success=false
                    ((failed++))
                    log "ERROR" "Failed to start container: $name"
                fi
            elif [[ "$saved_state" != "running" ]] && [[ "$current_state" == "running" ]]; then
                # Stop container
                if docker stop "$name" &> /dev/null; then
                    result="stopped"
                    operation_success=true
                    ((successful++))
                    log "INFO" "Stopped container: $name"
                else
                    result="failed_to_stop"
                    operation_success=false
                    ((failed++))
                    log "ERROR" "Failed to stop container: $name"
                fi
            else
                # Container already in correct state
                result="no_change_needed"
                operation_success=true
                ((successful++))
                log "INFO" "Container already in correct state: $name"
            fi

            if [[ "$first" == "true" ]]; then
                containers_json+="{\"name\":\"$name\",\"saved_state\":\"$saved_state\",\"current_state\":\"$current_state\",\"result\":\"$result\",\"operation_success\":$operation_success}"
                first=false
            else
                containers_json+=",{\"name\":\"$name\",\"saved_state\":\"$saved_state\",\"current_state\":\"$current_state\",\"result\":\"$result\",\"operation_success\":$operation_success}"
            fi
        done < <(echo "$container_states" | jq -c '.[]')
    else
        log "WARN" "Docker not available, skipping container restoration"
    fi

    containers_json+="]"
    echo "$containers_json|$successful|$failed"
}

# Restore VM states
restore_vm_states() {
    local vm_states="$1"
    local vms_json="["
    local first=true
    local successful=0
    local failed=0

    if check_virsh; then
        while IFS= read -r vm; do
            local name=$(echo "$vm" | jq -r '.name')
            local saved_state=$(echo "$vm" | jq -r '.state')
            local gpu_config=$(echo "$vm" | jq -r '.gpu_config')

            # Get current state
            local current_state=$(virsh domstate "$name" 2>/dev/null || echo "unknown")

            local operation_success=false
            local result=""

            # Determine what to do based on saved state
            if [[ "$saved_state" == "running" ]] && [[ "$current_state" != "running" ]]; then
                # Start VM
                if virsh start "$name" &> /dev/null; then
                    result="started"
                    operation_success=true
                    ((successful++))
                    log "INFO" "Started VM: $name"
                else
                    result="failed_to_start"
                    operation_success=false
                    ((failed++))
                    log "ERROR" "Failed to start VM: $name"
                fi
            elif [[ "$saved_state" != "running" ]] && [[ "$saved_state" != "shut off" ]] && [[ "$current_state" == "running" ]]; then
                # Stop VM
                if virsh shutdown "$name" &> /dev/null; then
                    result="stopped"
                    operation_success=true
                    ((successful++))
                    log "INFO" "Stopped VM: $name"
                else
                    result="failed_to_stop"
                    operation_success=false
                    ((failed++))
                    log "ERROR" "Failed to stop VM: $name"
                fi
            else
                # VM already in correct state
                result="no_change_needed"
                operation_success=true
                ((successful++))
                log "INFO" "VM already in correct state: $name"
            fi

            if [[ "$first" == "true" ]]; then
                vms_json+="{\"name\":\"$name\",\"saved_state\":\"$saved_state\",\"current_state\":\"$current_state\",\"result\":\"$result\",\"operation_success\":$operation_success}"
                first=false
            else
                vms_json+=",{\"name\":\"$name\",\"saved_state\":\"$saved_state\",\"current_state\":\"$current_state\",\"result\":\"$result\",\"operation_success\":$operation_success}"
            fi
        done < <(echo "$vm_states" | jq -c '.[]')
    else
        log "WARN" "virsh not available, skipping VM restoration"
    fi

    vms_json+="]"
    echo "$vms_json|$successful|$failed"
}

# Verify restoration
verify_restoration() {
    local container_results="$1"
    local vm_results="$2"

    local container_successful=$(echo "$container_results" | cut -d'|' -f2)
    local container_failed=$(echo "$container_results" | cut -d'|' -f3)
    local vm_successful=$(echo "$vm_results" | cut -d'|' -f2)
    local vm_failed=$(echo "$vm_results" | cut -d'|' -f3)

    local total_successful=$((container_successful + vm_successful))
    local total_failed=$((container_failed + vm_failed))

    if [[ "$total_failed" -eq 0 ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# Main function
main() {
    # Check arguments
    if [[ $# -ne 1 ]]; then
        error_exit "Usage: $0 <state_file>"
    fi

    local state_file="$1"

    log "INFO" "Restoring service states from: $state_file"

    # Validate state file
    validate_state_file "$state_file"

    # Read state file
    local state_json=$(cat "$state_file")
    local gpu_address=$(echo "$state_json" | jq -r '.gpu_address')
    local timestamp=$(echo "$state_json" | jq -r '.timestamp')
    local container_states=$(echo "$state_json" | jq '.containers')
    local vm_states=$(echo "$state_json" | jq '.vms')

    log "INFO" "State file info: gpu_address=$gpu_address, timestamp=$timestamp"

    # Restore container states
    log "INFO" "Restoring container states"
    local container_results=$(restore_container_states "$container_states")
    local containers_json=$(echo "$container_results" | cut -d'|' -f1)

    # Restore VM states
    log "INFO" "Restoring VM states"
    local vm_results=$(restore_vm_states "$vm_states")
    local vms_json=$(echo "$vm_results" | cut -d'|' -f1)

    # Verify restoration
    local restoration_success=$(verify_restoration "$container_results" "$vm_results")

    # Get counts
    local container_successful=$(echo "$container_results" | cut -d'|' -f2)
    local container_failed=$(echo "$container_results" | cut -d'|' -f3)
    local vm_successful=$(echo "$vm_results" | cut -d'|' -f2)
    local vm_failed=$(echo "$vm_results" | cut -d'|' -f3)

    local total_successful=$((container_successful + vm_successful))
    local total_failed=$((container_failed + vm_failed))

    # Success
    echo '{"success":true,"message":"Service states restored successfully","state_file":"'"$state_file"'","gpu_address":"'"$gpu_address"'","containers":'"$containers_json"',"vms":'"$vms_json"',"total_successful":'"$total_successful"',"total_failed":'"$total_failed"',"restoration_success":'"$restoration_success"',"timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}}' | jq .
}

# Run main function
main "$@"