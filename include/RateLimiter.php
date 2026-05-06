<?php

/**
 * RateLimiter.php
 * Rate limiter for GPU Switch Manager
 * Implements rate limiting to prevent abuse and DoS attacks
 */

class RateLimiter {
    private $storage;
    private $limits;
    private $storageFile;
    private $logFile;

    /**
     * Constructor
     *
     * @param string $storageFile Storage file path
     * @param string $logFile Log file path
     */
    public function __construct($storageFile = null, $logFile = null) {
        $this->storageFile = $storageFile ?? '/var/lib/gpu-switch-manager/rate-limits.json';
        $this->logFile = $logFile ?? '/var/log/gpu.switch.manager.log';

        // Initialize storage
        $this->storage = $this->loadStorage();

        // Initialize default limits
        $this->limits = [
            'default' => [
                'requests' => 100,
                'window' => 60
            ],
            'auth' => [
                'requests' => 5,
                'window' => 60
            ],
            'write' => [
                'requests' => 10,
                'window' => 60
            ],
            'delete' => [
                'requests' => 5,
                'window' => 60
            ],
            'api' => [
                'requests' => 200,
                'window' => 60
            ]
        ];
    }

    /**
     * Check rate limit
     *
     * @param string $identifier Identifier (IP, user ID, etc.)
     * @param string $limitKey Limit key
     * @return bool Allow status
     */
    public function check($identifier, $limitKey = 'default') {
        try {
            $limit = $this->getLimit($limitKey);
            $now = time();
            $windowStart = $now - $limit['window'];

            // Get or create identifier data
            if (!isset($this->storage[$identifier])) {
                $this->storage[$identifier] = [];
            }

            if (!isset($this->storage[$identifier][$limitKey])) {
                $this->storage[$identifier][$limitKey] = [];
            }

            // Clean old requests
            $this->storage[$identifier][$limitKey] = array_filter(
                $this->storage[$identifier][$limitKey],
                function($timestamp) use ($windowStart) {
                    return $timestamp > $windowStart;
                }
            );

            // Check if limit exceeded
            $requestCount = count($this->storage[$identifier][$limitKey]);

            if ($requestCount >= $limit['requests']) {
                $this->log('warning', "Rate limit exceeded for $identifier: $limitKey");
                return false;
            }

            // Add current request
            $this->storage[$identifier][$limitKey][] = $now;

            // Save storage
            $this->saveStorage();

            return true;
        } catch (Exception $e) {
            $this->log('error', 'Rate limit check error: ' . $e->getMessage());
            // Fail open - allow request if rate limiter fails
            return true;
        }
    }

    /**
     * Get remaining requests
     *
     * @param string $identifier Identifier
     * @param string $limitKey Limit key
     * @return int Remaining requests
     */
    public function getRemaining($identifier, $limitKey = 'default') {
        $limit = $this->getLimit($limitKey);
        $now = time();
        $windowStart = $now - $limit['window'];

        if (!isset($this->storage[$identifier][$limitKey])) {
            return $limit['requests'];
        }

        // Clean old requests
        $this->storage[$identifier][$limitKey] = array_filter(
            $this->storage[$identifier][$limitKey],
            function($timestamp) use ($windowStart) {
                return $timestamp > $windowStart;
            }
        );

        $requestCount = count($this->storage[$identifier][$limitKey]);
        $remaining = max(0, $limit['requests'] - $requestCount);

        return $remaining;
    }

    /**
     * Get rate limit info
     *
     * @param string $identifier Identifier
     * @param string $limitKey Limit key
     * @return array Rate limit info
     */
    public function getInfo($identifier, $limitKey = 'default') {
        $limit = $this->getLimit($limitKey);
        $remaining = $this->getRemaining($identifier, $limitKey);
        $resetTime = time() + $limit['window'];

        return [
            'limit' => $limit['requests'],
            'remaining' => $remaining,
            'reset' => $resetTime,
            'window' => $limit['window']
        ];
    }

    /**
     * Reset rate limit for identifier
     *
     * @param string $identifier Identifier
     * @param string $limitKey Limit key
     * @return bool Success status
     */
    public function reset($identifier, $limitKey = null) {
        try {
            if (!isset($this->storage[$identifier])) {
                return false;
            }

            if ($limitKey !== null) {
                if (isset($this->storage[$identifier][$limitKey])) {
                    unset($this->storage[$identifier][$limitKey]);
                }
            } else {
                unset($this->storage[$identifier]);
            }

            $this->saveStorage();
            return true;
        } catch (Exception $e) {
            $this->log('error', 'Rate limit reset error: ' . $e->getMessage());
            return false;
        }
    }

    /**
     * Set custom limit
     *
     * @param string $limitKey Limit key
     * @param int $requests Max requests
     * @param int $window Time window in seconds
     * @return void
     */
    public function setLimit($limitKey, $requests, $window) {
        $this->limits[$limitKey] = [
            'requests' => $requests,
            'window' => $window
        ];
    }

    /**
     * Get limit
     *
     * @param string $limitKey Limit key
     * @return array Limit configuration
     */
    private function getLimit($limitKey) {
        return $this->limits[$limitKey] ?? $this->limits['default'];
    }

    /**
     * Load storage
     *
     * @return array Storage data
     */
    private function loadStorage() {
        if (!file_exists($this->storageFile)) {
            return [];
        }

        $content = file_get_contents($this->storageFile);
        $storage = json_decode($content, true);

        // Clean expired entries
        $now = time();
        foreach ($this->limits as $limitKey => $limit) {
            $windowStart = $now - $limit['window'];

            foreach ($storage as $identifier => $limits) {
                if (isset($limits[$limitKey])) {
                    $storage[$identifier][$limitKey] = array_filter(
                        $limits[$limitKey],
                        function($timestamp) use ($windowStart) {
                            return $timestamp > $windowStart;
                        }
                    );
                }
            }
        }

        return $storage ?? [];
    }

    /**
     * Save storage
     *
     * @return void
     */
    private function saveStorage() {
        $dir = dirname($this->storageFile);
        if (!is_dir($dir)) {
            mkdir($dir, 0700, true);
        }

        $content = json_encode($this->storage, JSON_PRETTY_PRINT);
        file_put_contents($this->storageFile, $content, LOCK_EX);
        chmod($this->storageFile, 0600);
    }

    /**
     * Log message
     *
     * @param string $level Log level
     * @param string $message Log message
     */
    private function log($level, $message) {
        $timestamp = date('Y-m-d H:i:s');
        $logMessage = "[$timestamp] [$level] [RATE_LIMITER] $message\n";

        if (file_exists($this->logFile)) {
            file_put_contents($this->logFile, $logMessage, FILE_APPEND);
        }
    }
}
