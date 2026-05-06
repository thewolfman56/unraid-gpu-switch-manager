<?php

/**
 * ConfigBackup.php
 * Configuration backup manager for GPU Switch Manager
 * Provides configuration backup and restore capabilities
 */

class ConfigBackup {
    private $backupDir;
    private $configFile;
    private $logFile;

    /**
     * Constructor
     *
     * @param string $backupDir Backup directory path
     * @param string $configFile Configuration file path
     * @param string $logFile Log file path
     */
    public function __construct($backupDir = null, $configFile = null, $logFile = null) {
        $this->backupDir = $backupDir ?? dirname(__DIR__) . '/config/backups';
        $this->configFile = $configFile ?? dirname(__DIR__) . '/config/config.json';
        $this->logFile = $logFile ?? '/var/log/gpu.switch.manager.log';

        // Initialize backup directory
        $this->initBackupDir();
    }

    /**
     * Initialize backup directory
     *
     * @return bool Success status
     */
    private function initBackupDir() {
        if (!is_dir($this->backupDir)) {
            mkdir($this->backupDir, 0755, true);
        }

        return true;
    }

    /**
     * Create backup
     *
     * @param string $configPath Configuration file path
     * @param bool $compress Whether to compress backup
     * @return string Backup file path
     * @throws Exception If configuration file not found
     */
    public function createBackup($configPath = null, $compress = true) {
        $configPath = $configPath ?? $this->configFile;

        if (!file_exists($configPath)) {
            throw new Exception("Configuration file not found: $configPath");
        }

        // Initialize backup directory
        $this->initBackupDir();

        // Create backup file
        $timestamp = date('Ymd_His');
        $backupFile = $this->backupDir . '/config_' . $timestamp . '.json';

        // Copy configuration
        copy($configPath, $backupFile);

        // Compress if requested
        if ($compress) {
            $compressed = gzencode(file_get_contents($backupFile), 9);
            if ($compressed === false) {
                throw new Exception("Failed to compress backup");
            }
            file_put_contents($backupFile . '.gz', $compressed);
            unlink($backupFile);
            $backupFile .= '.gz';
        }

        $backupSize = filesize($backupFile);

        $this->log('INFO', "Created backup: $backupFile");

        return $backupFile;
    }

    /**
     * List backups
     *
     * @return array List of backups
     */
    public function listBackups() {
        $backups = [];

        foreach (glob($this->backupDir . '/config_*.json*') as $backupFile) {
            $backupName = basename($backupFile);
            $backupSize = filesize($backupFile);
            $backupDate = filemtime($backupFile);
            $backupDateFormatted = date('Y-m-d H:i:s', $backupDate);

            $backups[] = [
                'name' => $backupName,
                'size' => $backupSize,
                'date' => $backupDateFormatted,
                'path' => $backupFile
            ];
        }

        // Sort by date (newest first)
        usort($backups, function($a, $b) {
            return filemtime($b['path']) - filemtime($a['path']);
        });

        return $backups;
    }

    /**
     * Restore backup
     *
     * @param string $backupFile Backup file path
     * @param string $configPath Configuration file path
     * @return bool Success status
     * @throws Exception If backup file not found or invalid
     */
    public function restoreBackup($backupFile, $configPath = null) {
        $configPath = $configPath ?? $this->configFile;

        if (!file_exists($backupFile)) {
            throw new Exception("Backup file not found: $backupFile");
        }

        // Decompress if needed
        $tempFile = $backupFile . '.tmp';
        if (preg_match('/\.gz$/', $backupFile)) {
            $content = gzdecode(file_get_contents($backupFile));
            if ($content === false) {
                throw new Exception("Failed to decompress backup");
            }
            file_put_contents($tempFile, $content);
        } else {
            copy($backupFile, $tempFile);
        }

        // Validate backup
        $config = json_decode(file_get_contents($tempFile), true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            unlink($tempFile);
            throw new Exception("Invalid backup file");
        }

        // Create backup of current configuration
        if (file_exists($configPath)) {
            $this->createBackup($configPath);
        }

        // Restore configuration
        copy($tempFile, $configPath);
        unlink($tempFile);

        $this->log('INFO', "Restored backup: $backupFile");

        return true;
    }

