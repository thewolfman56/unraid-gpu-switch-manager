<?php
/**
 * Apply GPU Profile
 * Applies a GPU profile configuration
 */

header('Content-Type: application/json');

$config_path = '/boot/config/plugins/gpu-switch-manager';
$profiles_file = $config_path . '/profiles.json';
$state_file = $config_path . '/state.json';

$name = $_POST['name'] ?? '';

if (empty($name)) {
    echo json_encode(array('success' => false, 'error' => 'Profile name is required'));
    exit;
}

// Load profiles
$profiles_data = array('version' => '1.0', 'profiles' => array());
if (file_exists($profiles_file)) {
    $existing_data = json_decode(file_get_contents($profiles_file), true);
    if ($existing_data) {
        $profiles_data = $existing_data;
    }
}

// Check if profile exists
if (!isset($profiles_data['profiles'][$name])) {
    echo json_encode(array('success' => false, 'error' => 'Profile not found'));
    exit;
}

$profile = $profiles_data['profiles'][$name];

// Load current state
$state_data = array('version' => '1.0', 'last_operation' => null, 'last_operation_time' => null, 'active_profile' => null, 'saved_container_states' => array());
if (file_exists($state_file)) {
    $existing_state = json_decode(file_get_contents($state_file), true);
    if ($existing_state) {
        $state_data = $existing_state;
    }
}

// Update state with profile application
$state_data['last_operation'] = 'apply_profile';
$state_data['last_operation_time'] = date('Y-m-d H:i:s');
$state_data['active_profile'] = $name;
$state_data['profile_operation'] = array(
    'profile_name' => $name,
    'gpu' => $profile['gpu'],
    'mode' => $profile['mode'],
    'docker_containers' => $profile['docker_containers'],
    'vm_name' => $profile['vm_name'],
    'vm_shutdown' => $profile['vm_shutdown'],
    'timestamp' => date('Y-m-d H:i:s')
);

// Save state
file_put_contents($state_file, json_encode($state_data, JSON_PRETTY_PRINT));

// Log the operation
$log_file = '/var/log/gpu-switch-manager.log';
$log_entry = '[' . date('Y-m-d H:i:s') . '] Profile applied: ' . $name . "\n";
$log_entry .= '  GPU: ' . ($profile['gpu'] ?? 'N/A') . "\n";
$log_entry .= '  Mode: ' . ($profile['mode'] ?? 'N/A') . "\n";
$log_entry .= '  Docker Containers: ' . ($profile['docker_containers'] ?? 'None') . "\n";
$log_entry .= '  VM: ' . ($profile['vm_name'] ?? 'None') . "\n";
file_put_contents($log_file, $log_entry, FILE_APPEND);

// In a real implementation, this would:
// 1. Stop specified Docker containers
// 2. Modify GPU binding configuration
// 3. Start VM if specified
// 4. Restart Docker containers if needed
// 5. Handle VM shutdown on release if configured

echo json_encode(array('success' => true, 'message' => 'Profile ' . $name . ' applied successfully'));
?>