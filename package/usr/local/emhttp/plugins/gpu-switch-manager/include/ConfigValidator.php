<?php

/**
 * ConfigValidator.php
 * Configuration validator for GPU Switch Manager
 * Provides comprehensive configuration validation capabilities
 */

class ConfigValidator {
    private $validationRulesFile;
    private $logFile;

    /**
     * Constructor
     *
     * @param string $validationRulesFile Validation rules file path
     * @param string $logFile Log file path
     */
    public function __construct($validationRulesFile = null, $logFile = null) {
        $this->validationRulesFile = $validationRulesFile ?? dirname(__DIR__) . '/config/validation_rules.json';
        $this->logFile = $logFile ?? '/var/log/gpu.switch.manager.log';

        // Initialize validation rules
        $this->initValidationRules();
    }

    /**
     * Initialize validation rules
     *
     * @return bool Success status
     */
    private function initValidationRules() {
        $configDir = dirname($this->validationRulesFile);

        // Create config directory if it doesn't exist
        if (!is_dir($configDir)) {
            mkdir($configDir, 0755, true);
        }

        // Create default validation rules if they don't exist
        if (!file_exists($this->validationRulesFile)) {
            $defaultRules = [
                'schema' => [
                    'version' => [
                        'type' => 'string',
                        'pattern' => '^\d+\.\d+\.\d+$',
                        'required' => true
                    ],
                    'profiles' => [
                        'type' => 'object',
                        'required' => true
                    ],
                    'preferences' => [
                        'type' => 'object',
                        'required' => true
                    ],
                    'services' => [
                        'type' => 'object',
                        'required' => true
                    ]
                ],
                'references' => [
                    'gpu_bindings' => [
                        'check' => 'gpu_exists',
                        'message' => 'GPU address must exist'
                    ],
                    'service_preferences' => [
                        'check' => 'service_exists',
                        'message' => 'Service must exist'
                    ]
                ],
                'dependencies' => [
                    'gpu_bindings' => [
                        'requires' => ['driver'],
                        'message' => 'GPU binding requires driver specification'
                    ],
                    'event_handlers' => [
                        'requires' => ['enabled'],
                        'message' => 'Event handler requires enabled flag'
                    ]
                ],
                'conflicts' => [
                    'auto_switch' => [
                        'conflicts_with' => ['manual_mode'],
                        'message' => 'Auto switch conflicts with manual mode'
                    ]
                ]
            ];

            file_put_contents($this->validationRulesFile, json_encode($defaultRules, JSON_PRETTY_PRINT));
            $this->log('INFO', 'Created default validation rules');
        }

        return true;
    }

    /**
     * Load validation rules
     *
     * @return array Validation rules
     */
    private function loadValidationRules() {
        if (!file_exists($this->validationRulesFile)) {
            $this->initValidationRules();
        }

        $rules = json_decode(file_get_contents($this->validationRulesFile), true);

        if (json_last_error() !== JSON_ERROR_NONE) {
            throw new Exception("Invalid validation rules file: " . json_last_error_msg());
        }

        return $rules;
    }

    /**
     * Validate against schema
     *
     * @param array $config Configuration to validate
     * @param array $schema Schema to validate against
     * @return array Validation result with 'valid' and 'errors' keys
     */
    public function validateSchema($config, $schema = null) {
        $errors = [];

        if ($schema === null) {
            $rules = $this->loadValidationRules();
            $schema = $rules['schema'] ?? [];
        }

        // Check if config is valid array
        if (!is_array($config)) {
            $errors[] = "Invalid JSON configuration";
            return ['valid' => false, 'errors' => $errors];
        }

        // Validate schema
        foreach ($schema as $field => $fieldConfig) {
            $fieldType = $fieldConfig['type'] ?? null;
            $fieldRequired = $fieldConfig['required'] ?? false;
            $fieldPattern = $fieldConfig['pattern'] ?? null;

            // Check if field exists
            if (!isset($config[$field])) {
                if ($fieldRequired) {
                    $errors[] = "Missing required field: $field";
                }
                continue;
            }

            // Check field type
            $fieldValue = $config[$field];
            $actualType = gettype($fieldValue);

            switch ($fieldType) {
                case 'string':
                    if ($actualType !== 'string') {
                        $errors[] = "Field $field must be string";
                    }
                    break;

                case 'number':
                    if ($actualType !== 'integer' && $actualType !== 'double') {
                        $errors[] = "Field $field must be number";
                    }
                    break;

                case 'boolean':
                    if ($actualType !== 'boolean') {
                        $errors[] = "Field $field must be boolean";
                    }
                    break;

                case 'object':
                    if ($actualType !== 'array' || !is_assoc_array($fieldValue)) {
                        $errors[] = "Field $field must be object";
                    }
                    break;

                case 'array':
                    if ($actualType !== 'array') {
                        $errors[] = "Field $field must be array";
                    }
                    break;
            }

            // Check pattern if specified
            if ($fieldPattern !== null && $actualType === 'string') {
                if (!preg_match('/' . $fieldPattern . '/', $fieldValue)) {
                    $errors[] = "Field $field does not match pattern";
                }
            }
        }

        return [
            'valid' => empty($errors),
            'errors' => $errors,
            'error_count' => count($errors)
        ];
    }

