# Phase 3: Service Management Implementation Plan

## Overview
Phase 3 implements service management functionality to coordinate Docker containers and VMs during GPU switching operations. This includes starting/stopping GPU-dependent containers, managing VM services, tracking service dependencies, and monitoring service states.

## Files to Create

### 1. scripts/manage_docker_containers.sh
**Purpose:** Manage Docker containers during GPU switching
**Location:** `/usr/local/emhttp/plugins/gpu.switch.manager/scripts/`
**Input:** Operation (start/stop), container names
**Output:** JSON-formatted operation result

**Responsibilities:**
- Stop GPU containers before GPU binding
- Start CPU replacement containers when GPU unavailable
- Restore GPU containers after GPU unbinding
- Stop CPU replacement containers when GPU available
- Track container states
- Handle container dependencies
- Provide operation status

**Container Management Operations:**
- List GPU containers
- List CPU replacement containers
- Stop containers gracefully
- Start containers
- Check container status
- Save container states
- Restore container states

### 2. scripts/manage_vm_services.sh
**Purpose:** Manage VM services during GPU switching
**Location:** `/usr/local/emhttp/plugins/gpu.switch.manager/scripts/`
**Input:** Operation (start/stop), VM names
**Output:** JSON-formatted operation result

**Responsibilities:**
- Stop VMs before GPU unbinding
- Start VMs after GPU binding
- Check VM status
- Track VM states
- Handle VM dependencies
- Coordinate with libvirt
- Provide operation status

**VM Management Operations:**
- List VMs using specific GPU
- Stop VMs gracefully
- Start VMs
- Check VM status
- Get VM GPU configuration
- Track VM states

### 3. scripts/check_service_dependencies.sh
**Purpose:** Check service dependencies before GPU switching
**Location:** `/usr/local/emhttp/plugins/gpu.switch.manager/scripts/`
**Input:** GPU PCI address
**Output:** JSON-formatted dependency information

**Responsibilities:**
- Identify containers using GPU
- Identify VMs using GPU
- Check service states
- Determine safe switching windows
- Report blocking services
- Provide dependency recommendations

**Dependency Information:**
- GPU-dependent containers
- GPU-dependent VMs
- Service states
- Blocking services
- Safe switching status
- Recommendations

### 4. scripts/save_service_states.sh
**Purpose:** Save current service states before GPU switching
**Location:** `/usr/local/emhttp/plugins/gpu.switch.manager/scripts/`
**Input:** GPU PCI address
**Output:** JSON-formatted save result

**Responsibilities:**
- Save running container states
- Save running VM states
- Store state information
- Create state snapshot
- Handle save failures
- Provide save status

**State Information:**
- Container names and states
- VM names and states
- Timestamp
- GPU address
- Operation context

### 5. scripts/restore_service_states.sh
**Purpose:** Restore service states after GPU switching
**Location:** `/usr/local/emhttp/plugins/gpu.switch.manager/scripts/`
**Input:** State file path
**Output:** JSON-formatted restore result

**Responsibilities:**
- Read saved state information
- Restore container states
- Restore VM states
- Handle restore failures
- Verify restoration
- Provide restore status

**Restoration Operations:**
- Start stopped containers
- Stop started containers
- Start stopped VMs
- Verify service states
- Report restoration status

### 6. scripts/get_service_status.sh
**Purpose:** Get current status of all services
**Location:** `/usr/local/emhttp/plugins/gpu.switch.manager/scripts/`
**Input:** Service type (docker/vm/all)
**Output:** JSON-formatted service status

**Responsibilities:**
- Get Docker container status
- Get VM service status
- Check service health
- Report service states
- Identify GPU-dependent services
- Provide status summary

**Service Status Information:**
- Container names and states
- VM names and states
- GPU dependencies
- Service health
- Resource usage

### 7. scripts/validate_service_operation.sh
**Purpose:** Validate service operations before execution
**Location:** `/usr/local/emhttp/plugins/gpu.switch.manager/scripts/`
**Input:** Operation type, service names
**Output:** JSON-formatted validation result

**Responsibilities:**
- Validate service existence
- Check service states
- Verify operation safety
- Identify conflicts
- Provide validation results
- Report blocking issues

**Validation Checks:**
- Service existence
- Current service state
- Operation compatibility
- Dependency conflicts
- Resource availability
- Safety concerns

## Implementation Steps

