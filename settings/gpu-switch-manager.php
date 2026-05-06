<?php
/**
 * GPU Switch Manager Settings Page
 * Unraid Settings integration
 */

// Prevent direct access
if (!defined('IN_UNRAID')) {
    die('Direct access not permitted');
}

// Get plugin paths
$plugin_path = '/usr/local/emhttp/plugins/gpu-switch-manager';
$web_path = '/usr/local/emhttp/webplugins/gpu-switch-manager';
$config_path = '/boot/config/plugins/gpu-switch-manager';

// Load plugin configuration
$config_file = $config_path . '/gpu.switch.manager.cfg';
$config = [];

if (file_exists($config_file)) {
    $lines = file($config_file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        if (strpos($line, '=') !== false && strpos($line, '#') !== 0) {
            list($key, $value) = explode('=', $line, 2);
            $config[trim($key)] = trim($value);
        }
    }
}

// Get server IP
$server_ip = $_SERVER['SERVER_ADDR'] ?? 'localhost';

// Page title
$page_title = 'GPU Switch Manager Settings';

// Include header
require_once('/usr/local/emhttp/web/include/header.php');

?>

<!-- GPU Switch Manager Settings Page -->
<div class="gpu-switch-manager-settings">
    <div class="panel">
        <div class="panel-header">
            <h2><?php echo $page_title; ?></h2>
            <div class="panel-actions">
                <a href="/" class="button">Back to Main</a>
            </div>
        </div>

        <div class="panel-body">
            <!-- Plugin Status -->
            <div class="status-section">
                <h3>Plugin Status</h3>
                <div class="status-info">
                    <div class="status-item">
                        <span class="label">Version:</span>
                        <span class="value">2026.05.05</span>
                    </div>
                    <div class="status-item">
                        <span class="label">Author:</span>
                        <span class="value">thewolfman56</span>
                    </div>
                    <div class="status-item">
                        <span class="label">Status:</span>
                        <span class="value active">Active</span>
                    </div>
                </div>
            </div>

            <!-- Quick Actions -->
            <div class="actions-section">
                <h3>Quick Actions</h3>
                <div class="action-buttons">
                    <a href="/gpu-switch-manager/" class="button button-primary">
                        <i class="fa fa-desktop"></i> Open Dashboard
                    </a>
                    <a href="/gpu-switch-manager/gpu.php" class="button">
                        <i class="fa fa-microchip"></i> Manage GPUs
                    </a>
                    <a href="/gpu-switch-manager/profiles.php" class="button">
                        <i class="fa fa-list"></i> Manage Profiles
                    </a>
                    <a href="/gpu-switch-manager/config.php" class="button">
                        <i class="fa fa-cog"></i> Configuration
                    </a>
                </div>
            </div>

            <!-- Configuration Overview -->
            <div class="config-section">
                <h3>Current Configuration</h3>
                <div class="config-overview">
                    <div class="config-item">
                        <span class="label">Plugin Enabled:</span>
                        <span class="value <?php echo ($config['ENABLED'] ?? 'false') === 'true' ? 'enabled' : 'disabled'; ?>">
                            <?php echo ($config['ENABLED'] ?? 'false') === 'true' ? 'Yes' : 'No'; ?>
                        </span>
                    </div>
                    <div class="config-item">
                        <span class="label">Debug Mode:</span>
                        <span class="value <?php echo ($config['DEBUG'] ?? 'false') === 'true' ? 'enabled' : 'disabled'; ?>">
                            <?php echo ($config['DEBUG'] ?? 'false') === 'true' ? 'Yes' : 'No'; ?>
                        </span>
                    </div>
                    <div class="config-item">
                        <span class="label">Log Level:</span>
                        <span class="value"><?php echo htmlspecialchars($config['LOG_LEVEL'] ?? 'info'); ?></span>
                    </div>
                    <div class="config-item">
                        <span class="label">Auto Start VM:</span>
                        <span class="value <?php echo ($config['AUTO_START_VM'] ?? 'false') === 'true' ? 'enabled' : 'disabled'; ?>">
                            <?php echo ($config['AUTO_START_VM'] ?? 'false') === 'true' ? 'Yes' : 'No'; ?>
                        </span>
                    </div>
                    <div class="config-item">
                        <span class="label">Protect Primary GPU:</span>
                        <span class="value <?php echo ($config['PROTECT_PRIMARY_GPU'] ?? 'true') === 'true' ? 'enabled' : 'disabled'; ?>">
                            <?php echo ($config['PROTECT_PRIMARY_GPU'] ?? 'true') === 'true' ? 'Yes' : 'No'; ?>
                        </span>
                    </div>
                </div>
            </div>

            <!-- Links -->
            <div class="links-section">
                <h3>Resources</h3>
                <div class="resource-links">
                    <a href="https://github.com/thewolfman56/unraid-gpu-switch-manager" target="_blank">
                        <i class="fa fa-github"></i> GitHub Repository
                    </a>
                    <a href="/gpu-switch-manager/" target="_blank">
                        <i class="fa fa-external-link"></i> Open in New Tab
                    </a>
                </div>
            </div>
        </div>
    </div>
