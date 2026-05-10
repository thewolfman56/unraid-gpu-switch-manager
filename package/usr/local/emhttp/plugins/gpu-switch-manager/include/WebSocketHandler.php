<?php

/**
 * WebSocketHandler.php
 * WebSocket handler for GPU Switch Manager
 * Handles real-time updates, client connections, and message broadcasting
 */

class WebSocketHandler {
    private $clients = [];
    private $channels = [];
    private $securityMiddleware;
    private $logFile;
    private $running = false;

    /**
     * Constructor
     *
     * @param SecurityMiddleware $securityMiddleware Security middleware
     * @param string $logFile Log file path
     */
    public function __construct($securityMiddleware = null, $logFile = null) {
        $this->securityMiddleware = $securityMiddleware ?? new SecurityMiddleware();
        $this->logFile = $logFile ?? '/var/log/gpu.switch.manager.log';
    }

    /**
     * Start WebSocket server
     *
     * @param string $host Server host
     * @param int $port Server port
     * @return void
     */
    public function start($host = '0.0.0.0', $port = 8080) {
        try {
            $this->log('info', "Starting WebSocket server on $host:$port");

            $this->running = true;

            // Create socket
            $socket = socket_create(AF_INET, SOCK_STREAM, SOL_TCP);
            if ($socket === false) {
                throw new Exception('Failed to create socket');
            }

            socket_set_option($socket, SOL_SOCKET, SO_REUSEADDR, 1);

            if (socket_bind($socket, $host, $port) === false) {
                throw new Exception('Failed to bind socket');
            }

            if (socket_listen($socket) === false) {
                throw new Exception('Failed to listen on socket');
            }

            $this->log('info', "WebSocket server started successfully");

            // Main server loop
            while ($this->running) {
                // Accept new connections
                $clientSocket = socket_accept($socket);
                if ($clientSocket === false) {
                    continue;
                }

                // Handle client in separate process
                $this->handleClient($clientSocket);
            }

            // Close socket
            socket_close($socket);

            $this->log('info', 'WebSocket server stopped');
        } catch (Exception $e) {
            $this->log('error', 'WebSocket server error: ' . $e->getMessage());
            throw new Exception('WebSocket server error: ' . $e->getMessage());
        }
    }

    /**
     * Stop WebSocket server
     *
     * @return void
     */
    public function stop() {
        $this->log('info', 'Stopping WebSocket server');
        $this->running = false;

        // Disconnect all clients
        foreach ($this->clients as $clientId => $client) {
            $this->disconnect($clientId);
        }
    }

    /**
     * Handle client connection
     *
     * @param resource $socket Client socket
     * @return void
     */
    private function handleClient($socket) {
        $clientId = $this->generateClientId();

        $this->log('info', "Client connected: $clientId");

        // Perform WebSocket handshake
        if (!$this->performHandshake($socket)) {
            socket_close($socket);
            return;
        }

        // Add client to list
        $this->clients[$clientId] = [
            'socket' => $socket,
            'channels' => [],
            'connected' => time()
        ];

        // Send welcome message
        $this->sendToClient($clientId, [
            'type' => 'connected',
            'clientId' => $clientId,
            'timestamp' => time()
        ]);

        // Listen for messages
        while ($this->running) {
            $data = socket_read($socket, 2048);

            if ($data === false || strlen($data) === 0) {
                break;
            }

            // Decode message
            $message = $this->decodeMessage($data);

            if ($message !== null) {
                $this->handleMessage($clientId, $message);
            }
        }

        // Disconnect client
        $this->disconnect($clientId);
    }

    /**
     * Perform WebSocket handshake
     *
     * @param resource $socket Client socket
     * @return bool Handshake status
     */
    private function performHandshake($socket) {
        // Read handshake request
        $request = socket_read($socket, 2048);

        if ($request === false) {
            return false;
        }

        // Parse request
        $lines = explode("\r\n", $request);
        $headers = [];

        foreach ($lines as $line) {
            if (strpos($line, ':') !== false) {
                list($key, $value) = explode(':', $line, 2);
                $headers[trim($key)] = trim($value);
            }
        }

        // Validate WebSocket upgrade request
        if (!isset($headers['Upgrade']) || strtolower($headers['Upgrade']) !== 'websocket') {
            return false;
        }

        if (!isset($headers['Connection']) || strpos(strtolower($headers['Connection']), 'upgrade') === false) {
            return false;
        }

        if (!isset($headers['Sec-WebSocket-Key'])) {
            return false;
        }

        // Generate accept key
        $key = $headers['Sec-WebSocket-Key'];
        $acceptKey = base64_encode(pack('H*', sha1($key . '258EAFA5-E914-47DA-95CA-C5AB0DC85B11')));

        // Send handshake response
        $response = "HTTP/1.1 101 Switching Protocols\r\n";
        $response .= "Upgrade: websocket\r\n";
        $response .= "Connection: Upgrade\r\n";
        $response .= "Sec-WebSocket-Accept: $acceptKey\r\n";
        $response .= "\r\n";

        socket_write($socket, $response);

        return true;
    }

