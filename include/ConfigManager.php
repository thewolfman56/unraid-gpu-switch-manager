<?php

/**
 * ConfigManager.php
 * Configuration manager for GPU Switch Manager
 * Provides comprehensive configuration management capabilities
 */

class ConfigManager {
    private $configDir;
    private $configFile;
    private $configLock;
    private $logFile;

    /**
     * Constructor
     *
     * @param string $configDir Configuration directory path
     * @param string $logFile Log file path
     */
    public function __construct($configDir = null, $logFile = null) {
        $this->configDir = $configDir ?? dirname(__DIR__) . '/config';
        $this->configFile = $this->configDir . '/config.json';
        $this->configLock = $this->configDir . '/config.lock';
        $this->logFile = $logFile ?? '/var/log/gpu.switch.manager.log';

        // Initialize configuration directory
        $this->initConfig();
    }

    /**
     * Initialize configuration system
     *
     * @return bool Success status
     */
    private function initConfig() {
        // Create configuration directory
        if (!is_dir($this->configDir)) {
            mkdir($this->configDir, 0755, true);
        }

        // Create subdirectories
        $subdirs = ['profiles', 'preferences', 'services', 'templates', 'backups'];
        foreach ($subdirs as $subdir) {
            if (!is_dir($this->configDir . '/' . $subdir)) {
                mkdir($this->configDir . '/' . $subdir, 0755, true);
            }
        }

        // Create default configuration if it doesn't exist
        if (!file_exists($this->configFile)) {
            $defaultConfig = [
                'version' => '1.0.0',
                'profiles' => [
                    'default' => [
                        'name' => 'default',
                        'description' => 'Default GPU switching profile',
                        'gpu_bindings' => [],
                        'service_preferences' => [],
                        'event_handlers' => [],
                        'safety_checks' => [
                            'check_active_usage' => true,
                            'check_dependencies' => true,
                            'check_resources' => true
                        ],
                        'created_at' => gmdate('Y-m-d\TH:i:s\Z'),
                        'updated_at' => gmdate('Y-m-d\TH:i:s\Z')
                    ]
                ],
                'preferences' => [
                    'auto_switch' => true,
                    'auto_backup' => true,
                    'backup_interval' => 86400,
                    'log_level' => 'INFO',
                    'notification_enabled' => true
                ],
                'services' => [
                    'docker' => [
                        'auto_restart' => true,
                        'graceful_shutdown' => true,
                        'timeout' => 30
                    ],
                    'vm' => [
                        'auto_restart' => false,
                        'graceful_shutdown' => true,
                        'timeout' => 60
                    ]
                ]
            ];

            $this->saveConfig($defaultConfig);
            $this->log('INFO', 'Created default configuration');
        }

        return true;
    }

    /**
     * Load configuration from file
     *
     * @param string $configPath Configuration file path
     * @return array Configuration data
     * @throws Exception If configuration file not found or invalid
     */
    public function loadConfig($configPath = null) {
        $configPath = $configPath ?? $this->configFile;

        if (!file_exists($configPath)) {
            throw new Exception("Configuration file not found: $configPath");
        }

        $config = json_decode(file_get_contents($configPath), true);

        if (json_last_error() !== JSON_ERROR_NONE) {
            throw new Exception("Invalid JSON configuration: " . json_last_error_msg());
        }

        return $config;
    }

    /**
     * Save configuration to file
     *
     * @param array $config Configuration data
     * @param string $configPath Configuration file path
     * @return bool Success status
     * @throws Exception If configuration is invalid
     */
    public function saveConfig($config, $configPath = null) {
        $configPath = $configPath ?? $this->configFile;

        // Validate configuration
        if (!is_array($config)) {
            throw new Exception("Configuration must be an array");
        }

        // Create backup before saving
        if (file_exists($configPath)) {
            $backupFile = $this->configDir . '/backups/config_' . date('Ymd_His') . '.json';
            copy($configPath, $backupFile);
            $this->log('INFO', "Created backup: $backupFile");
        }

        // Save configuration
        $json = json_encode($config, JSON_PRETTY_PRINT);
        if ($json === false) {
            throw new Exception("Failed to encode configuration: " . json_last_error_msg());
        }

        file_put_contents($configPath, $json);

        return true;
    }

    /**
     * Get configuration value
     *
     * @param string $key Configuration key (supports dot notation)
     * @param mixed $default Default value if key not found
     * @return mixed Configuration value
     */
    public function getConfigValue($key, $default = null) {
        $config = $this->loadConfig();

        $keys = explode('.', $key);
        $value = $config;

        foreach ($keys as $k) {
            if (!isset($value[$k])) {
                return $default;
            }
            $value = $value[$k];
        }

        return $value;
    }

    /**
     * Set configuration value
     *
     * @param string $key Configuration key (supports dot notation)
     * @param mixed $value Configuration value
     * @return bool Success status
     */
    public function setConfigValue($key, $value) {
        $config = $this->loadConfig();

        $keys = explode('.', $key);
        $current = &$config;

        foreach ($keys as $k) {
            if (!isset($current[$k]) || !is_array($current[$k])) {
                $current[$k] = [];
            }
            $current = &$current[$k];
        }

        $current = $value;

        $this->saveConfig($config);

        return true;
    }

