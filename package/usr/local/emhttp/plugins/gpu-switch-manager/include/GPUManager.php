<?php
/**
 * GPU Switch Manager - GPU Manager Class
 * Version: 1.0.0
 * Description: PHP class for GPU discovery and state management
 */

class GPUManager {
    private $configDir;
    private $scriptDir;
    private $logFile;
    private $cache = [];
    private $cacheEnabled = true;
    private $cacheTimeout = 30; // seconds

    /**
     * Constructor
     */
    public function __construct() {
        $this->configDir = '/boot/config/plugins/gpu.switch.manager';
        $this->scriptDir = '/usr/local/emhttp/plugins/gpu.switch.manager/scripts';
        $this->logFile = '/var/log/gpu.switch.manager.log';
    }

    /**
     * Set cache enabled status
     */
    public function setCacheEnabled($enabled) {
        $this->cacheEnabled = $enabled;
    }

    /**
     * Set cache timeout
     */
    public function setCacheTimeout($timeout) {
        $this->cacheTimeout = $timeout;
    }

    /**
     * Clear cache
     */
    public function clearCache() {
        $this->cache = [];
    }

    /**
     * Log message
     */
    private function log($message, $level = 'info') {
        $timestamp = date('Y-m-d H:i:s');
        $logMessage = "[$timestamp] [$level] $message\n";

        file_put_contents($this->logFile, $logMessage, FILE_APPEND);
    }

    /**
     * Execute shell script and return output
     */
    private function executeScript($scriptName, $args = []) {
        $scriptPath = $this->scriptDir . '/' . $scriptName;

        if (!file_exists($scriptPath)) {
            $this->log("Script not found: $scriptPath", 'error');
            throw new Exception("Script not found: $scriptName");
        }

        if (!is_executable($scriptPath)) {
            $this->log("Script not executable: $scriptPath", 'error');
            throw new Exception("Script not executable: $scriptName");
        }

        // Build command with proper escaping
        $command = $scriptPath;
        foreach ($args as $arg) {
            $command .= ' ' . escapeshellarg($arg);
        }

        // Execute command safely
        $output = [];
        $returnCode = 0;
        exec($command . ' 2>&1', $output, $returnCode);

        if ($returnCode !== 0) {
            $this->log("Script execution failed: $scriptName (code: $returnCode)", 'error');
            throw new Exception("Script execution failed: $scriptName");
        }

        return trim(implode("\n", $output));
    }

    /**
     * Parse JSON output
     */
    private function parseJson($jsonString) {
        $data = json_decode($jsonString, true);

        if (json_last_error() !== JSON_ERROR_NONE) {
            $this->log("JSON parse error: " . json_last_error_msg(), 'error');
            throw new Exception("JSON parse error: " . json_last_error_msg());
        }

        return $data;
    }

    /**
     * Get cache key
     */
    private function getCacheKey($method, $args = []) {
        return $method . ':' . implode(':', $args);
    }

    /**
     * Get from cache
     */
    private function getFromCache($key) {
        if (!$this->cacheEnabled) {
            return null;
        }

        if (isset($this->cache[$key])) {
            $cached = $this->cache[$key];

            // Check if cache is still valid
            if (time() - $cached['time'] < $this->cacheTimeout) {
                return $cached['data'];
            } else {
                // Remove expired cache
                unset($this->cache[$key]);
            }
        }

        return null;
    }

    /**
     * Set cache
     */
    private function setCache($key, $data) {
        if (!$this->cacheEnabled) {
            return;
        }

        $this->cache[$key] = [
            'data' => $data,
            'time' => time()
        ];
    }

