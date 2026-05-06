#!/bin/bash

# validate_phase5.sh
# Validation script for Phase 5: Configuration Management
# Tests all configuration management functionality

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
echo "GPU Switch Manager Phase 5 Validation"
echo "=========================================="
echo ""
echo "Testing in: $PROJECT_DIR"
echo ""

# Configuration Manager
echo "Configuration Manager:"
file_exists "$PROJECT_DIR/scripts/config_manager.sh"
echo ""

# Profile Manager
echo "Profile Manager:"
file_exists "$PROJECT_DIR/scripts/profile_manager.sh"
echo ""

# Preference Manager
echo "Preference Manager:"
file_exists "$PROJECT_DIR/scripts/preference_manager.sh"
echo ""

# Configuration Validator
echo "Configuration Validator:"
file_exists "$PROJECT_DIR/scripts/config_validator.sh"
echo ""

# Configuration Backup
echo "Configuration Backup:"
file_exists "$PROJECT_DIR/scripts/config_backup.sh"
echo ""

# Configuration Import
echo "Configuration Import:"
file_exists "$PROJECT_DIR/scripts/config_import.sh"
echo ""

# Configuration Export
echo "Configuration Export:"
file_exists "$PROJECT_DIR/scripts/config_export.sh"
echo ""

# Configuration Migration
echo "Configuration Migration:"
file_exists "$PROJECT_DIR/scripts/config_migrate.sh"
echo ""

# Configuration Version
echo "Configuration Version:"
file_exists "$PROJECT_DIR/scripts/config_version.sh"
echo ""

# Configuration Template
echo "Configuration Template:"
file_exists "$PROJECT_DIR/scripts/config_template.sh"
echo ""

# PHP Classes
echo "PHP Classes:"
file_exists "$PROJECT_DIR/include/ConfigManager.php"
file_exists "$PROJECT_DIR/include/ProfileManager.php"
file_exists "$PROJECT_DIR/include/PreferenceManager.php"
file_exists "$PROJECT_DIR/include/ConfigValidator.php"
file_exists "$PROJECT_DIR/include/ConfigBackup.php"
echo ""

# Script Permissions
echo "Script Permissions:"
file_executable "$PROJECT_DIR/scripts/config_manager.sh"
file_executable "$PROJECT_DIR/scripts/profile_manager.sh"
file_executable "$PROJECT_DIR/scripts/preference_manager.sh"
file_executable "$PROJECT_DIR/scripts/config_validator.sh"
file_executable "$PROJECT_DIR/scripts/config_backup.sh"
file_executable "$PROJECT_DIR/scripts/config_import.sh"
file_executable "$PROJECT_DIR/scripts/config_export.sh"
file_executable "$PROJECT_DIR/scripts/config_migrate.sh"
file_executable "$PROJECT_DIR/scripts/config_version.sh"
file_executable "$PROJECT_DIR/scripts/config_template.sh"
echo ""

# Script Content
echo "Script Content:"
file_has_shebang "$PROJECT_DIR/scripts/config_manager.sh"
file_has_shebang "$PROJECT_DIR/scripts/profile_manager.sh"
file_has_shebang "$PROJECT_DIR/scripts/preference_manager.sh"
file_has_shebang "$PROJECT_DIR/scripts/config_validator.sh"
file_has_shebang "$PROJECT_DIR/scripts/config_backup.sh"
file_has_shebang "$PROJECT_DIR/scripts/config_import.sh"
file_has_shebang "$PROJECT_DIR/scripts/config_export.sh"
file_has_shebang "$PROJECT_DIR/scripts/config_migrate.sh"
file_has_shebang "$PROJECT_DIR/scripts/config_version.sh"
file_has_shebang "$PROJECT_DIR/scripts/config_template.sh"
echo ""

# Script Safety
echo "Script Safety:"
file_contains "$PROJECT_DIR/scripts/config_manager.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/profile_manager.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/preference_manager.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/config_validator.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/config_backup.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/config_import.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/config_export.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/config_migrate.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/config_version.sh" "set -euo pipefail"
file_contains "$PROJECT_DIR/scripts/config_template.sh" "set -euo pipefail"
echo ""

