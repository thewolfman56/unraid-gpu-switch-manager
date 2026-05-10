#!/bin/bash

# preference_manager.sh
# Preference manager for GPU Switch Manager
# Usage: ./preference_manager.sh <command> [arguments]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Source secure shell library
source "$SCRIPT_DIR/secure_shell_lib.sh"

CONFIG_DIR="$PROJECT_DIR/config"
PREFERENCES_DIR="$CONFIG_DIR/preferences"
USER_PREFERENCES_FILE="$PREFERENCES_DIR/user.json"
SYSTEM_PREFERENCES_FILE="$PREFERENCES_DIR/system.json"
DEFAULT_PREFERENCES_FILE="$PREFERENCES_DIR/defaults.json"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    secure_log "$level" "[PREFERENCE_MANAGER] $message"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    secure_error_exit "$1"
}

# Initialize preferences
init_preferences() {
    log "INFO" "Initializing preferences"

    # Create preferences directory
    mkdir -p "$PREFERENCES_DIR"

    # Create default preferences if they don't exist
    if [[ ! -f "$DEFAULT_PREFERENCES_FILE" ]]; then
        local default_preferences='{
  "auto_switch": true,
  "auto_backup": true,
  "backup_interval": 86400,
  "log_level": "INFO",
  "notification_enabled": true,
  "max_backups": 10,
  "backup_retention_days": 30,
  "auto_cleanup": true,
  "debug_mode": false,
  "verbose_logging": false
}'

        echo "$default_preferences" > "$DEFAULT_PREFERENCES_FILE"
        log "INFO" "Created default preferences"
    fi

    # Create user preferences if they don't exist
    if [[ ! -f "$USER_PREFERENCES_FILE" ]]; then
        echo '{}' > "$USER_PREFERENCES_FILE"
        log "INFO" "Created user preferences"
    fi

    # Create system preferences if they don't exist
    if [[ ! -f "$SYSTEM_PREFERENCES_FILE" ]]; then
        echo '{}' > "$SYSTEM_PREFERENCES_FILE"
        log "INFO" "Created system preferences"
    fi

    echo '{"success":true,"message":"Preferences initialized"}' | jq .
}

# Load preferences
load_preferences() {
    local preferences_file="${1:-$USER_PREFERENCES_FILE}"

    log "INFO" "Loading preferences from $preferences_file"

    if [[ ! -f "$preferences_file" ]]; then
        error_exit "Preferences file not found: $preferences_file"
    fi

    local preferences=$(cat "$preferences_file")

    echo "$preferences"
}

# Save preferences
save_preferences() {
    local preferences="$1"
    local preferences_file="${2:-$USER_PREFERENCES_FILE}"

    log "INFO" "Saving preferences to $preferences_file"

    # Validate preferences
    if ! echo "$preferences" | jq . >/dev/null 2>&1; then
        error_exit "Invalid JSON preferences"
    fi

    # Save preferences
    echo "$preferences" > "$preferences_file"

    echo '{"success":true,"message":"Preferences saved","preferences_file":"'"$preferences_file"'"}' | jq .
}

# Set preference
set_preference() {
    local key="$1"
    local value="$2"
    local preferences_file="${3:-$USER_PREFERENCES_FILE}"

    log "INFO" "Setting preference: $key = $value"

    validate_preference_key "$key"

    # Load existing preferences
    local preferences=$(load_preferences "$preferences_file")

    # Update preference
    local updated_preferences=$(echo "$preferences" | jq --arg key "$key" --argjson value "$value" '.[$key] = $value')

    # Save preferences
    save_preferences "$updated_preferences" "$preferences_file" >/dev/null

    echo '{"success":true,"message":"Preference set","key":"'"$key"'","value":'"$value"'}' | jq .
}

# Get preference
get_preference() {
    local key="$1"
    local preferences_file="${2:-$USER_PREFERENCES_FILE}"

    log "INFO" "Getting preference: $key"

    validate_preference_key "$key"

    local preferences=$(load_preferences "$preferences_file")
    local value=$(echo "$preferences" | jq -r ".$key")

    # Check if value exists in user preferences
    if [[ "$value" == "null" ]]; then
        # Try default preferences
        if [[ -f "$DEFAULT_PREFERENCES_FILE" ]]; then
            local default_preferences=$(cat "$DEFAULT_PREFERENCES_FILE")
            value=$(echo "$default_preferences" | jq -r ".$key")
        fi
    fi

    if [[ "$value" == "null" ]]; then
        error_exit "Preference not found: $key"
    fi

    echo '{"success":true,"key":"'"$key"'","value":'"$value"'}' | jq .
}

# Delete preference
delete_preference() {
    local key="$1"
    local preferences_file="${2:-$USER_PREFERENCES_FILE}"

    log "INFO" "Deleting preference: $key"

    validate_preference_key "$key"

    local preferences=$(load_preferences "$preferences_file")

    # Check if key exists
    if ! echo "$preferences" | jq -e ".$key" >/dev/null 2>&1; then
        error_exit "Preference not found: $key"
    fi

    # Delete preference
    local updated_preferences=$(echo "$preferences" | jq "del(.$key)")

    # Save preferences
    save_preferences "$updated_preferences" "$preferences_file" >/dev/null

    echo '{"success":true,"message":"Preference deleted","key":"'"$key"'"}' | jq .
}

# List all preferences
list_preferences() {
    local preferences_file="${1:-$USER_PREFERENCES_FILE}"

    log "INFO" "Listing all preferences"

    local preferences=$(load_preferences "$preferences_file")

    echo '{"success":true,"preferences":'"$preferences"'}' | jq .
}

