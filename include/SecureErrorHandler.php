<?php

/**
 * SecureErrorHandler.php
 * Secure error handling for GPU Switch Manager
 * Prevents information disclosure and provides appropriate error messages
 */

class SecureErrorHandler {
    private $logFile;
    private $debugMode;
    private $userRole;
    private $errorCodes;

    /**
     * Constructor
     *
     * @param string $logFile Log file path
     * @param bool $debugMode Debug mode flag
     * @param string $userRole Current user role
     */
    public function __construct($logFile = null, $debugMode = false, $userRole = null) {
        $this->logFile = $logFile ?? '/var/log/gpu.switch.manager.log';
        $this->debugMode = $debugMode;
        $this->userRole = $userRole;
        $this->initializeErrorCodes();
    }

    /**
     * Initialize error codes
     */
    private function initializeErrorCodes() {
        $this->errorCodes = [
            // Authentication errors
            'AUTH_FAILED' => [
                'user_message' => 'Invalid credentials',
                'admin_message' => 'Authentication failed: Invalid username or password',
                'log_level' => 'WARNING'
            ],
            'AUTH_LOCKED' => [
                'user_message' => 'Account temporarily locked',
                'admin_message' => 'Account locked due to multiple failed attempts',
                'log_level' => 'WARNING'
            ],
            'AUTH_SESSION_EXPIRED' => [
                'user_message' => 'Session expired',
                'admin_message' => 'User session expired',
                'log_level' => 'INFO'
            ],
            'AUTH_UNAUTHORIZED' => [
                'user_message' => 'Access denied',
                'admin_message' => 'Unauthorized access attempt',
                'log_level' => 'WARNING'
            ],

            // Authorization errors
            'AUTHZ_DENIED' => [
                'user_message' => 'Permission denied',
                'admin_message' => 'Authorization failed: Insufficient permissions',
                'log_level' => 'WARNING'
            ],
            'AUTHZ_RESOURCE_NOT_FOUND' => [
                'user_message' => 'Resource not found',
                'admin_message' => 'Authorization failed: Resource not found',
                'log_level' => 'INFO'
            ],

            // Input validation errors
            'VALIDATION_FAILED' => [
                'user_message' => 'Invalid input',
                'admin_message' => 'Input validation failed',
                'log_level' => 'WARNING'
            ],
            'VALIDATION_REQUIRED' => [
                'user_message' => 'Required field missing',
                'admin_message' => 'Required field validation failed',
                'log_level' => 'WARNING'
            ],
            'VALIDATION_FORMAT' => [
                'user_message' => 'Invalid format',
                'admin_message' => 'Format validation failed',
                'log_level' => 'WARNING'
            ],
            'VALIDATION_LENGTH' => [
                'user_message' => 'Invalid length',
                'admin_message' => 'Length validation failed',
                'log_level' => 'WARNING'
            ],

            // GPU errors
            'GPU_NOT_FOUND' => [
                'user_message' => 'GPU not found',
                'admin_message' => 'GPU not found at specified address',
                'log_level' => 'WARNING'
            ],
            'GPU_ALREADY_BOUND' => [
                'user_message' => 'GPU already bound',
                'admin_message' => 'GPU is already bound to VFIO',
                'log_level' => 'INFO'
            ],
            'GPU_NOT_BOUND' => [
                'user_message' => 'GPU not bound',
                'admin_message' => 'GPU is not bound to VFIO',
                'log_level' => 'INFO'
            ],
            'GPU_OPERATION_FAILED' => [
                'user_message' => 'GPU operation failed',
                'admin_message' => 'GPU operation failed',
                'log_level' => 'ERROR'
            ],

            // Configuration errors
            'CONFIG_NOT_FOUND' => [
                'user_message' => 'Configuration not found',
                'admin_message' => 'Configuration file not found',
                'log_level' => 'WARNING'
            ],
            'CONFIG_INVALID' => [
                'user_message' => 'Invalid configuration',
                'admin_message' => 'Configuration validation failed',
                'log_level' => 'ERROR'
            ],
            'CONFIG_SAVE_FAILED' => [
                'user_message' => 'Failed to save configuration',
                'admin_message' => 'Configuration save operation failed',
                'log_level' => 'ERROR'
            ],

            // Profile errors
            'PROFILE_NOT_FOUND' => [
                'user_message' => 'Profile not found',
                'admin_message' => 'Profile not found',
                'log_level' => 'WARNING'
            ],
            'PROFILE_EXISTS' => [
                'user_message' => 'Profile already exists',
                'admin_message' => 'Profile with this name already exists',
                'log_level' => 'WARNING'
            ],
            'PROFILE_INVALID' => [
                'user_message' => 'Invalid profile',
                'admin_message' => 'Profile validation failed',
                'log_level' => 'ERROR'
            ],

            // Service errors
            'SERVICE_NOT_FOUND' => [
                'user_message' => 'Service not found',
                'admin_message' => 'Service not found',
                'log_level' => 'WARNING'
            ],
            'SERVICE_START_FAILED' => [
                'user_message' => 'Failed to start service',
                'admin_message' => 'Service start operation failed',
                'log_level' => 'ERROR'
            ],
            'SERVICE_STOP_FAILED' => [
                'user_message' => 'Failed to stop service',
                'admin_message' => 'Service stop operation failed',
                'log_level' => 'ERROR'
            ],

            // File operation errors
            'FILE_NOT_FOUND' => [
                'user_message' => 'File not found',
                'admin_message' => 'File not found',
                'log_level' => 'WARNING'
            ],
            'FILE_READ_FAILED' => [
                'user_message' => 'Failed to read file',
                'admin_message' => 'File read operation failed',
                'log_level' => 'ERROR'
            ],
            'FILE_WRITE_FAILED' => [
                'user_message' => 'Failed to write file',
                'admin_message' => 'File write operation failed',
                'log_level' => 'ERROR'
            ],
            'FILE_DELETE_FAILED' => [
                'user_message' => 'Failed to delete file',
                'admin_message' => 'File delete operation failed',
                'log_level' => 'ERROR'
            ],
            'FILE_INVALID' => [
                'user_message' => 'Invalid file',
                'admin_message' => 'File validation failed',
                'log_level' => 'ERROR'
            ],

            // CSRF errors
            'CSRF_INVALID' => [
                'user_message' => 'Invalid security token',
                'admin_message' => 'CSRF token validation failed',
                'log_level' => 'WARNING'
            ],
            'CSRF_EXPIRED' => [
                'user_message' => 'Security token expired',
                'admin_message' => 'CSRF token expired',
                'log_level' => 'WARNING'
            ],
            'CSRF_MISSING' => [
                'user_message' => 'Security token required',
                'admin_message' => 'CSRF token missing from request',
                'log_level' => 'WARNING'
            ],

            // Rate limiting errors
            'RATE_LIMIT_EXCEEDED' => [
                'user_message' => 'Too many requests',
                'admin_message' => 'Rate limit exceeded',
                'log_level' => 'WARNING'
            ],

            // General errors
            'INTERNAL_ERROR' => [
                'user_message' => 'An error occurred',
                'admin_message' => 'Internal server error',
                'log_level' => 'ERROR'
            ],
            'NOT_IMPLEMENTED' => [
                'user_message' => 'Feature not available',
                'admin_message' => 'Feature not implemented',
                'log_level' => 'WARNING'
            ],
            'UNKNOWN_ERROR' => [
                'user_message' => 'An unexpected error occurred',
                'admin_message' => 'Unknown error occurred',
                'log_level' => 'ERROR'
            ]
        ];
    }