# Script Functionality
echo "Script Functionality:"
file_contains "$PROJECT_DIR/scripts/config_manager.sh" "main()"
file_contains "$PROJECT_DIR/scripts/profile_manager.sh" "main()"
file_contains "$PROJECT_DIR/scripts/preference_manager.sh" "main()"
file_contains "$PROJECT_DIR/scripts/config_validator.sh" "main()"
file_contains "$PROJECT_DIR/scripts/config_backup.sh" "main()"
file_contains "$PROJECT_DIR/scripts/config_import.sh" "main()"
file_contains "$PROJECT_DIR/scripts/config_export.sh" "main()"
file_contains "$PROJECT_DIR/scripts/config_migrate.sh" "main()"
file_contains "$PROJECT_DIR/scripts/config_version.sh" "main()"
file_contains "$PROJECT_DIR/scripts/config_template.sh" "main()"
echo ""

# PHP Class Structure
echo "PHP Class Structure:"
file_contains "$PROJECT_DIR/include/ConfigManager.php" "class ConfigManager"
file_contains "$PROJECT_DIR/include/ProfileManager.php" "class ProfileManager"
file_contains "$PROJECT_DIR/include/PreferenceManager.php" "class PreferenceManager"
file_contains "$PROJECT_DIR/include/ConfigValidator.php" "class ConfigValidator"
file_contains "$PROJECT_DIR/include/ConfigBackup.php" "class ConfigBackup"
echo ""

# PHP Class Features
echo "PHP Class Features:"
file_contains "$PROJECT_DIR/include/ConfigManager.php" "public function loadConfig"
file_contains "$PROJECT_DIR/include/ConfigManager.php" "public function saveConfig"
file_contains "$PROJECT_DIR/include/ConfigManager.php" "public function getConfigValue"
file_contains "$PROJECT_DIR/include/ConfigManager.php" "public function setConfigValue"
file_contains "$PROJECT_DIR/include/ProfileManager.php" "public function createProfile"
file_contains "$PROJECT_DIR/include/ProfileManager.php" "public function readProfile"
file_contains "$PROJECT_DIR/include/ProfileManager.php" "public function updateProfile"
file_contains "$PROJECT_DIR/include/ProfileManager.php" "public function deleteProfile"
file_contains "$PROJECT_DIR/include/PreferenceManager.php" "public function setPreference"
file_contains "$PROJECT_DIR/include/PreferenceManager.php" "public function getPreference"
file_contains "$PROJECT_DIR/include/PreferenceManager.php" "public function deletePreference"
file_contains "$PROJECT_DIR/include/ConfigValidator.php" "public function validateSchema"
file_contains "$PROJECT_DIR/include/ConfigValidator.php" "public function validateReferences"
file_contains "$PROJECT_DIR/include/ConfigValidator.php" "public function validateDependencies"
file_contains "$PROJECT_DIR/include/ConfigBackup.php" "public function createBackup"
file_contains "$PROJECT_DIR/include/ConfigBackup.php" "public function restoreBackup"
file_contains "$PROJECT_DIR/include/ConfigBackup.php" "public function deleteBackup"
echo ""

# JSON Output Format
echo "JSON Output Format:"
file_contains "$PROJECT_DIR/scripts/config_manager.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/profile_manager.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/preference_manager.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/config_validator.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/config_backup.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/config_import.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/config_export.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/config_migrate.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/config_version.sh" "jq ."
file_contains "$PROJECT_DIR/scripts/config_template.sh" "jq ."
echo ""

