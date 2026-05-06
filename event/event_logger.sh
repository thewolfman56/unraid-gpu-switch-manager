#!/bin/bash

# event_logger.sh
# Event logging utility for GPU switching events
# Usage: ./event_logger.sh <log_level> <event_type> <message> [additional_data...]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source secure shell library
source "$SCRIPT_DIR/secure_shell_lib.sh"
EVENT_LOG="/var/log/gpu-switch-manager/events.log"
EVENT_HISTORY_DIR="/var/lib/gpu-switch-manager/event_history"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S'
    secure_log "$level" "[EVENT_LOGGER] $message"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    secure_error_exit "$1"
}

# Validate log level
validate_log_level() {
    local log_level="$1"

    case "$log_level" in
        DEBUG|INFO|WARN|ERROR)
            return 0
            ;;
        *)
            error_exit "Invalid log level: $log_level (must be DEBUG, INFO, WARN, or ERROR)"
            ;;
    esac
}

# Validate event type
validate_event_type() {
    local event_type="$1"

    case "$event_type" in
        vm_start|vm_stop|docker_start|docker_stop|manual_switch|system_event|error_event)
            return 0
            ;;
        *)
            error_exit "Invalid event type: $event_type"
            ;;
    esac
}

# Create event history directory
create_event_history_dir() {
    mkdir -p "$EVENT_HISTORY_DIR"
}

# Log event to event log
log_event() {
    local log_level="$1"
    local event_type="$2"
    local message="$3"
    shift 3
    local additional_data=("$@")

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local timestamp_iso=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    # Log to event log
    echo "[$timestamp] [$log_level] [$event_type] $message" >> "$EVENT_LOG"

    # Create event JSON
    local event_json='{"timestamp":"'"$timestamp_iso"'","log_level":"'"$log_level"'","event_type":"'"$event_type"'","message":"'"$message"'","additional_data":{'

    # Add additional data if provided
    if [[ ${#additional_data[@]} -gt 0 ]]; then
        local first=true
        for data in "${additional_data[@]}"; do
            if [[ "$first" == "true" ]]; then
                event_json+='"'"$data"''
                first=false
            else
                event_json+=',"'"$data"'"
            fi
        done
    fi

    event_json+='}}'

    # Save event to history
    local event_file="$EVENT_HISTORY_DIR/event_$(date +%s)_$RANDOM.json"
    echo "$event_json" > "$event_file"

    echo "$event_file"
}

# Get event history
get_event_history() {
    local limit="${1:-100}"

    log "INFO" "Getting event history (limit: $limit)"

    if [[ ! -d "$EVENT_HISTORY_DIR" ]]; then
        echo '{"events":[],"count":0}'
        return
    fi

    # Get recent events
    local events_json='['
    local first=true
    local count=0

    for event_file in $(ls -t "$EVENT_HISTORY_DIR"/*.json 2>/dev/null | head -n "$limit"); do
        if [[ -f "$event_file" ]]; then
            local event_data=$(cat "$event_file")

            if [[ "$first" == "true" ]]; then
                events_json+="$event_data"
                first=false
            else
                events_json+=",$event_data"
            fi

            count=$((count + 1))
        fi
    done

    events_json+=']'

    echo '{"events":'"$events_json"',"count":'"$count"'}'
}

# Get event statistics
get_event_statistics() {
    log "INFO" "Getting event statistics"

    local total_events=0
    local event_types='{}'

    if [[ -d "$EVENT_HISTORY_DIR" ]]; then
        total_events=$(find "$EVENT_HISTORY_DIR" -type f -name "*.json" | wc -l)

        # Count events by type
        for event_file in "$EVENT_HISTORY_DIR"/*.json; do
            if [[ -f "$event_file" ]]; then
                local event_type=$(jq -r '.event_type' "$event_file")
                event_types=$(echo "$event_types" | jq --arg type "$event_type" '.[$type] += 1')
            fi
        done
    fi

    echo '{"total_events":'"$total_events"',"event_types":'"$event_types"',"timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}}'
}

# Clean up old events
cleanup_old_events() {
    local days="${1:-7}"

    log "INFO" "Cleaning up events older than $days days"

    if [[ ! -d "$EVENT_HISTORY_DIR" ]]; then
        echo '{"success":true,"message":"No event history directory","cleaned":0}'
        return
    fi

    # Remove events older than specified days
    local cleaned=0
    local cutoff_time=$(date -d "$days days ago" +%s)

    for event_file in "$EVENT_HISTORY_DIR"/*.json; do
        if [[ -f "$event_file" ]]; then
            local file_time=$(stat -c %Y "$event_file" 2>/dev/null || echo "0")

            if [[ "$file_time" -lt "$cutoff_time" ]]; then
                rm -f "$event_file"
                cleaned=$((cleaned + 1))
            fi
        fi
    done

    echo '{"success":true,"message":"Cleaned up old events","cleaned":'"$cleaned"',"days":'"$days"'}'
}

# Main function
main() {
    # Check arguments
    if [[ $# -lt 3 ]]; then
        error_exit "Usage: $0 <log_level> <event_type> <message> [additional_data...]"
    fi

    local log_level="$1"
    local event_type="$2"
    local message="$3"
    shift 3
    local additional_data=("$@")

    # Validate log level
    validate_log_level "$log_level"

    # Validate event type
    validate_event_type "$event_type"

    # Create event history directory
    create_event_history_dir

    # Log event
    local event_file=$(log_event "$log_level" "$event_type" "$message" "${additional_data[@]}")

    # Build JSON output
    local json_output='{"success":true,"log_level":"'"$log_level"'","event_type":"'"$event_type"'","message":"'"$message"'","event_file":"'"$event_file"'","timestamp":"'"$(date -u '+%Y-%m-%dT%H:%M:%SZ')"'"}}'

    echo "$json_output" | jq .
}

# Run main function
main "$@"