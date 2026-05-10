#!/bin/bash

# config_manager.sh
# Configuration manager for GPU Switch Manager
# Usage: ./config_manager.sh <command> [arguments]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Source secure shell library
source "$SCRIPT_DIR/secure_shell_lib.sh"

CONFIG_DIR="$PROJECT_DIR/config"
CONFIG_FILE="$CONFIG_DIR/config.json"
CONFIG_LOCK="$CONFIG_DIR/config.lock"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    secure_log "$level" "[CONFIG_MANAGER] $message"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    secure_error_exit "$1"
}

# Initialize configuration system
init_config() {
    log "INFO" "Initializing configuration system"

    # Create configuration directory
    mkdir -p "$CONFIG_DIR/profiles"
    mkdir -p "$CONFIG_DIR/preferences"
    mkdir -p "$CONFIG_DIR/services"
    mkdir -p "$CONFIG_DIR/templates"
    mkdir -p "$CONFIG_DIR/backups"

    # Create default configuration if it doesn't exist
    if [[ ! -f "$CONFIG_FILE" ]]; then
        local default_config='{
  "version": "1.0.0",
  "profiles": {
    "default": {
      "name": "default",
      "description": "Default GPU switching profile",
      "gpu_bindings": {},
      "service_preferences": {},
      "event_handlers": {},
      "safety_checks": {
        "check_active_usage": true,
        "check_dependencies": true,
        "check_resources": true
      },
      "created_at": "'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'",
      "updated_at": "'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"
    }
  },
  "preferences": {
    "auto_switch": true,
    "auto_backup": true,
    "backup_interval": 86400,
    "log_level": "INFO",
    "notification_enabled": true
  },
  "services": {
    "docker": {
      "auto_restart": true,
      "graceful_shutdown": true,
      "timeout": 30
    },
    "vm": {
      "auto_restart": false,
      "graceful_shutdown": true,
      "timeout": 60
    }
  }
}'

        echo "$default_config" > "$CONFIG_FILE"
        log "INFO" "Created default configuration"
    fi

    echo '{"success":true,"message":"Configuration system initialized","config_dir":"'"$CONFIG_DIR"'"}' | jq .
}

# Load configuration from file
load_config() {
    local config_path="${1:-$CONFIG_FILE}"

    log "INFO" "Loading configuration from $config_path"

    if [[ ! -f "$config_path" ]]; then
        error_exit "Configuration file not found: $config_path"
    fi

    # Acquire lock
    exec 200>"$CONFIG_LOCK"
    flock -n 200 || error_exit "Configuration file is locked"

    # Read configuration
    local config=$(cat "$config_path")

    # Release lock
    flock -u 200

    echo "$config"
}

# Save configuration to file
save_config() {
    local config="$1"
    local config_path="${2:-$CONFIG_FILE}"

    log "INFO" "Saving configuration to $config_path"

    # Validate configuration
    if ! echo "$config" | jq . >/dev/null 2>&1; then
        error_exit "Invalid JSON configuration"
    fi

    # Acquire lock
    exec 200>"$CONFIG_LOCK"
    flock -n 200 || error_exit "Configuration file is locked"

    # Create backup before saving
    local backup_file="$CONFIG_DIR/backups/config_$(date +%Y%m%d_%H%M%S).json"
    if [[ -f "$config_path" ]]; then
        cp "$config_path" "$backup_file"
        log "INFO" "Created backup: $backup_file"
    fi

    # Save configuration
    echo "$config" > "$config_path"

    # Release lock
    flock -u 200

    echo '{"success":true,"message":"Configuration saved","config_path":"'"$config_path"'","backup":"'"$backup_file"'"}' | jq .
}

# Get configuration value
get_config_value() {
    local key="$1"
    local config_path="${2:-$CONFIG_FILE}"

    log "INFO" "Getting configuration value: $key"

    local config=$(load_config "$config_path")
    local value=$(echo "$config" | jq -r ".$key")

    if [[ "$value" == "null" ]]; then
        error_exit "Configuration value not found: $key"
    fi

    echo '{"success":true,"key":"'"$key"'","value":'"$value"'}' | jq .
}

# Set configuration value
set_config_value() {
    local key="$1"
    local value="$2"
    local config_path="${3:-$CONFIG_FILE}"

    log "INFO" "Setting configuration value: $key = $value"

    local config=$(load_config "$config_path")

    # Update configuration
    local updated_config=$(echo "$config" | jq --arg key "$key" --argjson value "$value" '.[$key] = $value')

    # Save configuration
    save_config "$updated_config" "$config_path" >/dev/null

    echo '{"success":true,"message":"Configuration value set","key":"'"$key"'","value":'"$value"'}' | jq .
}

# Delete configuration value
delete_config_value() {
    local key="$1"
    local config_path="${2:-$CONFIG_FILE}"

    log "INFO" "Deleting configuration value: $key"

    local config=$(load_config "$config_path")

    # Check if key exists
    if ! echo "$config" | jq -e ".$key" >/dev/null 2>&1; then
        error_exit "Configuration value not found: $key"
    fi

    # Delete configuration value
    local updated_config=$(echo "$config" | jq "del(.$key)")

    # Save configuration
    save_config "$updated_config" "$config_path" >/dev/null

    echo '{"success":true,"message":"Configuration value deleted","key":"'"$key"'"}' | jq .
}

