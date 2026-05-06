<?php

/**
 * BackupsController.php
 * Backup management controller for GPU Switch Manager
 * Handles backup creation, restoration, deletion, and scheduling
 */

class BackupsController {
    private $webInterface;
    private $configBackup;
    private $securityMiddleware;
    private $secureErrorHandler;
    private $logFile;

    /**
     * Constructor
     *
     * @param WebInterface $webInterface Web interface instance
     * @param SecurityMiddleware $securityMiddleware Security middleware
     * @param SecureErrorHandler $secureErrorHandler Secure error handler
     * @param string $logFile Log file path
     */
    public function __construct($webInterface = null, $securityMiddleware = null, $secureErrorHandler = null, $logFile = null) {
        $this->webInterface = $webInterface ?? new WebInterface();
        $this->securityMiddleware = $securityMiddleware ?? new SecurityMiddleware();
        $this->secureErrorHandler = $secureErrorHandler ?? new SecureErrorHandler($logFile);
        $this->logFile = $logFile ?? '/var/log/gpu.switch.manager.log';

        // Initialize config backup
        $this->configBackup = new ConfigBackup();
    }

    /**
     * Backups main page
     *
     * @return string Rendered page
     */
    public function index() {
        try {
            // Require authentication
            $user = $this->securityMiddleware->process('backups', 'read', true);

            $backups = $this->listBackups();
            $backupInfo = $this->getBackupInfo();

            $data = [
                'title' => 'Backup Management',
                'backups' => $backups,
                'backupInfo' => $backupInfo,
                'backupCount' => count($backups['data'] ?? []),
                'user' => $user
            ];

            return $this->webInterface->renderPage('backups/index', $data);
        } catch (Exception $e) {
            $this->log('error', 'Failed to load backups page: ' . $e->getMessage());
            return $this->webInterface->renderError('Failed to load backup information');
        }
    }

