# Password Management Implementation

## Overview

The GPU Switch Manager now includes comprehensive password management with secure password policies, strength validation, history tracking, and forced password changes. This implementation follows OWASP guidelines and NIST password recommendations.

## Components

### 1. PasswordManager.php

**File:** `include/PasswordManager.php`

**Features:**
- Password strength validation
- Common password detection
- Secure password hashing (bcrypt)
- Password verification
- Password history tracking (last 5 passwords)
- Secure random password generation
- Password change requirement checking
- Password age tracking (90-day expiration)

**Key Methods:**
- `validatePasswordStrength($password)` - Validate password against requirements
- `hashPassword($password)` - Hash password using bcrypt
- `verifyPassword($password, $hash)` - Verify password against hash
- `addToPasswordHistory($username, $passwordHash)` - Add password to history
- `isPasswordInHistory($username, $password)` - Check if password was used before
- `generateSecurePassword($length)` - Generate cryptographically secure password
- `needsPasswordChange($username, $userData)` - Check if password change is required
- `markPasswordChanged($username, $userData)` - Mark password as changed

### 2. PasswordController.php

**File:** `include/PasswordController.php`

**Features:**
- Password change functionality
- Password strength validation
- Secure password generation
- Password requirements display
- Password change requirement checking
- Force password change (admin only)
- Password reset (admin only)

**Key Methods:**
- `changePassword($currentPassword, $newPassword, $confirmPassword)` - Change user password
- `validatePassword($password)` - Validate password strength
- `generatePassword($length)` - Generate secure password
- `getPasswordRequirements()` - Get password requirements
- `checkPasswordChangeRequired($username)` - Check if change is required
- `forcePasswordChange($username)` - Force password change for user
- `resetPassword($username, $generateNew)` - Reset user password

### 3. Setup Script

**File:** `scripts/setup_default_admin.sh`

**Features:**
- Creates default admin user
- Generates secure random password
- Sets password change requirement
- Configures secure file permissions
- Validates setup

**Usage:**
```bash
./scripts/setup_default_admin.sh
```

## Password Requirements

