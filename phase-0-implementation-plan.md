# Phase 0: Plugin Foundation Implementation Plan

## Overview
Phase 0 establishes the foundational structure required for all subsequent phases. This includes the Unraid plugin manifest, installation/removal scripts, and basic directory structure.

## Files to Create

### 1. plugin.plg
**Purpose:** Unraid plugin manifest for installation and updates
**Location:** Root of plugin package
**Format:** XML with plugin metadata

**Required Elements:**
- Plugin name, version, author
- Description and changelog
- Download URL and MD5 hash
- Unraid version requirements
- File installation instructions

**Key Features:**
- Version tracking for updates
- Dependency checking
- File installation paths
- MD5 verification for integrity

### 2. install.sh
**Purpose:** Installation script that runs when plugin is installed
**Location:** Executed during plugin installation
**Permissions:** Executable (755)

**Responsibilities:**
- Create required directories
- Set proper file permissions
- Initialize configuration files
- Register with Unraid system
- Validate system requirements

**Safety Checks:**
- Unraid version compatibility
- Required tools availability (lspci, virsh, docker)
- Sufficient disk space
- Write permissions on /boot/config

### 3. remove.sh
**Purpose:** Cleanup script that runs when plugin is removed
**Location:** Executed during plugin removal
**Permissions:** Executable (755)

**Responsibilities:**
- Stop any running services
- Remove plugin files
- Clean up configuration (optional - preserve user data)
- Unregister from Unraid system
- Remove log files

**Safety Features:**
- Graceful service shutdown
- Configuration backup option
- Error handling and rollback
- User confirmation for destructive operations

### 4. Directory Structure
**Runtime Files:** `/usr/local/emhttp/plugins/gpu.switch.manager/`
- Read-only after installation
- Contains PHP, JavaScript, CSS, scripts
- Web interface files

**Configuration Files:** `/boot/config/plugins/gpu.switch.manager/`
- Persistent storage
- User profiles and settings
- Survives system reboots

**Log Files:** `/var/log/gpu.switch.manager.log`
- Runtime logging
- Debug information
- Error tracking

## Implementation Steps

### Step 1: Create plugin.plg
1. Define XML structure with required metadata
2. Set initial version to 1.0.0
3. Add placeholder download URL (will be updated)
4. Include comprehensive description
5. Add Unraid 6.12.0+ requirement
6. Create initial changelog entry

### Step 2: Create install.sh
1. Add shebang and error handling
2. Create directory structure
3. Set file permissions (755 for scripts, 644 for configs)
4. Initialize empty configuration files
5. Create log file with proper permissions
6. Add system validation checks
7. Provide user feedback during installation

### Step 3: Create remove.sh
1. Add shebang and error handling
2. Stop any running plugin processes
3. Remove runtime files
4. Offer to preserve configuration
5. Clean up log files
6. Provide user feedback during removal

### Step 4: Create Basic Directory Structure
1. Create main plugin directory
2. Create subdirectories:
   - `scripts/` - Shell scripts
   - `event/` - Unraid event hooks
   - `include/` - PHP classes
   - `javascript/` - Frontend logic
   - `styles/` - CSS styling
   - `templates/` - HTML templates
3. Create config directory
4. Set proper ownership and permissions

### Step 5: Create Placeholder Configuration Files
1. Create main config file with default settings
2. Create empty profiles.json
3. Create empty state.json
4. Add comments explaining each setting

### Step 6: Testing
1. Validate plugin.plg XML syntax
2. Test install.sh script execution
3. Test remove.sh script execution
4. Verify directory creation
5. Check file permissions
6. Validate configuration file format

## Security Considerations

### Input Validation
- Validate all file paths
- Check for directory traversal attacks
- Sanitize user inputs in scripts

### Permission Management
- Use principle of least privilege
- Set appropriate file permissions
- Validate write access before operations

### Error Handling
- Comprehensive error checking
- Graceful failure modes
- Informative error messages
- Rollback on failure

## Dependencies

### System Requirements
- Unraid 6.12.0 or higher
- Bash shell
- Basic Unix tools (mkdir, chmod, chown, etc.)

### Optional Tools (for validation)
- xmllint (for XML validation)
- shellcheck (for script validation)

## Success Criteria

- [ ] plugin.plg is valid XML with all required fields
- [ ] install.sh creates all required directories
- [ ] install.sh sets correct permissions
- [ ] install.sh validates system requirements
- [ ] remove.sh cleans up all files
- [ ] remove.sh offers to preserve user configuration
- [ ] Configuration files are created with proper structure
- [ ] All scripts have proper error handling
- [ ] Installation provides user feedback
- [ ] Removal provides user feedback

## Risk Assessment

### Low Risk
- Directory creation operations
- File permission setting
- Configuration file initialization

### Medium Risk
- System requirement validation
- Dependency checking
- File cleanup operations

### Mitigation Strategies
- Comprehensive error handling
- User confirmation for destructive operations
- Rollback capabilities
- Detailed logging

## Next Phase Dependencies

Phase 0 completion enables:
- Phase 1: Device discovery scripts can be installed
- Phase 2: VFIO binding scripts have proper location
- Phase 3: Service management scripts can be added
- Phase 4: Event hooks can be registered
- Phase 5: Configuration system has foundation
- Phase 6: Web GUI files have proper location
- Phase 7: Dashboard widget can be integrated

## Estimated Time

- plugin.plg: 30 minutes
- install.sh: 45 minutes
- remove.sh: 30 minutes
- Directory structure: 15 minutes
- Configuration files: 20 minutes
- Testing: 30 minutes

**Total: ~2.5-3 hours**

## Notes

- This phase creates the foundation but doesn't provide any functionality yet
- All subsequent phases depend on this structure being correct
- Testing should be done on a test Unraid system first
- Keep plugin.plg version number synchronized throughout development
- Document any deviations from standard Unraid plugin conventions