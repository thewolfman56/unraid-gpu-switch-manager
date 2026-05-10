<?php

/**
 * AuthenticationService.php
 * Authentication service for GPU Switch Manager
 * Handles user authentication, session management, and password security
 */

class AuthenticationService {
    private $userFile;
    private $sessionFile;
    private $logFile;
    private $maxLoginAttempts = 5;
    private $lockoutTime = 900; // 15 minutes
    private $sessionTimeout = 3600; // 1 hour

    /**
     * Constructor
     *
     * @param string $userFile User data file path
     * @param string $sessionFile Session data file path
     * @param string $logFile Log file path
     */
    public function __construct($userFile = null, $sessionFile = null, $logFile = null) {
        $this->userFile = $userFile ?? '/var/lib/gpu-switch-manager/users.json';
        $this->sessionFile = $sessionFile ?? '/var/lib/gpu-switch-manager/sessions.json';
        $this->logFile = $logFile ?? '/var/log/gpu.switch.manager.log';

        // Initialize user file if it doesn't exist
        $this->initializeUserFile();
    }

    /**
     * Authenticate user
     *
     * @param string $username Username
     * @param string $password Password
     * @return array Authentication result
     */
    public function authenticate($username, $password) {
        try {
            // Validate input
            $this->validateUsername($username);
            $this->validatePassword($password);

            // Check for lockout
            if ($this->isLockedOut($username)) {
                $this->log('warning', "Authentication attempt for locked out user: $username");
                return [
                    'success' => false,
                    'error' => 'Account temporarily locked due to too many failed attempts'
                ];
            }

            // Get user
            $user = $this->getUser($username);

            if ($user === null) {
                $this->recordFailedAttempt($username);
                $this->log('warning', "Authentication failed for non-existent user: $username");
                return [
                    'success' => false,
                    'error' => 'Invalid credentials'
                ];
            }

            // Verify password
            if (!password_verify($password, $user['password_hash'])) {
                $this->recordFailedAttempt($username);
                $this->log('warning', "Authentication failed for user: $username");
                return [
                    'success' => false,
                    'error' => 'Invalid credentials'
                ];
            }

            // Check if user is active
            if (!$user['active']) {
                $this->log('warning', "Authentication attempt for inactive user: $username");
                return [
                    'success' => false,
                    'error' => 'Account is inactive'
                ];
            }

            // Clear failed attempts
            $this->clearFailedAttempts($username);

            // Create session
            $session = $this->createSession($user);

            $this->log('info', "User authenticated successfully: $username");

            return [
                'success' => true,
                'user' => [
                    'id' => $user['id'],
                    'username' => $user['username'],
                    'role' => $user['role'],
                    'email' => $user['email'] ?? null
                ],
                'session' => $session
            ];
        } catch (Exception $e) {
            $this->log('error', 'Authentication error: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => 'Authentication failed'
            ];
        }
    }

    /**
     * Verify session
     *
     * @param string $sessionId Session ID
     * @return array Verification result
     */
    public function verifySession($sessionId) {
        try {
            $sessions = $this->loadSessions();

            if (!isset($sessions[$sessionId])) {
                return [
                    'valid' => false,
                    'error' => 'Session not found'
                ];
            }

            $session = $sessions[$sessionId];

            // Check if session is expired
            if (time() - $session['created'] > $this->sessionTimeout) {
                $this->destroySession($sessionId);
                return [
                    'valid' => false,
                    'error' => 'Session expired'
                ];
            }

            // Check if session is for current IP
            $currentIP = $this->getClientIP();
            if ($session['ip_address'] !== $currentIP) {
                $this->destroySession($sessionId);
                $this->log('warning', "Session IP mismatch for session: $sessionId");
                return [
                    'valid' => false,
                    'error' => 'Session invalid'
                ];
            }

            // Update last activity
            $sessions[$sessionId]['last_activity'] = time();
            $this->saveSessions($sessions);

            // Get user
            $user = $this->getUserById($session['user_id']);

            if ($user === null) {
                return [
                    'valid' => false,
                    'error' => 'User not found'
                ];
            }

            return [
                'valid' => true,
                'user' => [
                    'id' => $user['id'],
                    'username' => $user['username'],
                    'role' => $user['role'],
                    'email' => $user['email'] ?? null
                ]
            ];
        } catch (Exception $e) {
            $this->log('error', 'Session verification error: ' . $e->getMessage());
            return [
                'valid' => false,
                'error' => 'Session verification failed'
            ];
        }
    }

