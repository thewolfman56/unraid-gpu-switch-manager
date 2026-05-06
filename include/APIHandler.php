<?php

/**
 * APIHandler.php
 * API request handler for GPU Switch Manager
 * Handles API routing, validation, authentication, and rate limiting
 */

class APIHandler {
    private $webInterface;
    private $configManager;
    private $securityMiddleware;
    private $rateLimiter;
    private $logFile;
    private $rateLimitWindow = 60; // seconds
    private $rateLimitMax = 100; // requests per window

    /**
     * Constructor
     *
     * @param WebInterface $webInterface Web interface instance
     * @param SecurityMiddleware $securityMiddleware Security middleware
     * @param RateLimiter $rateLimiter Rate limiter
     * @param string $logFile Log file path
     */
    public function __construct($webInterface = null, $securityMiddleware = null, $rateLimiter = null, $logFile = null) {
        $this->webInterface = $webInterface ?? new WebInterface();
        $this->securityMiddleware = $securityMiddleware ?? new SecurityMiddleware();
        $this->rateLimiter = $rateLimiter ?? new RateLimiter();
        $this->logFile = $logFile ?? '/var/log/gpu.switch.manager.log';

        // Initialize config manager
        $this->configManager = new ConfigManager();
    }

    /**
     * Handle API request
     *
     * @return void
     */
    public function handleRequest() {
        try {
            // Get request method and path
            $method = $_SERVER['REQUEST_METHOD'];
            $path = $this->getRequestPath();

            // Log request
            $this->logRequest($method, $path);

            // Rate limit request using RateLimiter
            $identifier = $this->getClientIP();
            $limitKey = "api:$method:$path";
            if (!$this->rateLimiter->check($identifier, $limitKey)) {
                $this->sendError(429, 'Rate limit exceeded');
                return;
            }

            // Authenticate request using SecurityMiddleware
            $user = $this->securityMiddleware->process('api', $method, false);

            // Route request
            $this->routeRequest($method, $path, $user);
        } catch (Exception $e) {
            $this->log('error', 'API request error: ' . $e->getMessage());
            $this->sendError(500, 'Internal server error');
        }
    }
            if (!$this->authenticateRequest()) {
                $this->sendError(401, 'Authentication required');
                return;
            }

            // Route request
            $response = $this->routeRequest($method, $path);

