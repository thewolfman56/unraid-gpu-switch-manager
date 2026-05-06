# Phase 1: Device Discovery & State Management Implementation Plan

## Overview
Phase 1 implements the core GPU discovery and state management functionality. This includes detecting available GPUs, identifying their current driver attachment, and managing the state of GPU devices throughout the switching process.

## Files to Create

### 1. scripts/list_gpus.sh
**Purpose:** Enumerate all available GPUs on the system
**Location:** `/usr/local/emhttp/plugins/gpu.switch.manager/scripts/`
**Output:** JSON-formatted list of GPUs with detailed information

**Responsibilities:**
- Scan PCI bus for GPU devices
- Identify GPU vendor (NVIDIA, AMD, Intel)
- Get GPU model and capabilities
- Detect current driver attachment
- Identify audio function devices
- Output structured JSON data

**GPU Information Collected:**
- PCI address (domain:bus:device.function)
- Vendor ID and Device ID
- Subsystem vendor and device IDs
- GPU model name
- Driver currently attached (nvidia, amdgpu, i915, vfio-pci, none)
- Audio function PCI address (if present)
- Is primary GPU (boot display)
- Is available for switching

### 2. scripts/get_gpu_state.sh
**Purpose:** Get current state of a specific GPU
**Location:** `/usr/local/emhttp/plugins/gpu.switch.manager/scripts/`
**Input:** GPU PCI address
**Output:** JSON-formatted state information

**Responsibilities:**
- Check current driver attachment
- Verify GPU is bound to vfio-pci
- Check if GPU is in use
- Identify running processes using GPU
- Check for open file handles
- Validate GPU accessibility

**State Information:**
- Current driver binding
- VFIO binding status
- In-use status
- Running processes (PIDs, command names)
- Open file handles
- Accessibility status
- Last operation timestamp

### 3. scripts/detect_primary_gpu.sh
**Purpose:** Identify the primary/boot GPU
**Location:** `/usr/local/emhttp/plugins/gpu.switch.manager/scripts/`
**Output:** PCI address of primary GPU or empty string if none

**Responsibilities:**
- Identify GPU used for boot display
- Check for connected monitors
- Verify X11/Wayland display server usage
- Determine if safe to switch this GPU
- Provide recommendations for GPU switching

**Safety Checks:**
- Number of GPUs detected
- Primary GPU identification
- Secondary GPU availability
- Display server attachment
- Console usage

### 4. include/GPUManager.php
**Purpose:** PHP class for GPU state management
**Location:** `/usr/local/emhttp/plugins/gpu.switch.manager/include/`
**Methods:** GPU discovery, state tracking, validation

**Key Methods:**
- `listGPUs()` - Get all available GPUs
- `getGPUState($pciAddress)` - Get state of specific GPU
- `isPrimaryGPU($pciAddress)` - Check if GPU is primary
- `canSwitchGPU($pciAddress)` - Validate GPU can be switched
- `getGPUInfo($pciAddress)` - Get detailed GPU information
- `validateGPUAddress($pciAddress)` - Validate PCI address format
- `getAudioFunction($pciAddress)` - Get audio function for GPU

**State Management:**
- Cache GPU information
- Track state changes
- Validate operations
- Provide error handling
- Log state transitions

### 5. scripts/validate_gpu_address.sh
**Purpose:** Validate GPU PCI address format
**Location:** `/usr/local/emhttp/plugins/gpu.switch.manager/scripts/`
**Input:** PCI address string
**Output:** Validation result (valid/invalid)

**Validation Rules:**
- Format: domain:bus:device.function (e.g., 0000:01:00.0)
- Hexadecimal format validation
- Range checking (domain: 0000-ffff, bus: 00-ff, device: 00-1f, function: 0-7)
- Device existence verification
- GPU device type verification

## Implementation Steps

### Step 1: Create list_gpus.sh
1. Implement PCI device scanning using lspci
2. Add vendor identification (NVIDIA, AMD, Intel)
3. Extract GPU model information
4. Detect current driver attachment
5. Identify audio function devices
6. Determine primary GPU status
7. Format output as JSON
8. Add error handling and validation

### Step 2: Create get_gpu_state.sh
1. Parse GPU PCI address input
2. Check current driver binding
3. Verify VFIO attachment
4. Check for GPU usage
5. Identify running processes
6. Check file handles
7. Format state as JSON
8. Add comprehensive error handling

### Step 3: Create detect_primary_gpu.sh
1. Scan for all GPUs
2. Identify boot display GPU
3. Check for monitor connections
4. Verify display server usage
5. Assess switching safety
6. Provide recommendations
7. Output results

### Step 4: Create GPUManager.php
1. Define class structure
2. Implement GPU discovery method
3. Add state tracking methods
4. Implement validation methods
5. Add caching mechanism
6. Create error handling
7. Add logging integration

### Step 5: Create validate_gpu_address.sh
1. Implement PCI address format validation
2. Add hexadecimal format checking
3. Verify device existence
4. Check GPU device type
5. Provide detailed error messages
6. Return validation results

### Step 6: Testing
1. Test GPU discovery on single GPU system
2. Test GPU discovery on multi-GPU system
3. Test state detection for various GPU states
4. Test primary GPU detection
5. Test PCI address validation
6. Test error handling
7. Test JSON output formatting

## Technical Implementation Details

### GPU Discovery Process

