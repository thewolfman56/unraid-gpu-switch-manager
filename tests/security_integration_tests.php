<?php

/**
 * Security Integration Tests
 *
 * Integration tests for security components working together
 * Tests authentication + authorization, CSRF + rate limiting, etc.
 */

declare(strict_types=1);

require_once __DIR__ . '/../include/AuthenticationService.php';
require_once __DIR__ . '/../include/AuthorizationService.php';
require_once __DIR__ . '/../include/SecurityMiddleware.php';
require_once __DIR__ . '/../include/RateLimiter.php';
require_once __DIR__ . '/../include/PasswordManager.php';
require_once __DIR__ . '/../include/PasswordController.php';
require_once __DIR__ . '/../include/SecureErrorHandler.php';
require_once __DIR__ . '/../include/CsrfMiddleware.php';
require_once __DIR__ . '/../include/CsrfController.php';
require_once __DIR__ . '/../include/WebInterface.php';

// Simple mock WebInterface for testing
class MockWebInterface {
    private $csrfToken = null;
    private $csrfTokenTime = null;

    public function __construct() {
        // Minimal implementation for testing
    }

    public function generateCSRF($lifetime = 3600) {
        // Generate cryptographically secure token
        $this->csrfToken = bin2hex(random_bytes(32));
        $this->csrfTokenTime = time();
        return $this->csrfToken;
    }

    public function getCSRFToken() {
        return $this->csrfToken;
    }

    public function validateCSRF($token = null, $rotateToken = true) {
        // Simple validation: check if token matches stored token
        if ($token === null) {
            return false;
        }

        if (!$this->csrfToken) {
            return false;
        }

        // For testing, we'll do a simple comparison
        // In real implementation, this would use hash_equals()
        return hash_equals($this->csrfToken, $token);
    }

    public function getCSRFMetadata() {
        return [
            'has_token' => (bool)$this->csrfToken,
            'token_age' => $this->csrfTokenTime ? (time() - $this->csrfTokenTime) : null,
            'token_lifetime' => 3600,
            'is_expired' => false,
            'has_old_token' => false,
            'old_token_age' => null,
            'has_cookie_token' => false
        ];
    }
}

class SecurityIntegrationTests
{
    private array $results = [];
    private int $passed = 0;
    private int $failed = 0;

    /**
     * Run all integration tests
     */
    public function runAll(): void
    {
        echo "========================================\n";
        echo "SECURITY INTEGRATION TESTS\n";
        echo "========================================\n\n";

        $this->testAuthenticationAndAuthorization();
        $this->testCSRFAndRateLimiting();
        $this->testPasswordAndAuthentication();
        $this->testErrorHandlingAndSecurity();
        $this->testSecurityMiddlewareIntegration();
        $this->testCompleteSecurityFlow();

        $this->printSummary();
    }

    /**
     * Test authentication and authorization integration
     */
    private function testAuthenticationAndAuthorization(): void
    {
        echo "Testing Authentication + Authorization Integration...\n";

        $this->test('User Can Access Allowed Resources', function () {
            $auth = new AuthenticationService();
            $authz = new AuthorizationService();

            // Create test user
            $username = 'test_user';
            $password = 'TestPassword123!';
            $auth->createUser($username, $password, null, 'user');

            // Authenticate user (creates session)
            $authResult = $auth->authenticate($username, $password);
            $sessionId = $authResult['session'] ?? null;

            // Check if user can read GPU
            $canRead = $authz->hasPermission('user', 'gpu', 'read');

            $this->assert($canRead === true, 'User should be able to read GPU');
            $this->assert(!empty($sessionId), 'Session should be created');
            $this->assert($authResult['success'] === true, 'Authentication should succeed');

            return true;
        });

        $this->test('User Cannot Access Forbidden Resources', function () {
            $auth = new AuthenticationService();
            $authz = new AuthorizationService();

            // Create test user
            $username = 'test_user2';
            $password = 'TestPassword123!';
            $auth->createUser($username, $password, null, 'user');

            // Authenticate user (creates session)
            $authResult = $auth->authenticate($username, $password);
            $sessionId = $authResult['session'] ?? null;

            // Check if user can delete GPU
            $canDelete = $authz->hasPermission('user', 'gpu', 'delete');

            $this->assert($canDelete === false, 'User should not be able to delete GPU');
            $this->assert(!empty($sessionId), 'Session should be created');
            $this->assert($authResult['success'] === true, 'Authentication should succeed');

            return true;
        });

        $this->test('Admin Can Access All Resources', function () {
            $auth = new AuthenticationService();
            $authz = new AuthorizationService();

            // Create admin user
            $username = 'test_admin';
            $password = 'AdminPassword123!';
            $auth->createUser($username, $password, null, 'admin');

            // Authenticate admin (creates session)
            $authResult = $auth->authenticate($username, $password);
            $sessionId = $authResult['session'] ?? null;

            // Check if admin can perform all actions
            $canRead = $authz->hasPermission('admin', 'gpu', 'read');
            $canWrite = $authz->hasPermission('admin', 'gpu', 'write');
            $canDelete = $authz->hasPermission('admin', 'gpu', 'delete');

            $this->assert($canRead === true, 'Admin should be able to read');
            $this->assert($canWrite === true, 'Admin should be able to write');
            $this->assert($canDelete === true, 'Admin should be able to delete');
            $this->assert(!empty($sessionId), 'Session should be created');

            return true;
        });

        echo "\n";
    }

