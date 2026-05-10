<?php

/**
 * SecurityMiddleware.php
 * Security middleware for GPU Switch Manager
 * Handles authentication, authorization, rate limiting, and security headers
 */

class SecurityMiddleware {
    private $authService;
    private $authzService;
    private $rateLimiter;
    private $securityLogger;
    private $logFile;

    /**
     * Constructor
     *
     * @param AuthenticationService $authService Authentication service
     * @param AuthorizationService $authzService Authorization service
     * @param RateLimiter $rateLimiter Rate limiter
     * @param string $logFile Log file path
     */
    public function __construct($authService = null, $authzService = null, $rateLimiter = null, $logFile = null) {
        $this->authService = $authService ?? new AuthenticationService();
        $this->authzService = $authzService ?? new AuthorizationService();
        $this->rateLimiter = $rateLimiter ?? new RateLimiter();
        $this->logFile = $logFile ?? '/var/log/gpu.switch.manager.log';
    }

    /**
     * Process request through security middleware
     *
     * @param string $resource Resource identifier
     * @param string $action Action identifier
     * @param bool $requireAuth Whether authentication is required
     * @return array User data if authenticated
     * @throws Exception If security check fails
     */
    public function process($resource, $action, $requireAuth = true) {
        try {
            // Set security headers
            $this->setSecurityHeaders();

            // Check rate limiting
            $this->checkRateLimit($resource, $action);

            // Get session
            $sessionId = $this->getSessionId();

            // Verify session if present
            $user = null;
            if ($sessionId !== null) {
                $sessionResult = $this->authService->verifySession($sessionId);
                if ($sessionResult['valid']) {
                    $user = $sessionResult['user'];
                }
            }

            // Check authentication requirement
            if ($requireAuth && $user === null) {
                $this->logSecurityEvent('authentication_required', [
                    'resource' => $resource,
                    'action' => $action,
                    'ip' => $this->getClientIP()
                ]);
                throw new Exception('Authentication required', 401);
            }

            // Check authorization if user is authenticated
            if ($user !== null) {
                $this->checkAuthorization($user, $resource, $action);
            }

            // Log successful security check
            if ($user !== null) {
                $this->logSecurityEvent('access_granted', [
                    'user' => $user['username'],
                    'resource' => $resource,
                    'action' => $action,
                    'ip' => $this->getClientIP()
                ]);
            }

            return $user;
        } catch (Exception $e) {
            $this->logSecurityEvent('access_denied', [
                'resource' => $resource,
                'action' => $action,
                'error' => $e->getMessage(),
                'ip' => $this->getClientIP()
            ]);
            throw $e;
        }
    }

    /**
     * Require authentication
     *
     * @return array User data
     * @throws Exception If not authenticated
     */
    public function requireAuth() {
        $sessionId = $this->getSessionId();

        if ($sessionId === null) {
            throw new Exception('Authentication required', 401);
        }

        $sessionResult = $this->authService->verifySession($sessionId);

        if (!$sessionResult['valid']) {
            throw new Exception('Invalid session', 401);
        }

        return $sessionResult['user'];
    }

    /**
     * Require admin role
     *
     * @return array User data
     * @throws Exception If not admin
     */
    public function requireAdmin() {
        $user = $this->requireAuth();

        if (!isset($user['role']) || $user['role'] !== 'admin') {
            $this->logSecurityEvent('admin_access_denied', [
                'user' => $user['username'],
                'ip' => $this->getClientIP()
            ]);
            throw new Exception('Administrator access required', 403);
        }

        return $user;
    }

    /**
     * Require specific permission
     *
     * @param string $resource Resource identifier
     * @param string $action Action identifier
     * @return array User data
     * @throws Exception If permission denied
     */
    public function requirePermission($resource, $action) {
        $user = $this->requireAuth();

        if (!$this->authzService->hasPermission($user['role'], $resource, $action)) {
            $this->logSecurityEvent('permission_denied', [
                'user' => $user['username'],
                'role' => $user['role'],
                'resource' => $resource,
                'action' => $action,
                'ip' => $this->getClientIP()
            ]);
            throw new Exception('Permission denied', 403);
        }

        return $user;
    }

