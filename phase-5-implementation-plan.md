# Phase 5: Configuration Management Implementation Plan

## Date: 2026-05-03

## Overview
Phase 5: Configuration Management provides comprehensive configuration management capabilities for the GPU Switch Manager plugin. This phase enables users to create and manage GPU switching profiles, persist configuration settings, define user preferences, validate configurations, and store service-specific preferences. The configuration management system provides a robust foundation for the web interface in Phase 6.

## Objectives

### Primary Objectives
1. Implement profile management for GPU switching configurations
2. Add configuration persistence with file-based storage
3. Create user preferences system
4. Add comprehensive configuration validation
5. Store service-specific preferences

### Secondary Objectives
1. Provide configuration import/export functionality
2. Implement configuration versioning
3. Add configuration backup/restore
4. Create configuration templates
5. Support configuration inheritance

## Technical Requirements

### Profile Management
- Create, read, update, delete (CRUD) operations for profiles
- Profile validation and verification
- Profile activation and deactivation
- Profile cloning and duplication
- Profile export/import

### Configuration Persistence
- File-based configuration storage
- JSON format for configuration files
- Configuration directory structure
- Configuration file locking
- Atomic configuration updates

### User Preferences
- User preference storage
- Preference validation
- Default preferences
- Preference inheritance
- Preference overrides

### Configuration Validation
- Schema-based validation
- Cross-reference validation
- Dependency validation
- Conflict detection
- Error reporting

### Service Preferences
- Service-specific configuration
- Service preference storage
- Service preference validation
- Service preference inheritance
- Service preference overrides

## File Structure

### Configuration Files
```
config/
├── profiles/
│   ├── default.json
│   ├── gaming.json
│   ├── workstation.json
│   └── custom.json
├── preferences/
│   ├── user.json
│   ├── system.json
│   └── defaults.json
├── services/
│   ├── docker.json
│   ├── vm.json
│   └── array.json
├── templates/
│   ├── basic.json
│   ├── advanced.json
│   └── minimal.json
├── backups/
│   ├── config_20260503_120000.json
│   └── config_20260503_130000.json
└── config.json
```

### Shell Scripts
```
scripts/
├── config_manager.sh
├── profile_manager.sh
├── preference_manager.sh
├── config_validator.sh
├── config_backup.sh
├── config_import.sh
├── config_export.sh
├── config_migrate.sh
├── config_version.sh
└── config_template.sh
```

### PHP Classes
```
include/
├── ConfigManager.php
├── ProfileManager.php
├── PreferenceManager.php
├── ConfigValidator.php
└── ConfigBackup.php
```

## Implementation Steps

### Step 1: Configuration Manager Core
**File:** `scripts/config_manager.sh`

**Functions:**
- `init_config()` - Initialize configuration system
- `load_config()` - Load configuration from file
- `save_config()` - Save configuration to file
- `get_config_value()` - Get configuration value
- `set_config_value()` - Set configuration value
- `delete_config_value()` - Delete configuration value
- `validate_config()` - Validate configuration
- `merge_config()` - Merge configurations
- `backup_config()` - Backup configuration
- `restore_config()` - Restore configuration

**Features:**
- File-based configuration storage
- JSON format for configuration files
- Configuration file locking
- Atomic configuration updates
- Configuration validation
- Configuration backup/restore

### Step 2: Profile Manager
**File:** `scripts/profile_manager.sh`

**Functions:**
- `create_profile()` - Create new profile
- `read_profile()` - Read profile
- `update_profile()` - Update profile
- `delete_profile()` - Delete profile
- `list_profiles()` - List all profiles
- `activate_profile()` - Activate profile
- `deactivate_profile()` - Deactivate profile
- `clone_profile()` - Clone profile
- `validate_profile()` - Validate profile
- `get_active_profile()` - Get active profile

**Features:**
- Profile CRUD operations
- Profile validation
- Profile activation/deactivation
- Profile cloning
- Profile export/import

### Step 3: Preference Manager
**File:** `scripts/preference_manager.sh`

