#!/bin/bash

# secure_shell_lib.sh
# Secure shell library for GPU Switch Manager
# Provides safe functions for JSON output, error handling, and input validation

set -euo pipefail

# Configuration
SECURE_LOG_FILE="/var/log/gpu.switch.manager.log"

# Secure logging function
secure_log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$SECURE_LOG_FILE"
}

# Secure error exit with JSON output
secure_error_exit() {
    local error_message="$1"
    local error_code="${2:-1}"

    # Log the error
    secure_log "ERROR" "$error_message"

    # Escape the error message for JSON
    local escaped_message=$(echo "$error_message" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/$/\\$/g')

    # Output secure JSON error
    echo "{\"success\":false,\"error\":\"$escaped_message\",\"error_code\":$error_code}"
    exit "$error_code"
}

# Secure JSON output function
secure_json_output() {
    local json_data="$1"

    # Validate JSON format
    if ! echo "$json_data" | jq . > /dev/null 2>&1; then
        secure_error_exit "Invalid JSON format: $json_data"
    fi

    # Output validated JSON
    echo "$json_data"
}

# Secure JSON string escaping
secure_json_escape() {
    local input="$1"
    # Escape backslashes, quotes, newlines, and other special characters
    echo "$input" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/$/\\$/g' | sed 's/\t/\\t/g' | sed 's/\r/\\r/g' | sed 's/\n/\\n/g'
}

# Validate PCI address format
validate_pci_address() {
    local pci_address="$1"

    # Check format
    if [[ ! "$pci_address" =~ ^[0-9a-fA-F]{4}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-7]$ ]]; then
        secure_error_exit "Invalid PCI address format: $pci_address"
    fi

    # Normalize to lowercase
    echo "$pci_address" | tr '[:upper:]' '[:lower:]'
}

# Validate GPU address (alias for PCI address)
validate_gpu_address() {
    validate_pci_address "$1"
}

