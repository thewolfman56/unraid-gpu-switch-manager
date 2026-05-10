<?php

/**
 * PasswordController.php
 * Password management controller for GPU Switch Manager
 * Handles password changes, resets, and validation
 */

class PasswordController {
    private $webInterface;
    private $authenticationService;
    private $passwordManager;
    private $securityMiddleware;
    private $secureErrorHandler;
    private $logFile;

    /**
     * Constructor
     *
     * @param WebInterface $webInterface Web interface instance
     * @param AuthenticationService $authenticationService Authentication service
     * @param PasswordManager $passwordManager Password manager
     * @param SecurityMiddleware $securityMiddleware Security middleware
     * @param SecureErrorHandler $secureErrorHandler Secure error handler
     * @param string $logFile Log file path
     */
    public function __construct($webInterface = null, $authenticationService = null, $passwordManager = null, $securityMiddleware = null, $secureErrorHandler = null, $logFile = null) {
        $this->webInterface = $webInterface ?? new WebInterface();
        $this->authenticationService = $authenticationService ?? new AuthenticationService();
        $this->passwordManager = $passwordManager ?? new PasswordManager();
        $this->securityMiddleware = $securityMiddleware ?? new SecurityMiddleware();
        $this->secureErrorHandler = $secureErrorHandler ?? new SecureErrorHandler($logFile);
        $this->logFile = $logFile ?? '/var/log/gpu.switch.manager.log';
    }

    /**
     * Password change page
     *
     * @return string Rendered page
     */
    public function index() {
        try {
            // Require authentication
            $user = $this->securityMiddleware->process('password', 'read', true);

            // Check if user needs to change password
            $needsChange = $this->passwordManager->needsPasswordChange($user['username'], $user);

            $data = [
                'title' => 'Change Password',
                'user' => $user,
                'needs_change' => $needsChange,
                'requirements' => $this->passwordManager->getPasswordRequirements()
            ];

            return $this->webInterface->renderPage('password/change', $data);
        } catch (Exception $e) {
            $this->log('error', 'Failed to load password change page');
            $errorResponse = $this->secureErrorHandler->handleError('INTERNAL_ERROR', $e, [
                'action' => 'load_password_page'
            ]);
            return $this->webInterface->renderError($errorResponse['message']);
        }
    }