### Step 1: Create manage_docker_containers.sh
1. Implement Docker container listing
2. Add container stop functionality
3. Add container start functionality
4. Implement state tracking
5. Add graceful shutdown handling
6. Implement error handling
7. Add logging
8. Format JSON output

### Step 2: Create manage_vm_services.sh
1. Implement VM listing
2. Add VM stop functionality
3. Add VM start functionality
4. Implement libvirt integration
5. Add state tracking
6. Implement error handling
7. Add logging
8. Format JSON output

### Step 3: Create check_service_dependencies.sh
1. Implement GPU dependency detection
2. Add container dependency checking
3. Add VM dependency checking
4. Implement state analysis
5. Add safety assessment
6. Implement error handling
7. Format JSON output

### Step 4: Create save_service_states.sh
1. Implement state collection
2. Add container state saving
3. Add VM state saving
4. Implement state file creation
5. Add error handling
6. Implement logging
7. Format JSON output

### Step 5: Create restore_service_states.sh
1. Implement state file reading
2. Add container state restoration
3. Add VM state restoration
4. Implement verification
5. Add error handling
6. Implement logging
7. Format JSON output

### Step 6: Create get_service_status.sh
1. Implement Docker status collection
2. Add VM status collection
3. Implement health checking
4. Add GPU dependency detection
5. Implement error handling
6. Format JSON output

### Step 7: Create validate_service_operation.sh
1. Implement service existence validation
2. Add state compatibility checking
3. Implement conflict detection
4. Add safety verification
5. Implement error handling
6. Format JSON output

### Step 8: Update GPUManager.php
1. Add service management methods
2. Add dependency checking methods
3. Add state management methods
4. Add validation methods
5. Update caching logic
6. Add error handling
7. Add integration with Phase 2 methods

### Step 9: Testing
1. Test Docker container management
2. Test VM service management
3. Test dependency checking
4. Test state saving/restoration
5. Test service status monitoring
6. Test operation validation
7. Test error scenarios
8. Test integration with Phase 2

## Technical Implementation Details

### Docker Container Management

```bash
# List all containers
docker ps -a --format "{{.Names}}|{{.Status}}|{{.State}}"

# Stop container
docker stop <container_name>

# Start container
docker start <container_name>

# Check container status
docker inspect --format='{{.State.Status}}' <container_name>

# Get container GPU usage
docker inspect --format='{{range .HostConfig.DeviceRequests}}{{.DeviceIDs}}{{end}}' <container_name>
```

### VM Service Management

```bash
# List all VMs
virsh list --all

# Get VM GPU configuration
virsh dumpxml <vm_name> | grep -A 5 "hostdev"

# Stop VM
virsh shutdown <vm_name>
# Force stop if needed
virsh destroy <vm_name>

# Start VM
virsh start <vm_name>

# Check VM status
virsh domstate <vm_name>
```

### Service Dependency Detection

```bash
# Check container GPU usage
docker inspect <container_name> | grep -i "nvidia\|gpu\|device"

# Check VM GPU configuration
virsh dumpxml <vm_name> | grep -A 10 "hostdev" | grep "pci"

# Cross-reference with GPU PCI addresses
lspci -nn -s <pci_address>
```

### State Management

```bash
# Save state to JSON
cat > /tmp/service_state_<timestamp>.json <<EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "gpu_address": "<pci_address>",
    "containers": [
        {"name": "container1", "state": "running"},
        {"name": "container2", "state": "stopped"}
    ],
    "vms": [
        {"name": "vm1", "state": "running"}
    ]
}
EOF

# Restore state from JSON
jq -r '.containers[] | select(.state=="running") | .name' state.json | xargs -I {} docker start {}
```

## Data Structures

### Container Management Result JSON

```json
{
    "success": true,
    "operation": "stop",
    "containers": [
        {
            "name": "plex",
            "previous_state": "running",
            "current_state": "stopped",
            "operation_success": true
        },
        {
            "name": "jellyfin",
            "previous_state": "running",
            "current_state": "stopped",
            "operation_success": true
        }
    ],
    "total_containers": 2,
    "successful_operations": 2,
    "failed_operations": 0,
    "timestamp": "2026-05-03T16:00:00Z"
}
```

### VM Management Result JSON

```json
{
    "success": true,
    "operation": "start",
    "vms": [
        {
            "name": "windows-gaming",
            "previous_state": "shut off",
            "current_state": "running",
            "operation_success": true,
            "gpu_address": "0000:01:00.0"
        }
    ],
    "total_vms": 1,
    "successful_operations": 1,
    "failed_operations": 0,
    "timestamp": "2026-05-03T16:05:00Z"
}
```

