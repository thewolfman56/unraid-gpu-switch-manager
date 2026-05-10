#!/bin/bash

# profile_manager.sh
# Profile manager for GPU Switch Manager
# Usage: ./profile_manager.sh <command> [arguments]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Source secure shell library
source "$SCRIPT_DIR/secure_shell_lib.sh"

CONFIG_DIR="$PROJECT_DIR/config"
PROFILES_DIR="$CONFIG_DIR/profiles"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    secure_log "$level" "[PROFILE_MANAGER] $message"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    secure_error_exit "$1"
}

# Create new profile
create_profile() {
    local profile_name="$1"
    local description="${2:-}"
    local config="${3:-}"

    log "INFO" "Creating profile: $profile_name"

    validate_profile_name "$profile_name"

    local profile_file="$PROFILES_DIR/$profile_name.json"

    if [[ -f "$profile_file" ]]; then
        error_exit "Profile already exists: $profile_name"
    fi

    # Create profile
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    local profile='{
  "name": "'"$profile_name"'",
  "description": "'"$description"'",
  "gpu_bindings": {},
  "service_preferences": {},
  "event_handlers": {},
  "safety_checks": {
    "check_active_usage": true,
    "check_dependencies": true,
    "check_resources": true
  },
  "created_at": "'"$timestamp"'",
  "updated_at": "'"$timestamp"'"
}'

    # Merge with provided config if available
    if [[ -n "$config" ]]; then
        if echo "$config" | jq . >/dev/null 2>&1; then
            profile=$(echo "$profile" "$config" | jq -s '.[0] * .[1]')
        else
            error_exit "Invalid profile configuration"
        fi
    fi

    # Save profile
    echo "$profile" > "$profile_file"

    echo '{"success":true,"message":"Profile created","profile_name":"'"$profile_name"'","profile_file":"'"$profile_file"'"}' | jq .
}

# Read profile
read_profile() {
    local profile_name="$1"

    log "INFO" "Reading profile: $profile_name"

    validate_profile_name "$profile_name"

    local profile_file="$PROFILES_DIR/$profile_name.json"

    if [[ ! -f "$profile_file" ]]; then
        error_exit "Profile not found: $profile_name"
    fi

    local profile=$(cat "$profile_file")

    echo "$profile" | jq .
}

# Update profile
update_profile() {
    local profile_name="$1"
    local config="$2"

    log "INFO" "Updating profile: $profile_name"

    validate_profile_name "$profile_name"

    local profile_file="$PROFILES_DIR/$profile_name.json"

    if [[ ! -f "$profile_file" ]]; then
        error_exit "Profile not found: $profile_name"
    fi

    # Validate config
    if ! echo "$config" | jq . >/dev/null 2>&1; then
        error_exit "Invalid profile configuration"
    fi

    # Load existing profile
    local existing_profile=$(cat "$profile_file")

    # Update profile
    local updated_profile=$(echo "$existing_profile" "$config" | jq -s '.[0] * .[1]')

    # Update timestamp
    updated_profile=$(echo "$updated_profile" | jq --arg timestamp "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" '.updated_at = $timestamp')

    # Save profile
    echo "$updated_profile" > "$profile_file"

    echo '{"success":true,"message":"Profile updated","profile_name":"'"$profile_name"'"}' | jq .
}

# Delete profile
delete_profile() {
    local profile_name="$1"

    log "INFO" "Deleting profile: $profile_name"

    validate_profile_name "$profile_name"

    local profile_file="$PROFILES_DIR/$profile_name.json"

    if [[ ! -f "$profile_file" ]]; then
        error_exit "Profile not found: $profile_name"
    fi

    # Check if profile is active
    local active_profile=$(get_active_profile 2>/dev/null | jq -r '.active_profile // empty')
    if [[ "$active_profile" == "$profile_name" ]]; then
        error_exit "Cannot delete active profile: $profile_name"
    fi

    # Delete profile
    rm -f "$profile_file"

    echo '{"success":true,"message":"Profile deleted","profile_name":"'"$profile_name"'"}' | jq .
}