    /**
     * Delete backup
     *
     * @param string $backupFile Backup file path
     * @return bool Success status
     * @throws Exception If backup file not found
     */
    public function deleteBackup($backupFile) {
        if (!file_exists($backupFile)) {
            throw new Exception("Backup file not found: $backupFile");
        }

        unlink($backupFile);

        $this->log('INFO', "Deleted backup: $backupFile");

        return true;
    }

    /**
     * Automatic backup
     *
     * @param string $configPath Configuration file path
     * @param int $maxBackups Maximum number of backups to keep
     * @return bool Success status
     */
    public function autoBackup($configPath = null, $maxBackups = 10) {
        // Create backup
        $this->createBackup($configPath);

        // Cleanup old backups
        $this->cleanupBackups($maxBackups);

        return true;
    }

    /**
     * Schedule backup
     *
     * @param int $interval Backup interval in seconds
     * @param string $configPath Configuration file path
     * @return bool Success status
     */
    public function scheduleBackup($interval, $configPath = null) {
        $configPath = $configPath ?? $this->configFile;

        // Create cron job
        $cronInterval = (int)($interval / 60);
        $cronJob = "*/$cronInterval * * * * " . __DIR__ . "/../scripts/config_backup.sh auto_backup $configPath";

        // Add to crontab
        $currentCrontab = shell_exec('crontab -l 2>/dev/null') ?? '';
        $newCrontab = preg_replace('/.*config_backup\.sh.*/', '', $currentCrontab);
        $newCrontab = trim($newCrontab) . "\n" . $cronJob . "\n";

        file_put_contents('/tmp/crontab.tmp', $newCrontab);
        shell_exec('crontab /tmp/crontab.tmp');
        unlink('/tmp/crontab.tmp');

        $this->log('INFO', "Scheduled backup every $interval seconds");

        return true;
    }

    /**
     * Verify backup
     *
     * @param string $backupFile Backup file path
     * @return array Verification result
     * @throws Exception If backup file not found
     */
    public function verifyBackup($backupFile) {
        if (!file_exists($backupFile)) {
            throw new Exception("Backup file not found: $backupFile");
        }

        $valid = false;
        $errors = [];

        // Decompress if needed
        $tempFile = $backupFile . '.tmp';
        if (preg_match('/\.gz$/', $backupFile)) {
            $content = gzdecode(file_get_contents($backupFile));
            if ($content === false) {
                $errors[] = "Failed to decompress backup";
            } else {
                file_put_contents($tempFile, $content);
            }
        } else {
            copy($backupFile, $tempFile);
        }

        // Validate JSON
        $config = json_decode(file_get_contents($tempFile), true);
        if (json_last_error() === JSON_ERROR_NONE) {
            $valid = true;

            // Check required fields
            $requiredFields = ['version', 'profiles', 'preferences', 'services'];
            foreach ($requiredFields as $field) {
                if (!isset($config[$field])) {
                    $valid = false;
                    $errors[] = "Missing required field: $field";
                }
            }
        } else {
            $errors[] = "Invalid JSON";
        }

        // Cleanup temp file
        if (file_exists($tempFile)) {
            unlink($tempFile);
        }

        return [
            'valid' => $valid,
            'backup_file' => $backupFile,
            'errors' => $errors
        ];
    }