**Functions:**
- `set_preference()` - Set user preference
- `get_preference()` - Get user preference
- `delete_preference()` - Delete user preference
- `list_preferences()` - List all preferences
- `reset_preference()` - Reset preference to default
- `reset_all_preferences()` - Reset all preferences
- `validate_preference()` - Validate preference
- `get_default_preference()` - Get default preference
- `merge_preferences()` - Merge preferences
- `export_preferences()` - Export preferences

**Features:**
- User preference storage
- Preference validation
- Default preferences
- Preference inheritance
- Preference overrides

### Step 4: Configuration Validator
**File:** `scripts/config_validator.sh`

**Functions:**
- `validate_schema()` - Validate against schema
- `validate_references()` - Validate cross-references
- `validate_dependencies()` - Validate dependencies
- `detect_conflicts()` - Detect conflicts
- `generate_report()` - Generate validation report
- `fix_errors()` - Fix validation errors
- `get_validation_rules()` - Get validation rules
- `add_validation_rule()` - Add validation rule
- `remove_validation_rule()` - Remove validation rule
- `test_validation()` - Test validation

**Features:**
- Schema-based validation
- Cross-reference validation
- Dependency validation
- Conflict detection
- Error reporting
- Error fixing

### Step 5: Configuration Backup
**File:** `scripts/config_backup.sh`

**Functions:**
- `create_backup()` - Create configuration backup
- `list_backups()` - List all backups
- `restore_backup()` - Restore from backup
- `delete_backup()` - Delete backup
- `auto_backup()` - Automatic backup
- `schedule_backup()` - Schedule backup
- `verify_backup()` - Verify backup integrity
- `compress_backup()` - Compress backup
- `decompress_backup()` - Decompress backup
- `cleanup_backups()` - Cleanup old backups

**Features:**
- Configuration backup/restore
- Automatic backup scheduling
- Backup verification
- Backup compression
- Backup cleanup

### Step 6: Configuration Import/Export
**File:** `scripts/config_import.sh` and `scripts/config_export.sh`

**Functions (import):**
- `import_config()` - Import configuration
- `validate_import()` - Validate import
- `merge_import()` - Merge import
- `preview_import()` - Preview import
- `confirm_import()` - Confirm import

**Functions (export):**
- `export_config()` - Export configuration
- `select_export()` - Select export scope
- `format_export()` - Format export
- `compress_export()` - Compress export
- `verify_export()` - Verify export

**Features:**
- Configuration import/export
- Import validation
- Export formatting
- Import preview
- Export verification

### Step 7: Configuration Migration
**File:** `scripts/config_migrate.sh`

**Functions:**
- `migrate_config()` - Migrate configuration
- `detect_version()` - Detect configuration version
- `upgrade_config()` - Upgrade configuration
- `downgrade_config()` - Downgrade configuration
- `validate_migration()` - Validate migration
- `rollback_migration()` - Rollback migration
- `get_migration_path()` - Get migration path
- `test_migration()` - Test migration

**Features:**
- Configuration versioning
- Configuration migration
- Version detection
- Migration validation
- Migration rollback

### Step 8: Configuration Versioning
**File:** `scripts/config_version.sh`

**Functions:**
- `get_version()` - Get configuration version
- `set_version()` - Set configuration version
- `increment_version()` - Increment version
- `compare_versions()` - Compare versions
- `get_version_history()` - Get version history
- `create_version_tag()` - Create version tag
- `get_version_diff()` - Get version diff
- `validate_version()` - Validate version

**Features:**
- Configuration versioning
- Version history
- Version comparison
- Version tagging
- Version diff

### Step 9: Configuration Templates
**File:** `scripts/config_template.sh`

**Functions:**
- `create_template()` - Create template
- `list_templates()` - List templates
- `apply_template()` - Apply template
- `validate_template()` - Validate template
- `customize_template()` - Customize template
- `delete_template()` - Delete template
- `export_template()` - Export template
- `import_template()` - Import template
- `get_template_info()` - Get template info
- `test_template()` - Test template

**Features:**
- Configuration templates
- Template application
- Template customization
- Template validation
- Template import/export

### Step 10: PHP Configuration Classes
**Files:** `include/ConfigManager.php`, `include/ProfileManager.php`, `include/PreferenceManager.php`, `include/ConfigValidator.php`, `include/ConfigBackup.php`

