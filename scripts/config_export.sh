#!/bin/bash

# config_export.sh
# Configuration export manager for GPU Switch Manager
# Usage: ./config_export.sh <command> [arguments]

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
    secure_log "$level" "[CONFIG_EXPORT] $message"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    secure_error_exit "$1"
}

# Export configuration
export_config() {
    local export_file="${1:-config_export_$(date +%Y%m%d_%H%M%S).json}"
    local config_path="${2:-$CONFIG_FILE}"
    local compress="${3:-false}"

    log "INFO" "Exporting configuration to $export_file"

    if [[ ! -f "$config_path" ]]; then
        error_exit "Configuration file not found: $config_path"
    fi

    # Copy configuration
    cp "$config_path" "$export_file"

    # Compress if requested
    if [[ "$compress" == "true" ]]; then
        gzip -f "$export_file"
        export_file="${export_file}.gz"
    fi

    # Get export size
    local export_size=$(stat -c%s "$export_file" 2>/dev/null || stat -f%z "$export_file" 2>/dev/null || echo "0")

    echo '{"success":true,"message":"Configuration exported","export_file":"'"$export_file"'","export_size":'"$export_size"'}' | jq .
}

# Select export scope
select_export() {
    local scope="$1"
    local export_file="${2:-config_export_$(date +%Y%m%d_%H%M%S).json}"
    local config_path="${3:-$CONFIG_FILE}"

    log "INFO" "Exporting configuration scope: $scope"

    if [[ ! -f "$config_path" ]]; then
        error_exit "Configuration file not found: $config_path"
    fi

    local config=$(cat "$config_path")
    local export_config="{}"

    case "$scope" in
        full)
            export_config="$config"
            ;;
        profiles)
            export_config=$(echo "$config" | jq '{profiles: .profiles}')
            ;;
        preferences)
            export_config=$(echo "$config" | jq '{preferences: .preferences}')
            ;;
        services)
            export_config=$(echo "$config" | jq '{services: .services}')
            ;;
        profiles_preferences)
            export_config=$(echo "$config" | jq '{profiles: .profiles, preferences: .preferences}')
            ;;
        profiles_services)
            export_config=$(echo "$config" | jq '{profiles: .profiles, services: .services}')
            ;;
        preferences_services)
            export_config=$(echo "$config" | jq '{preferences: .preferences, services: .services}')
            ;;
        *)
            error_exit "Invalid export scope: $scope"
            ;;
    esac

    # Save export
    echo "$export_config" > "$export_file"

    echo '{"success":true,"message":"Configuration scope exported","export_file":"'"$export_file"'","scope":"'"$scope"'"}' | jq .
}

# Format export
format_export() {
    local format="$1"
    local export_file="${2:-config_export_$(date +%Y%m%d_%H%M%S)}"
    local config_path="${3:-$CONFIG_FILE}"

    log "INFO" "Exporting configuration in format: $format"

    if [[ ! -f "$config_path" ]]; then
        error_exit "Configuration file not found: $config_path"
    fi

    local config=$(cat "$config_path")

    case "$format" in
        json)
            export_file="${export_file}.json"
            echo "$config" > "$export_file"
            ;;
        pretty)
            export_file="${export_file}.json"
            echo "$config" | jq . > "$export_file"
            ;;
        yaml)
            export_file="${export_file}.yaml"
            # Convert JSON to YAML (requires yq or python)
            if command -v yq &>/dev/null; then
                echo "$config" | yq -y > "$export_file"
            elif command -v python3 &>/dev/null; then
                python3 -c "import json, yaml, sys; yaml.dump(json.load(sys.stdin), open('$export_file', 'w'), default_flow_style=False)" <<< "$config"
            else
                error_exit "YAML export requires yq or python3"
            fi
            ;;
        xml)
            export_file="${export_file}.xml"
            # Convert JSON to XML (requires python)
            if command -v python3 &>/dev/null; then
                python3 -c "import json, xml.etree.ElementTree as ET, sys; data = json.load(sys.stdin); root = ET.Element('config'); def dict_to_xml(t, d): for k, v in d.items(): child = ET.SubElement(t, k); dict_to_xml(child, v) if isinstance(v, dict) else child.text = str(v); dict_to_xml(root, data); ET.ElementTree(root).write('$export_file', encoding='utf-8', xml_declaration=True)" <<< "$config"
            else
                error_exit "XML export requires python3"
            fi
            ;;
        *)
            error_exit "Invalid export format: $format"
            ;;
    esac

    echo '{"success":true,"message":"Configuration exported","export_file":"'"$export_file"'","format":"'"$format"'"}' | jq .
}

