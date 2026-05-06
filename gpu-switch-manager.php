<?php
/**
 * GPU Switch Manager - Unraid Plugin Integration
 * Main plugin file for Unraid Settings integration
 */

// Plugin information
$plugin_name = 'GPU Switch Manager';
$plugin_version = '2026.05.05';
$plugin_author = 'thewolfman56';
$plugin_url = 'https://github.com/thewolfman56/unraid-gpu-switch-manager';

// Get Unraid server IP
$server_ip = $_SERVER['SERVER_ADDR'] ?? 'localhost';

// Plugin paths
$plugin_path = '/usr/local/emhttp/plugins/gpu-switch-manager';
$web_path = '/usr/local/emhttp/webplugins/gpu-switch-manager';
$config_path = '/boot/config/plugins/gpu-switch-manager';

// Check if plugin is properly installed
$plugin_installed = is_dir($plugin_path) && is_dir($web_path);

// Get plugin status
$plugin_status = $plugin_installed ? 'installed' : 'not installed';

// Display plugin information
echo "<div class='gpu-switch-manager-plugin'>";

if ($plugin_installed) {
    // Plugin is installed - show settings link
    echo "<div class='plugin-status installed'>";
    echo "<span class='status-indicator'>●</span> ";
    echo "<span class='status-text'>Installed</span>";
    echo "</div>";

    echo "<div class='plugin-actions'>";
    echo "<a href='/settings/gpu-switch-manager' class='button button-primary'>";
    echo "<i class='fa fa-cog'></i> Open Settings";
    echo "</a>";
    echo "</div>";

    // Show quick stats if available
    $state_file = $config_path . '/state.json';
    if (file_exists($state_file)) {
        $state_data = json_decode(file_get_contents($state_file), true);
        if ($state_data && isset($state_data['active_profile'])) {
            echo "<div class='plugin-info'>";
            echo "<span class='info-label'>Active Profile:</span> ";
            echo "<span class='info-value'>" . htmlspecialchars($state_data['active_profile']) . "</span>";
            echo "</div>";
        }
    }
} else {
    // Plugin is not installed - show installation message
    echo "<div class='plugin-status not-installed'>";
    echo "<span class='status-indicator'>○</span> ";
    echo "<span class='status-text'>Not Installed</span>";
    echo "</div>";

    echo "<div class='plugin-message'>";
    echo "<p>GPU Switch Manager is not properly installed.</p>";
    echo "<p>Please run the installation script or install via the Plugins page.</p>";
    echo "</div>";
}

echo "</div>";

// Add plugin-specific CSS
echo "<style>
.gpu-switch-manager-plugin {
    padding: 15px;
    background: #f5f5f5;
    border-radius: 5px;
    margin: 10px 0;
}

.gpu-switch-manager-plugin .plugin-status {
    display: flex;
    align-items: center;
    margin-bottom: 10px;
    font-weight: bold;
}

.gpu-switch-manager-plugin .status-indicator {
    font-size: 16px;
    margin-right: 8px;
}

.gpu-switch-manager-plugin .installed .status-indicator {
    color: #28a745;
}

.gpu-switch-manager-plugin .not-installed .status-indicator {
    color: #dc3545;
}

.gpu-switch-manager-plugin .plugin-actions {
    margin: 10px 0;
}

.gpu-switch-manager-plugin .button {
    display: inline-block;
    padding: 8px 16px;
    background: #007bff;
    color: white;
    text-decoration: none;
    border-radius: 4px;
    border: none;
    cursor: pointer;
    font-size: 14px;
}

.gpu-switch-manager-plugin .button:hover {
    background: #0056b3;
}

.gpu-switch-manager-plugin .plugin-info {
    margin-top: 10px;
    padding: 8px;
    background: white;
    border-radius: 3px;
    font-size: 13px;
}

.gpu-switch-manager-plugin .info-label {
    font-weight: bold;
    color: #666;
}

.gpu-switch-manager-plugin .info-value {
    color: #333;
}

.gpu-switch-manager-plugin .plugin-message {
    margin-top: 10px;
    padding: 10px;
    background: #fff3cd;
    border: 1px solid #ffc107;
    border-radius: 3px;
    font-size: 13px;
}

.gpu-switch-manager-plugin .plugin-message p {
    margin: 5px 0;
}
</style>";
?>