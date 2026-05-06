# Phase 4 Implementation Plan: Event Handlers

## Date: 2026-05-03
## Status: Planning

## Overview

Phase 4 implements event handlers that automatically coordinate GPU switching operations based on system events. This phase enables the plugin to respond to VM start/stop events, Docker container lifecycle events, and other system triggers, providing automated GPU management without manual intervention.

## Objectives

1. Create VM event handlers for automatic GPU switching
2. Implement Docker event hooks for container lifecycle management
3. Build automatic GPU switching based on events
4. Create service coordination during events
5. Integrate with Unraid event system
6. Provide event logging and monitoring

## Technical Requirements

### VM Event Handlers

**VM Start Event Handler:**
- Detect VM start events via libvirt hooks
- Identify GPU requirements from VM configuration
- Automatically bind GPU to VFIO before VM starts
- Stop GPU-dependent Docker containers if needed
- Restore GPU binding after VM stops
- Handle VM start failures gracefully

**VM Stop Event Handler:**
- Detect VM stop events via libvirt hooks
- Identify which GPU was used by the VM
- Unbind GPU from VFIO after VM stops
- Restore GPU-dependent Docker containers
- Clean up temporary configurations
- Handle VM stop failures gracefully

**VM Lifecycle Hooks:**
- `/etc/libvirt/hooks/qemu` - Pre-start hook
- `/etc/libvirt/hooks/qemu.d/` - Post-start hook
- `/etc/libvirt/hooks/qemu` - Pre-stop hook
- `/etc/libvirt/hooks/qemu.d/` - Post-stop hook

### Docker Event Hooks

**Docker Container Start Event:**
- Detect container start events via Docker API
- Check if container requires GPU access
- Ensure GPU is bound to appropriate driver
- Handle GPU conflicts with running VMs
- Log container start events

**Docker Container Stop Event:**
- Detect container stop events via Docker API
- Release GPU resources if no longer needed
- Update GPU usage tracking
- Log container stop events

**Docker Event Monitoring:**
- Docker event stream monitoring
- Event filtering for GPU-relevant events
- Event queue processing
- Event deduplication

### Automatic GPU Switching

**Event-Based Switching Logic:**
- Determine GPU switching requirements from events
- Check current GPU binding state
- Validate switching safety
- Execute switching operations
- Verify switching success

**Switching Triggers:**
- VM start with GPU passthrough
- VM stop with GPU passthrough
- Docker container start with GPU access
- Docker container stop with GPU access
- Manual switching requests
- Scheduled switching operations

**Switching Safety Checks:**
- Check for active GPU usage
- Verify service dependencies
- Validate resource availability
- Check for conflicts
- Verify system stability

### Service Coordination

**Pre-Event Coordination:**
- Identify affected services
- Stop conflicting services
- Save service states
- Prepare for GPU switching

**Post-Event Coordination:**
- Restore service states
- Restart affected services
- Verify service health
- Update GPU usage tracking

**Coordination Strategies:**
- Graceful service shutdown
- State preservation
- Ordered service operations
- Conflict resolution
- Rollback capabilities

### Unraid Event Integration

**Unraid Event Hooks:**
- `/usr/local/emhttp/webGui/event_handlers/` - Event handler directory
- Array start/stop events
- Docker service start/stop events
- VM service start/stop events
- Custom plugin events

**Event Handler Registration:**
- Register event handlers with Unraid
- Configure event priorities
- Set up event filtering
- Enable/disable handlers

**Event Logging:**
- Log all events to plugin log
- Include event details and context
- Track event processing results
- Monitor event handler performance

## Implementation Plan

### Step 1: VM Event Handlers

**Files to Create:**
1. `scripts/vm_start_handler.sh` - VM start event handler
2. `scripts/vm_stop_handler.sh` - VM stop event handler
3. `scripts/vm_lifecycle_hooks.sh` - VM lifecycle hook installer
4. `scripts/check_vm_gpu_requirements.sh` - Check VM GPU requirements

