<?php

/**
 * AuthorizationService.php
 * Authorization service for GPU Switch Manager
 * Handles role-based access control (RBAC) and permission checking
 */

class AuthorizationService {
    private $permissions;
    private $logFile;

    /**
     * Constructor
     *
     * @param string $logFile Log file path
     */
    public function __construct($logFile = null) {
        $this->logFile = $logFile ?? '/var/log/gpu.switch.manager.log';
        $this->initializePermissions();
    }

    /**
     * Check if user has permission
     *
     * @param string $role User role
     * @param string $resource Resource identifier
     * @param string $action Action identifier
     * @return bool Permission status
     */
    public function hasPermission($role, $resource, $action) {
        try {
            // Check if role exists
            if (!isset($this->permissions[$role])) {
                $this->log('warning', "Unknown role: $role");
                return false;
            }

            // Check if resource exists for role
            if (!isset($this->permissions[$role][$resource])) {
                $this->log('warning', "Role $role has no permissions for resource: $resource");
                return false;
            }

            // Check if action is allowed
            $allowedActions = $this->permissions[$role][$resource];

            if ($allowedActions === '*') {
                return true; // All actions allowed
            }

            if (in_array($action, $allowedActions)) {
                return true;
            }

            $this->log('warning', "Role $role denied action $action on resource $resource");
            return false;
        } catch (Exception $e) {
            $this->log('error', 'Authorization check error: ' . $e->getMessage());
            return false;
        }
    }

    /**
     * Check if user has any of the required roles
     *
     * @param array $roles User roles
     * @param string $resource Resource identifier
     * @param string $action Action identifier
     * @return bool Permission status
     */
    public function hasAnyRole($roles, $resource, $action) {
        foreach ($roles as $role) {
            if ($this->hasPermission($role, $resource, $action)) {
                return true;
            }
        }

        return false;
    }

    /**
     * Check if user has all required roles
     *
     * @param array $roles User roles
     * @param string $resource Resource identifier
     * @param string $action Action identifier
     * @return bool Permission status
     */
    public function hasAllRoles($roles, $resource, $action) {
        foreach ($roles as $role) {
            if (!$this->hasPermission($role, $resource, $action)) {
                return false;
            }
        }

        return true;
    }

    /**
     * Get user permissions
     *
     * @param string $role User role
     * @return array User permissions
     */
    public function getUserPermissions($role) {
        return $this->permissions[$role] ?? [];
    }

    /**
     * Get all available roles
     *
     * @return array Available roles
     */
    public function getAvailableRoles() {
        return array_keys($this->permissions);
    }

    /**
     * Get role description
     *
     * @param string $role Role name
     * @return string Role description
     */
    public function getRoleDescription($role) {
        $descriptions = [
            'admin' => 'Full system access including all operations',
            'user' => 'Standard user access for GPU and configuration management',
            'readonly' => 'Read-only access for monitoring and viewing'
        ];

        return $descriptions[$role] ?? 'Unknown role';
    }

    /**
     * Require authentication
     *
     * @param array $user User data
     * @return void
     * @throws Exception If not authenticated
     */
    public function requireAuth($user) {
        if ($user === null || !isset($user['id'])) {
            throw new Exception('Authentication required', 401);
        }
    }

    /**
     * Require admin role
     *
     * @param array $user User data
     * @return void
     * @throws Exception If not admin
     */
    public function requireAdmin($user) {
        $this->requireAuth($user);

        if (!isset($user['role']) || $user['role'] !== 'admin') {
            throw new Exception('Administrator access required', 403);
        }
    }

    /**
     * Require specific permission
     *
     * @param array $user User data
     * @param string $resource Resource identifier
     * @param string $action Action identifier
     * @return void
     * @throws Exception If permission denied
     */
    public function requirePermission($user, $resource, $action) {
        $this->requireAuth($user);

        if (!$this->hasPermission($user['role'], $resource, $action)) {
            throw new Exception('Permission denied', 403);
        }
    }

    /**
     * Check if user can read resource
     *
     * @param array $user User data
     * @param string $resource Resource identifier
     * @return bool Read permission status
     */
    public function canRead($user, $resource) {
        if ($user === null) {
            return false;
        }

        return $this->hasPermission($user['role'], $resource, 'read');
    }

    /**
     * Check if user can write resource
     *
     * @param array $user User data
     * @param string $resource Resource identifier
     * @return bool Write permission status
     */
    public function canWrite($user, $resource) {
        if ($user === null) {
            return false;
        }

        return $this->hasPermission($user['role'], $resource, 'write');
    }

    /**
     * Check if user can delete resource
     *
     * @param array $user User data
     * @param string $resource Resource identifier
     * @return bool Delete permission status
     */
    public function canDelete($user, $resource) {
        if ($user === null) {
            return false;
        }

        return $this->hasPermission($user['role'], $resource, 'delete');
    }

    /**
     * Check if user can execute action
     *
     * @param array $user User data
     * @param string $resource Resource identifier
     * @param string $action Action identifier
     * @return bool Execute permission status
     */
    public function canExecute($user, $resource, $action) {
        if ($user === null) {
            return false;
        }

        return $this->hasPermission($user['role'], $resource, $action);
    }

    /**
     * Initialize permissions
     *
     * @return void
     */
    private function initializePermissions() {
        $this->permissions = [
            'admin' => [
                'config' => '*',
                'gpu' => '*',
                'events' => '*',
                'profiles' => '*',
                'preferences' => '*',
                'backups' => '*',
                'users' => '*',
                'system' => '*'
            ],
            'user' => [
                'config' => ['read', 'write'],
                'gpu' => ['read', 'bind', 'unbind', 'switch'],
                'events' => ['read'],
                'profiles' => ['read', 'create', 'activate'],
                'preferences' => ['read', 'write'],
                'backups' => ['read', 'create'],
                'users' => [],
                'system' => ['read']
            ],
            'readonly' => [
                'config' => ['read'],
                'gpu' => ['read'],
                'events' => ['read'],
                'profiles' => ['read'],
                'preferences' => ['read'],
                'backups' => ['read'],
                'users' => [],
                'system' => ['read']
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
        $logMessage = "[$timestamp] [$level] [AUTHZ_SERVICE] $message\n";

        if (file_exists($this->logFile)) {
            file_put_contents($this->logFile, $logMessage, FILE_APPEND);
        }
    }
}