# Reset preference to default
reset_preference() {
    local key="$1"
    local preferences_file="${2:-$USER_PREFERENCES_FILE}"

    log "INFO" "Resetting preference: $key"

    validate_preference_key "$key"

    # Check if default exists
    if [[ ! -f "$DEFAULT_PREFERENCES_FILE" ]]; then
        error_exit "Default preferences file not found"
    fi

    local default_preferences=$(cat "$DEFAULT_PREFERENCES_FILE")
    local default_value=$(echo "$default_preferences" | jq -r ".$key")

    if [[ "$default_value" == "null" ]]; then
        error_exit "Default preference not found: $key"
    fi

    # Set preference to default value
    set_preference "$key" "$default_value" "$preferences_file" >/dev/null

    echo '{"success":true,"message":"Preference reset to default","key":"'"$key"'","default_value":'"$default_value"'}' | jq .
}

# Reset all preferences
reset_all_preferences() {
    local preferences_file="${1:-$USER_PREFERENCES_FILE}"

    log "INFO" "Resetting all preferences"

    # Check if default exists
    if [[ ! -f "$DEFAULT_PREFERENCES_FILE" ]]; then
        error_exit "Default preferences file not found"
    fi

    # Copy default preferences
    cp "$DEFAULT_PREFERENCES_FILE" "$preferences_file"

    echo '{"success":true,"message":"All preferences reset to defaults"}' | jq .
}

# Validate preference
validate_preference() {
    local key="$1"
    local value="$2"

    log "INFO" "Validating preference: $key"

    validate_preference_key "$key"

    local errors='[]'

    # Check if value is valid JSON
    if ! echo "$value" | jq . >/dev/null 2>&1; then
        errors=$(echo "$errors" | jq '. + [{"error":"Invalid JSON value"}]')
    fi

    # Check specific preference types
    case "$key" in
        auto_switch|auto_backup|notification_enabled|auto_cleanup|debug_mode|verbose_logging)
            if ! echo "$value" | jq -e 'type == "boolean"' >/dev/null 2>&1; then
                errors=$(echo "$errors" | jq '. + [{"error":"Value must be boolean"}]')
            fi
            ;;
        backup_interval|max_backups|backup_retention_days)
            if ! echo "$value" | jq -e 'type == "number"' >/dev/null 2>&1; then
                errors=$(echo "$errors" | jq '. + [{"error":"Value must be number"}]')
            fi
            ;;
        log_level)
            if ! echo "$value" | jq -e 'type == "string"' >/dev/null 2>&1; then
                errors=$(echo "$errors" | jq '. + [{"error":"Value must be string"}]')
            fi
            local valid_levels=("DEBUG" "INFO" "WARN" "ERROR")
            local level=$(echo "$value" | jq -r '.')
            local valid=false
            for valid_level in "${valid_levels[@]}"; do
                if [[ "$level" == "$valid_level" ]]; then
                    valid=true
                    break
                fi
            done
            if [[ "$valid" == "false" ]]; then
                errors=$(echo "$errors" | jq '. + [{"error":"Invalid log level"}]')
            fi
            ;;
    esac

    # Build result
    local error_count=$(echo "$errors" | jq 'length')
    local valid=$([[ $error_count -eq 0 ]] && echo "true" || echo "false")

    echo '{"valid":'"$valid"',"key":"'"$key"'","errors":'"$errors"',"error_count":'"$error_count"'}' | jq .
}

# Get default preference
get_default_preference() {
    local key="$1"

    log "INFO" "Getting default preference: $key"

    validate_preference_key "$key"

    if [[ ! -f "$DEFAULT_PREFERENCES_FILE" ]]; then
        error_exit "Default preferences file not found"
    fi

    local default_preferences=$(cat "$DEFAULT_PREFERENCES_FILE")
    local value=$(echo "$default_preferences" | jq -r ".$key")

    if [[ "$value" == "null" ]]; then
        error_exit "Default preference not found: $key"
    fi

    echo '{"success":true,"key":"'"$key"'","default_value":'"$value"'}' | jq .
}

# Merge preferences
merge_preferences() {
    local base_preferences="$1"
    local override_preferences="$2"
    local preferences_file="${3:-$USER_PREFERENCES_FILE}"

    log "INFO" "Merging preferences"

    # Validate preferences
    if ! echo "$base_preferences" | jq . >/dev/null 2>&1; then
        error_exit "Invalid base preferences"
    fi

    if ! echo "$override_preferences" | jq . >/dev/null 2>&1; then
        error_exit "Invalid override preferences"
    fi

    # Merge preferences
    local merged_preferences=$(echo "$base_preferences" "$override_preferences" | jq -s '.[0] * .[1]')

    # Save preferences
    save_preferences "$merged_preferences" "$preferences_file" >/dev/null

    echo '{"success":true,"message":"Preferences merged","preferences_file":"'"$preferences_file"'"}' | jq .
}

# Export preferences
export_preferences() {
    local preferences_file="${1:-$USER_PREFERENCES_FILE}"

    log "INFO" "Exporting preferences"

    local preferences=$(load_preferences "$preferences_file")

    echo "$preferences" | jq .
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
            init_preferences
            ;;
        load)
            load_preferences "$@"
            ;;
        save)
            save_preferences "$@"
            ;;
        set)
            set_preference "$@"
            ;;
        get)
            get_preference "$@"
            ;;
        delete)
            delete_preference "$@"
            ;;
        list)
            list_preferences "$@"
            ;;
        reset)
            reset_preference "$@"
            ;;
        reset-all)
            reset_all_preferences "$@"
            ;;
        validate)
            validate_preference "$@"
            ;;
        default)
            get_default_preference "$@"
            ;;
        merge)
            merge_preferences "$@"
            ;;
        export)
            export_preferences "$@"
            ;;
        *)
            error_exit "Unknown command: $command"
            ;;
    esac
}

# Run main function
main "$@"
