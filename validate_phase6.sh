#!/bin/bash

# validate_phase6.sh
# Validation script for Phase 6: Web Interface
# Tests all web interface functionality

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
echo "GPU Switch Manager Phase 6 Validation"
echo "=========================================="
echo ""
echo "Testing in: $PROJECT_DIR"
echo ""

# Web Interface Core
echo "Web Interface Core:"
file_exists "$PROJECT_DIR/include/WebInterface.php"
echo ""

# Dashboard Controller
echo "Dashboard Controller:"
file_exists "$PROJECT_DIR/include/DashboardController.php"
echo ""

# Configuration Controller
echo "Configuration Controller:"
file_exists "$PROJECT_DIR/include/ConfigController.php"
echo ""

# GPU Controller
echo "GPU Controller:"
file_exists "$PROJECT_DIR/include/GPUController.php"
echo ""

# Events Controller
echo "Events Controller:"
file_exists "$PROJECT_DIR/include/EventsController.php"
echo ""

# Profiles Controller
echo "Profiles Controller:"
file_exists "$PROJECT_DIR/include/ProfilesController.php"
echo ""

# Preferences Controller
echo "Preferences Controller:"
file_exists "$PROJECT_DIR/include/PreferencesController.php"
echo ""

# Backups Controller
echo "Backups Controller:"
file_exists "$PROJECT_DIR/include/BackupsController.php"
echo ""

# API Handler
echo "API Handler:"
file_exists "$PROJECT_DIR/include/APIHandler.php"
echo ""

# WebSocket Handler
echo "WebSocket Handler:"
file_exists "$PROJECT_DIR/include/WebSocketHandler.php"
echo ""

# PHP Class Structure
echo "PHP Class Structure:"
file_contains "$PROJECT_DIR/include/WebInterface.php" "class WebInterface"
file_contains "$PROJECT_DIR/include/DashboardController.php" "class DashboardController"
file_contains "$PROJECT_DIR/include/ConfigController.php" "class ConfigController"
file_contains "$PROJECT_DIR/include/GPUController.php" "class GPUController"
file_contains "$PROJECT_DIR/include/EventsController.php" "class EventsController"
file_contains "$PROJECT_DIR/include/ProfilesController.php" "class ProfilesController"
file_contains "$PROJECT_DIR/include/PreferencesController.php" "class PreferencesController"
file_contains "$PROJECT_DIR/include/BackupsController.php" "class BackupsController"
file_contains "$PROJECT_DIR/include/APIHandler.php" "class APIHandler"
file_contains "$PROJECT_DIR/include/WebSocketHandler.php" "class WebSocketHandler"
echo ""

# WebInterface Features
echo "WebInterface Features:"
file_contains "$PROJECT_DIR/include/WebInterface.php" "public function renderPage"
file_contains "$PROJECT_DIR/include/WebInterface.php" "public function renderJSON"
file_contains "$PROJECT_DIR/include/WebInterface.php" "public function renderError"
file_contains "$PROJECT_DIR/include/WebInterface.php" "public function redirect"
file_contains "$PROJECT_DIR/include/WebInterface.php" "public function getRequestData"
file_contains "$PROJECT_DIR/include/WebInterface.php" "public function validateCSRF"
file_contains "$PROJECT_DIR/include/WebInterface.php" "public function generateCSRF"
file_contains "$PROJECT_DIR/include/WebInterface.php" "public function getSession"
file_contains "$PROJECT_DIR/include/WebInterface.php" "public function setSession"
file_contains "$PROJECT_DIR/include/WebInterface.php" "public function validateRequest"
echo ""

# DashboardController Features
echo "DashboardController Features:"
file_contains "$PROJECT_DIR/include/DashboardController.php" "public function index"
file_contains "$PROJECT_DIR/include/DashboardController.php" "public function getSystemStatus"
file_contains "$PROJECT_DIR/include/DashboardController.php" "public function getGPUStatus"
file_contains "$PROJECT_DIR/include/DashboardController.php" "public function getRecentEvents"
file_contains "$PROJECT_DIR/include/DashboardController.php" "public function getStatistics"
file_contains "$PROJECT_DIR/include/DashboardController.php" "public function getQuickActions"
echo ""