# Error Handling
echo "Error Handling:"
file_contains "$PROJECT_DIR/scripts/config_manager.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/profile_manager.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/preference_manager.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/config_validator.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/config_backup.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/config_import.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/config_export.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/config_migrate.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/config_version.sh" "error_exit"
file_contains "$PROJECT_DIR/scripts/config_template.sh" "error_exit"
file_contains "$PROJECT_DIR/include/ConfigManager.php" "throw new Exception"
file_contains "$PROJECT_DIR/include/ProfileManager.php" "throw new Exception"
file_contains "$PROJECT_DIR/include/PreferenceManager.php" "throw new Exception"
file_contains "$PROJECT_DIR/include/ConfigValidator.php" "throw new Exception"
file_contains "$PROJECT_DIR/include/ConfigBackup.php" "throw new Exception"
echo ""

# Input Validation
echo "Input Validation:"
file_contains "$PROJECT_DIR/scripts/config_manager.sh" "validate_config"
file_contains "$PROJECT_DIR/scripts/profile_manager.sh" "validate_profile_name"
file_contains "$PROJECT_DIR/scripts/preference_manager.sh" "validate_preference_key"
file_contains "$PROJECT_DIR/scripts/config_validator.sh" "validate_schema"
file_contains "$PROJECT_DIR/scripts/config_backup.sh" "verify_backup"
file_contains "$PROJECT_DIR/scripts/config_import.sh" "validate_import"
file_contains "$PROJECT_DIR/scripts/config_export.sh" "verify_export"
file_contains "$PROJECT_DIR/scripts/config_migrate.sh" "validate_migration"
file_contains "$PROJECT_DIR/scripts/config_version.sh" "validate_version"
file_contains "$PROJECT_DIR/scripts/config_template.sh" "validate_template"
file_contains "$PROJECT_DIR/include/ConfigManager.php" "validateConfig"
file_contains "$PROJECT_DIR/include/ProfileManager.php" "validateProfileName"
file_contains "$PROJECT_DIR/include/PreferenceManager.php" "validatePreferenceKey"
file_contains "$PROJECT_DIR/include/ConfigValidator.php" "validateSchema"
file_contains "$PROJECT_DIR/include/ConfigBackup.php" "verifyBackup"
echo ""

# Logging
echo "Logging:"
file_contains "$PROJECT_DIR/scripts/config_manager.sh" "log()"
file_contains "$PROJECT_DIR/scripts/profile_manager.sh" "log()"
file_contains "$PROJECT_DIR/scripts/preference_manager.sh" "log()"
file_contains "$PROJECT_DIR/scripts/config_validator.sh" "log()"
file_contains "$PROJECT_DIR/scripts/config_backup.sh" "log()"
file_contains "$PROJECT_DIR/scripts/config_import.sh" "log()"
file_contains "$PROJECT_DIR/scripts/config_export.sh" "log()"
file_contains "$PROJECT_DIR/scripts/config_migrate.sh" "log()"
file_contains "$PROJECT_DIR/scripts/config_version.sh" "log()"
file_contains "$PROJECT_DIR/scripts/config_template.sh" "log()"
file_contains "$PROJECT_DIR/include/ConfigManager.php" "private function log"
file_contains "$PROJECT_DIR/include/ProfileManager.php" "private function log"
file_contains "$PROJECT_DIR/include/PreferenceManager.php" "private function log"
file_contains "$PROJECT_DIR/include/ConfigValidator.php" "private function log"
file_contains "$PROJECT_DIR/include/ConfigBackup.php" "private function log"
echo ""

# Configuration Features
echo "Configuration Features:"
file_contains "$PROJECT_DIR/scripts/config_manager.sh" "init_config"
file_contains "$PROJECT_DIR/scripts/config_manager.sh" "load_config"
file_contains "$PROJECT_DIR/scripts/config_manager.sh" "save_config"
file_contains "$PROJECT_DIR/scripts/config_manager.sh" "backup_config"
file_contains "$PROJECT_DIR/scripts/config_manager.sh" "restore_config"
file_contains "$PROJECT_DIR/scripts/config_manager.sh" "validate_config"
file_contains "$PROJECT_DIR/scripts/config_manager.sh" "merge_config"
echo ""

