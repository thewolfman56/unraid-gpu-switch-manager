#!/bin/bash

# coordinate_services_for_event.sh
# Coordinate services for GPU switching events
# Usage: ./coordinate_services_for_event.sh <event_type> <event_data_json>

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source secure shell library
source "$SCRIPT_DIR/secure_shell_lib.sh"

STATE_DIR="/var/lib/gpu-switch-manager/states"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    secure_log "$level" "[COORDINATE_SERVICES] $message"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    secure_error_exit "$1"
}

# Validate event type
validate_event_type() {
    local event_type="$1"

    case "$event_type" in
        vm_start|vm_stop|docker_start|docker_stop|manual_switch)
            return 0
            ;;
        *)
            error_exit "Invalid event type: $event_type"
            ;;
    esac
}

# Parse event data JSON
parse_event_data() {
    local event_data_json="$1"

    # Validate JSON
    if ! echo "$event_data_json" | jq . &>/dev/null; then
        error_exit "Invalid event data JSON"
    fi

    echo "$event_data_json"
}

# Identify affected services
identify_affected_services() {
    local event_type="$1"
    local event_data="$2"

    log "INFO" "Identifying affected services for event: $event_type"

    local affected_services='[]'

    case "$event_type" in
        vm_start)
            local vm_name=$(echo "$event_data" | jq -r '.vm_name')

            # Get GPU-dependent Docker containers
            if [[ -f "$SCRIPT_DIR/check_service_dependencies.sh" ]]; then
                local dependencies=$("$SCRIPT_DIR/check_service_dependencies.sh" "01:00.0" 2>&1)

                if echo "$dependencies" | jq -e '.gpu_dependent_containers' &>/dev/null; then
                    affected_services=$(echo "$dependencies" | jq '.gpu_dependent_containers | map({service_name: ., service_type: "docker", action: "stop"})')
                fi
            fi
            ;;
        vm_stop)
            local vm_name=$(echo "$event_data" | jq -r '.vm_name')

            # Get previously stopped Docker containers
            local state_file="$STATE_DIR/vm_${vm_name}_services.json"

            if [[ -f "$state_file" ]]; then
                affected_services=$(cat "$state_file" | jq '.services | map({service_name: .name, service_type: .type, action: "start"})')
            fi
            ;;
        docker_start)
            local container_name=$(echo "$event_data" | jq -r '.container_name')

            # Check for VM conflicts
            if command -v virsh &> /dev/null; then
                local running_vms=$(virsh list --name --state-running 2>/dev/null || echo "")

                while IFS= read -r vm; do
                    if [[ -n "$vm" ]]; then
                        if [[ -f "$SCRIPT_DIR/check_vm_gpu_requirements.sh" ]]; then
                            local vm_gpu=$("$SCRIPT_DIR/check_vm_gpu_requirements.sh" "$vm" 2>&1)

                            if echo "$vm_gpu" | jq -e '.has_gpu' &>/dev/null && [[ $(echo "$vm_gpu" | jq -r '.has_gpu') == "true" ]]; then
                                affected_services=$(echo "$affected_services" | jq --arg vm "$vm" '. + [{service_name: $vm, service_type: "vm", action: "stop"}]')
                            fi
                        fi
                    fi
                done <<< "$running_vms"
            fi
            ;;
        docker_stop)
            # No specific services to coordinate for Docker stop
            ;;
        manual_switch)
            local gpu_address=$(echo "$event_data" | jq -r '.gpu_address')
            local action=$(echo "$event_data" | jq -r '.action')

            # Get GPU-dependent services
            if [[ -f "$SCRIPT_DIR/check_service_dependencies.sh" ]]; then
                local dependencies=$("$SCRIPT_DIR/check_service_dependencies.sh" "$gpu_address" 2>&1)

                if echo "$dependencies" | jq -e '.gpu_dependent_containers' &>/dev/null; then
                    local container_action="stop"
                    if [[ "$action" == "unbind_from_vfio" ]]; then
                        container_action="start"
                    fi
                    affected_services=$(echo "$dependencies" | jq '.gpu_dependent_containers | map({service_name: ., service_type: "docker", action: "'"$container_action"'})')
                fi

                if echo "$dependencies" | jq -e '.gpu_dependent_vms' &>/dev/null; then
                    local vm_action="stop"
                    if [[ "$action" == "unbind_from_vfio" ]]; then
                        vm_action="start"
                    fi
                    local vm_services=$(echo "$dependencies" | jq '.gpu_dependent_vms | map({service_name: ., service_type: "vm", action: "'"$vm_action"'})')
                    affected_services=$(echo "$affected_services" | jq --argjson vm_services "$vm_services" '. + $vm_services')
                fi
            fi
            ;;
    esac

    echo '{"affected_services":'"$affected_services"'}'
}

