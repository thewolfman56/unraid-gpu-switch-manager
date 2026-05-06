<?php

/**
 * PreferenceManager.php
 * Preference manager for GPU Switch Manager
 * Provides user preference management capabilities
 */

class PreferenceManager {
    private $preferencesDir;
    private $userPreferencesFile;
    private $systemPreferencesFile;
    private $defaultPreferencesFile;
    private $logFile;

    /**
     * Constructor
     *
     * @param string $preferencesDir Preferences directory path
     * @param string $logFile Log file path
     */
    public function __construct($preferencesDir = null, $logFile = null) {
        $this->preferencesDir = $preferencesDir ?? dirname(__DIR__) . '/config/preferences';
        $this->userPreferencesFile = $this->preferencesDir . '/user.json';
        $this->systemPreferencesFile = $this->preferencesDir . '/system.json';
        $this->defaultPreferencesFile = $this->preferencesDir . '/defaults.json';
        $this->logFile = $logFile ?? '/var/log/gpu.switch.manager.log';

        // Initialize preferences
        $this->initPreferences();
    }

    /**
     * Initialize preferences
     *
     * @return bool Success status
     */
    private function initPreferences() {
        // Create preferences directory
        if (!is_dir($this->preferencesDir)) {
            mkdir($this->preferencesDir, 0755, true);
        }

        // Create default preferences if they don't exist
        if (!file_exists($this->defaultPreferencesFile)) {
            $defaultPreferences = [
                'auto_switch' => true,
                'auto_backup' => true,
                'backup_interval' => 86400,
                'log_level' => 'INFO',
                'notification_enabled' => true,
                'max_backups' => 10,
                'backup_retention_days' => 30,
                'auto_cleanup' => true,
                'debug_mode' => false,
                'verbose_logging' => false
            ];

            file_put_contents($this->defaultPreferencesFile, json_encode($defaultPreferences, JSON_PRETTY_PRINT));
            $this->log('INFO', 'Created default preferences');
        }

        // Create user preferences if they don't exist
        if (!file_exists($this->userPreferencesFile)) {
            file_put_contents($this->userPreferencesFile, json_encode([], JSON_PRETTY_PRINT));
            $this->log('INFO', 'Created user preferences');
        }

        // Create system preferences if they don't exist
        if (!file_exists($this->systemPreferencesFile)) {
            file_put_contents($this->systemPreferencesFile, json_encode([], JSON_PRETTY_PRINT));
            $this->log('INFO', 'Created system preferences');
        }

        return true;
    }

    /**
     * Validate preference key
     *
     * @param string $key Preference key to validate
     * @return bool Valid status
     * @throws Exception If preference key is invalid
     */
    private function validatePreferenceKey($key) {
        if (empty($key)) {
            throw new Exception("Preference key cannot be empty");
        }

        if (!preg_match('/^[a-zA-Z0-9_.-]+$/', $key)) {
            throw new Exception("Invalid preference key: $key (must contain only letters, numbers, underscores, dots, and hyphens)");
        }

        return true;
    }

    /**
     * Load preferences
     *
     * @param string $preferencesFile Preferences file path
     * @return array Preferences data
     * @throws Exception If preferences file not found or invalid
     */
    private function loadPreferences($preferencesFile = null) {
        $preferencesFile = $preferencesFile ?? $this->userPreferencesFile;

        if (!file_exists($preferencesFile)) {
            throw new Exception("Preferences file not found: $preferencesFile");
        }

        $preferences = json_decode(file_get_contents($preferencesFile), true);

        if (json_last_error() !== JSON_ERROR_NONE) {
            throw new Exception("Invalid preferences file: " . json_last_error_msg());
        }

        return $preferences;
    }

    /**
     * Save preferences
     *
     * @param array $preferences Preferences data
     * @param string $preferencesFile Preferences file path
     * @return bool Success status
     * @throws Exception If preferences are invalid
     */
    private function savePreferences($preferences, $preferencesFile = null) {
        $preferencesFile = $preferencesFile ?? $this->userPreferencesFile;

        if (!is_array($preferences)) {
            throw new Exception("Preferences must be an array");
        }

        file_put_contents($preferencesFile, json_encode($preferences, JSON_PRETTY_PRINT));

        return true;
    }

    /**
     * Set preference
     *
     * @param string $key Preference key
     * @param mixed $value Preference value
     * @param string $preferencesFile Preferences file path
     * @return bool Success status
     */
    public function setPreference($key, $value, $preferencesFile = null) {
        $this->validatePreferenceKey($key);

        $preferences = $this->loadPreferences($preferencesFile);
        $preferences[$key] = $value;

        $this->savePreferences($preferences, $preferencesFile);

        $this->log('INFO', "Set preference: $key");

        return true;
    }

    /**
     * Get preference
     *
     * @param string $key Preference key
     * @param string $preferencesFile Preferences file path
     * @return mixed Preference value
     * @throws Exception If preference not found
     */
    public function getPreference($key, $preferencesFile = null) {
        $this->validatePreferenceKey($key);

        $preferences = $this->loadPreferences($preferencesFile);
        $value = $preferences[$key] ?? null;

        // Check if value exists in user preferences
        if ($value === null && $preferencesFile === null) {
            // Try default preferences
            if (file_exists($this->defaultPreferencesFile)) {
                $defaultPreferences = json_decode(file_get_contents($this->defaultPreferencesFile), true);
                $value = $defaultPreferences[$key] ?? null;
            }
        }

        if ($value === null) {
            throw new Exception("Preference not found: $key");
        }

        return $value;
    }