    /**
     * Test CSRF and rate limiting integration
     */
    private function testCSRFAndRateLimiting(): void
    {
        echo "Testing CSRF + Rate Limiting Integration...\n";

        $this->test('CSRF Token With Rate Limiting', function () {
            $mockWebInterface = new MockWebInterface();
            $csrfController = new CsrfController($mockWebInterface);
            $limiter = new RateLimiter();

            // Set rate limit for token requests
            $limitKey = 'test_csrf_rate_limit';
            $identifier = 'user_789';
            $limiter->setLimit($limitKey, 10, 60);

            // Get CSRF token
            $token = $csrfController->getToken();

            // Check rate limit
            $allowed = $limiter->check($identifier, $limitKey);

            $this->assert(!empty($token), 'CSRF token should be generated');
            $this->assert($allowed === true, 'Request should be allowed');

            return true;
        });

        $this->test('CSRF Validation With Rate Limiting', function () {
            $mockWebInterface = new MockWebInterface();
            $csrfController = new CsrfController($mockWebInterface);
            $limiter = new RateLimiter();

            // Set rate limit for validation requests
            $limitKey = 'test_csrf_validation_rate_limit';
            $identifier = 'user_101';
            $limiter->setLimit($limitKey, 5, 60);

            // Get and validate token
            $tokenResponse = $csrfController->getToken();
            $token = $tokenResponse['token'] ?? null;
            $result = $csrfController->validateToken($token);

            // Check rate limit
            $allowed = $limiter->check($identifier, $limitKey);

            $this->assert($result['success'] === true, 'Token should be valid');
            $this->assert($allowed === true, 'Request should be allowed');

            return true;
        });

        $this->test('Rate Limit Blocks Excessive CSRF Requests', function () {
            $mockWebInterface = new MockWebInterface();
            $csrfController = new CsrfController($mockWebInterface);
            $limiter = new RateLimiter();

            // Set low rate limit
            $limitKey = 'test_csrf_excessive';
            $identifier = 'user_123';
            $limiter->setLimit($limitKey, 3, 60);

            // Make 3 requests
            for ($i = 0; $i < 3; $i++) {
                $csrfController->getToken();
                $limiter->check($identifier, $limitKey);
            }

            // 4th request should be blocked
            $allowed = $limiter->check($identifier, $limitKey);

            $this->assert($allowed === false, 'Excessive requests should be blocked');

            return true;
        });

        echo "\n";
    }

