<?php

/**
 * csrf_protection_test.php
 * Test script for CSRF protection implementation
 * Run with: php csrf_protection_test.php
 */

// Include required files
require_once __DIR__ . '/include/WebInterface.php';
require_once __DIR__ . '/include/CsrfMiddleware.php';
require_once __DIR__ . '/include/CsrfController.php';

class CSRFProtectionTest {
    private $webInterface;
    private $csrfMiddleware;
    private $csrfController;
    private $testsPassed = 0;
    private $testsFailed = 0;

    public function __construct() {
        $this->webInterface = new WebInterface();
        $this->csrfMiddleware = new CsrfMiddleware($this->webInterface);
        $this->csrfController = new CsrfController($this->webInterface);
    }

    /**
     * Run all tests
     */
    public function runAllTests() {
        echo "=== CSRF Protection Tests ===\n\n";

        $this->testTokenGeneration();
        $this->testTokenValidation();
        $this->testTokenRotation();
        $this->testDoubleSubmitPattern();
        $this->testTokenExpiration();
        $this->testValidationWindow();
        $this->testCSRFMetadata();
        $this->testCsrfController();

        echo "\n=== Test Results ===\n";
        echo "Passed: {$this->testsPassed}\n";
        echo "Failed: {$this->testsFailed}\n";
        echo "Total: " . ($this->testsPassed + $this->testsFailed) . "\n";

        return $this->testsFailed === 0;
    }

    /**
     * Test token generation
     */
    private function testTokenGeneration() {
        echo "Test: Token Generation\n";

        try {
            // Generate token
            $token = $this->webInterface->generateCSRF();

            // Verify token is not empty
            $this->assert(!empty($token), "Token should not be empty");

            // Verify token is 64 characters (32 bytes * 2 for hex)
            $this->assert(strlen($token) === 64, "Token should be 64 characters");

            // Verify token is hexadecimal
            $this->assert(ctype_xdigit($token), "Token should be hexadecimal");

            echo "✓ Token generation test passed\n\n";
        } catch (Exception $e) {
            echo "✗ Token generation test failed: " . $e->getMessage() . "\n\n";
        }
    }

    /**
     * Test token validation
     */
    private function testTokenValidation() {
        echo "Test: Token Validation\n";

        try {
            // Generate token
            $token = $this->webInterface->generateCSRF();

            // Test valid token
            $valid = $this->webInterface->validateCSRF($token, false);
            $this->assert($valid, "Valid token should pass validation");

            // Test invalid token
            $invalid = $this->webInterface->validateCSRF('invalid_token', false);
            $this->assert(!$invalid, "Invalid token should fail validation");

            // Test empty token
            $empty = $this->webInterface->validateCSRF('', false);
            $this->assert(!$empty, "Empty token should fail validation");

            echo "✓ Token validation test passed\n\n";
        } catch (Exception $e) {
            echo "✗ Token validation test failed: " . $e->getMessage() . "\n\n";
        }
    }

    /**
     * Test token rotation
     */
    private function testTokenRotation() {
        echo "Test: Token Rotation\n";

        try {
            // Generate initial token
            $initialToken = $this->webInterface->generateCSRF();

            // Validate token (should rotate)
            $this->webInterface->validateCSRF($initialToken, true);

            // Get new token
            $newToken = $this->webInterface->generateCSRF();

            // Verify tokens are different
            $this->assert($initialToken !== $newToken, "Token should rotate after validation");

            // Verify old token is still valid (validation window)
            $oldTokenValid = $this->webInterface->validateCSRF($initialToken, false);
            $this->assert($oldTokenValid, "Old token should be valid during validation window");

            echo "✓ Token rotation test passed\n\n";
        } catch (Exception $e) {
            echo "✗ Token rotation test failed: " . $e->getMessage() . "\n\n";
        }
    }

    /**
     * Test double-submit cookie pattern
     */
    private function testDoubleSubmitPattern() {
        echo "Test: Double-Submit Cookie Pattern\n";

        try {
            // Generate token
            $token = $this->webInterface->generateCSRF();

            // Simulate cookie token
            $_COOKIE['csrf_token'] = $token;

            // Test validation with matching tokens
            $valid = $this->webInterface->validateCSRF($token, false);
            $this->assert($valid, "Matching tokens should pass validation");

            // Test validation with mismatched tokens
            $_COOKIE['csrf_token'] = 'different_token';
            $invalid = $this->webInterface->validateCSRF($token, false);
            $this->assert(!$invalid, "Mismatched tokens should fail validation");

            // Reset cookie
            $_COOKIE['csrf_token'] = $token;

            echo "✓ Double-submit cookie pattern test passed\n\n";
        } catch (Exception $e) {
            echo "✗ Double-submit cookie pattern test failed: " . $e->getMessage() . "\n\n";
        }
    }

