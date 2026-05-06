# GPU Switch Manager for Unraid

Automated GPU driver switching for VM passthrough and Docker workloads.

## Overview

GPU Switch Manager provides a centralized interface to toggle GPU drivers and assignments on Unraid. It automates the process of binding/unbinding GPUs to vfio-pci for VM passthrough or ensuring they are available for Docker-based AI and transcoding workflows.

## Features

- **Automated VFIO Binding**: Toggle GPUs between host/Docker use and VM isolation without manual XML editing
- **Service Dependency Management**: Automatically stop/start affected Docker containers and VMs during driver handovers
- **Web Interface**: Configure GPU containers, CPU replacement containers, and ignored containers
- **Real-time Status Dashboard**: Display current GPU utilization, temperature, and driver assignment
- **Persistent Configuration**: Save preferred profiles that persist across system reboots
- **Event-Driven Operation**: Automatic GPU switching when starting/stopping VMs

## Installation

### Method 1: Unraid Plugins Tab (Requires GitHub)

**Note:** This method requires the plugin to be hosted on GitHub. See "Building from Source" section below.

1. Go to Settings → Plugins in Unraid web interface
2. Click "Install Plugin"
3. Paste the plugin URL: `https://github.com/thewolfman56/unraid-gpu-switch-manager/raw/main/gpu-switch-manager.plg`
4. Click "Install"

### Method 2: Manual Installation (Recommended for Testing)

1. Download the plugin package: `gpu-switch-manager-1.0.0.txz`
2. Upload to your Unraid server via SCP:
   ```bash
   scp gpu-switch-manager-1.0.0.txz root@[server-ip]:/tmp/
   ```
3. SSH into your Unraid server:
   ```bash
   ssh root@[server-ip]
   ```
4. Extract and install:
   ```bash
   cd /tmp
   tar -xzf gpu-switch-manager-1.0.0.txz
   cd gpu-switch-manager
   chmod +x install.sh
   ./install.sh
   ```

### Method 3: Direct File Copy

1. Download the complete source code from GitHub
2. Copy all files to your Unraid server:
   ```bash
   scp -r * root@[server-ip]:/tmp/gpu-switch-manager/
   ```
3. SSH into your Unraid server and run:
   ```bash
   ssh root@[server-ip]
   cd /tmp/gpu-switch-manager
   chmod +x install.sh
   ./install.sh
   ```

## Configuration

### Initial Setup

1. Navigate to Settings → GPU Switch Manager
   - Or access directly: `http://[server-ip]/settings/gpu-switch-manager`
2. Click "Open Dashboard" to access the main interface
3. Click "Scan for GPUs" to detect available GPUs
4. Create profiles for each GPU you want to manage
5. Configure Docker containers and VMs for each profile

### Profile Configuration

Each GPU profile includes:
- **GPU Identification**: PCI address, model, vendor
- **VM Assignment**: Which VM uses this GPU
- **Docker Containers**: GPU containers to stop/start
- **CPU Replacements**: CPU-only containers to run when GPU is unavailable
- **Ignored Containers**: Containers not affected by GPU switching

### Safety Settings

- **Protect Primary GPU**: Prevents switching the primary display GPU
- **Require Confirmation**: Prompts before critical operations
- **Backup Configuration**: Automatically backs up configuration changes

## Usage

### Starting a VM with GPU Passthrough

1. Ensure VM is configured with GPU profile
2. Start the VM normally
3. Plugin automatically:
   - Saves running Docker container states
   - Stops GPU containers
   - Starts CPU replacement containers (if configured)
   - Binds GPU to vfio-pci
   - Verifies binding success
   - Starts the VM

### Stopping a VM

1. Stop the VM normally
2. Plugin automatically:
   - Unbinds GPU from vfio-pci
   - Verifies GPU release
   - Stops CPU replacement containers
   - Restores GPU containers
   - Restores container states

### Manual GPU Switching

You can manually switch GPU binding via:
- Web Interface: Settings → GPU Switch Manager → Open Dashboard → Manual Control
- Command Line: `/usr/local/emhttp/plugins/gpu-switch-manager/scripts/bind_gpu_to_vfio.sh [pci-address]`
- Settings Page: `http://[server-ip]/settings/gpu-switch-manager`

## Dashboard Widget

The plugin adds a widget to the Unraid dashboard showing:
- Real-time GPU utilization
- Temperature readings
- Current driver assignment
- Active profile status
- Quick actions for common operations

## Settings Integration

The plugin integrates with Unraid's Settings page:

- **Icon**: Appears in User Utilities section of Settings
- **Settings Page**: `http://[server-ip]/settings/gpu-switch-manager`
- **Quick Access**: Direct links to main interface sections
- **Status Display**: Shows plugin installation status and configuration

### Settings Page Features

- Plugin status and version information
- Quick action buttons for common tasks
- Configuration overview
- Links to documentation and support

## Troubleshooting