    /**
     * Handle error
     *
     * @param string $errorCode Error code
     * @param Exception $exception Exception object
     * @param array $context Additional context
     * @return array Error response
     */
    public function handleError($errorCode, $exception = null, $context = []) {
        // Get error code definition
        $errorDef = $this->errorCodes[$errorCode] ?? $this->errorCodes['UNKNOWN_ERROR'];

        // Determine message based on user role
        $message = $this->getErrorMessage($errorDef, $exception);

        // Log error with details
        $this->logError($errorCode, $errorDef, $exception, $context);

        // Build error response
        $response = [
            'success' => false,
            'error' => $errorCode,
            'message' => $message,
            'timestamp' => gmdate('Y-m-d\TH:i:s\Z')
        ];

        // Add debug information if in debug mode and user is admin
        if ($this->debugMode && $this->isAdmin()) {
            $response['debug'] = $this->getDebugInfo($exception, $context);
        }

        return $response;
    }

    /**
     * Get error message based on user role
     *
     * @param array $errorDef Error definition
     * @param Exception $exception Exception object
     * @return string Error message
     */
    private function getErrorMessage($errorDef, $exception = null) {
        // Use admin message if user is admin or in debug mode
        if ($this->isAdmin() || $this->debugMode) {
            return $errorDef['admin_message'];
        }

        // Use generic user message
        return $errorDef['user_message'];
    }

    /**
     * Log error with details
     *
     * @param string $errorCode Error code
     * @param array $errorDef Error definition
     * @param Exception $exception Exception object
     * @param array $context Additional context
     */
    private function logError($errorCode, $errorDef, $exception = null, $context = []) {
        $timestamp = date('Y-m-d H:i:s');
        $logLevel = $errorDef['log_level'] ?? 'ERROR';

        // Build log message
        $logMessage = "[$timestamp] [$logLevel] [SECURE_ERROR_HANDLER] ";
        $logMessage .= "Error: $errorCode | ";
        $logMessage .= "Message: {$errorDef['admin_message']}";

        // Add exception details
        if ($exception) {
            $logMessage .= " | Exception: " . get_class($exception);
            $logMessage .= " | File: " . $exception->getFile();
            $logMessage .= " | Line: " . $exception->getLine();
        }

        // Add context
        if (!empty($context)) {
            $logMessage .= " | Context: " . json_encode($context);
        }

        $logMessage .= "\n";

        // Write to log file
        if (file_exists($this->logFile)) {
            file_put_contents($this->logFile, $logMessage, FILE_APPEND);
        }
    }

