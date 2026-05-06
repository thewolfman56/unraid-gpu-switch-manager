#!/bin/bash

# GPU Switch Manager Phase 0 Validation Script
# Version: 1.0.0
# Description: Validates Phase 0 implementation completeness

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

# Function to check if directory exists
check_directory_exists() {
    local dir_path="$1"
    local description="$2"

    if [[ -d "$dir_path" ]]; then
        print_result "$description" "PASS"
    else
        print_result "$description" "FAIL" "Directory not found: $dir_path"
    fi
}

# Function to check file permissions
check_file_permissions() {
    local file_path="$1"
    local expected_perms="$2"
    local description="$3"

    if [[ ! -f "$file_path" ]]; then
        print_result "$description" "FAIL" "File not found: $file_path"
        return
    fi

    local actual_perms=$(stat -c "%a" "$file_path" 2>/dev/null || stat -f "%A" "$file_path" 2>/dev/null)

    if [[ "$actual_perms" == "$expected_perms" ]]; then
        print_result "$description" "PASS"
    else
        print_result "$description" "FAIL" "Expected $expected_perms, got $actual_perms"
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

# Main validation process
main() {
    echo "=========================================="
    echo "GPU Switch Manager Phase 0 Validation"
    echo "=========================================="
    echo ""

    # Get the script directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    echo "Testing in: $SCRIPT_DIR"
    echo ""

    # Test 1: Core Files Exist
    echo "Core Files:"
    check_file_exists "$SCRIPT_DIR/plugin.plg" "plugin.plg exists"
    check_file_exists "$SCRIPT_DIR/install.sh" "install.sh exists"
    check_file_exists "$SCRIPT_DIR/remove.sh" "remove.sh exists"
    check_file_exists "$SCRIPT_DIR/README.md" "README.md exists"
    echo ""

    # Test 2: Configuration Files Exist
    echo "Configuration Files:"
    check_file_exists "$SCRIPT_DIR/gpu.switch.manager.cfg" "Main config file exists"
    check_file_exists "$SCRIPT_DIR/profiles.json" "Profiles file exists"
    check_file_exists "$SCRIPT_DIR/state.json" "State file exists"
    echo ""

    # Test 3: Directory Structure
    echo "Directory Structure:"
    check_directory_exists "$SCRIPT_DIR/scripts" "scripts directory exists"
    check_directory_exists "$SCRIPT_DIR/event" "event directory exists"
    check_directory_exists "$SCRIPT_DIR/include" "include directory exists"
    check_directory_exists "$SCRIPT_DIR/javascript" "javascript directory exists"
    check_directory_exists "$SCRIPT_DIR/styles" "styles directory exists"
    check_directory_exists "$SCRIPT_DIR/templates" "templates directory exists"
    echo ""

    # Test 4: File Permissions
    echo "File Permissions:"
    check_file_permissions "$SCRIPT_DIR/install.sh" "755" "install.sh is executable"
    check_file_permissions "$SCRIPT_DIR/remove.sh" "755" "remove.sh is executable"
    echo ""

    # Test 5: File Content Validation
    echo "File Content:"
    check_file_content "$SCRIPT_DIR/plugin.plg" "<PLUGIN" "plugin.plg has XML structure"
    check_file_content "$SCRIPT_DIR/install.sh" "#!/bin/bash" "install.sh has shebang"
    check_file_content "$SCRIPT_DIR/remove.sh" "#!/bin/bash" "remove.sh has shebang"
    check_file_content "$SCRIPT_DIR/gpu.switch.manager.cfg" "ENABLED" "Config has ENABLED setting"
    echo ""

    # Test 6: JSON Validation
    echo "JSON Syntax:"
    validate_json "$SCRIPT_DIR/profiles.json" "profiles.json is valid JSON"
    validate_json "$SCRIPT_DIR/state.json" "state.json is valid JSON"
    echo ""

    # Test 7: Script Safety Features
    echo "Script Safety:"
    check_file_content "$SCRIPT_DIR/install.sh" "set -e" "install.sh has error handling"
    check_file_content "$SCRIPT_DIR/remove.sh" "set -e" "remove.sh has error handling"
    check_file_content "$SCRIPT_DIR/install.sh" "check_root" "install.sh has root check"
    check_file_content "$SCRIPT_DIR/remove.sh" "check_root" "remove.sh has root check"
    echo ""

    # Test 8: Documentation
    echo "Documentation:"
    check_file_content "$SCRIPT_DIR/README.md" "# GPU Switch Manager" "README has title"
    check_file_content "$SCRIPT_DIR/README.md" "## Installation" "README has installation section"
    check_file_content "$SCRIPT_DIR/README.md" "## Configuration" "README has configuration section"
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
        echo -e "${GREEN}✓ All tests passed! Phase 0 is complete.${NC}"
        exit 0
    else
        echo -e "${RED}✗ Some tests failed. Please review the failures above.${NC}"
        exit 1
    fi
}

# Run main function
main "$@"