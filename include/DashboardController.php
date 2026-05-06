<?php

/**
 * DashboardController.php
 * Dashboard controller for GPU Switch Manager
 * Handles system overview, GPU status, recent events, and statistics
 */

class DashboardController {
    private $webInterface;
    private $gpuManager;
    private $eventHandler;
    private $configManager;
    private $securityMiddleware;
    private $logFile;

    /**
     * Constructor
     *
     * @param WebInterface $webInterface Web interface instance
     * @param SecurityMiddleware $securityMiddleware Security middleware
     * @param string $logFile Log file path
     */
    public function __construct($webInterface = null, $securityMiddleware = null, $logFile = null) {
        $this->webInterface = $webInterface ?? new WebInterface();
        $this->securityMiddleware = $securityMiddleware ?? new SecurityMiddleware();
        $this->logFile = $logFile ?? '/var/log/gpu.switch.manager.log';

        // Initialize managers
        $this->gpuManager = new GPUManager();
        $this->eventHandler = new EventHandler();
        $this->configManager = new ConfigManager();
    }

    /**
     * Dashboard main page
     *
     * @return string Rendered page
     */
    public function index() {
        try {
            // Require authentication
            $user = $this->securityMiddleware->process('dashboard', 'read', true);

            $systemStatus = $this->getSystemStatus();
            $gpuStatus = $this->getGPUStatus();
            $recentEvents = $this->getRecentEvents();
            $statistics = $this->getStatistics();
            $quickActions = $this->getQuickActions();

            $data = [
                'title' => 'Dashboard',
                'systemStatus' => $systemStatus,
                'gpuStatus' => $gpuStatus,
                'recentEvents' => $recentEvents,
                'statistics' => $statistics,
                'quickActions' => $quickActions,
                'user' => $user
            ];

            return $this->webInterface->renderPage('dashboard/index', $data);
        } catch (Exception $e) {
            $this->log('error', 'Failed to load dashboard: ' . $e->getMessage());
            throw new Exception('Failed to load dashboard: ' . $e->getMessage());
        }
    }