    /**
     * Change password
     *
     * @param string $currentPassword Current password
     * @param string $newPassword New password
     * @param string $confirmPassword Confirm password
     * @return array Change result
     */
    public function changePassword($currentPassword, $newPassword, $confirmPassword) {
        try {
            // Get current user
            $user = $this->securityMiddleware->process('password', 'write', true);

            // Validate CSRF token
            if (!$this->webInterface->validateCSRF()) {
                throw $this->secureErrorHandler->createSecureException('CSRF_INVALID');
            }

            // Validate current password
            if (empty($currentPassword)) {
                throw $this->secureErrorHandler->createSecureException('VALIDATION_REQUIRED');
            }

            // Verify current password
            if (!$this->authenticationService->verifyPassword($user['username'], $currentPassword)) {
                $this->log('warning', "Failed password change attempt for user: {$user['username']}");
                throw $this->secureErrorHandler->createSecureException('AUTH_FAILED');
            }

            // Validate new password
            if (empty($newPassword)) {
                throw $this->secureErrorHandler->createSecureException('VALIDATION_REQUIRED');
            }

            // Validate password strength
            $strengthValidation = $this->passwordManager->validatePasswordStrength($newPassword);
            if (!$strengthValidation['valid']) {
                throw new Exception(implode(', ', $strengthValidation['errors']));
            }

            // Check password confirmation
            if ($newPassword !== $confirmPassword) {
                throw new Exception('New password and confirmation do not match');
            }

            // Check if new password is same as current
            if ($currentPassword === $newPassword) {
                throw new Exception('New password must be different from current password');
            }

            // Check password history
            if ($this->passwordManager->isPasswordInHistory($user['username'], $newPassword)) {
                throw new Exception('Cannot reuse recent passwords');
            }

            // Hash new password
            $newPasswordHash = $this->passwordManager->hashPassword($newPassword);

            // Update user password
            $this->authenticationService->updatePassword($user['username'], $newPasswordHash);

            // Add to password history
            $this->passwordManager->addToPasswordHistory($user['username'], $newPasswordHash);

            // Mark password as changed
            $userData = $this->authenticationService->getUser($user['username']);
            $userData = $this->passwordManager->markPasswordChanged($user['username'], $userData);
            $this->authenticationService->updateUser($user['username'], $userData);

            $this->log('info', "Password changed successfully for user: {$user['username']}");

            return [
                'success' => true,
                'message' => 'Password changed successfully'
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to change password');
            return $this->secureErrorHandler->handleError('AUTH_FAILED', $e, [
                'action' => 'change_password',
                'username' => $user['username'] ?? 'unknown'
            ]);
        }
    }

    /**
     * Validate password strength
     *
     * @param string $password Password to validate
     * @return array Validation result
     */
    public function validatePassword($password) {
        try {
            $validation = $this->passwordManager->validatePasswordStrength($password);

            return [
                'success' => true,
                'validation' => $validation
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to validate password');
            return $this->secureErrorHandler->handleError('VALIDATION_FAILED', $e, [
                'action' => 'validate_password'
            ]);
        }
    }

    /**
     * Generate secure password
     *
     * @param int $length Password length
     * @return array Generated password
     */
    public function generatePassword($length = 16) {
        try {
            // Require authentication
            $this->securityMiddleware->process('password', 'write', true);

            $password = $this->passwordManager->generateSecurePassword($length);

            $this->log('info', 'Secure password generated');

            return [
                'success' => true,
                'password' => $password,
                'length' => strlen($password),
                'message' => 'Secure password generated. Please save it securely.'
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to generate password');
            return $this->secureErrorHandler->handleError('INTERNAL_ERROR', $e, [
                'action' => 'generate_password'
            ]);
        }
    }

    /**
     * Get password requirements
     *
     * @return array Password requirements
     */
    public function getPasswordRequirements() {
        try {
            $requirements = $this->passwordManager->getPasswordRequirements();

            return [
                'success' => true,
                'requirements' => $requirements
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to get password requirements');
            return $this->secureErrorHandler->handleError('INTERNAL_ERROR', $e, [
                'action' => 'get_password_requirements'
            ]);
        }
    }

    /**
     * Check if password change is required
     *
     * @param string $username Username
     * @return array Check result
     */
    public function checkPasswordChangeRequired($username) {
        try {
            $userData = $this->authenticationService->getUser($username);

            if (!$userData) {
                throw $this->secureErrorHandler->createSecureException('AUTH_FAILED');
            }

            $needsChange = $this->passwordManager->needsPasswordChange($username, $userData);

            return [
                'success' => true,
                'required' => $needsChange,
                'reason' => $this->getPasswordChangeReason($userData)
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to check password change requirement');
            return $this->secureErrorHandler->handleError('INTERNAL_ERROR', $e, [
                'action' => 'check_password_change_required',
                'username' => $username
            ]);
        }
    }

    /**
     * Get password change reason
     *
     * @param array $userData User data
     * @return string Reason for password change
     */
    private function getPasswordChangeReason($userData) {
        if (isset($userData['force_password_change']) && $userData['force_password_change']) {
            return 'Password change required by administrator';
        }

        if (isset($userData['is_default_password']) && $userData['is_default_password']) {
            return 'Default password must be changed';
        }

        if (isset($userData['password_changed_at'])) {
            $passwordAge = time() - $userData['password_changed_at'];
            $maxAge = 90 * 24 * 60 * 60; // 90 days

            if ($passwordAge > $maxAge) {
                return 'Password has expired (90 days maximum)';
            }
        }

        return 'Password change required';
    }

    /**
     * Force password change for user
     *
     * @param string $username Username
     * @return array Force result
     */
    public function forcePasswordChange($username) {
        try {
            // Require admin authentication
            $admin = $this->securityMiddleware->process('user', 'admin', true);

            if ($admin['role'] !== 'admin') {
                throw $this->secureErrorHandler->createSecureException('AUTHZ_DENIED');
            }

            // Get user data
            $userData = $this->authenticationService->getUser($username);

            if (!$userData) {
                throw $this->secureErrorHandler->createSecureException('AUTH_FAILED');
            }

            // Force password change
            $userData['force_password_change'] = true;
            $this->authenticationService->updateUser($username, $userData);

            $this->log('info', "Password change forced for user: $username by admin: {$admin['username']}");

            return [
                'success' => true,
                'message' => 'Password change forced for user'
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to force password change');
            return $this->secureErrorHandler->handleError('AUTHZ_DENIED', $e, [
                'action' => 'force_password_change',
                'username' => $username,
                'admin' => $admin['username'] ?? 'unknown'
            ]);
        }
    }

    /**
     * Reset password (admin only)
     *
     * @param string $username Username
     * @param bool $generateNew Generate new password
     * @return array Reset result
     */
    public function resetPassword($username, $generateNew = true) {
        try {
            // Require admin authentication
            $admin = $this->securityMiddleware->process('user', 'admin', true);

            if ($admin['role'] !== 'admin') {
                throw $this->secureErrorHandler->createSecureException('AUTHZ_DENIED');
            }

            // Get user data
            $userData = $this->authenticationService->getUser($username);

            if (!$userData) {
                throw $this->secureErrorHandler->createSecureException('AUTH_FAILED');
            }

            // Generate new password or use temporary
            if ($generateNew) {
                $newPassword = $this->passwordManager->generateSecurePassword();
                $newPasswordHash = $this->passwordManager->hashPassword($newPassword);
            } else {
                $newPassword = 'temp123'; // Temporary password
                $newPasswordHash = $this->passwordManager->hashPassword($newPassword);
            }

            // Update user password
            $this->authenticationService->updatePassword($username, $newPasswordHash);

            // Force password change on next login
            $userData['force_password_change'] = true;
            $userData['is_default_password'] = true;
            $this->authenticationService->updateUser($username, $userData);

            $this->log('info', "Password reset for user: $username by admin: {$admin['username']}");

            $response = [
                'success' => true,
                'message' => 'Password reset successfully',
                'username' => $username,
                'force_change' => true
            ];

            // Include new password if generated
            if ($generateNew) {
                $response['new_password'] = $newPassword;
                $response['warning'] = 'Please communicate this password securely to the user';
            }

            return $response;
        } catch (Exception $e) {
            $this->log('error', 'Failed to reset password');
            return $this->secureErrorHandler->handleError('AUTHZ_DENIED', $e, [
                'action' => 'reset_password',
                'username' => $username,
                'admin' => $admin['username'] ?? 'unknown'
            ]);
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
        $logMessage = "[$timestamp] [$level] [PASSWORD_CONTROLLER] $message\n";

        if (file_exists($this->logFile)) {
            file_put_contents($this->logFile, $logMessage, FILE_APPEND);
        }
    }
}