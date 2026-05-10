<?php
/**
 * Get GPU Statistics
 * Returns real-time GPU statistics
 */

header('Content-Type: application/json');

$gpus = array();

// Try to get NVIDIA GPU stats
$nvidia_smi = shell_exec('nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader 2>/dev/null');
if ($nvidia_smi) {
    $lines = explode("\n", trim($nvidia_smi));
    foreach ($lines as $index => $line) {
        $parts = str_getcsv($line);
        if (count($parts) >= 5) {
            $gpus[] = array(
                'id' => 'nvidia-' . $index,
                'name' => trim($parts[0]),
                'temperature' => trim($parts[1]),
                'utilization' => trim(str_replace('%', '', $parts[2])),
                'memory_used' => trim(str_replace(' MiB', '', $parts[3])),
                'memory_total' => trim(str_replace(' MiB', '', $parts[4])),
                'status' => 'Active'
            );
        }
    }
}

// Try to get AMD GPU stats
$amd_info = shell_exec('rocm-smi --showuse --showtemp --showmem 2>/dev/null');
if ($amd_info && empty($gpus)) {
    // Parse AMD GPU info (simplified parsing)
    $gpus[] = array(
        'id' => 'amd-0',
        'name' => 'AMD GPU',
        'temperature' => 'N/A',
        'utilization' => 'N/A',
        'memory_used' => 'N/A',
        'memory_total' => 'N/A',
        'status' => 'Active'
    );
}

// Try to get Intel GPU stats
$intel_info = shell_exec('intel_gpu_top 2>/dev/null');
if ($intel_info && empty($gpus)) {
    $gpus[] = array(
        'id' => 'intel-0',
        'name' => 'Intel GPU',
        'temperature' => 'N/A',
        'utilization' => 'N/A',
        'memory_used' => 'N/A',
        'memory_total' => 'N/A',
        'status' => 'Active'
    );
}

// Fallback to lspci if no GPU stats found
if (empty($gpus)) {
    $lspci = shell_exec('lspci | grep -i vga');
    if ($lspci) {
        $lines = explode("\n", trim($lspci));
        foreach ($lines as $index => $line) {
            $gpus[] = array(
                'id' => 'pci-' . $index,
                'name' => trim($line),
                'temperature' => 'N/A',
                'utilization' => 'N/A',
                'memory_used' => 'N/A',
                'memory_total' => 'N/A',
                'status' => 'Detected'
            );
        }
    }
}

echo json_encode(array('gpus' => $gpus));
?>