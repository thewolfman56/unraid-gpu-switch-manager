<?php

/**
 * ProfileManager.php
 * Profile manager for GPU Switch Manager
 * Provides profile management capabilities
 */

class ProfileManager {
    private $profilesDir;
    private $configFile;
    private $logFile;

    /**
     * Constructor
     *
     * @param string $profilesDir Profiles directory path
     * @param string $configFile Configuration file path
     * @param string $logFile Log file path
     */
    public function __construct($profilesDir = null, $configFile = null, $logFile = null) {
        $this->profilesDir = $profilesDir ?? dirname(__DIR__) . '/config/profiles';
        $this->configFile = $configFile ?? dirname(__DIR__) . '/config/config.json';
        $this->logFile = $logFile ?? '/var/log/gpu.switch.manager.log';

        // Initialize profiles directory
        $this->initProfiles();
    }

    /**
     * Initialize profiles directory
     *
     * @return bool Success status
     */
    private function initProfiles() {
        if (!is_dir($this->profilesDir)) {
            mkdir($this->profilesDir, 0755, true);
        }

        return true;
    }

    /**
     * Validate profile name
     *
     * @param string $profileName Profile name to validate
     * @return bool Valid status
     * @throws Exception If profile name is invalid
     */
    private function validateProfileName($profileName) {
        if (empty($profileName)) {
            throw new Exception("Profile name cannot be empty");
        }

        if (!preg_match('/^[a-zA-Z0-9_-]+$/', $profileName)) {
            throw new Exception("Invalid profile name: $profileName (must contain only letters, numbers, underscores, and hyphens)");
        }

        return true;
    }

    /**
     * Create profile
     *
     * @param string $name Profile name
     * @param array $config Profile configuration
     * @return bool Success status
     * @throws Exception If profile already exists or invalid
     */
    public function createProfile($name, $config = []) {
        $this->validateProfileName($name);

        $profileFile = $this->profilesDir . '/' . $name . '.json';

        if (file_exists($profileFile)) {
            throw new Exception("Profile already exists: $name");
        }

        $timestamp = gmdate('Y-m-d\TH:i:s\Z');

        $profile = [
            'name' => $name,
            'description' => $config['description'] ?? '',
            'gpu_bindings' => $config['gpu_bindings'] ?? [],
            'service_preferences' => $config['service_preferences'] ?? [],
            'event_handlers' => $config['event_handlers'] ?? [],
            'safety_checks' => [
                'check_active_usage' => true,
                'check_dependencies' => true,
                'check_resources' => true
            ],
            'created_at' => $timestamp,
            'updated_at' => $timestamp
        ];

        // Merge with provided config
        $profile = array_merge($profile, $config);

        // Save profile
        file_put_contents($profileFile, json_encode($profile, JSON_PRETTY_PRINT));

        $this->log('INFO', "Created profile: $name");

        return true;
    }

    /**
     * Read profile
     *
     * @param string $name Profile name
     * @return array Profile data
     * @throws Exception If profile not found
     */
    public function readProfile($name) {
        $this->validateProfileName($name);

        $profileFile = $this->profilesDir . '/' . $name . '.json';

        if (!file_exists($profileFile)) {
            throw new Exception("Profile not found: $name");
        }

        $profile = json_decode(file_get_contents($profileFile), true);

        if (json_last_error() !== JSON_ERROR_NONE) {
            throw new Exception("Invalid profile file: " . json_last_error_msg());
        }

        return $profile;
    }

    /**
     * Update profile
     *
     * @param string $name Profile name
     * @param array $config Profile configuration
     * @return bool Success status
     * @throws Exception If profile not found or invalid
     */
    public function updateProfile($name, $config) {
        $this->validateProfileName($name);

        $profileFile = $this->profilesDir . '/' . $name . '.json';

        if (!file_exists($profileFile)) {
            throw new Exception("Profile not found: $name");
        }

        // Load existing profile
        $existingProfile = $this->readProfile($name);

        // Update profile
        $updatedProfile = array_merge($existingProfile, $config);
        $updatedProfile['updated_at'] = gmdate('Y-m-d\TH:i:s\Z');

        // Save profile
        file_put_contents($profileFile, json_encode($updatedProfile, JSON_PRETTY_PRINT));

        $this->log('INFO', "Updated profile: $name");

        return true;
    }

    /**
     * Delete profile
     *
     * @param string $name Profile name
     * @return bool Success status
     * @throws Exception If profile not found or active
     */
    public function deleteProfile($name) {
        $this->validateProfileName($name);

        $profileFile = $this->profilesDir . '/' . $name . '.json';

        if (!file_exists($profileFile)) {
            throw new Exception("Profile not found: $name");
        }

        // Check if profile is active
        $activeProfile = $this->getActiveProfile();
        if ($activeProfile === $name) {
            throw new Exception("Cannot delete active profile: $name");
        }

        // Delete profile
        unlink($profileFile);

        $this->log('INFO', "Deleted profile: $name");

        return true;
    }

