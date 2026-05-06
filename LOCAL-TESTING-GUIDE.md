# Local Testing Guide

## Testing Without GitHub Upload

### Method 1: Direct Unraid Server Testing

If you have a Unraid server available:

#### Step 1: Transfer Files to Unraid Server

```bash
# From your local machine, transfer the plugin package
scp archives/gpu-switch-manager-1.0.0.txz root@your-unraid-server:/tmp/

# Or transfer individual files for testing
scp plugin.plg root@your-unraid-server:/boot/config/plugins/
scp -r include/ root@your-unraid-server:/usr/local/emhttp/plugins/gpu-switch-manager/
scp -r scripts/ root@your-unraid-server:/usr/local/emhttp/plugins/gpu-switch-manager/
scp -r web/ root@your-unraid-server:/usr/local/emhttp/plugins/gpu-switch-manager/
```

#### Step 2: Manual Installation on Unraid

```bash
# SSH into your Unraid server
ssh root@your-unraid-server

# Create plugin directory
mkdir -p /usr/local/emhttp/plugins/gpu-switch-manager

# Extract the package
cd /tmp
tar -xzf gpu-switch-manager-1.0.0.txz -C /usr/local/emhttp/plugins/gpu-switch-manager/

# Make scripts executable
chmod +x /usr/local/emhttp/plugins/gpu-switch-manager/scripts/*.sh
chmod +x /usr/local/emhttp/plugins/gpu-switch-manager/install.sh
chmod +x /usr/local/emhttp/plugins/gpu-switch-manager/remove.sh

# Run installation
cd /usr/local/emhttp/plugins/gpu-switch-manager
./install.sh
```

#### Step 3: Verify Installation

```bash
# Check if files are in place
ls -la /usr/local/emhttp/plugins/gpu-switch-manager/

# Check web interface
ls -la /usr/local/emhttp/webplugins/gpu-switch-manager/

# Check configuration
cat /boot/config/plugins/gpu-switch-manager/gpu.switch.manager.cfg
```

#### Step 4: Test Functionality

```bash
# Test GPU listing
/usr/local/emhttp/plugins/gpu-switch-manager/scripts/list_gpus.sh

# Test GPU state checking
/usr/local/emhttp/plugins/gpu-switch-manager/scripts/get_gpu_state.sh

# Test web interface access
# Open browser: http://your-unraid-server:80/gpu-switch-manager/
```

### Method 2: Component Testing (No Unraid Required)

Test individual components on your local machine:

#### Test PHP Components

```bash
# Test PHP syntax
php -l include/AuthenticationService.php
php -l include/AuthorizationService.php
php -l include/SecurityMiddleware.php
php -l include/GPUManager.php

# Run security tests
php tests/security_test_suite.php
php tests/security_integration_tests.php
```

#### Test Shell Scripts

```bash
# Test shell script syntax
bash -n scripts/bind_gpu_to_vfio.sh
bash -n scripts/unbind_gpu_from_vfio.sh
bash -n scripts/list_gpus.sh

# Test secure shell library
bash -n scripts/secure_shell_lib.sh
```

#### Test Configuration Files

```bash
# Validate JSON configuration
python -m json.tool profiles.json
python -m json.tool state.json

# Check plugin metadata
cat plugin.plg
```

#### Test Web Interface

```bash
# Start local PHP server (if PHP is installed)
cd web
php -S localhost:8080

# Then access: http://localhost:8080/
```

### Method 3: Docker/VM Testing

Create a test environment:

#### Using Docker (if available)

```bash
# Create a test container with PHP
docker run -it -v $(pwd):/app php:8.1-cli bash

# Inside container
cd /app
php tests/security_test_suite.php
php -l include/*.php
```

#### Using Virtual Machine

1. Create a Unraid VM or use existing Unraid installation
2. Follow Method 1 steps above
3. Test in isolated environment

### Method 4: Validation Scripts

Run the included validation scripts:

```bash
# Validate all phases
./validate_phase0.sh
./validate_phase1.sh
./validate_phase2.sh
./validate_phase3.sh
./validate_phase4.sh
./validate_phase5.sh
./validate_phase6.sh

# Run security tests
./tests/run_security_tests.sh
```

## Pre-Upload Checklist

Before uploading to GitHub, verify:

- [ ] All PHP files have valid syntax
- [ ] All shell scripts have valid syntax
- [ ] Security tests pass (100% pass rate)
- [ ] Configuration files are valid JSON
- [ ] Plugin metadata is correct
- [ ] MD5 hash matches package
- [ ] Installation script is executable
- [ ] Removal script is executable
- [ ] Web interface files are present
- [ ] Assets (icon.png, banner.png) are included

## Quick Test Commands

Run these commands for quick validation:

```bash
# Syntax check all PHP files
find include/ -name "*.php" -exec php -l {} \;

# Syntax check all shell scripts
find scripts/ -name "*.sh" -exec bash -n {} \;

# Validate JSON files
python -m json.tool profiles.json > /dev/null && echo "profiles.json valid"
python -m json.tool state.json > /dev/null && echo "state.json valid"

# Run security tests
php tests/security_test_suite.php
php tests/security_integration_tests.php

# Check package contents
tar -tzf archives/gpu-switch-manager-1.0.0.txz | head -20

# Verify MD5
md5sum archives/gpu-switch-manager-1.0.0.txz
```

## Testing Web Interface Locally

If you want to test the web interface without Unraid:

```bash
# Install PHP if not available
# On Ubuntu/Debian: sudo apt install php-cli php-json

# Start local server
cd web
php -S localhost:8080

# Access in browser
# http://localhost:8080/
```

Note: Some functionality may not work without Unraid environment, but you can test the UI and basic interactions.

## Troubleshooting

### PHP Not Found
```bash
# Install PHP
# Ubuntu/Debian: sudo apt install php-cli
# macOS: brew install php
# Windows: Download from php.net
```

### Permission Errors
```bash
# Make scripts executable
chmod +x scripts/*.sh
chmod +x install.sh
chmod +x remove.sh
```

### Missing Dependencies
```bash
# Check PHP extensions
php -m | grep -E "(json|curl|openssl)"

# Install missing extensions
# Ubuntu/Debian: sudo apt install php-json php-curl
```

## Next Steps After Testing

Once testing is complete:

1. Create GitHub repository
2. Push source code
3. Create v1.0.0 release
4. Upload plugin package
5. Submit to Unraid Plugin Repository

---

**Testing Status:** Ready for local testing
**Recommended Method:** Method 1 (Direct Unraid Server Testing) if available, otherwise Method 2 (Component Testing)