```bash
# Scan for GPU devices
lspci -nn | grep -E "VGA|3D|Display"

# Get detailed GPU information
lspci -nn -s <pci_address> -v

# Check current driver
readlink /sys/bus/pci/devices/<pci_address>/driver

# Get NVIDIA GPU info
nvidia-smi --query-gpu=index,name,uuid,driver_version --format=csv

# Get AMD GPU info
lspci -nn -d 1002:: | grep -E "VGA|3D"

# Get Intel GPU info
lspci -nn -d 8086:: | grep -E "VGA"
```

### State Detection Process

```bash
# Check driver binding
driver_path=$(readlink /sys/bus/pci/devices/<pci_address>/driver)
driver_name=$(basename "$driver_path")

# Check VFIO binding
if [[ "$driver_name" == "vfio-pci" ]]; then
    # GPU is bound to VFIO
fi

# Check for GPU usage
nvidia-smi --query-compute-apps=pid,process_name --format=csv,noheader

# Check file handles
lsof /dev/nvidia* 2>/dev/null

# Check for X11/Wayland
ps aux | grep -E "Xorg|weston|gnome-shell"
```

### Primary GPU Detection

```bash
# Get boot GPU
boot_gpu=$(cat /proc/cmdline | grep -oP 'video=\K[^ ]+' || echo "")

# Check for connected monitors
xrandr --query 2>/dev/null || echo "No display server"

# Check display server
ps aux | grep -E "Xorg|weston|gnome-shell|kwin"

# Count GPUs
gpu_count=$(lspci -nn | grep -E "VGA|3D|Display" | wc -l)
```

## Data Structures

### GPU Information JSON

```json
{
    "pci_address": "0000:01:00.0",
    "vendor_id": "10de",
    "device_id": "2204",
    "subsystem_vendor_id": "10de",
    "subsystem_device_id": "1404",
    "vendor": "NVIDIA",
    "model": "NVIDIA GeForce RTX 3060",
    "driver": "nvidia",
    "audio_function": "0000:01:00.1",
    "is_primary": true,
    "is_available": true,
    "can_switch": false,
    "reason": "Primary GPU - no secondary GPU available"
}
```

### GPU State JSON

```json
{
    "pci_address": "0000:01:00.0",
    "current_driver": "nvidia",
    "vfio_bound": false,
    "in_use": true,
    "processes": [
        {
            "pid": 1234,
            "command": "Xorg",
            "user": "root"
        }
    ],
    "file_handles": [
        "/dev/nvidia0",
        "/dev/nvidiactl"
    ],
    "accessible": true,
    "last_operation": "none",
    "last_operation_time": null
}
```

## Security Considerations

### Input Validation
- Validate all PCI address formats
- Sanitize all user inputs
- Check for directory traversal attacks
- Validate command arguments

### Permission Management
- Check for required permissions
- Validate file system access
- Ensure proper user context
- Handle permission errors gracefully

### Error Handling
- Comprehensive error checking
- Graceful failure modes
- Informative error messages
- Safe default behaviors

## Dependencies

### Required Tools
- lspci (PCI device enumeration)
- grep (text processing)
- sed (text manipulation)
- awk (text processing)
- readlink (symbolic link resolution)

### Optional Tools
- nvidia-smi (NVIDIA GPU management)
- lsof (file handle monitoring)
- xrandr (display information)
- jq (JSON processing)

## Success Criteria

- [ ] list_gpus.sh discovers all GPUs correctly
- [ ] list_gpus.sh identifies GPU vendors accurately
- [ ] list_gpus.sh detects current driver attachment
- [ ] list_gpus.sh outputs valid JSON
- [ ] get_gpu_state.sh reports accurate GPU state
- [ ] get_gpu_state.sh detects GPU usage correctly
- [ ] get_gpu_state.sh identifies running processes
- [ ] detect_primary_gpu.sh identifies primary GPU
- [ ] detect_primary_gpu.sh provides safety recommendations
- [ ] GPUManager.php provides complete API
- [ ] GPUManager.php handles errors gracefully
- [ ] validate_gpu_address.sh validates addresses correctly
- [ ] All scripts have proper error handling
- [ ] All outputs are valid JSON
- [ ] Security validation is comprehensive

## Risk Assessment

### Low Risk
- GPU device enumeration
- PCI address validation
- Driver detection
- JSON formatting

### Medium Risk
- Primary GPU detection
- Usage detection
- File handle monitoring
- Process identification

### High Risk
- Incorrect primary GPU identification
- Missing GPU detection
- Inaccurate state reporting
- Security vulnerabilities in input handling

### Mitigation Strategies
- Comprehensive testing on various hardware
- Multiple detection methods for redundancy
- Extensive input validation
- Conservative safety checks
- Detailed error logging

## Next Phase Dependencies

Phase 1 completion enables:
- Phase 2: VFIO binding scripts can target specific GPUs
- Phase 3: Service management knows which GPUs to manage
- Phase 4: Event handlers can query GPU state
- Phase 5: Configuration can reference specific GPUs
- Phase 6: Web GUI can display GPU information
- Phase 7: Dashboard can show real-time GPU stats

## Estimated Time

- list_gpus.sh: 45 minutes
- get_gpu_state.sh: 30 minutes
- detect_primary_gpu.sh: 30 minutes
- GPUManager.php: 45 minutes
- validate_gpu_address.sh: 15 minutes
- Testing: 45 minutes

**Total: ~3-3.5 hours**

## Notes

- GPU discovery must work with NVIDIA, AMD, and Intel GPUs
- State detection must be accurate for safety
- Primary GPU detection is critical for system stability
- JSON output format must be consistent
- Error messages must be user-friendly
- All scripts must handle edge cases gracefully
- Testing should cover various hardware configurations