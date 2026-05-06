#!/bin/bash

# config_template.sh
# Configuration template manager for GPU Switch Manager
# Usage: ./config_template.sh <command> [arguments]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_DIR/config"
TEMPLATES_DIR="$CONFIG_DIR/templates"
# Source secure shell library
source "$SCRIPT_DIR/secure_shell_lib.sh"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    secure_log "$level" "[CONFIG_TEMPLATE] $message"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    secure_error_exit "$1"
}

# Initialize templates directory
init_templates_dir() {
    log "INFO" "Initializing templates directory"

    # Create templates directory
    mkdir -p "$TEMPLATES_DIR"

    # Create default templates if they don't exist
    if [[ ! -f "$TEMPLATES_DIR/basic.json" ]]; then
        local basic_template='{
  "name": "basic",
  "description": "Basic GPU switching template",
  "version": "1.0.0",
  "profiles": {
    "default": {
      "name": "default",
      "description": "Default profile",
      "gpu_bindings": {},
      "service_preferences": {},
      "event_handlers": {},
      "safety_checks": {
        "check_active_usage": true,
        "check_dependencies": true,
        "check_resources": true
      },
      "created_at": "2026-05-03T12:00:00Z",
      "updated_at": "2026-05-03T12:00:00Z"
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

        echo "$basic_template" > "$TEMPLATES_DIR/basic.json"
        log "INFO" "Created basic template"
    fi

    if [[ ! -f "$TEMPLATES_DIR/advanced.json" ]]; then
        local advanced_template='{
  "name": "advanced",
  "description": "Advanced GPU switching template with all features",
  "version": "1.0.0",
  "profiles": {
    "gaming": {
      "name": "gaming",
      "description": "Gaming profile with GPU passthrough",
      "gpu_bindings": {
        "0000:01:00.0": {
          "driver": "nvidia",
          "vfio_enabled": true,
          "audio_passthrough": true
        }
      },
      "service_preferences": {
        "docker": {
          "auto_restart": false,
          "graceful_shutdown": true
        },
        "vm": {
          "auto_restart": true,
          "graceful_shutdown": true
        }
      },
      "event_handlers": {
        "vm_start": {
          "enabled": true,
          "auto_switch": true
        },
        "vm_stop": {
          "enabled": true,
          "auto_switch": true
        }
      },
      "safety_checks": {
        "check_active_usage": true,
        "check_dependencies": true,
        "check_resources": true
      },
      "created_at": "2026-05-03T12:00:00Z",
      "updated_at": "2026-05-03T12:00:00Z"
    },
    "workstation": {
      "name": "workstation",
      "description": "Workstation profile with GPU available for Docker",
      "gpu_bindings": {
        "0000:01:00.0": {
          "driver": "nvidia",
          "vfio_enabled": false,
          "audio_passthrough": false
        }
      },
      "service_preferences": {
        "docker": {
          "auto_restart": true,
          "graceful_shutdown": true
        },
        "vm": {
          "auto_restart": false,
          "graceful_shutdown": true
        }
      },
      "event_handlers": {
        "docker_start": {
          "enabled": true,
          "auto_switch": true
        },
        "docker_stop": {
          "enabled": true,
          "auto_switch": true
        }
      },
      "safety_checks": {
        "check_active_usage": true,
        "check_dependencies": true,
        "check_resources": true
      },
      "created_at": "2026-05-03T12:00:00Z",
      "updated_at": "2026-05-03T12:00:00Z"
    }
  },
  "preferences": {
    "auto_switch": true,
    "auto_backup": true,
    "backup_interval": 86400,
    "log_level": "DEBUG",
    "notification_enabled": true,
    "max_backups": 20,
    "backup_retention_days": 60,
    "auto_cleanup": true,
    "debug_mode": true,
    "verbose_logging": true
  },
  "services": {
    "docker": {
      "auto_restart": true,
      "graceful_shutdown": true,
      "timeout": 60
    },
    "vm": {
      "auto_restart": true,
      "graceful_shutdown": true,
      "timeout": 120
    }
  }
}'

        echo "$advanced_template" > "$TEMPLATES_DIR/advanced.json"
        log "INFO" "Created advanced template"
    fi

    if [[ ! -f "$TEMPLATES_DIR/minimal.json" ]]; then
        local minimal_template='{
  "name": "minimal",
  "description": "Minimal GPU switching template",
  "version": "1.0.0",
  "profiles": {
    "default": {
      "name": "default",
      "description": "Default profile",
      "gpu_bindings": {},
      "service_preferences": {},
      "event_handlers": {},
      "safety_checks": {
        "check_active_usage": true,
        "check_dependencies": true,
        "check_resources": true
      },
      "created_at": "2026-05-03T12:00:00Z",
      "updated_at": "2026-05-03T12:00:00Z"
    }
  },
  "preferences": {
    "auto_switch": false,
    "auto_backup": false,
    "backup_interval": 86400,
    "log_level": "ERROR",
    "notification_enabled": false
  },
  "services": {
    "docker": {
      "auto_restart": false,
      "graceful_shutdown": false,
      "timeout": 30
    },
    "vm": {
      "auto_restart": false,
      "graceful_shutdown": false,
      "timeout": 60
    }
  }
}'

        echo "$minimal_template" > "$TEMPLATES_DIR/minimal.json"
        log "INFO" "Created minimal template"
    fi

    echo '{"success":true,"message":"Templates directory initialized","templates_dir":"'"$TEMPLATES_DIR"'"}' | jq .
}