    /**
     * Create backup
     *
     * @param string $description Backup description
     * @return array Create result
     */
    public function createBackup($description = null) {
        try {
            // Validate CSRF token
            if (!$this->webInterface->validateCSRF()) {
                throw new Exception('Invalid CSRF token');
            }

            // Create backup
            $backup = $this->configBackup->createBackup($description);

            $this->log('info', 'Backup created successfully');

            return [
                'success' => true,
                'data' => $backup,
                'message' => 'Backup created successfully'
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to create backup: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Restore backup
     *
     * @param string $backupId Backup ID
     * @return array Restore result
     */
    public function restoreBackup($backupId) {
        try {
            // Validate CSRF token
            if (!$this->webInterface->validateCSRF()) {
                throw new Exception('Invalid CSRF token');
            }

            // Validate backup ID
            if (empty($backupId)) {
                throw new Exception('Backup ID is required');
            }

            // Verify backup exists
            $backups = $this->configBackup->listBackups();
            $backupExists = false;
            foreach ($backups as $backup) {
                if ($backup['id'] === $backupId) {
                    $backupExists = true;
                    break;
                }
            }

            if (!$backupExists) {
                throw new Exception('Backup not found');
            }

            // Create pre-restore backup
            $preRestoreBackup = $this->configBackup->createBackup('pre-restore');

            // Restore backup
            $result = $this->configBackup->restoreBackup($backupId);

            $this->log('info', "Backup $backupId restored successfully");

            return [
                'success' => true,
                'data' => $result,
                'message' => 'Backup restored successfully',
                'preRestoreBackup' => $preRestoreBackup
            ];
        } catch (Exception $e) {
            $this->log('error', "Failed to restore backup $backupId: " . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Delete backup
     *
     * @param string $backupId Backup ID
     * @return array Delete result
     */
    public function deleteBackup($backupId) {
        try {
            // Validate CSRF token
            if (!$this->webInterface->validateCSRF()) {
                throw new Exception('Invalid CSRF token');
            }

            // Validate backup ID
            if (empty($backupId)) {
                throw new Exception('Backup ID is required');
            }

            // Verify backup exists
            $backups = $this->configBackup->listBackups();
            $backupExists = false;
            foreach ($backups as $backup) {
                if ($backup['id'] === $backupId) {
                    $backupExists = true;
                    break;
                }
            }

            if (!$backupExists) {
                throw new Exception('Backup not found');
            }

            // Delete backup
            $result = $this->configBackup->deleteBackup($backupId);

            $this->log('info', "Backup $backupId deleted successfully");

            return [
                'success' => true,
                'data' => $result,
                'message' => 'Backup deleted successfully'
            ];
        } catch (Exception $e) {
            $this->log('error', "Failed to delete backup $backupId: " . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * List backups
     *
     * @return array Backup list
     */
    public function listBackups() {
        try {
            $backups = $this->configBackup->listBackups();

            return [
                'success' => true,
                'data' => $backups,
                'count' => count($backups)
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to list backups: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Get backup info
     *
     * @param string $backupId Backup ID
     * @return array Backup info
     */
    public function getBackupInfo($backupId = null) {
        try {
            if ($backupId !== null) {
                // Get specific backup info
                $info = $this->configBackup->getBackupInfo($backupId);

                if ($info === null) {
                    throw new Exception('Backup not found');
                }

                return [
                    'success' => true,
                    'data' => $info
                ];
            } else {
                // Get general backup info
                $backups = $this->configBackup->listBackups();

                $totalSize = 0;
                $oldestBackup = null;
                $newestBackup = null;

                foreach ($backups as $backup) {
                    $totalSize += $backup['size'] ?? 0;

                    if ($oldestBackup === null || $backup['created'] < $oldestBackup['created']) {
                        $oldestBackup = $backup;
                    }

                    if ($newestBackup === null || $backup['created'] > $newestBackup['created']) {
                        $newestBackup = $backup;
                    }
                }

                $info = [
                    'totalBackups' => count($backups),
                    'totalSize' => $totalSize,
                    'oldestBackup' => $oldestBackup,
                    'newestBackup' => $newestBackup,
                    'averageSize' => count($backups) > 0 ? $totalSize / count($backups) : 0
                ];

                return [
                    'success' => true,
                    'data' => $info
                ];
            }
        } catch (Exception $e) {
            $this->log('error', "Failed to get backup info for $backupId: " . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Schedule backup
     *
     * @param string $schedule Backup schedule (daily, weekly, monthly)
     * @param string $time Backup time (HH:MM)
     * @return array Schedule result
     */
    public function scheduleBackup($schedule, $time = null) {
        try {
            // Validate CSRF token
            if (!$this->webInterface->validateCSRF()) {
                throw new Exception('Invalid CSRF token');
            }

            // Validate schedule
            if (!in_array($schedule, ['daily', 'weekly', 'monthly'])) {
                throw new Exception('Invalid schedule. Must be daily, weekly, or monthly');
            }

            // Validate time format
            if ($time !== null && !preg_match('/^([01]?[0-9]|2[0-3]):[0-5][0-9]$/', $time)) {
                throw new Exception('Invalid time format. Must be HH:MM');
            }

            // Schedule backup
            $result = $this->configBackup->scheduleBackup($schedule, $time);

            $this->log('info', "Backup scheduled successfully: $schedule at $time");

            return [
                'success' => true,
                'data' => $result,
                'message' => 'Backup scheduled successfully'
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to schedule backup: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Verify backup
     *
     * @param string $backupId Backup ID
     * @return array Verification result
     */
    public function verifyBackup($backupId) {
        try {
            // Validate backup ID
            if (empty($backupId)) {
                throw new Exception('Backup ID is required');
            }

            // Verify backup
            $result = $this->configBackup->verifyBackup($backupId);

            $this->log('info', "Backup $backupId verified successfully");

            return [
                'success' => true,
                'data' => $result,
                'message' => 'Backup verified successfully'
            ];
        } catch (Exception $e) {
            $this->log('error', "Failed to verify backup $backupId: " . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Cleanup old backups
     *
     * @param int $retentionCount Number of backups to keep
     * @return array Cleanup result
     */
    public function cleanupBackups($retentionCount = null) {
        try {
            // Validate CSRF token
            if (!$this->webInterface->validateCSRF()) {
                throw new Exception('Invalid CSRF token');
            }

            // Cleanup backups
            $result = $this->configBackup->cleanupBackups($retentionCount);

            $this->log('info', 'Old backups cleaned up successfully');

            return [
                'success' => true,
                'data' => $result,
                'message' => 'Old backups cleaned up successfully'
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to cleanup backups: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Download backup
     *
     * @param string $backupId Backup ID
     * @return array Download result
     */
    public function downloadBackup($backupId) {
        try {
            // Validate backup ID
            if (empty($backupId)) {
                throw new Exception('Backup ID is required');
            }

            // Get backup info
            $backupInfo = $this->configBackup->getBackupInfo($backupId);

            if ($backupInfo === null) {
                throw new Exception('Backup not found');
            }

            // Get backup file path
            $backupFile = $backupInfo['file'] ?? null;

            if ($backupFile === null || !file_exists($backupFile)) {
                throw new Exception('Backup file not found');
            }

            // Read backup file
            $backupData = file_get_contents($backupFile);

            $this->log('info', "Backup $backupId downloaded successfully");

            return [
                'success' => true,
                'data' => $backupData,
                'filename' => basename($backupFile),
                'size' => strlen($backupData),
                'message' => 'Backup downloaded successfully'
            ];
        } catch (Exception $e) {
            $this->log('error', "Failed to download backup $backupId: " . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Get backup statistics
     *
     * @return array Backup statistics
     */
    public function getBackupStatistics() {
        try {
            $backups = $this->configBackup->listBackups();

            $statistics = [
                'total' => count($backups),
                'totalSize' => 0,
                'averageSize' => 0,
                'oldest' => null,
                'newest' => null,
                'byDay' => [],
                'byWeek' => [],
                'byMonth' => []
            ];

            foreach ($backups as $backup) {
                $size = $backup['size'] ?? 0;
                $created = $backup['created'] ?? null;

                $statistics['totalSize'] += $size;

                if ($created !== null) {
                    $date = date('Y-m-d', $created);
                    $week = date('Y-W', $created);
                    $month = date('Y-m', $created);

                    if (!isset($statistics['byDay'][$date])) {
                        $statistics['byDay'][$date] = 0;
                    }
                    $statistics['byDay'][$date]++;

                    if (!isset($statistics['byWeek'][$week])) {
                        $statistics['byWeek'][$week] = 0;
                    }
                    $statistics['byWeek'][$week]++;

                    if (!isset($statistics['byMonth'][$month])) {
                        $statistics['byMonth'][$month] = 0;
                    }
                    $statistics['byMonth'][$month]++;

                    if ($statistics['oldest'] === null || $created < $statistics['oldest']) {
                        $statistics['oldest'] = $created;
                    }

                    if ($statistics['newest'] === null || $created > $statistics['newest']) {
                        $statistics['newest'] = $created;
                    }
                }
            }

            if (count($backups) > 0) {
                $statistics['averageSize'] = $statistics['totalSize'] / count($backups);
            }

            return [
                'success' => true,
                'data' => $statistics
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to get backup statistics: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
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
        $logMessage = "[$timestamp] [$level] [BACKUPS_CONTROLLER] $message\n";

        if (file_exists($this->logFile)) {
            file_put_contents($this->logFile, $logMessage, FILE_APPEND);
        }
    }
}
