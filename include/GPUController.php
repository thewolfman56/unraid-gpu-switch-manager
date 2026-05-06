<?php

/**
 * GPUController.php
 * GPU management controller for GPU Switch Manager
 * Handles GPU discovery, status monitoring, binding, and switching
 */

class GPUController {
    private $webInterface;
    private $gpuManager;
    private $securityMiddleware;
    private $csrfMiddleware;
    private $secureErrorHandler;
    private $logFile;

    /**
     * Constructor
     *
     * @param WebInterface $webInterface Web interface instance
     * @param SecurityMiddleware $securityMiddleware Security middleware
     * @param CsrfMiddleware $csrfMiddleware CSRF middleware
     * @param SecureErrorHandler $secureErrorHandler Secure error handler
     * @param string $logFile Log file path
     */
    public function __construct($webInterface = null, $securityMiddleware = null, $csrfMiddleware = null, $secureErrorHandler = null, $logFile = null) {
        $this->webInterface = $webInterface ?? new WebInterface();
        $this->securityMiddleware = $securityMiddleware ?? new SecurityMiddleware();
        $this->csrfMiddleware = $csrfMiddleware ?? new CsrfMiddleware($this->webInterface);
        $this->secureErrorHandler = $secureErrorHandler ?? new SecureErrorHandler($logFile);
        $this->logFile = $logFile ?? '/var/log/gpu.switch.manager.log';

        // Initialize GPU manager
        $this->gpuManager = new GPUManager();
    }

    /**
     * GPU main page
     *
     * @return string Rendered page
     */
    public function index() {
        try {
            // Require authentication
            $user = $this->securityMiddleware->process('gpu', 'read', true);

            $gpus = $this->getGPUs();

            $data = [
                'title' => 'GPU Management',
                'gpus' => $gpus,
                'gpuCount' => count($gpus['data'] ?? []),
                'boundCount' => count(array_filter($gpus['data'] ?? [], function($gpu) {
                    return $gpu['bound'] ?? false;
                })),
                'user' => $user
            ];

            return $this->webInterface->renderPage('gpu/index', $data);
        } catch (Exception $e) {
            $this->log('error', 'Failed to load GPU page');
            $errorResponse = $this->secureErrorHandler->handleError('INTERNAL_ERROR', $e, [
                'action' => 'load_gpu_page'
            ]);
            return $this->webInterface->renderError($errorResponse['message']);
        }
    }

