<?php

/**
 * CsrfController.php
 * CSRF token management controller for GPU Switch Manager
 * Provides token endpoints for AJAX requests
 */

class CsrfController {
    private $webInterface;
    private $logFile;

    /**
     * Constructor
     *
     * @param WebInterface $webInterface Web interface instance
     * @param string $logFile Log file path
     */
    public function __construct($webInterface = null, $logFile = null) {
        $this->webInterface = $webInterface ?? new WebInterface();
        $this->logFile = $logFile ?? '/var/log/gpu.switch.manager.log';
    }

    /**
     * Get CSRF token
     *
     * @return array CSRF token data
     */
    public function getToken() {
        try {
            $token = $this->webInterface->generateCSRF();

            $response = [
                'success' => true,
                'token' => $token,
                'headerName' => 'X-CSRF-Token',
                'parameterName' => 'csrf_token',
                'metadata' => $this->webInterface->getCSRFMetadata()
            ];

            $this->log('info', 'CSRF token generated');

            return $response;
        } catch (Exception $e) {
            $this->log('error', 'Failed to generate CSRF token: ' . $e->getMessage());

            return [
                'success' => false,
                'error' => 'Failed to generate CSRF token'
            ];
        }
    }

    /**
     * Validate CSRF token
     *
     * @param string $token CSRF token to validate
     * @return array Validation result
     */
    public function validateToken($token) {
        try {
            $valid = $this->webInterface->validateCSRF($token, false); // Don't rotate on validation

            $response = [
                'success' => true,
                'valid' => $valid,
                'metadata' => $this->webInterface->getCSRFMetadata()
            ];

            $this->log('info', 'CSRF token validation: ' . ($valid ? 'valid' : 'invalid'));

            return $response;
        } catch (Exception $e) {
            $this->log('error', 'Failed to validate CSRF token: ' . $e->getMessage());

            return [
                'success' => false,
                'error' => 'Failed to validate CSRF token'
            ];
        }
    }

    /**
     * Refresh CSRF token
     *
     * @return array New token data
     */
    public function refreshToken() {
        try {
            // Generate new token
            $token = $this->webInterface->generateCSRF();

            $response = [
                'success' => true,
                'token' => $token,
                'headerName' => 'X-CSRF-Token',
                'parameterName' => 'csrf_token',
                'metadata' => $this->webInterface->getCSRFMetadata(),
                'message' => 'CSRF token refreshed successfully'
            ];

            $this->log('info', 'CSRF token refreshed');

            return $response;
        } catch (Exception $e) {
            $this->log('error', 'Failed to refresh CSRF token: ' . $e->getMessage());

            return [
                'success' => false,
                'error' => 'Failed to refresh CSRF token'
            ];
        }
    }

    /**
     * Get CSRF metadata
     *
     * @return array CSRF metadata
     */
    public function getMetadata() {
        try {
            $metadata = $this->webInterface->getCSRFMetadata();

            $response = [
                'success' => true,
                'metadata' => $metadata
            ];

            return $response;
        } catch (Exception $e) {
            $this->log('error', 'Failed to get CSRF metadata: ' . $e->getMessage());

            return [
                'success' => false,
                'error' => 'Failed to get CSRF metadata'
            ];
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
        $logMessage = "[$timestamp] [$level] [CSRF_CONTROLLER] $message\n";

        if (file_exists($this->logFile)) {
            file_put_contents($this->logFile, $logMessage, FILE_APPEND);
        }
    }
}