    /**
     * Check rate limit
     *
     * @param string $resource Resource identifier
     * @param string $action Action identifier
     * @return void
     * @throws Exception If rate limit exceeded
     */
    private function checkRateLimit($resource, $action) {
        $identifier = $this->getClientIP();
        $limitKey = "$resource:$action";

        if (!$this->rateLimiter->check($identifier, $limitKey)) {
            $this->logSecurityEvent('rate_limit_exceeded', [
                'resource' => $resource,
                'action' => $action,
                'ip' => $identifier
            ]);
            throw new Exception('Rate limit exceeded', 429);
        }
    }

    /**
     * Check authorization
     *
     * @param array $user User data
     * @param string $resource Resource identifier
     * @param string $action Action identifier
     * @return void
     * @throws Exception If authorization denied
     */
    private function checkAuthorization($user, $resource, $action) {
        if (!$this->authzService->hasPermission($user['role'], $resource, $action)) {
            throw new Exception('Permission denied', 403);
        }
    }

    /**
     * Set security headers
     *
     * @return void
     */
    /**
     * Get security headers
     *
     * @return array Security headers
     */
    public function getSecurityHeaders() {
        return [
            'X-Frame-Options' => 'DENY',
            'X-Content-Type-Options' => 'nosniff',
            'X-XSS-Protection' => '1; mode=block',
            'Content-Security-Policy' => "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'; frame-ancestors 'none';",
            'Strict-Transport-Security' => 'max-age=31536000; includeSubDomains; preload',
            'Referrer-Policy' => 'strict-origin-when-cross-origin',
            'Permissions-Policy' => 'geolocation=(), microphone=(), camera=(), payment=()',
            'X-Powered-By' => 'GPU-Switch-Manager'
        ];
    }

    /**
     * Set security headers
     */
    private function setSecurityHeaders() {
        // Prevent clickjacking
        header('X-Frame-Options: DENY');

        // Prevent MIME type sniffing
        header('X-Content-Type-Options: nosniff');

        // Enable XSS protection
        header('X-XSS-Protection: 1; mode=block');

        // Content Security Policy
        header("Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'; frame-ancestors 'none';");

        // Strict Transport Security (if HTTPS)
        if ($this->isHTTPS()) {
            header('Strict-Transport-Security: max-age=31536000; includeSubDomains; preload');
        }

        // Referrer Policy
        header('Referrer-Policy: strict-origin-when-cross-origin');

        // Permissions Policy
        header('Permissions-Policy: geolocation=(), microphone=(), camera=(), payment=()');

        // X-Powered-By (remove or set generic)
        header('X-Powered-By: GPU-Switch-Manager');
    }

    /**
     * Get session ID
     *
     * @return string|null Session ID
     */
    private function getSessionId() {
        // Check session cookie
        if (isset($_COOKIE['session_id'])) {
            return $_COOKIE['session_id'];
        }

        // Check session header
        if (isset($_SERVER['HTTP_X_SESSION_ID'])) {
            return $_SERVER['HTTP_X_SESSION_ID'];
        }

        // Check Authorization header
        $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
        if (preg_match('/^Bearer\s+(.+)$/i', $authHeader, $matches)) {
            return $matches[1];
        }

        return null;
    }

    /**
     * Get client IP
     *
     * @return string Client IP
     */
    private function getClientIP() {
        $ip = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? $_SERVER['HTTP_X_REAL_IP'] ?? $_SERVER['REMOTE_ADDR'] ?? 'unknown';

        // Handle multiple IPs in X-Forwarded-For
        if (strpos($ip, ',') !== false) {
            $ips = explode(',', $ip);
            $ip = trim($ips[0]);
        }

        return $ip;
    }

    /**
     * Check if HTTPS
     *
     * @return bool HTTPS status
     */
    private function isHTTPS() {
        return (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ||
               ($_SERVER['SERVER_PORT'] ?? 80) == 443 ||
               (!empty($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https');
    }

    /**
     * Log security event
     *
     * @param string $event Event name
     * @param array $context Event context
     * @return void
     */
    private function logSecurityEvent($event, $context = []) {
        $timestamp = date('Y-m-d H:i:s');
        $logMessage = "[$timestamp] [SECURITY] [$event] " . json_encode($context) . "\n";

        if (file_exists($this->logFile)) {
            file_put_contents($this->logFile, $logMessage, FILE_APPEND);
        }
    }
}
