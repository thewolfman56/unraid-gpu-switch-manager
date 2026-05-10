<?php

/**
 * PreferencesController.php
 * Preference management controller for GPU Switch Manager
 * Handles user preferences, settings, and defaults
 */

class PreferencesController {
    private $webInterface;
    private $preferenceManager;
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

        // Initialize preference manager
        $this->preferenceManager = new PreferenceManager();
    }

    /**
     * Preferences main page
     *
     * @return string Rendered page
     */
    public function index() {
        try {
            // Require authentication
            $user = $this->securityMiddleware->process('preferences', 'read', true);

            $preferences = $this->getPreferences();
            $defaultPreferences = $this->getDefaultPreferences();

            $data = [
                'title' => 'Preference Management',
                'preferences' => $preferences,
                'defaultPreferences' => $defaultPreferences,
                'preferenceCount' => count($preferences['data'] ?? []),
                'user' => $user
            ];

            return $this->webInterface->renderPage('preferences/index', $data);
        } catch (Exception $e) {
            $this->log('error', 'Failed to load preferences page: ' . $e->getMessage());
            return $this->webInterface->renderError('Failed to load preference information');
        }
    }

    /**
     * Get preferences
     *
     * @return array Preferences
     */
    public function getPreferences() {
        try {
            $preferences = $this->preferenceManager->listPreferences();

            return [
                'success' => true,
                'data' => $preferences,
                'count' => count($preferences)
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to get preferences: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Get preference
     *
     * @param string $key Preference key
     * @return array Preference value
     */
    public function getPreference($key) {
        try {
            // Validate preference key
            if (empty($key)) {
                throw new Exception('Preference key is required');
            }

            $value = $this->preferenceManager->getPreference($key);

            return [
                'success' => true,
                'data' => [
                    'key' => $key,
                    'value' => $value
                ]
            ];
        } catch (Exception $e) {
            $this->log('error', "Failed to get preference $key: " . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Update preference
     *
     * @param string $key Preference key
     * @param mixed $value Preference value
     * @return array Update result
     */
    public function updatePreference($key, $value) {
        try {
            // Validate CSRF token
            if (!$this->webInterface->validateCSRF()) {
                throw new Exception('Invalid CSRF token');
            }

            // Validate preference key
            if (empty($key)) {
                throw new Exception('Preference key is required');
            }

            // Validate preference key format
            if (!preg_match('/^[a-zA-Z0-9_.-]+$/', $key)) {
                throw new Exception('Preference key must contain only alphanumeric characters, dots, hyphens, and underscores');
            }

            // Set preference
            $result = $this->preferenceManager->setPreference($key, $value);

            $this->log('info', "Preference $key updated successfully");

            return [
                'success' => true,
                'data' => $result,
                'message' => 'Preference updated successfully'
            ];
        } catch (Exception $e) {
            $this->log('error', "Failed to update preference $key: " . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Delete preference
     *
     * @param string $key Preference key
     * @return array Delete result
     */
    public function deletePreference($key) {
        try {
            // Validate CSRF token
            if (!$this->webInterface->validateCSRF()) {
                throw new Exception('Invalid CSRF token');
            }

            // Validate preference key
            if (empty($key)) {
                throw new Exception('Preference key is required');
            }

            // Delete preference
            $result = $this->preferenceManager->deletePreference($key);

            $this->log('info', "Preference $key deleted successfully");

            return [
                'success' => true,
                'data' => $result,
                'message' => 'Preference deleted successfully'
            ];
        } catch (Exception $e) {
            $this->log('error', "Failed to delete preference $key: " . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Reset preference
     *
     * @param string $key Preference key
     * @return array Reset result
     */
    public function resetPreference($key) {
        try {
            // Validate CSRF token
            if (!$this->webInterface->validateCSRF()) {
                throw new Exception('Invalid CSRF token');
            }

            // Validate preference key
            if (empty($key)) {
                throw new Exception('Preference key is required');
            }

            // Reset preference to default
            $result = $this->preferenceManager->resetPreference($key);

            $this->log('info', "Preference $key reset to default successfully");

            return [
                'success' => true,
                'data' => $result,
                'message' => 'Preference reset to default successfully'
            ];
        } catch (Exception $e) {
            $this->log('error', "Failed to reset preference $key: " . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Reset all preferences
     *
     * @return array Reset result
     */
    public function resetAllPreferences() {
        try {
            // Validate CSRF token
            if (!$this->webInterface->validateCSRF()) {
                throw new Exception('Invalid CSRF token');
            }

            // Reset all preferences
            $result = $this->preferenceManager->resetAllPreferences();

            $this->log('info', 'All preferences reset to defaults successfully');

            return [
                'success' => true,
                'data' => $result,
                'message' => 'All preferences reset to defaults successfully'
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to reset all preferences: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Get default preferences
     *
     * @return array Default preferences
     */
    public function getDefaultPreferences() {
        try {
            $defaults = $this->preferenceManager->getDefaultPreferences();

            return [
                'success' => true,
                'data' => $defaults
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to get default preferences: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Get preference categories
     *
     * @return array Preference categories
     */
    public function getPreferenceCategories() {
        try {
            $categories = [
                'ui' => [
                    'title' => 'User Interface',
                    'description' => 'UI appearance and behavior settings',
                    'preferences' => [
                        'theme',
                        'language',
                        'timezone',
                        'date_format',
                        'time_format'
                    ]
                ],
                'notifications' => [
                    'title' => 'Notifications',
                    'description' => 'Notification settings and preferences',
                    'preferences' => [
                        'notification_enabled',
                        'notification_level',
                        'notification_sound',
                        'notification_desktop'
                    ]
                ],
                'gpu' => [
                    'title' => 'GPU Settings',
                    'description' => 'GPU-related preferences',
                    'preferences' => [
                        'default_gpu_mode',
                        'gpu_auto_switch',
                        'gpu_switch_timeout'
                    ]
                ],
                'services' => [
                    'title' => 'Service Settings',
                    'description' => 'Service management preferences',
                    'preferences' => [
                        'docker_auto_stop',
                        'vm_auto_stop',
                        'service_stop_timeout'
                    ]
                ],
                'logging' => [
                    'title' => 'Logging',
                    'description' => 'Logging and debugging preferences',
                    'preferences' => [
                        'log_level',
                        'log_retention',
                        'debug_mode'
                    ]
                ],
                'backup' => [
                    'title' => 'Backup',
                    'description' => 'Backup and restore preferences',
                    'preferences' => [
                        'auto_backup_enabled',
                        'backup_retention_count',
                        'backup_schedule'
                    ]
                ]
            ];

            return [
                'success' => true,
                'data' => $categories
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to get preference categories: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Export preferences
     *
     * @param string $format Export format (json, yaml)
     * @return array Export result
     */
    public function exportPreferences($format = 'json') {
        try {
            $preferences = $this->preferenceManager->listPreferences();

            $exported = $this->formatExport($preferences, $format);

            $this->log('info', "Preferences exported in $format format");

            return [
                'success' => true,
                'data' => $exported,
                'format' => $format,
                'count' => count($preferences)
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to export preferences: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Import preferences
     *
     * @param array $preferences Preferences to import
     * @param bool $merge Merge with existing preferences
     * @return array Import result
     */
    public function importPreferences($preferences, $merge = true) {
        try {
            // Validate CSRF token
            if (!$this->webInterface->validateCSRF()) {
                throw new Exception('Invalid CSRF token');
            }

            if ($merge) {
                // Merge with existing preferences
                $existingPreferences = $this->preferenceManager->listPreferences();
                $mergedPreferences = $this->preferenceManager->mergePreferences($existingPreferences, $preferences);

                foreach ($mergedPreferences as $key => $value) {
                    $this->preferenceManager->setPreference($key, $value);
                }
            } else {
                // Replace existing preferences
                foreach ($preferences as $key => $value) {
                    $this->preferenceManager->setPreference($key, $value);
                }
            }

            $this->log('info', 'Preferences imported successfully');

            return [
                'success' => true,
                'message' => 'Preferences imported successfully',
                'merged' => $merge
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to import preferences: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Validate preference
     *
     * @param string $key Preference key
     * @param mixed $value Preference value
     * @return array Validation result
     */
    public function validatePreference($key, $value) {
        try {
            $validation = $this->preferenceManager->validatePreference($key, $value);

            return [
                'success' => true,
                'data' => $validation
            ];
        } catch (Exception $e) {
            $this->log('error', "Failed to validate preference $key: " . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
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

            default:
                return json_encode($data, JSON_PRETTY_PRINT);
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
        $logMessage = "[$timestamp] [$level] [PREFERENCES_CONTROLLER] $message\n";

        if (file_exists($this->logFile)) {
            file_put_contents($this->logFile, $logMessage, FILE_APPEND);
        }
    }
}
