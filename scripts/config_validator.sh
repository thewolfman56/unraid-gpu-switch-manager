#!/bin/bash

# config_validator.sh
# Configuration validator for GPU Switch Manager
# Usage: ./config_validator.sh <command> [arguments]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_DIR/config"
VALIDATION_RULES_FILE="$CONFIG_DIR/validation_rules.json"
# Source secure shell library
source "$SCRIPT_DIR/secure_shell_lib.sh"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    secure_log "$level" "[CONFIG_VALIDATOR] $message"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    secure_error_exit "$1"
}

# Initialize validation rules
init_validation_rules() {
    log "INFO" "Initializing validation rules"

    # Create config directory if it doesn't exist
    mkdir -p "$CONFIG_DIR"

    # Create default validation rules if they don't exist
    if [[ ! -f "$VALIDATION_RULES_FILE" ]]; then
        local default_rules='{
  "schema": {
    "version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$",
      "required": true
    },
    "profiles": {
      "type": "object",
      "required": true
    },
    "preferences": {
      "type": "object",
      "required": true
    },
    "services": {
      "type": "object",
      "required": true
    }
  },
  "references": {
    "gpu_bindings": {
      "check": "gpu_exists",
      "message": "GPU address must exist"
    },
    "service_preferences": {
      "check": "service_exists",
      "message": "Service must exist"
    }
  },
  "dependencies": {
    "gpu_bindings": {
      "requires": ["driver"],
      "message": "GPU binding requires driver specification"
    },
    "event_handlers": {
      "requires": ["enabled"],
      "message": "Event handler requires enabled flag"
    }
  },
  "conflicts": {
    "auto_switch": {
      "conflicts_with": ["manual_mode"],
      "message": "Auto switch conflicts with manual mode"
    }
  }
}'

        echo "$default_rules" > "$VALIDATION_RULES_FILE"
        log "INFO" "Created default validation rules"
    fi

    echo '{"success":true,"message":"Validation rules initialized"}' | jq .
}

# Load validation rules
load_validation_rules() {
    log "INFO" "Loading validation rules"

    if [[ ! -f "$VALIDATION_RULES_FILE" ]]; then
        init_validation_rules >/dev/null
    fi

    local rules=$(cat "$VALIDATION_RULES_FILE")

    echo "$rules"
}

# Validate against schema
validate_schema() {
    local config="$1"
    local schema="${2:-$(load_validation_rules | jq '.schema')}"

    log "INFO" "Validating against schema"

    local errors='[]'

    # Check if config is valid JSON
    if ! echo "$config" | jq . >/dev/null 2>&1; then
        errors=$(echo "$errors" | jq '. + [{"error":"Invalid JSON configuration"}]')
        echo '{"valid":false,"errors":'"$errors"'}' | jq .
        return
    fi

    # Validate schema
    for field in $(echo "$schema" | jq -r 'keys[]'); do
        local field_config=$(echo "$schema" | jq ".$field")
        local field_type=$(echo "$field_config" | jq -r '.type')
        local field_required=$(echo "$field_config" | jq -r '.required')
        local field_pattern=$(echo "$field_config" | jq -r '.pattern // empty')

        # Check if field exists
        if ! echo "$config" | jq -e ".$field" >/dev/null 2>&1; then
            if [[ "$field_required" == "true" ]]; then
                errors=$(echo "$errors" | jq '. + [{"error":"Missing required field: '"$field"'"}]')
            fi
            continue
        fi

        # Check field type
        local field_value=$(echo "$config" | jq ".$field")
        local actual_type=$(echo "$field_value" | jq -r 'type')

        case "$field_type" in
            string)
                if [[ "$actual_type" != "string" ]]; then
                    errors=$(echo "$errors" | jq '. + [{"error":"Field '"$field"' must be string"}]')
                fi
                ;;
            number)
                if [[ "$actual_type" != "number" ]]; then
                    errors=$(echo "$errors" | jq '. + [{"error":"Field '"$field"' must be number"}]')
                fi
                ;;
            boolean)
                if [[ "$actual_type" != "boolean" ]]; then
                    errors=$(echo "$errors" | jq '. + [{"error":"Field '"$field"' must be boolean"}]')
                fi
                ;;
            object)
                if [[ "$actual_type" != "object" ]]; then
                    errors=$(echo "$errors" | jq '. + [{"error":"Field '"$field"' must be object"}]')
                fi
                ;;
            array)
                if [[ "$actual_type" != "array" ]]; then
                    errors=$(echo "$errors" | jq '. + [{"error":"Field '"$field"' must be array"}]')
                fi
                ;;
        esac

        # Check pattern if specified
        if [[ -n "$field_pattern" ]] && [[ "$actual_type" == "string" ]]; then
            local field_string=$(echo "$field_value" | jq -r '.')
            if ! [[ "$field_string" =~ $field_pattern ]]; then
                errors=$(echo "$errors" | jq '. + [{"error":"Field '"$field"' does not match pattern"}]')
            fi
        fi
    done

    # Build result
    local error_count=$(echo "$errors" | jq 'length')
    local valid=$([[ $error_count -eq 0 ]] && echo "true" || echo "false")

    echo '{"valid":'"$valid"',"errors":'"$errors"',"error_count":'"$error_count"'}' | jq .
}