# Create template
create_template() {
    local template_name="$1"
    local description="${2:-}"
    local config="${3:-}"

    log "INFO" "Creating template: $template_name"

    # Initialize templates directory
    init_templates_dir >/dev/null

    local template_file="$TEMPLATES_DIR/$template_name.json"

    if [[ -f "$template_file" ]]; then
        error_exit "Template already exists: $template_name"
    fi

    # Create template
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    local template='{
  "name": "'"$template_name"'",
  "description": "'"$description"'",
  "version": "1.0.0",
  "profiles": {},
  "preferences": {},
  "services": {},
  "created_at": "'"$timestamp"'",
  "updated_at": "'"$timestamp"'"
}'

    # Merge with provided config if available
    if [[ -n "$config" ]]; then
        if echo "$config" | jq . >/dev/null 2>&1; then
            template=$(echo "$template" "$config" | jq -s '.[0] * .[1]')
        else
            error_exit "Invalid template configuration"
        fi
    fi

    # Save template
    echo "$template" > "$template_file"

    echo '{"success":true,"message":"Template created","template_name":"'"$template_name"'","template_file":"'"$template_file"'"}' | jq .
}

# List templates
list_templates() {
    log "INFO" "Listing templates"

    # Initialize templates directory
    init_templates_dir >/dev/null

    local templates='[]'

    for template_file in "$TEMPLATES_DIR"/*.json; do
        if [[ -f "$template_file" ]]; then
            local template=$(cat "$template_file")
            local template_name=$(echo "$template" | jq -r '.name')
            local template_description=$(echo "$template" | jq -r '.description')
            local template_version=$(echo "$template" | jq -r '.version')
            local template_info='{"name":"'"$template_name"'","description":"'"$template_description"'","version":"'"$template_version"'"}'

            templates=$(echo "$templates" | jq --argjson info "$template_info" '. + [$info]')
        fi
    done

    echo '{"success":true,"templates":'"$templates"',"count":'"$(echo "$templates" | jq 'length')"'}' | jq .
}

# Apply template
apply_template() {
    local template_name="$1"
    local config_path="${2:-$CONFIG_DIR/config.json}"

    log "INFO" "Applying template: $template_name"

    # Initialize templates directory
    init_templates_dir >/dev/null

    local template_file="$TEMPLATES_DIR/$template_name.json"

    if [[ ! -f "$template_file" ]]; then
        error_exit "Template not found: $template_name"
    fi

    # Load template
    local template=$(cat "$template_file")

    # Validate template
    if ! echo "$template" | jq . >/dev/null 2>&1; then
        error_exit "Invalid template"
    fi

    # Create backup of current configuration
    if [[ -f "$config_path" ]]; then
        local backup_file="$CONFIG_DIR/backups/config_$(date +%Y%m%d_%H%M%S).json"
        mkdir -p "$CONFIG_DIR/backups"
        cp "$config_path" "$backup_file"
        log "INFO" "Created backup: $backup_file"
    fi

    # Apply template
    echo "$template" > "$config_path"

    echo '{"success":true,"message":"Template applied","template_name":"'"$template_name"'","config_path":"'"$config_path"'"}' | jq .
}

# Validate template
validate_template() {
    local template_name="$1"

    log "INFO" "Validating template: $template_name"

    # Initialize templates directory
    init_templates_dir >/dev/null

    local template_file="$TEMPLATES_DIR/$template_name.json"

    if [[ ! -f "$template_file" ]]; then
        error_exit "Template not found: $template_name"
    fi

    local template=$(cat "$template_file")
    local errors='[]'

    # Check if valid JSON
    if ! echo "$template" | jq . >/dev/null 2>&1; then
        errors=$(echo "$errors" | jq '. + [{"error":"Invalid JSON template"}]')
    fi

    # Check required fields
    local required_fields=("name" "description" "version" "profiles" "preferences" "services")
    for field in "${required_fields[@]}"; do
        if ! echo "$template" | jq -e ".$field" >/dev/null 2>&1; then
            errors=$(echo "$errors" | jq '. + [{"error":"Missing required field: '"$field"'"}]')
        fi
    done

    # Check version format
    local version=$(echo "$template" | jq -r '.version')
    if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        errors=$(echo "$errors" | jq '. + [{"error":"Invalid version format"}]')
    fi

    # Build result
    local error_count=$(echo "$errors" | jq 'length')
    local valid=$([[ $error_count -eq 0 ]] && echo "true" || echo "false")

    echo '{"valid":'"$valid"',"template_name":"'"$template_name"'","errors":'"$errors"',"error_count":'"$error_count"'}' | jq .
}

# Customize template
customize_template() {
    local template_name="$1"
    local customizations="$2"

    log "INFO" "Customizing template: $template_name"

    # Initialize templates directory
    init_templates_dir >/dev/null

    local template_file="$TEMPLATES_DIR/$template_name.json"

    if [[ ! -f "$template_file" ]]; then
        error_exit "Template not found: $template_name"
    fi

    # Validate customizations
    if ! echo "$customizations" | jq . >/dev/null 2>&1; then
        error_exit "Invalid customizations"
    fi

    # Load template
    local template=$(cat "$template_file")

    # Apply customizations
    local customized_template=$(echo "$template" "$customizations" | jq -s '.[0] * .[1]')

    # Update timestamp
    customized_template=$(echo "$customized_template" | jq --arg timestamp "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" '.updated_at = $timestamp')

    # Save customized template
    echo "$customized_template" > "$template_file"

    echo '{"success":true,"message":"Template customized","template_name":"'"$template_name"'"}' | jq .
}

# Delete template
delete_template() {
    local template_name="$1"

    log "INFO" "Deleting template: $template_name"

    # Initialize templates directory
    init_templates_dir >/dev/null

    local template_file="$TEMPLATES_DIR/$template_name.json"

    if [[ ! -f "$template_file" ]]; then
        error_exit "Template not found: $template_name"
    fi

    # Delete template
    rm -f "$template_file"

    echo '{"success":true,"message":"Template deleted","template_name":"'"$template_name"'"}' | jq .
}

# Export template
export_template() {
    local template_name="$1"
    local export_file="${2:-${template_name}_template.json}"

    log "INFO" "Exporting template: $template_name"

    # Initialize templates directory
    init_templates_dir >/dev/null

    local template_file="$TEMPLATES_DIR/$template_name.json"

    if [[ ! -f "$template_file" ]]; then
        error_exit "Template not found: $template_name"
    fi

    # Copy template
    cp "$template_file" "$export_file"

    echo '{"success":true,"message":"Template exported","template_name":"'"$template_name"'","export_file":"'"$export_file"'"}' | jq .
}

# Import template
import_template() {
    local import_file="$1"
    local template_name="${2:-}"

    log "INFO" "Importing template from $import_file"

    if [[ ! -f "$import_file" ]]; then
        error_exit "Import file not found: $import_file"
    fi

    # Validate import
    if ! cat "$import_file" | jq . >/dev/null 2>&1; then
        error_exit "Invalid import file"
    fi

    # Get template name from file if not provided
    if [[ -z "$template_name" ]]; then
        template_name=$(cat "$import_file" | jq -r '.name')
    fi

    if [[ -z "$template_name" ]]; then
        error_exit "Template name not found in import file"
    fi

    # Initialize templates directory
    init_templates_dir >/dev/null

    local template_file="$TEMPLATES_DIR/$template_name.json"

    if [[ -f "$template_file" ]]; then
        error_exit "Template already exists: $template_name"
    fi

    # Copy template
    cp "$import_file" "$template_file"

    echo '{"success":true,"message":"Template imported","template_name":"'"$template_name"'"}' | jq .
}

# Get template info
get_template_info() {
    local template_name="$1"

    log "INFO" "Getting template info: $template_name"

    # Initialize templates directory
    init_templates_dir >/dev/null

    local template_file="$TEMPLATES_DIR/$template_name.json"

    if [[ ! -f "$template_file" ]]; then
        error_exit "Template not found: $template_name"
    fi

    local template=$(cat "$template_file")

    echo "$template" | jq .
}

# Test template
test_template() {
    local template_name="$1"

    log "INFO" "Testing template: $template_name"

    # Initialize templates directory
    init_templates_dir >/dev/null

    local template_file="$TEMPLATES_DIR/$template_name.json"

    if [[ ! -f "$template_file" ]]; then
        error_exit "Template not found: $template_name"
    fi

    # Validate template
    local validation=$(validate_template "$template_name")
    local valid=$(echo "$validation" | jq -r '.valid')

    if [[ "$valid" == "true" ]]; then
        echo '{"success":true,"result":"passed","template_name":"'"$template_name"'"}' | jq .
    else
        echo '{"success":true,"result":"failed","template_name":"'"$template_name"'","validation":'"$validation"'}' | jq .
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
        init)
            init_templates_dir
            ;;
        create)
            create_template "$@"
            ;;
        list)
            list_templates
            ;;
        apply)
            apply_template "$@"
            ;;
        validate)
            validate_template "$@"
            ;;
        customize)
            customize_template "$@"
            ;;
        delete)
            delete_template "$@"
            ;;
        export)
            export_template "$@"
            ;;
        import)
            import_template "$@"
            ;;
        info)
            get_template_info "$@"
            ;;
        test)
            test_template "$@"
            ;;
        *)
            error_exit "Unknown command: $command"
            ;;
    esac
}

# Run main function
main "$@"