</div>

<style>
.gpu-switch-manager-settings {
    max-width: 1200px;
    margin: 0 auto;
    padding: 20px;
}

.gpu-switch-manager-settings .panel {
    background: white;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    overflow: hidden;
}

.gpu-switch-manager-settings .panel-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 20px;
    background: #007bff;
    color: white;
}

.gpu-switch-manager-settings .panel-header h2 {
    margin: 0;
    font-size: 24px;
}

.gpu-switch-manager-settings .panel-body {
    padding: 20px;
}

.gpu-switch-manager-settings h3 {
    margin-top: 0;
    margin-bottom: 15px;
    color: #333;
    border-bottom: 2px solid #007bff;
    padding-bottom: 10px;
}

.gpu-switch-manager-settings .status-section,
.gpu-switch-manager-settings .actions-section,
.gpu-switch-manager-settings .config-section,
.gpu-switch-manager-settings .links-section {
    margin-bottom: 30px;
}

.gpu-switch-manager-settings .status-info,
.gpu-switch-manager-settings .config-overview {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 15px;
}

.gpu-switch-manager-settings .status-item,
.gpu-switch-manager-settings .config-item {
    display: flex;
    justify-content: space-between;
    padding: 10px;
    background: #f8f9fa;
    border-radius: 4px;
}

.gpu-switch-manager-settings .label {
    font-weight: bold;
    color: #666;
}

.gpu-switch-manager-settings .value {
    color: #333;
}

.gpu-switch-manager-settings .value.active {
    color: #28a745;
    font-weight: bold;
}

.gpu-switch-manager-settings .value.enabled {
    color: #28a745;
}

.gpu-switch-manager-settings .value.disabled {
    color: #dc3545;
}

.gpu-switch-manager-settings .action-buttons {
    display: flex;
    gap: 10px;
    flex-wrap: wrap;
}

.gpu-switch-manager-settings .button {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    padding: 10px 20px;
    background: #6c757d;
    color: white;
    text-decoration: none;
    border-radius: 4px;
    border: none;
    cursor: pointer;
    font-size: 14px;
    transition: background 0.2s;
}

.gpu-switch-manager-settings .button:hover {
    background: #5a6268;
}

.gpu-switch-manager-settings .button-primary {
    background: #007bff;
}

.gpu-switch-manager-settings .button-primary:hover {
    background: #0056b3;
}

.gpu-switch-manager-settings .resource-links {
    display: flex;
    gap: 15px;
    flex-wrap: wrap;
}

.gpu-switch-manager-settings .resource-links a {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    padding: 10px 20px;
    background: #f8f9fa;
    color: #007bff;
    text-decoration: none;
    border-radius: 4px;
    border: 1px solid #dee2e6;
    transition: all 0.2s;
}

.gpu-switch-manager-settings .resource-links a:hover {
    background: #e9ecef;
    border-color: #007bff;
}
</style>

<?php
// Include footer
require_once('/usr/local/emhttp/web/include/footer.php');
?>