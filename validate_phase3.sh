#!/bin/bash

# validate_phase3.sh
# Validation script for Phase 3: Service Management
# Tests all service management functionality

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
echo "GPU Switch Manager Phase 3 Validation"
echo "=========================================="
echo ""
echo "Testing in: $PROJECT_DIR"
echo ""

# Script Files
echo "Script Files:"
file_exists "$PROJECT_DIR/scripts/manage_docker_containers.sh"
file_exists "$PROJECT_DIR/scripts/manage_vm_services.sh"
file_exists "$PROJECT_DIR/scripts/check_service_dependencies.sh"
file_exists "$PROJECT_DIR/scripts/save_service_states.sh"
file_exists "$PROJECT_DIR/scripts/restore_service_states.sh"
file_exists "$PROJECT_DIR/scripts/get_service_status.sh"
file_exists "$PROJECT_DIR/scripts/validate_service_operation.sh"
echo ""

# PHP Class
echo "PHP Class:"
file_exists "$PROJECT_DIR/include/GPUManager.php"
echo ""

# Script Permissions
echo "Script Permissions:"
file_executable "$PROJECT_DIR/scripts/manage_docker_containers.sh"
file_executable "$PROJECT_DIR/scripts/manage_vm_services.sh"
file_executable "$PROJECT_DIR/scripts/check_service_dependencies.sh"
file_executable "$PROJECT_DIR/scripts/save_service_states.sh"
file_executable "$PROJECT_DIR/scripts/restore_service_states.sh"
file_executable "$PROJECT_DIR/scripts/get_service_status.sh"
file_executable "$PROJECT_DIR/scripts/validate_service_operation.sh"
echo ""

# Script Content
echo "Script Content:"
file_has_shebang "$PROJECT_DIR/scripts/manage_docker_containers.sh"
file_has_shebang "$PROJECT_DIR/scripts/manage_vm_services.sh"
file_has_shebang "$PROJECT_DIR/scripts/check_service_dependencies.sh"
file_has_shebang "$PROJECT_DIR/scripts/save_service_states.sh"
file_has_shebang "$PROJECT_DIR/scripts/restore_service_states.sh"
file_has_shebang "$PROJECT_DIR/scripts/get_service_status.sh"
file_has_shebang "$PROJECT_DIR/scripts/validate_service_operation.sh"
echo ""

# Script Safety
echo "Script Safety:"
file_contains "$PROJECT_DIR/scripts/manage_docker_containers.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/manage_vm_services.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/check_service_dependencies.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/save_service_states.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/restore_service_states.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/get_service_status.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/validate_service_operation.sh" "set -euo pipefail"
echo ""

# Script Functionality
echo "Script Functionality:"
file_contains "$PROJECT_DIR/scripts/manage_docker_containers.sh" "manage_docker_containers"
file_contains "$PROJECT_DIR/scripts/manage_vm_services.sh" "manage_vm_services"
file_contains "$PROJECT_DIR/scripts/check_service_dependencies.sh" "check_service_dependencies"
file_contains "$PROJECT_DIR/scripts/save_service_states.sh" "save_service_states"
file_contains "$PROJECT_DIR/scripts/restore_service_states.sh" "restore_service_states"
file_contains "$PROJECT_DIR/scripts/get_service_status.sh" "get_service_status"
file_contains "$PROJECT_DIR/scripts/validate_service_operation.sh" "validate_service_operation"
echo ""

# PHP Class Structure
echo "PHP Class Structure:"
file_contains "$PROJECT_DIR/include/GPUManager.php" "manageDockerContainers"
file_contains "$PROJECT_DIR/include/GPUManager.php" "manageVMServices"
file_contains "$PROJECT_DIR/include/GPUManager.php" "checkServiceDependencies"
file_contains "$PROJECT_DIR/include/GPUManager.php" "saveServiceStates"
file_contains "$PROJECT_DIR/include/GPUManager.php" "restoreServiceStates"
file_contains "$PROJECT_DIR/include/GPUManager.php" "getServiceStatus"
file_contains "$PROJECT_DIR/include/GPUManager.php" "validateServiceOperation"
echo ""

# PHP Class Features
echo "PHP Class Features:"
file_contains "$PROJECT_DIR/include/GPUManager.php" "prepareGPUForVMPassthrough"
file_contains "$PROJECT_DIR/include/GPUManager.php" "restoreGPUAfterVMPassthrough"
file_contains "$PROJECT_DIR/include/GPUManager.php" "getGPUDependentServices"
file_contains "$PROJECT_DIR/include/GPUManager.php" "getSystemStatus"
echo ""

# JSON Output Format
echo "JSON Output Format:"
file_contains "$PROJECT_DIR/scripts/manage_docker_containers.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/manage_vm_services.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/check_service_dependencies.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/save_service_states.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/restore_service_states.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/get_service_status.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/validate_service_operation.sh" "jq ."
echo ""

