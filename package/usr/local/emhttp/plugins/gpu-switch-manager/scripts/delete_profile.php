<?php
/**
 * Delete GPU Profile
 * Deletes an existing GPU profile
 */

header('Content-Type: application/json');

$config_path = '/boot/config/plugins/gpu-switch-manager';
$profiles_file = $config_path . '/profiles.json';

$name = $_POST['name'] ?? '';

if (empty($name)) {
    echo json_encode(array('success' => false, 'error' => 'Profile name is required'));
    exit;
}

// Load existing profiles
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

// Delete profile
unset($profiles_data['profiles'][$name]);

// Save profiles
file_put_contents($profiles_file, json_encode($profiles_data, JSON_PRETTY_PRINT));

echo json_encode(array('success' => true));
?>