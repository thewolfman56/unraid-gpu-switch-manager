<?php

/**
 * SecureFileOperations.php
 * Secure file operations for GPU Switch Manager
 * Handles file operations with security checks and validation
 */

class SecureFileOperations {
    private $pathValidator;
    private $logFile;
    private $maxFileSize;
    private $allowedMimeTypes;

    /**
     * Constructor
     *
     * @param PathValidator $pathValidator Path validator
     * @param string $logFile Log file path
     * @param int $maxFileSize Maximum file size in bytes
     */
    public function __construct($pathValidator = null, $logFile = null, $maxFileSize = null) {
        $this->pathValidator = $pathValidator ?? new PathValidator();
        $this->logFile = $logFile ?? '/var/log/gpu.switch.manager.log';
        $this->maxFileSize = $maxFileSize ?? 10485760; // 10MB default

        // Initialize allowed MIME types
        $this->allowedMimeTypes = [
            'application/json',
            'text/plain',
            'text/xml',
            'application/xml',
            'application/yaml',
            'text/yaml',
            'text/x-yaml'
        ];
    }

    /**
     * Read file securely
     *
     * @param string $filePath File path
     * @param string $basePath Base path
     * @return string File contents
     * @throws Exception If operation fails
     */
    public function readFile($filePath, $basePath = null) {
        try {
            $validatedPath = $this->pathValidator->validateFilePath($filePath, $basePath);

            if (!file_exists($validatedPath)) {
                throw new Exception('File not found');
            }

            if (!is_readable($validatedPath)) {
                throw new Exception('File not readable');
            }

            $content = file_get_contents($validatedPath);

            if ($content === false) {
                throw new Exception('Failed to read file');
            }

            $this->log('info', "File read successfully: $validatedPath");

            return $content;
        } catch (Exception $e) {
            $this->log('error', "File read error: " . $e->getMessage());
            throw $e;
        }
    }

    /**
     * Write file securely
     *
     * @param string $filePath File path
     * @param string $content File content
     * @param string $basePath Base path
     * @return bool Success status
     * @throws Exception If operation fails
     */
    public function writeFile($filePath, $content, $basePath = null) {
        try {
            $validatedPath = $this->pathValidator->validateFilePath($filePath, $basePath);

            // Check file size
            if (strlen($content) > $this->maxFileSize) {
                throw new Exception('File size exceeds maximum allowed size');
            }

            // Create directory if it doesn't exist
            $directory = dirname($validatedPath);
            if (!is_dir($directory)) {
                if (!mkdir($directory, 0700, true)) {
                    throw new Exception('Failed to create directory');
                }
            }

            // Write file with exclusive lock
            $result = file_put_contents($validatedPath, $content, LOCK_EX);

            if ($result === false) {
                throw new Exception('Failed to write file');
            }

            // Set secure permissions
            chmod($validatedPath, 0600);

            $this->log('info', "File written successfully: $validatedPath");

            return true;
        } catch (Exception $e) {
            $this->log('error', "File write error: " . $e->getMessage());
            throw $e;
        }
    }

    /**
     * Delete file securely
     *
     * @param string $filePath File path
     * @param string $basePath Base path
     * @return bool Success status
     * @throws Exception If operation fails
     */
    public function deleteFile($filePath, $basePath = null) {
        try {
            $validatedPath = $this->pathValidator->validateFilePath($filePath, $basePath);

            if (!file_exists($validatedPath)) {
                throw new Exception('File not found');
            }

            if (!is_writable($validatedPath)) {
                throw new Exception('File not writable');
            }

            if (!unlink($validatedPath)) {
                throw new Exception('Failed to delete file');
            }

            $this->log('info', "File deleted successfully: $validatedPath");

            return true;
        } catch (Exception $e) {
            $this->log('error', "File delete error: " . $e->getMessage());
            throw $e;
        }
    }

    /**
     * Create directory securely
     *
     * @param string $dirPath Directory path
     * @param string $basePath Base path
     * @param int $mode Directory permissions
     * @return bool Success status
     * @throws Exception If operation fails
     */
    public function createDirectory($dirPath, $basePath = null, $mode = 0700) {
        try {
            $validatedPath = $this->pathValidator->validateDirectoryPath($dirPath, $basePath);

            if (is_dir($validatedPath)) {
                throw new Exception('Directory already exists');
            }

            if (!mkdir($validatedPath, $mode, true)) {
                throw new Exception('Failed to create directory');
            }

            $this->log('info', "Directory created successfully: $validatedPath");

            return true;
        } catch (Exception $e) {
            $this->log('error', "Directory creation error: " . $e->getMessage());
            throw $e;
        }
    }