**Functionality:**
- VM start handler:
  - Parse VM configuration for GPU requirements
  - Check current GPU binding state
  - Bind GPU to VFIO if needed
  - Stop conflicting Docker containers
  - Save service states
  - Handle errors gracefully

- VM stop handler:
  - Identify GPU used by VM
  - Unbind GPU from VFIO
  - Restore Docker containers
  - Restore service states
  - Clean up temporary files
  - Handle errors gracefully

- VM lifecycle hooks installer:
  - Install libvirt hooks
  - Configure hook permissions
  - Set up hook logging
  - Test hook functionality

- VM GPU requirements checker:
  - Parse VM XML configuration
  - Extract GPU device information
  - Identify audio function requirements
  - Determine VFIO binding needs
  - Return requirements in JSON format

### Step 2: Docker Event Hooks

**Files to Create:**
1. `scripts/docker_event_monitor.sh` - Docker event monitoring daemon
2. `scripts/docker_start_handler.sh` - Docker container start handler
3. `scripts/docker_stop_handler.sh` - Docker container stop handler
4. `scripts/check_container_gpu_requirements.sh` - Check container GPU requirements

**Functionality:**
- Docker event monitor:
  - Monitor Docker event stream
  - Filter GPU-relevant events
  - Queue events for processing
  - Process events asynchronously
  - Handle event failures

- Docker start handler:
  - Check container GPU requirements
  - Verify GPU binding state
  - Bind GPU to appropriate driver if needed
  - Check for VM conflicts
  - Log container start

- Docker stop handler:
  - Release GPU resources
  - Update GPU usage tracking
  - Check if GPU can be switched
  - Log container stop

- Container GPU requirements checker:
  - Inspect container configuration
  - Identify GPU device requests
  - Determine driver requirements
  - Return requirements in JSON format

### Step 3: Automatic GPU Switching

**Files to Create:**
1. `scripts/auto_gpu_switch.sh` - Automatic GPU switching logic
2. `scripts/determine_switching_action.sh` - Determine switching action from events
3. `scripts/validate_switching_safety.sh` - Validate switching safety
4. `scripts/execute_gpu_switch.sh` - Execute GPU switching operation

**Functionality:**
- Auto GPU switch:
  - Parse event information
  - Determine switching requirements
  - Validate switching safety
  - Execute switching operations
  - Verify switching success
  - Handle failures gracefully

- Determine switching action:
  - Analyze event type and context
  - Check current GPU state
  - Identify required action
  - Return action plan

- Validate switching safety:
  - Check for active GPU usage
  - Verify service dependencies
  - Validate resource availability
  - Check for conflicts
  - Return safety assessment

- Execute GPU switch:
  - Execute VFIO binding/unbinding
  - Coordinate service operations
  - Update GPU state tracking
  - Verify operation success
  - Handle errors with rollback

### Step 4: Service Coordination

**Files to Create:**
1. `scripts/coordinate_services_for_event.sh` - Coordinate services for events
2. `scripts/prepare_for_gpu_switch.sh` - Prepare system for GPU switching
3. `scripts/cleanup_after_gpu_switch.sh` - Cleanup after GPU switching
4. `scripts/rollback_gpu_switch.sh` - Rollback failed GPU switching

**Functionality:**
- Coordinate services for event:
  - Identify affected services
  - Determine service operation order
  - Execute service operations
  - Verify service states
  - Handle coordination failures

- Prepare for GPU switch:
  - Stop conflicting services
  - Save service states
  - Create temporary configurations
  - Verify system readiness

- Cleanup after GPU switch:
  - Restore service states
  - Restart affected services
  - Clean up temporary files
  - Update GPU usage tracking

- Rollback GPU switch:
  - Restore previous GPU binding
  - Restore service states
  - Clean up temporary files
  - Log rollback details