### Service Dependencies JSON

```json
{
    "success": true,
    "gpu_address": "0000:01:00.0",
    "safe_to_switch": false,
    "blocking_services": [
        {
            "type": "container",
            "name": "plex",
            "state": "running",
            "reason": "Container is actively using GPU"
        }
    ],
    "dependent_services": [
        {
            "type": "container",
            "name": "plex",
            "state": "running"
        },
        {
            "type": "vm",
            "name": "windows-gaming",
            "state": "shut off"
        }
    ],
    "recommendations": [
        "Stop plex container before switching GPU",
        "VM is not running, no action needed"
    ]
}
```

### Service Status JSON

```json
{
    "success": true,
    "docker": {
        "total_containers": 5,
        "running_containers": 3,
        "stopped_containers": 2,
        "gpu_dependent": [
            {
                "name": "plex",
                "state": "running",
                "gpu_address": "0000:01:00.0"
            }
        ]
    },
    "vms": {
        "total_vms": 2,
        "running_vms": 1,
        "stopped_vms": 1,
        "gpu_dependent": [
            {
                "name": "windows-gaming",
                "state": "running",
                "gpu_address": "0000:01:00.0"
            }
        ]
    },
    "timestamp": "2026-05-03T16:10:00Z"
}
```

## Security Considerations

### Input Validation
- Validate all container names
- Validate all VM names
- Check for command injection
- Sanitize all user inputs

### Permission Management
- Check for Docker daemon access
- Check for libvirt access
- Validate user permissions
- Handle permission errors gracefully

### Safety Checks
- Verify service states before operations
- Check for active connections
- Validate operation safety
- Prevent destructive operations

### Error Handling
- Comprehensive error checking
- Graceful failure modes
- Rollback capabilities
- Detailed error logging

## Dependencies

### Required Tools
- docker (Docker container management)
- virsh (libvirt VM management)
- jq (JSON processing)
- grep (text processing)
- awk (text processing)

### System Requirements
- Docker daemon running
- libvirt service running
- Root privileges for service operations
- Network access for Docker operations

### Optional Tools
- docker-compose (multi-container management)
- systemctl (service management)

## Success Criteria

- [ ] manage_docker_containers.sh manages containers correctly
- [ ] manage_vm_services.sh manages VMs correctly
- [ ] check_service_dependencies.sh identifies dependencies accurately
- [ ] save_service_states.sh saves states correctly
- [ ] restore_service_states.sh restores states correctly
- [ ] get_service_status.sh reports accurate status
- [ ] validate_service_operation.sh validates operations correctly
- [ ] All scripts handle errors gracefully
- [ ] All outputs are valid JSON
- [ ] GPUManager.php provides complete service API
- [ ] Safety checks prevent unsafe operations
- [ ] Logging captures all operations
- [ ] Integration with Phase 2 works correctly

## Risk Assessment

### Low Risk
- Service status checking
- Dependency detection
- State file management

### Medium Risk
- Container stop/start operations
- VM stop/start operations
- State restoration

### High Risk
- Stopping services in use
- Losing service states
- VM data corruption during operations

### Mitigation Strategies
- Comprehensive state checking
- Multiple verification steps
- Rollback capabilities
- Detailed logging
- Conservative safety checks
- User confirmation for destructive operations

## Next Phase Dependencies

Phase 3 completion enables:
- Phase 4: Event handlers can automate service coordination
- Phase 5: Configuration can store service preferences
- Phase 6: Web GUI can control services
- Phase 7: Dashboard can show service status
- Phase 8: Testing can validate service workflows

## Estimated Time

- manage_docker_containers.sh: 60 minutes
- manage_vm_services.sh: 60 minutes
- check_service_dependencies.sh: 45 minutes
- save_service_states.sh: 30 minutes
- restore_service_states.sh: 30 minutes
- get_service_status.sh: 30 minutes
- validate_service_operation.sh: 30 minutes
- GPUManager.php updates: 45 minutes
- Testing: 90 minutes

**Total: ~6 hours**

## Notes

- Docker operations require Docker daemon to be running
- VM operations require libvirt service to be running
- Service states must be saved before GPU switching
- State restoration must be verified
- Container dependencies must be respected
- VM states must be checked before operations
- Error messages must be user-friendly
- All operations must be logged for debugging
- Testing should cover various service configurations
- Integration with Phase 2 VFIO binding is critical
- Service coordination timing is important for user experience