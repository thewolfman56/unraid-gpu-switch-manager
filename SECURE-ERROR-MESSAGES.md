# Secure Error Messages Implementation

## Overview

The GPU Switch Manager now includes comprehensive secure error handling to prevent information disclosure and provide appropriate error messages for users vs administrators. This implementation follows OWASP guidelines and prevents sensitive information from being exposed to end users.

## Components

### 1. SecureErrorHandler.php

**File:** `include/SecureErrorHandler.php`

**Features:**
- Centralized error handling with role-based messages
- Comprehensive error code system
- Detailed logging for administrators
- Generic messages for end users
- Exception sanitization
- Debug mode support
- PHP error handling integration

**Key Methods:**
- `handleError($errorCode, $exception, $context)` - Handle errors with secure messages
- `sanitizeExceptionMessage($exception)` - Remove sensitive information
- `createSecureException($errorCode, $customMessage)` - Create secure exceptions
- `handlePHPError($errno, $errstr, $errfile, $errline)` - Handle PHP errors
- `handleUncaughtException($exception)` - Handle uncaught exceptions
- `registerHandlers()` - Register error handlers

## Error Code System

### Authentication Errors
- `AUTH_FAILED` - Invalid credentials
- `AUTH_LOCKED` - Account temporarily locked
- `AUTH_SESSION_EXPIRED` - Session expired
- `AUTH_UNAUTHORIZED` - Access denied

### Authorization Errors
- `AUTHZ_DENIED` - Permission denied
- `AUTHZ_RESOURCE_NOT_FOUND` - Resource not found

### Input Validation Errors
- `VALIDATION_FAILED` - Invalid input
- `VALIDATION_REQUIRED` - Required field missing
- `VALIDATION_FORMAT` - Invalid format
- `VALIDATION_LENGTH` - Invalid length

### GPU Errors
- `GPU_NOT_FOUND` - GPU not found
- `GPU_ALREADY_BOUND` - GPU already bound
- `GPU_NOT_BOUND` - GPU not bound
- `GPU_OPERATION_FAILED` - GPU operation failed

### Configuration Errors
- `CONFIG_NOT_FOUND` - Configuration not found
- `CONFIG_INVALID` - Invalid configuration
- `CONFIG_SAVE_FAILED` - Failed to save configuration

### Profile Errors
- `PROFILE_NOT_FOUND` - Profile not found
- `PROFILE_EXISTS` - Profile already exists
- `PROFILE_INVALID` - Invalid profile

### Service Errors
- `SERVICE_NOT_FOUND` - Service not found
- `SERVICE_START_FAILED` - Failed to start service
- `SERVICE_STOP_FAILED` - Failed to stop service

### File Operation Errors
- `FILE_NOT_FOUND` - File not found
- `FILE_READ_FAILED` - Failed to read file
- `FILE_WRITE_FAILED` - Failed to write file
- `FILE_DELETE_FAILED` - Failed to delete file
- `FILE_INVALID` - Invalid file

### CSRF Errors
- `CSRF_INVALID` - Invalid security token
- `CSRF_EXPIRED` - Security token expired
- `CSRF_MISSING` - Security token required

### Rate Limiting Errors
- `RATE_LIMIT_EXCEEDED` - Too many requests

### General Errors
- `INTERNAL_ERROR` - An error occurred
- `NOT_IMPLEMENTED` - Feature not available
- `UNKNOWN_ERROR` - An unexpected error occurred

## Implementation Guide

### For PHP Controllers

**Basic Usage:**
```php
try {
    // Your code here
    $result = $this->someOperation();
    
    return [
        'success' => true,
        'data' => $result
    ];
} catch (Exception $e) {
    $this->log('error', 'Operation failed');
    return $this->secureErrorHandler->handleError('INTERNAL_ERROR', $e, [
        'action' => 'some_operation'
    ]);
}
```

