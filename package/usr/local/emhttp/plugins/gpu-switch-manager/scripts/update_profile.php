<?php
/**
 * Update GPU Profile
 * Updates an existing GPU profile with full configuration
 */

header('Content-Type: application/json');

$config_path = '/boot/config/plugins/gpu-switch-manager';
$profiles_file = $config_path . '/profiles.json';

$old_name = $_POST['old_name'] ?? '';
$profile_data_json = $_POST['profile_data'] ?? '';

if (empty($old_name) || empty($profile_data_json)) {
    echo json_encode(array('success' => false, 'error' => 'Old profile name and profile data are required'));
    exit;
}

$profile_data = json_decode($profile_data_json, true);
if (!$profile_data || empty($profile_data['name'])) {
    echo json_encode(array('success' => false, 'error' => 'Invalid profile data'));
    exit;
}

$new_name = $profile_data['name'];

// Load existing profiles
$profiles_data = array('version' => '1.0', 'profiles' => array());
if (file_exists($profiles_file)) {
    $existing_data = json_decode(file_get_contents($profiles_file), true);
    if ($existing_data) {
        $profiles_data = $existing_data;
    }
}

// Check if old profile exists
if (!isset($profiles_data['profiles'][$old_name])) {
    echo json_encode(array('success' => false, 'error' => 'Profile not found'));
    exit;
}

// If name changed, check if new name already exists
if ($new_name !== $old_name && isset($profiles_data['profiles'][$new_name])) {
    echo json_encode(array('success' => false, 'error' => 'Profile with new name already exists'));
    exit;
}

// Remove old profile if name changed
if ($new_name !== $old_name) {
    unset($profiles_data['profiles'][$old_name]);
}

// Update profile with full configuration
$profiles_data['profiles'][$new_name] = array(
    'name' => $new_name,
    'description' => $profile_data['description'] ?? '',
    'gpu' => $profile_data['gpu'] ?? '',
    'mode' => $profile_data['mode'] ?? 'host',
    'docker_containers' => $profile_data['docker_containers'] ?? '',
    'vm_name' => $profile_data['vm_name'] ?? '',
    'vm_shutdown' => $profile_data['vm_shutdown'] ?? 'false',
    'notes' => $profile_data['notes'] ?? '',
    'created' => $profiles_data['profiles'][$old_name]['created'] ?? date('Y-m-d H:i:s'),
    'updated' => $profile_data['updated'] ?? date('Y-m-d H:i:s')
);

// Save profiles
file_put_contents($profiles_file, json_encode($profiles_data, JSON_PRETTY_PRINT));

echo json_encode(array('success' => true));
?>