# Determine service operation order
determine_operation_order() {
    local affected_services="$1"

    log "INFO" "Determining service operation order"

    # Order: VMs first, then Docker containers
    local ordered_services='[]'

    # Add VMs first
    local vms=$(echo "$affected_services" | jq '[.[] | select(.service_type == "vm")]')
    ordered_services=$(echo "$ordered_services" | jq --argjson vms "$vms" '. + $vms')

    # Add Docker containers
    local containers=$(echo "$affected_services" | jq '[.[] | select(.service_type == "docker")]')
    ordered_services=$(echo "$ordered_services" | jq --argjson containers "$containers" '. + $containers')

    echo '{"ordered_services":'"$ordered_services"'}'
}

# Execute service operations
execute_service_operations() {
    local ordered_services="$1"

    log "INFO" "Executing service operations"

    local operation_results='[]'
    local all_success=true

    while IFS= read -r service; do
        if [[ -n "$service" ]]; then
            local service_name=$(echo "$service" | jq -r '.service_name')
            local service_type=$(echo "$service" | jq -r '.service_type')
            local action=$(echo "$service" | jq -r '.action')

            log "INFO" "Executing service operation: service=$service_name, type=$service_type, action=$action"

            local result=""
            local success=false

            case "$service_type" in
                docker)
                    if [[ -f "$SCRIPT_DIR/manage_docker_containers.sh" ]]; then
                        result=$("$SCRIPT_DIR/manage_docker_containers.sh" "$action" "$service_name" 2>&1)

                        if echo "$result" | jq -e '.success' &>/dev/null && [[ $(echo "$result" | jq -r '.success') == "true" ]]; then
                            success=true
                        fi
                    fi
                    ;;
                vm)
                    if [[ -f "$SCRIPT_DIR/manage_vm_services.sh" ]]; then
                        result=$("$SCRIPT_DIR/manage_vm_services.sh" "$action" "$service_name" 2>&1)

                        if echo "$result" | jq -e '.success' &>/dev/null && [[ $(echo "$result" | jq -r '.success') == "true" ]]; then
                            success=true
                        fi
                    fi
                    ;;
            esac

            if [[ "$success" != "true" ]]; then
                all_success=false
            fi

            operation_results=$(echo "$operation_results" | jq --arg service_name "$service_name" --arg service_type "$service_type" --arg action "$action" --argjson success "$success" '. + [{service_name: $service_name, service_type: $service_type, action: $action, success: $success}]')
        fi
    done <<< "$(echo "$ordered_services" | jq -c '.[]')"

    echo '{"all_success":'"$all_success"',"operation_results":'"$operation_results"'}'
}