    /**
     * Get GPU list
     *
     * @return array GPU list
     */
    public function getGPUs() {
        try {
            $gpus = $this->gpuManager->discoverGPUs();

            $gpuList = [];
            foreach ($gpus as $gpu) {
                $status = $this->getGPUStatus($gpu['address']);
                $gpuList[] = array_merge($gpu, $status);
            }

            return [
                'success' => true,
                'data' => $gpuList,
                'count' => count($gpuList)
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to get GPU list: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Get GPU status
     *
     * @param string $gpuAddress GPU PCI address
     * @return array GPU status
     */
    public function getGPUStatus($gpuAddress) {
        try {
            $status = $this->gpuManager->getGPUStatus($gpuAddress);

            return [
                'success' => true,
                'data' => $status
            ];
        } catch (Exception $e) {
            $this->log('error', "Failed to get GPU status for $gpuAddress: " . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Bind GPU to VFIO
     *
     * @param string $gpuAddress GPU PCI address
     * @return array Bind result
     */
    public function bindGPU($gpuAddress) {
        try {
            // Require authentication and bind permission
            $this->securityMiddleware->process('gpu', 'bind', true);

            // Validate CSRF token
            if (!$this->webInterface->validateCSRF()) {
                throw $this->secureErrorHandler->createSecureException('CSRF_INVALID');
            }

            // Validate GPU address
            if (empty($gpuAddress)) {
                throw $this->secureErrorHandler->createSecureException('VALIDATION_REQUIRED');
            }

            // Check if GPU is already bound
            $status = $this->gpuManager->getGPUStatus($gpuAddress);
            if ($status['bound'] ?? false) {
                throw $this->secureErrorHandler->createSecureException('GPU_ALREADY_BOUND');
            }

            // Bind GPU
            $result = $this->gpuManager->bindGPU($gpuAddress);

            $this->log('info', "GPU $gpuAddress bound to VFIO successfully");

            return [
                'success' => true,
                'data' => $result,
                'message' => 'GPU bound to VFIO successfully'
            ];
        } catch (Exception $e) {
            $this->log('error', "Failed to bind GPU");
            return $this->secureErrorHandler->handleError('GPU_OPERATION_FAILED', $e, [
                'gpu_address' => $gpuAddress,
                'action' => 'bind_gpu'
            ]);
        }
    }

    /**
     * Unbind GPU from VFIO
     *
     * @param string $gpuAddress GPU PCI address
     * @return array Unbind result
     */
    public function unbindGPU($gpuAddress) {
        try {
            // Require authentication and unbind permission
            $this->securityMiddleware->process('gpu', 'unbind', true);

            // Validate CSRF token
            if (!$this->webInterface->validateCSRF()) {
                throw $this->secureErrorHandler->createSecureException('CSRF_INVALID');
            }

            // Validate GPU address
            if (empty($gpuAddress)) {
                throw $this->secureErrorHandler->createSecureException('VALIDATION_REQUIRED');
            }

            // Check if GPU is bound
            $status = $this->gpuManager->getGPUStatus($gpuAddress);
            if (!($status['bound'] ?? false)) {
                throw $this->secureErrorHandler->createSecureException('GPU_NOT_BOUND');
            }

            // Unbind GPU
            $result = $this->gpuManager->unbindGPU($gpuAddress);

            $this->log('info', "GPU $gpuAddress unbound from VFIO successfully");

            return [
                'success' => true,
                'data' => $result,
                'message' => 'GPU unbound from VFIO successfully'
            ];
        } catch (Exception $e) {
            $this->log('error', "Failed to unbind GPU");
            return $this->secureErrorHandler->handleError('GPU_OPERATION_FAILED', $e, [
                'gpu_address' => $gpuAddress,
                'action' => 'unbind_gpu'
            ]);
        }
    }

    /**
     * Switch GPU
     *
     * @param string $gpuAddress GPU PCI address
     * @param string $targetMode Target mode (vfio, host)
     * @return array Switch result
     */
    public function switchGPU($gpuAddress, $targetMode) {
        try {
            // Require authentication and switch permission
            $this->securityMiddleware->process('gpu', 'switch', true);

            // Validate CSRF token
            if (!$this->webInterface->validateCSRF()) {
                throw $this->secureErrorHandler->createSecureException('CSRF_INVALID');
            }

            // Validate GPU address
            if (empty($gpuAddress)) {
                throw $this->secureErrorHandler->createSecureException('VALIDATION_REQUIRED');
            }

            // Validate target mode
            if (!in_array($targetMode, ['vfio', 'host'])) {
                throw $this->secureErrorHandler->createSecureException('VALIDATION_FORMAT');
            }

            // Get current status
            $status = $this->gpuManager->getGPUStatus($gpuAddress);
            $currentMode = ($status['bound'] ?? false) ? 'vfio' : 'host';

            // Check if already in target mode
            if ($currentMode === $targetMode) {
                throw $this->secureErrorHandler->createSecureException('GPU_OPERATION_FAILED');
            }

            // Switch GPU
            if ($targetMode === 'vfio') {
                $result = $this->gpuManager->bindGPU($gpuAddress);
            } else {
                $result = $this->gpuManager->unbindGPU($gpuAddress);
            }

            $this->log('info', "GPU $gpuAddress switched to $targetMode mode successfully");

            return [
                'success' => true,
                'data' => $result,
                'message' => "GPU switched to $targetMode mode successfully",
                'previousMode' => $currentMode,
                'currentMode' => $targetMode
            ];
        } catch (Exception $e) {
            $this->log('error', "Failed to switch GPU");
            return $this->secureErrorHandler->handleError('GPU_OPERATION_FAILED', $e, [
                'gpu_address' => $gpuAddress,
                'target_mode' => $targetMode,
                'action' => 'switch_gpu'
            ]);
        }
    }

    /**
     * Get GPU drivers
     *
     * @return array GPU drivers
     */
    public function getGPUDrivers() {
        try {
            $drivers = $this->gpuManager->getGPUDrivers();

            return [
                'success' => true,
                'data' => $drivers
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to get GPU drivers: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Get GPU details
     *
     * @param string $gpuAddress GPU PCI address
     * @return array GPU details
     */
    public function getGPUDetails($gpuAddress) {
        try {
            $details = $this->gpuManager->getGPUDetails($gpuAddress);

            return [
                'success' => true,
                'data' => $details
            ];
        } catch (Exception $e) {
            $this->log('error', "Failed to get GPU details for $gpuAddress: " . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Refresh GPU discovery
     *
     * @return array Refresh result
     */
    public function refreshGPUDiscovery() {
        try {
            // Require authentication
            $this->securityMiddleware->process('gpu', 'read', true);

            // Validate CSRF token
            if (!$this->webInterface->validateCSRF()) {
                throw new Exception('Invalid CSRF token');
            }

            // Refresh GPU discovery
            $gpus = $this->gpuManager->discoverGPUs(true);

            $this->log('info', 'GPU discovery refreshed successfully');

            return [
                'success' => true,
                'data' => $gpus,
                'count' => count($gpus),
                'message' => 'GPU discovery refreshed successfully'
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to refresh GPU discovery: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Get GPU usage statistics
     *
     * @return array GPU usage statistics
     */
    public function getGPUUsageStatistics() {
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

            return [
                'success' => true,
                'data' => $statistics
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to get GPU usage statistics: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Get GPU binding history
     *
     * @param string $gpuAddress GPU PCI address
     * @param int $limit Number of entries to return
     * @return array Binding history
     */
    public function getGPUBindingHistory($gpuAddress, $limit = 10) {
        try {
            $history = $this->gpuManager->getBindingHistory($gpuAddress, $limit);

            return [
                'success' => true,
                'data' => $history,
                'count' => count($history)
            ];
        } catch (Exception $e) {
            $this->log('error', "Failed to get GPU binding history for $gpuAddress: " . $e->getMessage());
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
        $logMessage = "[$timestamp] [$level] [GPU_CONTROLLER] $message\n";

        if (file_exists($this->logFile)) {
            file_put_contents($this->logFile, $logMessage, FILE_APPEND);
        }
    }
}