    /**
     * Delete preference
     *
     * @param string $key Preference key
     * @param string $preferencesFile Preferences file path
     * @return bool Success status
     * @throws Exception If preference not found
     */
    public function deletePreference($key, $preferencesFile = null) {
        $this->validatePreferenceKey($key);

        $preferences = $this->loadPreferences($preferencesFile);

        if (!isset($preferences[$key])) {
            throw new Exception("Preference not found: $key");
        }

        unset($preferences[$key]);

        $this->savePreferences($preferences, $preferencesFile);

        $this->log('INFO', "Deleted preference: $key");

        return true;
    }

    /**
     * List all preferences
     *
     * @param string $preferencesFile Preferences file path
     * @return array Preferences data
     */
    public function listPreferences($preferencesFile = null) {
        return $this->loadPreferences($preferencesFile);
    }

    /**
     * Reset preference to default
     *
     * @param string $key Preference key
     * @param string $preferencesFile Preferences file path
     * @return bool Success status
     * @throws Exception If default preference not found
     */
    public function resetPreference($key, $preferencesFile = null) {
        $this->validatePreferenceKey($key);

        if (!file_exists($this->defaultPreferencesFile)) {
            throw new Exception("Default preferences file not found");
        }

        $defaultPreferences = json_decode(file_get_contents($this->defaultPreferencesFile), true);
        $defaultValue = $defaultPreferences[$key] ?? null;

        if ($defaultValue === null) {
            throw new Exception("Default preference not found: $key");
        }

        $this->setPreference($key, $defaultValue, $preferencesFile);

        $this->log('INFO', "Reset preference to default: $key");

        return true;
    }

    /**
     * Reset all preferences
     *
     * @param string $preferencesFile Preferences file path
     * @return bool Success status
     */
    public function resetAllPreferences($preferencesFile = null) {
        if (!file_exists($this->defaultPreferencesFile)) {
            throw new Exception("Default preferences file not found");
        }

        // Copy default preferences
        copy($this->defaultPreferencesFile, $preferencesFile ?? $this->userPreferencesFile);

        $this->log('INFO', 'Reset all preferences to defaults');

        return true;
    }

    /**
     * Validate preference
     *
     * @param string $key Preference key
     * @param mixed $value Preference value
     * @return array Validation result with 'valid' and 'errors' keys
     */
    public function validatePreference($key, $value) {
        $errors = [];

        // Check if value is valid JSON
        if (!is_scalar($value) && !is_array($value) && !is_null($value)) {
            $errors[] = "Invalid value type";
        }

        // Check specific preference types
        switch ($key) {
            case 'auto_switch':
            case 'auto_backup':
            case 'notification_enabled':
            case 'auto_cleanup':
            case 'debug_mode':
            case 'verbose_logging':
                if (!is_bool($value)) {
                    $errors[] = "Value must be boolean";
                }
                break;

            case 'backup_interval':
            case 'max_backups':
            case 'backup_retention_days':
                if (!is_int($value) && !is_float($value)) {
                    $errors[] = "Value must be number";
                }
                break;

            case 'log_level':
                if (!is_string($value)) {
                    $errors[] = "Value must be string";
                } else {
                    $validLevels = ['DEBUG', 'INFO', 'WARN', 'ERROR'];
                    if (!in_array($value, $validLevels)) {
                        $errors[] = "Invalid log level";
                    }
                }
                break;
        }

        return [
            'valid' => empty($errors),
            'key' => $key,
            'errors' => $errors,
            'error_count' => count($errors)
        ];
    }

    /**
     * Get default preference
     *
     * @param string $key Preference key
     * @return mixed Default preference value
     * @throws Exception If default preference not found
     */
    public function getDefaultPreference($key) {
        $this->validatePreferenceKey($key);

        if (!file_exists($this->defaultPreferencesFile)) {
            throw new Exception("Default preferences file not found");
        }

        $defaultPreferences = json_decode(file_get_contents($this->defaultPreferencesFile), true);
        $value = $defaultPreferences[$key] ?? null;

        if ($value === null) {
            throw new Exception("Default preference not found: $key");
        }

        return $value;
    }

    /**
     * Merge preferences
     *
     * @param array $basePreferences Base preferences
     * @param array $overridePreferences Override preferences
     * @param string $preferencesFile Preferences file path
     * @return bool Success status
     */
    public function mergePreferences($basePreferences, $overridePreferences, $preferencesFile = null) {
        if (!is_array($basePreferences) || !is_array($overridePreferences)) {
            throw new Exception("Preferences must be arrays");
        }

        $mergedPreferences = array_merge($basePreferences, $overridePreferences);

        $this->savePreferences($mergedPreferences, $preferencesFile);

        $this->log('INFO', 'Merged preferences');

        return true;
    }

    /**
     * Export preferences
     *
     * @param string $preferencesFile Preferences file path
     * @return array Preferences data
     */
    public function exportPreferences($preferencesFile = null) {
        return $this->loadPreferences($preferencesFile);
    }

    /**
     * Log message
     *
     * @param string $level Log level
     * @param string $message Log message
     */
    private function log($level, $message) {
        $timestamp = date('Y-m-d H:i:s');
        $logMessage = "[$timestamp] [$level] [PREFERENCE_MANAGER] $message\n";

        if (file_exists($this->logFile)) {
            file_put_contents($this->logFile, $logMessage, FILE_APPEND);
        }
    }
}