**ConfigManager.php Methods:**
- `__construct()` - Constructor
- `loadConfig($configPath)` - Load configuration
- `saveConfig($configPath)` - Save configuration
- `getConfigValue($key)` - Get configuration value
- `setConfigValue($key, $value)` - Set configuration value
- `deleteConfigValue($key)` - Delete configuration value
- `validateConfig()` - Validate configuration
- `mergeConfig($otherConfig)` - Merge configurations
- `backupConfig()` - Backup configuration
- `restoreConfig($backupPath)` - Restore configuration
- `getConfigVersion()` - Get configuration version

**ProfileManager.php Methods:**
- `__construct()` - Constructor
- `createProfile($name, $config)` - Create profile
- `readProfile($name)` - Read profile
- `updateProfile($name, $config)` - Update profile
- `deleteProfile($name)` - Delete profile
- `listProfiles()` - List profiles
- `activateProfile($name)` - Activate profile
- `deactivateProfile($name)` - Deactivate profile
- `cloneProfile($source, $target)` - Clone profile
- `validateProfile($name)` - Validate profile
- `getActiveProfile()` - Get active profile

**PreferenceManager.php Methods:**
- `__construct()` - Constructor
- `setPreference($key, $value)` - Set preference
- `getPreference($key)` - Get preference
- `deletePreference($key)` - Delete preference
- `listPreferences()` - List preferences
- `resetPreference($key)` - Reset preference
- `resetAllPreferences()` - Reset all preferences
- `validatePreference($key, $value)` - Validate preference
- `getDefaultPreference($key)` - Get default preference
- `mergePreferences($preferences)` - Merge preferences
- `exportPreferences()` - Export preferences

**ConfigValidator.php Methods:**
- `__construct()` - Constructor
- `validateSchema($config, $schema)` - Validate schema
- `validateReferences($config)` - Validate references
- `validateDependencies($config)` - Validate dependencies
- `detectConflicts($config)` - Detect conflicts
- `generateReport($errors)` - Generate report
- `fixErrors($errors)` - Fix errors
- `getValidationRules()` - Get validation rules
- `addValidationRule($rule)` - Add validation rule
- `removeValidationRule($rule)` - Remove validation rule
- `testValidation($config)` - Test validation

**ConfigBackup.php Methods:**
- `__construct()` - Constructor
- `createBackup()` - Create backup
- `listBackups()` - List backups
- `restoreBackup($backupPath)` - Restore backup
- `deleteBackup($backupPath)` - Delete backup
- `autoBackup()` - Automatic backup
- `scheduleBackup($schedule)` - Schedule backup
- `verifyBackup($backupPath)` - Verify backup
- `compressBackup($backupPath)` - Compress backup
- `decompressBackup($backupPath)` - Decompress backup
- `cleanupBackups()` - Cleanup backups

## Configuration Schema

### Main Configuration Schema
```json
{
  "version": "1.0.0",
  "profiles": {
    "default": {
      "name": "default",
      "description": "Default GPU switching profile",
      "gpu_bindings": {},
      "service_preferences": {},
      "event_handlers": {},
      "safety_checks": {},
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
}
```

### Profile Schema
```json
{
  "name": "profile_name",
  "description": "Profile description",
  "gpu_bindings": {
    "gpu_address": {
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
}
```

## Success Criteria

### Functional Requirements
- Profile management works correctly
- Configuration persistence works correctly
- User preferences work correctly
- Configuration validation works correctly
- Service preferences work correctly

### Non-Functional Requirements
- Configuration operations are efficient
- Configuration storage is reliable
- Configuration validation is comprehensive
- Error handling is robust
- Logging is complete

### Quality Requirements
- All validation tests pass
- Code is well-documented
- Error messages are clear
- Performance is acceptable
- Security is maintained

## Testing Requirements

### Unit Tests
- Configuration manager functions
- Profile manager functions
- Preference manager functions
- Configuration validator functions
- Configuration backup functions

### Integration Tests
- Configuration manager integration
- Profile manager integration
- Preference manager integration
- Configuration validator integration
- Configuration backup integration