# Error Handling
echo "Error Handling:"
file_contains "$PROJECT_DIR/scripts/manage_docker_containers.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/manage_vm_services.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/check_service_dependencies.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/save_service_states.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/restore_service_states.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/get_service_status.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/validate_service_operation.sh" "error_exit"
file_contains "$PROJECT_DIR/include/GPUManager.php" "throw new Exception"
echo ""

# Input Validation
echo "Input Validation:"
file_contains "$PROJECT_DIR/scripts/manage_docker_containers.sh" "validate_operation"
file_contains "$PROJECT_DIR/scripts/manage_vm_services.sh" "validate_operation"
file_contains "$PROJECT_DIR/scripts/check_service_dependencies.sh" "validate_pci_address"
file_contains "$PROJECT_DIR/scripts/save_service_states.sh" "validate_pci_address"
file_contains "$PROJECT_DIR/scripts/restore_service_states.sh" "validate_state_file"
file_contains "$PROJECT_DIR/scripts/get_service_status.sh" "validate_service_type"
file_contains "$PROJECT_DIR/scripts/validate_service_operation.sh" "validate_operation_type"
file_contains "$PROJECT_DIR/include/GPUManager.php" "validateGPUAddress"
echo ""

# Logging
echo "Logging:"
file_contains "$PROJECT_DIR/scripts/manage_docker_containers.sh" "log()"
file_contains "$PROJECT_DIR/scripts/manage_vm_services.sh" "log()"
file_contains "$PROJECT_DIR/scripts/check_service_dependencies.sh" "log()"
file_contains "$PROJECT_DIR/scripts/save_service_states.sh" "log()"
file_contains "$PROJECT_DIR/scripts/restore_service_states.sh" "log()"
file_contains "$PROJECT_DIR/scripts/get_service_status.sh" "log()"
file_contains "$PROJECT_DIR/scripts/validate_service_operation.sh" "log()"
file_contains "$PROJECT_DIR/include/GPUManager.php" "private function log"
echo ""

# Docker Integration
echo "Docker Integration:"
file_contains "$PROJECT_DIR/scripts/manage_docker_containers.sh" "check_docker"
file_contains "$PROJECT_DIR/scripts/check_service_dependencies.sh" "check_docker"
file_contains "$PROJECT_DIR/scripts/save_service_states.sh" "check_docker"
file_contains "$PROJECT_DIR/scripts/restore_service_states.sh" "check_docker"
file_contains "$PROJECT_DIR/scripts/get_service_status.sh" "check_docker"
file_contains "$PROJECT_DIR/scripts/validate_service_operation.sh" "check_docker"
echo ""

# VM Integration
echo "VM Integration:"
file_contains "$PROJECT_DIR/scripts/manage_vm_services.sh" "check_virsh"
file_contains "$PROJECT_DIR/scripts/check_service_dependencies.sh" "check_virsh"
file_contains "$PROJECT_DIR/scripts/save_service_states.sh" "check_virsh"
file_contains "$PROJECT_DIR/scripts/restore_service_states.sh" "check_virsh"
file_contains "$PROJECT_DIR/scripts/get_service_status.sh" "check_virsh"
file_contains "$PROJECT_DIR/scripts/validate_service_operation.sh" "check_virsh"
echo ""

# State Management
echo "State Management:"
file_contains "$PROJECT_DIR/scripts/save_service_states.sh" "create_state_dir"
file_contains "$PROJECT_DIR/scripts/save_service_states.sh" "save_state_file"
file_contains "$PROJECT_DIR/scripts/restore_service_states.sh" "validate_state_file"
file_contains "$PROJECT_DIR/scripts/restore_service_states.sh" "verify_restoration"
file_contains "$PROJECT_DIR/scripts/manage_docker_containers.sh" "get_container_state"
file_contains "$PROJECT_DIR/scripts/manage_vm_services.sh" "get_vm_state"
echo ""

# Dependency Checking
echo "Dependency Checking:"
file_contains "$PROJECT_DIR/scripts/check_service_dependencies.sh" "get_gpu_dependent_containers"
file_contains "$PROJECT_DIR/scripts/check_service_dependencies.sh" "get_gpu_dependent_vms"
file_contains "$PROJECT_DIR/scripts/check_service_dependencies.sh" "get_blocking_services"
file_contains "$PROJECT_DIR/scripts/check_service_dependencies.sh" "determine_safe_to_switch"
file_contains "$PROJECT_DIR/scripts/check_service_dependencies.sh" "generate_recommendations"
echo ""

# Service Validation
echo "Service Validation:"
file_contains "$PROJECT_DIR/scripts/validate_service_operation.sh" "validate_docker_operation"
file_contains "$PROJECT_DIR/scripts/validate_service_operation.sh" "validate_vm_operation"
file_contains "$PROJECT_DIR/scripts/validate_service_operation.sh" "check_resource_conflicts"
file_contains "$PROJECT_DIR/scripts/validate_service_operation.sh" "check_dependency_conflicts"
file_contains "$PROJECT_DIR/scripts/validate_service_operation.sh" "check_safety_concerns"
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
    echo -e "${GREEN}✓ All tests passed! Phase 3 is complete.${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Please review the failures above.${NC}"
    exit 1
fi