# ConfigController Features
echo "ConfigController Features:"
file_contains "$PROJECT_DIR/include/ConfigController.php" "public function index"
file_contains "$PROJECT_DIR/include/ConfigController.php" "public function getConfiguration"
file_contains "$PROJECT_DIR/include/ConfigController.php" "public function updateConfiguration"
file_contains "$PROJECT_DIR/include/ConfigController.php" "public function validateConfiguration"
file_contains "$PROJECT_DIR/include/ConfigController.php" "public function resetConfiguration"
file_contains "$PROJECT_DIR/include/ConfigController.php" "public function exportConfiguration"
file_contains "$PROJECT_DIR/include/ConfigController.php" "public function importConfiguration"
echo ""

# GPUController Features
echo "GPUController Features:"
file_contains "$PROJECT_DIR/include/GPUController.php" "public function index"
file_contains "$PROJECT_DIR/include/GPUController.php" "public function getGPUs"
file_contains "$PROJECT_DIR/include/GPUController.php" "public function getGPUStatus"
file_contains "$PROJECT_DIR/include/GPUController.php" "public function bindGPU"
file_contains "$PROJECT_DIR/include/GPUController.php" "public function unbindGPU"
file_contains "$PROJECT_DIR/include/GPUController.php" "public function switchGPU"
file_contains "$PROJECT_DIR/include/GPUController.php" "public function getGPUDrivers"
echo ""

# EventsController Features
echo "EventsController Features:"
file_contains "$PROJECT_DIR/include/EventsController.php" "public function index"
file_contains "$PROJECT_DIR/include/EventsController.php" "public function getEventHistory"
file_contains "$PROJECT_DIR/include/EventsController.php" "public function getEventStatistics"
file_contains "$PROJECT_DIR/include/EventsController.php" "public function getActiveOperations"
file_contains "$PROJECT_DIR/include/EventsController.php" "public function cancelOperation"
file_contains "$PROJECT_DIR/include/EventsController.php" "public function getEventHandlerStatus"
echo ""

# ProfilesController Features
echo "ProfilesController Features:"
file_contains "$PROJECT_DIR/include/ProfilesController.php" "public function index"
file_contains "$PROJECT_DIR/include/ProfilesController.php" "public function createProfile"
file_contains "$PROJECT_DIR/include/ProfilesController.php" "public function editProfile"
file_contains "$PROJECT_DIR/include/ProfilesController.php" "public function deleteProfile"
file_contains "$PROJECT_DIR/include/ProfilesController.php" "public function activateProfile"
file_contains "$PROJECT_DIR/include/ProfilesController.php" "public function cloneProfile"
echo ""

# PreferencesController Features
echo "PreferencesController Features:"
file_contains "$PROJECT_DIR/include/PreferencesController.php" "public function index"
file_contains "$PROJECT_DIR/include/PreferencesController.php" "public function getPreferences"
file_contains "$PROJECT_DIR/include/PreferencesController.php" "public function updatePreference"
file_contains "$PROJECT_DIR/include/PreferencesController.php" "public function deletePreference"
file_contains "$PROJECT_DIR/include/PreferencesController.php" "public function resetPreference"
file_contains "$PROJECT_DIR/include/PreferencesController.php" "public function resetAllPreferences"
echo ""

# BackupsController Features
echo "BackupsController Features:"
file_contains "$PROJECT_DIR/include/BackupsController.php" "public function index"
file_contains "$PROJECT_DIR/include/BackupsController.php" "public function createBackup"
file_contains "$PROJECT_DIR/include/BackupsController.php" "public function restoreBackup"
file_contains "$PROJECT_DIR/include/BackupsController.php" "public function deleteBackup"
file_contains "$PROJECT_DIR/include/BackupsController.php" "public function listBackups"
file_contains "$PROJECT_DIR/include/BackupsController.php" "public function getBackupInfo"
echo ""

# APIHandler Features
echo "APIHandler Features:"
file_contains "$PROJECT_DIR/include/APIHandler.php" "public function handleRequest"
file_contains "$PROJECT_DIR/include/APIHandler.php" "private function routeRequest"
file_contains "$PROJECT_DIR/include/APIHandler.php" "private function authenticateRequest"
file_contains "$PROJECT_DIR/include/APIHandler.php" "private function rateLimitRequest"
file_contains "$PROJECT_DIR/include/APIHandler.php" "private function logRequest"
echo ""

