<?php

/**
 * WebInterface.php
 * Core web interface class for GPU Switch Manager
 * Provides page rendering, JSON response handling, and session management
 */

class WebInterface {
    private $templateDir;
    private $assetDir;
    private $session;
    private $configManager;
    private $logFile;

    /**
     * Constructor
     *
     * @param string $templateDir Template directory path
     * @param string $assetDir Asset directory path
     * @param string $logFile Log file path
     */
    public function __construct($templateDir = null, $assetDir = null, $logFile = null) {
        $this->templateDir = $templateDir ?? dirname(__DIR__) . '/web/templates';
        $this->assetDir = $assetDir ?? dirname(__DIR__) . '/web/assets';
        $this->logFile = $logFile ?? '/var/log/gpu.switch.manager.log';

        // Initialize session
        $this->initSession();

        // Initialize configuration manager
        $this->configManager = new ConfigManager();
    }

    /**
     * Initialize session
     *
     * @return bool Success status
     */
    private function initSession() {
        if (session_status() === PHP_SESSION_NONE) {
            // Set secure session parameters
            ini_set('session.cookie_httponly', 1);
            ini_set('session.cookie_secure', 1);
            ini_set('session.cookie_samesite', 'Strict');
            ini_set('session.use_strict_mode', 1);

            session_start();
        }

        $this->session = &$_SESSION;

        // Initialize CSRF protection
        $this->initCSRF();

        return true;
    }

    /**
     * Initialize CSRF protection
     *
     * @return void
     */
    private function initCSRF() {
        // Generate new CSRF token if not exists or expired
        if (!$this->getSession('csrf_token') || $this->isCSRFTokenExpired()) {
            $this->generateCSRF();
        }

        // Set CSRF cookie for double-submit pattern
        $this->setCSRFCookie();
    }

    /**
     * Check if CSRF token is expired
     *
     * @return bool True if expired
     */
    private function isCSRFTokenExpired() {
        $tokenTime = $this->getSession('csrf_token_time');
        $tokenLifetime = $this->getSession('csrf_token_lifetime', 3600); // Default 1 hour

        return $tokenTime && (time() - $tokenTime) > $tokenLifetime;
    }

    /**
     * Set CSRF cookie for double-submit pattern
     *
     * @return void
     */
    private function setCSRFCookie() {
        $token = $this->getSession('csrf_token');

        if ($token) {
            // Set HttpOnly, Secure, SameSite cookie
            setcookie(
                'csrf_token',
                $token,
                [
                    'expires' => time() + 3600,
                    'path' => '/',
                    'domain' => '',
                    'secure' => true,
                    'httponly' => true,
                    'samesite' => 'Strict'
                ]
            );
        }
    }

    /**
     * Render page with template
     *
     * @param string $template Template name
     * @param array $data Template data
     * @return string Rendered page
     */
    public function renderPage($template, $data = []) {
        // Add common data
        $commonData = [
            'title' => $data['title'] ?? 'GPU Switch Manager',
            'csrf_token' => $this->generateCSRF(),
            'user' => $this->getSession('user'),
            'flash' => $this->getSession('flash'),
            'current_page' => $template
        ];

        $data = array_merge($commonData, $data);

        // Clear flash messages
        $this->setSession('flash', null);

        // Render template
        $templateFile = $this->templateDir . '/' . $template . '.php';

        if (!file_exists($templateFile)) {
            return $this->renderError("Template not found: $template");
        }

        ob_start();
        extract($data);
        include $templateFile;
        $content = ob_get_clean();

        return $content;
    }

    /**
     * Render JSON response
     *
     * @param array $data Response data
     * @param int $statusCode HTTP status code
     * @return string JSON response
     */
    public function renderJSON($data, $statusCode = 200) {
        http_response_code($statusCode);
        header('Content-Type: application/json');

        $response = [
            'success' => $data['success'] ?? true,
            'data' => $data,
            'timestamp' => gmdate('Y-m-d\TH:i:s\Z')
        ];

        echo json_encode($response, JSON_PRETTY_PRINT);
        exit;
    }

    /**
     * Render error page
     *
     * @param string $message Error message
     * @param int $statusCode HTTP status code
     * @return string Error page
     */
    public function renderError($message, $statusCode = 500) {
        http_response_code($statusCode);

        $data = [
            'title' => 'Error',
            'error' => $message,
            'statusCode' => $statusCode
        ];

        return $this->renderPage('error', $data);
    }

    /**
     * Redirect to URL
     *
     * @param string $url Target URL
     * @return void
     */
    public function redirect($url) {
        header("Location: $url");
        exit;
    }