# Verify service states
verify_service_states() {
    local ordered_services="$1"

    log "INFO" "Verifying service states"

    local verification_results='[]'
    local all_verified=true

    while IFS= read -r service; do
        if [[ -n "$service" ]]; then
            local service_name=$(echo "$service" | jq -r '.service_name')
            local service_type=$(echo "$service" | jq -r '.service_type')
            local action=$(echo "$service" | jq -r '.action')

            log "INFO" "Verifying service state: service=$service_name, type=$service_type, action=$action"

            local verified=false
            local current_state="unknown"

            case "$service_type" in
                docker)
                    if command -v docker &> /dev/null; then
                        current_state=$(docker inspect --format='{{.State.Status}}' "$service_name" 2>/dev/null || echo "unknown")

                        case "$action" in
                            start)
                                if [[ "$current_state" == "running" ]]; then
                                    verified=true
                                fi
                                ;;
                            stop)
                                if [[ "$current_state" == "exited" ]] || [[ "$current_state" == "created" ]]; then
                                    verified=true
                                fi
                                ;;
                        esac
                    fi
                    ;;
                vm)
                    if command -v virsh &> /dev/null; then
                        current_state=$(virsh domstate "$service_name" 2>/dev/null || echo "unknown")

                        case "$action" in
                            start)
                                if [[ "$current_state" == "running" ]]; then
                                    verified=true
                                fi
                                ;;
                            stop)
                                if [[ "$current_state" == "shut off" ]]; then
                                    verified=true
                                fi
                                ;;
                        esac
                    fi
                    ;;
            esac

            if [[ "$verified" != "true" ]]; then
                all_verified=false
            fi

            verification_results=$(echo "$verification_results" | jq --arg service_name "$service_name" --arg service_type "$service_type" --arg action "$action" --argjson verified "$verified" --arg current_state "$current_state" '. + [{service_name: $service_name, service_type: $service_type, action: $action, verified: $verified, current_state: $current_state}]')
        fi
    done <<< "$(echo "$ordered_services" | jq -c '.[]')"

    echo '{"all_verified":'"$all_verified"',"verification_results":'"$verification_results"'}'
}

# Save service coordination state
save_coordination_state() {
    local event_type="$1"
    local event_data="$2"
    local ordered_services="$3"

    log "INFO" "Saving service coordination state"

    # Create state directory
    mkdir -p "$STATE_DIR"

    # Create state file
    local state_file="$STATE_DIR/coordination_${event_type}_$(date +%s).json"

    echo '{"event_type":"'"$event_type"'","event_data":'"$event_data"',"services":'"$ordered_services"',"timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}}' > "$state_file"

    log "INFO" "Coordination state saved to: $state_file"
    echo "$state_file"
}

# Main function
main() {
    # Check arguments
    if [[ $# -lt 2 ]]; then
        error_exit "Usage: $0 <event_type> <event_data_json>"
    fi

    local event_type="$1"
    local event_data_json="$2"

    log "INFO" "Coordinating services for event: event_type=$event_type"

    # Validate event type
    validate_event_type "$event_type"

    # Parse event data
    local event_data=$(parse_event_data "$event_data_json")

    # Identify affected services
    local affected_services=$(identify_affected_services "$event_type" "$event_data")

    # Determine operation order
    local operation_order=$(determine_operation_order "$(echo "$affected_services" | jq -c '.affected_services')")
    local ordered_services=$(echo "$operation_order" | jq -c '.ordered_services')

    # Save coordination state
    local state_file=$(save_coordination_state "$event_type" "$event_data" "$ordered_services")

    # Execute service operations
    local operations=$(execute_service_operations "$ordered_services")
    local all_success=$(echo "$operations" | jq -r '.all_success')

    # Verify service states
    local verification=$(verify_service_states "$ordered_services")
    local all_verified=$(echo "$verification" | jq -r '.all_verified')

    # Build JSON output
    local json_output='{"success":'"$all_success"',"event_type":"'"$event_type"'","affected_services":'"$affected_services"',"operation_order":'"$operation_order"',"operations":'"$operations"',"verification":'"$verification"',"state_file":"'"$state_file"'","timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}}'

    log "INFO" "Service coordination completed: all_success=$all_success, all_verified=$all_verified"

    echo "$json_output" | jq .
}

# Run main function
main "$@"