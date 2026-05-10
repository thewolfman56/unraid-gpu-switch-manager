<?php

/**
 * PathValidator.php
 * Path validator for GPU Switch Manager
 * Handles path validation and prevents directory traversal attacks
 */

class PathValidator {
    private $allowedBasePaths;
    private $logFile;

    /**
     * Constructor
     *
     * @param array $allowedBasePaths Allowed base paths
     * @param string $logFile Log file path
     */
    public function __construct($allowedBasePaths = null, $logFile = null) {
        $this->logFile = $logFile ?? '/var/log/gpu.switch.manager.log';

        // Initialize default allowed base paths
        $this->allowedBasePaths = $allowedBasePaths ?? [
            '/var/lib/gpu-switch-manager',
            '/var/log/gpu-switch-manager',
            '/tmp/gpu-switch-manager',
            '/usr/local/emhttp/plugins/gpu-switch-manager'
        ];
    }

    /**
     * Validate path
     *
     * @param string $path Path to validate
     * @param string $basePath Base path to validate against
     * @return string Validated and normalized path
     * @throws Exception If invalid
     */
    public function validatePath($path, $basePath = null) {
        if (empty($path)) {
            throw new Exception('Path is required');
        }

        // Normalize path
        $normalizedPath = $this->normalizePath($path);

        // Check for directory traversal
        if ($this->containsDirectoryTraversal($normalizedPath)) {
            $this->log('warning', "Directory traversal attempt detected: $path");
            throw new Exception('Invalid path: directory traversal detected');
        }

        // Check for absolute path outside allowed paths
        if ($this->isAbsolutePath($normalizedPath)) {
            if (!$this->isAllowedPath($normalizedPath)) {
                $this->log('warning', "Access to disallowed absolute path attempted: $path");
                throw new Exception('Invalid path: path outside allowed directories');
            }
        }

        // If base path provided, ensure path is within it
        if ($basePath !== null) {
            $normalizedBasePath = $this->normalizePath($basePath);
            $resolvedPath = $this->resolvePath($normalizedBasePath, $normalizedPath);

            if (!$this->isPathWithinBase($resolvedPath, $normalizedBasePath)) {
                $this->log('warning', "Path outside base directory attempted: $path (base: $basePath)");
                throw new Exception('Invalid path: path outside base directory');
            }

            return $resolvedPath;
        }

        return $normalizedPath;
    }

    /**
     * Validate file path
     *
     * @param string $filePath File path to validate
     * @param string $basePath Base path
     * @return string Validated file path
     * @throws Exception If invalid
     */
    public function validateFilePath($filePath, $basePath = null) {
        $validatedPath = $this->validatePath($filePath, $basePath);

        // Check for suspicious file extensions
        $suspiciousExtensions = ['.php', '.php3', '.php4', '.php5', '.phtml', '.sh', '.bash', '.pl', '.py', '.rb'];
        $extension = strtolower(pathinfo($validatedPath, PATHINFO_EXTENSION));

        if (in_array($extension, $suspiciousExtensions)) {
            $this->log('warning', "Suspicious file extension detected: $filePath");
            throw new Exception('Invalid file: suspicious file extension');
        }

        return $validatedPath;
    }

    /**
     * Validate directory path
     *
     * @param string $dirPath Directory path to validate
     * @param string $basePath Base path
     * @return string Validated directory path
     * @throws Exception If invalid
     */
    public function validateDirectoryPath($dirPath, $basePath = null) {
        $validatedPath = $this->validatePath($dirPath, $basePath);

        // Ensure path ends with separator
        if (substr($validatedPath, -1) !== '/') {
            $validatedPath .= '/';
        }

        return $validatedPath;
    }

