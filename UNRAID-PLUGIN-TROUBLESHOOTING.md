# Unraid Plugin Installation Troubleshooting

## Current Issue

Plugin didn't install correctly from GitHub link. Expected directories don't exist:
- `/usr/local/emhttp/plugins/gpu-switch-manager/` ❌
- `/usr/local/emhttp/webplugins/gpu-switch-manager/` ❌
- `/usr/local/emhttp/websettings/gpu-switch-manager.php` ❌

## Diagnostic Steps

### Step 1: Check Plugin Installation Status

```bash
# Check if plugin was downloaded
ls -la /var/log/plugins/

# Check plugin installation logs
cat /var/log/syslog | grep -i "gpu-switch-manager"

# Check for any plugin files
find /usr/local/emhttp -name "*gpu-switch*" -type f 2>/dev/null

# Check boot config
ls -la /boot/config/plugins/
```

### Step 2: Check Unraid Plugin System

```bash
# Check if plugin is listed in installed plugins
ls -la /var/log/plugins/*.plg

# Check plugin download directory
ls -la /boot/config/plugins/

# Look for any error logs
tail -100 /var/log/syslog | grep -i error
```

### Step 3: Manual Installation (Recommended)

Since automatic installation failed, let's install manually:

```bash
# 1. Download the plugin package directly
cd /tmp
wget https://github.com/thewolfman56/unraid-gpu-switch-manager/releases/download/2026.05.05/gpu-switch-manager-2026.05.05.txz

# OR if wget doesn't work, use curl:
curl -L -o gpu-switch-manager-2026.05.05.txz https://github.com/thewolfman56/unraid-gpu-switch-manager/releases/download/2026.05.05/gpu-switch-manager-2026.05.05.txz

# 2. Verify the download
ls -lh gpu-switch-manager-2026.05.05.txz
md5sum gpu-switch-manager-2026.05.05.txz

# Expected MD5: c32be8dcf8357e95608e663e75657642

# 3. Extract the package
mkdir -p /tmp/gpu-switch-manager
tar -xzf gpu-switch-manager-2026.05.05.txz -C /tmp/gpu-switch-manager/

# 4. Check extracted contents
ls -la /tmp/gpu-switch-manager/

# 5. Run installation script
cd /tmp/gpu-switch-manager
chmod +x install.sh
./install.sh

# 6. Verify installation
ls -la /usr/local/emhttp/plugins/gpu-switch-manager/
ls -la /usr/local/emhttp/webplugins/gpu-switch-manager/
ls -la /usr/local/emhttp/websettings/gpu-switch-manager.php
```

### Step 4: Alternative Manual Installation

If the above doesn't work, try this step-by-step approach:

```bash
# 1. Create directories manually
mkdir -p /usr/local/emhttp/plugins/gpu-switch-manager/{scripts,event,include,javascript,styles,templates,assets}
mkdir -p /usr/local/emhttp/webplugins/gpu-switch-manager
mkdir -p /usr/local/emhttp/websettings
mkdir -p /boot/config/plugins/gpu-switch-manager

# 2. Copy files from extracted package
cd /tmp/gpu-switch-manager

# Copy main plugin files
cp -r include/* /usr/local/emhttp/plugins/gpu-switch-manager/include/
cp -r scripts/* /usr/local/emhttp/plugins/gpu-switch-manager/scripts/
cp -r event/* /usr/local/emhttp/plugins/gpu-switch-manager/event/ 2>/dev/null || true
cp -r assets/* /usr/local/emhttp/plugins/gpu-switch-manager/assets/
cp -r assets/* /usr/local/emhttp/webplugins/gpu-switch-manager/assets/ 2>/dev/null || true

# Copy web interface
cp -r web/* /usr/local/emhttp/webplugins/gpu-switch-manager/

# Copy settings page
cp settings/gpu-switch-manager.php /usr/local/emhttp/websettings/

# Copy main plugin file
cp gpu-switch-manager.php /usr/local/emhttp/plugins/gpu-switch-manager/

# Copy configuration files
cp gpu.switch.manager.cfg /boot/config/plugins/gpu-switch-manager/
cp profiles.json /boot/config/plugins/gpu-switch-manager/
cp state.json /boot/config/plugins/gpu-switch-manager/

# 3. Set permissions
chmod -R 755 /usr/local/emhttp/plugins/gpu-switch-manager
chmod -R 755 /usr/local/emhttp/webplugins/gpu-switch-manager
chmod +x /usr/local/emhttp/plugins/gpu-switch-manager/scripts/*.sh
chmod 644 /usr/local/emhttp/websettings/gpu-switch-manager.php

# 4. Verify installation
ls -la /usr/local/emhttp/plugins/gpu-switch-manager/
ls -la /usr/local/emhttp/webplugins/gpu-switch-manager/
ls -la /usr/local/emhttp/websettings/gpu-switch-manager.php
```