# Validate configuration
validate_config() {
    local config="${1:-$(load_config)}"

    log "INFO" "Validating configuration"

    local errors='[]'

    # Check if valid JSON
    if ! echo "$config" | jq . >/dev/null 2>&1; then
        errors=$(echo "$errors" | jq '. + [{"error":"Invalid JSON configuration"}]')
    fi

    # Check required fields
    local required_fields=("version" "profiles" "preferences" "services")
    for field in "${required_fields[@]}"; do
        if ! echo "$config" | jq -e ".$field" >/dev/null 2>&1; then
            errors=$(echo "$errors" | jq '. + [{"error":"Missing required field: '"$field"'"}]')
        fi
    done

    # Check version format
    local version=$(echo "$config" | jq -r '.version')
    if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        errors=$(echo "$errors" | jq '. + [{"error":"Invalid version format: '"$version"'"}]')
    fi

    # Check profiles
    local profiles=$(echo "$config" | jq '.profiles')
    if ! echo "$profiles" | jq . >/dev/null 2>&1; then
        errors=$(echo "$errors" | jq '. + [{"error":"Invalid profiles format"}]')
    fi

    # Check preferences
    local preferences=$(echo "$config" | jq '.preferences')
    if ! echo "$preferences" | jq . >/dev/null 2>&1; then
        errors=$(echo "$errors" | jq '. + [{"error":"Invalid preferences format"}]')
    fi

    # Check services
    local services=$(echo "$config" | jq '.services')
    if ! echo "$services" | jq . >/dev/null 2>&1; then
        errors=$(echo "$errors" | jq '. + [{"error":"Invalid services format"}]')
    fi

    # Build result
    local error_count=$(echo "$errors" | jq 'length')
    local valid=$([[ $error_count -eq 0 ]] && echo "true" || echo "false")

    echo '{"valid":'"$valid"',"errors":'"$errors"',"error_count":'"$error_count"'}' | jq .
}

# Merge configurations
merge_config() {
    local base_config="$1"
    local override_config="$2"
    local config_path="${3:-$CONFIG_FILE}"

    log "INFO" "Merging configurations"

    # Validate configurations
    if ! echo "$base_config" | jq . >/dev/null 2>&1; then
        error_exit "Invalid base configuration"
    fi

    if ! echo "$override_config" | jq . >/dev/null 2>&1; then
        error_exit "Invalid override configuration"
    fi

    # Merge configurations
    local merged_config=$(echo "$base_config" "$override_config" | jq -s '.[0] * .[1]')

    # Save configuration
    save_config "$merged_config" "$config_path" >/dev/null

    echo '{"success":true,"message":"Configurations merged","config_path":"'"$config_path"'"}' | jq .
}

# Backup configuration
backup_config() {
    local config_path="${1:-$CONFIG_FILE}"

    log "INFO" "Backing up configuration"

    if [[ ! -f "$config_path" ]]; then
        error_exit "Configuration file not found: $config_path"
    fi

    # Create backup file
    local backup_file="$CONFIG_DIR/backups/config_$(date +%Y%m%d_%H%M%S).json"
    cp "$config_path" "$backup_file"

    # Compress backup
    gzip -f "$backup_file"
    backup_file="${backup_file}.gz"

    echo '{"success":true,"message":"Configuration backed up","backup_file":"'"$backup_file"'"}' | jq .
}

# Restore configuration
restore_config() {
    local backup_file="$1"
    local config_path="${2:-$CONFIG_FILE}"

    log "INFO" "Restoring configuration from $backup_file"

    if [[ ! -f "$backup_file" ]]; then
        error_exit "Backup file not found: $backup_file"
    fi

    # Decompress if needed
    local temp_file="$backup_file.tmp"
    if [[ "$backup_file" == *.gz ]]; then
        gunzip -c "$backup_file" > "$temp_file"
    else
        cp "$backup_file" "$temp_file"
    fi

    # Validate backup
    if ! cat "$temp_file" | jq . >/dev/null 2>&1; then
        rm -f "$temp_file"
        error_exit "Invalid backup file"
    fi

    # Create backup of current configuration
    backup_config "$config_path" >/dev/null

    # Restore configuration
    cp "$temp_file" "$config_path"
    rm -f "$temp_file"

    echo '{"success":true,"message":"Configuration restored","config_path":"'"$config_path"'"}' | jq .
}

# Get configuration version
get_config_version() {
    local config_path="${1:-$CONFIG_FILE}"

    log "INFO" "Getting configuration version"

    local config=$(load_config "$config_path")
    local version=$(echo "$config" | jq -r '.version')

    echo '{"success":true,"version":"'"$version"'"}' | jq .
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
            init_config
            ;;
        load)
            load_config "$@"
            ;;
        save)
            save_config "$@"
            ;;
        get)
            get_config_value "$@"
            ;;
        set)
            set_config_value "$@"
            ;;
        delete)
            delete_config_value "$@"
            ;;
        validate)
            validate_config "$@"
            ;;
        merge)
            merge_config "$@"
            ;;
        backup)
            backup_config "$@"
            ;;
        restore)
            restore_config "$@"
            ;;
        version)
            get_config_version "$@"
            ;;
        *)
            error_exit "Unknown command: $command"
            ;;
    esac
}

# Run main function
main "$@"