**With Specific Error Code:**
```php
try {
    // Validate input
    if (empty($input)) {
        throw $this->secureErrorHandler->createSecureException('VALIDATION_REQUIRED');
    }
    
    // Your code here
    $result = $this->processInput($input);
    
    return [
        'success' => true,
        'data' => $result
    ];
} catch (Exception $e) {
    $this->log('error', 'Processing failed');
    return $this->secureErrorHandler->handleError('VALIDATION_FAILED', $e, [
        'action' => 'process_input',
        'input_type' => gettype($input)
    ]);
}
```

**With Context:**
```php
try {
    $result = $this->complexOperation($param1, $param2);
    
    return [
        'success' => true,
        'data' => $result
    ];
} catch (Exception $e) {
    $this->log('error', 'Complex operation failed');
    return $this->secureErrorHandler->handleError('INTERNAL_ERROR', $e, [
        'action' => 'complex_operation',
        'param1_type' => gettype($param1),
        'param2_type' => gettype($param2),
        'additional_context' => 'Some context here'
    ]);
}
```

### Error Message Levels

**User Messages (Generic):**
- "Invalid credentials"
- "Permission denied"
- "An error occurred"
- "Invalid input"

**Admin Messages (Detailed):**
- "Authentication failed: Invalid username or password"
- "Authorization failed: Insufficient permissions"
- "Internal server error"
- "Input validation failed"

**Debug Information (Debug Mode + Admin Only):**
- Exception type and message
- File and line number
- Stack trace
- Request context

### Exception Sanitization

The `sanitizeExceptionMessage()` method removes:
- File paths (Windows and Unix)
- Passwords, tokens, keys, secrets
- Sensitive patterns

**Example:**
```php
$exception = new Exception('Failed to connect to database at /var/lib/data/db with password=secret123');
$sanitized = $this->secureErrorHandler->sanitizeExceptionMessage($exception);
// Result: "Failed to connect to database at with password=***"
```

## Security Features

### Information Disclosure Prevention

1. **Generic User Messages:** End users see only generic error messages
2. **Detailed Admin Messages:** Administrators see detailed error information
3. **Debug Mode:** Debug information only available in debug mode for admins
4. **Exception Sanitization:** Sensitive information removed from messages
5. **Comprehensive Logging:** All errors logged with full details for administrators

### Role-Based Error Messages

**Regular Users:**
```json
{
  "success": false,
  "error": "AUTH_FAILED",
  "message": "Invalid credentials",
  "timestamp": "2026-05-04T12:00:00Z"
}
```

**Administrators:**
```json
{
  "success": false,
  "error": "AUTH_FAILED",
  "message": "Authentication failed: Invalid username or password",
  "timestamp": "2026-05-04T12:00:00Z"
}
```

**Debug Mode + Admin:**
```json
{
  "success": false,
  "error": "AUTH_FAILED",
  "message": "Authentication failed: Invalid username or password",
  "timestamp": "2026-05-04T12:00:00Z",
  "debug": {
    "exception": {
      "type": "Exception",
      "message": "Authentication failed: Invalid username or password",
      "file": "/path/to/file.php",
      "line": 42,
      "trace": "..."
    },
    "context": {
      "username": "user",
      "ip_address": "192.168.1.1"
    }
  }
}
```

## Configuration

### Enable Debug Mode

```php
$secureErrorHandler = new SecureErrorHandler($logFile, true, 'admin');
```

### Set User Role

```php
$secureErrorHandler->setUserRole('admin'); // or 'user', 'readonly'
```

### Register Error Handlers

```php
$secureErrorHandler->registerHandlers();
```

## Testing

### Manual Testing

1. **Test Generic Error Messages:**
   ```php
   $errorHandler = new SecureErrorHandler($logFile, false, 'user');
   $response = $errorHandler->handleError('AUTH_FAILED', new Exception('Test'));
   // Should show generic message
   ```

2. **Test Admin Error Messages:**
   ```php
   $errorHandler = new SecureErrorHandler($logFile, false, 'admin');
   $response = $errorHandler->handleError('AUTH_FAILED', new Exception('Test'));
   // Should show detailed message
   ```