## Common Issues and Solutions

### Issue 1: GitHub Release Not Public

**Problem:** Unraid can't download from private repository

**Solution:**
- Make sure GitHub repository is **Public**
- Make sure release is **Published** (not draft)
- Verify the .txz file is attached to the release

### Issue 2: Wrong URL in plugin.plg

**Problem:** URL doesn't match actual release location

**Solution:**
- Check the actual release URL on GitHub
- Update gpu-switch-manager.plg with correct URL
- Recreate package with updated plugin.plg

### Issue 3: MD5 Hash Mismatch

**Problem:** Downloaded file doesn't match expected MD5

**Solution:**
- Verify MD5 of uploaded file matches plugin.plg
- Recalculate MD5: `md5sum gpu-switch-manager-2026.05.05.txz`
- Update plugin.plg with correct MD5

### Issue 4: Network Issues

**Problem:** Unraid can't reach GitHub

**Solution:**
- Check internet connectivity on Unraid server
- Try manual download with wget/curl
- Check firewall settings

### Issue 5: Permissions Issues

**Problem:** Installation script can't create directories

**Solution:**
- Run installation as root
- Check disk space: `df -h`
- Check file system permissions

## Verification Commands

After installation, run these to verify:

```bash
# Check plugin structure
echo "=== Plugin Directory ==="
ls -la /usr/local/emhttp/plugins/gpu-switch-manager/

echo "=== Web Interface ==="
ls -la /usr/local/emhttp/webplugins/gpu-switch-manager/

echo "=== Settings Page ==="
ls -la /usr/local/emhttp/websettings/gpu-switch-manager.php

echo "=== Configuration ==="
ls -la /boot/config/plugins/gpu-switch-manager/

echo "=== Scripts ==="
ls -la /usr/local/emhttp/plugins/gpu-switch-manager/scripts/

echo "=== Include Files ==="
ls -la /usr/local/emhttp/plugins/gpu-switch-manager/include/
```

## Testing Installation

Once installed, test the plugin:

```bash
# Test a script
/usr/local/emhttp/plugins/gpu-switch-manager/scripts/list_gpus.sh

# Check web interface access
# Open browser: http://[server-ip]/gpu-switch-manager/

# Check settings page
# Open browser: http://[server-ip]/settings/gpu-switch-manager
```

## Cleanup

If installation fails and you need to clean up:

```bash
# Remove plugin files
rm -rf /usr/local/emhttp/plugins/gpu-switch-manager
rm -rf /usr/local/emhttp/webplugins/gpu-switch-manager
rm -f /usr/local/emhttp/websettings/gpu-switch-manager.php

# Remove configuration (optional - preserves settings)
# rm -rf /boot/config/plugins/gpu-switch-manager

# Remove downloaded files
rm -rf /tmp/gpu-switch-manager
rm -f /tmp/gpu-switch-manager-2026.05.05.txz
```

## Next Steps

1. **Run diagnostic commands** to see what happened
2. **Try manual installation** using the steps above
3. **Verify installation** with the verification commands
4. **Test functionality** once installed
5. **Report issues** if problems persist

---

**Current Status:** Installation failed - directories don't exist
**Recommended Action:** Manual installation using wget/curl
**Expected MD5:** c32be8dcf8357e95608e663e75657642