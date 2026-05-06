<?php

/**
 * ConfigController.php
 * Configuration management controller for GPU Switch Manager
 * Handles configuration display, editing, validation, and import/export
 */

class ConfigController {
    private $webInterface;
    private $configManager;
    private $configValidator;
    private $configBackup;
    private $securityMiddleware;
    private $secureErrorHandler;
    private $logFile;

    /**
     * Constructor
     *
     * @param WebInterface $webInterface Web interface instance
     * @param SecurityMiddleware $securityMiddleware Security middleware
     * @param SecureErrorHandler $secureErrorHandler Secure error handler
     * @param string $logFile Log file path
     */
    public function __construct($webInterface = null, $securityMiddleware = null, $secureErrorHandler = null, $logFile = null) {
        $this->webInterface = $webInterface ?? new WebInterface();
        $this->securityMiddleware = $securityMiddleware ?? new SecurityMiddleware();
        $this->secureErrorHandler = $secureErrorHandler ?? new SecureErrorHandler($logFile);
        $this->logFile = $logFile ?? '/var/log/gpu.switch.manager.log';

        // Initialize managers
        $this->configManager = new ConfigManager();
        $this->configValidator = new ConfigValidator();
        $this->configBackup = new ConfigBackup();
    }

    /**
     * Configuration main page
     *
     * @return string Rendered page
     */
    public function index() {
        try {
            // Require authentication
            $user = $this->securityMiddleware->process('config', 'read', true);

            $config = $this->getConfiguration();
            $validation = $this->validateConfiguration();

            $data = [
                'title' => 'Configuration Management',
                'config' => $config,
                'validation' => $validation,
                'configSections' => $this->getConfigSections(),
                'user' => $user
            ];

            return $this->webInterface->renderPage('config/index', $data);
        } catch (Exception $e) {
            $this->log('error', 'Failed to load configuration page: ' . $e->getMessage());
            return $this->webInterface->renderError('Failed to load configuration');
        }
    }