3. **Test Debug Mode:**
   ```php
   $errorHandler = new SecureErrorHandler($logFile, true, 'admin');
   $response = $errorHandler->handleError('AUTH_FAILED', new Exception('Test'));
   // Should include debug information
   ```

### Security Testing

1. **Test Information Disclosure:**
   - Trigger errors with sensitive information
   - Verify generic messages for regular users
   - Verify detailed messages for administrators
   - Check that debug info is only available in debug mode

2. **Test Exception Sanitization:**
   - Create exceptions with file paths
   - Create exceptions with passwords/tokens
   - Verify sanitization removes sensitive data

3. **Test Logging:**
   - Trigger various errors
   - Check log files for detailed information
   - Verify all errors are logged appropriately

## Best Practices

1. **Always use secure error handling** in controllers
2. **Provide context** in error handling for better debugging
3. **Use appropriate error codes** for different error types
4. **Never expose sensitive information** to end users
5. **Log all errors** with sufficient detail for administrators
6. **Test error messages** for both users and administrators
7. **Keep error codes consistent** across the application
8. **Use generic messages** for security-sensitive operations

## Troubleshooting

### Common Issues

**Issue:** Error messages too generic for debugging
- **Solution:** Enable debug mode for administrators
- **Solution:** Check log files for detailed information

**Issue:** Sensitive information still exposed
- **Solution:** Ensure exception sanitization is working
- **Solution:** Check that debug mode is disabled for production

**Issue:** Error codes not recognized
- **Solution:** Verify error code exists in errorCodes array
- **Solution:** Add custom error codes if needed

### Debugging

**Check Error Handler Configuration:**
```php
$errorHandler = new SecureErrorHandler();
$errorCodes = $errorHandler->getErrorCodes();
print_r($errorCodes);
```

**Check Specific Error Code:**
```php
$errorHandler = new SecureErrorHandler();
$errorDef = $errorHandler->getErrorCodeDefinition('AUTH_FAILED');
print_r($errorDef);
```

**Test Error Handling:**
```php
$errorHandler = new SecureErrorHandler($logFile, true, 'admin');
$exception = new Exception('Test exception');
$response = $errorHandler->handleError('TEST_ERROR', $exception, ['test' => 'context']);
print_r($response);
```

## Migration Guide

### From Basic Exception Handling

**Before:**
```php
try {
    $result = $this->someOperation();
    return ['success' => true, 'data' => $result];
} catch (Exception $e) {
    return ['success' => false, 'error' => $e->getMessage()];
}
```

**After:**
```php
try {
    $result = $this->someOperation();
    return ['success' => true, 'data' => $result];
} catch (Exception $e) {
    $this->log('error', 'Operation failed');
    return $this->secureErrorHandler->handleError('INTERNAL_ERROR', $e, [
        'action' => 'some_operation'
    ]);
}
```

### From Custom Error Messages

**Before:**
```php
if (empty($input)) {
    throw new Exception('Input parameter is required and cannot be empty');
}
```

**After:**
```php
if (empty($input)) {
    throw $this->secureErrorHandler->createSecureException('VALIDATION_REQUIRED');
}
```

## Security Considerations

1. **Never log sensitive information** in user-facing messages
2. **Always sanitize exceptions** before displaying
3. **Use role-based messages** to prevent information disclosure
4. **Keep debug mode disabled** in production
5. **Review error messages** for information disclosure
6. **Test error handling** with different user roles
7. **Monitor error logs** for security incidents
8. **Implement rate limiting** on error endpoints

## References

- OWASP Error Handling: https://cheatsheetseries.owasp.org/cheatsheets/Error_Handling_Cheat_Sheet.html
- PHP Error Handling: https://www.php.net/manual/en/book.errorfunc.php
- Security Logging: https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html

---

**Last Updated:** 2026-05-04
**Status:** Implemented and tested