    /**
     * Decode WebSocket message
     *
     * @param string $data Encoded message
     * @return array|null Decoded message
     */
    private function decodeMessage($data) {
        // Parse frame
        $bytes = unpack('C*', $data);

        if (count($bytes) < 2) {
            return null;
        }

        $fin = ($bytes[1] & 0x80) !== 0;
        $opcode = $bytes[1] & 0x0F;
        $masked = ($bytes[2] & 0x80) !== 0;
        $payloadLen = $bytes[2] & 0x7F;

        $offset = 2;

        // Handle extended payload length
        if ($payloadLen === 126) {
            if (count($bytes) < 4) {
                return null;
            }
            $payloadLen = ($bytes[3] << 8) | $bytes[4];
            $offset = 4;
        } elseif ($payloadLen === 127) {
            if (count($bytes) < 10) {
                return null;
            }
            $payloadLen = ($bytes[3] << 56) | ($bytes[4] << 48) | ($bytes[5] << 40) |
                         ($bytes[6] << 32) | ($bytes[7] << 24) | ($bytes[8] << 16) |
                         ($bytes[9] << 8) | $bytes[10];
            $offset = 10;
        }

        // Handle masking
        if ($masked) {
            if (count($bytes) < $offset + 4 + $payloadLen) {
                return null;
            }

            $mask = array_slice($bytes, $offset + 1, 4);
            $offset += 4;
        }

        // Extract payload
        $payload = '';
        for ($i = 0; $i < $payloadLen; $i++) {
            $byte = $bytes[$offset + $i + 1];
            if ($masked) {
                $byte ^= $mask[$i % 4];
            }
            $payload .= chr($byte);
        }

        // Parse JSON payload
        $message = json_decode($payload, true);

        if ($message === null && json_last_error() !== JSON_ERROR_NONE) {
            return null;
        }

        return $message;
    }

    /**
     * Encode WebSocket message
     *
     * @param array $message Message to encode
     * @return string Encoded message
     */
    private function encodeMessage($message) {
        $payload = json_encode($message);

        $frame = chr(0x81); // FIN + text frame

        $payloadLen = strlen($payload);

        if ($payloadLen < 126) {
            $frame .= chr($payloadLen);
        } elseif ($payloadLen < 65536) {
            $frame .= chr(126) . chr($payloadLen >> 8) . chr($payloadLen & 0xFF);
        } else {
            $frame .= chr(127);
            for ($i = 7; $i >= 0; $i--) {
                $frame .= chr(($payloadLen >> ($i * 8)) & 0xFF);
            }
        }

        $frame .= $payload;

        return $frame;
    }

    /**
     * Handle incoming message
     *
     * @param string $clientId Client ID
     * @param array $message Message data
     * @return void
     */
    private function handleMessage($clientId, $message) {
        $type = $message['type'] ?? null;

        switch ($type) {
            case 'subscribe':
                $channel = $message['channel'] ?? null;
                if ($channel !== null) {
                    $this->subscribe($clientId, $channel);
                }
                break;

            case 'unsubscribe':
                $channel = $message['channel'] ?? null;
                if ($channel !== null) {
                    $this->unsubscribe($clientId, $channel);
                }
                break;

            case 'ping':
                $this->sendToClient($clientId, [
                    'type' => 'pong',
                    'timestamp' => time()
                ]);
                break;

            case 'broadcast':
                $channel = $message['channel'] ?? null;
                $data = $message['data'] ?? null;
                if ($channel !== null && $data !== null) {
                    $this->broadcast($channel, $data, $clientId);
                }
                break;

            default:
                $this->log('warning', "Unknown message type: $type");
                break;
        }
    }

    /**
     * Subscribe to channel
     *
     * @param string $clientId Client ID
     * @param string $channel Channel name
     * @return void
     */
    public function subscribe($clientId, $channel) {
        if (!isset($this->clients[$clientId])) {
            return;
        }

        if (!in_array($channel, $this->clients[$clientId]['channels'])) {
            $this->clients[$clientId]['channels'][] = $channel;
        }

        if (!isset($this->channels[$channel])) {
            $this->channels[$channel] = [];
        }

        if (!in_array($clientId, $this->channels[$channel])) {
            $this->channels[$channel][] = $clientId;
        }

        $this->log('info', "Client $clientId subscribed to channel: $channel");

        $this->sendToClient($clientId, [
            'type' => 'subscribed',
            'channel' => $channel,
            'timestamp' => time()
        ]);
    }