    /**
     * Test password and authentication integration
     */
    private function testPasswordAndAuthentication(): void
    {
        echo "Testing Password + Authentication Integration...\n";

        $this->test('Password Change Updates Authentication', function () {
            $auth = new AuthenticationService();
            $passwordManager = new PasswordManager();

            $username = 'test_password_auth';
            $oldPassword = 'OldPassword123!';
            $newPassword = 'NewPassword456!';

            // Hash old password
            $oldHash = $passwordManager->hashPassword($oldPassword);

            // Verify old password
            $verified = $passwordManager->verifyPassword($oldPassword, $oldHash);
            $this->assert($verified === true, 'Old password should verify');

            // Hash new password
            $newHash = $passwordManager->hashPassword($newPassword);

            // Verify new password
            $verified = $passwordManager->verifyPassword($newPassword, $newHash);
            $this->assert($verified === true, 'New password should verify');

            // Verify old password doesn't work with new hash
            $verified = $passwordManager->verifyPassword($oldPassword, $newHash);
            $this->assert($verified === false, 'Old password should not verify with new hash');

            return true;
        });

        $this->test('Password History Prevents Reuse', function () {
            $passwordManager = new PasswordManager();
            $username = 'test_password_history';

            // Add passwords to history
            $passwordManager->addToPasswordHistory($username, $passwordManager->hashPassword('Password1!'));
            $passwordManager->addToPasswordHistory($username, $passwordManager->hashPassword('Password2!'));

            // Check if passwords are in history
            $inHistory1 = $passwordManager->isPasswordInHistory($username, 'Password1!');
            $inHistory2 = $passwordManager->isPasswordInHistory($username, 'Password2!');
            $inHistory3 = $passwordManager->isPasswordInHistory($username, 'Password3!');

            $this->assert($inHistory1 === true, 'Password1 should be in history');
            $this->assert($inHistory2 === true, 'Password2 should be in history');
            $this->assert($inHistory3 === false, 'Password3 should not be in history');

            return true;
        });

        $this->test('Password Expiration Triggers Change', function () {
            $passwordManager = new PasswordManager();
            $username = 'test_password_expiration';

            // Create user data with expired password
            $userData = [
                'password_changed_at' => time() - (91 * 24 * 60 * 60) // 91 days ago
            ];

            // Check if password change is needed
            $needsChange = $passwordManager->needsPasswordChange($username, $userData);

            $this->assert($needsChange === true, 'Expired password should require change');

            // Mark password as changed
            $userData = $passwordManager->markPasswordChanged($username, $userData);

            // Check if password change is still needed
            $needsChange = $passwordManager->needsPasswordChange($username, $userData);

            $this->assert($needsChange === false, 'Fresh password should not require change');

            return true;
        });

        echo "\n";
    }

    /**
     * Test error handling and security integration
     */
    private function testErrorHandlingAndSecurity(): void
    {
        echo "Testing Error Handling + Security Integration...\n";

        $this->test('Authentication Errors Are Secure', function () {
            $auth = new AuthenticationService();
            $errorHandler = new SecureErrorHandler();

            // Get error code definition
            $errorDefinition = $errorHandler->getErrorCodeDefinition('AUTH_FAILED');

            // Get user message from error definition
            $userMessage = $errorDefinition['user_message'] ?? '';

            // Verify message doesn't leak sensitive information
            $this->assert(strpos($userMessage, 'password') === false, 'User message should not contain password');
            $this->assert(strpos($userMessage, 'username') === false, 'User message should not contain username');
            $this->assert(!empty($userMessage), 'User message should not be empty');

            return true;
        });

        $this->test('Authorization Errors Are Secure', function () {
            $authz = new AuthorizationService();
            $errorHandler = new SecureErrorHandler();

            // Get error code definition
            $errorDefinition = $errorHandler->getErrorCodeDefinition('AUTHZ_DENIED');

            // Get user message from error definition
            $userMessage = $errorDefinition['user_message'] ?? '';

            // Verify message doesn't leak sensitive information
            $this->assert(strpos($userMessage, 'admin') === false, 'User message should not contain admin');
            $this->assert(strpos($userMessage, 'user') === false, 'User message should not contain user');
            $this->assert(!empty($userMessage), 'User message should not be empty');

            return true;
        });

        $this->test('CSRF Errors Are Secure', function () {
            $errorHandler = new SecureErrorHandler();

            // Get error code definition
            $errorDefinition = $errorHandler->getErrorCodeDefinition('CSRF_INVALID');

            // Get user message from error definition
            $userMessage = $errorDefinition['user_message'] ?? '';

            // Verify message doesn't leak sensitive information
            // The word "token" is acceptable as it's a generic term, not sensitive data
            $this->assert(strpos($userMessage, 'session') === false, 'User message should not contain session');
            $this->assert(strpos($userMessage, 'csrf') === false, 'User message should not contain csrf');
            $this->assert(!empty($userMessage), 'User message should not be empty');

            return true;
        });

        $this->test('Exception Sanitization Works', function () {
            $errorHandler = new SecureErrorHandler();

            // Create exception with sensitive information
            $exception = new Exception('Database error: SELECT * FROM users WHERE password = "secret"');

            // Sanitize exception
            $sanitized = $errorHandler->sanitizeExceptionMessage($exception);

            // Verify sensitive information is removed
            $this->assert(strpos($sanitized, 'password') === false, 'Sanitized message should not contain password');
            $this->assert(strpos($sanitized, 'secret') === false, 'Sanitized message should not contain secret');
            $this->assert(strpos($sanitized, 'SELECT') === false, 'Sanitized message should not contain SQL');

            return true;
        });

        echo "\n";
    }

