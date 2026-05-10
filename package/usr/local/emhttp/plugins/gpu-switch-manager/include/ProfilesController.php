<?php

/**
 * ProfilesController.php
 * Profile management controller for GPU Switch Manager
 * Handles profile creation, editing, activation, and deletion
 */

class ProfilesController {
    private $webInterface;
    private $profileManager;
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

        // Initialize profile manager
        $this->profileManager = new ProfileManager();
    }

    /**
     * Profiles main page
     *
     * @return string Rendered page
     */
    public function index() {
        try {
            // Require authentication
            $user = $this->securityMiddleware->process('profiles', 'read', true);

            $profiles = $this->listProfiles();
            $activeProfile = $this->getActiveProfile();

            $data = [
                'title' => 'Profile Management',
                'profiles' => $profiles,
                'activeProfile' => $activeProfile,
                'profileCount' => count($profiles['data'] ?? []),
                'user' => $user
            ];

            return $this->webInterface->renderPage('profiles/index', $data);
        } catch (Exception $e) {
            $this->log('error', 'Failed to load profiles page');
            $errorResponse = $this->secureErrorHandler->handleError('INTERNAL_ERROR', $e, [
                'action' => 'load_profiles_page'
            ]);
            return $this->webInterface->renderError($errorResponse['message']);
        }
    }

    /**
     * Create profile
     *
     * @param string $profileName Profile name
     * @param array $profileData Profile data
     * @return array Create result
     */
    public function createProfile($profileName, $profileData) {
        try {
            // Validate CSRF token
            if (!$this->webInterface->validateCSRF()) {
                throw $this->secureErrorHandler->createSecureException('CSRF_INVALID');
            }

            // Validate profile name
            if (empty($profileName)) {
                throw $this->secureErrorHandler->createSecureException('VALIDATION_REQUIRED');
            }

            // Validate profile name format
            if (!preg_match('/^[a-zA-Z0-9_-]+$/', $profileName)) {
                throw $this->secureErrorHandler->createSecureException('VALIDATION_FORMAT');
            }

            // Check if profile already exists
            $existingProfile = $this->profileManager->readProfile($profileName);
            if ($existingProfile !== null) {
                throw $this->secureErrorHandler->createSecureException('PROFILE_EXISTS');
            }

            // Create profile
            $result = $this->profileManager->createProfile($profileName, $profileData);

            $this->log('info', "Profile $profileName created successfully");

            return [
                'success' => true,
                'data' => $result,
                'message' => 'Profile created successfully'
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to create profile');
            return $this->secureErrorHandler->handleError('PROFILE_INVALID', $e, [
                'profile_name' => $profileName,
                'action' => 'create_profile'
            ]);
        }
    }

    /**
     * Edit profile
     *
     * @param string $profileName Profile name
     * @param array $profileData Updated profile data
     * @return array Edit result
     */
    public function editProfile($profileName, $profileData) {
        try {
            // Validate CSRF token
            if (!$this->webInterface->validateCSRF()) {
                throw new Exception('Invalid CSRF token');
            }

            // Validate profile name
            if (empty($profileName)) {
                throw new Exception('Profile name is required');
            }

            // Check if profile exists
            $existingProfile = $this->profileManager->readProfile($profileName);
            if ($existingProfile === null) {
                throw new Exception('Profile not found');
            }

            // Update profile
            $result = $this->profileManager->updateProfile($profileName, $profileData);

            $this->log('info', "Profile $profileName updated successfully");

            return [
                'success' => true,
                'data' => $result,
                'message' => 'Profile updated successfully'
            ];
        } catch (Exception $e) {
            $this->log('error', "Failed to edit profile $profileName: " . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Delete profile
     *
     * @param string $profileName Profile name
     * @return array Delete result
     */
    public function deleteProfile($profileName) {
        try {
            // Validate CSRF token
            if (!$this->webInterface->validateCSRF()) {
                throw new Exception('Invalid CSRF token');
            }

            // Validate profile name
            if (empty($profileName)) {
                throw new Exception('Profile name is required');
            }

            // Check if profile exists
            $existingProfile = $this->profileManager->readProfile($profileName);
            if ($existingProfile === null) {
                throw new Exception('Profile not found');
            }

            // Check if profile is active
            $activeProfile = $this->profileManager->getActiveProfile();
            if ($activeProfile === $profileName) {
                throw new Exception('Cannot delete active profile. Please deactivate it first.');
            }

            // Delete profile
            $result = $this->profileManager->deleteProfile($profileName);

            $this->log('info', "Profile $profileName deleted successfully");

            return [
                'success' => true,
                'data' => $result,
                'message' => 'Profile deleted successfully'
            ];
        } catch (Exception $e) {
            $this->log('error', "Failed to delete profile $profileName: " . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Activate profile
     *
     * @param string $profileName Profile name
     * @return array Activate result
     */
    public function activateProfile($profileName) {
        try {
            // Validate CSRF token
            if (!$this->webInterface->validateCSRF()) {
                throw new Exception('Invalid CSRF token');
            }

            // Validate profile name
            if (empty($profileName)) {
                throw new Exception('Profile name is required');
            }

            // Check if profile exists
            $existingProfile = $this->profileManager->readProfile($profileName);
            if ($existingProfile === null) {
                throw new Exception('Profile not found');
            }

            // Validate profile
            $validation = $this->profileManager->validateProfile($profileName);
            if (!$validation['valid']) {
                throw new Exception('Profile validation failed: ' . implode(', ', $validation['errors']));
            }

            // Activate profile
            $result = $this->profileManager->activateProfile($profileName);

            $this->log('info', "Profile $profileName activated successfully");

            return [
                'success' => true,
                'data' => $result,
                'message' => 'Profile activated successfully'
            ];
        } catch (Exception $e) {
            $this->log('error', "Failed to activate profile $profileName: " . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Deactivate profile
     *
     * @return array Deactivate result
     */
    public function deactivateProfile() {
        try {
            // Validate CSRF token
            if (!$this->webInterface->validateCSRF()) {
                throw new Exception('Invalid CSRF token');
            }

            // Deactivate profile
            $result = $this->profileManager->deactivateProfile();

            $this->log('info', 'Profile deactivated successfully');

            return [
                'success' => true,
                'data' => $result,
                'message' => 'Profile deactivated successfully'
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to deactivate profile: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Clone profile
     *
     * @param string $sourceProfileName Source profile name
     * @param string $targetProfileName Target profile name
     * @return array Clone result
     */
    public function cloneProfile($sourceProfileName, $targetProfileName) {
        try {
            // Validate CSRF token
            if (!$this->webInterface->validateCSRF()) {
                throw new Exception('Invalid CSRF token');
            }

            // Validate source profile name
            if (empty($sourceProfileName)) {
                throw new Exception('Source profile name is required');
            }

            // Validate target profile name
            if (empty($targetProfileName)) {
                throw new Exception('Target profile name is required');
            }

            // Validate target profile name format
            if (!preg_match('/^[a-zA-Z0-9_-]+$/', $targetProfileName)) {
                throw new Exception('Target profile name must contain only alphanumeric characters, hyphens, and underscores');
            }

            // Check if source profile exists
            $sourceProfile = $this->profileManager->readProfile($sourceProfileName);
            if ($sourceProfile === null) {
                throw new Exception('Source profile not found');
            }

            // Check if target profile already exists
            $targetProfile = $this->profileManager->readProfile($targetProfileName);
            if ($targetProfile !== null) {
                throw new Exception('Target profile already exists');
            }

            // Clone profile
            $result = $this->profileManager->cloneProfile($sourceProfileName, $targetProfileName);

            $this->log('info', "Profile $sourceProfileName cloned to $targetProfileName successfully");

            return [
                'success' => true,
                'data' => $result,
                'message' => 'Profile cloned successfully'
            ];
        } catch (Exception $e) {
            $this->log('error', "Failed to clone profile $sourceProfileName: " . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Validate profile
     *
     * @param string $profileName Profile name
     * @return array Validation result
     */
    public function validateProfile($profileName) {
        try {
            // Validate profile name
            if (empty($profileName)) {
                throw new Exception('Profile name is required');
            }

            // Check if profile exists
            $existingProfile = $this->profileManager->readProfile($profileName);
            if ($existingProfile === null) {
                throw new Exception('Profile not found');
            }

            // Validate profile
            $validation = $this->profileManager->validateProfile($profileName);

            return [
                'success' => true,
                'data' => $validation
            ];
        } catch (Exception $e) {
            $this->log('error', "Failed to validate profile $profileName: " . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * List profiles
     *
     * @return array Profile list
     */
    public function listProfiles() {
        try {
            $profiles = $this->profileManager->listProfiles();

            return [
                'success' => true,
                'data' => $profiles,
                'count' => count($profiles)
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to list profiles: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Get active profile
     *
     * @return array Active profile
     */
    public function getActiveProfile() {
        try {
            $activeProfile = $this->profileManager->getActiveProfile();

            if ($activeProfile === null) {
                return [
                    'success' => true,
                    'data' => null,
                    'message' => 'No active profile'
                ];
            }

            $profileData = $this->profileManager->readProfile($activeProfile);

            return [
                'success' => true,
                'data' => [
                    'name' => $activeProfile,
                    'profile' => $profileData
                ]
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to get active profile: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Get profile details
     *
     * @param string $profileName Profile name
     * @return array Profile details
     */
    public function getProfileDetails($profileName) {
        try {
            // Validate profile name
            if (empty($profileName)) {
                throw new Exception('Profile name is required');
            }

            // Get profile
            $profile = $this->profileManager->readProfile($profileName);

            if ($profile === null) {
                throw new Exception('Profile not found');
            }

            // Get validation status
            $validation = $this->profileManager->validateProfile($profileName);

            // Check if active
            $activeProfile = $this->profileManager->getActiveProfile();
            $isActive = ($activeProfile === $profileName);

            return [
                'success' => true,
                'data' => [
                    'name' => $profileName,
                    'profile' => $profile,
                    'validation' => $validation,
                    'isActive' => $isActive
                ]
            ];
        } catch (Exception $e) {
            $this->log('error', "Failed to get profile details for $profileName: " . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Export profile
     *
     * @param string $profileName Profile name
     * @param string $format Export format (json, yaml)
     * @return array Export result
     */
    public function exportProfile($profileName, $format = 'json') {
        try {
            // Validate profile name
            if (empty($profileName)) {
                throw new Exception('Profile name is required');
            }

            // Get profile
            $profile = $this->profileManager->readProfile($profileName);

            if ($profile === null) {
                throw new Exception('Profile not found');
            }

            // Format export
            $exported = $this->formatExport($profile, $format);

            $this->log('info', "Profile $profileName exported in $format format");

            return [
                'success' => true,
                'data' => $exported,
                'format' => $format
            ];
        } catch (Exception $e) {
            $this->log('error', "Failed to export profile $profileName: " . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Import profile
     *
     * @param string $profileName Profile name
     * @param array $profileData Profile data
     * @param bool $overwrite Overwrite existing profile
     * @return array Import result
     */
    public function importProfile($profileName, $profileData, $overwrite = false) {
        try {
            // Validate CSRF token
            if (!$this->webInterface->validateCSRF()) {
                throw new Exception('Invalid CSRF token');
            }

            // Validate profile name
            if (empty($profileName)) {
                throw new Exception('Profile name is required');
            }

            // Check if profile exists
            $existingProfile = $this->profileManager->readProfile($profileName);

            if ($existingProfile !== null && !$overwrite) {
                throw new Exception('Profile already exists. Use overwrite flag to replace it.');
            }

            // Create or update profile
            if ($existingProfile !== null) {
                $result = $this->profileManager->updateProfile($profileName, $profileData);
            } else {
                $result = $this->profileManager->createProfile($profileName, $profileData);
            }

            $this->log('info', "Profile $profileName imported successfully");

            return [
                'success' => true,
                'data' => $result,
                'message' => 'Profile imported successfully'
            ];
        } catch (Exception $e) {
            $this->log('error', "Failed to import profile $profileName: " . $e->getMessage());
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
        $logMessage = "[$timestamp] [$level] [PROFILES_CONTROLLER] $message\n";

        if (file_exists($this->logFile)) {
            file_put_contents($this->logFile, $logMessage, FILE_APPEND);
        }
    }
}