    /**
     * Get system status
     *
     * @return array System status
     */
    public function getSystemStatus() {
        try {
            $uptime = $this->getSystemUptime();
            $memoryUsage = $this->getMemoryUsage();
            $diskUsage = $this->getDiskUsage();
            $serviceStatus = $this->getServiceStatus();

            return [
                'success' => true,
                'data' => [
                    'uptime' => $uptime,
                    'memory' => $memoryUsage,
                    'disk' => $diskUsage,
                    'services' => $serviceStatus,
                    'timestamp' => time()
                ]
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to get system status: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Get GPU status
     *
     * @return array GPU status
     */
    public function getGPUStatus() {
        try {
            $gpus = $this->gpuManager->discoverGPUs();

            $gpuStatus = [];
            foreach ($gpus as $gpu) {
                $status = $this->gpuManager->getGPUStatus($gpu['address']);
                $gpuStatus[] = array_merge($gpu, $status);
            }

            return [
                'success' => true,
                'data' => $gpuStatus,
                'count' => count($gpuStatus)
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to get GPU status: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Get recent events
     *
     * @param int $count Number of events
     * @return array Recent events
     */
    public function getRecentEvents($count = 10) {
        try {
            $events = $this->eventHandler->getRecentEvents($count);

            return [
                'success' => true,
                'data' => $events,
                'count' => count($events)
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to get recent events: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Get statistics
     *
     * @param int $days Number of days to analyze
     * @return array Statistics
     */
    public function getStatistics($days = 7) {
        try {
            $eventStats = $this->eventHandler->getStatistics($days);
            $gpuStats = $this->getGPUStatistics();

            return [
                'success' => true,
                'data' => [
                    'events' => $eventStats,
                    'gpu' => $gpuStats,
                    'days' => $days
                ]
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to get statistics: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Get quick actions
     *
     * @return array Quick actions
     */
    public function getQuickActions() {
        try {
            $actions = [
                [
                    'id' => 'refresh_gpu',
                    'title' => 'Refresh GPU Discovery',
                    'description' => 'Re-scan for available GPUs',
                    'icon' => 'refresh',
                    'action' => 'refreshGPUDiscovery'
                ],
                [
                    'id' => 'create_backup',
                    'title' => 'Create Backup',
                    'description' => 'Create a configuration backup',
                    'icon' => 'backup',
                    'action' => 'createBackup'
                ],
                [
                    'id' => 'view_logs',
                    'title' => 'View Logs',
                    'description' => 'View recent log entries',
                    'icon' => 'logs',
                    'action' => 'viewLogs'
                ],
                [
                    'id' => 'system_info',
                    'title' => 'System Information',
                    'description' => 'View detailed system information',
                    'icon' => 'info',
                    'action' => 'viewSystemInfo'
                ]
            ];

            return [
                'success' => true,
                'data' => $actions
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to get quick actions: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Get system uptime
     *
     * @return string System uptime
     */
    private function getSystemUptime() {
        $uptimeFile = '/proc/uptime';

        if (file_exists($uptimeFile)) {
            $uptime = file_get_contents($uptimeFile);
            $uptime = explode(' ', $uptime)[0];
            $uptime = (int)$uptime;

            $days = floor($uptime / 86400);
            $hours = floor(($uptime % 86400) / 3600);
            $minutes = floor(($uptime % 3600) / 60);

            return sprintf('%d days, %d hours, %d minutes', $days, $hours, $minutes);
        }

        return 'Unknown';
    }

    /**
     * Get memory usage
     *
     * @return array Memory usage
     */
    private function getMemoryUsage() {
        $meminfoFile = '/proc/meminfo';

        if (file_exists($meminfoFile)) {
            $meminfo = file_get_contents($meminfoFile);
            preg_match_all('/(\w+):\s+(\d+)\s+kB/', $meminfo, $matches, PREG_SET_ORDER);

            $memory = [];
            foreach ($matches as $match) {
                $memory[$match[1]] = (int)$match[2] * 1024; // Convert to bytes
            }

            $total = $memory['MemTotal'] ?? 0;
            $free = $memory['MemFree'] ?? 0;
            $available = $memory['MemAvailable'] ?? $free;
            $used = $total - $available;

            return [
                'total' => $total,
                'used' => $used,
                'free' => $available,
                'percent' => $total > 0 ? round(($used / $total) * 100, 2) : 0
            ];
        }

        return [
            'total' => 0,
            'used' => 0,
            'free' => 0,
            'percent' => 0
        ];
    }

    /**
     * Get disk usage
     *
     * @return array Disk usage
     */
    private function getDiskUsage() {
        $diskFree = disk_free_space('/');
        $diskTotal = disk_total_space('/');

        if ($diskFree !== false && $diskTotal !== false) {
            $diskUsed = $diskTotal - $diskFree;

            return [
                'total' => $diskTotal,
                'used' => $diskUsed,
                'free' => $diskFree,
                'percent' => $diskTotal > 0 ? round(($diskUsed / $diskTotal) * 100, 2) : 0
            ];
        }

        return [
            'total' => 0,
            'used' => 0,
            'free' => 0,
            'percent' => 0
        ];
    }

    /**
     * Get service status
     *
     * @return array Service status
     */
    private function getServiceStatus() {
        $services = [
            'docker' => $this->checkServiceStatus('docker'),
            'libvirt' => $this->checkServiceStatus('libvirtd'),
            'gpu-switch-manager' => $this->checkServiceStatus('gpu-switch-manager')
        ];

        return $services;
    }

    /**
     * Check service status
     *
     * @param string $service Service name
     * @return array Service status
     */
    private function checkServiceStatus($service) {
        $status = shell_exec("systemctl is-active $service 2>/dev/null") ?? 'unknown';

        return [
            'name' => $service,
            'status' => trim($status),
            'running' => trim($status) === 'active'
        ];
    }

    /**
     * Get GPU statistics
     *
     * @return array GPU statistics
     */
    private function getGPUStatistics() {
        try {
            $gpus = $this->gpuManager->discoverGPUs();

            $statistics = [
                'total' => count($gpus),
                'bound' => 0,
                'unbound' => 0,
                'in_use' => 0,
                'available' => 0
            ];

            foreach ($gpus as $gpu) {
                $status = $this->gpuManager->getGPUStatus($gpu['address']);

                if ($status['bound'] ?? false) {
                    $statistics['bound']++;
                } else {
                    $statistics['unbound']++;
                }

                if ($status['in_use'] ?? false) {
                    $statistics['in_use']++;
                } else {
                    $statistics['available']++;
                }
            }

            return $statistics;
        } catch (Exception $e) {
            return [
                'total' => 0,
                'bound' => 0,
                'unbound' => 0,
                'in_use' => 0,
                'available' => 0
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
        $logMessage = "[$timestamp] [$level] [DASHBOARD_CONTROLLER] $message\n";

        if (file_exists($this->logFile)) {
            file_put_contents($this->logFile, $logMessage, FILE_APPEND);
        }
    }
}
