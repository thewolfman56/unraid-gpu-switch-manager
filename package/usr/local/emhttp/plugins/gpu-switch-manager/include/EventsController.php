<?php

/**
 * EventsController.php
 * Events monitoring controller for GPU Switch Manager
 * Handles event history, statistics, and active operations
 */

class EventsController {
    private $webInterface;
    private $eventHandler;
    private $securityMiddleware;
    private $secureErrorHandler;
    private $logFile;

    /**
     * Constructor
     *
     * @param WebInterface $webInterface Web interface instance
     * @param SecurityMiddleware $securityMiddleware Security middleware
     * @param SecureErrorHandler $secureErrorHandler Secure error handler
     * @param string $logFile Log file path
     */
    public function __construct($webInterface = null, $securityMiddleware = null, $secureErrorHandler = null, $logFile = null) {
        $this->webInterface = $webInterface ?? new WebInterface();
        $this->securityMiddleware = $securityMiddleware ?? new SecurityMiddleware();
        $this->secureErrorHandler = $secureErrorHandler ?? new SecureErrorHandler($logFile);
        $this->logFile = $logFile ?? '/var/log/gpu.switch.manager.log';

        // Initialize event handler
        $this->eventHandler = new EventHandler();
    }

    /**
     * Events main page
     *
     * @return string Rendered page
     */
    public function index() {
        try {
            // Require authentication
            $user = $this->securityMiddleware->process('events', 'read', true);

            $recentEvents = $this->getRecentEvents(20);
            $statistics = $this->getEventStatistics();
            $activeOperations = $this->getActiveOperations();

            $data = [
                'title' => 'Event Monitoring',
                'events' => $recentEvents,
                'statistics' => $statistics,
                'activeOperations' => $activeOperations,
                'user' => $user
            ];

            return $this->webInterface->renderPage('events/index', $data);
        } catch (Exception $e) {
            $this->log('error', 'Failed to load events page: ' . $e->getMessage());
            return $this->webInterface->renderError('Failed to load event information');
        }
    }

