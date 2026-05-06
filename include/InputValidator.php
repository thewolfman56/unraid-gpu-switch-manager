<?php

/**
 * InputValidator.php
 * Input validator for GPU Switch Manager
 * Handles input validation, sanitization, and security checks
 */

class InputValidator {
    private $rules;
    private $logFile;

    /**
     * Constructor
     *
     * @param string $logFile Log file path
     */
    public function __construct($logFile = null) {
        $this->logFile = $logFile ?? '/var/log/gpu.switch.manager.log';
        $this->initializeRules();
    }

    /**
     * Validate input
     *
     * @param array $data Input data
     * @param array $rules Validation rules
     * @return array Validation result
     */
    public function validate($data, $rules) {
        $errors = [];
        $sanitized = [];

        foreach ($rules as $field => $rule) {
            $value = $data[$field] ?? null;

            // Check required
            if (isset($rule['required']) && $rule['required'] && $value === null) {
                $errors[$field] = "$field is required";
                continue;
            }

            // Skip validation if empty and not required
            if ($value === null && !isset($rule['required'])) {
                continue;
            }

            // Validate type
            if (isset($rule['type'])) {
                $typeResult = $this->validateType($value, $rule['type']);
                if (!$typeResult['valid']) {
                    $errors[$field] = $typeResult['error'];
                    continue;
                }
            }

            // Validate format
            if (isset($rule['format'])) {
                $formatResult = $this->validateFormat($value, $rule['format']);
                if (!$formatResult['valid']) {
                    $errors[$field] = $formatResult['error'];
                    continue;
                }
            }

            // Validate length
            if (isset($rule['min_length']) || isset($rule['max_length'])) {
                $lengthResult = $this->validateLength($value, $rule['min_length'] ?? null, $rule['max_length'] ?? null);
                if (!$lengthResult['valid']) {
                    $errors[$field] = $lengthResult['error'];
                    continue;
                }
            }

            // Validate range
            if (isset($rule['min']) || isset($rule['max'])) {
                $rangeResult = $this->validateRange($value, $rule['min'] ?? null, $rule['max'] ?? null);
                if (!$rangeResult['valid']) {
                    $errors[$field] = $rangeResult['error'];
                    continue;
                }
            }

            // Validate enum
            if (isset($rule['enum'])) {
                $enumResult = $this->validateEnum($value, $rule['enum']);
                if (!$enumResult['valid']) {
                    $errors[$field] = $enumResult['error'];
                    continue;
                }
            }

            // Validate pattern
            if (isset($rule['pattern'])) {
                $patternResult = $this->validatePattern($value, $rule['pattern']);
                if (!$patternResult['valid']) {
                    $errors[$field] = $patternResult['error'];
                    continue;
                }
            }

            // Sanitize value
            $sanitizedValue = $this->sanitize($value, $rule);
            $sanitized[$field] = $sanitizedValue;
        }

        return [
            'valid' => empty($errors),
            'errors' => $errors,
            'sanitized' => $sanitized
        ];
    }

    /**
     * Validate GPU address
     *
     * @param string $address GPU address
     * @return string Validated GPU address
     * @throws Exception If invalid
     */
    public static function validateGPUAddress($address) {
        if (empty($address)) {
            throw new Exception('GPU address is required');
        }

        if (!preg_match('/^[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-7]$/i', $address)) {
            throw new Exception('Invalid GPU address format. Expected format: XXXX:XX:XX.X');
        }

        return strtolower($address);
    }

    /**
     * Validate profile name
     *
     * @param string $name Profile name
     * @return string Validated profile name
     * @throws Exception If invalid
     */
    public static function validateProfileName($name) {
        if (empty($name)) {
            throw new Exception('Profile name is required');
        }

        if (strlen($name) > 64) {
            throw new Exception('Profile name too long (max 64 characters)');
        }

        if (!preg_match('/^[a-zA-Z0-9_-]+$/', $name)) {
            throw new Exception('Profile name must contain only alphanumeric characters, hyphens, and underscores');
        }

        return $name;
    }

