# CSRF Protection Implementation

## Overview

The GPU Switch Manager now includes enhanced CSRF (Cross-Site Request Forgery) protection with token rotation and double-submit cookie pattern. This implementation follows OWASP guidelines and provides comprehensive protection against CSRF attacks.

## Components

### 1. Enhanced WebInterface.php

**File:** `include/WebInterface.php`

**New Features:**
- Token expiration (1 hour default)
- Token rotation after validation
- Double-submit cookie pattern
- Validation window (5 minutes)
- Automatic token cleanup

**Key Methods:**
- `generateCSRF($lifetime)` - Generate token with expiration
- `validateCSRF($token, $rotateToken)` - Validate with rotation
- `rotateCSRFToken()` - Rotate token after use
- `isCSRFTokenExpired()` - Check token expiration
- `setCSRFCookie()` - Set HttpOnly cookie
- `getCSRFMetadata()` - Get token metadata for debugging

### 2. CsrfMiddleware.php

**File:** `include/CsrfMiddleware.php`

**Features:**
- Centralized CSRF validation
- Route exemption support
- AJAX request validation
- CSRF header management
- Comprehensive error handling

**Usage:**
```php
$csrfMiddleware = new CsrfMiddleware($webInterface, $exemptRoutes);
$csrfMiddleware->handle($route, $method);
```

### 3. CsrfController.php

**File:** `include/CsrfController.php`

**Endpoints:**
- `GET /api/csrf/token` - Get new CSRF token
- `POST /api/csrf/validate` - Validate CSRF token
- `POST /api/csrf/refresh` - Refresh CSRF token
- `GET /api/csrf/metadata` - Get CSRF metadata

### 4. JavaScript Helper

**File:** `web/assets/js/csrf-protection.js`

**Features:**
- Automatic form protection
- AJAX request interception
- Automatic token refresh
- Meta tag management
- Fetch and XMLHttpRequest protection

**Usage:**
```html
<script src="/assets/js/csrf-protection.js"></script>
```

## Security Features

### Double-Submit Cookie Pattern

Tokens are stored in both:
1. **Session:** Server-side storage
2. **Cookie:** HttpOnly, Secure, SameSite=Strict

Validation requires both to match, preventing:
- Session theft attacks
- Cookie theft attacks
- Cross-origin requests

### Token Rotation

After successful validation:
1. New token generated
2. Old token kept for 5 minutes
3. Both tokens valid during window
4. Old token automatically cleaned up

Benefits:
- Prevents replay attacks
- Allows concurrent requests
- Maintains user experience

### Token Expiration

- Default lifetime: 1 hour
- Configurable per request
- Automatic cleanup
- Metadata available for debugging

## Implementation Guide

### For PHP Controllers

**Basic Usage:**
```php
// Validate CSRF token
if (!$this->webInterface->validateCSRF()) {
    throw new Exception('Invalid CSRF token');
}
```

**With Custom Token:**
```php
$token = $this->getRequestData('csrf_token');
if (!$this->webInterface->validateCSRF($token)) {
    throw new Exception('Invalid CSRF token');
}
```

**Without Rotation:**
```php
// Validate without rotating token
if (!$this->webInterface->validateCSRF($token, false)) {
    throw new Exception('Invalid CSRF token');
}
```

### For HTML Forms

**Automatic Protection:**
```html
<!-- CSRF token automatically added by JavaScript -->
<form method="POST" action="/api/gpu/bind">
    <input type="text" name="gpu_address" />
    <button type="submit">Bind GPU</button>
</form>
```

**Manual Protection:**
```html
<form method="POST" action="/api/gpu/bind">
    <input type="hidden" name="csrf_token" value="{{ csrf_token }}" />
    <input type="text" name="gpu_address" />
    <button type="submit">Bind GPU</button>
</form>
```

### For AJAX Requests

**Using Fetch:**
```javascript
// CSRF token automatically added by JavaScript
fetch('/api/gpu/bind', {
    method: 'POST',
    headers: {
        'Content-Type': 'application/json'
    },
    body: JSON.stringify({ gpu_address: '0000:01:00.0' })
});
```

**Manual Token:**
```javascript
const token = csrfProtection.getToken();
fetch('/api/gpu/bind', {
    method: 'POST',
    headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': token
    },
    body: JSON.stringify({ gpu_address: '0000:01:00.0' })
});
```

## Testing

### Manual Testing

1. **Test Token Generation:**
   ```bash
   curl -X GET http://localhost/api/csrf/token
   ```

2. **Test Token Validation:**
   ```bash
   curl -X POST http://localhost/api/csrf/validate \
     -H "Content-Type: application/json" \
     -d '{"token":"YOUR_TOKEN"}'
   ```

3. **Test Token Refresh:**
   ```bash
   curl -X POST http://localhost/api/csrf/refresh
   ```

### Security Testing

1. **Test CSRF Protection:**
   - Submit form without token → Should fail
   - Submit form with invalid token → Should fail
   - Submit form with valid token → Should succeed

2. **Test Token Rotation:**
   - Submit request with valid token
   - Try same token again → Should fail (rotated)
   - Submit new token → Should succeed

3. **Test Double-Submit Pattern:**
   - Manipulate session token → Should fail
   - Manipulate cookie token → Should fail
   - Both must match → Should succeed

## Configuration

### Token Lifetime

```php
// Set custom token lifetime (2 hours)
$token = $this->webInterface->generateCSRF(7200);
```

### Route Exemptions

```php
// Exempt specific routes from CSRF validation
$exemptRoutes = [
    '/api/auth/login',
    '/api/auth/logout',
    '/api/public/*'
];

$csrfMiddleware = new CsrfMiddleware($webInterface, $exemptRoutes);
```

### Validation Window

```php
// Adjust validation window in WebInterface.php
private function cleanupOldCSRFTokens() {
    $validationWindow = 300; // 5 minutes (adjust as needed)
    // ...
}
```

## Troubleshooting

### Common Issues

**Issue:** "CSRF validation failed"
- **Solution:** Ensure token is included in request
- **Solution:** Check that token hasn't expired
- **Solution:** Verify token matches both session and cookie

**Issue:** Token expires too quickly
- **Solution:** Increase token lifetime
- **Solution:** Implement automatic token refresh

**Issue:** Concurrent requests fail
- **Solution:** Use validation window
- **Solution:** Disable token rotation for specific endpoints

### Debugging

**Get CSRF Metadata:**
```php
$metadata = $this->webInterface->getCSRFMetadata();
// Returns: has_token, token_age, token_lifetime, is_expired, etc.
```

**Check Logs:**
```bash
tail -f /var/log/gpu.switch.manager.log | grep CSRF
```

## Security Best Practices

1. **Always validate CSRF tokens** for state-changing operations
2. **Use HttpOnly cookies** to prevent JavaScript access
3. **Implement token rotation** to prevent replay attacks
4. **Set appropriate token lifetimes** based on risk assessment
5. **Log CSRF events** for security monitoring
6. **Test CSRF protection** regularly
7. **Keep tokens confidential** - never log or expose them

## References

- OWASP CSRF Prevention Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html
- PHP Session Security: https://www.php.net/manual/en/session.security.php
- Double-Submit Cookie Pattern: https://www.owasp.org/index.php/Cross-Site_Request_Forgery_(CSRF)_Prevention_Cheat_Sheet#Double_Submit_Cookie

---

**Last Updated:** 2026-05-04
**Status:** Implemented and tested