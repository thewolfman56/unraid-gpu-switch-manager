#!/bin/bash

# validate_phase4.sh
# Validation script for Phase 4: Event Handlers
# Tests all event handler functionality

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test functions
test_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    PASSED_TESTS=$((PASSED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

test_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    FAILED_TESTS=$((FAILED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

test_info() {
    echo -e "${YELLOW}ℹ INFO${NC}: $1"
}

# Check if file exists
file_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        test_pass "$file exists"
        return 0
    else
        test_fail "$file does not exist"
        return 1
    fi
}

# Check if file is executable
file_executable() {
    local file="$1"
    if [[ -x "$file" ]]; then
        test_pass "$file is executable"
        return 0
    else
        test_fail "$file is not executable"
        return 1
    fi
}

# Check if file has shebang
file_has_shebang() {
    local file="$1"
    if head -1 "$file" | grep -q '#!'; then
        test_pass "$file has shebang"
        return 0
    else
        test_fail "$file does not have shebang"
        return 1
    fi
}

# Check if file contains specific content
file_contains() {
    local file="$1"
    local content="$2"
    if grep -q "$content" "$file"; then
        test_pass "$file contains '$content'"
        return 0
    else
        test_fail "$file does not contain '$content'"
        return 1
    fi
}

# Check PHP syntax
check_php_syntax() {
    local file="$1"
    local php_paths=(
        "/c/Users/steph/AppData/Local/Microsoft/WinGet/Packages/PHP.PHP.8.2_Microsoft.Winget.Source_8wekyb3d8bbwe/php.exe"
        "/usr/bin/php"
        "/usr/local/bin/php"
        "php"
    )

    for php_path in "${php_paths[@]}"; do
        if [[ -x "$php_path" ]] || command -v "$php_path" &>/dev/null; then
            if "$php_path" -l "$file" 2>&1 | grep -q "No syntax errors"; then
                test_pass "$file has valid PHP syntax"
                return 0
            else
                test_fail "$file has PHP syntax errors"
                return 1
            fi
        fi
    done

    test_info "PHP not found for syntax check of $file"
    return 0
}

# Main validation
echo "=========================================="
echo "GPU Switch Manager Phase 4 Validation"
echo "=========================================="
echo ""
echo "Testing in: $PROJECT_DIR"
echo ""

# VM Event Handlers
echo "VM Event Handlers:"
file_exists "$PROJECT_DIR/scripts/vm_start_handler.sh"
file_exists "$PROJECT_DIR/scripts/vm_stop_handler.sh"
file_exists "$PROJECT_DIR/scripts/vm_lifecycle_hooks.sh"
file_exists "$PROJECT_DIR/scripts/check_vm_gpu_requirements.sh"
echo ""

# Docker Event Hooks
echo "Docker Event Hooks:"
file_exists "$PROJECT_DIR/scripts/docker_event_monitor.sh"
file_exists "$PROJECT_DIR/scripts/docker_start_handler.sh"
file_exists "$PROJECT_DIR/scripts/docker_stop_handler.sh"
file_exists "$PROJECT_DIR/scripts/check_container_gpu_requirements.sh"
echo ""

# Automatic GPU Switching
echo "Automatic GPU Switching:"
file_exists "$PROJECT_DIR/scripts/auto_gpu_switch.sh"
file_exists "$PROJECT_DIR/scripts/determine_switching_action.sh"
file_exists "$PROJECT_DIR/scripts/validate_switching_safety.sh"
file_exists "$PROJECT_DIR/scripts/execute_gpu_switch.sh"
echo ""

# Service Coordination
echo "Service Coordination:"
file_exists "$PROJECT_DIR/scripts/coordinate_services_for_event.sh"
file_exists "$PROJECT_DIR/scripts/prepare_for_gpu_switch.sh"
file_exists "$PROJECT_DIR/scripts/cleanup_after_gpu_switch.sh"
file_exists "$PROJECT_DIR/scripts/rollback_gpu_switch.sh"
echo ""

# Unraid Event Integration
echo "Unraid Event Integration:"
file_exists "$PROJECT_DIR/scripts/unraid_event_handler.sh"
file_exists "$PROJECT_DIR/scripts/register_event_handlers.sh"
file_exists "$PROJECT_DIR/scripts/unregister_event_handlers.sh"
file_exists "$PROJECT_DIR/scripts/event_logger.sh"
echo ""

# PHP Class
echo "PHP Class:"
file_exists "$PROJECT_DIR/include/GPUManager.php"
echo ""

# Script Permissions
echo "Script Permissions:"
file_executable "$PROJECT_DIR/scripts/vm_start_handler.sh"
file_executable "$PROJECT_DIR/scripts/vm_stop_handler.sh"
file_executable "$PROJECT_DIR/scripts/vm_lifecycle_hooks.sh"
file_executable "$PROJECT_DIR/scripts/check_vm_gpu_requirements.sh"
file_executable "$PROJECT_DIR/scripts/docker_event_monitor.sh"
file_executable "$PROJECT_DIR/scripts/docker_start_handler.sh"
file_executable "$PROJECT_DIR/scripts/docker_stop_handler.sh"
file_executable "$PROJECT_DIR/scripts/check_container_gpu_requirements.sh"
file_executable "$PROJECT_DIR/scripts/auto_gpu_switch.sh"
file_executable "$PROJECT_DIR/scripts/determine_switching_action.sh"
file_executable "$PROJECT_DIR/scripts/validate_switching_safety.sh"
file_executable "$PROJECT_DIR/scripts/execute_gpu_switch.sh"
file_executable "$PROJECT_DIR/scripts/coordinate_services_for_event.sh"
file_executable "$PROJECT_DIR/scripts/prepare_for_gpu_switch.sh"
file_executable "$PROJECT_DIR/scripts/cleanup_after_gpu_switch.sh"
file_executable "$PROJECT_DIR/scripts/rollback_gpu_switch.sh"
file_executable "$PROJECT_DIR/scripts/unraid_event_handler.sh"
file_executable "$PROJECT_DIR/scripts/register_event_handlers.sh"
file_executable "$PROJECT_DIR/scripts/unregister_event_handlers.sh"
file_executable "$PROJECT_DIR/scripts/event_logger.sh"
echo ""

# Script Content
echo "Script Content:"
file_has_shebang "$PROJECT_DIR/scripts/vm_start_handler.sh"
file_has_shebang "$PROJECT_DIR/scripts/vm_stop_handler.sh"
file_has_shebang "$PROJECT_DIR/scripts/vm_lifecycle_hooks.sh"
file_has_shebang "$PROJECT_DIR/scripts/check_vm_gpu_requirements.sh"
file_has_shebang "$PROJECT_DIR/scripts/docker_event_monitor.sh"
file_has_shebang "$PROJECT_DIR/scripts/docker_start_handler.sh"
file_has_shebang "$PROJECT_DIR/scripts/docker_stop_handler.sh"
file_has_shebang "$PROJECT_DIR/scripts/check_container_gpu_requirements.sh"
file_has_shebang "$PROJECT_DIR/scripts/auto_gpu_switch.sh"
file_has_shebang "$PROJECT_DIR/scripts/determine_switching_action.sh"
file_has_shebang "$PROJECT_DIR/scripts/validate_switching_safety.sh"
file_has_shebang "$PROJECT_DIR/scripts/execute_gpu_switch.sh"
file_has_shebang "$PROJECT_DIR/scripts/coordinate_services_for_event.sh"
file_has_shebang "$PROJECT_DIR/scripts/prepare_for_gpu_switch.sh"
file_has_shebang "$PROJECT_DIR/scripts/cleanup_after_gpu_switch.sh"
file_has_shebang "$PROJECT_DIR/scripts/rollback_gpu_switch.sh"
file_has_shebang "$PROJECT_DIR/scripts/unraid_event_handler.sh"
file_has_shebang "$PROJECT_DIR/scripts/register_event_handlers.sh"
file_has_shebang "$PROJECT_DIR/scripts/unregister_event_handlers.sh"
file_has_shebang "$PROJECT_DIR/scripts/event_logger.sh"
echo ""

# Script Safety
echo "Script Safety:"
file_contains "$PROJECT_DIR/scripts/vm_start_handler.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/vm_stop_handler.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/vm_lifecycle_hooks.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/check_vm_gpu_requirements.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/docker_event_monitor.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/docker_start_handler.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/docker_stop_handler.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/check_container_gpu_requirements.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/auto_gpu_switch.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/determine_switching_action.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/validate_switching_safety.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/execute_gpu_switch.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/coordinate_services_for_event.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/prepare_for_gpu_switch.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/cleanup_after_gpu_switch.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/rollback_gpu_switch.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/unraid_event_handler.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/register_event_handlers.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/unregister_event_handlers.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/event_logger.sh" "set -euo pipefail"
echo ""

# Script Functionality
echo "Script Functionality:"
file_contains "$PROJECT_DIR/scripts/vm_start_handler.sh" "main()"
file_contains "$PROJECT_DIR/scripts/vm_stop_handler.sh" "main()"
file_contains "$PROJECT_DIR/scripts/vm_lifecycle_hooks.sh" "main()"
file_contains "$PROJECT_DIR/scripts/check_vm_gpu_requirements.sh" "main()"
file_contains "$PROJECT_DIR/scripts/docker_event_monitor.sh" "main()"
file_contains "$PROJECT_DIR/scripts/docker_start_handler.sh" "main()"
file_contains "$PROJECT_DIR/scripts/docker_stop_handler.sh" "main()"
file_contains "$PROJECT_DIR/scripts/check_container_gpu_requirements.sh" "main()"
file_contains "$PROJECT_DIR/scripts/auto_gpu_switch.sh" "main()"
file_contains "$PROJECT_DIR/scripts/determine_switching_action.sh" "main()"
file_contains "$PROJECT_DIR/scripts/validate_switching_safety.sh" "main()"
file_contains "$PROJECT_DIR/scripts/execute_gpu_switch.sh" "main()"
file_contains "$PROJECT_DIR/scripts/coordinate_services_for_event.sh" "main()"
file_contains "$PROJECT_DIR/scripts/prepare_for_gpu_switch.sh" "main()"
file_contains "$PROJECT_DIR/scripts/cleanup_after_gpu_switch.sh" "main()"
file_contains "$PROJECT_DIR/scripts/rollback_gpu_switch.sh" "main()"
file_contains "$PROJECT_DIR/scripts/unraid_event_handler.sh" "main()"
file_contains "$PROJECT_DIR/scripts/register_event_handlers.sh" "main()"
file_contains "$PROJECT_DIR/scripts/unregister_event_handlers.sh" "main()"
file_contains "$PROJECT_DIR/scripts/event_logger.sh" "main()"
echo ""

# PHP Class Structure
echo "PHP Class Structure:"
file_contains "$PROJECT_DIR/include/GPUManager.php" "handleVMStartEvent"
file_contains "$PROJECT_DIR/include/GPUManager.php" "handleVMStopEvent"
file_contains "$PROJECT_DIR/include/GPUManager.php" "handleDockerStartEvent"
file_contains "$PROJECT_DIR/include/GPUManager.php" "handleDockerStopEvent"
file_contains "$PROJECT_DIR/include/GPUManager.php" "determineSwitchingAction"
file_contains "$PROJECT_DIR/include/GPUManager.php" "validateSwitchingSafety"
file_contains "$PROJECT_DIR/include/GPUManager.php" "executeAutoSwitch"
file_contains "$PROJECT_DIR/include/GPUManager.php" "coordinateServicesForEvent"
file_contains "$PROJECT_DIR/include/GPUManager.php" "getEventHistory"
file_contains "$PROJECT_DIR/include/GPUManager.php" "getActiveSwitchingOperations"
file_contains "$PROJECT_DIR/include/GPUManager.php" "cancelSwitchingOperation"
file_contains "$PROJECT_DIR/include/GPUManager.php" "getEventHandlerStatus"
echo ""

# PHP Class Features
echo "PHP Class Features:"
file_contains "$PROJECT_DIR/include/GPUManager.php" "public function handleVMStartEvent"
file_contains "$PROJECT_DIR/include/GPUManager.php" "public function handleVMStopEvent"
file_contains "$PROJECT_DIR/include/GPUManager.php" "public function handleDockerStartEvent"
file_contains "$PROJECT_DIR/include/GPUManager.php" "public function handleDockerStopEvent"
file_contains "$PROJECT_DIR/include/GPUManager.php" "public function determineSwitchingAction"
file_contains "$PROJECT_DIR/include/GPUManager.php" "public function validateSwitchingSafety"
file_contains "$PROJECT_DIR/include/GPUManager.php" "public function executeAutoSwitch"
file_contains "$PROJECT_DIR/include/GPUManager.php" "public function coordinateServicesForEvent"
file_contains "$PROJECT_DIR/include/GPUManager.php" "public function getEventHistory"
file_contains "$PROJECT_DIR/include/GPUManager.php" "public function getActiveSwitchingOperations"
file_contains "$PROJECT_DIR/include/GPUManager.php" "public function cancelSwitchingOperation"
file_contains "$PROJECT_DIR/include/GPUManager.php" "public function getEventHandlerStatus"
echo ""

# JSON Output Format
echo "JSON Output Format:"
file_contains "$PROJECT_DIR/scripts/vm_start_handler.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/vm_stop_handler.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/vm_lifecycle_hooks.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/check_vm_gpu_requirements.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/docker_event_monitor.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/docker_start_handler.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/docker_stop_handler.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/check_container_gpu_requirements.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/auto_gpu_switch.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/determine_switching_action.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/validate_switching_safety.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/execute_gpu_switch.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/coordinate_services_for_event.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/prepare_for_gpu_switch.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/cleanup_after_gpu_switch.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/rollback_gpu_switch.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/unraid_event_handler.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/register_event_handlers.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/unregister_event_handlers.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/event_logger.sh" "jq ."
echo ""

# Error Handling
echo "Error Handling:"
file_contains "$PROJECT_DIR/scripts/vm_start_handler.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/vm_stop_handler.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/vm_lifecycle_hooks.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/check_vm_gpu_requirements.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/docker_event_monitor.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/docker_start_handler.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/docker_stop_handler.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/check_container_gpu_requirements.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/auto_gpu_switch.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/determine_switching_action.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/validate_switching_safety.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/execute_gpu_switch.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/coordinate_services_for_event.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/prepare_for_gpu_switch.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/cleanup_after_gpu_switch.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/rollback_gpu_switch.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/unraid_event_handler.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/register_event_handlers.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/unregister_event_handlers.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/event_logger.sh" "error_exit"
file_contains "$PROJECT_DIR/include/GPUManager.php" "throw new Exception"
echo ""

# Input Validation
echo "Input Validation:"
file_contains "$PROJECT_DIR/scripts/vm_start_handler.sh" "validate_vm_name"
file_contains "$PROJECT_DIR/scripts/vm_stop_handler.sh" "validate_vm_name"
file_contains "$PROJECT_DIR/scripts/check_vm_gpu_requirements.sh" "validate_vm_name"
file_contains "$PROJECT_DIR/scripts/docker_start_handler.sh" "validate_container_name"
file_contains "$PROJECT_DIR/scripts/docker_stop_handler.sh" "validate_container_name"
file_contains "$PROJECT_DIR/scripts/check_container_gpu_requirements.sh" "validate_container_name"
file_contains "$PROJECT_DIR/scripts/auto_gpu_switch.sh" "validate_event_type"
file_contains "$PROJECT_DIR/scripts/determine_switching_action.sh" "validate_event_type"
file_contains "$PROJECT_DIR/scripts/validate_switching_safety.sh" "validate_action"
file_contains "$PROJECT_DIR/scripts/execute_gpu_switch.sh" "validate_action"
file_contains "$PROJECT_DIR/scripts/prepare_for_gpu_switch.sh" "validate_action"
file_contains "$PROJECT_DIR/scripts/cleanup_after_gpu_switch.sh" "validate_action"
file_contains "$PROJECT_DIR/scripts/rollback_gpu_switch.sh" "validate_action"
file_contains "$PROJECT_DIR/scripts/unraid_event_handler.sh" "validate_event_type"
file_contains "$PROJECT_DIR/scripts/register_event_handlers.sh" "check_root"
file_contains "$PROJECT_DIR/scripts/unregister_event_handlers.sh" "check_root"
file_contains "$PROJECT_DIR/scripts/event_logger.sh" "validate_log_level"
file_contains "$PROJECT_DIR/include/GPUManager.php" "validateGPUAddress"
echo ""

# Logging
echo "Logging:"
file_contains "$PROJECT_DIR/scripts/vm_start_handler.sh" "log()"
file_contains "$PROJECT_DIR/scripts/vm_stop_handler.sh" "log()"
file_contains "$PROJECT_DIR/scripts/vm_lifecycle_hooks.sh" "log()"
file_contains "$PROJECT_DIR/scripts/check_vm_gpu_requirements.sh" "log()"
file_contains "$PROJECT_DIR/scripts/docker_event_monitor.sh" "log()"
file_contains "$PROJECT_DIR/scripts/docker_start_handler.sh" "log()"
file_contains "$PROJECT_DIR/scripts/docker_stop_handler.sh" "log()"
file_contains "$PROJECT_DIR/scripts/check_container_gpu_requirements.sh" "log()"
file_contains "$PROJECT_DIR/scripts/auto_gpu_switch.sh" "log()"
file_contains "$PROJECT_DIR/scripts/determine_switching_action.sh" "log()"
file_contains "$PROJECT_DIR/scripts/validate_switching_safety.sh" "log()"
file_contains "$PROJECT_DIR/scripts/execute_gpu_switch.sh" "log()"
file_contains "$PROJECT_DIR/scripts/coordinate_services_for_event.sh" "log()"
file_contains "$PROJECT_DIR/scripts/prepare_for_gpu_switch.sh" "log()"
file_contains "$PROJECT_DIR/scripts/cleanup_after_gpu_switch.sh" "log()"
file_contains "$PROJECT_DIR/scripts/rollback_gpu_switch.sh" "log()"
file_contains "$PROJECT_DIR/scripts/unraid_event_handler.sh" "log()"
file_contains "$PROJECT_DIR/scripts/register_event_handlers.sh" "log()"
file_contains "$PROJECT_DIR/scripts/unregister_event_handlers.sh" "log()"
file_contains "$PROJECT_DIR/scripts/event_logger.sh" "log()"
file_contains "$PROJECT_DIR/include/GPUManager.php" "private function log"
echo ""

# Event Integration
echo "Event Integration:"
file_contains "$PROJECT_DIR/scripts/vm_start_handler.sh" "virsh"
file_contains "$PROJECT_DIR/scripts/vm_stop_handler.sh" "virsh"
file_contains "$PROJECT_DIR/scripts/check_vm_gpu_requirements.sh" "virsh"
file_contains "$PROJECT_DIR/scripts/docker_event_monitor.sh" "docker events"
file_contains "$PROJECT_DIR/scripts/docker_start_handler.sh" "docker"
file_contains "$PROJECT_DIR/scripts/docker_stop_handler.sh" "docker"
file_contains "$PROJECT_DIR/scripts/check_container_gpu_requirements.sh" "docker"
file_contains "$PROJECT_DIR/scripts/unraid_event_handler.sh" "array_start"
file_contains "$PROJECT_DIR/scripts/unraid_event_handler.sh" "array_stop"
file_contains "$PROJECT_DIR/scripts/register_event_handlers.sh" "event_handlers"
file_contains "$PROJECT_DIR/scripts/unregister_event_handlers.sh" "event_handlers"
echo ""

# Safety Checks
echo "Safety Checks:"
file_contains "$PROJECT_DIR/scripts/validate_switching_safety.sh" "check_active_gpu_usage"
file_contains "$PROJECT_DIR/scripts/validate_switching_safety.sh" "check_service_dependencies"
file_contains "$PROJECT_DIR/scripts/validate_switching_safety.sh" "check_resource_availability"
file_contains "$PROJECT_DIR/scripts/validate_switching_safety.sh" "check_conflicts"
file_contains "$PROJECT_DIR/scripts/validate_switching_safety.sh" "validate_system_stability"
file_contains "$PROJECT_DIR/scripts/execute_gpu_switch.sh" "verify_switching_result"
file_contains "$PROJECT_DIR/scripts/execute_gpu_switch.sh" "rollback_switching"
file_contains "$PROJECT_DIR/scripts/rollback_gpu_switch.sh" "restore_previous_driver"
echo ""

# PHP Syntax
echo "PHP Syntax:"
check_php_syntax "$PROJECT_DIR/include/GPUManager.php"
echo ""

# Summary
echo "=========================================="
echo "Validation Summary"
echo "=========================================="
echo "Total Tests: $TOTAL_TESTS"
echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
echo -e "${RED}Failed: $FAILED_TESTS${NC}"
echo ""

if [[ $FAILED_TESTS -eq 0 ]]; then
    echo -e "${GREEN}✓ All tests passed! Phase 4 is complete.${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Please review the failures above.${NC}"
    exit 1
fi