    /**
     * List all available GPUs
     */
    public function listGPUs() {
        $cacheKey = $this->getCacheKey('listGPUs');

        // Check cache
        $cached = $this->getFromCache($cacheKey);
        if ($cached !== null) {
            return $cached;
        }

        try {
            $output = $this->executeScript('list_gpus.sh');
            $gpus = $this->parseJson($output);

            // Cache the result
            $this->setCache($cacheKey, $gpus);

            $this->log("Listed {$gpus['gpu_count']} GPUs");
            return $gpus;
        } catch (Exception $e) {
            $this->log("Failed to list GPUs: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Get state of specific GPU
     */
    public function getGPUState($pciAddress) {
        // Validate PCI address
        if (!$this->validateGPUAddress($pciAddress)) {
            throw new Exception("Invalid PCI address: $pciAddress");
        }

        $cacheKey = $this->getCacheKey('getGPUState', [$pciAddress]);

        // Check cache
        $cached = $this->getFromCache($cacheKey);
        if ($cached !== null) {
            return $cached;
        }

        try {
            $output = $this->executeScript('get_gpu_state.sh', [$pciAddress]);
            $state = $this->parseJson($output);

            // Cache the result
            $this->setCache($cacheKey, $state);

            $this->log("Got state for GPU: $pciAddress");
            return $state;
        } catch (Exception $e) {
            $this->log("Failed to get GPU state: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Check if GPU is primary
     */
    public function isPrimaryGPU($pciAddress) {
        // Validate PCI address
        if (!$this->validateGPUAddress($pciAddress)) {
            throw new Exception("Invalid PCI address: $pciAddress");
        }

        try {
            $gpus = $this->listGPUs();

            foreach ($gpus['gpus'] as $gpu) {
                if ($gpu['pci_address'] === $pciAddress) {
                    return $gpu['is_primary'];
                }
            }

            return false;
        } catch (Exception $e) {
            $this->log("Failed to check primary GPU: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Check if GPU can be switched
     */
    public function canSwitchGPU($pciAddress) {
        // Validate PCI address
        if (!$this->validateGPUAddress($pciAddress)) {
            throw new Exception("Invalid PCI address: $pciAddress");
        }

        try {
            $gpus = $this->listGPUs();

            foreach ($gpus['gpus'] as $gpu) {
                if ($gpu['pci_address'] === $pciAddress) {
                    return [
                        'can_switch' => $gpu['can_switch'],
                        'reason' => $gpu['switch_reason']
                    ];
                }
            }

            return [
                'can_switch' => false,
                'reason' => 'GPU not found'
            ];
        } catch (Exception $e) {
            $this->log("Failed to check GPU switch capability: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Get detailed GPU information
     */
    public function getGPUInfo($pciAddress) {
        // Validate PCI address
        if (!$this->validateGPUAddress($pciAddress)) {
            throw new Exception("Invalid PCI address: $pciAddress");
        }

        try {
            $gpus = $this->listGPUs();

            foreach ($gpus['gpus'] as $gpu) {
                if ($gpu['pci_address'] === $pciAddress) {
                    // Get current state
                    $state = $this->getGPUState($pciAddress);

                    // Combine information
                    return array_merge($gpu, [
                        'state' => $state
                    ]);
                }
            }

            throw new Exception("GPU not found: $pciAddress");
        } catch (Exception $e) {
            $this->log("Failed to get GPU info: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Validate GPU address format
     */
    public function validateGPUAddress($pciAddress) {
        try {
            $output = $this->executeScript('validate_gpu_address.sh', [$pciAddress]);
            $result = $this->parseJson($output);

            return $result['valid'];
        } catch (Exception $e) {
            $this->log("Failed to validate GPU address: " . $e->getMessage(), 'error');
            return false;
        }
    }

    /**
     * Get audio function for GPU
     */
    public function getAudioFunction($pciAddress) {
        // Validate PCI address
        if (!$this->validateGPUAddress($pciAddress)) {
            throw new Exception("Invalid PCI address: $pciAddress");
        }

        try {
            $gpus = $this->listGPUs();

            foreach ($gpus['gpus'] as $gpu) {
                if ($gpu['pci_address'] === $pciAddress) {
                    return $gpu['audio_function'];
                }
            }

            return null;
        } catch (Exception $e) {
            $this->log("Failed to get audio function: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Get primary GPU detection info
     */
    public function getPrimaryGPUDetection() {
        $cacheKey = $this->getCacheKey('getPrimaryGPUDetection');

        // Check cache
        $cached = $this->getFromCache($cacheKey);
        if ($cached !== null) {
            return $cached;
        }

        try {
            $output = $this->executeScript('detect_primary_gpu.sh');
            $detection = $this->parseJson($output);

            // Cache the result
            $this->setCache($cacheKey, $detection);

            $this->log("Got primary GPU detection info");
            return $detection;
        } catch (Exception $e) {
            $this->log("Failed to get primary GPU detection: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Get available GPUs for switching
     */
    public function getAvailableGPUs() {
        try {
            $gpus = $this->listGPUs();
            $availableGPUs = [];

            foreach ($gpus['gpus'] as $gpu) {
                if ($gpu['can_switch']) {
                    $availableGPUs[] = $gpu;
                }
            }

            return [
                'total_gpus' => $gpus['gpu_count'],
                'available_gpus' => count($availableGPUs),
                'gpus' => $availableGPUs
            ];
        } catch (Exception $e) {
            $this->log("Failed to get available GPUs: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Get GPUs by vendor
     */
    public function getGPUsByVendor($vendor) {
        try {
            $gpus = $this->listGPUs();
            $vendorGPUs = [];

            foreach ($gpus['gpus'] as $gpu) {
                if (strcasecmp($gpu['vendor'], $vendor) === 0) {
                    $vendorGPUs[] = $gpu;
                }
            }

            return $vendorGPUs;
        } catch (Exception $e) {
            $this->log("Failed to get GPUs by vendor: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Get GPU statistics
     */
    public function getGPUStatistics() {
        try {
            $gpus = $this->listGPUs();
            $primaryDetection = $this->getPrimaryGPUDetection();

            $stats = [
                'total_gpus' => $gpus['gpu_count'],
                'primary_gpu' => $primaryDetection['primary_gpu'],
                'safety_level' => $primaryDetection['safety_level'],
                'vendors' => [],
                'available_for_switching' => 0,
                'in_use' => 0,
                'vfio_bound' => 0
            ];

            // Count by vendor
            foreach ($gpus['gpus'] as $gpu) {
                $vendor = $gpu['vendor'];

                if (!isset($stats['vendors'][$vendor])) {
                    $stats['vendors'][$vendor] = 0;
                }

                $stats['vendors'][$vendor]++;

                if ($gpu['can_switch']) {
                    $stats['available_for_switching']++;
                }

                // Get state to check if in use or VFIO bound
                try {
                    $state = $this->getGPUState($gpu['pci_address']);
                    if ($state['in_use']) {
                        $stats['in_use']++;
                    }
                    if ($state['vfio_bound']) {
                        $stats['vfio_bound']++;
                    }
                } catch (Exception $e) {
                    // Skip state check if it fails
                }
            }

            return $stats;
        } catch (Exception $e) {
            $this->log("Failed to get GPU statistics: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Bind GPU to VFIO driver
     */
    public function bindGPUToVFIO($pciAddress) {
        // Validate PCI address
        if (!$this->validateGPUAddress($pciAddress)) {
            throw new Exception("Invalid PCI address: $pciAddress");
        }

        // Check if GPU can be switched
        $switchCheck = $this->canSwitchGPU($pciAddress);
        if (!$switchCheck['can_switch']) {
            throw new Exception("GPU cannot be switched: " . $switchCheck['reason']);
        }

        // Check if GPU is in use
        try {
            $state = $this->getGPUState($pciAddress);
            if ($state['in_use']) {
                throw new Exception("GPU is currently in use");
            }
        } catch (Exception $e) {
            // Continue if state check fails
        }

        try {
            $output = $this->executeScript('bind_gpu_to_vfio.sh', [$pciAddress]);
            $result = $this->parseJson($output);

            if (!$result['success']) {
                throw new Exception($result['error'] ?? 'Failed to bind GPU to VFIO');
            }

            // Clear cache for this GPU
            $this->clearCache();

            $this->log("Successfully bound GPU $pciAddress to VFIO");
            return $result;
        } catch (Exception $e) {
            $this->log("Failed to bind GPU to VFIO: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Unbind GPU from VFIO driver
     */
    public function unbindGPUFromVFIO($pciAddress) {
        // Validate PCI address
        if (!$this->validateGPUAddress($pciAddress)) {
            throw new Exception("Invalid PCI address: $pciAddress");
        }

        try {
            $output = $this->executeScript('unbind_gpu_from_vfio.sh', [$pciAddress]);
            $result = $this->parseJson($output);

            if (!$result['success']) {
                throw new Exception($result['error'] ?? 'Failed to unbind GPU from VFIO');
            }

            // Clear cache for this GPU
            $this->clearCache();

            $this->log("Successfully unbound GPU $pciAddress from VFIO");
            return $result;
        } catch (Exception $e) {
            $this->log("Failed to unbind GPU from VFIO: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Check VFIO binding status
     */
    public function checkVFIOBinding($pciAddress) {
        // Validate PCI address
        if (!$this->validateGPUAddress($pciAddress)) {
            throw new Exception("Invalid PCI address: $pciAddress");
        }

        $cacheKey = $this->getCacheKey('checkVFIOBinding', [$pciAddress]);

        // Check cache
        $cached = $this->getFromCache($cacheKey);
        if ($cached !== null) {
            return $cached;
        }

        try {
            $output = $this->executeScript('check_vfio_binding.sh', [$pciAddress]);
            $result = $this->parseJson($output);

            if (!$result['success']) {
                throw new Exception($result['error'] ?? 'Failed to check VFIO binding');
            }

            // Cache the result
            $this->setCache($cacheKey, $result);

            $this->log("Checked VFIO binding for GPU $pciAddress");
            return $result;
        } catch (Exception $e) {
            $this->log("Failed to check VFIO binding: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Update VFIO configuration
     */
    public function updateVFIOConfig($pciAddresses, $remove = false) {
        // Validate PCI addresses
        if (!is_array($pciAddresses)) {
            $pciAddresses = [$pciAddresses];
        }

        foreach ($pciAddresses as $pciAddress) {
            if (!$this->validateGPUAddress($pciAddress)) {
                throw new Exception("Invalid PCI address: $pciAddress");
            }
        }

        try {
            $args = $pciAddresses;
            if ($remove) {
                $args[] = '--remove';
            }

            $output = $this->executeScript('update_vfio_conf.sh', $args);
            $result = $this->parseJson($output);

            if (!$result['success']) {
                throw new Exception($result['error'] ?? 'Failed to update VFIO configuration');
            }

            $this->log("Successfully updated VFIO configuration");
            return $result;
        } catch (Exception $e) {
            $this->log("Failed to update VFIO configuration: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Get GPU driver information
     */
    public function getGPUDriverInfo($pciAddress) {
        // Validate PCI address
        if (!$this->validateGPUAddress($pciAddress)) {
            throw new Exception("Invalid PCI address: $pciAddress");
        }

        $cacheKey = $this->getCacheKey('getGPUDriverInfo', [$pciAddress]);

        // Check cache
        $cached = $this->getFromCache($cacheKey);
        if ($cached !== null) {
            return $cached;
        }

        try {
            $output = $this->executeScript('get_gpu_driver_info.sh', [$pciAddress]);
            $result = $this->parseJson($output);

            if (!$result['success']) {
                throw new Exception($result['error'] ?? 'Failed to get GPU driver information');
            }

            // Cache the result
            $this->setCache($cacheKey, $result);

            $this->log("Got driver information for GPU $pciAddress");
            return $result;
        } catch (Exception $e) {
            $this->log("Failed to get GPU driver information: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Verify VFIO binding
     */
    public function verifyVFIOBinding($pciAddress) {
        // Validate PCI address
        if (!$this->validateGPUAddress($pciAddress)) {
            throw new Exception("Invalid PCI address: $pciAddress");
        }

        try {
            $output = $this->executeScript('verify_vfio_binding.sh', [$pciAddress]);
            $result = $this->parseJson($output);

            if (!$result['success']) {
                throw new Exception($result['error'] ?? 'Failed to verify VFIO binding');
            }

            $this->log("Verified VFIO binding for GPU $pciAddress");
            return $result;
        } catch (Exception $e) {
            $this->log("Failed to verify VFIO binding: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Toggle GPU VFIO binding
     */
    public function toggleGPUVFIOBinding($pciAddress) {
        // Validate PCI address
        if (!$this->validateGPUAddress($pciAddress)) {
            throw new Exception("Invalid PCI address: $pciAddress");
        }

        try {
            // Check current binding status
            $bindingStatus = $this->checkVFIOBinding($pciAddress);

            if ($bindingStatus['vfio_bound']) {
                // Unbind from VFIO
                return $this->unbindGPUFromVFIO($pciAddress);
            } else {
                // Bind to VFIO
                return $this->bindGPUToVFIO($pciAddress);
            }
        } catch (Exception $e) {
            $this->log("Failed to toggle GPU VFIO binding: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Get all VFIO-bound GPUs
     */
    public function getVFIOBoundGPUs() {
        try {
            $gpus = $this->listGPUs();
            $vfioBoundGPUs = [];

            foreach ($gpus['gpus'] as $gpu) {
                try {
                    $bindingStatus = $this->checkVFIOBinding($gpu['pci_address']);
                    if ($bindingStatus['vfio_bound']) {
                        $vfioBoundGPUs[] = array_merge($gpu, [
                            'binding_status' => $bindingStatus
                        ]);
                    }
                } catch (Exception $e) {
                    // Skip GPU if binding check fails
                    continue;
                }
            }

            return [
                'total_gpus' => $gpus['gpu_count'],
                'vfio_bound_count' => count($vfioBoundGPUs),
                'gpus' => $vfioBoundGPUs
            ];
        } catch (Exception $e) {
            $this->log("Failed to get VFIO-bound GPUs: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Manage Docker containers
     */
    public function manageDockerContainers($operation, $containers) {
        if (!is_array($containers)) {
            $containers = [$containers];
        }

        try {
            $args = array_merge([$operation], $containers);
            $output = $this->executeScript('manage_docker_containers.sh', $args);
            $result = $this->parseJson($output);

            if (!$result['success']) {
                throw new Exception($result['error'] ?? 'Failed to manage Docker containers');
            }

            // Clear cache for service status
            $this->clearCache();

            $this->log("Successfully managed Docker containers: $operation");
            return $result;
        } catch (Exception $e) {
            $this->log("Failed to manage Docker containers: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Manage VM services
     */
    public function manageVMServices($operation, $vms) {
        if (!is_array($vms)) {
            $vms = [$vms];
        }

        try {
            $args = array_merge([$operation], $vms);
            $output = $this->executeScript('manage_vm_services.sh', $args);
            $result = $this->parseJson($output);

            if (!$result['success']) {
                throw new Exception($result['error'] ?? 'Failed to manage VM services');
            }

            // Clear cache for service status
            $this->clearCache();

            $this->log("Successfully managed VM services: $operation");
            return $result;
        } catch (Exception $e) {
            $this->log("Failed to manage VM services: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Check service dependencies
     */
    public function checkServiceDependencies($pciAddress) {
        // Validate PCI address
        if (!$this->validateGPUAddress($pciAddress)) {
            throw new Exception("Invalid PCI address: $pciAddress");
        }

        $cacheKey = $this->getCacheKey('checkServiceDependencies', [$pciAddress]);

        // Check cache
        $cached = $this->getFromCache($cacheKey);
        if ($cached !== null) {
            return $cached;
        }

        try {
            $output = $this->executeScript('check_service_dependencies.sh', [$pciAddress]);
            $result = $this->parseJson($output);

            if (!$result['success']) {
                throw new Exception($result['error'] ?? 'Failed to check service dependencies');
            }

            // Cache the result
            $this->setCache($cacheKey, $result);

            $this->log("Checked service dependencies for GPU $pciAddress");
            return $result;
        } catch (Exception $e) {
            $this->log("Failed to check service dependencies: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Save service states
     */
    public function saveServiceStates($pciAddress) {
        // Validate PCI address
        if (!$this->validateGPUAddress($pciAddress)) {
            throw new Exception("Invalid PCI address: $pciAddress");
        }

        try {
            $output = $this->executeScript('save_service_states.sh', [$pciAddress]);
            $result = $this->parseJson($output);

            if (!$result['success']) {
                throw new Exception($result['error'] ?? 'Failed to save service states');
            }

            $this->log("Successfully saved service states for GPU $pciAddress");
            return $result;
        } catch (Exception $e) {
            $this->log("Failed to save service states: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Restore service states
     */
    public function restoreServiceStates($stateFile) {
        try {
            $output = $this->executeScript('restore_service_states.sh', [$stateFile]);
            $result = $this->parseJson($output);

            if (!$result['success']) {
                throw new Exception($result['error'] ?? 'Failed to restore service states');
            }

            // Clear cache for service status
            $this->clearCache();

            $this->log("Successfully restored service states from $stateFile");
            return $result;
        } catch (Exception $e) {
            $this->log("Failed to restore service states: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Get service status
     */
    public function getServiceStatus($serviceType = 'all') {
        $cacheKey = $this->getCacheKey('getServiceStatus', [$serviceType]);

        // Check cache
        $cached = $this->getFromCache($cacheKey);
        if ($cached !== null) {
            return $cached;
        }

        try {
            $output = $this->executeScript('get_service_status.sh', [$serviceType]);
            $result = $this->parseJson($output);

            if (!$result['success']) {
                throw new Exception($result['error'] ?? 'Failed to get service status');
            }

            // Cache the result
            $this->setCache($cacheKey, $result);

            $this->log("Got service status for $serviceType");
            return $result;
        } catch (Exception $e) {
            $this->log("Failed to get service status: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Validate service operation
     */
    public function validateServiceOperation($operationType, $serviceType, $services) {
        if (!is_array($services)) {
            $services = [$services];
        }

        try {
            $args = array_merge([$operationType, $serviceType], $services);
            $output = $this->executeScript('validate_service_operation.sh', $args);
            $result = $this->parseJson($output);

            if (!$result['success']) {
                throw new Exception($result['error'] ?? 'Failed to validate service operation');
            }

            $this->log("Validated service operation: $operationType on $serviceType");
            return $result;
        } catch (Exception $e) {
            $this->log("Failed to validate service operation: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Prepare GPU for VM passthrough
     */
    public function prepareGPUForVMPassthrough($pciAddress) {
        // Validate PCI address
        if (!$this->validateGPUAddress($pciAddress)) {
            throw new Exception("Invalid PCI address: $pciAddress");
        }

        try {
            // Check service dependencies
            $dependencies = $this->checkServiceDependencies($pciAddress);

            if (!$dependencies['safe_to_switch']) {
                throw new Exception("GPU is not safe to switch: " . implode(', ', $dependencies['blocking_services']));
            }

            // Save current service states
            $savedStates = $this->saveServiceStates($pciAddress);

            // Stop GPU-dependent containers
            if (isset($dependencies['dependent_services'])) {
                $gpuContainers = [];
                foreach ($dependencies['dependent_services'] as $service) {
                    if ($service['type'] === 'container' && $service['state'] === 'running') {
                        $gpuContainers[] = $service['name'];
                    }
                }

                if (!empty($gpuContainers)) {
                    $this->manageDockerContainers('stop', $gpuContainers);
                }
            }

            // Bind GPU to VFIO
            $bindingResult = $this->bindGPUToVFIO($pciAddress);

            return [
                'success' => true,
                'pci_address' => $pciAddress,
                'saved_states' => $savedStates,
                'binding_result' => $bindingResult,
                'stopped_containers' => $gpuContainers ?? []
            ];
        } catch (Exception $e) {
            $this->log("Failed to prepare GPU for VM passthrough: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Restore GPU after VM passthrough
     */
    public function restoreGPUAfterVMPassthrough($pciAddress, $stateFile = null) {
        // Validate PCI address
        if (!$this->validateGPUAddress($pciAddress)) {
            throw new Exception("Invalid PCI address: $pciAddress");
        }

        try {
            // Unbind GPU from VFIO
            $unbindingResult = $this->unbindGPUFromVFIO($pciAddress);

            // Restore service states if state file provided
            $restorationResult = null;
            if ($stateFile !== null) {
                $restorationResult = $this->restoreServiceStates($stateFile);
            }

            return [
                'success' => true,
                'pci_address' => $pciAddress,
                'unbinding_result' => $unbindingResult,
                'restoration_result' => $restorationResult
            ];
        } catch (Exception $e) {
            $this->log("Failed to restore GPU after VM passthrough: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Get GPU-dependent services
     */
    public function getGPUDependentServices($pciAddress) {
        // Validate PCI address
        if (!$this->validateGPUAddress($pciAddress)) {
            throw new Exception("Invalid PCI address: $pciAddress");
        }

        try {
            $dependencies = $this->checkServiceDependencies($pciAddress);

            return [
                'success' => true,
                'pci_address' => $pciAddress,
                'safe_to_switch' => $dependencies['safe_to_switch'],
                'blocking_services' => $dependencies['blocking_services'],
                'dependent_services' => $dependencies['dependent_services'],
                'recommendations' => $dependencies['recommendations']
            ];
        } catch (Exception $e) {
            $this->log("Failed to get GPU-dependent services: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Get comprehensive system status
     */
    public function getSystemStatus() {
        try {
            // Get GPU statistics
            $gpuStats = $this->getGPUStatistics();

            // Get service status
            $serviceStatus = $this->getServiceStatus('all');

            // Get VFIO-bound GPUs
            $vfioBoundGPUs = $this->getVFIOBoundGPUs();

            return [
                'success' => true,
                'gpus' => $gpuStats,
                'services' => $serviceStatus,
                'vfio_bound_gpus' => $vfioBoundGPUs,
                'timestamp' => date('c')
            ];
        } catch (Exception $e) {
            $this->log("Failed to get system status: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Handle VM start event
     */
    public function handleVMStartEvent($vmName) {
        try {
            $output = $this->executeScript('vm_start_handler.sh', [$vmName]);
            $result = $this->parseJson($output);

            if (!$result['success']) {
                throw new Exception($result['error'] ?? 'Failed to handle VM start event');
            }

            $this->log("Successfully handled VM start event: $vmName");
            return $result;
        } catch (Exception $e) {
            $this->log("Failed to handle VM start event: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Handle VM stop event
     */
    public function handleVMStopEvent($vmName) {
        try {
            $output = $this->executeScript('vm_stop_handler.sh', [$vmName]);
            $result = $this->parseJson($output);

            if (!$result['success']) {
                throw new Exception($result['error'] ?? 'Failed to handle VM stop event');
            }

            $this->log("Successfully handled VM stop event: $vmName");
            return $result;
        } catch (Exception $e) {
            $this->log("Failed to handle VM stop event: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Handle Docker start event
     */
    public function handleDockerStartEvent($containerName) {
        try {
            $output = $this->executeScript('docker_start_handler.sh', [$containerName]);
            $result = $this->parseJson($output);

            if (!$result['success']) {
                throw new Exception($result['error'] ?? 'Failed to handle Docker start event');
            }

            $this->log("Successfully handled Docker start event: $containerName");
            return $result;
        } catch (Exception $e) {
            $this->log("Failed to handle Docker start event: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Handle Docker stop event
     */
    public function handleDockerStopEvent($containerName) {
        try {
            $output = $this->executeScript('docker_stop_handler.sh', [$containerName]);
            $result = $this->parseJson($output);

            if (!$result['success']) {
                throw new Exception($result['error'] ?? 'Failed to handle Docker stop event');
            }

            $this->log("Successfully handled Docker stop event: $containerName");
            return $result;
        } catch (Exception $e) {
            $this->log("Failed to handle Docker stop event: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Determine switching action from event
     */
    public function determineSwitchingAction($eventType, $eventData) {
        try {
            $eventDataJson = json_encode($eventData);
            $output = $this->executeScript('determine_switching_action.sh', [$eventType, $eventDataJson]);
            $result = $this->parseJson($output);

            if (!$result['success']) {
                throw new Exception($result['error'] ?? 'Failed to determine switching action');
            }

            $this->log("Determined switching action for event: $eventType");
            return $result;
        } catch (Exception $e) {
            $this->log("Failed to determine switching action: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Validate switching safety
     */
    public function validateSwitchingSafety($action, $gpuAddress) {
        // Validate PCI address
        if (!$this->validateGPUAddress($gpuAddress)) {
            throw new Exception("Invalid PCI address: $gpuAddress");
        }

        try {
            $output = $this->executeScript('validate_switching_safety.sh', [$action, $gpuAddress]);
            $result = $this->parseJson($output);

            if (!$result['success']) {
                throw new Exception($result['error'] ?? 'Failed to validate switching safety');
            }

            $this->log("Validated switching safety for action: $action, GPU: $gpuAddress");
            return $result;
        } catch (Exception $e) {
            $this->log("Failed to validate switching safety: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Execute automatic GPU switching
     */
    public function executeAutoSwitch($action, $gpuAddress) {
        // Validate PCI address
        if (!$this->validateGPUAddress($gpuAddress)) {
            throw new Exception("Invalid PCI address: $gpuAddress");
        }

        try {
            $output = $this->executeScript('execute_gpu_switch.sh', [$action, $gpuAddress]);
            $result = $this->parseJson($output);

            if (!$result['success']) {
                throw new Exception($result['error'] ?? 'Failed to execute GPU switching');
            }

            // Clear cache for this GPU
            $this->clearCache();

            $this->log("Successfully executed GPU switching: $action on $gpuAddress");
            return $result;
        } catch (Exception $e) {
            $this->log("Failed to execute GPU switching: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Coordinate services for event
     */
    public function coordinateServicesForEvent($eventType, $eventData) {
        try {
            $eventDataJson = json_encode($eventData);
            $output = $this->executeScript('coordinate_services_for_event.sh', [$eventType, $eventDataJson]);
            $result = $this->parseJson($output);

            if (!$result['success']) {
                throw new Exception($result['error'] ?? 'Failed to coordinate services for event');
            }

            $this->log("Successfully coordinated services for event: $eventType");
            return $result;
        } catch (Exception $e) {
            $this->log("Failed to coordinate services for event: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Get event history
     */
    public function getEventHistory($limit = 100) {
        try {
            $output = $this->executeScript('event_logger.sh', ['INFO', 'system_event', 'Getting event history']);
            $result = $this->parseJson($output);

            // For now, return a placeholder since event_logger.sh doesn't have a get history command
            return [
                'success' => true,
                'events' => [],
                'count' => 0,
                'limit' => $limit,
                'timestamp' => date('c')
            ];
        } catch (Exception $e) {
            $this->log("Failed to get event history: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Get active switching operations
     */
    public function getActiveSwitchingOperations() {
        try {
            $switchingDir = '/var/run/gpu-switch-manager/switching';
            $operations = [];

            if (is_dir($switchingDir)) {
                foreach (glob("$switchingDir/switch_*.json") as $operationFile) {
                    $operationData = json_decode(file_get_contents($operationFile), true);
                    if ($operationData && $operationData['status'] === 'in_progress') {
                        $operations[] = $operationData;
                    }
                }
            }

            return [
                'success' => true,
                'active_operations' => $operations,
                'count' => count($operations),
                'timestamp' => date('c')
            ];
        } catch (Exception $e) {
            $this->log("Failed to get active switching operations: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Cancel switching operation
     */
    public function cancelSwitchingOperation($operationId) {
        try {
            $switchingDir = '/var/run/gpu-switch-manager/switching';
            $operationFile = "$switchingDir/${operationId}.json";

            if (!file_exists($operationFile)) {
                throw new Exception("Operation not found: $operationId");
            }

            $operationData = json_decode(file_get_contents($operationFile), true);

            if ($operationData['status'] !== 'in_progress') {
                throw new Exception("Operation is not in progress: $operationId");
            }

            // Update operation status to cancelled
            $operationData['status'] = 'cancelled';
            $operationData['end_time'] = date('c');
            file_put_contents($operationFile, json_encode($operationData));

            $this->log("Cancelled switching operation: $operationId");
            return [
                'success' => true,
                'operation_id' => $operationId,
                'status' => 'cancelled',
                'timestamp' => date('c')
            ];
        } catch (Exception $e) {
            $this->log("Failed to cancel switching operation: " . $e->getMessage(), 'error');
            throw $e;
        }
    }

    /**
     * Get event handler status
     */
    public function getEventHandlerStatus() {
        try {
            $status = [
                'docker_event_monitor' => false,
                'vm_lifecycle_hooks' => false,
                'unraid_event_handlers' => false
            ];

            // Check Docker event monitor
            $pidFile = '/var/run/gpu-switch-manager/docker-event-monitor.pid';
            if (file_exists($pidFile)) {
                $pid = trim(file_get_contents($pidFile));
                if ($pid && posix_kill($pid, 0)) {
                    $status['docker_event_monitor'] = true;
                    $status['docker_event_monitor_pid'] = $pid;
                }
            }

            // Check VM lifecycle hooks
            $libvirtHook = '/etc/libvirt/hooks/qemu';
            if (file_exists($libvirtHook) && is_executable($libvirtHook)) {
                $status['vm_lifecycle_hooks'] = true;
            }

            // Check Unraid event handlers
            $unraidEventDir = '/usr/local/emhttp/webGui/event_handlers';
            $unraidHandlers = glob("$unraidEventDir/gpu-switch-*");
            if (!empty($unraidHandlers)) {
                $status['unraid_event_handlers'] = true;
                $status['unraid_handler_count'] = count($unraidHandlers);
            }

            return [
                'success' => true,
                'status' => $status,
                'timestamp' => date('c')
            ];
        } catch (Exception $e) {
            $this->log("Failed to get event handler status: " . $e->getMessage(), 'error');
            throw $e;
        }
    }
}
?>