    /**
     * Get debug information
     *
     * @param Exception $exception Exception object
     * @param array $context Additional context
     * @return array Debug information
     */
    private function getDebugInfo($exception = null, $context = []) {
        $debug = [];

        if ($exception) {
            $debug['exception'] = [
                'type' => get_class($exception),
                'message' => $exception->getMessage(),
                'file' => $exception->getFile(),
                'line' => $exception->getLine(),
                'trace' => $exception->getTraceAsString()
            ];
        }

        if (!empty($context)) {
            $debug['context'] = $context;
        }

        return $debug;
    }

    /**
     * Check if user is admin
     *
     * @return bool True if admin
     */
    private function isAdmin() {
        return $this->userRole === 'admin';
    }

    /**
     * Set user role
     *
     * @param string $role User role
     */
    public function setUserRole($role) {
        $this->userRole = $role;
    }

    /**
     * Set debug mode
     *
     * @param bool $debugMode Debug mode flag
     */
    public function setDebugMode($debugMode) {
        $this->debugMode = $debugMode;
    }

    /**
     * Sanitize exception message
     *
     * @param Exception $exception Exception object
     * @return string Sanitized message
     */
    public function sanitizeExceptionMessage($exception) {
        $message = $exception->getMessage();

        // Remove file paths
        $message = preg_replace('/[a-zA-Z]:\\\\[^\\\\]+\\\\/g', '', $message);
        $message = preg_replace('/\/[^\/]+\/[^\/]+\//g', '', $message);

        // Remove sensitive information patterns
        $message = preg_replace('/password[=:][^\s]+/i', 'password=***', $message);
        $message = preg_replace('/token[=:][^\s]+/i', 'token=***', $message);
        $message = preg_replace('/key[=:][^\s]+/i', 'key=***', $message);
        $message = preg_replace('/secret[=:][^\s]+/i', 'secret=***', $message);

        return $message;
    }

    /**
     * Create secure exception
     *
     * @param string $errorCode Error code
     * @param string $customMessage Custom message (optional)
     * @return Exception Secure exception
     */
    public function createSecureException($errorCode, $customMessage = null) {
        $errorDef = $this->errorCodes[$errorCode] ?? $this->errorCodes['UNKNOWN_ERROR'];
        $message = $customMessage ?? $errorDef['user_message'];

        return new Exception($message);
    }

    /**
     * Handle PHP error
     *
     * @param int $errno Error number
     * @param string $errstr Error message
     * @param string $errfile Error file
     * @param int $errline Error line
     * @return bool True if error handled
     */
    public function handlePHPError($errno, $errstr, $errfile, $errline) {
        // Map PHP error codes to our error codes
        $errorMap = [
            E_ERROR => 'INTERNAL_ERROR',
            E_WARNING => 'INTERNAL_ERROR',
            E_PARSE => 'INTERNAL_ERROR',
            E_NOTICE => 'INTERNAL_ERROR',
            E_CORE_ERROR => 'INTERNAL_ERROR',
            E_CORE_WARNING => 'INTERNAL_ERROR',
            E_COMPILE_ERROR => 'INTERNAL_ERROR',
            E_COMPILE_WARNING => 'INTERNAL_ERROR',
            E_USER_ERROR => 'INTERNAL_ERROR',
            E_USER_WARNING => 'INTERNAL_ERROR',
            E_USER_NOTICE => 'INTERNAL_ERROR',
            E_STRICT => 'INTERNAL_ERROR',
            E_RECOVERABLE_ERROR => 'INTERNAL_ERROR',
            E_DEPRECATED => 'INTERNAL_ERROR',
            E_USER_DEPRECATED => 'INTERNAL_ERROR'
        ];

        $errorCode = $errorMap[$errno] ?? 'UNKNOWN_ERROR';

        // Create exception-like object
        $exception = new Exception($errstr, $errno);

        // Log error
        $this->logError($errorCode, $this->errorCodes[$errorCode], $exception, [
            'file' => $errfile,
            'line' => $errline
        ]);

        return true;
    }

    /**
     * Handle uncaught exception
     *
     * @param Exception $exception Uncaught exception
     */
    public function handleUncaughtException($exception) {
        $errorCode = 'INTERNAL_ERROR';

        // Log error
        $this->logError($errorCode, $this->errorCodes[$errorCode], $exception);

        // Return error response
        return $this->handleError($errorCode, $exception);
    }

    /**
     * Register error handlers
     */
    public function registerHandlers() {
        set_error_handler([$this, 'handlePHPError']);
        set_exception_handler([$this, 'handleUncaughtException']);
    }

    /**
     * Get all error codes
     *
     * @return array All error codes
     */
    public function getErrorCodes() {
        return array_keys($this->errorCodes);
    }

    /**
     * Get error code definition
     *
     * @param string $errorCode Error code
     * @return array Error definition
     */
    public function getErrorCodeDefinition($errorCode) {
        return $this->errorCodes[$errorCode] ?? null;
    }
}