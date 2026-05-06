#!/bin/bash

# config_version.sh
# Configuration version manager for GPU Switch Manager
# Usage: ./config_version.sh <command> [arguments]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_DIR/config"
CONFIG_FILE="$CONFIG_DIR/config.json"
VERSION_HISTORY_FILE="$CONFIG_DIR/version_history.json"
# Source secure shell library
source "$SCRIPT_DIR/secure_shell_lib.sh"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    secure_log "$level" "[CONFIG_VERSION] $message"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    secure_error_exit "$1"
}

# Initialize version history
init_version_history() {
    log "INFO" "Initializing version history"

    # Create config directory if it doesn't exist
    mkdir -p "$CONFIG_DIR"

    # Create version history file if it doesn't exist
    if [[ ! -f "$VERSION_HISTORY_FILE" ]]; then
        local version_history='{
  "versions": [],
  "current_version": null,
  "created_at": "'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"
}'

        echo "$version_history" > "$VERSION_HISTORY_FILE"
        log "INFO" "Created version history file"
    fi

    echo '{"success":true,"message":"Version history initialized"}' | jq .
}

# Get configuration version
get_version() {
    local config_path="${1:-$CONFIG_FILE}"

    log "INFO" "Getting configuration version"

    if [[ ! -f "$config_path" ]]; then
        error_exit "Configuration file not found: $config_path"
    fi

    local config=$(cat "$config_path")
    local version=$(echo "$config" | jq -r '.version // "0.0.0"')

    echo '{"success":true,"version":"'"$version"'","config_path":"'"$config_path"'"}' | jq .
}

# Set configuration version
set_version() {
    local version="$1"
    local config_path="${2:-$CONFIG_FILE}"

    log "INFO" "Setting configuration version to $version"

    if [[ ! -f "$config_path" ]]; then
        error_exit "Configuration file not found: $config_path"
    fi

    # Validate version format
    if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        error_exit "Invalid version format: $version (must be X.Y.Z)"
    fi

    # Load configuration
    local config=$(cat "$config_path")

    # Update version
    local updated_config=$(echo "$config" | jq --arg version "$version" '.version = $version')

    # Save configuration
    echo "$updated_config" > "$config_path"

    # Add to version history
    add_to_version_history "$version" "Manual version set" >/dev/null

    echo '{"success":true,"message":"Configuration version set","version":"'"$version"'"}' | jq .
}

# Increment version
increment_version() {
    local part="${1:-patch}"
    local config_path="${2:-$CONFIG_FILE}"

    log "INFO" "Incrementing configuration version ($part)"

    if [[ ! -f "$config_path" ]]; then
        error_exit "Configuration file not found: $config_path"
    fi

    # Get current version
    local current_version=$(get_version "$config_path" | jq -r '.version')

    # Parse version
    local major=$(echo "$current_version" | cut -d. -f1)
    local minor=$(echo "$current_version" | cut -d. -f2)
    local patch=$(echo "$current_version" | cut -d. -f3)

    # Increment version
    case "$part" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            error_exit "Invalid version part: $part (must be major, minor, or patch)"
            ;;
    esac

    local new_version="$major.$minor.$patch"

    # Set new version
    set_version "$new_version" "$config_path" >/dev/null

    echo '{"success":true,"message":"Configuration version incremented","old_version":"'"$current_version"'","new_version":"'"$new_version"'"}' | jq .
}

# Compare versions
compare_versions() {
    local version1="$1"
    local version2="$2"

    log "INFO" "Comparing versions: $version1 vs $version2"

    # Parse versions
    local major1=$(echo "$version1" | cut -d. -f1)
    local minor1=$(echo "$version1" | cut -d. -f2)
    local patch1=$(echo "$version1" | cut -d. -f3)

    local major2=$(echo "$version2" | cut -d. -f1)
    local minor2=$(echo "$version2" | cut -d. -f2)
    local patch2=$(echo "$version2" | cut -d. -f3)

    local result="equal"

    if [[ $major1 -gt $major2 ]]; then
        result="greater"
    elif [[ $major1 -lt $major2 ]]; then
        result="less"
    elif [[ $minor1 -gt $minor2 ]]; then
        result="greater"
    elif [[ $minor1 -lt $minor2 ]]; then
        result="less"
    elif [[ $patch1 -gt $patch2 ]]; then
        result="greater"
    elif [[ $patch1 -lt $patch2 ]]; then
        result="less"
    fi

    echo '{"success":true,"version1":"'"$version1"'","version2":"'"$version2"'","result":"'"$result"'"}' | jq .
}