### GPU Not Detected

- Check that GPU is properly seated and recognized by Unraid
- Verify `lspci` shows the GPU device
- Check that appropriate drivers are installed

### VFIO Binding Fails

- Ensure GPU is not in use by any process
- Check that no VMs are using the GPU
- Verify `/etc/modprobe.d/vfio.conf` is writable
- Check system logs: `/var/log/gpu.switch.manager.log`

### Docker Container Issues

- Verify container names match profile configuration
- Check that containers are properly labeled
- Ensure Docker service is running
- Review container logs for specific errors

### VM Start Failures

- Check VM XML configuration for GPU assignment
- Verify GPU is properly bound to vfio-pci
- Check that GPU audio function is also bound (if applicable)
- Review libvirt logs: `/var/log/libvirt/qemu/`

## Advanced Configuration

### Custom Timeout Settings

Edit `/boot/config/plugins/gpu-switch-manager/gpu.switch.manager.cfg`:

```ini
TIMEOUT_SECONDS=60
VERIFY_BINDING=true
```

### Debug Mode

Enable debug logging:

```ini
DEBUG=true
LOG_LEVEL=debug
```

### Manual VFIO Configuration

For advanced users, you can manually edit `/etc/modprobe.d/vfio.conf`:

```bash
options vfio-pci ids=10de:2204,10de:2205
```

## File Locations

- **Plugin Files**: `/usr/local/emhttp/plugins/gpu-switch-manager/`
- **Web Interface**: `/usr/local/emhttp/webplugins/gpu-switch-manager/`
- **Settings Page**: `/usr/local/emhttp/websettings/gpu-switch-manager.php`
- **Configuration**: `/boot/config/plugins/gpu-switch-manager/`
- **Logs**: `/var/log/gpu.switch.manager.log`
- **State**: `/boot/config/plugins/gpu-switch-manager/state.json`

## System Requirements

- Unraid 6.12.0 or higher
- Compatible GPU (NVIDIA, AMD, or Intel)
- Sufficient system resources for concurrent operations
- Docker and VM services enabled (if using those features)

## Security Considerations

- Plugin runs as root - ensure system is properly secured
- Validate all user inputs before processing
- Keep plugin updated for security patches
- Review configuration changes before applying
- Monitor logs for suspicious activity

## Performance Impact

- Minimal overhead during normal operation
- Brief pause during GPU switching (typically 5-30 seconds)
- Dashboard widget refreshes every 5 seconds (configurable)
- Logging enabled by default (can be disabled)

## Compatibility

### GPU Support

- **NVIDIA**: Most modern NVIDIA GPUs (GeForce, Quadro, Tesla)
- **AMD**: Most modern AMD GPUs (Radeon, Instinct)
- **Intel**: Intel integrated graphics and discrete GPUs

### Unraid Versions

- **Tested**: Unraid 6.12.0, 6.12.1, 6.12.2
- **Compatible**: Unraid 6.12.x and 7.x
- **Legacy**: May work with older versions but not officially supported

## Development

### Building from Source

```bash
# Clone repository
git clone https://github.com/thewolfman56/unraid-gpu-switch-manager.git
cd unraid-gpu-switch-manager

# Create package
tar -czf gpu-switch-manager-1.0.0.txz plugin.plg install.sh remove.sh gpu-switch-manager.php assets/ include/ scripts/ web/ settings/ event/ javascript/ styles/ templates/ gpu.switch.manager.cfg profiles.json state.json README.md SECURITY-HARDENING-SUMMARY.md SECURITY-TEST-REPORT.md

# Calculate MD5
md5sum gpu-switch-manager-1.0.0.txz
```

### Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## Support

- **Issues**: https://github.com/thewolfman56/unraid-gpu-switch-manager/issues
- **Forums**: https://forums.unraid.net/
- **Documentation**: https://github.com/thewolfman56/unraid-gpu-switch-manager/wiki

## License

This plugin is provided as-is for use with Unraid systems. Please refer to the individual license files for specific components.

## Changelog

### Version 1.0.0
- Initial release
- Complete plugin foundation with all phases (0-6)
- Unraid Settings page integration
- Web interface with GPU management
- Profile management system
- Event-driven GPU switching
- Docker and VM service coordination
- Security hardening (100% test pass rate)
- Comprehensive documentation

### Security Features
- Authentication with secure password hashing
- Role-based access control (admin, user, readonly)
- CSRF protection with token rotation
- Rate limiting on all endpoints
- Input validation and sanitization
- Path traversal prevention
- Secure file operations
- Security headers (CSP, X-Frame-Options, HSTS)
- Secure error handling with role-based messages
- Password strength validation and history tracking

## Credits

Developed for the Unraid community to simplify GPU passthrough workflows.

## Disclaimer

This plugin modifies system-level GPU bindings. Use at your own risk. Always backup your configuration before making changes. The authors are not responsible for data loss or system instability.