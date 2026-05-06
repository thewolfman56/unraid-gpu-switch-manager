# Phase 2: VFIO Binding Core Implementation Plan

## Overview
Phase 2 implements the core VFIO binding functionality that enables GPU passthrough to VMs. This includes binding/unbinding GPUs to the vfio-pci driver, managing driver overrides, and handling GPU audio functions.

## Files to Create

### 1. scripts/bind_gpu_to_vfio.sh
**Purpose:** Bind a GPU to the vfio-pci driver for VM passthrough
**Location:** `/usr/local/emhttp/plugins/gpu.switch.manager/scripts/`
**Input:** GPU PCI address
**Output:** JSON-formatted binding result

**Responsibilities:**
- Validate GPU is not in use
- Unbind current driver if present
- Bind GPU to vfio-pci driver
- Handle audio function binding
- Verify binding success
- Update driver configuration
- Handle errors gracefully

**Binding Process:**
1. Check GPU current state
2. Verify GPU is not in use
3. Unbind from current driver
4. Bind to vfio-pci driver
5. Update vfio.conf if needed
6. Verify binding success
7. Log operation

### 2. scripts/unbind_gpu_from_vfio.sh
**Purpose:** Unbind a GPU from vfio-pci and restore normal driver
**Location:** `/usr/local/emhttp/plugins/gpu.switch.manager/scripts/`
**Input:** GPU PCI address
**Output:** JSON-formatted unbinding result

**Responsibilities:**
- Verify GPU is bound to vfio-pci
- Unbind from vfio-pci driver
- Restore original driver binding
- Handle audio function unbinding
- Verify unbinding success
- Update driver configuration
- Handle errors gracefully

**Unbinding Process:**
1. Check GPU current state
2. Verify vfio-pci binding
3. Unbind from vfio-pci
4. Bind to appropriate driver (nvidia, amdgpu, i915)
5. Update vfio.conf if needed
6. Verify unbinding success
7. Log operation

### 3. scripts/check_vfio_binding.sh
**Purpose:** Check if a GPU is currently bound to vfio-pci
**Location:** `/usr/local/emhttp/plugins/gpu.switch.manager/scripts/`
**Input:** GPU PCI address
**Output:** JSON-formatted binding status

**Responsibilities:**
- Check current driver binding
- Verify vfio-pci attachment
- Check device accessibility
- Identify bound functions
- Report binding status

**Binding Status Information:**
- Current driver name
- VFIO binding status
- Device accessibility
- Bound functions (GPU, audio)
- Binding timestamp

### 4. scripts/update_vfio_conf.sh
**Purpose:** Update /etc/modprobe.d/vfio.conf with GPU IDs
**Location:** `/usr/local/emhttp/plugins/gpu.switch.manager/scripts/`
**Input:** List of GPU PCI addresses to bind
**Output:** JSON-formatted update result

**Responsibilities:**
- Parse GPU PCI addresses
- Extract vendor and device IDs
- Update vfio.conf file
- Backup original configuration
- Validate configuration syntax
- Handle conflicts gracefully

**Configuration Format:**
```bash
options vfio-pci ids=10de:2204,10de:2205,1002:1234
```

### 5. scripts/get_gpu_driver_info.sh
**Purpose:** Get information about available drivers for a GPU
**Location:** `/usr/local/emhttp/plugins/gpu.switch.manager/scripts/`
**Input:** GPU PCI address
**Output:** JSON-formatted driver information

**Responsibilities:**
- Identify GPU vendor and device
- Determine appropriate driver
- Check driver availability
- List alternative drivers
- Report driver compatibility

**Driver Information:**
- Vendor ID and Device ID
- Recommended driver
- Available drivers
- Driver compatibility status
- Current driver binding

### 6. scripts/verify_vfio_binding.sh
**Purpose:** Verify that VFIO binding is working correctly
**Location:** `/usr/local/emhttp/plugins/gpu.switch.manager/scripts/`
**Input:** GPU PCI address
**Output:** JSON-formatted verification result

**Responsibilities:**
- Check vfio-pci module loaded
- Verify device in vfio-pci group
- Test device accessibility
- Check IOMMU groups
- Verify passthrough readiness

**Verification Checks:**
- VFIO module status
- Device group membership
- IOMMU group configuration
- Device accessibility
- Passthrough readiness

## Implementation Steps

### Step 1: Create bind_gpu_to_vfio.sh
1. Implement GPU state validation
2. Add usage checking
3. Implement driver unbinding
4. Add vfio-pci binding
5. Handle audio function
6. Add verification
7. Implement error handling
8. Add logging