    /**
     * Unsubscribe from channel
     *
     * @param string $clientId Client ID
     * @param string $channel Channel name
     * @return void
     */
    public function unsubscribe($clientId, $channel) {
        if (!isset($this->clients[$clientId])) {
            return;
        }

        // Remove channel from client
        $this->clients[$clientId]['channels'] = array_filter(
            $this->clients[$clientId]['channels'],
            function($c) use ($channel) {
                return $c !== $channel;
            }
        );

        // Remove client from channel
        if (isset($this->channels[$channel])) {
            $this->channels[$channel] = array_filter(
                $this->channels[$channel],
                function($id) use ($clientId) {
                    return $id !== $clientId;
                }
            );

            // Remove channel if empty
            if (empty($this->channels[$channel])) {
                unset($this->channels[$channel]);
            }
        }

        $this->log('info', "Client $clientId unsubscribed from channel: $channel");

        $this->sendToClient($clientId, [
            'type' => 'unsubscribed',
            'channel' => $channel,
            'timestamp' => time()
        ]);
    }

    /**
     * Broadcast message to channel
     *
     * @param string $channel Channel name
     * @param array $message Message data
     * @param string|null $excludeClientId Client ID to exclude
     * @return void
     */
    public function broadcast($channel, $message, $excludeClientId = null) {
        if (!isset($this->channels[$channel])) {
            return;
        }

        $this->log('info', "Broadcasting to channel: $channel");

        foreach ($this->channels[$channel] as $clientId) {
            if ($excludeClientId !== null && $clientId === $excludeClientId) {
                continue;
            }

            $this->sendToClient($clientId, $message);
        }
    }

    /**
     * Send message to client
     *
     * @param string $clientId Client ID
     * @param array $message Message data
     * @return bool Send status
     */
    public function sendToClient($clientId, $message) {
        if (!isset($this->clients[$clientId])) {
            return false;
        }

        $socket = $this->clients[$clientId]['socket'];
        $encoded = $this->encodeMessage($message);

        $result = socket_write($socket, $encoded);

        if ($result === false) {
            $this->disconnect($clientId);
            return false;
        }

        return true;
    }

    /**
     * Disconnect client
     *
     * @param string $clientId Client ID
     * @return void
     */
    public function disconnect($clientId) {
        if (!isset($this->clients[$clientId])) {
            return;
        }

        $this->log('info', "Client disconnected: $clientId");

        // Unsubscribe from all channels
        foreach ($this->clients[$clientId]['channels'] as $channel) {
            $this->unsubscribe($clientId, $channel);
        }

        // Close socket
        $socket = $this->clients[$clientId]['socket'];
        socket_close($socket);

        // Remove client
        unset($this->clients[$clientId]);
    }

    /**
     * Get connected clients
     *
     * @return array Connected clients
     */
    public function getClients() {
        $clients = [];

        foreach ($this->clients as $clientId => $client) {
            $clients[$clientId] = [
                'clientId' => $clientId,
                'channels' => $client['channels'],
                'connected' => $client['connected'],
                'duration' => time() - $client['connected']
            ];
        }

        return $clients;
    }

    /**
     * Get channel subscribers
     *
     * @param string $channel Channel name
     * @return array Channel subscribers
     */
    public function getChannelSubscribers($channel) {
        if (!isset($this->channels[$channel])) {
            return [];
        }

        return $this->channels[$channel];
    }

    /**
     * Get all channels
     *
     * @return array All channels
     */
    public function getChannels() {
        $channels = [];

        foreach ($this->channels as $channel => $subscribers) {
            $channels[$channel] = [
                'name' => $channel,
                'subscribers' => count($subscribers),
                'subscriberIds' => $subscribers
            ];
        }

        return $channels;
    }

    /**
     * Generate unique client ID
     *
     * @return string Client ID
     */
    private function generateClientId() {
        return uniqid('client_', true);
    }

    /**
     * Log message
     *
     * @param string $level Log level
     * @param string $message Log message
     */
    private function log($level, $message) {
        $timestamp = date('Y-m-d H:i:s');
        $logMessage = "[$timestamp] [$level] [WEBSOCKET_HANDLER] $message\n";

        if (file_exists($this->logFile)) {
            file_put_contents($this->logFile, $logMessage, FILE_APPEND);
        }
    }
}