### Step 5: Unraid Event Integration

**Files to Create:**
1. `scripts/unraid_event_handler.sh` - Unraid event handler
2. `scripts/register_event_handlers.sh` - Register event handlers
3. `scripts/unregister_event_handlers.sh` - Unregister event handlers
4. `scripts/event_logger.sh` - Event logging utility

**Functionality:**
- Unraid event handler:
  - Handle Unraid events
  - Parse event information
  - Determine appropriate action
  - Execute event-specific logic
  - Log event processing

- Register event handlers:
  - Install event handler scripts
  - Configure event priorities
  - Set up event filtering
  - Test handler registration

- Unregister event handlers:
  - Remove event handler scripts
  - Clean up configurations
  - Verify removal

- Event logger:
  - Log events to plugin log
  - Include event details
  - Track processing results
  - Monitor handler performance

### Step 6: GPUManager.php Updates

**Methods to Add:**
1. `handleVMStartEvent($vmName)` - Handle VM start event
2. `handleVMStopEvent($vmName)` - Handle VM stop event
3. `handleDockerStartEvent($containerName)` - Handle Docker start event
4. `handleDockerStopEvent($containerName)` - Handle Docker stop event
5. `determineSwitchingAction($eventType, $eventData)` - Determine switching action
6. `validateSwitchingSafety($action, $gpuAddress)` - Validate switching safety
7. `executeAutoSwitch($action, $gpuAddress)` - Execute automatic switching
8. `coordinateServicesForEvent($eventType, $eventData)` - Coordinate services
9. `getEventHistory($limit = 100)` - Get event history
10. `getActiveSwitchingOperations()` - Get active switching operations
11. `cancelSwitchingOperation($operationId)` - Cancel switching operation
12. `getEventHandlerStatus()` - Get event handler status

**Functionality:**
- Event handling methods:
  - Parse event data
  - Determine appropriate action
  - Execute switching operations
  - Coordinate services
  - Handle errors gracefully

- Switching validation:
  - Check safety conditions
  - Validate resource availability
  - Verify system stability
  - Return validation results

- Automatic switching:
  - Execute switching operations
  - Coordinate service operations
  - Verify success
  - Handle failures with rollback

- Event monitoring:
  - Track event history
  - Monitor active operations
  - Provide status information
  - Support operation cancellation

## File Structure

```
unRAID-GPU-Auto-Bind/
├── scripts/
│   ├── vm_start_handler.sh
│   ├── vm_stop_handler.sh
│   ├── vm_lifecycle_hooks.sh
│   ├── check_vm_gpu_requirements.sh
│   ├── docker_event_monitor.sh
│   ├── docker_start_handler.sh
│   ├── docker_stop_handler.sh
│   ├── check_container_gpu_requirements.sh
│   ├── auto_gpu_switch.sh
│   ├── determine_switching_action.sh
│   ├── validate_switching_safety.sh
│   ├── execute_gpu_switch.sh
│   ├── coordinate_services_for_event.sh
│   ├── prepare_for_gpu_switch.sh
│   ├── cleanup_after_gpu_switch.sh
│   ├── rollback_gpu_switch.sh
│   ├── unraid_event_handler.sh
│   ├── register_event_handlers.sh
│   ├── unregister_event_handlers.sh
│   └── event_logger.sh
├── include/
│   └── GPUManager.php (updated)
├── validate_phase4.sh
└── PHASE-4-COMPLETE.md
```

## Dependencies

### Phase 3 Dependencies
- Service management scripts from Phase 3
- GPUManager.php service management methods
- State management functionality
- Service validation capabilities

### External Dependencies
- libvirt for VM event hooks
- Docker API for container events
- Unraid event system
- System logging facilities

## Testing Strategy

### Unit Tests
- Test each event handler script independently
- Test event parsing logic
- Test switching action determination
- Test safety validation
- Test service coordination

