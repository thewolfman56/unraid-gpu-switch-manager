#!/bin/bash

# setup_default_admin.sh
# Setup script for default admin user with password change requirement
# Usage: ./setup_default_admin.sh

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_DIR/config"
USERS_FILE="$CONFIG_DIR/users.json"
LOG_FILE="/var/log/gpu.switch.manager.log"

# Source secure shell library
source "$SCRIPT_DIR/secure_shell_lib.sh"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    secure_log "$level" "[SETUP_DEFAULT_ADMIN] $message"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    secure_error_exit "$1"
}

# Initialize configuration directory
init_config_dir() {
    log "INFO" "Initializing configuration directory"

    # Create config directory if it doesn't exist
    mkdir -p "$CONFIG_DIR"

    # Set secure permissions
    chmod 700 "$CONFIG_DIR"
}

# Check if users file exists
check_users_file() {
    if [[ -f "$USERS_FILE" ]]; then
        log "INFO" "Users file already exists: $USERS_FILE"
        return 1
    fi

    log "INFO" "Users file does not exist, will create: $USERS_FILE"
    return 0
}

# Generate secure random password
generate_password() {
    local length="${1:-16}"
    local password=""

    # Character sets
    local uppercase="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local lowercase="abcdefghijklmnopqrstuvwxyz"
    local numbers="0123456789"
    local special="!@#$%^&*()_+-=[]{}|;:,.<>?"

    # Ensure at least one of each required character type
    password+="${uppercase:RANDOM%${#uppercase}:1}"
    password+="${lowercase:RANDOM%${#lowercase}:1}"
    password+="${numbers:RANDOM%${#numbers}:1}"
    password+="${special:RANDOM%${#special}:1}"

    # Fill remaining length with random characters
    local all="$uppercase$lowercase$numbers$special"
    for ((i=4; i<length; i++)); do
        password+="${all:RANDOM%${#all}:1}"
    done

    # Shuffle password
    echo "$password" | fold -w1 | shuf | tr -d '\n'
}

# Create default admin user
create_default_admin() {
    log "INFO" "Creating default admin user"

    # Generate secure password
    local admin_password
    admin_password=$(generate_password 16)

    # Hash password
    local password_hash
    password_hash=$(php -r "echo password_hash('$admin_password', PASSWORD_DEFAULT);")

    # Get current timestamp
    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    # Create user data
    local user_data
    user_data=$(cat <<EOF
{
  "users": [
    {
      "id": "admin",
      "username": "admin",
      "password_hash": "$password_hash",
      "email": null,
      "role": "admin",
      "active": true,
      "created": "$timestamp",
      "last_login": null,
      "force_password_change": true,
      "is_default_password": true,
      "password_changed_at": null
    }
  ]
}
EOF
)

    # Write users file
    echo "$user_data" > "$USERS_FILE"

    # Set secure permissions
    chmod 600 "$USERS_FILE"

    log "INFO" "Default admin user created successfully"
    log "WARNING" "DEFAULT PASSWORD MUST BE CHANGED: $admin_password"
    log "WARNING" "Please save this password securely and change it immediately after first login"

    # Display password to user
    echo ""
    echo "=========================================="
    echo "DEFAULT ADMIN USER CREATED"
    echo "=========================================="
    echo "Username: admin"
    echo "Password: $admin_password"
    echo "=========================================="
    echo ""
    echo "IMPORTANT: Please change this password immediately after first login!"
    echo "The system will require you to change the password on first login."
    echo ""
}

# Verify setup
verify_setup() {
    log "INFO" "Verifying setup"

    if [[ ! -f "$USERS_FILE" ]]; then
        error_exit "Users file not found: $USERS_FILE"
    fi

    # Check file permissions
    local permissions
    permissions=$(stat -c '%a' "$USERS_FILE" 2>/dev/null || stat -f '%A' "$USERS_FILE" 2>/dev/null || echo "0000")

    if [[ "$permissions" != "600" ]]; then
        log "WARNING" "Users file permissions are not secure: $permissions (should be 600)"
        chmod 600 "$USERS_FILE"
        log "INFO" "Fixed file permissions to 600"
    fi

    # Verify JSON structure
    if ! jq . "$USERS_FILE" >/dev/null 2>&1; then
        error_exit "Users file is not valid JSON"
    fi

    # Verify admin user exists
    local admin_exists
    admin_exists=$(jq -r '.users[] | select(.username == "admin") | .username' "$USERS_FILE")

    if [[ "$admin_exists" != "admin" ]]; then
        error_exit "Admin user not found in users file"
    fi

    # Verify force_password_change is set
    local force_change
    force_change=$(jq -r '.users[] | select(.username == "admin") | .force_password_change' "$USERS_FILE")

    if [[ "$force_change" != "true" ]]; then
        log "WARNING" "force_password_change not set for admin user"
    fi

    log "INFO" "Setup verification completed successfully"
}

# Display setup summary
display_summary() {
    echo ""
    echo "=========================================="
    echo "SETUP SUMMARY"
    echo "=========================================="
    echo "Users file: $USERS_FILE"
    echo "Config directory: $CONFIG_DIR"
    echo "Log file: $LOG_FILE"
    echo ""
    echo "Default admin user: admin"
    echo "Password change required: YES"
    echo ""
    echo "Next steps:"
    echo "1. Log in with the default admin credentials"
    echo "2. You will be required to change the password immediately"
    echo "3. Choose a strong password that meets the requirements:"
    echo "   - Minimum 12 characters"
    echo "   - At least one uppercase letter"
    echo "   - At least one lowercase letter"
    echo "   - At least one number"
    echo "   - At least one special character"
    echo "4. The system will track password history (last 5 passwords)"
    echo "=========================================="
    echo ""
}

# Main function
main() {
    log "INFO" "Starting default admin user setup"

    # Initialize configuration directory
    init_config_dir

    # Check if users file exists
    if check_users_file; then
        # Create default admin user
        create_default_admin
    else
        log "WARNING" "Users file already exists, skipping creation"
        echo "Users file already exists. Skipping default admin user creation."
        echo "If you want to reset the admin user, please delete the existing users file first."
        exit 0
    fi

    # Verify setup
    verify_setup

    # Display summary
    display_summary

    log "INFO" "Default admin user setup completed successfully"
}

# Run main function
main "$@"