    /**
     * Compress backup
     *
     * @param string $backupFile Backup file path
     * @return string Compressed backup file path
     * @throws Exception If backup file not found or already compressed
     */
    public function compressBackup($backupFile) {
        if (!file_exists($backupFile)) {
            throw new Exception("Backup file not found: $backupFile");
        }

        if (preg_match('/\.gz$/', $backupFile)) {
            throw new Exception("Backup already compressed");
        }

        // Compress backup
        $compressed = gzencode(file_get_contents($backupFile), 9);
        if ($compressed === false) {
            throw new Exception("Failed to compress backup");
        }

        $compressedFile = $backupFile . '.gz';
        file_put_contents($compressedFile, $compressed);
        unlink($backupFile);

        $compressedSize = filesize($compressedFile);

        $this->log('INFO', "Compressed backup: $backupFile");

        return $compressedFile;
    }

    /**
     * Decompress backup
     *
     * @param string $backupFile Backup file path
     * @return string Decompressed backup file path
     * @throws Exception If backup file not found or not compressed
     */
    public function decompressBackup($backupFile) {
        if (!file_exists($backupFile)) {
            throw new Exception("Backup file not found: $backupFile");
        }

        if (!preg_match('/\.gz$/', $backupFile)) {
            throw new Exception("Backup not compressed");
        }

        // Decompress backup
        $content = gzdecode(file_get_contents($backupFile));
        if ($content === false) {
            throw new Exception("Failed to decompress backup");
        }

        $decompressedFile = substr($backupFile, 0, -3);
        file_put_contents($decompressedFile, $content);
        unlink($backupFile);

        $decompressedSize = filesize($decompressedFile);

        $this->log('INFO', "Decompressed backup: $backupFile");

        return $decompressedFile;
    }

    /**
     * Cleanup old backups
     *
     * @param int $maxBackups Maximum number of backups to keep
     * @return array Cleanup result
     */
    public function cleanupBackups($maxBackups = 10) {
        $backupCount = 0;
        $deletedCount = 0;

        // List backups sorted by date (oldest first)
        $backups = glob($this->backupDir . '/config_*.json*');
        usort($backups, function($a, $b) {
            return filemtime($a) - filemtime($b);
        });

        foreach ($backups as $backupFile) {
            if (file_exists($backupFile)) {
                $backupCount++;

                // Delete old backups beyond max
                if ($backupCount > $maxBackups) {
                    unlink($backupFile);
                    $deletedCount++;
                    $this->log('INFO', "Deleted old backup: $backupFile");
                }
            }
        }

        return [
            'success' => true,
            'deleted_count' => $deletedCount,
            'backup_count' => $backupCount
        ];
    }

    /**
     * Get backup info
     *
     * @param string $backupFile Backup file path
     * @return array Backup information
     * @throws Exception If backup file not found
     */
    public function getBackupInfo($backupFile) {
        if (!file_exists($backupFile)) {
            throw new Exception("Backup file not found: $backupFile");
        }

        $backupName = basename($backupFile);
        $backupSize = filesize($backupFile);
        $backupDate = filemtime($backupFile);
        $backupDateFormatted = date('Y-m-d H:i:s', $backupDate);

        // Get config version if possible
        $configVersion = 'unknown';
        $tempFile = $backupFile . '.tmp';

        if (preg_match('/\.gz$/', $backupFile)) {
            $content = gzdecode(file_get_contents($backupFile));
            if ($content !== false) {
                file_put_contents($tempFile, $content);
            }
        } else {
            copy($backupFile, $tempFile);
        }

        if (file_exists($tempFile)) {
            $config = json_decode(file_get_contents($tempFile), true);
            if (json_last_error() === JSON_ERROR_NONE && isset($config['version'])) {
                $configVersion = $config['version'];
            }
            unlink($tempFile);
        }

        return [
            'success' => true,
            'backup_name' => $backupName,
            'backup_size' => $backupSize,
            'backup_date' => $backupDateFormatted,
            'config_version' => $configVersion
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
        $logMessage = "[$timestamp] [$level] [CONFIG_BACKUP] $message\n";

        if (file_exists($this->logFile)) {
            file_put_contents($this->logFile, $logMessage, FILE_APPEND);
        }
    }
}