    /**
     * Validate references
     *
     * @param array $config Configuration to validate
     * @return array Validation result with 'valid' and 'errors' keys
     */
    public function validateReferences($config) {
        $errors = [];

        // Check GPU bindings references
        if (isset($config['profiles']) && is_array($config['profiles'])) {
            foreach ($config['profiles'] as $profile) {
                if (isset($profile['gpu_bindings']) && is_array($profile['gpu_bindings'])) {
                    foreach (array_keys($profile['gpu_bindings']) as $gpuAddress) {
                        // In real implementation, would check against actual GPU list
                        $this->log('INFO', "Checking GPU reference: $gpuAddress");
                    }
                }
            }
        }

        // Check service preferences references
        if (isset($config['services']) && is_array($config['services'])) {
            $validServices = ['docker', 'vm', 'array'];

            foreach (array_keys($config['services']) as $service) {
                if (!in_array($service, $validServices)) {
                    $errors[] = "Invalid service: $service";
                }
            }
        }

        return [
            'valid' => empty($errors),
            'errors' => $errors,
            'error_count' => count($errors)
        ];
    }

    /**
     * Validate dependencies
     *
     * @param array $config Configuration to validate
     * @return array Validation result with 'valid' and 'errors' keys
     */
    public function validateDependencies($config) {
        $errors = [];

        // Check GPU binding dependencies
        if (isset($config['profiles']) && is_array($config['profiles'])) {
            foreach ($config['profiles'] as $profile) {
                if (isset($profile['gpu_bindings']) && is_array($profile['gpu_bindings'])) {
                    foreach ($profile['gpu_bindings'] as $gpuAddress => $binding) {
                        if (is_array($binding)) {
                            // Check if driver is specified
                            if (!isset($binding['driver']) || empty($binding['driver'])) {
                                $errors[] = "GPU binding $gpuAddress missing driver specification";
                            }
                        }
                    }
                }
            }
        }

        // Check event handler dependencies
        if (isset($config['profiles']) && is_array($config['profiles'])) {
            foreach ($config['profiles'] as $profile) {
                if (isset($profile['event_handlers']) && is_array($profile['event_handlers'])) {
                    foreach ($profile['event_handlers'] as $event => $handler) {
                        if (is_array($handler)) {
                            // Check if enabled is specified
                            if (!isset($handler['enabled'])) {
                                $errors[] = "Event handler $event missing enabled flag";
                            }
                        }
                    }
                }
            }
        }

        return [
            'valid' => empty($errors),
            'errors' => $errors,
            'error_count' => count($errors)
        ];
    }

    /**
     * Detect conflicts
     *
     * @param array $config Configuration to validate
     * @return array Validation result with 'valid' and 'errors' keys
     */
    public function detectConflicts($config) {
        $errors = [];

        // Check for auto_switch vs manual_mode conflict
        $autoSwitch = $config['preferences']['auto_switch'] ?? false;
        $manualMode = $config['preferences']['manual_mode'] ?? false;

        if ($autoSwitch && $manualMode) {
            $errors[] = "Auto switch conflicts with manual mode";
        }

        // Check for duplicate GPU bindings
        $seenGpus = [];

        if (isset($config['profiles']) && is_array($config['profiles'])) {
            foreach ($config['profiles'] as $profile) {
                if (isset($profile['gpu_bindings']) && is_array($profile['gpu_bindings'])) {
                    foreach (array_keys($profile['gpu_bindings']) as $gpuAddress) {
                        if (in_array($gpuAddress, $seenGpus)) {
                            $errors[] = "Duplicate GPU binding: $gpuAddress";
                        } else {
                            $seenGpus[] = $gpuAddress;
                        }
                    }
                }
            }
        }

        return [
            'valid' => empty($errors),
            'errors' => $errors,
            'error_count' => count($errors)
        ];
    }