    /**
     * Validate preference key
     *
     * @param string $key Preference key
     * @return string Validated preference key
     * @throws Exception If invalid
     */
    public static function validatePreferenceKey($key) {
        if (empty($key)) {
            throw new Exception('Preference key is required');
        }

        if (!preg_match('/^[a-zA-Z0-9_.-]+$/', $key)) {
            throw new Exception('Preference key must contain only alphanumeric characters, dots, hyphens, and underscores');
        }

        if (strlen($key) > 128) {
            throw new Exception('Preference key too long (max 128 characters)');
        }

        return $key;
    }

    /**
     * Sanitize string
     *
     * @param string $input Input string
     * @param int $maxLength Max length
     * @return string Sanitized string
     */
    public static function sanitizeString($input, $maxLength = 255) {
        if (!is_string($input)) {
            throw new Exception('Invalid input type');
        }

        $input = trim($input);
        $input = substr($input, 0, $maxLength);

        // Remove potentially dangerous characters
        $input = preg_replace('/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/', '', $input);

        return $input;
    }

    /**
     * Sanitize integer
     *
     * @param mixed $input Input value
     * @return int Sanitized integer
     */
    public static function sanitizeInt($input) {
        if (!is_numeric($input)) {
            throw new Exception('Invalid integer value');
        }

        return (int)$input;
    }

    /**
     * Sanitize boolean
     *
     * @param mixed $input Input value
     * @return bool Sanitized boolean
     */
    public static function sanitizeBool($input) {
        if (is_bool($input)) {
            return $input;
        }

        if (in_array(strtolower($input), ['true', '1', 'yes', 'on'])) {
            return true;
        }

        if (in_array(strtolower($input), ['false', '0', 'no', 'off'])) {
            return false;
        }

        return (bool)$input;
    }

    /**
     * Validate type
     *
     * @param mixed $value Value to validate
     * @param string $type Expected type
     * @return array Validation result
     */
    private function validateType($value, $type) {
        switch ($type) {
            case 'string':
                if (!is_string($value)) {
                    return ['valid' => false, 'error' => 'Value must be a string'];
                }
                break;

            case 'integer':
                if (!is_int($value)) {
                    return ['valid' => false, 'error' => 'Value must be an integer'];
                }
                break;

            case 'float':
                if (!is_numeric($value)) {
                    return ['valid' => false, 'error' => 'Value must be a number'];
                }
                break;

            case 'boolean':
                if (!is_bool($value) && !in_array(strtolower($value), ['true', 'false', '1', '0', 'yes', 'no'])) {
                    return ['valid' => false, 'error' => 'Value must be a boolean'];
                }
                break;

            case 'array':
                if (!is_array($value)) {
                    return ['valid' => false, 'error' => 'Value must be an array'];
                }
                break;

            case 'email':
                if (!filter_var($value, FILTER_VALIDATE_EMAIL)) {
                    return ['valid' => false, 'error' => 'Value must be a valid email address'];
                }
                break;

            case 'url':
                if (!filter_var($value, FILTER_VALIDATE_URL)) {
                    return ['valid' => false, 'error' => 'Value must be a valid URL'];
                }
                break;

            default:
                return ['valid' => false, 'error' => "Unknown type: $type"];
        }

        return ['valid' => true];
    }

    /**
     * Validate format
     *
     * @param mixed $value Value to validate
     * @param string $format Expected format
     * @return array Validation result
     */
    private function validateFormat($value, $format) {
        switch ($format) {
            case 'gpu_address':
                try {
                    self::validateGPUAddress($value);
                    return ['valid' => true];
                } catch (Exception $e) {
                    return ['valid' => false, 'error' => $e->getMessage()];
                }

            case 'profile_name':
                try {
                    self::validateProfileName($value);
                    return ['valid' => true];
                } catch (Exception $e) {
                    return ['valid' => false, 'error' => $e->getMessage()];
                }

            case 'preference_key':
                try {
                    self::validatePreferenceKey($value);
                    return ['valid' => true];
                } catch (Exception $e) {
                    return ['valid' => false, 'error' => $e->getMessage()];
                }

            default:
                return ['valid' => false, 'error' => "Unknown format: $format"];
        }
    }

