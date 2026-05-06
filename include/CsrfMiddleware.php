<?php

/**
 * CsrfMiddleware.php
 * CSRF protection middleware for GPU Switch Manager
 * Provides token validation, rotation, and double-submit cookie pattern
 */

class CsrfMiddleware {
    private $webInterface;
    private $exemptRoutes;
    private $logFile;

    /**
     * Constructor
     *
     * @param WebInterface $webInterface Web interface instance
     * @param array $exemptRoutes Routes exempt from CSRF validation
     * @param string $logFile Log file path
     */
    public function __construct($webInterface, $exemptRoutes = [], $logFile = null) {
        $this->webInterface = $webInterface;
        $this->exemptRoutes = $exemptRoutes;
        $this->logFile = $logFile ?? '/var/log/gpu.switch.manager.log';
    }

    /**
     * Handle incoming request
     *
     * @param string $route Current route
     * @param string $method HTTP method
     * @return bool True if request should proceed
     */
    public function handle($route, $method = 'GET') {
        // Skip CSRF validation for exempt routes
        if ($this->isRouteExempt($route, $method)) {
            $this->log('INFO', "CSRF validation skipped for exempt route: $route ($method)");
            return true;
        }

        // Only validate state-changing methods
        if (!in_array($method, ['POST', 'PUT', 'DELETE', 'PATCH'])) {
            return true;
        }

        // Validate CSRF token
        $valid = $this->webInterface->validateCSRF();

        if (!$valid) {
            $this->log('WARNING', "CSRF validation failed for route: $route ($method)");
            $this->sendCSRFError();
            return false;
        }

        $this->log('INFO', "CSRF validation passed for route: $route ($method)");
        return true;
    }

    /**
     * Check if route is exempt from CSRF validation
     *
     * @param string $route Current route
     * @param string $method HTTP method
     * @return bool True if exempt
     */
    private function isRouteExempt($route, $method) {
        foreach ($this->exemptRoutes as $exemptRoute) {
            // Check for exact match
            if ($exemptRoute === $route) {
                return true;
            }

            // Check for wildcard match
            if (str_ends_with($exemptRoute, '*')) {
                $pattern = str_replace('*', '', $exemptRoute);
                if (str_starts_with($route, $pattern)) {
                    return true;
                }
            }

            // Check for method-specific exemption
            if (str_contains($exemptRoute, ':')) {
                list($exemptMethod, $exemptRoutePattern) = explode(':', $exemptRoute);
                if ($exemptMethod === $method && $route === $exemptRoutePattern) {
                    return true;
                }
            }
        }

        return false;
    }

    /**
     * Send CSRF error response
     *
     * @return void
     */
    private function sendCSRFError() {
        http_response_code(403);
        header('Content-Type: application/json');

        $response = [
            'success' => false,
            'error' => 'CSRF validation failed',
            'message' => 'Invalid or missing CSRF token. Please refresh the page and try again.',
            'timestamp' => gmdate('Y-m-d\TH:i:s\Z')
        ];

        echo json_encode($response, JSON_PRETTY_PRINT);
        exit;
    }

    /**
     * Add CSRF headers to response
     *
     * @return void
     */
    public function addCSRFHeaders() {
        // Add CSRF token to response headers for AJAX requests
        $token = $this->webInterface->generateCSRF();
        header('X-CSRF-Token: ' . $token);

        // Add CSRF protection headers
        header('X-Content-Type-Options: nosniff');
        header('X-Frame-Options: DENY');
        header('X-XSS-Protection: 1; mode=block');
    }

    /**
     * Get CSRF token for JavaScript
     *
     * @return array CSRF token data
     */
    public function getCSRFTokenForJS() {
        return [
            'token' => $this->webInterface->generateCSRF(),
            'headerName' => 'X-CSRF-Token',
            'parameterName' => 'csrf_token',
            'metadata' => $this->webInterface->getCSRFMetadata()
        ];
    }

    /**
     * Validate AJAX request with custom token
     *
     * @param string $token CSRF token from request
     * @return bool Valid status
     */
    public function validateAJAXRequest($token) {
        if (!$token) {
            // Try to get token from header
            $token = $_SERVER['HTTP_X_CSRF_TOKEN'] ?? null;
        }

        return $this->webInterface->validateCSRF($token);
    }

    /**
     * Log message
     *
     * @param string $level Log level
     * @param string $message Log message
     */
    private function log($level, $message) {
        $timestamp = date('Y-m-d H:i:s');
        $logMessage = "[$timestamp] [$level] [CSRF_MIDDLEWARE] $message\n";

        if (file_exists($this->logFile)) {
            file_put_contents($this->logFile, $logMessage, FILE_APPEND);
        }
    }
}