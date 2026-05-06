# GitHub Repository Setup Guide

## Step 1: Create GitHub Repository

1. Go to https://github.com/new
2. Repository name: `unraid-gpu-switch-manager`
3. Description: `Automated GPU driver switching for VM passthrough and Docker workloads on Unraid`
4. Make it **Public** (so Unraid can download the plugin)
5. **Don't** initialize with README, .gitignore, or license (we already have these)
6. Click "Create repository"

## Step 2: Push Code to GitHub

Run these commands in your project directory:

```bash
# Add GitHub remote (replace with your GitHub username)
git remote add origin https://github.com/thewolfman56/unraid-gpu-switch-manager.git

# Push to GitHub
git branch -M main
git push -u origin main
```

## Step 3: Create GitHub Release

### Option A: Using GitHub Web Interface

1. Go to your repository on GitHub
2. Click "Releases" → "Create a new release"
3. Tag version: `2026.05.05`
4. Release title: `GPU Switch Manager 2026.05.05`
5. Description:

```
## GPU Switch Manager 2026.05.05

### Features
- Automated VFIO binding/unbinding for GPU passthrough
- Service dependency management for Docker and VMs
- Real-time GPU status dashboard
- Persistent configuration profiles
- Event-driven GPU switching
- Unraid Settings page integration
- Comprehensive security features

### Installation
1. Go to Settings → Plugins in Unraid
2. Click "Install Plugin"
3. Paste: `https://github.com/thewolfman56/unraid-gpu-switch-manager/raw/main/gpu-switch-manager.plg`
4. Click "Install"

### Security
- 100% security test pass rate
- CSRF protection with token rotation
- Rate limiting on all endpoints
- Role-based access control
- Secure error handling

### Documentation
- README.md - Main documentation
- SECURITY-HARDENING-SUMMARY.md - Security features
- UNRAID-INSTALLATION-GUIDE.md - Installation instructions
```

6. **Attach the plugin package:**
   - Click "Attach binaries"
   - Select `archives/gpu-switch-manager-2026.05.05.txz`
   - Upload the file

7. Click "Publish release"

### Option B: Using GitHub CLI (if installed)

```bash
# Install GitHub CLI if not available
# On Windows: winget install GitHub.cli

# Login to GitHub
gh auth login

# Create release
gh release create 2026.05.05 \
  --title "GPU Switch Manager 2026.05.05" \
  --notes "See README.md for installation instructions" \
  archives/gpu-switch-manager-2026.05.05.txz
```

## Step 4: Test Plugin Installation

Once the release is created, test the installation:

1. Go to your Unraid server
2. Navigate to Settings → Plugins
3. Click "Install Plugin"
4. Paste: `https://github.com/thewolfman56/unraid-gpu-switch-manager/raw/main/gpu-switch-manager.plg`
5. Click "Install"

The plugin should download and install automatically!

## Step 5: Verify Installation

After installation, verify:

```bash
# Check plugin files
ls -la /usr/local/emhttp/plugins/gpu-switch-manager/

# Check web interface
ls -la /usr/local/emhttp/webplugins/gpu-switch-manager/

# Check settings page
ls -la /usr/local/emhttp/websettings/gpu-switch-manager.php

# Access the settings page
# Open browser: http://[server-ip]/settings/gpu-switch-manager
```

## Step 6: Update Repository Settings

### Add Topics
Go to repository Settings → Topics and add:
- `unraid`
- `gpu-passthrough`
- `vfio`
- `docker`
- `virtualization`
- `gpu-management`

### Add Description
Update repository description:
```
Automated GPU driver switching for VM passthrough and Docker workloads on Unraid. Toggle GPUs between host/Docker use and VM isolation without manual XML editing.
```

### Add Website
Set repository website to: `https://github.com/thewolfman56/unraid-gpu-switch-manager`

## Troubleshooting

### Push Fails
```bash
# If push fails, try forcing the push
git push -u origin main --force
```

### Release Creation Fails
- Make sure the `.txz` file exists in `archives/` directory
- Verify the file size is around 1.6MB
- Check that you have write permissions

### Plugin Installation Fails
- Verify the release is published (not just draft)
- Check that the `.txz` file is attached to the release
- Ensure the repository is public
- Check the MD5 hash in `gpu-switch-manager.plg` matches the uploaded file

## Next Steps

After successful installation:

1. **Test Functionality**
   - Access Settings page
   - Test GPU switching
   - Verify web interface works

2. **Update Documentation**
   - Add screenshots to README
   - Create troubleshooting guide
   - Add user examples

3. **Community Engagement**
   - Post in Unraid forums
   - Share on Reddit
   - Submit to Unraid Plugin Repository

4. **Future Development**
   - Create issue templates
   - Add contribution guidelines
   - Set up CI/CD for testing

---

**Repository URL:** https://github.com/thewolfman56/unraid-gpu-switch-manager
**Plugin URL:** https://github.com/thewolfman56/unraid-gpu-switch-manager/raw/main/gpu-switch-manager.plg
**Release URL:** https://github.com/thewolfman56/unraid-gpu-switch-manager/releases/tag/2026.05.05