    /**
     * Validate length
     *
     * @param mixed $value Value to validate
     * @param int|null $minLength Minimum length
     * @param int|null $maxLength Maximum length
     * @return array Validation result
     */
    private function validateLength($value, $minLength = null, $maxLength = null) {
        $length = strlen((string)$value);

        if ($minLength !== null && $length < $minLength) {
            return ['valid' => false, 'error' => "Value must be at least $minLength characters"];
        }

        if ($maxLength !== null && $length > $maxLength) {
            return ['valid' => false, 'error' => "Value must be at most $maxLength characters"];
        }

        return ['valid' => true];
    }

    /**
     * Validate range
     *
     * @param mixed $value Value to validate
     * @param int|null $min Minimum value
     * @param int|null $max Maximum value
     * @return array Validation result
     */
    private function validateRange($value, $min = null, $max = null) {
        $numericValue = (float)$value;

        if ($min !== null && $numericValue < $min) {
            return ['valid' => false, 'error' => "Value must be at least $min"];
        }

        if ($max !== null && $numericValue > $max) {
            return ['valid' => false, 'error' => "Value must be at most $max"];
        }

        return ['valid' => true];
    }

    /**
     * Validate enum
     *
     * @param mixed $value Value to validate
     * @param array $enum Allowed values
     * @return array Validation result
     */
    private function validateEnum($value, $enum) {
        if (!in_array($value, $enum, true)) {
            return ['valid' => false, 'error' => 'Value must be one of: ' . implode(', ', $enum)];
        }

        return ['valid' => true];
    }

    /**
     * Validate pattern
     *
     * @param mixed $value Value to validate
     * @param string $pattern Regular expression pattern
     * @return array Validation result
     */
    private function validatePattern($value, $pattern) {
        if (!preg_match($pattern, $value)) {
            return ['valid' => false, 'error' => 'Value format is invalid'];
        }

        return ['valid' => true];
    }

    /**
     * Sanitize value
     *
     * @param mixed $value Value to sanitize
     * @param array $rule Validation rule
     * @return mixed Sanitized value
     */
    private function sanitize($value, $rule) {
        $type = $rule['type'] ?? 'string';

        switch ($type) {
            case 'string':
                $maxLength = $rule['max_length'] ?? 255;
                return self::sanitizeString($value, $maxLength);

            case 'integer':
                return self::sanitizeInt($value);

            case 'boolean':
                return self::sanitizeBool($value);

            case 'float':
                return (float)$value;

            case 'array':
                return is_array($value) ? $value : [];

            default:
                return $value;
        }
    }

    /**
     * Initialize validation rules
     *
     * @return void
     */
    private function initializeRules() {
        $this->rules = [
            'gpu_address' => [
                'type' => 'string',
                'format' => 'gpu_address',
                'required' => true
            ],
            'profile_name' => [
                'type' => 'string',
                'format' => 'profile_name',
                'required' => true
            ],
            'preference_key' => [
                'type' => 'string',
                'format' => 'preference_key',
                'required' => true
            ],
            'username' => [
                'type' => 'string',
                'min_length' => 3,
                'max_length' => 32,
                'pattern' => '/^[a-zA-Z0-9_-]+$/',
                'required' => true
            ],
            'password' => [
                'type' => 'string',
                'min_length' => 8,
                'required' => true
            ],
            'email' => [
                'type' => 'string',
                'format' => 'email',
                'required' => false
            ],
            'role' => [
                'type' => 'string',
                'enum' => ['admin', 'user', 'readonly'],
                'required' => true
            ]
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
        $logMessage = "[$timestamp] [$level] [INPUT_VALIDATOR] $message\n";

        if (file_exists($this->logFile)) {
            file_put_contents($this->logFile, $logMessage, FILE_APPEND);
        }
    }
}