### Step 2: Create unbind_gpu_from_vfio.sh
1. Implement vfio-pci detection
2. Add driver identification
3. Implement vfio-pci unbinding
4. Add driver restoration
5. Handle audio function
6. Add verification
7. Implement error handling
8. Add logging

### Step 3: Create check_vfio_binding.sh
1. Implement driver binding check
2. Add vfio-pci detection
3. Check device accessibility
4. Identify bound functions
5. Format status output
6. Add error handling

### Step 4: Create update_vfio_conf.sh
1. Parse PCI addresses
2. Extract vendor/device IDs
3. Read existing configuration
4. Update vfio.conf
5. Backup original file
6. Validate syntax
7. Handle errors

### Step 5: Create get_gpu_driver_info.sh
1. Parse GPU PCI address
2. Extract vendor/device IDs
3. Identify recommended driver
4. Check driver availability
5. List alternatives
6. Format output
7. Add error handling

### Step 6: Create verify_vfio_binding.sh
1. Check vfio-pci module
2. Verify device groups
3. Test accessibility
4. Check IOMMU configuration
5. Verify passthrough readiness
6. Format results
7. Add error handling

### Step 7: Update GPUManager.php
1. Add bindGPUToVFIO method
2. Add unbindGPUFromVFIO method
3. Add checkVFIOBinding method
4. Add updateVFIOConfig method
5. Add getGPUDriverInfo method
6. Add verifyVFIOBinding method
7. Update caching logic
8. Add error handling

### Step 8: Testing
1. Test binding on NVIDIA GPU
2. Test binding on AMD GPU
3. Test binding on Intel GPU
4. Test unbinding operations
5. Test audio function handling
6. Test vfio.conf updates
7. Test error scenarios
8. Test verification logic

## Technical Implementation Details

### VFIO Binding Process

```bash
# Get current driver
current_driver=$(readlink /sys/bus/pci/devices/<pci_address>/driver)
driver_name=$(basename "$current_driver")

# Unbind from current driver
echo "<pci_address>" > /sys/bus/pci/devices/<pci_address>/driver/unbind

# Bind to vfio-pci
echo "<vendor_id> <device_id>" > /sys/bus/pci/drivers/vfio-pci/new_id
echo "<pci_address>" > /sys/bus/pci/drivers/vfio-pci/bind

# Verify binding
new_driver=$(readlink /sys/bus/pci/devices/<pci_address>/driver)
```

### Driver Restoration Process

```bash
# Unbind from vfio-pci
echo "<pci_address>" > /sys/bus/pci/drivers/vfio-pci/unbind

# Remove from vfio-pci ID table
echo "<vendor_id> <device_id>" > /sys/bus/pci/drivers/vfio-pci/remove_id

# Bind to appropriate driver
echo "<pci_address>" > /sys/bus/pci/drivers/<driver_name>/bind

# Verify binding
new_driver=$(readlink /sys/bus/pci/devices/<pci_address>/driver)
```

### VFIO Configuration Update

```bash
# Extract vendor and device IDs
vendor_id=$(lspci -nn -s <pci_address> | grep -oP '\[([0-9a-f]{4}):([0-9a-f]{4})\]' | head -1 | sed 's/\[//;s/\]//;s/:/ /')

# Update vfio.conf
echo "options vfio-pci ids=$vendor_id,$device_id" > /etc/modprobe.d/vfio.conf

# Reload configuration
modprobe -r vfio-pci
modprobe vfio-pci
```

### Audio Function Handling

```bash
# Get audio function PCI address
audio_address=$(lspci -nn -s <gpu_address> | grep -A1 "VGA" | grep "Audio" | awk '{print $1}')

# Bind audio function to vfio-pci
echo "$audio_address" > /sys/bus/pci/devices/$audio_address/driver/unbind
echo "<audio_vendor_id> <audio_device_id>" > /sys/bus/pci/drivers/vfio-pci/new_id
echo "$audio_address" > /sys/bus/pci/drivers/vfio-pci/bind
```

## Data Structures

### Binding Result JSON

```json
{
    "pci_address": "0000:01:00.0",
    "success": true,
    "previous_driver": "nvidia",
    "current_driver": "vfio-pci",
    "audio_bound": true,
    "audio_address": "0000:01:00.1",
    "vfio_conf_updated": true,
    "timestamp": "2026-05-03T14:30:00Z",
    "message": "GPU successfully bound to vfio-pci"
}
```

### Unbinding Result JSON