    /**
     * Generate validation report
     *
     * @param array $config Configuration to validate
     * @return array Validation report
     */
    public function generateReport($config) {
        $schemaResult = $this->validateSchema($config);
        $referencesResult = $this->validateReferences($config);
        $dependenciesResult = $this->validateDependencies($config);
        $conflictsResult = $this->detectConflicts($config);

        $schemaValid = $schemaResult['valid'];
        $referencesValid = $referencesResult['valid'];
        $dependenciesValid = $dependenciesResult['valid'];
        $conflictsValid = $conflictsResult['valid'];

        $allValid = $schemaValid && $referencesValid && $dependenciesValid && $conflictsValid;

        $totalErrors = $schemaResult['error_count'] + $referencesResult['error_count'] +
                      $dependenciesResult['error_count'] + $conflictsResult['error_count'];

        return [
            'valid' => $allValid,
            'total_errors' => $totalErrors,
            'schema' => $schemaResult,
            'references' => $referencesResult,
            'dependencies' => $dependenciesResult,
            'conflicts' => $conflictsResult,
            'timestamp' => gmdate('Y-m-d\TH:i:s\Z')
        ];
    }

    /**
     * Fix errors
     *
     * @param array $config Configuration to fix
     * @param array $errors Errors to fix
     * @return array Fixed configuration
     */
    public function fixErrors($config, $errors) {
        $fixedConfig = $config;
        $fixedCount = 0;

        // Fix missing required fields with defaults
        foreach ($errors as $error) {
            if (strpos($error, 'Missing required field:') === 0) {
                $field = substr($error, strlen('Missing required field: '));
                $this->log('INFO', "Fixing missing field: $field");

                switch ($field) {
                    case 'version':
                        $fixedConfig['version'] = '1.0.0';
                        $fixedCount++;
                        break;

                    case 'profiles':
                        $fixedConfig['profiles'] = [];
                        $fixedCount++;
                        break;

                    case 'preferences':
                        $fixedConfig['preferences'] = [];
                        $fixedCount++;
                        break;

                    case 'services':
                        $fixedConfig['services'] = [];
                        $fixedCount++;
                        break;
                }
            }
        }

        return [
            'success' => true,
            'fixed_count' => $fixedCount,
            'fixed_config' => $fixedConfig
        ];
    }

    /**
     * Get validation rules
     *
     * @return array Validation rules
     */
    public function getValidationRules() {
        return $this->loadValidationRules();
    }

    /**
     * Add validation rule
     *
     * @param string $ruleType Rule type
     * @param string $ruleName Rule name
     * @param array $ruleConfig Rule configuration
     * @return bool Success status
     */
    public function addValidationRule($ruleType, $ruleName, $ruleConfig) {
        $rules = $this->loadValidationRules();

        if (!isset($rules[$ruleType])) {
            $rules[$ruleType] = [];
        }

        $rules[$ruleType][$ruleName] = $ruleConfig;

        file_put_contents($this->validationRulesFile, json_encode($rules, JSON_PRETTY_PRINT));

        $this->log('INFO', "Added validation rule: $ruleType/$ruleName");

        return true;
    }

    /**
     * Remove validation rule
     *
     * @param string $ruleType Rule type
     * @param string $ruleName Rule name
     * @return bool Success status
     */
    public function removeValidationRule($ruleType, $ruleName) {
        $rules = $this->loadValidationRules();

        if (isset($rules[$ruleType][$ruleName])) {
            unset($rules[$ruleType][$ruleName]);

            file_put_contents($this->validationRulesFile, json_encode($rules, JSON_PRETTY_PRINT));

            $this->log('INFO', "Removed validation rule: $ruleType/$ruleName");

            return true;
        }

        return false;
    }

    /**
     * Test validation
     *
     * @param array $config Configuration to test
     * @return array Validation report
     */
    public function testValidation($config) {
        return $this->generateReport($config);
    }

    /**
     * Log message
     *
     * @param string $level Log level
     * @param string $message Log message
     */
    private function log($level, $message) {
        $timestamp = date('Y-m-d H:i:s');
        $logMessage = "[$timestamp] [$level] [CONFIG_VALIDATOR] $message\n";

        if (file_exists($this->logFile)) {
            file_put_contents($this->logFile, $logMessage, FILE_APPEND);
        }
    }
}

/**
 * Check if array is associative
 *
 * @param array $arr Array to check
 * @return bool True if associative, false if indexed
 */
function is_assoc_array($arr) {
    if (!is_array($arr)) {
        return false;
    }

    return array_keys($arr) !== range(0, count($arr) - 1);
}