### Validation Tests
- Configuration file validation
- Profile validation
- Preference validation
- Configuration backup validation
- Configuration import/export validation

## Security Considerations

### Input Validation
- All configuration values validated before use
- All profile names validated
- All preference keys validated
- All file paths validated
- All configuration operations validated

### Permission Management
- Configuration file permissions checking
- Profile file permissions checking
- Preference file permissions checking
- Backup file permissions checking
- Operation permission verification

### Safety Checks
- Configuration validation before saving
- Profile validation before activation
- Preference validation before setting
- Backup verification before restore
- Import validation before applying

### Error Handling
- Comprehensive error checking
- Graceful failure modes
- Rollback capabilities
- Detailed logging
- User notification

## Performance Considerations

### Configuration Operations
- Efficient configuration loading
- Efficient configuration saving
- Efficient configuration validation
- Efficient configuration merging
- Minimal configuration operation latency

### Resource Usage
- Minimal CPU usage for configuration operations
- Minimal memory usage for configuration storage
- Efficient disk I/O for configuration files
- Optimized network usage for import/export
- Efficient backup operations

### Caching
- Configuration value caching
- Profile information caching
- Preference value caching
- Validation result caching
- Backup information caching

## Documentation Requirements

### Code Documentation
- Comprehensive function comments
- Usage examples in script headers
- Error message clarity
- Logging for debugging

### User Documentation
- Configuration management guide
- Profile management guide
- Preference management guide
- Configuration validation guide
- Configuration backup guide

### API Documentation
- ConfigManager.php method documentation
- ProfileManager.php method documentation
- PreferenceManager.php method documentation
- ConfigValidator.php method documentation
- ConfigBackup.php method documentation

## Known Limitations

### Environment Requirements
- Requires file system access for configuration storage
- Requires JSON processing capabilities
- Requires file locking support
- Root privileges for some operations
- Sufficient disk space for backups

### Platform Dependencies
- Linux-specific implementation
- Unraid-specific paths
- Bash shell requirement
- jq for JSON processing
- File system dependencies

### Configuration Limitations
- Configuration size limits
- Profile count limits
- Preference count limits
- Backup retention limits
- Import/export size limits

## Integration Points

### Phase 4 Dependencies
- Uses event handlers from Phase 4
- Leverages GPU discovery from Phase 1
- Integrates with VFIO binding from Phase 2
- Coordinates with service management from Phase 3
- Uses GPUManager.php class

### Phase 6+ Enablement
- Enables web GUI configuration management
- Provides configuration API for web interface
- Enables user preference management
- Supports configuration templates
- Provides configuration backup/restore

## Implementation Order

1. **Configuration Manager Core** - Foundation for all configuration operations
2. **Profile Manager** - Profile management functionality
3. **Preference Manager** - User preference management
4. **Configuration Validator** - Configuration validation
5. **Configuration Backup** - Backup/restore functionality
6. **Configuration Import/Export** - Import/export functionality
7. **Configuration Migration** - Version management
8. **Configuration Versioning** - Version tracking
9. **Configuration Templates** - Template management
10. **PHP Configuration Classes** - PHP API for configuration management

## Validation Plan

### Script Validation
- Script existence and permissions
- Function presence and naming
- Error handling implementation
- Input validation coverage
- JSON output format validation

### PHP Class Validation
- Class structure validation
- Method presence and naming
- Error handling implementation
- Input validation coverage
- Return type validation

### Integration Validation
- Configuration manager integration
- Profile manager integration
- Preference manager integration
- Configuration validator integration
- Configuration backup integration

### Functional Validation
- Configuration CRUD operations
- Profile CRUD operations
- Preference CRUD operations
- Configuration validation
- Configuration backup/restore

## Next Steps

After completing Phase 5, the next phase will be:
- Phase 6: Web Interface - Implement web GUI for configuration management and GPU control

## Conclusion

Phase 5: Configuration Management provides comprehensive configuration management capabilities for the GPU Switch Manager plugin. The implementation includes profile management, configuration persistence, user preferences, configuration validation, and service preferences.

The configuration management system provides a robust foundation for the web interface in Phase 6, enabling users to easily manage GPU switching configurations through a user-friendly web interface.