    /**
     * Get configuration
     *
     * @return array Configuration data
     */
    public function getConfiguration() {
        try {
            $config = $this->configManager->loadConfig();

            return [
                'success' => true,
                'data' => $config,
                'version' => $this->configManager->getConfigVersion()
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to get configuration: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Update configuration
     *
     * @param array $configData Configuration data to update
     * @return array Update result
     */
    public function updateConfiguration($configData) {
        try {
            // Require authentication and write permission
            $this->securityMiddleware->process('config', 'write', true);

            // Validate CSRF token
            if (!$this->webInterface->validateCSRF()) {
                throw $this->secureErrorHandler->createSecureException('CSRF_INVALID');
            }

            // Validate configuration
            $validation = $this->configValidator->validateSchema($configData);
            if (!$validation['valid']) {
                throw $this->secureErrorHandler->createSecureException('CONFIG_INVALID');
            }

            // Create backup before update
            $backup = $this->configBackup->createBackup('pre-update');

            // Update configuration
            $result = $this->configManager->saveConfig($configData);

            $this->log('info', 'Configuration updated successfully');

            return [
                'success' => true,
                'data' => $result,
                'backup' => $backup
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to update configuration');
            return $this->secureErrorHandler->handleError('CONFIG_SAVE_FAILED', $e, [
                'action' => 'update_configuration'
            ]);
        }
    }

    /**
     * Validate configuration
     *
     * @return array Validation result
     */
    public function validateConfiguration() {
        try {
            $config = $this->configManager->loadConfig();

            $schemaValidation = $this->configValidator->validateSchema($config);
            $referenceValidation = $this->configValidator->validateReferences($config);
            $dependencyValidation = $this->configValidator->validateDependencies($config);
            $conflicts = $this->configValidator->detectConflicts($config);

            $allValid = $schemaValidation['valid'] &&
                        $referenceValidation['valid'] &&
                        $dependencyValidation['valid'] &&
                        empty($conflicts);

            return [
                'valid' => $allValid,
                'schema' => $schemaValidation,
                'references' => $referenceValidation,
                'dependencies' => $dependencyValidation,
                'conflicts' => $conflicts,
                'errors' => array_merge(
                    $schemaValidation['errors'] ?? [],
                    $referenceValidation['errors'] ?? [],
                    $dependencyValidation['errors'] ?? []
                )
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to validate configuration: ' . $e->getMessage());
            return [
                'valid' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Reset configuration
     *
     * @return array Reset result
     */
    public function resetConfiguration() {
        try {
            // Require authentication and write permission
            $this->securityMiddleware->process('config', 'write', true);

            // Validate CSRF token
            if (!$this->webInterface->validateCSRF()) {
                throw $this->secureErrorHandler->createSecureException('CSRF_INVALID');
            }

            // Create backup before reset
            $backup = $this->configBackup->createBackup('pre-reset');

            // Reset to defaults
            $defaultConfig = $this->getDefaultConfiguration();
            $result = $this->configManager->saveConfig($defaultConfig);

            $this->log('info', 'Configuration reset to defaults');

            return [
                'success' => true,
                'data' => $result,
                'backup' => $backup
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to reset configuration');
            return $this->secureErrorHandler->handleError('CONFIG_SAVE_FAILED', $e, [
                'action' => 'reset_configuration'
            ]);
        }
    }

    /**
     * Export configuration
     *
     * @param string $format Export format (json, yaml, xml)
     * @return array Export result
     */
    public function exportConfiguration($format = 'json') {
        try {
            $config = $this->configManager->loadConfig();

            $exported = $this->formatExport($config, $format);

            $this->log('info', "Configuration exported in $format format");

            return [
                'success' => true,
                'data' => $exported,
                'format' => $format,
                'version' => $this->configManager->getConfigVersion()
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to export configuration: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Import configuration
     *
     * @param array $importData Configuration data to import
     * @param bool $merge Merge with existing configuration
     * @return array Import result
     */
    public function importConfiguration($importData, $merge = false) {
        try {
            // Require authentication and write permission
            $this->securityMiddleware->process('config', 'write', true);

            // Validate CSRF token
            if (!$this->webInterface->validateCSRF()) {
                throw $this->secureErrorHandler->createSecureException('CSRF_INVALID');
            }

            // Validate imported configuration
            $validation = $this->configValidator->validateSchema($importData);
            if (!$validation['valid']) {
                throw $this->secureErrorHandler->createSecureException('CONFIG_INVALID');
            }

            // Create backup before import
            $backup = $this->configBackup->createBackup('pre-import');

            if ($merge) {
                // Merge with existing configuration
                $existingConfig = $this->configManager->loadConfig();
                $mergedConfig = $this->configManager->mergeConfig($existingConfig, $importData);
                $result = $this->configManager->saveConfig($mergedConfig);
            } else {
                // Replace existing configuration
                $result = $this->configManager->saveConfig($importData);
            }

            $this->log('info', 'Configuration imported successfully');

            return [
                'success' => true,
                'data' => $result,
                'backup' => $backup,
                'merged' => $merge
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to import configuration');
            return $this->secureErrorHandler->handleError('CONFIG_SAVE_FAILED', $e, [
                'action' => 'import_configuration',
                'merge' => $merge
            ]);
        }
    }

    /**
     * Get configuration sections
     *
     * @return array Configuration sections
     */
    private function getConfigSections() {
        return [
            'general' => [
                'title' => 'General Settings',
                'description' => 'General plugin configuration',
                'fields' => [
                    'plugin_name',
                    'plugin_version',
                    'log_level',
                    'debug_mode'
                ]
            ],
            'gpu' => [
                'title' => 'GPU Settings',
                'description' => 'GPU discovery and binding configuration',
                'fields' => [
                    'gpu_discovery_interval',
                    'auto_bind_enabled',
                    'auto_bind_delay',
                    'vfio_driver'
                ]
            ],
            'switching' => [
                'title' => 'Switching Settings',
                'description' => 'GPU switching behavior configuration',
                'fields' => [
                    'switch_timeout',
                    'switch_retry_count',
                    'switch_retry_delay',
                    'force_switch_enabled'
                ]
            ],
            'services' => [
                'title' => 'Service Settings',
                'description' => 'Service management configuration',
                'fields' => [
                    'docker_auto_stop',
                    'vm_auto_stop',
                    'service_stop_timeout',
                    'service_start_timeout'
                ]
            ],
            'events' => [
                'title' => 'Event Settings',
                'description' => 'Event handling configuration',
                'fields' => [
                    'event_log_enabled',
                    'event_log_retention',
                    'event_notification_enabled',
                    'event_notification_level'
                ]
            ],
            'backup' => [
                'title' => 'Backup Settings',
                'description' => 'Configuration backup configuration',
                'fields' => [
                    'auto_backup_enabled',
                    'backup_retention_count',
                    'backup_schedule',
                    'backup_compression'
                ]
            ]
        ];
    }

    /**
     * Get default configuration
     *
     * @return array Default configuration
     */
    private function getDefaultConfiguration() {
        return [
            'general' => [
                'plugin_name' => 'GPU Switch Manager',
                'plugin_version' => '1.0.0',
                'log_level' => 'info',
                'debug_mode' => false
            ],
            'gpu' => [
                'gpu_discovery_interval' => 60,
                'auto_bind_enabled' => true,
                'auto_bind_delay' => 5,
                'vfio_driver' => 'vfio-pci'
            ],
            'switching' => [
                'switch_timeout' => 30,
                'switch_retry_count' => 3,
                'switch_retry_delay' => 5,
                'force_switch_enabled' => false
            ],
            'services' => [
                'docker_auto_stop' => true,
                'vm_auto_stop' => true,
                'service_stop_timeout' => 60,
                'service_start_timeout' => 120
            ],
            'events' => [
                'event_log_enabled' => true,
                'event_log_retention' => 30,
                'event_notification_enabled' => false,
                'event_notification_level' => 'warning'
            ],
            'backup' => [
                'auto_backup_enabled' => true,
                'backup_retention_count' => 10,
                'backup_schedule' => 'daily',
                'backup_compression' => true
            ]
        ];
    }

    /**
     * Format export data
     *
     * @param array $data Data to format
     * @param string $format Format type
     * @return string Formatted data
     */
    private function formatExport($data, $format) {
        switch ($format) {
            case 'json':
                return json_encode($data, JSON_PRETTY_PRINT);

            case 'yaml':
                if (function_exists('yaml_emit')) {
                    return yaml_emit($data);
                }
                // Fallback to JSON if YAML not available
                return json_encode($data, JSON_PRETTY_PRINT);

            case 'xml':
                $xml = new SimpleXMLElement('<configuration></configuration>');
                $this->arrayToXml($data, $xml);
                return $xml->asXML();

            default:
                return json_encode($data, JSON_PRETTY_PRINT);
        }
    }

    /**
     * Convert array to XML
     *
     * @param array $data Array data
     * @param SimpleXMLElement $xml XML element
     */
    private function arrayToXml($data, &$xml) {
        foreach ($data as $key => $value) {
            if (is_array($value)) {
                if (is_numeric($key)) {
                    $key = 'item' . $key;
                }
                $subnode = $xml->addChild($key);
                $this->arrayToXml($value, $subnode);
            } else {
                $xml->addChild($key, htmlspecialchars($value));
            }
        }
    }

    /**
     * Log message
     *
     * @param string $level Log level
     * @param string $message Log message
     */
    private function log($level, $message) {
        $timestamp = date('Y-m-d H:i:s');
        $logMessage = "[$timestamp] [$level] [CONFIG_CONTROLLER] $message\n";

        if (file_exists($this->logFile)) {
            file_put_contents($this->logFile, $logMessage, FILE_APPEND);
        }
    }
}