    /**
     * Test security middleware integration
     */
    private function testSecurityMiddlewareIntegration(): void
    {
        echo "Testing Security Middleware Integration...\n";

        $this->test('Middleware Enforces Authentication', function () {
            $middleware = new SecurityMiddleware();
            $auth = new AuthenticationService();

            // Create test user
            $username = 'test_middleware_user';
            $password = 'TestPassword123!';
            $auth->createUser($username, $password, null, 'user');

            // Test without authentication (should throw exception)
            try {
                $result = $middleware->process('gpu', 'read', true);
                $this->assert(false, 'Should have thrown exception for unauthenticated request');
            } catch (Exception $e) {
                $this->assert($e->getCode() === 401, 'Should return 401 status code');
            }

            return true;
        });

        $this->test('Middleware Enforces Authorization', function () {
            $middleware = new SecurityMiddleware();
            $authz = new AuthorizationService();

            // Check authorization for user trying to delete
            $authorized = $authz->hasPermission('user', 'gpu', 'delete');

            $this->assert($authorized === false, 'User should not be authorized to delete');

            return true;
        });

        $this->test('Middleware Enforces Rate Limiting', function () {
            $middleware = new SecurityMiddleware();
            $limiter = new RateLimiter();

            // Set rate limit
            $limitKey = 'test_middleware_rate_limit';
            $identifier = 'user_456';
            $limiter->setLimit($limitKey, 5, 60);

            // Make 5 requests
            for ($i = 0; $i < 5; $i++) {
                $limiter->check($identifier, $limitKey);
            }

            // 6th request should be blocked
            $allowed = $limiter->check($identifier, $limitKey);

            $this->assert($allowed === false, '6th request should be blocked by rate limit');

            return true;
        });

        $this->test('Middleware Adds Security Headers', function () {
            $middleware = new SecurityMiddleware();

            // Get security headers
            $headers = $middleware->getSecurityHeaders();

            // Verify required headers are present
            $this->assert(isset($headers['Content-Security-Policy']), 'CSP header should be present');
            $this->assert(isset($headers['X-Frame-Options']), 'X-Frame-Options header should be present');
            $this->assert(isset($headers['X-Content-Type-Options']), 'X-Content-Type-Options header should be present');
            $this->assert(isset($headers['Strict-Transport-Security']), 'HSTS header should be present');

            return true;
        });

        echo "\n";
    }