    /**
     * Test token expiration
     */
    private function testTokenExpiration() {
        echo "Test: Token Expiration\n";

        try {
            // Generate token with short lifetime
            $token = $this->webInterface->generateCSRF(1); // 1 second

            // Wait for token to expire
            sleep(2);

            // Test expired token
            $expired = $this->webInterface->validateCSRF($token, false);
            $this->assert(!$expired, "Expired token should fail validation");

            // Generate new token with normal lifetime
            $newToken = $this->webInterface->generateCSRF();

            // Test new token
            $valid = $this->webInterface->validateCSRF($newToken, false);
            $this->assert($valid, "New token should pass validation");

            echo "✓ Token expiration test passed\n\n";
        } catch (Exception $e) {
            echo "✗ Token expiration test failed: " . $e->getMessage() . "\n\n";
        }
    }

    /**
     * Test validation window
     */
    private function testValidationWindow() {
        echo "Test: Validation Window\n";

        try {
            // Generate initial token
            $initialToken = $this->webInterface->generateCSRF();

            // Rotate token
            $this->webInterface->validateCSRF($initialToken, true);

            // Get new token
            $newToken = $this->webInterface->generateCSRF();

            // Both tokens should be valid
            $oldValid = $this->webInterface->validateCSRF($initialToken, false);
            $newValid = $this->webInterface->validateCSRF($newToken, false);

            $this->assert($oldValid, "Old token should be valid during validation window");
            $this->assert($newValid, "New token should be valid");

            echo "✓ Validation window test passed\n\n";
        } catch (Exception $e) {
            echo "✗ Validation window test failed: " . $e->getMessage() . "\n\n";
        }
    }

    /**
     * Test CSRF metadata
     */
    private function testCSRFMetadata() {
        echo "Test: CSRF Metadata\n";

        try {
            // Generate token
            $this->webInterface->generateCSRF();

            // Get metadata
            $metadata = $this->webInterface->getCSRFMetadata();

            // Verify metadata structure
            $this->assert(isset($metadata['has_token']), "Metadata should have has_token");
            $this->assert(isset($metadata['token_age']), "Metadata should have token_age");
            $this->assert(isset($metadata['token_lifetime']), "Metadata should have token_lifetime");
            $this->assert(isset($metadata['is_expired']), "Metadata should have is_expired");
            $this->assert(isset($metadata['has_cookie_token']), "Metadata should have has_cookie_token");

            // Verify values
            $this->assert($metadata['has_token'], "Should have token");
            $this->assert(!$metadata['is_expired'], "Token should not be expired");

            echo "✓ CSRF metadata test passed\n\n";
        } catch (Exception $e) {
            echo "✗ CSRF metadata test failed: " . $e->getMessage() . "\n\n";
        }
    }

    /**
     * Test CSRF controller
     */
    private function testCsrfController() {
        echo "Test: CSRF Controller\n";

        try {
            // Test getToken
            $result = $this->csrfController->getToken();
            $this->assert($result['success'], "getToken should succeed");
            $this->assert(isset($result['token']), "Result should have token");

            // Test validateToken
            $token = $result['token'];
            $validation = $this->csrfController->validateToken($token);
            $this->assert($validation['success'], "validateToken should succeed");
            $this->assert($validation['valid'], "Token should be valid");

            // Test refreshToken
            $refresh = $this->csrfController->refreshToken();
            $this->assert($refresh['success'], "refreshToken should succeed");
            $this->assert(isset($refresh['token']), "Result should have token");

            // Test getMetadata
            $metadata = $this->csrfController->getMetadata();
            $this->assert($metadata['success'], "getMetadata should succeed");
            $this->assert(isset($metadata['metadata']), "Result should have metadata");

            echo "✓ CSRF controller test passed\n\n";
        } catch (Exception $e) {
            echo "✗ CSRF controller test failed: " . $e->getMessage() . "\n\n";
        }
    }

    /**
     * Assert condition
     */
    private function assert($condition, $message) {
        if ($condition) {
            $this->testsPassed++;
        } else {
            $this->testsFailed++;
            throw new Exception($message);
        }
    }
}

// Run tests
$test = new CSRFProtectionTest();
$success = $test->runAllTests();

exit($success ? 0 : 1);