    /**
     * List all profiles
     *
     * @return array List of profiles
     */
    public function listProfiles() {
        $profiles = [];

        foreach (glob($this->profilesDir . '/*.json') as $profileFile) {
            $profile = json_decode(file_get_contents($profileFile), true);
            if ($profile) {
                $profiles[] = [
                    'name' => $profile['name'],
                    'description' => $profile['description'] ?? ''
                ];
            }
        }

        return $profiles;
    }

    /**
     * Activate profile
     *
     * @param string $name Profile name
     * @return bool Success status
     * @throws Exception If profile not found or invalid
     */
    public function activateProfile($name) {
        $this->validateProfileName($name);

        $profileFile = $this->profilesDir . '/' . $name . '.json';

        if (!file_exists($profileFile)) {
            throw new Exception("Profile not found: $name");
        }

        // Load profile
        $profile = $this->readProfile($name);

        // Validate profile
        $validation = $this->validateProfile($name);
        if (!$validation['valid']) {
            throw new Exception("Invalid profile: " . implode(', ', $validation['errors']));
        }

        // Set active profile in main config
        if (file_exists($this->configFile)) {
            $config = json_decode(file_get_contents($this->configFile), true);
            $config['active_profile'] = $name;
            file_put_contents($this->configFile, json_encode($config, JSON_PRETTY_PRINT));
        }

        $this->log('INFO', "Activated profile: $name");

        return true;
    }

    /**
     * Deactivate profile
     *
     * @return bool Success status
     */
    public function deactivateProfile() {
        if (file_exists($this->configFile)) {
            $config = json_decode(file_get_contents($this->configFile), true);
            unset($config['active_profile']);
            file_put_contents($this->configFile, json_encode($config, JSON_PRETTY_PRINT));
        }

        $this->log('INFO', "Deactivated profile");

        return true;
    }

    /**
     * Clone profile
     *
     * @param string $sourceProfile Source profile name
     * @param string $targetProfile Target profile name
     * @return bool Success status
     * @throws Exception If source profile not found or target exists
     */
    public function cloneProfile($sourceProfile, $targetProfile) {
        $this->validateProfileName($sourceProfile);
        $this->validateProfileName($targetProfile);

        $sourceFile = $this->profilesDir . '/' . $sourceProfile . '.json';
        $targetFile = $this->profilesDir . '/' . $targetProfile . '.json';

        if (!file_exists($sourceFile)) {
            throw new Exception("Source profile not found: $sourceProfile");
        }

        if (file_exists($targetFile)) {
            throw new Exception("Target profile already exists: $targetProfile");
        }

        // Load source profile
        $sourceProfileData = $this->readProfile($sourceProfile);

        // Update profile name and timestamps
        $timestamp = gmdate('Y-m-d\TH:i:s\Z');
        $clonedProfile = $sourceProfileData;
        $clonedProfile['name'] = $targetProfile;
        $clonedProfile['created_at'] = $timestamp;
        $clonedProfile['updated_at'] = $timestamp;

        // Save cloned profile
        file_put_contents($targetFile, json_encode($clonedProfile, JSON_PRETTY_PRINT));

        $this->log('INFO', "Cloned profile: $sourceProfile -> $targetProfile");

        return true;
    }

    /**
     * Validate profile
     *
     * @param string $name Profile name
     * @return array Validation result with 'valid' and 'errors' keys
     */
    public function validateProfile($name) {
        $errors = [];

        try {
            $profile = $this->readProfile($name);
        } catch (Exception $e) {
            return ['valid' => false, 'errors' => [$e->getMessage()]];
        }

        // Check required fields
        $requiredFields = ['name', 'description', 'gpu_bindings', 'service_preferences', 'event_handlers', 'safety_checks'];
        foreach ($requiredFields as $field) {
            if (!isset($profile[$field])) {
                $errors[] = "Missing required field: $field";
            }
        }

        // Check timestamps
        if (isset($profile['created_at'])) {
            if (!preg_match('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/', $profile['created_at'])) {
                $errors[] = "Invalid created_at format";
            }
        }

        if (isset($profile['updated_at'])) {
            if (!preg_match('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/', $profile['updated_at'])) {
                $errors[] = "Invalid updated_at format";
            }
        }

        return [
            'valid' => empty($errors),
            'profile_name' => $name,
            'errors' => $errors,
            'error_count' => count($errors)
        ];
    }

    /**
     * Get active profile
     *
     * @return string|null Active profile name or null
     */
    public function getActiveProfile() {
        if (!file_exists($this->configFile)) {
            return null;
        }

        $config = json_decode(file_get_contents($this->configFile), true);
        return $config['active_profile'] ?? null;
    }

    /**
     * Log message
     *
     * @param string $level Log level
     * @param string $message Log message
     */
    private function log($level, $message) {
        $timestamp = date('Y-m-d H:i:s');
        $logMessage = "[$timestamp] [$level] [PROFILE_MANAGER] $message\n";

        if (file_exists($this->logFile)) {
            file_put_contents($this->logFile, $logMessage, FILE_APPEND);
        }
    }
}
