<?php
/**
 * Get Docker Containers
 * Returns list of available Docker containers
 */

header('Content-Type: application/json');

$containers = array();

// Try to get container list from docker
$docker_output = shell_exec('docker ps -a --format "{{.Names}}\t{{.Status}}" 2>/dev/null');
if ($docker_output) {
    $lines = explode("\n", trim($docker_output));
    foreach ($lines as $line) {
        $parts = explode("\t", trim($line));
        if (count($parts) >= 1) {
            $containerName = $parts[0];
            $containerStatus = isset($parts[1]) ? $parts[1] : 'unknown';

            if (!empty($containerName)) {
                $containers[] = array(
                    'name' => $containerName,
                    'status' => $containerStatus
                );
            }
        }
    }
}

echo json_encode(array('containers' => $containers));
?>