#!/bin/bash

# config_migrate.sh
# Configuration migration manager for GPU Switch Manager
# Usage: ./config_migrate.sh <command> [arguments]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_DIR/config"
CONFIG_FILE="$CONFIG_DIR/config.json"
MIGRATION_DIR="$CONFIG_DIR/migrations"
# Source secure shell library
source "$SCRIPT_DIR/secure_shell_lib.sh"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    secure_log "$level" "[CONFIG_MIGRATE] $message"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    secure_error_exit "$1"
}

# Initialize migration directory
init_migration_dir() {
    log "INFO" "Initializing migration directory"

    # Create migration directory
    mkdir -p "$MIGRATION_DIR"

    echo '{"success":true,"message":"Migration directory initialized","migration_dir":"'"$MIGRATION_DIR"'"}' | jq .
}

# Detect configuration version
detect_version() {
    local config_path="${1:-$CONFIG_FILE}"

    log "INFO" "Detecting configuration version"

    if [[ ! -f "$config_path" ]]; then
        error_exit "Configuration file not found: $config_path"
    fi

    local config=$(cat "$config_path")
    local version=$(echo "$config" | jq -r '.version // "0.0.0"')

    echo '{"success":true,"version":"'"$version"'","config_path":"'"$config_path"'"}' | jq .
}

# Upgrade configuration
upgrade_config() {
    local config_path="${1:-$CONFIG_FILE}"
    local target_version="${2:-latest}"

    log "INFO" "Upgrading configuration to $target_version"

    if [[ ! -f "$config_path" ]]; then
        error_exit "Configuration file not found: $config_path"
    fi

    # Detect current version
    local current_version=$(detect_version "$config_path" | jq -r '.version')

    # Get target version
    if [[ "$target_version" == "latest" ]]; then
        target_version="1.0.0"
    fi

    # Check if upgrade is needed
    if [[ "$current_version" == "$target_version" ]]; then
        echo '{"success":true,"message":"Configuration already at target version","current_version":"'"$current_version"'","target_version":"'"$target_version"'"}' | jq .
        return
    fi

    # Create backup
    local backup_file="$CONFIG_DIR/backups/config_$(date +%Y%m%d_%H%M%S).json"
    mkdir -p "$CONFIG_DIR/backups"
    cp "$config_path" "$backup_file"
    log "INFO" "Created backup: $backup_file"

    # Load configuration
    local config=$(cat "$config_path")

    # Apply migrations based on version
    local updated_config="$config"

    # Migration from 0.0.0 to 1.0.0
    if [[ "$current_version" == "0.0.0" ]]; then
        log "INFO" "Applying migration from 0.0.0 to 1.0.0"

        # Add version field
        updated_config=$(echo "$updated_config" | jq '.version = "1.0.0"')

        # Ensure required fields exist
        updated_config=$(echo "$updated_config" | jq '.profiles = .profiles // {}')
        updated_config=$(echo "$updated_config" | jq '.preferences = .preferences // {}')
        updated_config=$(echo "$updated_config" | jq '.services = .services // {}')

        # Add default safety checks to profiles
        updated_config=$(echo "$updated_config" | jq '.profiles |= with_entries(.value.safety_checks = .value.safety_checks // {"check_active_usage": true, "check_dependencies": true, "check_resources": true})')
    fi

    # Save updated configuration
    echo "$updated_config" > "$config_path"

    echo '{"success":true,"message":"Configuration upgraded","current_version":"'"$current_version"'","target_version":"'"$target_version"'","backup_file":"'"$backup_file"'"}' | jq .
}

# Downgrade configuration
downgrade_config() {
    local config_path="${1:-$CONFIG_FILE}"
    local target_version="$2"

    log "INFO" "Downgrading configuration to $target_version"

    if [[ ! -f "$config_path" ]]; then
        error_exit "Configuration file not found: $config_path"
    fi

    # Detect current version
    local current_version=$(detect_version "$config_path" | jq -r '.version')

    # Check if downgrade is needed
    if [[ "$current_version" == "$target_version" ]]; then
        echo '{"success":true,"message":"Configuration already at target version","current_version":"'"$current_version"'","target_version":"'"$target_version"'"}' | jq .
        return
    fi

    # Create backup
    local backup_file="$CONFIG_DIR/backups/config_$(date +%Y%m%d_%H%M%S).json"
    mkdir -p "$CONFIG_DIR/backups"
    cp "$config_path" "$backup_file"
    log "INFO" "Created backup: $backup_file"

    # Load configuration
    local config=$(cat "$config_path")

    # Apply downgrades based on version
    local updated_config="$config"

    # Downgrade from 1.0.0 to 0.0.0
    if [[ "$current_version" == "1.0.0" ]] && [[ "$target_version" == "0.0.0" ]]; then
        log "INFO" "Applying downgrade from 1.0.0 to 0.0.0"

        # Remove version field
        updated_config=$(echo "$updated_config" | jq 'del(.version)')

        # Remove safety checks from profiles
        updated_config=$(echo "$updated_config" | jq '.profiles |= with_entries(del(.value.safety_checks))')
    fi

    # Save updated configuration
    echo "$updated_config" > "$config_path"

    echo '{"success":true,"message":"Configuration downgraded","current_version":"'"$current_version"'","target_version":"'"$target_version"'","backup_file":"'"$backup_file"'"}' | jq .
}