# Validate references
validate_references() {
    local config="$1"

    log "INFO" "Validating references"

    local errors='[]'

    # Check GPU bindings references
    local gpu_bindings=$(echo "$config" | jq '.profiles // {} | to_entries[] | select(.value.gpu_bindings) | .value.gpu_bindings | keys[]' 2>/dev/null || echo "")

    for gpu_address in $gpu_bindings; do
        # Remove quotes
        gpu_address=$(echo "$gpu_address" | tr -d '"')

        # Check if GPU exists (placeholder - would need actual GPU discovery)
        if [[ -n "$gpu_address" ]]; then
            log "INFO" "Checking GPU reference: $gpu_address"
            # In real implementation, would check against actual GPU list
        fi
    done

    # Check service preferences references
    local services=$(echo "$config" | jq '.services // {} | keys[]' 2>/dev/null || echo "")

    for service in $services; do
        # Remove quotes
        service=$(echo "$service" | tr -d '"')

        # Check if service is valid
        case "$service" in
            docker|vm|array)
                # Valid service
                ;;
            *)
                errors=$(echo "$errors" | jq '. + [{"error":"Invalid service: '"$service"'"}]')
                ;;
        esac
    done

    # Build result
    local error_count=$(echo "$errors" | jq 'length')
    local valid=$([[ $error_count -eq 0 ]] && echo "true" || echo "false")

    echo '{"valid":'"$valid"',"errors":'"$errors"',"error_count":'"$error_count"'}' | jq .
}

# Validate dependencies
validate_dependencies() {
    local config="$1"

    log "INFO" "Validating dependencies"

    local errors='[]'

    # Check GPU binding dependencies
    local profiles=$(echo "$config" | jq '.profiles // {} | keys[]' 2>/dev/null || echo "")

    for profile in $profiles; do
        # Remove quotes
        profile=$(echo "$profile" | tr -d '"')

        local gpu_bindings=$(echo "$config" | jq ".profiles.\"$profile\".gpu_bindings // {}")

        for gpu_address in $(echo "$gpu_bindings" | jq -r 'keys[]'); do
            local binding=$(echo "$gpu_bindings" | jq ".$gpu_address")

            # Check if driver is specified
            local driver=$(echo "$binding" | jq -r '.driver // empty')
            if [[ -z "$driver" ]]; then
                errors=$(echo "$errors" | jq '. + [{"error":"GPU binding '"$gpu_address"' missing driver specification"}]')
            fi
        done
    done

    # Check event handler dependencies
    for profile in $profiles; do
        # Remove quotes
        profile=$(echo "$profile" | tr -d '"')

        local event_handlers=$(echo "$config" | jq ".profiles.\"$profile\".event_handlers // {}")

        for event in $(echo "$event_handlers" | jq -r 'keys[]'); do
            local handler=$(echo "$event_handlers" | jq ".$event")

            # Check if enabled is specified
            local enabled=$(echo "$handler" | jq -r '.enabled // empty')
            if [[ -z "$enabled" ]]; then
                errors=$(echo "$errors" | jq '. + [{"error":"Event handler '"$event"' missing enabled flag"}]')
            fi
        done
    done

    # Build result
    local error_count=$(echo "$errors" | jq 'length')
    local valid=$([[ $error_count -eq 0 ]] && echo "true" || echo "false")

    echo '{"valid":'"$valid"',"errors":'"$errors"',"error_count":'"$error_count"'}' | jq .
}

# Detect conflicts
detect_conflicts() {
    local config="$1"

    log "INFO" "Detecting conflicts"

    local errors='[]'

    # Check for auto_switch vs manual_mode conflict
    local auto_switch=$(echo "$config" | jq -r '.preferences.auto_switch // false')
    local manual_mode=$(echo "$config" | jq -r '.preferences.manual_mode // false')

    if [[ "$auto_switch" == "true" ]] && [[ "$manual_mode" == "true" ]]; then
        errors=$(echo "$errors" | jq '. + [{"error":"Auto switch conflicts with manual mode"}]')
    fi

    # Check for duplicate GPU bindings
    local gpu_bindings=$(echo "$config" | jq '.profiles // {} | to_entries[] | .value.gpu_bindings | keys[]' 2>/dev/null || echo "")
    local seen_gpus=()

    for gpu_address in $gpu_bindings; do
        # Remove quotes
        gpu_address=$(echo "$gpu_address" | tr -d '"')

        if [[ " ${seen_gpus[@]} " =~ " ${gpu_address} " ]]; then
            errors=$(echo "$errors" | jq '. + [{"error":"Duplicate GPU binding: '"$gpu_address"'"}]')
        else
            seen_gpus+=("$gpu_address")
        fi
    done

    # Build result
    local error_count=$(echo "$errors" | jq 'length')
    local valid=$([[ $error_count -eq 0 ]] && echo "true" || echo "false")

    echo '{"valid":'"$valid"',"errors":'"$errors"',"error_count":'"$error_count"'}' | jq .
}

