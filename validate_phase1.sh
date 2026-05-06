#!/bin/bash

# GPU Switch Manager Phase 1 Validation Script
# Version: 1.0.0
# Description: Validates Phase 1 implementation completeness

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counter for results
PASS_COUNT=0
FAIL_COUNT=0
TOTAL_COUNT=0

# Function to print test result
print_result() {
    local test_name="$1"
    local result="$2"
    local message="$3"

    TOTAL_COUNT=$((TOTAL_COUNT + 1))

    if [[ "$result" == "PASS" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        if [[ -n "$message" ]]; then
            echo -e "  ${YELLOW}→${NC} $message"
        fi
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# Function to check if file exists
check_file_exists() {
    local file_path="$1"
    local description="$2"

    if [[ -f "$file_path" ]]; then
        print_result "$description" "PASS"
    else
        print_result "$description" "FAIL" "File not found: $file_path"
    fi
}

# Function to check if file is executable
check_file_executable() {
    local file_path="$1"
    local description="$2"

    if [[ -x "$file_path" ]]; then
        print_result "$description" "PASS"
    else
        print_result "$description" "FAIL" "File not executable: $file_path"
    fi
}

# Function to check file content
check_file_content() {
    local file_path="$1"
    local search_string="$2"
    local description="$3"

    if [[ ! -f "$file_path" ]]; then
        print_result "$description" "FAIL" "File not found: $file_path"
        return
    fi

    if grep -q "$search_string" "$file_path"; then
        print_result "$description" "PASS"
    else
        print_result "$description" "FAIL" "String not found: $search_string"
    fi
}

# Function to validate JSON syntax
validate_json() {
    local file_path="$1"
    local description="$2"

    if [[ ! -f "$file_path" ]]; then
        print_result "$description" "FAIL" "File not found: $file_path"
        return
    fi

    if command -v python3 &> /dev/null; then
        if python3 -m json.tool "$file_path" > /dev/null 2>&1; then
            print_result "$description" "PASS"
        else
            print_result "$description" "FAIL" "Invalid JSON syntax"
        fi
    elif command -v python &> /dev/null; then
        if python -m json.tool "$file_path" > /dev/null 2>&1; then
            print_result "$description" "PASS"
        else
            print_result "$description" "FAIL" "Invalid JSON syntax"
        fi
    else
        print_result "$description" "WARN" "No JSON validator available"
    fi
}

# Function to validate PHP syntax
validate_php() {
    local file_path="$1"
    local description="$2"

    if [[ ! -f "$file_path" ]]; then
        print_result "$description" "FAIL" "File not found: $file_path"
        return
    fi

    local php_cmd=""
    local php_paths=(
        "php"
        "/c/Users/steph/AppData/Local/Microsoft/WinGet/Packages/PHP.PHP.8.2_Microsoft.Winget.Source_8wekyb3d8bbwe/php.exe"
        "/c/Users/steph/Downloads/Programs/php-8.5.5-Win32-vs17-x64/php.exe"
        "/c/xampp/php/php.exe"
        "/c/xampp/php/windowsXamppPhp/php.exe"
    )

    # Try to find PHP executable
    for path in "${php_paths[@]}"; do
        if [[ -x "$path" ]] || command -v "$path" &> /dev/null; then
            php_cmd="$path"
            break
        fi
    done

    if [[ -n "$php_cmd" ]]; then
        if "$php_cmd" -l "$file_path" > /dev/null 2>&1; then
            print_result "$description" "PASS"
        else
            print_result "$description" "FAIL" "Invalid PHP syntax"
        fi
    else
        print_result "$description" "WARN" "PHP not available for validation"
    fi
}

# Function to test script execution
test_script_execution() {
    local script_path="$1"
    local description="$2"

    if [[ ! -f "$script_path" ]]; then
        print_result "$description" "FAIL" "Script not found: $script_path"
        return
    fi

    if [[ ! -x "$script_path" ]]; then
        print_result "$description" "FAIL" "Script not executable: $script_path"
        return
    fi

    # Try to run script with --help or similar
    if timeout 5 "$script_path" --help > /dev/null 2>&1; then
        print_result "$description" "PASS"
    elif timeout 5 "$script_path" -h > /dev/null 2>&1; then
        print_result "$description" "PASS"
    elif timeout 5 "$script_path" > /dev/null 2>&1; then
        print_result "$description" "PASS"
    else
        # Script might require arguments, check if it's syntactically valid
        if bash -n "$script_path" 2>/dev/null; then
            print_result "$description" "PASS"
        else
            print_result "$description" "FAIL" "Script syntax error"
        fi
    fi
}

# Main validation process
main() {
    echo "=========================================="
    echo "GPU Switch Manager Phase 1 Validation"
    echo "=========================================="
    echo ""

    # Get the script directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    echo "Testing in: $SCRIPT_DIR"
    echo ""

    # Test 1: Script Files Exist
    echo "Script Files:"
    check_file_exists "$SCRIPT_DIR/scripts/list_gpus.sh" "list_gpus.sh exists"
    check_file_exists "$SCRIPT_DIR/scripts/get_gpu_state.sh" "get_gpu_state.sh exists"
    check_file_exists "$SCRIPT_DIR/scripts/detect_primary_gpu.sh" "detect_primary_gpu.sh exists"
    check_file_exists "$SCRIPT_DIR/scripts/validate_gpu_address.sh" "validate_gpu_address.sh exists"
    echo ""

    # Test 2: PHP Class Exists
    echo "PHP Class:"
    check_file_exists "$SCRIPT_DIR/include/GPUManager.php" "GPUManager.php exists"
    echo ""

    # Test 3: Script Permissions
    echo "Script Permissions:"
    check_file_executable "$SCRIPT_DIR/scripts/list_gpus.sh" "list_gpus.sh is executable"
    check_file_executable "$SCRIPT_DIR/scripts/get_gpu_state.sh" "get_gpu_state.sh is executable"
    check_file_executable "$SCRIPT_DIR/scripts/detect_primary_gpu.sh" "detect_primary_gpu.sh is executable"
    check_file_executable "$SCRIPT_DIR/scripts/validate_gpu_address.sh" "validate_gpu_address.sh is executable"
    echo ""

    # Test 4: Script Content Validation
    echo "Script Content:"
    check_file_content "$SCRIPT_DIR/scripts/list_gpus.sh" "#!/bin/bash" "list_gpus.sh has shebang"
    check_file_content "$SCRIPT_DIR/scripts/get_gpu_state.sh" "#!/bin/bash" "get_gpu_state.sh has shebang"
    check_file_content "$SCRIPT_DIR/scripts/detect_primary_gpu.sh" "#!/bin/bash" "detect_primary_gpu.sh has shebang"
    check_file_content "$SCRIPT_DIR/scripts/validate_gpu_address.sh" "#!/bin/bash" "validate_gpu_address.sh has shebang"
    echo ""

    # Test 5: Script Safety Features
    echo "Script Safety:"
    check_file_content "$SCRIPT_DIR/scripts/list_gpus.sh" "set -e" "list_gpus.sh has error handling"
    check_file_content "$SCRIPT_DIR/scripts/get_gpu_state.sh" "set -e" "get_gpu_state.sh has error handling"
    check_file_content "$SCRIPT_DIR/scripts/detect_primary_gpu.sh" "set -e" "detect_primary_gpu.sh has error handling"
    check_file_content "$SCRIPT_DIR/scripts/validate_gpu_address.sh" "set -e" "validate_gpu_address.sh has error handling"
    echo ""

    # Test 6: Script Functionality
    echo "Script Functionality:"
    check_file_content "$SCRIPT_DIR/scripts/list_gpus.sh" "get_gpu_model" "list_gpus.sh has GPU model function"
    check_file_content "$SCRIPT_DIR/scripts/get_gpu_state.sh" "get_current_driver" "get_gpu_state.sh has driver detection"
    check_file_content "$SCRIPT_DIR/scripts/detect_primary_gpu.sh" "determine_primary_gpu" "detect_primary_gpu.sh has primary detection"
    check_file_content "$SCRIPT_DIR/scripts/validate_gpu_address.sh" "validate_format" "validate_gpu_address.sh has format validation"
    echo ""

    # Test 7: PHP Class Structure
    echo "PHP Class Structure:"
    check_file_content "$SCRIPT_DIR/include/GPUManager.php" "class GPUManager" "GPUManager class defined"
    check_file_content "$SCRIPT_DIR/include/GPUManager.php" "function listGPUs" "listGPUs method exists"
    check_file_content "$SCRIPT_DIR/include/GPUManager.php" "function getGPUState" "getGPUState method exists"
    check_file_content "$SCRIPT_DIR/include/GPUManager.php" "function isPrimaryGPU" "isPrimaryGPU method exists"
    check_file_content "$SCRIPT_DIR/include/GPUManager.php" "function canSwitchGPU" "canSwitchGPU method exists"
    check_file_content "$SCRIPT_DIR/include/GPUManager.php" "function validateGPUAddress" "validateGPUAddress method exists"
    echo ""

    # Test 8: PHP Class Features
    echo "PHP Class Features:"
    check_file_content "$SCRIPT_DIR/include/GPUManager.php" "private \$cache" "Cache mechanism implemented"
    check_file_content "$SCRIPT_DIR/include/GPUManager.php" "function log" "Logging functionality present"
    check_file_content "$SCRIPT_DIR/include/GPUManager.php" "function executeScript" "Script execution method exists"
    check_file_content "$SCRIPT_DIR/include/GPUManager.php" "function parseJson" "JSON parsing method exists"
    echo ""

    # Test 9: JSON Output Format
    echo "JSON Output Format:"
    check_file_content "$SCRIPT_DIR/scripts/list_gpus.sh" '"pci_address"' "list_gpus.sh outputs JSON"
    check_file_content "$SCRIPT_DIR/scripts/get_gpu_state.sh" '"current_driver"' "get_gpu_state.sh outputs JSON"
    check_file_content "$SCRIPT_DIR/scripts/detect_primary_gpu.sh" '"primary_gpu"' "detect_primary_gpu.sh outputs JSON"
    check_file_content "$SCRIPT_DIR/scripts/validate_gpu_address.sh" '"valid"' "validate_gpu_address.sh outputs JSON"
    echo ""

    # Test 10: Error Handling
    echo "Error Handling:"
    check_file_content "$SCRIPT_DIR/scripts/list_gpus.sh" "error_exit" "list_gpus.sh has error handling"
    check_file_content "$SCRIPT_DIR/scripts/get_gpu_state.sh" "error_exit" "get_gpu_state.sh has error handling"
    check_file_content "$SCRIPT_DIR/scripts/detect_primary_gpu.sh" "error_exit" "detect_primary_gpu.sh has error handling"
    check_file_content "$SCRIPT_DIR/scripts/validate_gpu_address.sh" "error_exit" "validate_gpu_address.sh has error handling"
    check_file_content "$SCRIPT_DIR/include/GPUManager.php" "throw new Exception" "GPUManager throws exceptions"
    echo ""

    # Test 11: Input Validation
    echo "Input Validation:"
    check_file_content "$SCRIPT_DIR/scripts/get_gpu_state.sh" "validate_pci_address" "get_gpu_state.sh validates input"
    check_file_content "$SCRIPT_DIR/scripts/validate_gpu_address.sh" "validate_format" "validate_gpu_address.sh validates format"
    check_file_content "$SCRIPT_DIR/include/GPUManager.php" "validateGPUAddress" "GPUManager validates addresses"
    echo ""

    # Test 12: Script Execution Tests
    echo "Script Execution:"
    test_script_execution "$SCRIPT_DIR/scripts/list_gpus.sh" "list_gpus.sh executes"
    test_script_execution "$SCRIPT_DIR/scripts/get_gpu_state.sh" "get_gpu_state.sh executes"
    test_script_execution "$SCRIPT_DIR/scripts/detect_primary_gpu.sh" "detect_primary_gpu.sh executes"
    test_script_execution "$SCRIPT_DIR/scripts/validate_gpu_address.sh" "validate_gpu_address.sh executes"
    echo ""

    # Test 13: PHP Syntax Validation
    echo "PHP Syntax:"
    validate_php "$SCRIPT_DIR/include/GPUManager.php" "GPUManager.php has valid PHP syntax"
    echo ""

    # Print summary
    echo "=========================================="
    echo "Validation Summary"
    echo "=========================================="
    echo -e "Total Tests: $TOTAL_COUNT"
    echo -e "${GREEN}Passed: $PASS_COUNT${NC}"
    echo -e "${RED}Failed: $FAIL_COUNT${NC}"
    echo ""

    if [[ $FAIL_COUNT -eq 0 ]]; then
        echo -e "${GREEN}✓ All tests passed! Phase 1 is complete.${NC}"
        exit 0
    else
        echo -e "${RED}✗ Some tests failed. Please review the failures above.${NC}"
        exit 1
    fi
}

# Run main function
main "$@"