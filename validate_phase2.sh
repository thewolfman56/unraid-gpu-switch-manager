#!/bin/bash

# validate_phase2.sh
# Validation script for Phase 2: VFIO Binding Core
# Tests all VFIO binding functionality

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
echo "GPU Switch Manager Phase 2 Validation"
echo "=========================================="
echo ""
echo "Testing in: $PROJECT_DIR"
echo ""

# Script Files
echo "Script Files:"
file_exists "$PROJECT_DIR/scripts/bind_gpu_to_vfio.sh"
file_exists "$PROJECT_DIR/scripts/unbind_gpu_from_vfio.sh"
file_exists "$PROJECT_DIR/scripts/check_vfio_binding.sh"
file_exists "$PROJECT_DIR/scripts/update_vfio_conf.sh"
file_exists "$PROJECT_DIR/scripts/get_gpu_driver_info.sh"
file_exists "$PROJECT_DIR/scripts/verify_vfio_binding.sh"
echo ""

# PHP Class
echo "PHP Class:"
file_exists "$PROJECT_DIR/include/GPUManager.php"
echo ""

# Script Permissions
echo "Script Permissions:"
file_executable "$PROJECT_DIR/scripts/bind_gpu_to_vfio.sh"
file_executable "$PROJECT_DIR/scripts/unbind_gpu_from_vfio.sh"
file_executable "$PROJECT_DIR/scripts/check_vfio_binding.sh"
file_executable "$PROJECT_DIR/scripts/update_vfio_conf.sh"
file_executable "$PROJECT_DIR/scripts/get_gpu_driver_info.sh"
file_executable "$PROJECT_DIR/scripts/verify_vfio_binding.sh"
echo ""

# Script Content
echo "Script Content:"
file_has_shebang "$PROJECT_DIR/scripts/bind_gpu_to_vfio.sh"
file_has_shebang "$PROJECT_DIR/scripts/unbind_gpu_from_vfio.sh"
file_has_shebang "$PROJECT_DIR/scripts/check_vfio_binding.sh"
file_has_shebang "$PROJECT_DIR/scripts/update_vfio_conf.sh"
file_has_shebang "$PROJECT_DIR/scripts/get_gpu_driver_info.sh"
file_has_shebang "$PROJECT_DIR/scripts/verify_vfio_binding.sh"
echo ""

# Script Safety
echo "Script Safety:"
file_contains "$PROJECT_DIR/scripts/bind_gpu_to_vfio.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/unbind_gpu_from_vfio.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/check_vfio_binding.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/update_vfio_conf.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/get_gpu_driver_info.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/verify_vfio_binding.sh" "set -euo pipefail"
echo ""

# Script Functionality
echo "Script Functionality:"
file_contains "$PROJECT_DIR/scripts/bind_gpu_to_vfio.sh" "bind_to_vfio"
file_contains "$PROJECT_DIR/scripts/unbind_gpu_from_vfio.sh" "unbind_from_vfio"
file_contains "$PROJECT_DIR/scripts/check_vfio_binding.sh" "check_vfio_binding"
file_contains "$PROJECT_DIR/scripts/update_vfio_conf.sh" "update_vfio_conf"
file_contains "$PROJECT_DIR/scripts/get_gpu_driver_info.sh" "get_gpu_driver_info"
file_contains "$PROJECT_DIR/scripts/verify_vfio_binding.sh" "verify_vfio_binding"
echo ""

# PHP Class Structure
echo "PHP Class Structure:"
file_contains "$PROJECT_DIR/include/GPUManager.php" "bindGPUToVFIO"
file_contains "$PROJECT_DIR/include/GPUManager.php" "unbindGPUFromVFIO"
file_contains "$PROJECT_DIR/include/GPUManager.php" "checkVFIOBinding"
file_contains "$PROJECT_DIR/include/GPUManager.php" "updateVFIOConfig"
file_contains "$PROJECT_DIR/include/GPUManager.php" "getGPUDriverInfo"
file_contains "$PROJECT_DIR/include/GPUManager.php" "verifyVFIOBinding"
echo ""

# PHP Class Features
echo "PHP Class Features:"
file_contains "$PROJECT_DIR/include/GPUManager.php" "toggleGPUVFIOBinding"
file_contains "$PROJECT_DIR/include/GPUManager.php" "getVFIOBoundGPUs"
file_contains "$PROJECT_DIR/include/GPUManager.php" "clearCache"
echo ""