```json
{
    "pci_address": "0000:01:00.0",
    "success": true,
    "previous_driver": "vfio-pci",
    "current_driver": "nvidia",
    "audio_unbound": true,
    "audio_address": "0000:01:00.1",
    "vfio_conf_updated": true,
    "timestamp": "2026-05-03T14:35:00Z",
    "message": "GPU successfully unbound from vfio-pci"
}
```

### Binding Status JSON

```json
{
    "pci_address": "0000:01:00.0",
    "current_driver": "vfio-pci",
    "vfio_bound": true,
    "accessible": true,
    "bound_functions": [
        {
            "type": "GPU",
            "address": "0000:01:00.0",
            "driver": "vfio-pci"
        },
        {
            "type": "Audio",
            "address": "0000:01:00.1",
            "driver": "vfio-pci"
        }
    ],
    "binding_timestamp": "2026-05-03T14:30:00Z"
}
```

### Driver Information JSON

```json
{
    "pci_address": "0000:01:00.0",
    "vendor_id": "10de",
    "device_id": "2204",
    "vendor": "NVIDIA",
    "recommended_driver": "nvidia",
    "available_drivers": [
        "nvidia",
        "vfio-pci",
        "nouveau"
    ],
    "current_driver": "nvidia",
    "compatibility": "full"
}
```

## Security Considerations

### Input Validation
- Validate all PCI address formats
- Check for device existence before operations
- Verify user permissions for driver operations
- Sanitize all file paths

### Permission Management
- Check for root privileges
- Validate write access to system directories
- Ensure proper file permissions
- Handle permission errors gracefully

### Safety Checks
- Verify GPU is not in use before binding
- Check for running processes
- Validate IOMMU is enabled
- Verify vfio-pci module is loaded

### Error Handling
- Comprehensive error checking
- Graceful failure modes
- Rollback on failure
- Detailed error logging

## Dependencies

### Required Tools
- lspci (PCI device enumeration)
- readlink (symbolic link resolution)
- echo (file writing)
- cat (file reading)
- grep (text processing)
- awk (text processing)

### System Requirements
- Root privileges
- IOMMU enabled in BIOS
- vfio-pci kernel module available
- Appropriate GPU drivers installed

### Optional Tools
- jq (JSON processing)
- modprobe (kernel module management)

## Success Criteria

- [ ] bind_gpu_to_vfio.sh successfully binds GPUs
- [ ] bind_gpu_to_vfio.sh handles audio functions
- [ ] unbind_gpu_from_vfio.sh successfully unbinds GPUs
- [ ] unbind_gpu_from_vfio.sh restores drivers correctly
- [ ] check_vfio_binding.sh reports accurate status
- [ ] update_vfio_conf.sh updates configuration correctly
- [ ] get_gpu_driver_info.sh identifies drivers correctly
- [ ] verify_vfio_binding.sh verifies passthrough readiness
- [ ] All scripts handle errors gracefully
- [ ] All outputs are valid JSON
- [ ] GPUManager.php provides complete VFIO API
- [ ] Safety checks prevent unsafe operations
- [ ] Logging captures all operations

## Risk Assessment

### Low Risk
- PCI address validation
- Driver information retrieval
- Binding status checking

### Medium Risk
- Driver unbinding operations
- vfio.conf file updates
- Audio function handling

### High Risk
- Binding GPUs while in use
- Incorrect driver restoration
- System instability from improper binding

### Mitigation Strategies
- Comprehensive usage checking
- Multiple verification steps
- Rollback capabilities
- Detailed logging
- Conservative safety checks

## Next Phase Dependencies

Phase 2 completion enables:
- Phase 3: Service management can trigger GPU binding
- Phase 4: Event handlers can automate GPU switching
- Phase 5: Configuration can store binding preferences
- Phase 6: Web GUI can control GPU binding
- Phase 7: Dashboard can show binding status

## Estimated Time

- bind_gpu_to_vfio.sh: 45 minutes
- unbind_gpu_from_vfio.sh: 45 minutes
- check_vfio_binding.sh: 30 minutes
- update_vfio_conf.sh: 30 minutes
- get_gpu_driver_info.sh: 30 minutes
- verify_vfio_binding.sh: 30 minutes
- GPUManager.php updates: 30 minutes
- Testing: 60 minutes

**Total: ~5 hours**

## Notes

- VFIO binding requires IOMMU to be enabled in BIOS
- Audio functions must be bound along with GPU for passthrough
- vfio.conf updates may require module reload
- Driver restoration must identify correct driver for GPU
- Safety checks are critical to prevent system instability
- Error messages must be user-friendly
- All operations must be logged for debugging
- Testing should cover various GPU vendors and models