# Generate validation report
generate_report() {
    local config="$1"

    log "INFO" "Generating validation report"

    local schema_result=$(validate_schema "$config")
    local references_result=$(validate_references "$config")
    local dependencies_result=$(validate_dependencies "$config")
    local conflicts_result=$(detect_conflicts "$config")

    local schema_valid=$(echo "$schema_result" | jq -r '.valid')
    local references_valid=$(echo "$references_result" | jq -r '.valid')
    local dependencies_valid=$(echo "$dependencies_result" | jq -r '.valid')
    local conflicts_valid=$(echo "$conflicts_result" | jq -r '.valid')

    local all_valid=$([[ "$schema_valid" == "true" ]] && [[ "$references_valid" == "true" ]] && [[ "$dependencies_valid" == "true" ]] && [[ "$conflicts_valid" == "true" ]] && echo "true" || echo "false")

    local total_errors=$(echo "$schema_result" | jq '.error_count' + "$references_result" | jq '.error_count' + "$dependencies_result" | jq '.error_count' + "$conflicts_result" | jq '.error_count')

    local report='{
  "valid": '"$all_valid"',
  "total_errors": '"$total_errors"',
  "schema": '"$schema_result"',
  "references": '"$references_result"',
  "dependencies": '"$dependencies_result"',
  "conflicts": '"$conflicts_result"',
  "timestamp": "'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"
}'

    echo "$report" | jq .
}

# Fix errors
fix_errors() {
    local config="$1"
    local errors="$2"

    log "INFO" "Fixing errors"

    local fixed_config="$config"
    local fixed_count=0

    # Fix missing required fields with defaults
    for error in $(echo "$errors" | jq -r '.[] | select(.error | contains("Missing required field")) | .error'); do
        local field=$(echo "$error" | sed 's/.*: //')
        log "INFO" "Fixing missing field: $field"

        case "$field" in
            version)
                fixed_config=$(echo "$fixed_config" | jq '.version = "1.0.0"')
                fixed_count=$((fixed_count + 1))
                ;;
            profiles)
                fixed_config=$(echo "$fixed_config" | jq '.profiles = {}')
                fixed_count=$((fixed_count + 1))
                ;;
            preferences)
                fixed_config=$(echo "$fixed_config" | jq '.preferences = {}')
                fixed_count=$((fixed_count + 1))
                ;;
            services)
                fixed_config=$(echo "$fixed_config" | jq '.services = {}')
                fixed_count=$((fixed_count + 1))
                ;;
        esac
    done

    echo '{"success":true,"fixed_count":'"$fixed_count"',"fixed_config":'"$fixed_config"'}' | jq .
}

# Get validation rules
get_validation_rules() {
    log "INFO" "Getting validation rules"

    local rules=$(load_validation_rules)

    echo "$rules" | jq .
}

# Add validation rule
add_validation_rule() {
    local rule_type="$1"
    local rule_name="$2"
    local rule_config="$3"

    log "INFO" "Adding validation rule: $rule_type/$rule_name"

    local rules=$(load_validation_rules)

    # Add rule
    local updated_rules=$(echo "$rules" | jq --arg type "$rule_type" --arg name "$rule_name" --argjson config "$rule_config" '.[$type][$name] = $config')

    # Save rules
    echo "$updated_rules" > "$VALIDATION_RULES_FILE"

    echo '{"success":true,"message":"Validation rule added","rule_type":"'"$rule_type"'","rule_name":"'"$rule_name"'"}' | jq .
}

# Remove validation rule
remove_validation_rule() {
    local rule_type="$1"
    local rule_name="$2"

    log "INFO" "Removing validation rule: $rule_type/$rule_name"

    local rules=$(load_validation_rules)

    # Remove rule
    local updated_rules=$(echo "$rules" | jq --arg type "$rule_type" --arg name "$rule_name" 'del(.[$type][$name])')

    # Save rules
    echo "$updated_rules" > "$VALIDATION_RULES_FILE"

    echo '{"success":true,"message":"Validation rule removed","rule_type":"'"$rule_type"'","rule_name":"'"$rule_name"'"}' | jq .
}

# Test validation
test_validation() {
    local config="$1"

    log "INFO" "Testing validation"

    local report=$(generate_report "$config")

    echo "$report" | jq .
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
            init_validation_rules
            ;;
        schema)
            validate_schema "$@"
            ;;
        references)
            validate_references "$@"
            ;;
        dependencies)
            validate_dependencies "$@"
            ;;
        conflicts)
            detect_conflicts "$@"
            ;;
        report)
            generate_report "$@"
            ;;
        fix)
            fix_errors "$@"
            ;;
        rules)
            get_validation_rules
            ;;
        add-rule)
            add_validation_rule "$@"
            ;;
        remove-rule)
            remove_validation_rule "$@"
            ;;
        test)
            test_validation "$@"
            ;;
        *)
            error_exit "Unknown command: $command"
            ;;
    esac
}

# Run main function
main "$@"