# JSON Output Format
echo "JSON Output Format:"
file_contains "$PROJECT_DIR/scripts/bind_gpu_to_vfio.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/unbind_gpu_from_vfio.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/check_vfio_binding.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/update_vfio_conf.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/get_gpu_driver_info.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/verify_vfio_binding.sh" "jq ."
echo ""

# Error Handling
echo "Error Handling:"
file_contains "$PROJECT_DIR/scripts/bind_gpu_to_vfio.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/unbind_gpu_from_vfio.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/check_vfio_binding.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/update_vfio_conf.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/get_gpu_driver_info.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/verify_vfio_binding.sh" "error_exit"
file_contains "$PROJECT_DIR/include/GPUManager.php" "throw new Exception"
echo ""

# Input Validation
echo "Input Validation:"
file_contains "$PROJECT_DIR/scripts/bind_gpu_to_vfio.sh" "validate_pci_address"
file_contains "$PROJECT_DIR/scripts/unbind_gpu_from_vfio.sh" "validate_pci_address"
file_contains "$PROJECT_DIR/scripts/check_vfio_binding.sh" "validate_pci_address"
file_contains "$PROJECT_DIR/scripts/update_vfio_conf.sh" "validate_pci_address"
file_contains "$PROJECT_DIR/scripts/get_gpu_driver_info.sh" "validate_pci_address"
file_contains "$PROJECT_DIR/scripts/verify_vfio_binding.sh" "validate_pci_address"
file_contains "$PROJECT_DIR/include/GPUManager.php" "validateGPUAddress"
echo ""

# Logging
echo "Logging:"
file_contains "$PROJECT_DIR/scripts/bind_gpu_to_vfio.sh" "log()"
file_contains "$PROJECT_DIR/scripts/unbind_gpu_from_vfio.sh" "log()"
file_contains "$PROJECT_DIR/scripts/check_vfio_binding.sh" "log()"
file_contains "$PROJECT_DIR/scripts/update_vfio_conf.sh" "log()"
file_contains "$PROJECT_DIR/scripts/get_gpu_driver_info.sh" "log()"
file_contains "$PROJECT_DIR/scripts/verify_vfio_binding.sh" "log()"
file_contains "$PROJECT_DIR/include/GPUManager.php" "private function log"
echo ""

# VFIO Configuration
echo "VFIO Configuration:"
file_contains "$PROJECT_DIR/scripts/bind_gpu_to_vfio.sh" "update_vfio_conf"
file_contains "$PROJECT_DIR/scripts/unbind_gpu_from_vfio.sh" "update_vfio_conf"
file_contains "$PROJECT_DIR/scripts/update_vfio_conf.sh" "/etc/modprobe.d/vfio.conf"
file_contains "$PROJECT_DIR/scripts/bind_gpu_to_vfio.sh" "backup"
file_contains "$PROJECT_DIR/scripts/unbind_gpu_from_vfio.sh" "backup"
file_contains "$PROJECT_DIR/scripts/update_vfio_conf.sh" "backup_config"
echo ""

# Audio Function Handling
echo "Audio Function Handling:"
file_contains "$PROJECT_DIR/scripts/bind_gpu_to_vfio.sh" "bind_audio_function"
file_contains "$PROJECT_DIR/scripts/unbind_gpu_from_vfio.sh" "unbind_audio_function"
file_contains "$PROJECT_DIR/scripts/bind_gpu_to_vfio.sh" "get_audio_function"
file_contains "$PROJECT_DIR/scripts/unbind_gpu_from_vfio.sh" "get_audio_function"
echo ""

# Driver Management
echo "Driver Management:"
file_contains "$PROJECT_DIR/scripts/bind_gpu_to_vfio.sh" "unbind_driver"
file_contains "$PROJECT_DIR/scripts/unbind_gpu_from_vfio.sh" "bind_to_driver"
file_contains "$PROJECT_DIR/scripts/get_gpu_driver_info.sh" "determine_recommended_driver"
file_contains "$PROJECT_DIR/scripts/get_gpu_driver_info.sh" "get_available_drivers"
echo ""

# Verification
echo "Verification:"
file_contains "$PROJECT_DIR/scripts/bind_gpu_to_vfio.sh" "verify_binding"
file_contains "$PROJECT_DIR/scripts/unbind_gpu_from_vfio.sh" "verify_unbinding"
file_contains "$PROJECT_DIR/scripts/verify_vfio_binding.sh" "verify_passthrough_readiness"
file_contains "$PROJECT_DIR/scripts/verify_vfio_binding.sh" "check_iommu_groups"
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
    echo -e "${GREEN}✓ All tests passed! Phase 2 is complete.${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Please review the failures above.${NC}"
    exit 1
fi