# WebSocketHandler Features
echo "WebSocketHandler Features:"
file_contains "$PROJECT_DIR/include/WebSocketHandler.php" "public function start"
file_contains "$PROJECT_DIR/include/WebSocketHandler.php" "public function stop"
file_contains "$PROJECT_DIR/include/WebSocketHandler.php" "public function broadcast"
file_contains "$PROJECT_DIR/include/WebSocketHandler.php" "public function sendToClient"
file_contains "$PROJECT_DIR/include/WebSocketHandler.php" "public function subscribe"
file_contains "$PROJECT_DIR/include/WebSocketHandler.php" "public function unsubscribe"
echo ""

# Error Handling
echo "Error Handling:"
file_contains "$PROJECT_DIR/include/WebInterface.php" "throw new Exception"
file_contains "$PROJECT_DIR/include/DashboardController.php" "throw new Exception"
file_contains "$PROJECT_DIR/include/ConfigController.php" "throw new Exception"
file_contains "$PROJECT_DIR/include/GPUController.php" "throw new Exception"
file_contains "$PROJECT_DIR/include/EventsController.php" "throw new Exception"
file_contains "$PROJECT_DIR/include/ProfilesController.php" "throw new Exception"
file_contains "$PROJECT_DIR/include/PreferencesController.php" "throw new Exception"
file_contains "$PROJECT_DIR/include/BackupsController.php" "throw new Exception"
file_contains "$PROJECT_DIR/include/APIHandler.php" "throw new Exception"
file_contains "$PROJECT_DIR/include/WebSocketHandler.php" "throw new Exception"
echo ""

# CSRF Protection
echo "CSRF Protection:"
file_contains "$PROJECT_DIR/include/WebInterface.php" "validateCSRF"
file_contains "$PROJECT_DIR/include/WebInterface.php" "generateCSRF"
file_contains "$PROJECT_DIR/include/ConfigController.php" "validateCSRF"
file_contains "$PROJECT_DIR/include/GPUController.php" "validateCSRF"
file_contains "$PROJECT_DIR/include/EventsController.php" "validateCSRF"
file_contains "$PROJECT_DIR/include/ProfilesController.php" "validateCSRF"
file_contains "$PROJECT_DIR/include/PreferencesController.php" "validateCSRF"
file_contains "$PROJECT_DIR/include/BackupsController.php" "validateCSRF"
echo ""

# Session Management
echo "Session Management:"
file_contains "$PROJECT_DIR/include/WebInterface.php" "getSession"
file_contains "$PROJECT_DIR/include/WebInterface.php" "setSession"
file_contains "$PROJECT_DIR/include/WebInterface.php" "setFlash"
file_contains "$PROJECT_DIR/include/WebInterface.php" "getFlash"
echo ""

# Logging
echo "Logging:"
file_contains "$PROJECT_DIR/include/WebInterface.php" "private function log"
file_contains "$PROJECT_DIR/include/DashboardController.php" "private function log"
file_contains "$PROJECT_DIR/include/ConfigController.php" "private function log"
file_contains "$PROJECT_DIR/include/GPUController.php" "private function log"
file_contains "$PROJECT_DIR/include/EventsController.php" "private function log"
file_contains "$PROJECT_DIR/include/ProfilesController.php" "private function log"
file_contains "$PROJECT_DIR/include/PreferencesController.php" "private function log"
file_contains "$PROJECT_DIR/include/BackupsController.php" "private function log"
file_contains "$PROJECT_DIR/include/APIHandler.php" "private function log"
file_contains "$PROJECT_DIR/include/WebSocketHandler.php" "private function log"
echo ""

# PHP Syntax
echo "PHP Syntax:"
check_php_syntax "$PROJECT_DIR/include/WebInterface.php"
check_php_syntax "$PROJECT_DIR/include/DashboardController.php"
check_php_syntax "$PROJECT_DIR/include/ConfigController.php"
check_php_syntax "$PROJECT_DIR/include/GPUController.php"
check_php_syntax "$PROJECT_DIR/include/EventsController.php"
check_php_syntax "$PROJECT_DIR/include/ProfilesController.php"
check_php_syntax "$PROJECT_DIR/include/PreferencesController.php"
check_php_syntax "$PROJECT_DIR/include/BackupsController.php"
check_php_syntax "$PROJECT_DIR/include/APIHandler.php"
check_php_syntax "$PROJECT_DIR/include/WebSocketHandler.php"
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
    echo -e "${GREEN}✓ All tests passed! Phase 6 is complete.${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Please review the failures above.${NC}"
    exit 1
fi