# List all profiles
list_profiles() {
    log "INFO" "Listing all profiles"

    local profiles='[]'

    for profile_file in "$PROFILES_DIR"/*.json; do
        if [[ -f "$profile_file" ]]; then
            local profile=$(cat "$profile_file")
            local profile_name=$(echo "$profile" | jq -r '.name')
            local profile_description=$(echo "$profile" | jq -r '.description')
            local profile_info='{"name":"'"$profile_name"'","description":"'"$profile_description"'"}'

            profiles=$(echo "$profiles" | jq --argjson info "$profile_info" '. + [$info]')
        fi
    done

    echo '{"success":true,"profiles":'"$profiles"',"count":'"$(echo "$profiles" | jq 'length')"'}' | jq .
}

# Activate profile
activate_profile() {
    local profile_name="$1"

    log "INFO" "Activating profile: $profile_name"

    validate_profile_name "$profile_name"

    local profile_file="$PROFILES_DIR/$profile_name.json"

    if [[ ! -f "$profile_file" ]]; then
        error_exit "Profile not found: $profile_name"
    fi

    # Load profile
    local profile=$(cat "$profile_file")

    # Validate profile
    if ! echo "$profile" | jq . >/dev/null 2>&1; then
        error_exit "Invalid profile"
    fi

    # Set active profile in main config
    local config_file="$CONFIG_DIR/config.json"
    if [[ -f "$config_file" ]]; then
        local config=$(cat "$config_file")
        local updated_config=$(echo "$config" | jq --arg profile "$profile_name" '.active_profile = $profile')
        echo "$updated_config" > "$config_file"
    fi

    echo '{"success":true,"message":"Profile activated","profile_name":"'"$profile_name"'"}' | jq .
}

# Deactivate profile
deactivate_profile() {
    log "INFO" "Deactivating profile"

    local config_file="$CONFIG_DIR/config.json"
    if [[ -f "$config_file" ]]; then
        local config=$(cat "$config_file")
        local updated_config=$(echo "$config" | jq 'del(.active_profile)')
        echo "$updated_config" > "$config_file"
    fi

    echo '{"success":true,"message":"Profile deactivated"}' | jq .
}

# Clone profile
clone_profile() {
    local source_profile="$1"
    local target_profile="$2"

    log "INFO" "Cloning profile: $source_profile -> $target_profile"

    validate_profile_name "$source_profile"
    validate_profile_name "$target_profile"

    local source_file="$PROFILES_DIR/$source_profile.json"
    local target_file="$PROFILES_DIR/$target_profile.json"

    if [[ ! -f "$source_file" ]]; then
        error_exit "Source profile not found: $source_profile"
    fi

    if [[ -f "$target_file" ]]; then
        error_exit "Target profile already exists: $target_profile"
    fi

    # Load source profile
    local source_profile_data=$(cat "$source_file")

    # Update profile name and timestamps
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    local cloned_profile=$(echo "$source_profile_data" | jq --arg name "$target_profile" --arg timestamp "$timestamp" '.name = $name | .created_at = $timestamp | .updated_at = $timestamp')

    # Save cloned profile
    echo "$cloned_profile" > "$target_file"

    echo '{"success":true,"message":"Profile cloned","source_profile":"'"$source_profile"'","target_profile":"'"$target_profile"'"}' | jq .
}

# Validate profile
validate_profile() {
    local profile_name="$1"

    log "INFO" "Validating profile: $profile_name"

    validate_profile_name "$profile_name"

    local profile_file="$PROFILES_DIR/$profile_name.json"

    if [[ ! -f "$profile_file" ]]; then
        error_exit "Profile not found: $profile_name"
    fi

    local profile=$(cat "$profile_file")
    local errors='[]'

    # Check if valid JSON
    if ! echo "$profile" | jq . >/dev/null 2>&1; then
        errors=$(echo "$errors" | jq '. + [{"error":"Invalid JSON profile"}]')
    fi

    # Check required fields
    local required_fields=("name" "description" "gpu_bindings" "service_preferences" "event_handlers" "safety_checks")
    for field in "${required_fields[@]}"; do
        if ! echo "$profile" | jq -e ".$field" >/dev/null 2>&1; then
            errors=$(echo "$errors" | jq '. + [{"error":"Missing required field: '"$field"'"}]')
        fi
    done

    # Check timestamps
    local created_at=$(echo "$profile" | jq -r '.created_at')
    local updated_at=$(echo "$profile" | jq -r '.updated_at')

    if ! [[ "$created_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
        errors=$(echo "$errors" | jq '. + [{"error":"Invalid created_at format"}]')
    fi

    if ! [[ "$updated_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
        errors=$(echo "$errors" | jq '. + [{"error":"Invalid updated_at format"}]')
    fi

    # Build result
    local error_count=$(echo "$errors" | jq 'length')
    local valid=$([[ $error_count -eq 0 ]] && echo "true" || echo "false")

    echo '{"valid":'"$valid"',"profile_name":"'"$profile_name"'","errors":'"$errors"',"error_count":'"$error_count"'}' | jq .
}

# Get active profile
get_active_profile() {
    log "INFO" "Getting active profile"

    local config_file="$CONFIG_DIR/config.json"
    local active_profile=""

    if [[ -f "$config_file" ]]; then
        local config=$(cat "$config_file")
        active_profile=$(echo "$config" | jq -r '.active_profile // empty')
    fi

    if [[ -z "$active_profile" ]]; then
        echo '{"success":true,"active_profile":null}' | jq .
    else
        echo '{"success":true,"active_profile":"'"$active_profile"'"}' | jq .
    fi
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
        create)
            create_profile "$@"
            ;;
        read)
            read_profile "$@"
            ;;
        update)
            update_profile "$@"
            ;;
        delete)
            delete_profile "$@"
            ;;
        list)
            list_profiles
            ;;
        activate)
            activate_profile "$@"
            ;;
        deactivate)
            deactivate_profile
            ;;
        clone)
            clone_profile "$@"
            ;;
        validate)
            validate_profile "$@"
            ;;
        active)
            get_active_profile
            ;;
        *)
            error_exit "Unknown command: $command"
            ;;
    esac
}

# Run main function
main "$@"