    /**
     * Get event history
     *
     * @param int $limit Number of events to return
     * @param int $offset Offset for pagination
     * @param string $eventType Filter by event type
     * @return array Event history
     */
    public function getEventHistory($limit = 100, $offset = 0, $eventType = null) {
        try {
            $events = $this->eventHandler->getEventHistory($limit, $offset, $eventType);

            return [
                'success' => true,
                'data' => $events,
                'count' => count($events),
                'limit' => $limit,
                'offset' => $offset
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to get event history: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Get recent events
     *
     * @param int $count Number of recent events
     * @return array Recent events
     */
    public function getRecentEvents($count = 20) {
        try {
            $events = $this->eventHandler->getRecentEvents($count);

            return [
                'success' => true,
                'data' => $events,
                'count' => count($events)
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to get recent events: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Get event statistics
     *
     * @param int $days Number of days to analyze
     * @return array Event statistics
     */
    public function getEventStatistics($days = 7) {
        try {
            $statistics = $this->eventHandler->getStatistics($days);

            return [
                'success' => true,
                'data' => $statistics,
                'days' => $days
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to get event statistics: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Get active operations
     *
     * @return array Active operations
     */
    public function getActiveOperations() {
        try {
            $operations = $this->eventHandler->getActiveOperations();

            return [
                'success' => true,
                'data' => $operations,
                'count' => count($operations)
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to get active operations: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Cancel operation
     *
     * @param string $operationId Operation ID
     * @return array Cancel result
     */
    public function cancelOperation($operationId) {
        try {
            // Validate CSRF token
            if (!$this->webInterface->validateCSRF()) {
                throw new Exception('Invalid CSRF token');
            }

            // Validate operation ID
            if (empty($operationId)) {
                throw new Exception('Operation ID is required');
            }

            // Cancel operation
            $result = $this->eventHandler->cancelOperation($operationId);

            $this->log('info', "Operation $operationId cancelled successfully");

            return [
                'success' => true,
                'data' => $result,
                'message' => 'Operation cancelled successfully'
            ];
        } catch (Exception $e) {
            $this->log('error', "Failed to cancel operation $operationId: " . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Get event handler status
     *
     * @return array Event handler status
     */
    public function getEventHandlerStatus() {
        try {
            $status = $this->eventHandler->getStatus();

            return [
                'success' => true,
                'data' => $status
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to get event handler status: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Get event details
     *
     * @param string $eventId Event ID
     * @return array Event details
     */
    public function getEventDetails($eventId) {
        try {
            $details = $this->eventHandler->getEventDetails($eventId);

            return [
                'success' => true,
                'data' => $details
            ];
        } catch (Exception $e) {
            $this->log('error', "Failed to get event details for $eventId: " . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Get event timeline
     *
     * @param string $gpuAddress GPU PCI address
     * @param int $days Number of days
     * @return array Event timeline
     */
    public function getEventTimeline($gpuAddress = null, $days = 7) {
        try {
            $timeline = $this->eventHandler->getTimeline($gpuAddress, $days);

            return [
                'success' => true,
                'data' => $timeline,
                'days' => $days,
                'gpuAddress' => $gpuAddress
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to get event timeline: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Get event types
     *
     * @return array Event types
     */
    public function getEventTypes() {
        try {
            $types = $this->eventHandler->getEventTypes();

            return [
                'success' => true,
                'data' => $types
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to get event types: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Clear event history
     *
     * @param int $days Keep events from last N days
     * @return array Clear result
     */
    public function clearEventHistory($days = 30) {
        try {
            // Validate CSRF token
            if (!$this->webInterface->validateCSRF()) {
                throw new Exception('Invalid CSRF token');
            }

            // Clear event history
            $result = $this->eventHandler->clearHistory($days);

            $this->log('info', "Event history cleared (kept last $days days)");

            return [
                'success' => true,
                'data' => $result,
                'message' => "Event history cleared (kept last $days days)"
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to clear event history: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Export event history
     *
     * @param string $format Export format (json, csv)
     * @param int $days Number of days to export
     * @return array Export result
     */
    public function exportEventHistory($format = 'json', $days = 30) {
        try {
            $events = $this->eventHandler->getEventHistory(0, 0, null, $days);

            $exported = $this->formatExport($events, $format);

            $this->log('info', "Event history exported in $format format");

            return [
                'success' => true,
                'data' => $exported,
                'format' => $format,
                'count' => count($events)
            ];
        } catch (Exception $e) {
            $this->log('error', 'Failed to export event history: ' . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Get operation progress
     *
     * @param string $operationId Operation ID
     * @return array Operation progress
     */
    public function getOperationProgress($operationId) {
        try {
            $progress = $this->eventHandler->getOperationProgress($operationId);

            return [
                'success' => true,
                'data' => $progress
            ];
        } catch (Exception $e) {
            $this->log('error', "Failed to get operation progress for $operationId: " . $e->getMessage());
            return [
                'success' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    /**
     * Format export data
     *
     * @param array $data Data to format
     * @param string $format Format type
     * @return string Formatted data
     */
    private function formatExport($data, $format) {
        switch ($format) {
            case 'json':
                return json_encode($data, JSON_PRETTY_PRINT);

            case 'csv':
                if (empty($data)) {
                    return '';
                }

                $headers = array_keys($data[0]);
                $csv = implode(',', $headers) . "\n";

                foreach ($data as $row) {
                    $values = array_map(function($value) {
                        if (is_array($value)) {
                            return json_encode($value);
                        }
                        return '"' . str_replace('"', '""', $value) . '"';
                    }, $row);
                    $csv .= implode(',', $values) . "\n";
                }

                return $csv;

            default:
                return json_encode($data, JSON_PRETTY_PRINT);
        }
    }

    /**
     * Log message
     *
     * @param string $level Log level
     * @param string $message Log message
     */
    private function log($level, $message) {
        $timestamp = date('Y-m-d H:i:s');
        $logMessage = "[$timestamp] [$level] [EVENTS_CONTROLLER] $message\n";

        if (file_exists($this->logFile)) {
            file_put_contents($this->logFile, $logMessage, FILE_APPEND);
        }
    }
}