# Validate migration
validate_migration() {
    local config_path="${1:-$CONFIG_FILE}"
    local target_version="${2:-latest}"

    log "INFO" "Validating migration to $target_version"

    if [[ ! -f "$config_path" ]]; then
        error_exit "Configuration file not found: $config_path"
    fi

    local valid=true
    local errors='[]'

    # Detect current version
    local current_version=$(detect_version "$config_path" | jq -r '.version')

    # Get target version
    if [[ "$target_version" == "latest" ]]; then
        target_version="1.0.0"
    fi

    # Check if migration is possible
    if [[ "$current_version" == "$target_version" ]]; then
        errors=$(echo "$errors" | jq '. + ["Configuration already at target version"]')
        valid=false
    fi

    # Check if target version is supported
    case "$target_version" in
        0.0.0|1.0.0)
            # Supported version
            ;;
        *)
            errors=$(echo "$errors" | jq '. + ["Unsupported target version: '"$target_version"'"]')
            valid=false
            ;;
    esac

    echo '{"valid":'"$valid"',"current_version":"'"$current_version"'","target_version":"'"$target_version"'","errors":'"$errors"'}' | jq .
}

# Rollback migration
rollback_migration() {
    local backup_file="$1"
    local config_path="${2:-$CONFIG_FILE}"

    log "INFO" "Rolling back migration from $backup_file"

    if [[ ! -f "$backup_file" ]]; then
        error_exit "Backup file not found: $backup_file"
    fi

    # Restore backup
    cp "$backup_file" "$config_path"

    echo '{"success":true,"message":"Migration rolled back","config_path":"'"$config_path"'"}' | jq .
}

# Get migration path
get_migration_path() {
    local config_path="${1:-$CONFIG_FILE}"
    local target_version="${2:-latest}"

    log "INFO" "Getting migration path"

    if [[ ! -f "$config_path" ]]; then
        error_exit "Configuration file not found: $config_path"
    fi

    # Detect current version
    local current_version=$(detect_version "$config_path" | jq -r '.version')

    # Get target version
    if [[ "$target_version" == "latest" ]]; then
        target_version="1.0.0"
    fi

    # Determine migration path
    local path='[]'
    local direction="none"

    if [[ "$current_version" < "$target_version" ]]; then
        direction="upgrade"
        path=$(echo "$path" | jq '. + ["'"$current_version"' -> '"$target_version"' (upgrade)"]')
    elif [[ "$current_version" > "$target_version" ]]; then
        direction="downgrade"
        path=$(echo "$path" | jq '. + ["'"$current_version"' -> '"$target_version"' (downgrade)"]')
    else
        direction="none"
        path=$(echo "$path" | jq '. + ["No migration needed"]')
    fi

    echo '{"success":true,"current_version":"'"$current_version"'","target_version":"'"$target_version"'","direction":"'"$direction"'","path":'"$path"'}' | jq .
}

# Test migration
test_migration() {
    local config_path="${1:-$CONFIG_FILE}"
    local target_version="${2:-latest}"

    log "INFO" "Testing migration to $target_version"

    if [[ ! -f "$config_path" ]]; then
        error_exit "Configuration file not found: $config_path"
    fi

    # Create test copy
    local test_config="/tmp/config_test_$$"
    cp "$config_path" "$test_config"

    # Test migration
    local result
    if upgrade_config "$test_config" "$target_version" >/dev/null 2>&1; then
        result="success"
    else
        result="failed"
    fi

    # Cleanup test copy
    rm -f "$test_config"

    echo '{"success":true,"result":"'"$result"'","target_version":"'"$target_version"'"}' | jq .
}

# Get available versions
get_available_versions() {
    log "INFO" "Getting available versions"

    local versions='[
  {"version":"0.0.0","description":"Initial version"},
  {"version":"1.0.0","description":"Current version with safety checks"}
]'

    echo '{"success":true,"versions":'"$versions"'}' | jq .
}

# Main function
main() {
    # Check arguments
    if [[ $# -lt 1 ]]; then
        error_exit "Usage: $0 <command> [arguments]"
    fi

    local command="$1"
    shift

    case "$command" in
        init)
            init_migration_dir
            ;;
        detect)
            detect_version "$@"
            ;;
        upgrade)
            upgrade_config "$@"
            ;;
        downgrade)
            downgrade_config "$@"
            ;;
        validate)
            validate_migration "$@"
            ;;
        rollback)
            rollback_migration "$@"
            ;;
        path)
            get_migration_path "$@"
            ;;
        test)
            test_migration "$@"
            ;;
        versions)
            get_available_versions
            ;;
        *)
            error_exit "Unknown command: $command"
            ;;
    esac
}

# Run main function
main "$@"
