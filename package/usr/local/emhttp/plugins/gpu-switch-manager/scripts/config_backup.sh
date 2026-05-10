#!/bin/bash

# config_backup.sh
# Configuration backup manager for GPU Switch Manager
# Usage: ./config_backup.sh <command> [arguments]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_DIR/config"
BACKUP_DIR="$CONFIG_DIR/backups"
CONFIG_FILE="$CONFIG_DIR/config.json"
# Source secure shell library
source "$SCRIPT_DIR/secure_shell_lib.sh"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    secure_log "$level" "[CONFIG_BACKUP] $message"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    secure_error_exit "$1"
}

# Initialize backup directory
init_backup_dir() {
    log "INFO" "Initializing backup directory"

    # Create backup directory
    mkdir -p "$BACKUP_DIR"

    echo '{"success":true,"message":"Backup directory initialized","backup_dir":"'"$BACKUP_DIR"'"}' | jq .
}

# Create backup
create_backup() {
    local config_path="${1:-$CONFIG_FILE}"
    local compress="${2:-true}"

    log "INFO" "Creating backup"

    if [[ ! -f "$config_path" ]]; then
        error_exit "Configuration file not found: $config_path"
    fi

    # Initialize backup directory
    init_backup_dir >/dev/null

    # Create backup file
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/config_$timestamp.json"

    # Copy configuration
    cp "$config_path" "$backup_file"

    # Compress if requested
    if [[ "$compress" == "true" ]]; then
        gzip -f "$backup_file"
        backup_file="${backup_file}.gz"
    fi

    # Get backup size
    local backup_size=$(stat -c%s "$backup_file" 2>/dev/null || stat -f%z "$backup_file" 2>/dev/null || echo "0")

    echo '{"success":true,"message":"Backup created","backup_file":"'"$backup_file"'","backup_size":'"$backup_size"',"timestamp":"'"$timestamp"'"}' | jq .
}

# List backups
list_backups() {
    log "INFO" "Listing backups"

    local backups='[]'

    for backup_file in "$BACKUP_DIR"/config_*.json*; do
        if [[ -f "$backup_file" ]]; then
            local backup_name=$(basename "$backup_file")
            local backup_size=$(stat -c%s "$backup_file" 2>/dev/null || stat -f%z "$backup_file" 2>/dev/null || echo "0")
            local backup_date=$(stat -c%Y "$backup_file" 2>/dev/null || stat -f%m "$backup_file" 2>/dev/null || echo "0")
            local backup_date_formatted=$(date -d "@$backup_date" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r "$backup_date" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "Unknown")

            local backup_info='{"name":"'"$backup_name"'","size":'"$backup_size"',"date":"'"$backup_date_formatted"'","path":"'"$backup_file"'"}'

            backups=$(echo "$backups" | jq --argjson info "$backup_info" '. + [$info]')
        fi
    done

    # Sort by date (newest first)
    backups=$(echo "$backups" | jq 'reverse')

    echo '{"success":true,"backups":'"$backups"',"count":'"$(echo "$backups" | jq 'length')"'}' | jq .
}

# Restore backup
restore_backup() {
    local backup_file="$1"
    local config_path="${2:-$CONFIG_FILE}"

    log "INFO" "Restoring backup from $backup_file"

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
    create_backup "$config_path" >/dev/null

    # Restore configuration
    cp "$temp_file" "$config_path"
    rm -f "$temp_file"

    echo '{"success":true,"message":"Backup restored","config_path":"'"$config_path"'"}' | jq .
}

# Delete backup
delete_backup() {
    local backup_file="$1"

    log "INFO" "Deleting backup: $backup_file"

    if [[ ! -f "$backup_file" ]]; then
        error_exit "Backup file not found: $backup_file"
    fi

    # Delete backup
    rm -f "$backup_file"

    echo '{"success":true,"message":"Backup deleted","backup_file":"'"$backup_file"'"}' | jq .
}

# Automatic backup
auto_backup() {
    local config_path="${1:-$CONFIG_FILE}"
    local max_backups="${2:-10}"

    log "INFO" "Creating automatic backup"

    # Create backup
    create_backup "$config_path" >/dev/null

    # Cleanup old backups
    cleanup_backups "$max_backups" >/dev/null

    echo '{"success":true,"message":"Automatic backup created"}' | jq .
}

# Schedule backup
schedule_backup() {
    local interval="$1"
    local config_path="${2:-$CONFIG_FILE}"

    log "INFO" "Scheduling backup every $interval seconds"

    # Create cron job
    local cron_job="*/$((interval / 60)) * * * * $SCRIPT_DIR/config_backup.sh auto_backup $config_path"

    # Add to crontab
    (crontab -l 2>/dev/null | grep -v "config_backup.sh"; echo "$cron_job") | crontab -

    echo '{"success":true,"message":"Backup scheduled","interval":'"$interval"'}' | jq .
}