### Minimum Requirements
- **Length:** Minimum 12 characters
- **Uppercase:** At least one uppercase letter (A-Z)
- **Lowercase:** At least one lowercase letter (a-z)
- **Numbers:** At least one number (0-9)
- **Special Characters:** At least one special character (!@#$%^&*()_+-=[]{}|;:,.<>?)

### Password Strength Scoring
- **Weak:** Score < 60
- **Medium:** Score 60-79
- **Strong:** Score 80-100

**Scoring Criteria:**
- Minimum length: 20 points
- Uppercase letter: 20 points
- Lowercase letter: 20 points
- Number: 20 points
- Special character: 20 points

### Common Password Detection
The system automatically rejects common weak passwords including:
- password, 123456, qwerty, abc123
- monkey, master, dragon, 111111
- baseball, iloveyou, trustno1, sunshine
- And many more...

## Password Policies

### Password History
- **History Size:** Last 5 passwords
- **Reuse Prevention:** Cannot reuse recent passwords
- **History Storage:** Secure JSON file with 600 permissions

### Password Expiration
- **Maximum Age:** 90 days
- **Expiration Warning:** User notified before expiration
- **Forced Change:** Required after expiration

### Default Password Handling
- **Detection:** System identifies default passwords
- **Forced Change:** Required on first login
- **Security:** Default passwords marked as insecure

## Implementation Guide

### For Users

**Change Password:**
```php
$passwordController = new PasswordController();
$result = $passwordController->changePassword(
    $currentPassword,
    $newPassword,
    $confirmPassword
);
```

**Validate Password Strength:**
```php
$passwordManager = new PasswordManager();
$validation = $passwordManager->validatePasswordStrength($password);

if (!$validation['valid']) {
    echo "Password errors: " . implode(', ', $validation['errors']);
}
```

**Generate Secure Password:**
```php
$passwordManager = new PasswordManager();
$password = $passwordManager->generateSecurePassword(16);
echo "Generated password: $password";
```

### For Administrators

**Force Password Change:**
```php
$passwordController = new PasswordController();
$result = $passwordController->forcePasswordChange($username);
```

**Reset User Password:**
```php
$passwordController = new PasswordController();
$result = $passwordController->resetPassword($username, true);

if ($result['success']) {
    echo "New password: " . $result['new_password'];
    echo "Please communicate this securely to the user";
}
```

**Check Password Change Requirement:**
```php
$passwordController = new PasswordController();
$result = $passwordController->checkPasswordChangeRequired($username);

if ($result['required']) {
    echo "Password change required: " . $result['reason'];
}
```

## Security Features

### Password Hashing
- **Algorithm:** bcrypt (PASSWORD_DEFAULT)
- **Cost Factor:** Automatic (PHP default)
- **Salt:** Automatic (bcrypt includes salt)
- **Rehashing:** Automatic when PHP defaults change

### Password Storage
- **Format:** bcrypt hash
- **Permissions:** 600 (owner read/write only)
- **Location:** /var/lib/gpu-switch-manager/users.json
- **Backup:** Automatic backup before changes

### Password History
- **Storage:** Separate JSON file
- **Permissions:** 600 (owner read/write only)
- **Retention:** Last 5 passwords
- **Format:** Hash + timestamp

### Password Generation
- **Algorithm:** cryptographically secure random
- **Source:** random_bytes() and random_int()
- **Entropy:** High (128+ bits)
- **Distribution:** Uniform

## User Experience

### First Login Flow

1. **User logs in** with default credentials
2. **System detects** default password
3. **User redirected** to password change page
4. **User enters** new password
5. **System validates** password strength
6. **System checks** password history
7. **Password updated** and marked as changed
8. **User logged in** to system

### Password Change Flow

1. **User navigates** to password change page
2. **User enters** current password
3. **User enters** new password
4. **User confirms** new password
5. **System validates** current password
6. **System validates** new password strength
7. **System checks** password history
8. **Password updated** and added to history
9. **All sessions** destroyed (except current)
10. **Success message** displayed

### Password Reset Flow (Admin)

1. **Admin navigates** to user management
2. **Admin selects** user
3. **Admin clicks** "Reset Password"
4. **System generates** secure password
5. **System updates** user password
6. **System forces** password change
7. **Admin receives** new password
8. **Admin communicates** password securely to user
9. **User logs in** and must change password

## Configuration

### Password Requirements

```php
$config = [
    'min_length' => 12,
    'require_uppercase' => true,
    'require_lowercase' => true,
    'require_numbers' => true,
    'require_special_chars' => true,
    'max_history' => 5,
    'history_file' => '/var/lib/gpu-switch-manager/password_history.json'
];

$passwordManager = new PasswordManager($config);
```

### Password Expiration

```php
// Password expires after 90 days
$maxAge = 90 * 24 * 60 * 60; // 90 days in seconds

if (time() - $userData['password_changed_at'] > $maxAge) {
    // Force password change
}
```

## Testing

### Manual Testing

**Test Password Strength:**
```bash
# Test weak password
echo "password" | php -r '
$password = file_get_contents("php://stdin");
require "include/PasswordManager.php";
$pm = new PasswordManager();
print_r($pm->validatePasswordStrength($password));
'

# Test strong password
echo "MyStr0ng!P@ssw0rd" | php -r '
$password = file_get_contents("php://stdin");
require "include/PasswordManager.php";
$pm = new PasswordManager();
print_r($pm->validatePasswordStrength($password));
'
```

**Test Password Generation:**
```bash
php -r '
require "include/PasswordManager.php";
$pm = new PasswordManager();
echo $pm->generateSecurePassword(16) . "\n";
'
```

**Test Setup Script:**
```bash
./scripts/setup_default_admin.sh
```

### Security Testing

1. **Test Common Password Detection:**
   - Try common passwords (password, 123456, etc.)
   - Verify they are rejected

2. **Test Password History:**
   - Change password multiple times
   - Try to reuse old passwords
   - Verify they are rejected

3. **Test Password Strength:**
   - Try passwords without required characters
   - Verify they are rejected

4. **Test Password Expiration:**
   - Set password_changed_at to old date
   - Verify change is required

## Best Practices

1. **Always use strong passwords** - Minimum 12 characters with mixed types
2. **Never reuse passwords** - System tracks last 5 passwords
3. **Change passwords regularly** - Every 90 days recommended
4. **Never share passwords** - Use secure communication channels
5. **Use password managers** - Generate and store complex passwords
6. **Enable 2FA when available** - Additional security layer
7. **Monitor for suspicious activity** - Check login logs
8. **Report security issues** - Notify administrators immediately

## Troubleshooting

### Common Issues

**Issue:** Password change fails with "Invalid current password"
- **Solution:** Verify current password is correct
- **Solution:** Check caps lock and special characters

**Issue:** New password rejected as "too common"
- **Solution:** Choose a more unique password
- **Solution:** Avoid dictionary words and common patterns

**Issue:** Cannot reuse recent password
- **Solution:** Choose a completely new password
- **Solution:** Wait until password rotates out of history

**Issue:** Password change required on every login
- **Solution:** Check force_password_change flag
- **Solution:** Verify password was marked as changed

### Debugging

**Check Password Requirements:**
```php
$passwordManager = new PasswordManager();
print_r($passwordManager->getPasswordRequirements());
```

**Check Password History:**
```bash
cat /var/lib/gpu-switch-manager/password_history.json | jq
```

**Check User Data:**
```bash
cat /var/lib/gpu-switch-manager/users.json | jq '.users[] | select(.username == "admin")'
```

**Check Password Logs:**
```bash
tail -f /var/log/gpu.switch.manager.log | grep PASSWORD
```

## Security Considerations

1. **Never log passwords** - Only log password changes
2. **Never display passwords** - Except during admin reset
3. **Always use HTTPS** - Protect passwords in transit
4. **Always hash passwords** - Never store plain text
5. **Always use strong algorithms** - bcrypt with proper cost
6. **Always validate input** - Prevent injection attacks
7. **Always enforce policies** - Consistent security standards
8. **Always monitor access** - Detect suspicious activity

## Migration Guide

### From Simple Password Storage

**Before:**
```php
// Plain text password storage (INSECURE)
$user['password'] = $password;
```

**After:**
```php
// Secure password hashing
$passwordManager = new PasswordManager();
$user['password_hash'] = $passwordManager->hashPassword($password);
```

### From Basic Password Validation

**Before:**
```php
if (strlen($password) < 8) {
    throw new Exception('Password too short');
}
```

**After:**
```php
$passwordManager = new PasswordManager();
$validation = $passwordManager->validatePasswordStrength($password);
if (!$validation['valid']) {
    throw new Exception(implode(', ', $validation['errors']));
}
```

## References

- OWASP Password Storage: https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html
- NIST Digital Identity Guidelines: https://pages.nist.gov/800-63-3
- PHP Password Hashing: https://www.php.net/manual/en/book.password.php
- Bcrypt Algorithm: https://en.wikipedia.org/wiki/Bcrypt

---

**Last Updated:** 2026-05-04
**Status:** Implemented and tested