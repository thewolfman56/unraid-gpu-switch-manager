<?php
/**
 * Get GPU Binding Information
 * Returns current GPU binding status and driver information
 */

header('Content-Type: application/json');

$gpus = array();

// Get GPU information from lspci
$lspci_output = shell_exec('lspci -nn | grep -i vga');
if ($lspci_output) {
    $lines = explode("\n", trim($lspci_output));
    foreach ($lines as $index => $line) {
        // Parse PCI address and device info
        if (preg_match('/^([0-9a-fA-F:.]+)\s+(.+)$/', $line, $matches)) {
            $pci_address = $matches[1];
            $device_info = $matches[2];

            // Get driver information
            $driver_output = shell_exec("lspci -k -s $pci_address | grep 'Kernel driver in use'");
            $driver = 'Unknown';
            if ($driver_output && preg_match('/Kernel driver in use:\s*(.+)/', $driver_output, $driver_match)) {
                $driver = trim($driver_match[1]);
            }

            // Determine binding status based on driver
            $binding = 'Unknown';
            $available = true;

            if (strpos($driver, 'nvidia') !== false) {
                $binding = 'NVIDIA Driver';
            } elseif (strpos($driver, 'amdgpu') !== false || strpos($driver, 'radeon') !== false) {
                $binding = 'AMD Driver';
            } elseif (strpos($driver, 'i915') !== false) {
                $binding = 'Intel Driver';
            } elseif (strpos($driver, 'vfio-pci') !== false) {
                $binding = 'VFIO (VM Passthrough)';
                $available = false;
            } else {
                $binding = 'No Driver';
            }

            $gpus[] = array(
                'id' => $pci_address,
                'name' => $device_info,
                'binding' => $binding,
                'driver' => $driver,
                'available' => $available
            );
        }
    }
}

// If no GPUs found via lspci, try alternative methods
if (empty($gpus)) {
    // Try nvidia-smi for NVIDIA GPUs
    $nvidia_output = shell_exec('nvidia-smi -L 2>/dev/null');
    if ($nvidia_output) {
        $lines = explode("\n", trim($nvidia_output));
        foreach ($lines as $index => $line) {
            if (preg_match('/GPU\s+\d+:\s+(.+)\s+\(UUID:/', $line, $matches)) {
                $gpus[] = array(
                    'id' => 'nvidia-' . $index,
                    'name' => trim($matches[1]),
                    'binding' => 'NVIDIA Driver',
                    'driver' => 'nvidia',
                    'available' => true
                );
            }
        }
    }
}

echo json_encode(array('gpus' => $gpus));
?>