# Verify backup
verify_backup() {
    local backup_file="$1"

    log "INFO" "Verifying backup: $backup_file"

    if [[ ! -f "$backup_file" ]]; then
        error_exit "Backup file not found: $backup_file"
    fi

    local valid=false
    local errors='[]'

    # Decompress if needed
    local temp_file="$backup_file.tmp"
    if [[ "$backup_file" == *.gz ]]; then
        gunzip -c "$backup_file" > "$temp_file"
    else
        cp "$backup_file" "$temp_file"
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

    echo '{"valid":'"$valid"',"backup_file":"'"$backup_file"'","errors":'"$errors"'}' | jq .
}

# Compress backup
compress_backup() {
    local backup_file="$1"

    log "INFO" "Compressing backup: $backup_file"

    if [[ ! -f "$backup_file" ]]; then
        error_exit "Backup file not found: $backup_file"
    fi

    if [[ "$backup_file" == *.gz ]]; then
        error_exit "Backup already compressed"
    fi

    # Compress backup
    gzip -f "$backup_file"

    local compressed_file="${backup_file}.gz"
    local compressed_size=$(stat -c%s "$compressed_file" 2>/dev/null || stat -f%z "$compressed_file" 2>/dev/null || echo "0")

    echo '{"success":true,"message":"Backup compressed","compressed_file":"'"$compressed_file"'","compressed_size":'"$compressed_size"'}' | jq .
}

# Decompress backup
decompress_backup() {
    local backup_file="$1"

    log "INFO" "Decompressing backup: $backup_file"

    if [[ ! -f "$backup_file" ]]; then
        error_exit "Backup file not found: $backup_file"
    fi

    if [[ "$backup_file" != *.gz ]]; then
        error_exit "Backup not compressed"
    fi

    # Decompress backup
    gunzip -f "$backup_file"

    local decompressed_file="${backup_file%.gz}"
    local decompressed_size=$(stat -c%s "$decompressed_file" 2>/dev/null || stat -f%z "$decompressed_file" 2>/dev/null || echo "0")

    echo '{"success":true,"message":"Backup decompressed","decompressed_file":"'"$decompressed_file"'","decompressed_size":'"$decompressed_size"'}' | jq .
}

# Cleanup old backups
cleanup_backups() {
    local max_backups="${1:-10}"

    log "INFO" "Cleaning up old backups (keeping $max_backups)"

    local backup_count=0
    local deleted_count=0

    # List backups sorted by date (oldest first)
    for backup_file in $(ls -t "$BACKUP_DIR"/config_*.json* 2>/dev/null); do
        if [[ -f "$backup_file" ]]; then
            backup_count=$((backup_count + 1))

            # Delete old backups beyond max
            if [[ $backup_count -gt $max_backups ]]; then
                rm -f "$backup_file"
                deleted_count=$((deleted_count + 1))
                log "INFO" "Deleted old backup: $backup_file"
            fi
        fi
    done

    echo '{"success":true,"message":"Old backups cleaned up","deleted_count":'"$deleted_count"',"backup_count":'"$backup_count"'}' | jq .
}

# Get backup info
get_backup_info() {
    local backup_file="$1"

    log "INFO" "Getting backup info: $backup_file"

    if [[ ! -f "$backup_file" ]]; then
        error_exit "Backup file not found: $backup_file"
    fi

    local backup_name=$(basename "$backup_file")
    local backup_size=$(stat -c%s "$backup_file" 2>/dev/null || stat -f%z "$backup_file" 2>/dev/null || echo "0")
    local backup_date=$(stat -c%Y "$backup_file" 2>/dev/null || stat -f%m "$backup_file" 2>/dev/null || echo "0")
    local backup_date_formatted=$(date -d "@$backup_date" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r "$backup_date" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "Unknown")

    # Get config version if possible
    local config_version="unknown"
    local temp_file="$backup_file.tmp"
    if [[ "$backup_file" == *.gz ]]; then
        gunzip -c "$backup_file" > "$temp_file"
    else
        cp "$backup_file" "$temp_file"
    fi

    if cat "$temp_file" | jq . >/dev/null 2>&1; then
        config_version=$(cat "$temp_file" | jq -r '.version // "unknown"')
    fi

    rm -f "$temp_file"

    echo '{"success":true,"backup_name":"'"$backup_name"'","backup_size":'"$backup_size"',"backup_date":"'"$backup_date_formatted"'","config_version":"'"$config_version"'"}' | jq .
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
            init_backup_dir
            ;;
        create)
            create_backup "$@"
            ;;
        list)
            list_backups
            ;;
        restore)
            restore_backup "$@"
            ;;
        delete)
            delete_backup "$@"
            ;;
        auto)
            auto_backup "$@"
            ;;
        schedule)
            schedule_backup "$@"
            ;;
        verify)
            verify_backup "$@"
            ;;
        compress)
            compress_backup "$@"
            ;;
        decompress)
            decompress_backup "$@"
            ;;
        cleanup)
            cleanup_backups "$@"
            ;;
        info)
            get_backup_info "$@"
            ;;
        *)
            error_exit "Unknown command: $command"
            ;;
    esac
}

# Run main function
main "$@"