    /**
     * Delete directory securely
     *
     * @param string $dirPath Directory path
     * @param string $basePath Base path
     * @param bool $recursive Delete recursively
     * @return bool Success status
     * @throws Exception If operation fails
     */
    public function deleteDirectory($dirPath, $basePath = null, $recursive = false) {
        try {
            $validatedPath = $this->pathValidator->validateDirectoryPath($dirPath, $basePath);

            if (!is_dir($validatedPath)) {
                throw new Exception('Directory not found');
            }

            if ($recursive) {
                $this->deleteDirectoryRecursive($validatedPath);
            } else {
                if (!rmdir($validatedPath)) {
                    throw new Exception('Failed to delete directory (not empty?)');
                }
            }

            $this->log('info', "Directory deleted successfully: $validatedPath");

            return true;
        } catch (Exception $e) {
            $this->log('error', "Directory delete error: " . $e->getMessage());
            throw $e;
        }
    }

    /**
     * List directory contents securely
     *
     * @param string $dirPath Directory path
     * @param string $basePath Base path
     * @return array Directory contents
     * @throws Exception If operation fails
     */
    public function listDirectory($dirPath, $basePath = null) {
        try {
            $validatedPath = $this->pathValidator->validateDirectoryPath($dirPath, $basePath);

            if (!is_dir($validatedPath)) {
                throw new Exception('Directory not found');
            }

            if (!is_readable($validatedPath)) {
                throw new Exception('Directory not readable');
            }

            $contents = scandir($validatedPath);

            if ($contents === false) {
                throw new Exception('Failed to read directory');
            }

            // Remove . and ..
            $contents = array_filter($contents, function($item) {
                return $item !== '.' && $item !== '..';
            });

            $this->log('info', "Directory listed successfully: $validatedPath");

            return array_values($contents);
        } catch (Exception $e) {
            $this->log('error', "Directory list error: " . $e->getMessage());
            throw $e;
        }
    }

    /**
     * Upload file securely
     *
     * @param array $fileData File data from $_FILES
     * @param string $destination Destination path
     * @param string $basePath Base path
     * @return string Uploaded file path
     * @throws Exception If operation fails
     */
    public function uploadFile($fileData, $destination, $basePath = null) {
        try {
            // Validate file data
            if (!isset($fileData['tmp_name']) || !isset($fileData['name']) || !isset($fileData['size'])) {
                throw new Exception('Invalid file data');
            }

            // Check for upload errors
            if ($fileData['error'] !== UPLOAD_ERR_OK) {
                throw new Exception('File upload error: ' . $fileData['error']);
            }

            // Validate file size
            if ($fileData['size'] > $this->maxFileSize) {
                throw new Exception('File size exceeds maximum allowed size');
            }

            // Validate MIME type
            $finfo = new finfo(FILEINFO_MIME_TYPE);
            $mimeType = $finfo->file($fileData['tmp_name']);

            if (!in_array($mimeType, $this->allowedMimeTypes)) {
                throw new Exception('Invalid file type: ' . $mimeType);
            }

            // Sanitize filename
            $sanitizedFilename = $this->pathValidator->sanitizeFilename($fileData['name']);

            // Validate destination path
            $validatedDestination = $this->pathValidator->validateFilePath($destination, $basePath);

            // Create directory if it doesn't exist
            $directory = dirname($validatedDestination);
            if (!is_dir($directory)) {
                if (!mkdir($directory, 0700, true)) {
                    throw new Exception('Failed to create directory');
                }
            }

            // Move uploaded file
            if (!move_uploaded_file($fileData['tmp_name'], $validatedDestination)) {
                throw new Exception('Failed to move uploaded file');
            }

            // Set secure permissions
            chmod($validatedDestination, 0600);

            $this->log('info', "File uploaded successfully: $validatedDestination");

            return $validatedDestination;
        } catch (Exception $e) {
            $this->log('error', "File upload error: " . $e->getMessage());
            throw $e;
        }
    }

    /**
     * Copy file securely
     *
     * @param string $source Source file path
     * @param string $destination Destination file path
     * @param string $basePath Base path
     * @return bool Success status
     * @throws Exception If operation fails
     */
    public function copyFile($source, $destination, $basePath = null) {
        try {
            $validatedSource = $this->pathValidator->validateFilePath($source, $basePath);
            $validatedDestination = $this->pathValidator->validateFilePath($destination, $basePath);

            if (!file_exists($validatedSource)) {
                throw new Exception('Source file not found');
            }

            if (!is_readable($validatedSource)) {
                throw new Exception('Source file not readable');
            }

            // Check file size
            $fileSize = filesize($validatedSource);
            if ($fileSize > $this->maxFileSize) {
                throw new Exception('File size exceeds maximum allowed size');
            }

            // Create directory if it doesn't exist
            $directory = dirname($validatedDestination);
            if (!is_dir($directory)) {
                if (!mkdir($directory, 0700, true)) {
                    throw new Exception('Failed to create directory');
                }
            }

            if (!copy($validatedSource, $validatedDestination)) {
                throw new Exception('Failed to copy file');
            }

            // Set secure permissions
            chmod($validatedDestination, 0600);

            $this->log('info', "File copied successfully: $validatedSource -> $validatedDestination");

            return true;
        } catch (Exception $e) {
            $this->log('error', "File copy error: " . $e->getMessage());
            throw $e;
        }
    }