    /**
     * Get request data
     *
     * @param string $key Request key
     * @param mixed $default Default value
     * @return mixed Request data
     */
    public function getRequestData($key = null, $default = null) {
        if ($key === null) {
            return array_merge($_GET, $_POST);
        }

        return $_GET[$key] ?? $_POST[$key] ?? $default;
    }

    /**
     * Get JSON request data
     *
     * @return array JSON request data
     */
    public function getJSONRequestData() {
        $input = file_get_contents('php://input');
        $data = json_decode($input, true);

        if (json_last_error() !== JSON_ERROR_NONE) {
            throw new Exception("Invalid JSON request: " . json_last_error_msg());
        }

        return $data;
    }

    /**
     * Validate CSRF token with double-submit pattern
     *
     * @param string $token CSRF token to validate
     * @param bool $rotateToken Whether to rotate token after validation
     * @return bool Valid status
     */
    public function validateCSRF($token = null, $rotateToken = true) {
        if ($token === null) {
            $token = $this->getRequestData('csrf_token');
        }

        $sessionToken = $this->getSession('csrf_token');
        $cookieToken = $_COOKIE['csrf_token'] ?? null;

        // Check if token is provided
        if (!$token) {
            $this->log('WARNING', 'CSRF validation failed: No token provided');
            return false;
        }

        // Check if session token exists
        if (!$sessionToken) {
            $this->log('WARNING', 'CSRF validation failed: No session token');
            return false;
        }

        // Check if cookie token exists
        if (!$cookieToken) {
            $this->log('WARNING', 'CSRF validation failed: No cookie token');
            return false;
        }

        // Check if token is expired
        if ($this->isCSRFTokenExpired()) {
            $this->log('WARNING', 'CSRF validation failed: Token expired');
            return false;
        }

        // Validate token against session (double-submit pattern)
        $sessionValid = hash_equals($sessionToken, $token);

        // Validate token against cookie (double-submit pattern)
        $cookieValid = hash_equals($cookieToken, $token);

        // If current token validation fails, try old token (validation window)
        if (!$sessionValid || !$cookieValid) {
            if ($this->validateCSRFWithOldToken($token)) {
                $this->log('INFO', 'CSRF validation passed using old token (validation window)');
                $sessionValid = true;
                $cookieValid = true;
            }
        }

        if (!$sessionValid) {
            $this->log('WARNING', 'CSRF validation failed: Token mismatch with session');
            return false;
        }

        if (!$cookieValid) {
            $this->log('WARNING', 'CSRF validation failed: Token mismatch with cookie');
            return false;
        }

        // Rotate token after successful validation
        if ($rotateToken) {
            $this->rotateCSRFToken();
        }

        return true;
    }

    /**
     * Generate CSRF token with expiration
     *
     * @param int $lifetime Token lifetime in seconds
     * @return string CSRF token
     */
    public function generateCSRF($lifetime = 3600) {
        // Generate cryptographically secure token
        $token = bin2hex(random_bytes(32));

        // Store token in session with timestamp
        $this->setSession('csrf_token', $token);
        $this->setSession('csrf_token_time', time());
        $this->setSession('csrf_token_lifetime', $lifetime);

        // Update cookie
        $this->setCSRFCookie();

        return $token;
    }

    /**
     * Rotate CSRF token after use
     *
     * @return void
     */
    private function rotateCSRFToken() {
        // Generate new token
        $newToken = bin2hex(random_bytes(32));

        // Store old token for validation window
        $oldToken = $this->getSession('csrf_token');
        $this->setSession('csrf_token_old', $oldToken);
        $this->setSession('csrf_token_old_time', time());

        // Set new token
        $this->setSession('csrf_token', $newToken);
        $this->setSession('csrf_token_time', time());

        // Update cookie
        $this->setCSRFCookie();

        // Clean up old tokens after validation window
        $this->cleanupOldCSRFTokens();
    }

    /**
     * Clean up old CSRF tokens
     *
     * @return void
     */
    private function cleanupOldCSRFTokens() {
        $oldTokenTime = $this->getSession('csrf_token_old_time');
        $validationWindow = 300; // 5 minutes validation window

        // Remove old token if validation window has passed
        if ($oldTokenTime && (time() - $oldTokenTime) > $validationWindow) {
            $this->setSession('csrf_token_old', null);
            $this->setSession('csrf_token_old_time', null);
        }
    }

    /**
     * Validate CSRF token against old token (for validation window)
     *
     * @param string $token CSRF token to validate
     * @return bool Valid status
     */
    private function validateCSRFWithOldToken($token) {
        $oldToken = $this->getSession('csrf_token_old');
        $oldTokenTime = $this->getSession('csrf_token_old_time');
        $validationWindow = 300; // 5 minutes validation window

        // Check if old token exists and is within validation window
        if (!$oldToken || !$oldTokenTime) {
            return false;
        }

        // Check if validation window has passed
        if ((time() - $oldTokenTime) > $validationWindow) {
            return false;
        }

        // Validate against old token
        return hash_equals($oldToken, $token);
    }