            // Send response
            $this->sendResponse($response);
        } catch (Exception $e) {
            $this->log('error', 'API request failed: ' . $e->getMessage());
            $this->sendError(500, 'Internal server error');
        }
    }

    /**
     * Route request to handler
     *
     * @param string $method HTTP method
     * @param string $path Request path
     * @return array Response data
     */
    private function routeRequest($method, $path) {
        // Parse path
        $parts = explode('/', trim($path, '/'));
        $endpoint = $parts[0] ?? '';
        $resource = $parts[1] ?? null;
        $action = $parts[2] ?? null;

        // Route to appropriate handler
        switch ($endpoint) {
            case 'config':
                return $this->handleConfigRequest($method, $resource, $action);

            case 'gpu':
                return $this->handleGPURequest($method, $resource, $action);

            case 'events':
                return $this->handleEventsRequest($method, $resource, $action);

            case 'profiles':
                return $this->handleProfilesRequest($method, $resource, $action);

            case 'preferences':
                return $this->handlePreferencesRequest($method, $resource, $action);

            case 'backups':
                return $this->handleBackupsRequest($method, $resource, $action);

            default:
                throw new Exception('Invalid endpoint');
        }
    }

    /**
     * Handle config requests
     *
     * @param string $method HTTP method
     * @param string $resource Resource identifier
     * @param string $action Action identifier
     * @return array Response data
     */
    private function handleConfigRequest($method, $resource, $action) {
        $controller = new ConfigController($this->webInterface, $this->logFile);

        switch ($method) {
            case 'GET':
                if ($resource === 'validate') {
                    return $controller->validateConfiguration();
                }
                return $controller->getConfiguration();

            case 'POST':
                if ($resource === 'export') {
                    $data = $this->webInterface->getJSONRequestData();
                    return $controller->exportConfiguration($data['format'] ?? 'json');
                }
                if ($resource === 'import') {
                    $data = $this->webInterface->getJSONRequestData();
                    return $controller->importConfiguration($data['config'], $data['merge'] ?? false);
                }
                $data = $this->webInterface->getJSONRequestData();
                return $controller->updateConfiguration($data);

            case 'PUT':
                $data = $this->webInterface->getJSONRequestData();
                return $controller->updateConfiguration($data);

            case 'DELETE':
                return $controller->resetConfiguration();

            default:
                throw new Exception('Invalid method');
        }
    }

    /**
     * Handle GPU requests
     *
     * @param string $method HTTP method
     * @param string $resource Resource identifier
     * @param string $action Action identifier
     * @return array Response data
     */
    private function handleGPURequest($method, $resource, $action) {
        $controller = new GPUController($this->webInterface, $this->logFile);

        switch ($method) {
            case 'GET':
                if ($resource === null) {
                    return $controller->getGPUs();
                }
                if ($action === 'drivers') {
                    return $controller->getGPUDrivers();
                }
                if ($action === 'history') {
                    return $controller->getGPUBindingHistory($resource);
                }
                if ($action === 'usage') {
                    return $controller->getGPUUsageStatistics();
                }
                return $controller->getGPUStatus($resource);

            case 'POST':
                if ($action === 'bind') {
                    return $controller->bindGPU($resource);
                }
                if ($action === 'unbind') {
                    return $controller->unbindGPU($resource);
                }
                if ($action === 'switch') {
                    $data = $this->webInterface->getJSONRequestData();
                    return $controller->switchGPU($resource, $data['targetMode']);
                }
                if ($action === 'refresh') {
                    return $controller->refreshGPUDiscovery();
                }
                throw new Exception('Invalid action');

            default:
                throw new Exception('Invalid method');
        }
    }

    /**
     * Handle events requests
     *
     * @param string $method HTTP method
     * @param string $resource Resource identifier
     * @param string $action Action identifier
     * @return array Response data
     */
    private function handleEventsRequest($method, $resource, $action) {
        $controller = new EventsController($this->webInterface, $this->logFile);

        switch ($method) {
            case 'GET':
                if ($resource === 'statistics') {
                    $data = $this->webInterface->getRequestData();
                    return $controller->getEventStatistics($data['days'] ?? 7);
                }
                if ($resource === 'active') {
                    return $controller->getActiveOperations();
                }
                if ($resource === 'status') {
                    return $controller->getEventHandlerStatus();
                }
                if ($resource === 'timeline') {
                    $data = $this->webInterface->getRequestData();
                    return $controller->getEventTimeline($data['gpuAddress'] ?? null, $data['days'] ?? 7);
                }
                if ($resource === 'types') {
                    return $controller->getEventTypes();
                }
                if ($action === 'progress') {
                    return $controller->getOperationProgress($resource);
                }
                $data = $this->webInterface->getRequestData();
                return $controller->getEventHistory($data['limit'] ?? 100, $data['offset'] ?? 0, $data['eventType'] ?? null);

            case 'POST':
                if ($action === 'cancel') {
                    return $controller->cancelOperation($resource);
                }
                if ($resource === 'clear') {
                    $data = $this->webInterface->getJSONRequestData();
                    return $controller->clearEventHistory($data['days'] ?? 30);
                }
                if ($resource === 'export') {
                    $data = $this->webInterface->getJSONRequestData();
                    return $controller->exportEventHistory($data['format'] ?? 'json', $data['days'] ?? 30);
                }
                throw new Exception('Invalid action');

            default:
                throw new Exception('Invalid method');
        }
    }

    /**
     * Handle profiles requests
     *
     * @param string $method HTTP method
     * @param string $resource Resource identifier
     * @param string $action Action identifier
     * @return array Response data
     */
    private function handleProfilesRequest($method, $resource, $action) {
        $controller = new ProfilesController($this->webInterface, $this->logFile);

        switch ($method) {
            case 'GET':
                if ($resource === null) {
                    return $controller->listProfiles();
                }
                if ($resource === 'active') {
                    return $controller->getActiveProfile();
                }
                if ($action === 'validate') {
                    return $controller->validateProfile($resource);
                }
                if ($action === 'export') {
                    $data = $this->webInterface->getRequestData();
                    return $controller->exportProfile($resource, $data['format'] ?? 'json');
                }
                return $controller->getProfileDetails($resource);

            case 'POST':
                if ($resource === null) {
                    $data = $this->webInterface->getJSONRequestData();
                    return $controller->createProfile($data['name'], $data['profile']);
                }
                if ($action === 'activate') {
                    return $controller->activateProfile($resource);
                }
                if ($action === 'deactivate') {
                    return $controller->deactivateProfile();
                }
                if ($action === 'clone') {
                    $data = $this->webInterface->getJSONRequestData();
                    return $controller->cloneProfile($resource, $data['targetName']);
                }
                if ($action === 'import') {
                    $data = $this->webInterface->getJSONRequestData();
                    return $controller->importProfile($resource, $data['profile'], $data['overwrite'] ?? false);
                }
                throw new Exception('Invalid action');

            case 'PUT':
                $data = $this->webInterface->getJSONRequestData();
                return $controller->editProfile($resource, $data['profile']);

            case 'DELETE':
                return $controller->deleteProfile($resource);

            default:
                throw new Exception('Invalid method');
        }
    }

    /**
     * Handle preferences requests
     *
     * @param string $method HTTP method
     * @param string $resource Resource identifier
     * @param string $action Action identifier
     * @return array Response data
     */
    private function handlePreferencesRequest($method, $resource, $action) {
        $controller = new PreferencesController($this->webInterface, $this->logFile);

        switch ($method) {
            case 'GET':
                if ($resource === null) {
                    return $controller->getPreferences();
                }
                if ($resource === 'default') {
                    return $controller->getDefaultPreferences();
                }
                if ($resource === 'categories') {
                    return $controller->getPreferenceCategories();
                }
                if ($action === 'export') {
                    $data = $this->webInterface->getRequestData();
                    return $controller->exportPreferences($data['format'] ?? 'json');
                }
                return $controller->getPreference($resource);

            case 'POST':
                if ($resource === 'reset') {
                    return $controller->resetAllPreferences();
                }
                if ($resource === 'import') {
                    $data = $this->webInterface->getJSONRequestData();
                    return $controller->importPreferences($data['preferences'], $data['merge'] ?? true);
                }
                throw new Exception('Invalid action');

            case 'PUT':
                $data = $this->webInterface->getJSONRequestData();
                return $controller->updatePreference($resource, $data['value']);

            case 'DELETE':
                if ($action === 'reset') {
                    return $controller->resetPreference($resource);
                }
                return $controller->deletePreference($resource);

            default:
                throw new Exception('Invalid method');
        }
    }

    /**
     * Handle backups requests
     *
     * @param string $method HTTP method
     * @param string $resource Resource identifier
     * @param string $action Action identifier
     * @return array Response data
     */
    private function handleBackupsRequest($method, $resource, $action) {
        $controller = new BackupsController($this->webInterface, $this->logFile);

        switch ($method) {
            case 'GET':
                if ($resource === null) {
                    return $controller->listBackups();
                }
                if ($resource === 'info') {
                    return $controller->getBackupInfo();
                }
                if ($resource === 'statistics') {
                    return $controller->getBackupStatistics();
                }
                if ($action === 'verify') {
                    return $controller->verifyBackup($resource);
                }
                if ($action === 'download') {
                    return $controller->downloadBackup($resource);
                }
                return $controller->getBackupInfo($resource);

            case 'POST':
                if ($resource === null) {
                    $data = $this->webInterface->getJSONRequestData();
                    return $controller->createBackup($data['description'] ?? null);
                }
                if ($action === 'restore') {
                    return $controller->restoreBackup($resource);
                }
                if ($action === 'schedule') {
                    $data = $this->webInterface->getJSONRequestData();
                    return $controller->scheduleBackup($data['schedule'], $data['time'] ?? null);
                }
                if ($action === 'cleanup') {
                    $data = $this->webInterface->getJSONRequestData();
                    return $controller->cleanupBackups($data['retentionCount'] ?? null);
                }
                throw new Exception('Invalid action');

            case 'DELETE':
                return $controller->deleteBackup($resource);

            default:
                throw new Exception('Invalid method');
        }
    }

    /**
     * Authenticate request
     *
     * @return bool Authentication status
     */
    private function authenticateRequest() {
        // Check for session authentication
        $user = $this->webInterface->getSession('user');
        if ($user !== null) {
            return true;
        }

        // Check for API key authentication
        $apiKey = $this->getAPIKey();
        if ($apiKey !== null && $this->validateAPIKey($apiKey)) {
            return true;
        }

        // Check for basic authentication
        $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
        if (preg_match('/^Basic\s+(.+)$/', $authHeader, $matches)) {
            $credentials = base64_decode($matches[1]);
            list($username, $password) = explode(':', $credentials, 2);

            if ($this->validateCredentials($username, $password)) {
                return true;
            }
        }

        return false;
    }

    /**
     * Get API key from request
     *
     * @return string|null API key
     */
    private function getAPIKey() {
        // Check header
        $apiKey = $_SERVER['HTTP_X_API_KEY'] ?? null;
        if ($apiKey !== null) {
            return $apiKey;
        }

        // Check query parameter
        $apiKey = $_GET['api_key'] ?? null;
        if ($apiKey !== null) {
            return $apiKey;
        }

        return null;
    }

    /**
     * Validate API key
     *
     * @param string $apiKey API key
     * @return bool Validation status
     */
    private function validateAPIKey($apiKey) {
        // Get configured API key
        $config = $this->configManager->loadConfig();
        $configuredKey = $config['api']['key'] ?? null;

        if ($configuredKey === null) {
            return false;
        }

        return hash_equals($configuredKey, $apiKey);
    }

    /**
     * Validate credentials
     *
     * @param string $username Username
     * @param string $password Password
     * @return bool Validation status
     */
    private function validateCredentials($username, $password) {
        // Get configured credentials
        $config = $this->configManager->loadConfig();
        $configuredUsername = $config['api']['username'] ?? null;
        $configuredPassword = $config['api']['password'] ?? null;

        if ($configuredUsername === null || $configuredPassword === null) {
            return false;
        }

        return hash_equals($configuredUsername, $username) &&
               hash_equals($configuredPassword, $password);
    }

    /**
     * Rate limit request
     *
     * @return bool Rate limit status
     */
    private function rateLimitRequest() {
        $clientIP = $this->getClientIP();
        $rateLimitFile = $this->getRateLimitFile($clientIP);

        // Read current rate limit data
        if (file_exists($rateLimitFile)) {
            $data = json_decode(file_get_contents($rateLimitFile), true);
        } else {
            $data = [
                'count' => 0,
                'window_start' => time()
            ];
        }

        // Check if window has expired
        if (time() - $data['window_start'] > $this->rateLimitWindow) {
            $data['count'] = 0;
            $data['window_start'] = time();
        }

        // Check if rate limit exceeded
        if ($data['count'] >= $this->rateLimitMax) {
            return false;
        }

        // Increment count
        $data['count']++;

        // Save rate limit data
        file_put_contents($rateLimitFile, json_encode($data));

        return true;
    }

    /**
     * Get client IP address
     *
     * @return string Client IP
     */
    private function getClientIP() {
        $ip = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? $_SERVER['HTTP_X_REAL_IP'] ?? $_SERVER['REMOTE_ADDR'] ?? 'unknown';
        return $ip;
    }

    /**
     * Get rate limit file path
     *
     * @param string $clientIP Client IP
     * @return string Rate limit file path
     */
    private function getRateLimitFile($clientIP) {
        $rateLimitDir = '/tmp/gpu-switch-manager/rate-limit';
        if (!is_dir($rateLimitDir)) {
            mkdir($rateLimitDir, 0755, true);
        }

        return $rateLimitDir . '/' . md5($clientIP) . '.json';
    }

    /**
     * Get request path
     *
     * @return string Request path
     */
    private function getRequestPath() {
        $requestUri = $_SERVER['REQUEST_URI'] ?? '/';
        $path = parse_url($requestUri, PHP_URL_PATH);

        // Remove base path if present
        $basePath = dirname($_SERVER['SCRIPT_NAME']);
        if (strpos($path, $basePath) === 0) {
            $path = substr($path, strlen($basePath));
        }

        // Remove /api prefix if present
        if (strpos($path, '/api') === 0) {
            $path = substr($path, 4);
        }

        return $path;
    }

    /**
     * Log request
     *
     * @param string $method HTTP method
     * @param string $path Request path
     */
    private function logRequest($method, $path) {
        $clientIP = $this->getClientIP();
        $userAgent = $_SERVER['HTTP_USER_AGENT'] ?? 'unknown';
        $timestamp = date('Y-m-d H:i:s');

        $logMessage = "[$timestamp] [$clientIP] [$method] $path - $userAgent\n";

        if (file_exists($this->logFile)) {
            file_put_contents($this->logFile, $logMessage, FILE_APPEND);
        }
    }

    /**
     * Send response
     *
     * @param array $response Response data
     * @return void
     */
    private function sendResponse($response) {
        $this->webInterface->renderJSON($response);
    }

    /**
     * Send error response
     *
     * @param int $statusCode HTTP status code
     * @param string $message Error message
     * @return void
     */
    private function sendError($statusCode, $message) {
        http_response_code($statusCode);
        header('Content-Type: application/json');

        $response = [
            'success' => false,
            'error' => $message,
            'timestamp' => gmdate('Y-m-d\TH:i:s\Z')
        ];

        echo json_encode($response, JSON_PRETTY_PRINT);
        exit;
    }

    /**
     * Log message
     *
     * @param string $level Log level
     * @param string $message Log message
     */
    private function log($level, $message) {
        $timestamp = date('Y-m-d H:i:s');
        $logMessage = "[$timestamp] [$level] [API_HANDLER] $message\n";

        if (file_exists($this->logFile)) {
            file_put_contents($this->logFile, $logMessage, FILE_APPEND);
        }
    }
}