    /**
     * Delete configuration value
     *
     * @param string $key Configuration key (supports dot notation)
     * @return bool Success status
     * @throws Exception If key not found
     */
    public function deleteConfigValue($key) {
        $config = $this->loadConfig();

        $keys = explode('.', $key);
        $current = &$config;

        // Navigate to parent of target key
        for ($i = 0; $i < count($keys) - 1; $i++) {
            if (!isset($current[$keys[$i]])) {
                throw new Exception("Configuration key not found: $key");
            }
            $current = &$current[$keys[$i]];
        }

        $lastKey = $keys[count($keys) - 1];
        if (!isset($current[$lastKey])) {
            throw new Exception("Configuration key not found: $key");
        }

        unset($current[$lastKey]);

        $this->saveConfig($config);

        return true;
    }

    /**
     * Validate configuration
     *
     * @param array $config Configuration to validate
     * @return array Validation result with 'valid' and 'errors' keys
     */
    public function validateConfig($config = null) {
        $config = $config ?? $this->loadConfig();
        $errors = [];

        // Check if valid array
        if (!is_array($config)) {
            $errors[] = "Configuration must be an array";
            return ['valid' => false, 'errors' => $errors];
        }

        // Check required fields
        $requiredFields = ['version', 'profiles', 'preferences', 'services'];
        foreach ($requiredFields as $field) {
            if (!isset($config[$field])) {
                $errors[] = "Missing required field: $field";
            }
        }

        // Check version format
        if (isset($config['version'])) {
            if (!preg_match('/^\d+\.\d+\.\d+$/', $config['version'])) {
                $errors[] = "Invalid version format: {$config['version']}";
            }
        }

        // Check profiles
        if (isset($config['profiles']) && !is_array($config['profiles'])) {
            $errors[] = "Invalid profiles format";
        }

        // Check preferences
        if (isset($config['preferences']) && !is_array($config['preferences'])) {
            $errors[] = "Invalid preferences format";
        }

        // Check services
        if (isset($config['services']) && !is_array($config['services'])) {
            $errors[] = "Invalid services format";
        }

        return [
            'valid' => empty($errors),
            'errors' => $errors,
            'error_count' => count($errors)
        ];
    }

    /**
     * Merge configurations
     *
     * @param array $baseConfig Base configuration
     * @param array $overrideConfig Override configuration
     * @return array Merged configuration
     */
    public function mergeConfig($baseConfig, $overrideConfig) {
        return array_replace_recursive($baseConfig, $overrideConfig);
    }

    /**
     * Backup configuration
     *
     * @param string $configPath Configuration file path
     * @return string Backup file path
     * @throws Exception If configuration file not found
     */
    public function backupConfig($configPath = null) {
        $configPath = $configPath ?? $this->configFile;

        if (!file_exists($configPath)) {
            throw new Exception("Configuration file not found: $configPath");
        }

        $backupFile = $this->configDir . '/backups/config_' . date('Ymd_His') . '.json';
        copy($configPath, $backupFile);

        // Compress backup
        gzcompress(file_get_contents($backupFile), 9);
        $backupFile .= '.gz';

        $this->log('INFO', "Configuration backed up: $backupFile");

        return $backupFile;
    }

    /**
     * Restore configuration from backup
     *
     * @param string $backupPath Backup file path
     * @param string $configPath Configuration file path
     * @return bool Success status
     * @throws Exception If backup file not found or invalid
     */
    public function restoreConfig($backupPath, $configPath = null) {
        $configPath = $configPath ?? $this->configFile;

        if (!file_exists($backupPath)) {
            throw new Exception("Backup file not found: $backupPath");
        }

        // Decompress if needed
        $tempFile = $backupPath . '.tmp';
        if (preg_match('/\.gz$/', $backupPath)) {
            $content = gzuncompress(file_get_contents($backupPath));
            file_put_contents($tempFile, $content);
        } else {
            copy($backupPath, $tempFile);
        }

        // Validate backup
        $config = json_decode(file_get_contents($tempFile), true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            unlink($tempFile);
            throw new Exception("Invalid backup file");
        }

        // Create backup of current configuration
        if (file_exists($configPath)) {
            $this->backupConfig($configPath);
        }

        // Restore configuration
        copy($tempFile, $configPath);
        unlink($tempFile);

        $this->log('INFO', "Configuration restored from: $backupPath");

        return true;
    }

    /**
     * Get configuration version
     *
     * @return string Configuration version
     */
    public function getConfigVersion() {
        $config = $this->loadConfig();
        return $config['version'] ?? '0.0.0';
    }

    /**
     * Log message
     *
     * @param string $level Log level
     * @param string $message Log message
     */
    private function log($level, $message) {
        $timestamp = date('Y-m-d H:i:s');
        $logMessage = "[$timestamp] [$level] [CONFIG_MANAGER] $message\n";

        if (file_exists($this->logFile)) {
            file_put_contents($this->logFile, $logMessage, FILE_APPEND);
        }
    }
}