    /**
     * Move file securely
     *
     * @param string $source Source file path
     * @param string $destination Destination file path
     * @param string $basePath Base path
     * @return bool Success status
     * @throws Exception If operation fails
     */
    public function moveFile($source, $destination, $basePath = null) {
        try {
            $validatedSource = $this->pathValidator->validateFilePath($source, $basePath);
            $validatedDestination = $this->pathValidator->validateFilePath($destination, $basePath);

            if (!file_exists($validatedSource)) {
                throw new Exception('Source file not found');
            }

            if (!is_writable($validatedSource)) {
                throw new Exception('Source file not writable');
            }

            // Create directory if it doesn't exist
            $directory = dirname($validatedDestination);
            if (!is_dir($directory)) {
                if (!mkdir($directory, 0700, true)) {
                    throw new Exception('Failed to create directory');
                }
            }

            if (!rename($validatedSource, $validatedDestination)) {
                throw new Exception('Failed to move file');
            }

            $this->log('info', "File moved successfully: $validatedSource -> $validatedDestination");

            return true;
        } catch (Exception $e) {
            $this->log('error', "File move error: " . $e->getMessage());
            throw $e;
        }
    }

    /**
     * Get file info securely
     *
     * @param string $filePath File path
     * @param string $basePath Base path
     * @return array File information
     * @throws Exception If operation fails
     */
    public function getFileInfo($filePath, $basePath = null) {
        try {
            $validatedPath = $this->pathValidator->validateFilePath($filePath, $basePath);

            if (!file_exists($validatedPath)) {
                throw new Exception('File not found');
            }

            $info = [
                'path' => $validatedPath,
                'size' => filesize($validatedPath),
                'modified' => filemtime($validatedPath),
                'type' => filetype($validatedPath),
                'readable' => is_readable($validatedPath),
                'writable' => is_writable($validatedPath)
            ];

            return $info;
        } catch (Exception $e) {
            $this->log('error', "File info error: " . $e->getMessage());
            throw $e;
        }
    }

    /**
     * Delete directory recursively
     *
     * @param string $dirPath Directory path
     * @return void
     */
    private function deleteDirectoryRecursive($dirPath) {
        $files = array_diff(scandir($dirPath), ['.', '..']);

        foreach ($files as $file) {
            $filePath = $dirPath . '/' . $file;

            if (is_dir($filePath)) {
                $this->deleteDirectoryRecursive($filePath);
            } else {
                unlink($filePath);
            }
        }

        rmdir($dirPath);
    }

    /**
     * Set maximum file size
     *
     * @param int $size Maximum file size in bytes
     * @return void
     */
    public function setMaxFileSize($size) {
        $this->maxFileSize = $size;
    }

    /**
     * Get maximum file size
     *
     * @return int Maximum file size in bytes
     */
    public function getMaxFileSize() {
        return $this->maxFileSize;
    }

    /**
     * Add allowed MIME type
     *
     * @param string $mimeType MIME type
     * @return void
     */
    public function addAllowedMimeType($mimeType) {
        if (!in_array($mimeType, $this->allowedMimeTypes)) {
            $this->allowedMimeTypes[] = $mimeType;
        }
    }

    /**
     * Remove allowed MIME type
     *
     * @param string $mimeType MIME type
     * @return void
     */
    public function removeAllowedMimeType($mimeType) {
        $this->allowedMimeTypes = array_filter($this->allowedMimeTypes, function($allowed) use ($mimeType) {
            return $allowed !== $mimeType;
        });
    }

    /**
     * Get allowed MIME types
     *
     * @return array Allowed MIME types
     */
    public function getAllowedMimeTypes() {
        return $this->allowedMimeTypes;
    }

    /**
     * Log message
     *
     * @param string $level Log level
     * @param string $message Log message
     */
    private function log($level, $message) {
        $timestamp = date('Y-m-d H:i:s');
        $logMessage = "[$timestamp] [$level] [SECURE_FILE_OPS] $message\n";

        if (file_exists($this->logFile)) {
            file_put_contents($this->logFile, $logMessage, FILE_APPEND);
        }
    }
}