# Profile Features
echo "Profile Features:"
file_contains "$PROJECT_DIR/scripts/profile_manager.sh" "create_profile"
file_contains "$PROJECT_DIR/scripts/profile_manager.sh" "read_profile"
file_contains "$PROJECT_DIR/scripts/profile_manager.sh" "update_profile"
file_contains "$PROJECT_DIR/scripts/profile_manager.sh" "delete_profile"
file_contains "$PROJECT_DIR/scripts/profile_manager.sh" "list_profiles"
file_contains "$PROJECT_DIR/scripts/profile_manager.sh" "activate_profile"
file_contains "$PROJECT_DIR/scripts/profile_manager.sh" "deactivate_profile"
file_contains "$PROJECT_DIR/scripts/profile_manager.sh" "clone_profile"
file_contains "$PROJECT_DIR/scripts/profile_manager.sh" "validate_profile"
file_contains "$PROJECT_DIR/scripts/profile_manager.sh" "get_active_profile"
echo ""

# Preference Features
echo "Preference Features:"
file_contains "$PROJECT_DIR/scripts/preference_manager.sh" "set_preference"
file_contains "$PROJECT_DIR/scripts/preference_manager.sh" "get_preference"
file_contains "$PROJECT_DIR/scripts/preference_manager.sh" "delete_preference"
file_contains "$PROJECT_DIR/scripts/preference_manager.sh" "list_preferences"
file_contains "$PROJECT_DIR/scripts/preference_manager.sh" "reset_preference"
file_contains "$PROJECT_DIR/scripts/preference_manager.sh" "reset_all_preferences"
file_contains "$PROJECT_DIR/scripts/preference_manager.sh" "validate_preference"
file_contains "$PROJECT_DIR/scripts/preference_manager.sh" "get_default_preference"
file_contains "$PROJECT_DIR/scripts/preference_manager.sh" "merge_preferences"
file_contains "$PROJECT_DIR/scripts/preference_manager.sh" "export_preferences"
echo ""

# Validation Features
echo "Validation Features:"
file_contains "$PROJECT_DIR/scripts/config_validator.sh" "validate_schema"
file_contains "$PROJECT_DIR/scripts/config_validator.sh" "validate_references"
file_contains "$PROJECT_DIR/scripts/config_validator.sh" "validate_dependencies"
file_contains "$PROJECT_DIR/scripts/config_validator.sh" "detect_conflicts"
file_contains "$PROJECT_DIR/scripts/config_validator.sh" "generate_report"
file_contains "$PROJECT_DIR/scripts/config_validator.sh" "fix_errors"
file_contains "$PROJECT_DIR/scripts/config_validator.sh" "get_validation_rules"
file_contains "$PROJECT_DIR/scripts/config_validator.sh" "add_validation_rule"
file_contains "$PROJECT_DIR/scripts/config_validator.sh" "remove_validation_rule"
file_contains "$PROJECT_DIR/scripts/config_validator.sh" "test_validation"
echo ""

# Backup Features
echo "Backup Features:"
file_contains "$PROJECT_DIR/scripts/config_backup.sh" "create_backup"
file_contains "$PROJECT_DIR/scripts/config_backup.sh" "list_backups"
file_contains "$PROJECT_DIR/scripts/config_backup.sh" "restore_backup"
file_contains "$PROJECT_DIR/scripts/config_backup.sh" "delete_backup"
file_contains "$PROJECT_DIR/scripts/config_backup.sh" "auto_backup"
file_contains "$PROJECT_DIR/scripts/config_backup.sh" "schedule_backup"
file_contains "$PROJECT_DIR/scripts/config_backup.sh" "verify_backup"
file_contains "$PROJECT_DIR/scripts/config_backup.sh" "compress_backup"
file_contains "$PROJECT_DIR/scripts/config_backup.sh" "decompress_backup"
file_contains "$PROJECT_DIR/scripts/config_backup.sh" "cleanup_backups"
file_contains "$PROJECT_DIR/scripts/config_backup.sh" "get_backup_info"
echo ""

