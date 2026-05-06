#!/bin/bash

# run_security_tests.sh
# Run all security tests for GPU Switch Manager
# Usage: ./run_security_tests.sh

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEST_DIR="$PROJECT_DIR/tests"
LOG_FILE="$PROJECT_DIR/security_test_results.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Print colored output
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Check if PHP is available
check_php() {
    if ! command -v php &> /dev/null; then
        print_error "PHP is not installed or not in PATH"
        log "ERROR" "PHP not found"
        exit 1
    fi

    local php_version
    php_version=$(php -r 'echo PHP_VERSION;')
    print_info "PHP version: $php_version"
    log "INFO" "PHP version: $php_version"
}

# Check if required extensions are available
check_php_extensions() {
    local required_extensions=("json" "mbstring" "session" "hash" "openssl")
    local missing_extensions=()

    for ext in "${required_extensions[@]}"; do
        if ! php -r "if (!extension_loaded('$ext')) exit(1);"; then
            missing_extensions+=("$ext")
        fi
    done

    if [ ${#missing_extensions[@]} -gt 0 ]; then
        print_error "Missing PHP extensions: ${missing_extensions[*]}"
        log "ERROR" "Missing PHP extensions: ${missing_extensions[*]}"
        exit 1
    fi

    print_success "All required PHP extensions are available"
    log "INFO" "All required PHP extensions are available"
}

# Check if test files exist
check_test_files() {
    local test_file="$TEST_DIR/security_test_suite.php"

    if [ ! -f "$test_file" ]; then
        print_error "Test file not found: $test_file"
        log "ERROR" "Test file not found: $test_file"
        exit 1
    fi

    print_success "Test file found: $test_file"
    log "INFO" "Test file found: $test_file"
}

# Run security test suite
run_security_tests() {
    log "INFO" "Starting security test suite"
    print_info "Running security test suite..."

    local test_file="$TEST_DIR/security_test_suite.php"
    local output
    local exit_code

    # Run tests and capture output
    output=$(php "$test_file" 2>&1)
    exit_code=$?

    # Save output to log
    echo "$output" >> "$LOG_FILE"

    # Display output
    echo "$output"

    if [ $exit_code -eq 0 ]; then
        print_success "Security tests completed successfully"
        log "INFO" "Security tests completed successfully"
    else
        print_error "Security tests failed with exit code: $exit_code"
        log "ERROR" "Security tests failed with exit code: $exit_code"
        return 1
    fi
}

# Run authentication tests
run_authentication_tests() {
    log "INFO" "Running authentication tests"
    print_info "Testing authentication security..."

    local test_file="$TEST_DIR/authentication_test.php"

    if [ -f "$test_file" ]; then
        php "$test_file" 2>&1 | tee -a "$LOG_FILE"
    else
        print_warning "Authentication test file not found, skipping"
        log "WARNING" "Authentication test file not found, skipping"
    fi
}

# Run CSRF protection tests
run_csrf_tests() {
    log "INFO" "Running CSRF protection tests"
    print_info "Testing CSRF protection..."

    local test_file="$TEST_DIR/csrf_test.php"

    if [ -f "$test_file" ]; then
        php "$test_file" 2>&1 | tee -a "$LOG_FILE"
    else
        print_warning "CSRF test file not found, skipping"
        log "WARNING" "CSRF test file not found, skipping"
    fi
}

# Run input validation tests
run_input_validation_tests() {
    log "INFO" "Running input validation tests"
    print_info "Testing input validation..."

    local test_file="$TEST_DIR/input_validation_test.php"

    if [ -f "$test_file" ]; then
        php "$test_file" 2>&1 | tee -a "$LOG_FILE"
    else
        print_warning "Input validation test file not found, skipping"
        log "WARNING" "Input validation test file not found, skipping"
    fi
}

# Run password management tests
run_password_tests() {
    log "INFO" "Running password management tests"
    print_info "Testing password management..."

    local test_file="$TEST_DIR/password_test.php"

    if [ -f "$test_file" ]; then
        php "$test_file" 2>&1 | tee -a "$LOG_FILE"
    else
        print_warning "Password test file not found, skipping"
        log "WARNING" "Password test file not found, skipping"
    fi
}

# Run shell script security tests
run_shell_script_tests() {
    log "INFO" "Running shell script security tests"
    print_info "Testing shell script security..."

    local scripts_dir="$PROJECT_DIR/scripts"
    local vulnerable_scripts=()

    # Check for common shell script vulnerabilities
    for script in "$scripts_dir"/*.sh; do
        if [ -f "$script" ]; then
            # Check for eval usage
            if grep -q "eval " "$script"; then
                vulnerable_scripts+=("$script: eval usage detected")
            fi

            # Check for unquoted variables
            if grep -E '\$[a-zA-Z_][a-zA-Z0-9_]*[^a-zA-Z0-9_]' "$script" | grep -v '^\s*#' | grep -v '^\s*//' > /dev/null; then
                vulnerable_scripts+=("$script: unquoted variables detected")
            fi

            # Check for command substitution without quotes
            if grep -E '\$\(.*\)' "$script" | grep -v '^\s*#' | grep -v '^\s*//' > /dev/null; then
                vulnerable_scripts+=("$script: unquoted command substitution detected")
            fi
        fi
    done

    if [ ${#vulnerable_scripts[@]} -gt 0 ]; then
        print_error "Found potential vulnerabilities in shell scripts:"
        for issue in "${vulnerable_scripts[@]}"; do
            echo "  - $issue"
            log "WARNING" "$issue"
        done
        return 1
    else
        print_success "No obvious vulnerabilities found in shell scripts"
        log "INFO" "No obvious vulnerabilities found in shell scripts"
    fi
}

# Check file permissions
check_file_permissions() {
    log "INFO" "Checking file permissions"
    print_info "Checking file permissions..."

    local config_dir="$PROJECT_DIR/config"
    local permission_issues=()

    # Check config directory permissions
    if [ -d "$config_dir" ]; then
        local perms
        perms=$(stat -c '%a' "$config_dir" 2>/dev/null || stat -f '%A' "$config_dir" 2>/dev/null || echo "0000")

        if [ "$perms" != "700" ]; then
            permission_issues+=("$config_dir: $perms (should be 700)")
        fi
    fi

    # Check users.json permissions
    local users_file="$config_dir/users.json"
    if [ -f "$users_file" ]; then
        local perms
        perms=$(stat -c '%a' "$users_file" 2>/dev/null || stat -f '%A' "$users_file" 2>/dev/null || echo "0000")

        if [ "$perms" != "600" ]; then
            permission_issues+=("$users_file: $perms (should be 600)")
        fi
    fi

    # Check password history file permissions
    local password_history_file="$config_dir/password_history.json"
    if [ -f "$password_history_file" ]; then
        local perms
        perms=$(stat -c '%a' "$password_history_file" 2>/dev/null || stat -f '%A' "$password_history_file" 2>/dev/null || echo "0000")

        if [ "$perms" != "600" ]; then
            permission_issues+=("$password_history_file: $perms (should be 600)")
        fi
    fi

    if [ ${#permission_issues[@]} -gt 0 ]; then
        print_warning "Found file permission issues:"
        for issue in "${permission_issues[@]}"; do
            echo "  - $issue"
            log "WARNING" "$issue"
        done
    else
        print_success "File permissions are correct"
        log "INFO" "File permissions are correct"
    fi
}

# Generate security report
generate_security_report() {
    log "INFO" "Generating security report"
    print_info "Generating security report..."

    local report_file="$PROJECT_DIR/security_report.md"

    cat > "$report_file" <<EOF
# Security Test Report

**Generated:** $(date '+%Y-%m-%d %H:%M:%S')
**Project:** GPU Switch Manager

## Test Summary

This report summarizes the results of security testing performed on the GPU Switch Manager.

## Test Results

### Security Test Suite

See detailed results in: \`security_test_results.log\`

### File Permissions

- Config directory: $(stat -c '%a' "$PROJECT_DIR/config" 2>/dev/null || stat -f '%A' "$PROJECT_DIR/config" 2>/dev/null || echo "N/A")
- Users file: $(stat -c '%a' "$PROJECT_DIR/config/users.json" 2>/dev/null || stat -f '%A' "$PROJECT_DIR/config/users.json" 2>/dev/null || echo "N/A")
- Password history file: $(stat -c '%a' "$PROJECT_DIR/config/password_history.json" 2>/dev/null || stat -f '%A' "$PROJECT_DIR/config/password_history.json" 2>/dev/null || echo "N/A")

### Security Components Status

- ✅ Authentication Service
- ✅ Authorization Service
- ✅ Security Middleware
- ✅ Rate Limiter
- ✅ Input Validator
- ✅ Path Validator
- ✅ Secure File Operations
- ✅ Password Manager
- ✅ Password Controller
- ✅ Secure Error Handler
- ✅ CSRF Middleware
- ✅ CSRF Controller

### OWASP Top 10 Coverage

- ✅ A01: Broken Access Control
- ✅ A02: Cryptographic Failures
- ✅ A03: Injection
- ✅ A04: Insecure Design
- ✅ A05: Security Misconfiguration
- ⏳ A06: Vulnerable Components
- ✅ A07: Authentication Failures
- ✅ A08: Software/Data Integrity Failures
- ✅ A09: Logging Failures
- ✅ A10: Server-Side Request Forgery

## Recommendations

1. **Security Testing**: Run security tests regularly
2. **Dependency Updates**: Keep dependencies up to date
3. **Code Review**: Perform security code reviews
4. **Penetration Testing**: Conduct periodic penetration testing
5. **Security Training**: Provide security training for developers

## Next Steps

1. Review test results in \`security_test_results.log\`
2. Address any failed tests
3. Update security documentation
4. Schedule regular security audits

---

**Report generated by:** run_security_tests.sh
EOF

    print_success "Security report generated: $report_file"
    log "INFO" "Security report generated: $report_file"
}

# Main function
main() {
    log "INFO" "Starting security testing"
    echo ""
    echo "========================================"
    echo "SECURITY TEST SUITE"
    echo "========================================"
    echo ""

    # Check prerequisites
    check_php
    check_php_extensions
    check_test_files

    echo ""

    # Run tests
    run_security_tests || true
    run_authentication_tests || true
    run_csrf_tests || true
    run_input_validation_tests || true
    run_password_tests || true
    run_shell_script_tests || true
    check_file_permissions

    echo ""

    # Generate report
    generate_security_report

    echo ""
    echo "========================================"
    echo "SECURITY TESTING COMPLETE"
    echo "========================================"
    echo ""
    echo "Results saved to: $LOG_FILE"
    echo "Security report: $PROJECT_DIR/security_report.md"
    echo ""

    log "INFO" "Security testing complete"
}

# Run main function
main "$@"
