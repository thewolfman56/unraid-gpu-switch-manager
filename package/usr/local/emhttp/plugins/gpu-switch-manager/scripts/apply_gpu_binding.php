<?php
/**
 * Apply GPU Binding
 * Applies GPU binding configuration
 */

header('Content-Type: application/json');

$gpu_id = $_POST['gpu_id'] ?? '';
$binding_mode = $_POST['binding_mode'] ?? '';

if (empty($gpu_id) || empty($binding_mode)) {
    echo json_encode(array('success' => false, 'error' => 'GPU ID and binding mode are required'));
    exit;
}

$config_path = '/boot/config/plugins/gpu-switch-manager';
$state_file = $config_path . '/state.json';

// Load current state
$state_data = array('version' => '1.0', 'last_operation' => null, 'last_operation_time' => null, 'active_profile' => null, 'saved_container_states' => array());
if (file_exists($state_file)) {
    $existing_data = json_decode(file_get_contents($state_file), true);
    if ($existing_data) {
        $state_data = $existing_data;
    }
}

// Update state with new binding operation
$state_data['last_operation'] = 'apply_binding';
$state_data['last_operation_time'] = date('Y-m-d H:i:s');
$state_data['binding_operation'] = array(
    'gpu_id' => $gpu_id,
    'binding_mode' => $binding_mode,
    'timestamp' => date('Y-m-d H:i:s')
);

// Save state
file_put_contents($state_file, json_encode($state_data, JSON_PRETTY_PRINT));

// Log the operation
$log_file = '/var/log/gpu-switch-manager.log';
$log_entry = '[' . date('Y-m-d H:i:s') . '] GPU binding operation: GPU=' . $gpu_id . ', Mode=' . $binding_mode . "\n";
file_put_contents($log_file, $log_entry, FILE_APPEND);

// In a real implementation, this would:
// 1. Modify VFIO configuration if needed
// 2. Update modprobe configurations
// 3. Handle Docker container states
// 4. Manage VM states
// 5. Restart services as needed

// For now, return success (actual implementation would be more complex)
echo json_encode(array('success' => true, 'message' => 'GPU binding operation queued'));
?>