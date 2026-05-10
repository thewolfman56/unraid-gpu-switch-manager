<?php
/**
 * Get VMs
 * Returns list of available VMs
 */

header('Content-Type: application/json');

$vms = array();

// Try to get VM list from virsh
$virsh_output = shell_exec('virsh list --all 2>/dev/null');
if ($virsh_output) {
    $lines = explode("\n", trim($virsh_output));
    foreach ($lines as $line) {
        // Skip header and separator lines
        if (strpos($line, 'Id') === 0 || strpos($line, '---') === 0 || strpos($line, '^') === 0) {
            continue;
        }

        // Parse VM info
        $parts = preg_split('/\s+/', trim($line));
        if (count($parts) >= 2) {
            $vmId = $parts[0];
            $vmName = $parts[1];
            $vmState = isset($parts[2]) ? $parts[2] : 'unknown';

            // Skip domain-0 (hypervisor)
            if ($vmName !== 'Domain-0') {
                $vms[] = array(
                    'id' => $vmId,
                    'name' => $vmName,
                    'state' => $vmState
                );
            }
        }
    }
}

echo json_encode(array('vms' => $vms));
?>