    /**
     * Sanitize filename
     *
     * @param string $filename Filename to sanitize
     * @return string Sanitized filename
     * @throws Exception If invalid
     */
    public function sanitizeFilename($filename) {
        if (empty($filename)) {
            throw new Exception('Filename is required');
        }

        // Remove path separators
        $filename = str_replace(['/', '\\'], '', $filename);

        // Remove null bytes
        $filename = str_replace("\0", '', $filename);

        // Remove control characters
        $filename = preg_replace('/[\x00-\x1f\x7f]/', '', $filename);

        // Limit length
        if (strlen($filename) > 255) {
            throw new Exception('Filename too long (max 255 characters)');
        }

        // Check for reserved names (Windows)
        $reservedNames = ['CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9', 'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9'];
        $nameWithoutExt = pathinfo($filename, PATHINFO_FILENAME);

        if (in_array(strtoupper($nameWithoutExt), $reservedNames)) {
            throw new Exception('Invalid filename: reserved name');
        }

        // Check for invalid characters
        if (preg_match('/[<>:"|?*]/', $filename)) {
            throw new Exception('Invalid filename: contains invalid characters');
        }

        return $filename;
    }

    /**
     * Normalize path
     *
     * @param string $path Path to normalize
     * @return string Normalized path
     */
    private function normalizePath($path) {
        // Remove redundant slashes
        $path = preg_replace('/\/+/', '/', $path);

        // Remove trailing slash (unless it's root)
        if (strlen($path) > 1 && substr($path, -1) === '/') {
            $path = substr($path, 0, -1);
        }

        return $path;
    }

    /**
     * Check for directory traversal
     *
     * @param string $path Path to check
     * @return bool True if contains directory traversal
     */
    private function containsDirectoryTraversal($path) {
        // Check for ../ patterns
        if (strpos($path, '../') !== false || strpos($path, '..\\') !== false) {
            return true;
        }

        // Check for encoded traversal
        $decoded = urldecode($path);
        if (strpos($decoded, '../') !== false || strpos($decoded, '..\\') !== false) {
            return true;
        }

        return false;
    }

    /**
     * Check if path is absolute
     *
     * @param string $path Path to check
     * @return bool True if absolute
     */
    private function isAbsolutePath($path) {
        return substr($path, 0, 1) === '/';
    }

    /**
     * Check if path is allowed
     *
     * @param string $path Path to check
     * @return bool True if allowed
     */
    private function isAllowedPath($path) {
        foreach ($this->allowedBasePaths as $allowedPath) {
            if ($this->isPathWithinBase($path, $allowedPath)) {
                return true;
            }
        }

        return false;
    }

    /**
     * Check if path is within base path
     *
     * @param string $path Path to check
     * @param string $basePath Base path
     * @return bool True if within base
     */
    private function isPathWithinBase($path, $basePath) {
        $realPath = realpath($path);
        $realBasePath = realpath($basePath);

        if ($realPath === false || $realBasePath === false) {
            return false;
        }

        return strpos($realPath, $realBasePath) === 0;
    }

    /**
     * Resolve path relative to base
     *
     * @param string $basePath Base path
     * @param string $path Path to resolve
     * @return string Resolved path
     */
    private function resolvePath($basePath, $path) {
        if ($this->isAbsolutePath($path)) {
            return $path;
        }

        return $basePath . '/' . $path;
    }

    /**
     * Add allowed base path
     *
     * @param string $path Base path to add
     * @return void
     */
    public function addAllowedBasePath($path) {
        $normalizedPath = $this->normalizePath($path);

        if (!in_array($normalizedPath, $this->allowedBasePaths)) {
            $this->allowedBasePaths[] = $normalizedPath;
        }
    }

    /**
     * Remove allowed base path
     *
     * @param string $path Base path to remove
     * @return void
     */
    public function removeAllowedBasePath($path) {
        $normalizedPath = $this->normalizePath($path);
        $this->allowedBasePaths = array_filter($this->allowedBasePaths, function($allowed) use ($normalizedPath) {
            return $allowed !== $normalizedPath;
        });
    }

    /**
     * Get allowed base paths
     *
     * @return array Allowed base paths
     */
    public function getAllowedBasePaths() {
        return $this->allowedBasePaths;
    }

    /**
     * Log message
     *
     * @param string $level Log level
     * @param string $message Log message
     */
    private function log($level, $message) {
        $timestamp = date('Y-m-d H:i:s');
        $logMessage = "[$timestamp] [$level] [PATH_VALIDATOR] $message\n";

        if (file_exists($this->logFile)) {
            file_put_contents($this->logFile, $logMessage, FILE_APPEND);
        }
    }
}
