#!/bin/bash

# config_import.sh
# Configuration import manager for GPU Switch Manager
# Usage: ./config_import.sh <command> [arguments]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_DIR/config"
CONFIG_FILE="$CONFIG_DIR/config.json"
# Source secure shell library
source "$SCRIPT_DIR/secure_shell_lib.sh"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    secure_log "$level" "[CONFIG_IMPORT] $message"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    secure_error_exit "$1"
}

# Import configuration
import_config() {
    local import_file="$1"
    local config_path="${2:-$CONFIG_FILE}"
    local merge="${3:-false}"

    log "INFO" "Importing configuration from $import_file"

    if [[ ! -f "$import_file" ]]; then
        error_exit "Import file not found: $import_file"
    fi

    # Decompress if needed
    local temp_file="$import_file.tmp"
    if [[ "$import_file" == *.gz ]]; then
        gunzip -c "$import_file" > "$temp_file"
    else
        cp "$import_file" "$temp_file"
    fi

    # Validate import
    if ! cat "$temp_file" | jq . >/dev/null 2>&1; then
        rm -f "$temp_file"
        error_exit "Invalid import file"
    fi

    # Create backup of current configuration
    if [[ -f "$config_path" ]]; then
        local backup_file="$CONFIG_DIR/backups/config_$(date +%Y%m%d_%H%M%S).json"
        mkdir -p "$CONFIG_DIR/backups"
        cp "$config_path" "$backup_file"
        log "INFO" "Created backup: $backup_file"
    fi

    # Import configuration
    if [[ "$merge" == "true" ]] && [[ -f "$config_path" ]]; then
        # Merge with existing configuration
        local existing_config=$(cat "$config_path")
        local import_config=$(cat "$temp_file")
        local merged_config=$(echo "$existing_config" "$import_config" | jq -s '.[0] * .[1]')
        echo "$merged_config" > "$config_path"
    else
        # Replace existing configuration
        cp "$temp_file" "$config_path"
    fi

    # Cleanup temp file
    rm -f "$temp_file"

    echo '{"success":true,"message":"Configuration imported","config_path":"'"$config_path"'","merge":'"$merge"'}' | jq .
}

# Validate import
validate_import() {
    local import_file="$1"

    log "INFO" "Validating import: $import_file"

    if [[ ! -f "$import_file" ]]; then
        error_exit "Import file not found: $import_file"
    fi

    local valid=true
    local errors='[]'

    # Decompress if needed
    local temp_file="$import_file.tmp"
    if [[ "$import_file" == *.gz ]]; then
        gunzip -c "$import_file" > "$temp_file"
    else
        cp "$import_file" "$temp_file"
    fi

    # Validate JSON
    if ! cat "$temp_file" | jq . >/dev/null 2>&1; then
        valid=false
        errors=$(echo "$errors" | jq '. + ["Invalid JSON"]')
    fi

    # Check required fields
    if [[ "$valid" == "true" ]]; then
        local config=$(cat "$temp_file")
        local required_fields=("version" "profiles" "preferences" "services")

        for field in "${required_fields[@]}"; do
            if ! echo "$config" | jq -e ".$field" >/dev/null 2>&1; then
                valid=false
                errors=$(echo "$errors" | jq '. + ["Missing required field: '"$field"'"]')
            fi
        done
    fi

    # Cleanup temp file
    rm -f "$temp_file"

    echo '{"valid":'"$valid"',"import_file":"'"$import_file"'","errors":'"$errors"'}' | jq .
}

# Merge import
merge_import() {
    local import_file="$1"
    local config_path="${2:-$CONFIG_FILE}"

    log "INFO" "Merging import: $import_file"

    if [[ ! -f "$import_file" ]]; then
        error_exit "Import file not found: $import_file"
    fi

    if [[ ! -f "$config_path" ]]; then
        error_exit "Configuration file not found: $config_path"
    fi

    # Decompress if needed
    local temp_file="$import_file.tmp"
    if [[ "$import_file" == *.gz ]]; then
        gunzip -c "$import_file" > "$temp_file"
    else
        cp "$import_file" "$temp_file"
    fi

    # Validate import
    if ! cat "$temp_file" | jq . >/dev/null 2>&1; then
        rm -f "$temp_file"
        error_exit "Invalid import file"
    fi

    # Merge configurations
    local existing_config=$(cat "$config_path")
    local import_config=$(cat "$temp_file")
    local merged_config=$(echo "$existing_config" "$import_config" | jq -s '.[0] * .[1]')

    # Save merged configuration
    echo "$merged_config" > "$config_path"

    # Cleanup temp file
    rm -f "$temp_file"

    echo '{"success":true,"message":"Import merged","config_path":"'"$config_path"'"}' | jq .
}