# Validate profile name
validate_profile_name() {
    local profile_name="$1"

    # Check length
    if [[ ${#profile_name} -gt 64 ]]; then
        secure_error_exit "Profile name too long (max 64 characters)"
    fi

    # Check format
    if [[ ! "$profile_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        secure_error_exit "Invalid profile name format: $profile_name"
    fi

    echo "$profile_name"
}

# Validate preference key
validate_preference_key() {
    local preference_key="$1"

    # Check length
    if [[ ${#preference_key} -gt 128 ]]; then
        secure_error_exit "Preference key too long (max 128 characters)"
    fi

    # Check format
    if [[ ! "$preference_key" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
        secure_error_exit "Invalid preference key format: $preference_key"
    fi

    echo "$preference_key"
}

# Validate username
validate_username() {
    local username="$1"

    # Check length
    if [[ ${#username} -lt 3 || ${#username} -gt 32 ]]; then
        secure_error_exit "Username must be between 3 and 32 characters"
    fi

    # Check format
    if [[ ! "$username" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        secure_error_exit "Invalid username format: $username"
    fi

    echo "$username"
}

# Validate integer
validate_integer() {
    local value="$1"
    local min_value="${2:-}"
    local max_value="${3:-}"

    # Check if integer
    if [[ ! "$value" =~ ^-?[0-9]+$ ]]; then
        secure_error_exit "Invalid integer value: $value"
    fi

    # Check range
    if [[ -n "$min_value" ]] && [[ "$value" -lt "$min_value" ]]; then
        secure_error_exit "Value must be at least $min_value"
    fi

    if [[ -n "$max_value" ]] && [[ "$value" -gt "$max_value" ]]; then
        secure_error_exit "Value must be at most $max_value"
    fi

    echo "$value"
}

# Validate boolean
validate_boolean() {
    local value="$1"

    case "$value" in
        true|1|yes|on|True|TRUE|Yes|YES|ON)
            echo "true"
            ;;
        false|0|no|off|False|FALSE|No|NO|OFF)
            echo "false"
            ;;
        *)
            secure_error_exit "Invalid boolean value: $value"
            ;;
    esac
}

# Validate file path
validate_file_path() {
    local file_path="$1"
    local base_path="${2:-}"

    # Check for path traversal
    if [[ "$file_path" == *".."* ]] || [[ "$file_path" == *"~"* ]]; then
        secure_error_exit "Invalid file path: contains path traversal characters"
    fi

    # Check for null bytes
    if [[ "$file_path" == *$'\0'* ]]; then
        secure_error_exit "Invalid file path: contains null bytes"
    fi

    # If base path provided, ensure path is within it
    if [[ -n "$base_path" ]]; then
        local resolved_path=$(realpath "$file_path" 2>/dev/null || echo "$file_path")
        local resolved_base=$(realpath "$base_path" 2>/dev/null || echo "$base_path")

        if [[ "$resolved_path" != "$resolved_base"* ]]; then
            secure_error_exit "Invalid file path: outside allowed base directory"
        fi
    fi

    echo "$file_path"
}

# Validate directory path
validate_directory_path() {
    local dir_path="$1"
    local base_path="${2:-}"

    # Validate as file path first
    validate_file_path "$dir_path" "$base_path"

    # Ensure it ends with /
    if [[ "$dir_path" != */ ]]; then
        dir_path="$dir_path/"
    fi

    echo "$dir_path"
}

# Sanitize filename
sanitize_filename() {
    local filename="$1"

    # Remove path separators
    filename="${filename//\//}"
    filename="${filename//\\/}"

    # Remove null bytes
    filename="${filename//$'\0'/}"

    # Remove control characters
    filename=$(echo "$filename" | tr -d '\000-\037')

    # Check length
    if [[ ${#filename} -gt 255 ]]; then
        secure_error_exit "Filename too long (max 255 characters)"
    fi

    # Check for reserved names (Windows)
    local reserved_names="CON PRN AUX NUL COM1 COM2 COM3 COM4 COM5 COM6 COM7 COM8 COM9 LPT1 LPT2 LPT3 LPT4 LPT5 LPT6 LPT7 LPT8 LPT9"
    local name_without_ext=$(basename "$filename" | cut -d. -f1)

    for reserved in $reserved_names; do
        if [[ "$(echo "$name_without_ext" | tr '[:lower:]' '[:upper:]')" == "$reserved" ]]; then
            secure_error_exit "Invalid filename: reserved name"
        fi
    done

    # Check for invalid characters
    case "$filename" in
        *\<*|*\>*|*:*|*\"*|*\|*|*\?*|*\**)
            secure_error_exit "Invalid filename: contains invalid characters"
            ;;
    esac

    echo "$filename"
}

# Safe command execution with timeout
safe_execute() {
    local command="$1"
    local timeout="${2:-30}"
    local description="${3:-command}"

    secure_log "INFO" "Executing $description with timeout ${timeout}s"

    # Execute with timeout
    timeout "$timeout" bash -c "$command" 2>&1 || {
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            secure_error_exit "Command timed out: $description"
        else
            secure_error_exit "Command failed: $description (exit code: $exit_code)"
        fi
    }
}

# Safe file read
safe_file_read() {
    local file_path="$1"
    local max_size="${2:-10485760}"  # 10MB default

    # Validate file path
    local validated_path=$(validate_file_path "$file_path")

    # Check if file exists
    if [[ ! -f "$validated_path" ]]; then
        secure_error_exit "File not found: $validated_path"
    fi

    # Check if file is readable
    if [[ ! -r "$validated_path" ]]; then
        secure_error_exit "File not readable: $validated_path"
    fi

    # Check file size
    local file_size=$(stat -f%z "$validated_path" 2>/dev/null || stat -c%s "$validated_path" 2>/dev/null)
    if [[ "$file_size" -gt "$max_size" ]]; then
        secure_error_exit "File too large: $validated_path (max: $max_size bytes)"
    fi

    # Read file content
    cat "$validated_path"
}

# Safe file write
safe_file_write() {
    local file_path="$1"
    local content="$2"
    local max_size="${3:-10485760}"  # 10MB default

    # Validate file path
    local validated_path=$(validate_file_path "$file_path")

    # Check content size
    local content_size=${#content}
    if [[ "$content_size" -gt "$max_size" ]]; then
        secure_error_exit "Content too large (max: $max_size bytes)"
    fi

    # Create directory if needed
    local dir_path=$(dirname "$validated_path")
    if [[ ! -d "$dir_path" ]]; then
        mkdir -p "$dir_path" 2>/dev/null || {
            secure_error_exit "Failed to create directory: $dir_path"
        }
        chmod 0700 "$dir_path"
    fi

    # Write file atomically
    local temp_file="${validated_path}.tmp.$$"
    echo "$content" > "$temp_file" || {
        secure_error_exit "Failed to write to temporary file"
    }
    mv "$temp_file" "$validated_path" || {
        rm -f "$temp_file"
        secure_error_exit "Failed to move temporary file to destination"
    }

    # Set secure permissions
    chmod 0600 "$validated_path"

    secure_log "INFO" "File written successfully: $validated_path"
}

# Safe file delete
safe_file_delete() {
    local file_path="$1"

    # Validate file path
    local validated_path=$(validate_file_path "$file_path")

    # Check if file exists
    if [[ ! -f "$validated_path" ]]; then
        secure_error_exit "File not found: $validated_path"
    fi

    # Check if file is writable
    if [[ ! -w "$validated_path" ]]; then
        secure_error_exit "File not writable: $validated_path"
    fi

    # Delete file
    rm -f "$validated_path" || {
        secure_error_exit "Failed to delete file: $validated_path"
    }

    secure_log "INFO" "File deleted successfully: $validated_path"
}

# Export functions for use in other scripts
export -f secure_log
export -f secure_error_exit
export -f secure_json_output
export -f secure_json_escape
export -f validate_pci_address
export -f validate_gpu_address
export -f validate_profile_name
export -f validate_preference_key
export -f validate_username
export -f validate_integer
export -f validate_boolean
export -f validate_file_path
export -f validate_directory_path
export -f sanitize_filename
export -f safe_execute
export -f safe_file_read
export -f safe_file_write
export -f safe_file_delete