### Integration Tests
- Test VM event handler integration
- Test Docker event handler integration
- Test automatic switching workflows
- Test service coordination
- Test error handling and rollback

### System Tests
- Test complete VM start/stop workflows
- Test complete Docker container start/stop workflows
- Test concurrent event handling
- Test failure scenarios
- Test rollback functionality

## Validation Criteria

### Script Validation
- All scripts exist and are executable
- All scripts have proper shebang
- All scripts include error handling
- All scripts include logging
- All scripts include input validation

### Functionality Validation
- VM event handlers work correctly
- Docker event handlers work correctly
- Automatic switching works correctly
- Service coordination works correctly
- Event integration works correctly

### Integration Validation
- Event handlers integrate with Phase 3
- GPUManager.php methods work correctly
- Error handling is comprehensive
- Logging is complete
- Rollback functionality works

## Security Considerations

### Input Validation
- Validate all event data
- Validate VM names and configurations
- Validate container names and configurations
- Validate GPU addresses
- Validate switching actions

### Permission Management
- Check libvirt hook permissions
- Check Docker API permissions
- Check Unraid event handler permissions
- Validate file system access
- Validate operation permissions

### Safety Checks
- Verify switching safety before operations
- Check for active GPU usage
- Verify service dependencies
- Check for conflicts
- Validate system stability

### Error Handling
- Comprehensive error checking
- Graceful failure modes
- Rollback capabilities
- Detailed logging
- User notification

## Performance Considerations

### Event Processing
- Asynchronous event processing
- Event queue management
- Event deduplication
- Efficient event filtering
- Minimal event processing latency

### Resource Usage
- Minimal CPU usage during monitoring
- Minimal memory usage for event queues
- Efficient disk I/O for logging
- Optimized network usage for Docker API

### Caching
- Cache VM configurations
- Cache container configurations
- Cache GPU state information
- Cache service dependency information
- Cache validation results

## Documentation Requirements

### Code Documentation
- Comprehensive function comments
- Usage examples in script headers
- Error message clarity
- Logging for debugging

### User Documentation
- Event handler configuration guide
- Automatic switching setup guide
- Troubleshooting guide
- Event monitoring guide

### API Documentation
- GPUManager.php method documentation
- Event handler API documentation
- Service coordination API documentation
- Event logging API documentation

## Known Limitations

### Environment Requirements
- Requires libvirt for VM event hooks
- Requires Docker API for container events
- Requires Unraid event system integration
- Root privileges for event handlers
- Network access for Docker API

### Platform Dependencies
- Linux-specific implementation
- Unraid-specific paths
- Bash shell requirement
- jq for JSON processing
- libvirt and Docker dependencies

### Event Limitations
- Event delivery is not guaranteed
- Event ordering may vary
- Event processing may be delayed
- Event failures may occur
- Event deduplication is best-effort

## Success Criteria

### Functional Requirements
- VM event handlers work correctly
- Docker event handlers work correctly
- Automatic switching works correctly
- Service coordination works correctly
- Event integration works correctly

### Non-Functional Requirements
- Event processing is efficient
- Resource usage is minimal
- Error handling is comprehensive
- Logging is complete
- Rollback functionality works

### Quality Requirements
- All validation tests pass
- Code is well-documented
- Error messages are clear
- Performance is acceptable
- Security is maintained

## Next Steps

After Phase 4 completion:
1. Begin Phase 5: Configuration Management
2. Implement profile management
3. Add configuration persistence
4. Create user preferences
5. Add configuration validation

## Conclusion

Phase 4: Event Handlers provides comprehensive event-based automation for GPU switching operations. The implementation includes VM event handlers, Docker event hooks, automatic GPU switching, service coordination, and Unraid event integration.

The event handlers enable the plugin to automatically respond to system events and coordinate GPU switching without manual intervention, providing a seamless user experience while maintaining safety and reliability.