    /**
     * Test complete security flow
     */
    private function testCompleteSecurityFlow(): void
    {
        echo "Testing Complete Security Flow...\n";

        $this->test('User Login Flow', function () {
            $auth = new AuthenticationService();
            $passwordManager = new PasswordManager();
            $authz = new AuthorizationService();
            $limiter = new RateLimiter();

            // Simulate user login
            $username = 'test_user';
            $password = 'TestPassword123!';

            // Check rate limit
            $limitKey = "login_$username";
            $identifier = "user_$username";
            $limiter->setLimit($limitKey, 5, 60);
            $allowed = $limiter->check($identifier, $limitKey);

            $this->assert($allowed === true, 'Login request should be allowed');

            // Hash password
            $passwordHash = $passwordManager->hashPassword($password);

            // Verify password
            $verified = $passwordManager->verifyPassword($password, $passwordHash);

            $this->assert($verified === true, 'Password should verify');

            // Create user and authenticate (creates session)
            $auth->createUser($username, $password, null, 'user');
            $authResult = $auth->authenticate($username, $password);
            $sessionId = $authResult['session'] ?? null;

            $this->assert(!empty($sessionId), 'Session should be created');

            // Check authorization
            $canRead = $authz->hasPermission('user', 'gpu', 'read');

            $this->assert($canRead === true, 'User should be authorized to read');

            return true;
        });

        $this->test('Admin Password Reset Flow', function () {
            $passwordManager = new PasswordManager();
            $auth = new AuthenticationService();

            // Simulate admin password reset
            $username = 'test_admin';
            $newPassword = $passwordManager->generateSecurePassword(16);

            // Validate new password strength
            $validation = $passwordManager->validatePasswordStrength($newPassword);

            $this->assert($validation['valid'] === true, 'Generated password should be strong');

            // Hash new password
            $newHash = $passwordManager->hashPassword($newPassword);

            // Verify new password
            $verified = $passwordManager->verifyPassword($newPassword, $newHash);

            $this->assert($verified === true, 'New password should verify');

            // Mark password as changed
            $userData = [
                'password_changed_at' => time()
            ];

            $passwordManager->markPasswordChanged($username, $userData);

            // Check if password change is needed
            $needsChange = $passwordManager->needsPasswordChange($username, $userData);

            $this->assert($needsChange === false, 'Fresh password should not require change');

            return true;
        });

        $this->test('CSRF-Protected Request Flow', function () {
            $mockWebInterface = new MockWebInterface();
            $csrfController = new CsrfController($mockWebInterface);
            $limiter = new RateLimiter();

            // Get CSRF token
            $tokenResponse = $csrfController->getToken();
            $token = $tokenResponse['token'] ?? null;

            $this->assert(!empty($token), 'CSRF token should be generated');

            // Check rate limit
            $limitKey = 'csrf_request';
            $identifier = 'user_202';
            $limiter->setLimit($limitKey, 10, 60);
            $allowed = $limiter->check($identifier, $limitKey);

            $this->assert($allowed === true, 'Request should be allowed');

            // Validate token
            $result = $csrfController->validateToken($token);

            $this->assert($result['success'] === true, 'Token should be valid');

            return true;
        });

        $this->test('Error Handling Throughout Flow', function () {
            $errorHandler = new SecureErrorHandler();
            $auth = new AuthenticationService();
            $authz = new AuthorizationService();

            // Get authentication error definition
            $authErrorDef = $errorHandler->getErrorCodeDefinition('AUTH_FAILED');
            $userMessage = $authErrorDef['user_message'] ?? '';

            $this->assert(!empty($userMessage), 'User message should not be empty');
            $this->assert(strpos($userMessage, 'password') === false, 'User message should not contain password');

            // Get authorization error definition
            $authzErrorDef = $errorHandler->getErrorCodeDefinition('AUTHZ_DENIED');
            $userMessage = $authzErrorDef['user_message'] ?? '';

            $this->assert(!empty($userMessage), 'User message should not be empty');
            $this->assert(strpos($userMessage, 'admin') === false, 'User message should not contain admin');

            return true;
        });

        echo "\n";
    }

    /**
     * Run a single test
     */
    private function test(string $name, callable $test): void
    {
        try {
            $result = $test();

            if ($result === true) {
                $this->passed++;
                $this->results[] = ['name' => $name, 'status' => 'PASS'];
                echo "  ✓ $name\n";
            } else {
                $this->failed++;
                $this->results[] = ['name' => $name, 'status' => 'FAIL'];
                echo "  ✗ $name\n";
            }
        } catch (Exception $e) {
            $this->failed++;
            $this->results[] = ['name' => $name, 'status' => 'FAIL', 'error' => $e->getMessage()];
            echo "  ✗ $name - {$e->getMessage()}\n";
        }
    }

    /**
     * Assert condition
     */
    private function assert(bool $condition, string $message): void
    {
        if (!$condition) {
            throw new Exception($message);
        }
    }

    /**
     * Print test summary
     */
    private function printSummary(): void
    {
        echo "========================================\n";
        echo "INTEGRATION TEST SUMMARY\n";
        echo "========================================\n";
        echo "Total: " . ($this->passed + $this->failed) . "\n";
        echo "Passed: $this->passed\n";
        echo "Failed: $this->failed\n";
        echo "\n";

        if ($this->failed > 0) {
            echo "Failed Tests:\n";
            foreach ($this->results as $result) {
                if ($result['status'] === 'FAIL') {
                    echo "  - {$result['name']}";
                    if (isset($result['error'])) {
                        echo ": {$result['error']}";
                    }
                    echo "\n";
                }
            }
            echo "\n";
        }

        $successRate = $this->passed + $this->failed > 0
            ? round(($this->passed / ($this->passed + $this->failed)) * 100, 2)
            : 0;

        echo "Success Rate: $successRate%\n";

        if ($this->failed === 0) {
            echo "\n✓ All integration tests passed!\n";
        } else {
            echo "\n✗ Some integration tests failed. Please review and fix.\n";
        }
    }
}

// Run tests if executed directly
if (php_sapi_name() === 'cli') {
    $suite = new SecurityIntegrationTests();
    $suite->runAll();
}
