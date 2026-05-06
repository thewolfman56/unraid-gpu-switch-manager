# Unraid Installation Guide

## Quick Setup for Web Interface

The web interface directory needs to be created and populated. Here's how to fix this:

## Step 1: Create Directory Structure

```bash
# SSH into your Unraid server
ssh root@[server-ip]

# Create web plugins directory
mkdir -p /usr/local/emhttp/webplugins/gpu-switch-manager

# Create main plugin directory if it doesn't exist
mkdir -p /usr/local/emhttp/plugins/gpu-switch-manager
```

## Step 2: Transfer Web Interface Files

From your local machine:

```bash
# Transfer web interface files to Unraid
scp -r web/* root@[server-ip]:/usr/local/emhttp/webplugins/gpu-switch-manager/

# Or if you have the package on Unraid already:
# Extract web files from the package
cd /usr/local/emhttp/plugins/gpu-switch-manager
tar -xzf gpu-switch-manager-1.0.0.txz -C /usr/local/emhttp/webplugins/gpu-switch-manager/ --strip-components=1 web/
```

## Step 3: Set Permissions

```bash
# On Unraid server
chmod -R 755 /usr/local/emhttp/webplugins/gpu-switch-manager
chmod -R 755 /usr/local/emhttp/plugins/gpu-switch-manager
```

## Step 4: Verify Installation

```bash
# Check web interface files
ls -la /usr/local/emhttp/webplugins/gpu-switch-manager/

# Check main plugin files
ls -la /usr/local/emhttp/plugins/gpu-switch-manager/

# Check configuration
ls -la /boot/config/plugins/gpu-switch-manager/
```

## Step 5: Test Web Interface

Open your browser and navigate to:
```
http://[server-ip]/gpu-switch-manager/
```

Or through Unraid web interface:
```
Settings → GPU Switch Manager
```

## Alternative: Full Package Installation

If you want to do a complete installation:

```bash
# On Unraid server
cd /tmp

# If you have the package file, extract it
tar -xzf gpu-switch-manager-1.0.0.txz -C /usr/local/emhttp/plugins/gpu-switch-manager/

# Run installation script
cd /usr/local/emhttp/plugins/gpu-switch-manager
chmod +x install.sh
./install.sh
```

## Manual Installation Steps

If the install.sh script doesn't work, do it manually:

```bash
# 1. Create directories
mkdir -p /usr/local/emhttp/plugins/gpu-switch-manager
mkdir -p /usr/local/emhttp/webplugins/gpu-switch-manager
mkdir -p /boot/config/plugins/gpu-switch-manager

# 2. Copy files (adjust paths based on where you extracted the package)
cp -r /path/to/extracted/include/* /usr/local/emhttp/plugins/gpu-switch-manager/
cp -r /path/to/extracted/web/* /usr/local/emhttp/webplugins/gpu-switch-manager/
cp -r /path/to/extracted/scripts/* /usr/local/emhttp/plugins/gpu-switch-manager/
cp -r /path/to/extracted/assets/* /usr/local/emhttp/plugins/gpu-switch-manager/

# 3. Copy configuration
cp /path/to/extracted/gpu.switch.manager.cfg /boot/config/plugins/gpu-switch-manager/
cp /path/to/extracted/profiles.json /boot/config/plugins/gpu-switch-manager/
cp /path/to/extracted/state.json /boot/config/plugins/gpu-switch-manager/

# 4. Set permissions
chmod -R 755 /usr/local/emhttp/plugins/gpu-switch-manager
chmod -R 755 /usr/local/emhttp/webplugins/gpu-switch-manager
chmod +x /usr/local/emhttp/plugins/gpu-switch-manager/scripts/*.sh

# 5. Create symlinks if needed
ln -sf /usr/local/emhttp/webplugins/gpu-switch-manager /var/www/html/gpu-switch-manager
```

## Troubleshooting

### Web Interface Not Accessible

```bash
# Check if web server is running
ps aux | grep emhttp

# Check file permissions
ls -la /usr/local/emhttp/webplugins/gpu-switch-manager/

# Check if directory exists
ls -la /usr/local/emhttp/webplugins/

# Restart web interface if needed
/etc/rc.d/rc.nginx restart
```

### PHP Errors

```bash
# Check PHP error log
tail -f /var/log/php_errors.log

# Check if PHP is installed
php -v

# Check PHP extensions
php -m
```

### Permission Issues

```bash
# Fix permissions
chown -R nobody:users /usr/local/emhttp/webplugins/gpu-switch-manager
chmod -R 755 /usr/local/emhttp/webplugins/gpu-switch-manager
```

## Verification Commands

Run these to verify installation:

```bash
# Check web interface files exist
ls -la /usr/local/emhttp/webplugins/gpu-switch-manager/

# Check main plugin files
ls -la /usr/local/emhttp/plugins/gpu-switch-manager/

# Check configuration
cat /boot/config/plugins/gpu-switch-manager/gpu.switch.manager.cfg

# Test a script
/usr/local/emhttp/plugins/gpu-switch-manager/scripts/list_gpus.sh
```

## Expected Directory Structure

After installation, you should have:

```
/usr/local/emhttp/plugins/gpu-switch-manager/
├── include/
│   ├── AuthenticationService.php
│   ├── AuthorizationService.php
│   ├── GPUManager.php
│   └── ...
├── scripts/
│   ├── bind_gpu_to_vfio.sh
│   ├── list_gpus.sh
│   └── ...
├── assets/
│   ├── icon.png
│   └── banner.png
└── install.sh

/usr/local/emhttp/webplugins/gpu-switch-manager/
├── index.php
├── gpu.php
├── config.php
├── profiles.php
├── assets/
│   ├── css/
│   ├── js/
│   └── images/
└── templates/

/boot/config/plugins/gpu-switch-manager/
├── gpu.switch.manager.cfg
├── profiles.json
└── state.json
```

## Next Steps After Installation

1. Access web interface: `http://[server-ip]/gpu-switch-manager/`
2. Login with default admin credentials
3. Change default password
4. Configure GPU profiles
5. Test GPU switching functionality

---

**Installation Status:** Web interface directory needs to be created
**Next Action:** Run the commands above to set up the directory structure