# Get version history
get_version_history() {
    local limit="${1:-100}"

    log "INFO" "Getting version history (limit: $limit)"

    # Initialize version history if needed
    init_version_history >/dev/null

    # Load version history
    local version_history=$(cat "$VERSION_HISTORY_FILE")

    # Get versions
    local versions=$(echo "$version_history" | jq '.versions')

    # Limit results
    if [[ $limit -gt 0 ]]; then
        versions=$(echo "$versions" | jq "reverse | .[0:$limit] | reverse")
    fi

    echo '{"success":true,"versions":'"$versions"',"count":'"$(echo "$versions" | jq 'length')"'}' | jq .
}

# Create version tag
create_version_tag() {
    local tag="$1"
    local description="${2:-}"

    log "INFO" "Creating version tag: $tag"

    # Get current version
    local current_version=$(get_version | jq -r '.version')

    # Initialize version history if needed
    init_version_history >/dev/null

    # Load version history
    local version_history=$(cat "$VERSION_HISTORY_FILE")

    # Add tag
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    local tag_entry='{
  "tag": "'"$tag"'",
  "version": "'"$current_version"'",
  "description": "'"$description"'",
  "created_at": "'"$timestamp"'"
}'

    local updated_history=$(echo "$version_history" | jq --argjson tag "$tag_entry" '.versions += [$tag]')

    # Save version history
    echo "$updated_history" > "$VERSION_HISTORY_FILE"

    echo '{"success":true,"message":"Version tag created","tag":"'"$tag"'","version":"'"$current_version"'"}' | jq .
}

# Get version diff
get_version_diff() {
    local version1="$1"
    local version2="$2"

    log "INFO" "Getting version diff: $version1 vs $version2"

    # Compare versions
    local comparison=$(compare_versions "$version1" "$version2" | jq -r '.result')

    local diff='{
  "version1": "'"$version1"'",
  "version2": "'"$version2"'",
  "comparison": "'"$comparison"'"
}'

    echo "$diff" | jq .
}

# Validate version
validate_version() {
    local version="$1"

    log "INFO" "Validating version: $version"

    local valid=true
    local errors='[]'

    # Check version format
    if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        valid=false
        errors=$(echo "$errors" | jq '. + ["Invalid version format"]')
    fi

    # Check version parts
    if [[ "$valid" == "true" ]]; then
        local major=$(echo "$version" | cut -d. -f1)
        local minor=$(echo "$version" | cut -d. -f2)
        local patch=$(echo "$version" | cut -d. -f3)

        # Check if parts are numbers
        if ! [[ "$major" =~ ^[0-9]+$ ]]; then
            valid=false
            errors=$(echo "$errors" | jq '. + ["Major version must be a number"]')
        fi

        if ! [[ "$minor" =~ ^[0-9]+$ ]]; then
            valid=false
            errors=$(echo "$errors" | jq '. + ["Minor version must be a number"]')
        fi

        if ! [[ "$patch" =~ ^[0-9]+$ ]]; then
            valid=false
            errors=$(echo "$errors" | jq '. + ["Patch version must be a number"]')
        fi
    fi

    echo '{"valid":'"$valid"',"version":"'"$version"'","errors":'"$errors"'}' | jq .
}

# Add to version history
add_to_version_history() {
    local version="$1"
    local description="${2:-}"

    log "INFO" "Adding to version history: $version"

    # Initialize version history if needed
    init_version_history >/dev/null

    # Load version history
    local version_history=$(cat "$VERSION_HISTORY_FILE")

    # Add version entry
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    local version_entry='{
  "version": "'"$version"'",
  "description": "'"$description"'",
  "created_at": "'"$timestamp"'"
}'

    local updated_history=$(echo "$version_history" | jq --argjson entry "$version_entry" '.versions += [$entry] | .current_version = "'"$version"'"')

    # Save version history
    echo "$updated_history" > "$VERSION_HISTORY_FILE"

    echo '{"success":true,"message":"Added to version history","version":"'"$version"'"}' | jq .
}

# Clear version history
clear_version_history() {
    log "INFO" "Clearing version history"

    # Initialize version history
    init_version_history >/dev/null

    # Clear versions
    local version_history='{
  "versions": [],
  "current_version": null,
  "created_at": "'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"
}'

    echo "$version_history" > "$VERSION_HISTORY_FILE"

    echo '{"success":true,"message":"Version history cleared"}' | jq .
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
            init_version_history
            ;;
        get)
            get_version "$@"
            ;;
        set)
            set_version "$@"
            ;;
        increment)
            increment_version "$@"
            ;;
        compare)
            compare_versions "$@"
            ;;
        history)
            get_version_history "$@"
            ;;
        tag)
            create_version_tag "$@"
            ;;
        diff)
            get_version_diff "$@"
            ;;
        validate)
            validate_version "$@"
            ;;
        add)
            add_to_version_history "$@"
            ;;
        clear)
            clear_version_history
            ;;
        *)
            error_exit "Unknown command: $command"
            ;;
    esac
}

# Run main function
main "$@"
