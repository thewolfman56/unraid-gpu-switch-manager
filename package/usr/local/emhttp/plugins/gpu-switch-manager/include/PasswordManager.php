<?php

/**
 * PasswordManager.php
 * Password management service for GPU Switch Manager
 * Handles password validation, strength checking, history tracking, and reset functionality
 */

class PasswordManager {
    private $minLength;
    private $requireUppercase;
    private $requireLowercase;
    private $requireNumbers;
    private $requireSpecialChars;
    private $maxHistory;
    private $passwordHistoryFile;
    private $logFile;

    /**
     * Constructor
     *
     * @param array $config Password configuration
     * @param string $logFile Log file path
     */
    public function __construct($config = [], $logFile = null) {
        $this->minLength = $config['min_length'] ?? 12;
        $this->requireUppercase = $config['require_uppercase'] ?? true;
        $this->requireLowercase = $config['require_lowercase'] ?? true;
        $this->requireNumbers = $config['require_numbers'] ?? true;
        $this->requireSpecialChars = $config['require_special_chars'] ?? true;
        $this->maxHistory = $config['max_history'] ?? 5;
        $this->passwordHistoryFile = $config['history_file'] ?? '/var/lib/gpu-switch-manager/password_history.json';
        $this->logFile = $logFile ?? '/var/log/gpu.switch.manager.log';
    }

    /**
     * Validate password strength
     *
     * @param string $password Password to validate
     * @return array Validation result
     */
    public function validatePasswordStrength($password) {
        $errors = [];
        $score = 0;

        // Check minimum length
        if (strlen($password) < $this->minLength) {
            $errors[] = "Password must be at least {$this->minLength} characters";
        } else {
            $score += 20;
        }

        // Check for uppercase letters
        if ($this->requireUppercase && !preg_match('/[A-Z]/', $password)) {
            $errors[] = "Password must contain at least one uppercase letter";
        } elseif (preg_match('/[A-Z]/', $password)) {
            $score += 20;
        }

        // Check for lowercase letters
        if ($this->requireLowercase && !preg_match('/[a-z]/', $password)) {
            $errors[] = "Password must contain at least one lowercase letter";
        } elseif (preg_match('/[a-z]/', $password)) {
            $score += 20;
        }

        // Check for numbers
        if ($this->requireNumbers && !preg_match('/[0-9]/', $password)) {
            $errors[] = "Password must contain at least one number";
        } elseif (preg_match('/[0-9]/', $password)) {
            $score += 20;
        }

        // Check for special characters
        if ($this->requireSpecialChars && !preg_match('/[^a-zA-Z0-9]/', $password)) {
            $errors[] = "Password must contain at least one special character";
        } elseif (preg_match('/[^a-zA-Z0-9]/', $password)) {
            $score += 20;
        }

        // Check for common weak passwords
        if ($this->isCommonPassword($password)) {
            $errors[] = "Password is too common";
            $score = 0;
        }

        // Determine strength level
        $strength = 'weak';
        if ($score >= 80) {
            $strength = 'strong';
        } elseif ($score >= 60) {
            $strength = 'medium';
        }

        return [
            'valid' => empty($errors),
            'errors' => $errors,
            'score' => $score,
            'strength' => $strength,
            'requirements' => [
                'min_length' => $this->minLength,
                'require_uppercase' => $this->requireUppercase,
                'require_lowercase' => $this->requireLowercase,
                'require_numbers' => $this->requireNumbers,
                'require_special_chars' => $this->requireSpecialChars
            ]
        ];
    }

    /**
     * Check if password is common/weak
     *
     * @param string $password Password to check
     * @return bool True if common password
     */
    private function isCommonPassword($password) {
        $commonPasswords = [
            'password', '123456', '12345678', 'qwerty', 'abc123',
            'monkey', 'master', 'dragon', '111111', 'baseball',
            'iloveyou', 'trustno1', 'sunshine', 'princess', 'admin',
            'welcome', 'shadow', 'ashley', 'football', 'jesus',
            'michael', 'ninja', 'mustang', 'password1', 'password123'
        ];

        $lowerPassword = strtolower($password);
        foreach ($commonPasswords as $common) {
            if (strpos($lowerPassword, $common) !== false) {
                return true;
            }
        }

        return false;
    }

    /**
     * Hash password
     *
     * @param string $password Plain text password
     * @return string Hashed password
     */
    public function hashPassword($password) {
        return password_hash($password, PASSWORD_DEFAULT);
    }

    /**
     * Verify password
     *
     * @param string $password Plain text password
     * @param string $hash Hashed password
     * @return bool True if password matches
     */
    public function verifyPassword($password, $hash) {
        return password_verify($password, $hash);
    }

    /**
     * Check if password needs rehashing
     *
     * @param string $hash Hashed password
     * @return bool True if needs rehashing
     */
    public function needsRehash($hash) {
        return password_needs_rehash($hash, PASSWORD_DEFAULT);
    }