# Compress export
compress_export() {
    local export_file="$1"

    log "INFO" "Compressing export: $export_file"

    if [[ ! -f "$export_file" ]]; then
        error_exit "Export file not found: $export_file"
    fi

    if [[ "$export_file" == *.gz ]]; then
        error_exit "Export already compressed"
    fi

    # Compress export
    gzip -f "$export_file"

    local compressed_file="${export_file}.gz"
    local compressed_size=$(stat -c%s "$compressed_file" 2>/dev/null || stat -f%z "$compressed_file" 2>/dev/null || echo "0")

    echo '{"success":true,"message":"Export compressed","compressed_file":"'"$compressed_file"'","compressed_size":'"$compressed_size"'}' | jq .
}

# Verify export
verify_export() {
    local export_file="$1"

    log "INFO" "Verifying export: $export_file"

    if [[ ! -f "$export_file" ]]; then
        error_exit "Export file not found: $export_file"
    fi

    local valid=false
    local errors='[]'

    # Decompress if needed
    local temp_file="$export_file.tmp"
    if [[ "$export_file" == *.gz ]]; then
        gunzip -c "$export_file" > "$temp_file"
    else
        cp "$export_file" "$temp_file"
    fi

    # Validate JSON
    if cat "$temp_file" | jq . >/dev/null 2>&1; then
        valid=true
    else
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

    echo '{"valid":'"$valid"',"export_file":"'"$export_file"'","errors":'"$errors"'}' | jq .
}

# Export to string
export_to_string() {
    local config_path="${1:-$CONFIG_FILE}"

    log "INFO" "Exporting configuration to string"

    if [[ ! -f "$config_path" ]]; then
        error_exit "Configuration file not found: $config_path"
    fi

    local config=$(cat "$config_path")

    echo '{"success":true,"config":'"$config"'}' | jq .
}

# Export profile
export_profile() {
    local profile_name="$1"
    local export_file="${2:-profile_${profile_name}_$(date +%Y%m%d_%H%M%S).json}"

    log "INFO" "Exporting profile: $profile_name"

    local profiles_dir="$CONFIG_DIR/profiles"
    local profile_file="$profiles_dir/$profile_name.json"

    if [[ ! -f "$profile_file" ]]; then
        error_exit "Profile not found: $profile_name"
    fi

    # Copy profile
    cp "$profile_file" "$export_file"

    echo '{"success":true,"message":"Profile exported","export_file":"'"$export_file"'","profile_name":"'"$profile_name"'"}' | jq .
}

# Export preferences
export_preferences() {
    local export_file="${1:-preferences_export_$(date +%Y%m%d_%H%M%S).json}"

    log "INFO" "Exporting preferences"

    local preferences_dir="$CONFIG_DIR/preferences"
    local user_preferences_file="$preferences_dir/user.json"

    if [[ ! -f "$user_preferences_file" ]]; then
        error_exit "User preferences not found"
    fi

    # Copy preferences
    cp "$user_preferences_file" "$export_file"

    echo '{"success":true,"message":"Preferences exported","export_file":"'"$export_file"'"}' | jq .
}

# Get export formats
get_export_formats() {
    log "INFO" "Getting supported export formats"

    local formats='[
  {"name":"JSON","extension":".json","description":"JSON configuration file"},
  {"name":"Pretty JSON","extension":".json","description":"Formatted JSON file"},
  {"name":"YAML","extension":".yaml","description":"YAML configuration file"},
  {"name":"XML","extension":".xml","description":"XML configuration file"},
  {"name":"GZIP","extension":".json.gz","description":"GZIP compressed JSON file"},
  {"name":"String","extension":"N/A","description":"Export to string"}
]'

    echo '{"success":true,"formats":'"$formats"'}' | jq .
}

# Get export scopes
get_export_scopes() {
    log "INFO" "Getting supported export scopes"

    local scopes='[
  {"name":"full","description":"Full configuration"},
  {"name":"profiles","description":"Profiles only"},
  {"name":"preferences","description":"Preferences only"},
  {"name":"services","description":"Services only"},
  {"name":"profiles_preferences","description":"Profiles and preferences"},
  {"name":"profiles_services","description":"Profiles and services"},
  {"name":"preferences_services","description":"Preferences and services"}
]'

    echo '{"success":true,"scopes":'"$scopes"'}' | jq .
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
        export)
            export_config "$@"
            ;;
        scope)
            select_export "$@"
            ;;
        format)
            format_export "$@"
            ;;
        compress)
            compress_export "$@"
            ;;
        verify)
            verify_export "$@"
            ;;
        string)
            export_to_string "$@"
            ;;
        profile)
            export_profile "$@"
            ;;
        preferences)
            export_preferences "$@"
            ;;
        formats)
            get_export_formats
            ;;
        scopes)
            get_export_scopes
            ;;
        *)
            error_exit "Unknown command: $command"
            ;;
    esac
}

# Run main function
main "$@"