    /**
     * Destroy session
     *
     * @param string $sessionId Session ID
     * @return bool Success status
     */
    public function destroySession($sessionId) {
        try {
            $sessions = $this->loadSessions();

            if (isset($sessions[$sessionId])) {
                unset($sessions[$sessionId]);
                $this->saveSessions($sessions);
                $this->log('info', "Session destroyed: $sessionId");
                return true;
            }

            return false;
        } catch (Exception $e) {
            $this->log('error', 'Session destruction error: ' . $e->getMessage());
            return false;
        }
    }

    /**
     * Create user
     *
     * @param string $username Username
     * @param string $password Password
     * @param string $email Email address
     * @param string $role User role
     * @return array Creation result
     */
    public function createUser($username, $password, $email = null, $role = 'user') {
        try {
            // Validate input
            $this->validateUsername($username);
            $this->validatePassword($password);
            $this->validateEmail($email);
            $this->validateRole($role);

            // Check if user already exists
            if ($this->getUser($username) !== null) {
                throw new Exception('User already exists');
            }

            // Hash password
            $passwordHash = password_hash($password, PASSWORD_DEFAULT);

            // Create user
            $user = [
                'id' => $this->generateUserId(),
                'username' => $username,
                'password_hash' => $passwordHash,
                'email' => $email,
                'role' => $role,
                'active' => true,
                'created' => time(),
                'last_login' => null,
                'failed_attempts' => 0,
                'locked_until' => null
            ];

            // Save user
            $users = $this->loadUsers();
            $users[$user['id']] = $user;
            $this->saveUsers($users);

            $this->log('info', "User created: $username");

            return [
                'success' => true,
                'user' => [
                    'id' => $user['id'],
                    'username' => $user['username'],
                    'role' => $user['role'],
                    'email' => $user['email']
                ]
            ];
        } catch (Exception $e) {
            $this->log('error', 'User creation error: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Update user password
     *
     * @param string $username Username
     * @param string $oldPassword Old password
     * @param string $newPassword New password
     * @return array Update result
     */
    public function updatePassword($username, $oldPassword, $newPassword) {
        try {
            // Validate input
            $this->validateUsername($username);
            $this->validatePassword($oldPassword);
            $this->validatePassword($newPassword);

            // Get user
            $user = $this->getUser($username);

            if ($user === null) {
                throw new Exception('User not found');
            }

            // Verify old password
            if (!password_verify($oldPassword, $user['password_hash'])) {
                throw new Exception('Invalid current password');
            }

            // Hash new password
            $newPasswordHash = password_hash($newPassword, PASSWORD_DEFAULT);

            // Update user
            $users = $this->loadUsers();
            $users[$user['id']]['password_hash'] = $newPasswordHash;
            $users[$user['id']]['password_changed'] = time();
            $this->saveUsers($users);

            // Destroy all sessions for this user
            $this->destroyUserSessions($user['id']);

            $this->log('info', "Password updated for user: $username");

            return [
                'success' => true,
                'message' => 'Password updated successfully'
            ];
        } catch (Exception $e) {
            $this->log('error', 'Password update error: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Get user by username
     *
     * @param string $username Username
     * @return array|null User data
     */
    public function getUser($username) {
        $users = $this->loadUsers();

        foreach ($users as $user) {
            if ($user['username'] === $username) {
                return $user;
            }
        }

        return null;
    }

    /**
     * Get user by ID
     *
     * @param string $userId User ID
     * @return array|null User data
     */
    public function getUserById($userId) {
        $users = $this->loadUsers();

        return $users[$userId] ?? null;
    }

    /**
     * List all users
     *
     * @return array User list
     */
    public function listUsers() {
        $users = $this->loadUsers();

        $userList = [];
        foreach ($users as $user) {
            $userList[] = [
                'id' => $user['id'],
                'username' => $user['username'],
                'email' => $user['email'] ?? null,
                'role' => $user['role'],
                'active' => $user['active'],
                'created' => $user['created'],
                'last_login' => $user['last_login'] ?? null
            ];
        }

        return $userList;
    }

    /**
     * Check if user is locked out
     *
     * @param string $username Username
     * @return bool Lockout status
     */
    private function isLockedOut($username) {
        $user = $this->getUser($username);

        if ($user === null) {
            return false;
        }

        // Check if locked
        if ($user['locked_until'] !== null && $user['locked_until'] > time()) {
            return true;
        }

        // Check failed attempts
        if ($user['failed_attempts'] >= $this->maxLoginAttempts) {
            // Lock account
            $this->lockAccount($username);
            return true;
        }

        return false;
    }

    /**
     * Lock account
     *
     * @param string $username Username
     * @return void
     */
    private function lockAccount($username) {
        $users = $this->loadUsers();

        foreach ($users as $userId => $user) {
            if ($user['username'] === $username) {
                $users[$userId]['locked_until'] = time() + $this->lockoutTime;
                $this->saveUsers($users);
                $this->log('warning', "Account locked: $username");
                return;
            }
        }
    }

    /**
     * Record failed attempt
     *
     * @param string $username Username
     * @return void
     */
    private function recordFailedAttempt($username) {
        $users = $this->loadUsers();

        foreach ($users as $userId => $user) {
            if ($user['username'] === $username) {
                $users[$userId]['failed_attempts'] = ($users[$userId]['failed_attempts'] ?? 0) + 1;
                $this->saveUsers($users);
                return;
            }
        }
    }

    /**
     * Clear failed attempts
     *
     * @param string $username Username
     * @return void
     */
    private function clearFailedAttempts($username) {
        $users = $this->loadUsers();

        foreach ($users as $userId => $user) {
            if ($user['username'] === $username) {
                $users[$userId]['failed_attempts'] = 0;
                $users[$userId]['locked_until'] = null;
                $users[$userId]['last_login'] = time();
                $this->saveUsers($users);
                return;
            }
        }
    }

    /**
     * Create session
     *
     * @param array $user User data
     * @return string Session ID
     */
    private function createSession($user) {
        $sessionId = $this->generateSessionId();

        $session = [
            'id' => $sessionId,
            'user_id' => $user['id'],
            'username' => $user['username'],
            'role' => $user['role'],
            'ip_address' => $this->getClientIP(),
            'user_agent' => $_SERVER['HTTP_USER_AGENT'] ?? null,
            'created' => time(),
            'last_activity' => time()
        ];

        $sessions = $this->loadSessions();
        $sessions[$sessionId] = $session;
        $this->saveSessions($sessions);

        return $sessionId;
    }

    /**
     * Destroy all sessions for user
     *
     * @param string $userId User ID
     * @return void
     */
    private function destroyUserSessions($userId) {
        $sessions = $this->loadSessions();

        foreach ($sessions as $sessionId => $session) {
            if ($session['user_id'] === $userId) {
                unset($sessions[$sessionId]);
            }
        }

        $this->saveSessions($sessions);
    }

    /**
     * Load users
     *
     * @return array Users
     */
    private function loadUsers() {
        if (!file_exists($this->userFile)) {
            return [];
        }

        $content = file_get_contents($this->userFile);
        $users = json_decode($content, true);

        return $users ?? [];
    }

    /**
     * Save users
     *
     * @param array $users Users
     * @return void
     */
    private function saveUsers($users) {
        $dir = dirname($this->userFile);
        if (!is_dir($dir)) {
            mkdir($dir, 0700, true);
        }

        $content = json_encode($users, JSON_PRETTY_PRINT);
        file_put_contents($this->userFile, $content, LOCK_EX);
        chmod($this->userFile, 0600);
    }

    /**
     * Load sessions
     *
     * @return array Sessions
     */
    private function loadSessions() {
        if (!file_exists($this->sessionFile)) {
            return [];
        }

        $content = file_get_contents($this->sessionFile);
        $sessions = json_decode($content, true);

        // Clean expired sessions
        $now = time();
        $sessions = array_filter($sessions, function($session) use ($now) {
            return ($now - $session['created']) <= $this->sessionTimeout;
        });

        return $sessions ?? [];
    }

    /**
     * Save sessions
     *
     * @param array $sessions Sessions
     * @return void
     */
    private function saveSessions($sessions) {
        $dir = dirname($this->sessionFile);
        if (!is_dir($dir)) {
            mkdir($dir, 0700, true);
        }

        $content = json_encode($sessions, JSON_PRETTY_PRINT);
        file_put_contents($this->sessionFile, $content, LOCK_EX);
        chmod($this->sessionFile, 0600);
    }

    /**
     * Initialize user file
     *
     * @return void
     */
    private function initializeUserFile() {
        if (!file_exists($this->userFile)) {
            // Create default admin user
            $defaultPassword = 'admin'; // Should be changed immediately
            $passwordHash = password_hash($defaultPassword, PASSWORD_DEFAULT);

            $users = [
                $this->generateUserId() => [
                    'id' => $this->generateUserId(),
                    'username' => 'admin',
                    'password_hash' => $passwordHash,
                    'email' => null,
                    'role' => 'admin',
                    'active' => true,
                    'created' => time(),
                    'last_login' => null,
                    'failed_attempts' => 0,
                    'locked_until' => null
                ]
            ];

            $this->saveUsers($users);

            $this->log('info', 'Default admin user created. Password: admin (CHANGE IMMEDIATELY!)');
        }
    }

    /**
     * Generate user ID
     *
     * @return string User ID
     */
    private function generateUserId() {
        return 'user_' . bin2hex(random_bytes(8));
    }

    /**
     * Generate session ID
     *
     * @return string Session ID
     */
    private function generateSessionId() {
        return bin2hex(random_bytes(32));
    }

    /**
     * Get client IP
     *
     * @return string Client IP
     */
    private function getClientIP() {
        $ip = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? $_SERVER['HTTP_X_REAL_IP'] ?? $_SERVER['REMOTE_ADDR'] ?? 'unknown';
        return $ip;
    }

    /**
     * Validate username
     *
     * @param string $username Username
     * @return void
     */
    private function validateUsername($username) {
        if (empty($username)) {
            throw new Exception('Username is required');
        }

        if (strlen($username) < 3 || strlen($username) > 32) {
            throw new Exception('Username must be between 3 and 32 characters');
        }

        if (!preg_match('/^[a-zA-Z0-9_-]+$/', $username)) {
            throw new Exception('Username must contain only alphanumeric characters, hyphens, and underscores');
        }
    }

    /**
     * Validate password
     *
     * @param string $password Password
     * @return void
     */
    private function validatePassword($password) {
        if (empty($password)) {
            throw new Exception('Password is required');
        }

        if (strlen($password) < 8) {
            throw new Exception('Password must be at least 8 characters');
        }
    }

    /**
     * Validate email
     *
     * @param string|null $email Email
     * @return void
     */
    private function validateEmail($email) {
        if ($email !== null && !filter_var($email, FILTER_VALIDATE_EMAIL)) {
            throw new Exception('Invalid email format');
        }
    }

    /**
     * Validate role
     *
     * @param string $role Role
     * @return void
     */
    private function validateRole($role) {
        $validRoles = ['admin', 'user', 'readonly'];

        if (!in_array($role, $validRoles)) {
            throw new Exception('Invalid role');
        }
    }

    /**
     * Update password hash (admin function)
     *
     * @param string $username Username
     * @param string $passwordHash Hashed password
     * @return bool Success status
     */
    public function updatePasswordHash($username, $passwordHash) {
        try {
            $users = $this->loadUsers();

            foreach ($users as $userId => $user) {
                if ($user['username'] === $username) {
                    $users[$userId]['password_hash'] = $passwordHash;
                    $users[$userId]['password_changed'] = time();
                    $this->saveUsers($users);

                    // Destroy all sessions for this user
                    $this->destroyUserSessions($userId);

                    $this->log('info', "Password updated for user: $username");
                    return true;
                }
            }

            return false;
        } catch (Exception $e) {
            $this->log('error', 'Password update error: ' . $e->getMessage());
            return false;
        }
    }

    /**
     * Update user data
     *
     * @param string $username Username
     * @param array $userData User data to update
     * @return bool Success status
     */
    public function updateUser($username, $userData) {
        try {
            $users = $this->loadUsers();

            foreach ($users as $userId => $user) {
                if ($user['username'] === $username) {
                    // Merge user data
                    $users[$userId] = array_merge($users[$userId], $userData);
                    $this->saveUsers($users);

                    $this->log('info', "User data updated for: $username");
                    return true;
                }
            }

            return false;
        } catch (Exception $e) {
            $this->log('error', 'User update error: ' . $e->getMessage());
            return false;
        }
    }

    /**
     * Verify password
     *
     * @param string $username Username
     * @param string $password Plain text password
     * @return bool True if password matches
     */
    public function verifyPassword($username, $password) {
        try {
            $user = $this->getUser($username);

            if ($user === null) {
                return false;
            }

            return password_verify($password, $user['password_hash']);
        } catch (Exception $e) {
            $this->log('error', 'Password verification error: ' . $e->getMessage());
            return false;
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
        $logMessage = "[$timestamp] [$level] [AUTH_SERVICE] $message\n";

        if (file_exists($this->logFile)) {
            file_put_contents($this->logFile, $logMessage, FILE_APPEND);
        }
    }
}