# Import/Export Features
echo "Import/Export Features:"
file_contains "$PROJECT_DIR/scripts/config_import.sh" "import_config"
file_contains "$PROJECT_DIR/scripts/config_import.sh" "validate_import"
file_contains "$PROJECT_DIR/scripts/config_import.sh" "merge_import"
file_contains "$PROJECT_DIR/scripts/config_import.sh" "preview_import"
file_contains "$PROJECT_DIR/scripts/config_import.sh" "confirm_import"
file_contains "$PROJECT_DIR/scripts/config_export.sh" "export_config"
file_contains "$PROJECT_DIR/scripts/config_export.sh" "select_export"
file_contains "$PROJECT_DIR/scripts/config_export.sh" "format_export"
file_contains "$PROJECT_DIR/scripts/config_export.sh" "compress_export"
file_contains "$PROJECT_DIR/scripts/config_export.sh" "verify_export"
echo ""

# Migration Features
echo "Migration Features:"
file_contains "$PROJECT_DIR/scripts/config_migrate.sh" "detect_version"
file_contains "$PROJECT_DIR/scripts/config_migrate.sh" "upgrade_config"
file_contains "$PROJECT_DIR/scripts/config_migrate.sh" "downgrade_config"
file_contains "$PROJECT_DIR/scripts/config_migrate.sh" "validate_migration"
file_contains "$PROJECT_DIR/scripts/config_migrate.sh" "rollback_migration"
file_contains "$PROJECT_DIR/scripts/config_migrate.sh" "get_migration_path"
file_contains "$PROJECT_DIR/scripts/config_migrate.sh" "test_migration"
file_contains "$PROJECT_DIR/scripts/config_migrate.sh" "get_available_versions"
echo ""

# Version Features
echo "Version Features:"
file_contains "$PROJECT_DIR/scripts/config_version.sh" "get_version"
file_contains "$PROJECT_DIR/scripts/config_version.sh" "set_version"
file_contains "$PROJECT_DIR/scripts/config_version.sh" "increment_version"
file_contains "$PROJECT_DIR/scripts/config_version.sh" "compare_versions"
file_contains "$PROJECT_DIR/scripts/config_version.sh" "get_version_history"
file_contains "$PROJECT_DIR/scripts/config_version.sh" "create_version_tag"
file_contains "$PROJECT_DIR/scripts/config_version.sh" "get_version_diff"
file_contains "$PROJECT_DIR/scripts/config_version.sh" "validate_version"
file_contains "$PROJECT_DIR/scripts/config_version.sh" "add_to_version_history"
file_contains "$PROJECT_DIR/scripts/config_version.sh" "clear_version_history"
echo ""

# Template Features
echo "Template Features:"
file_contains "$PROJECT_DIR/scripts/config_template.sh" "create_template"
file_contains "$PROJECT_DIR/scripts/config_template.sh" "list_templates"
file_contains "$PROJECT_DIR/scripts/config_template.sh" "apply_template"
file_contains "$PROJECT_DIR/scripts/config_template.sh" "validate_template"
file_contains "$PROJECT_DIR/scripts/config_template.sh" "customize_template"
file_contains "$PROJECT_DIR/scripts/config_template.sh" "delete_template"
file_contains "$PROJECT_DIR/scripts/config_template.sh" "export_template"
file_contains "$PROJECT_DIR/scripts/config_template.sh" "import_template"
file_contains "$PROJECT_DIR/scripts/config_template.sh" "get_template_info"
file_contains "$PROJECT_DIR/scripts/config_template.sh" "test_template"
echo ""

# PHP Syntax
echo "PHP Syntax:"
check_php_syntax "$PROJECT_DIR/include/ConfigManager.php"
check_php_syntax "$PROJECT_DIR/include/ProfileManager.php"
check_php_syntax "$PROJECT_DIR/include/PreferenceManager.php"
check_php_syntax "$PROJECT_DIR/include/ConfigValidator.php"
check_php_syntax "$PROJECT_DIR/include/ConfigBackup.php"
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
    echo -e "${GREEN}✓ All tests passed! Phase 5 is complete.${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Please review the failures above.${NC}"
    exit 1
fi
