<?php
/**
 * Get GPU Profiles
 * Returns list of all GPU profiles
 */

header('Content-Type: application/json');

$config_path = '/boot/config/plugins/gpu-switch-manager';
$profiles_file = $config_path . '/profiles.json';

$profiles = array();
if (file_exists($profiles_file)) {
    $data = json_decode(file_get_contents($profiles_file), true);
    if ($data && isset($data['profiles'])) {
        $profiles = $data['profiles'];
    }
}

echo json_encode(array('profiles' => $profiles));
?>