# Preview import
preview_import() {
    local import_file="$1"

    log "INFO" "Previewing import: $import_file"

    if [[ ! -f "$import_file" ]]; then
        error_exit "Import file not found: $import_file"
    fi

    # Decompress if needed
    local temp_file="$import_file.tmp"
    if [[ "$import_file" == *.gz ]]; then
        gunzip -c "$import_file" > "$temp_file"
    else
        cp "$import_file" "$temp_file"
    fi

    # Get import summary
    local config=$(cat "$temp_file")
    local version=$(echo "$config" | jq -r '.version')
    local profile_count=$(echo "$config" | jq '.profiles | length')
    local preference_count=$(echo "$config" | jq '.preferences | length')
    local service_count=$(echo "$config" | jq '.services | length')

    # Cleanup temp file
    rm -f "$temp_file"

    echo '{"success":true,"version":"'"$version"'","profile_count":'"$profile_count"',"preference_count":'"$preference_count"',"service_count":'"$service_count"'}' | jq .
}

# Confirm import
confirm_import() {
    local import_file="$1"
    local config_path="${2:-$CONFIG_FILE}"

    log "INFO" "Confirming import: $import_file"

    # Get import preview
    local preview=$(preview_import "$import_file")

    # Check if configuration exists
    local config_exists="false"
    if [[ -f "$config_path" ]]; then
        config_exists="true"
    fi

    echo '{"success":true,"preview":'"$preview"',"config_exists":'"$config_exists"',"config_path":"'"$config_path"'"}' | jq .
}

# Import from URL
import_from_url() {
    local url="$1"
    local config_path="${2:-$CONFIG_FILE}"

    log "INFO" "Importing configuration from URL: $url"

    # Download configuration
    local temp_file="/tmp/config_import_$$"
    if ! curl -s -o "$temp_file" "$url"; then
        error_exit "Failed to download configuration from URL"
    fi

    # Import configuration
    import_config "$temp_file" "$config_path" >/dev/null

    # Cleanup temp file
    rm -f "$temp_file"

    echo '{"success":true,"message":"Configuration imported from URL","url":"'"$url"'"}' | jq .
}

# Import from string
import_from_string() {
    local config_string="$1"
    local config_path="${2:-$CONFIG_FILE}"

    log "INFO" "Importing configuration from string"

    # Validate configuration string
    if ! echo "$config_string" | jq . >/dev/null 2>&1; then
        error_exit "Invalid configuration string"
    fi

    # Create temp file
    local temp_file="/tmp/config_import_$$"
    echo "$config_string" > "$temp_file"

    # Import configuration
    import_config "$temp_file" "$config_path" >/dev/null

    # Cleanup temp file
    rm -f "$temp_file"

    echo '{"success":true,"message":"Configuration imported from string"}' | jq .
}

# Get import formats
get_import_formats() {
    log "INFO" "Getting supported import formats"

    local formats='[
  {"name":"JSON","extension":".json","description":"JSON configuration file"},
  {"name":"GZIP","extension":".json.gz","description":"GZIP compressed JSON file"},
  {"name":"URL","extension":"N/A","description":"Download from URL"},
  {"name":"String","extension":"N/A","description":"Import from string"}
]'

    echo '{"success":true,"formats":'"$formats"'}' | jq .
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
        import)
            import_config "$@"
            ;;
        validate)
            validate_import "$@"
            ;;
        merge)
            merge_import "$@"
            ;;
        preview)
            preview_import "$@"
            ;;
        confirm)
            confirm_import "$@"
            ;;
        url)
            import_from_url "$@"
            ;;
        string)
            import_from_string "$@"
            ;;
        formats)
            get_import_formats
            ;;
        *)
            error_exit "Unknown command: $command"
            ;;
    esac
}

# Run main function
main "$@"