    /**
     * Get CSRF token metadata for debugging
     *
     * @return array CSRF metadata
     */
    public function getCSRFMetadata() {
        return [
            'has_token' => (bool)$this->getSession('csrf_token'),
            'token_age' => $this->getSession('csrf_token_time') ? (time() - $this->getSession('csrf_token_time')) : null,
            'token_lifetime' => $this->getSession('csrf_token_lifetime'),
            'is_expired' => $this->isCSRFTokenExpired(),
            'has_old_token' => (bool)$this->getSession('csrf_token_old'),
            'old_token_age' => $this->getSession('csrf_token_old_time') ? (time() - $this->getSession('csrf_token_old_time')) : null,
            'has_cookie_token' => isset($_COOKIE['csrf_token'])
        ];
    }

    /**
     * Get session data
     *
     * @param string $key Session key
     * @param mixed $default Default value
     * @return mixed Session data
     */
    public function getSession($key = null, $default = null) {
        if ($key === null) {
            return $this->session;
        }

        return $this->session[$key] ?? $default;
    }

    /**
     * Set session data
     *
     * @param string $key Session key
     * @param mixed $value Session value
     * @return bool Success status
     */
    public function setSession($key, $value) {
        $this->session[$key] = $value;

        return true;
    }

    /**
     * Set flash message
     *
     * @param string $type Message type (success, error, warning, info)
     * @param string $message Message content
     * @return bool Success status
     */
    public function setFlash($type, $message) {
        $flash = $this->getSession('flash', []);
        $flash[] = [
            'type' => $type,
            'message' => $message,
            'timestamp' => time()
        ];

        $this->setSession('flash', $flash);

        return true;
    }

    /**
     * Get flash messages
     *
     * @return array Flash messages
     */
    public function getFlash() {
        $flash = $this->getSession('flash', []);
        $this->setSession('flash', []);

        return $flash;
    }

    /**
     * Validate request
     *
     * @param array $rules Validation rules
     * @return array Validation result
     */
    public function validateRequest($rules) {
        $errors = [];

        foreach ($rules as $field => $rule) {
            $value = $this->getRequestData($field);

            // Check required
            if (isset($rule['required']) && $rule['required'] && empty($value)) {
                $errors[$field] = "$field is required";
                continue;
            }

            // Skip validation if empty and not required
            if (empty($value) && !isset($rule['required'])) {
                continue;
            }

            // Check type
            if (isset($rule['type'])) {
                switch ($rule['type']) {
                    case 'email':
                        if (!filter_var($value, FILTER_VALIDATE_EMAIL)) {
                            $errors[$field] = "$field must be a valid email";
                        }
                        break;

                    case 'url':
                        if (!filter_var($value, FILTER_VALIDATE_URL)) {
                            $errors[$field] = "$field must be a valid URL";
                        }
                        break;

                    case 'integer':
                        if (!is_numeric($value) || (int)$value != $value) {
                            $errors[$field] = "$field must be an integer";
                        }
                        break;

                    case 'float':
                        if (!is_numeric($value)) {
                            $errors[$field] = "$field must be a number";
                        }
                        break;

                    case 'boolean':
                        if (!in_array(strtolower($value), ['true', 'false', '1', '0', 'yes', 'no'])) {
                            $errors[$field] = "$field must be a boolean";
                        }
                        break;
                }
            }

            // Check min/max
            if (isset($rule['min']) && strlen($value) < $rule['min']) {
                $errors[$field] = "$field must be at least {$rule['min']} characters";
            }

            if (isset($rule['max']) && strlen($value) > $rule['max']) {
                $errors[$field] = "$field must be at most {$rule['max']} characters";
            }

            // Check pattern
            if (isset($rule['pattern']) && !preg_match($rule['pattern'], $value)) {
                $errors[$field] = "$field format is invalid";
            }

            // Check enum
            if (isset($rule['enum']) && !in_array($value, $rule['enum'])) {
                $errors[$field] = "$field must be one of: " . implode(', ', $rule['enum']);
            }
        }

        return [
            'valid' => empty($errors),
            'errors' => $errors
        ];
    }

    /**
     * Log message
     *
     * @param string $level Log level
     * @param string $message Log message
     */
    private function log($level, $message) {
        $timestamp = date('Y-m-d H:i:s');
        $logMessage = "[$timestamp] [$level] [WEB_INTERFACE] $message\n";

        if (file_exists($this->logFile)) {
            file_put_contents($this->logFile, $logMessage, FILE_APPEND);
        }
    }
}