    /**
     * Add password to history
     *
     * @param string $username Username
     * @param string $passwordHash Hashed password
     * @return bool Success status
     */
    public function addToPasswordHistory($username, $passwordHash) {
        try {
            // Load existing history
            $history = $this->loadPasswordHistory();

            // Initialize user history if not exists
            if (!isset($history[$username])) {
                $history[$username] = [];
            }

            // Add new password to history
            array_unshift($history[$username], [
                'hash' => $passwordHash,
                'timestamp' => time()
            ]);

            // Keep only last N passwords
            if (count($history[$username]) > $this->maxHistory) {
                $history[$username] = array_slice($history[$username], 0, $this->maxHistory);
            }

            // Save history
            $this->savePasswordHistory($history);

            $this->log('info', "Password added to history for user: $username");

            return true;
        } catch (Exception $e) {
            $this->log('error', "Failed to add password to history: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Check if password is in history
     *
     * @param string $username Username
     * @param string $password Plain text password
     * @return bool True if password is in history
     */
    public function isPasswordInHistory($username, $password) {
        try {
            $history = $this->loadPasswordHistory();

            if (!isset($history[$username])) {
                return false;
            }

            foreach ($history[$username] as $entry) {
                if ($this->verifyPassword($password, $entry['hash'])) {
                    return true;
                }
            }

            return false;
        } catch (Exception $e) {
            $this->log('error', "Failed to check password history: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Load password history
     *
     * @return array Password history
     */
    private function loadPasswordHistory() {
        if (!file_exists($this->passwordHistoryFile)) {
            return [];
        }

        $content = file_get_contents($this->passwordHistoryFile);
        $data = json_decode($content, true);

        return $data ?: [];
    }

    /**
     * Save password history
     *
     * @param array $history Password history
     * @return bool Success status
     */
    private function savePasswordHistory($history) {
        try {
            $directory = dirname($this->passwordHistoryFile);
            if (!is_dir($directory)) {
                mkdir($directory, 0700, true);
            }

            $content = json_encode($history, JSON_PRETTY_PRINT);
            file_put_contents($this->passwordHistoryFile, $content, LOCK_EX);

            // Set secure permissions
            chmod($this->passwordHistoryFile, 0600);

            return true;
        } catch (Exception $e) {
            $this->log('error', "Failed to save password history: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Clear password history for user
     *
     * @param string $username Username
     * @return bool Success status
     */
    public function clearPasswordHistory($username) {
        try {
            $history = $this->loadPasswordHistory();

            if (isset($history[$username])) {
                unset($history[$username]);
                $this->savePasswordHistory($history);

                $this->log('info', "Password history cleared for user: $username");
            }

            return true;
        } catch (Exception $e) {
            $this->log('error', "Failed to clear password history: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Generate secure random password
     *
     * @param int $length Password length
     * @return string Generated password
     */
    public function generateSecurePassword($length = 16) {
        $uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        $lowercase = 'abcdefghijklmnopqrstuvwxyz';
        $numbers = '0123456789';
        $special = '!@#$%^&*()_+-=[]{}|;:,.<>?';

        $all = $uppercase . $lowercase . $numbers . $special;
        $password = '';

        // Ensure at least one of each required character type
        $password .= $uppercase[random_int(0, strlen($uppercase) - 1)];
        $password .= $lowercase[random_int(0, strlen($lowercase) - 1)];
        $password .= $numbers[random_int(0, strlen($numbers) - 1)];
        $password .= $special[random_int(0, strlen($special) - 1)];

        // Fill remaining length with random characters
        for ($i = strlen($password); $i < $length; $i++) {
            $password .= $all[random_int(0, strlen($all) - 1)];
        }

        // Shuffle password
        $password = str_shuffle($password);

        return $password;
    }

    /**
     * Get password requirements
     *
     * @return array Password requirements
     */
    public function getPasswordRequirements() {
        return [
            'min_length' => $this->minLength,
            'require_uppercase' => $this->requireUppercase,
            'require_lowercase' => $this->requireLowercase,
            'require_numbers' => $this->requireNumbers,
            'require_special_chars' => $this->requireSpecialChars,
            'max_history' => $this->maxHistory
        ];
    }

    /**
     * Check if user needs to change password
     *
     * @param string $username Username
     * @param array $userData User data
     * @return bool True if password change required
     */
    public function needsPasswordChange($username, $userData) {
        // Check if password change is forced
        if (isset($userData['force_password_change']) && $userData['force_password_change']) {
            return true;
        }

        // Check if using default password
        if (isset($userData['is_default_password']) && $userData['is_default_password']) {
            return true;
        }

        // Check if password is too old (90 days)
        if (isset($userData['password_changed_at'])) {
            $passwordAge = time() - $userData['password_changed_at'];
            $maxAge = 90 * 24 * 60 * 60; // 90 days

            if ($passwordAge > $maxAge) {
                return true;
            }
        }

        return false;
    }

    /**
     * Mark password as changed
     *
     * @param string $username Username
     * @param array $userData User data
     * @return array Updated user data
     */
    public function markPasswordChanged($username, $userData) {
        $userData['force_password_change'] = false;
        $userData['is_default_password'] = false;
        $userData['password_changed_at'] = time();
        $userData['password_changed_by'] = $username;

        $this->log('info', "Password marked as changed for user: $username");

        return $userData;
    }

    /**
     * Log message
     *
     * @param string $level Log level
     * @param string $message Log message
     */
    private function log($level, $message) {
        $timestamp = date('Y-m-d H:i:s');
        $logMessage = "[$timestamp] [$level] [PASSWORD_MANAGER] $message\n";

        if (file_exists($this->logFile)) {
            file_put_contents($this->logFile, $logMessage, FILE_APPEND);
        }
    }
}