//
//  WebSocketManager.swift
//  reMIND Watch App
//
//  WebSocket connection manager using URLSessionWebSocketTask
//

import Foundation
import os

/// WebSocket connection manager
actor WebSocketManager {
    // MARK: - Properties

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private let url: URL
    private let apiKey: String

    private var isConnected = false
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = WebSocketConfiguration.maxReconnectAttempts

    // Delegate for receiving WebSocket lifecycle callbacks (must be held strongly)
    private var webSocketDelegate: WebSocketDelegate?

    // Event stream
    private var eventContinuation: AsyncStream<Result<Data, Error>>.Continuation?
    let eventStream: AsyncStream<Result<Data, Error>>

    // Connection state stream (for propagating state to VoiceLiveConnection)
    private var connectionStateContinuation: AsyncStream<ConnectionState>.Continuation?
    let connectionStateStream: AsyncStream<ConnectionState>

    // Heartbeat tracking
    private var heartbeatTask: Task<Void, Never>?
    private var lastMessageTime = Date()
    private var receiveTask: Task<Void, Never>?

    // MARK: - Initialization

    init(url: URL, apiKey: String) {
        self.url = url
        self.apiKey = apiKey

        // Create event stream
        var eventContinuationHolder: AsyncStream<Result<Data, Error>>.Continuation?
        self.eventStream = AsyncStream { continuation in
            eventContinuationHolder = continuation
        }
        self.eventContinuation = eventContinuationHolder

        // Create connection state stream
        var stateContinuationHolder: AsyncStream<ConnectionState>.Continuation?
        self.connectionStateStream = AsyncStream { continuation in
            stateContinuationHolder = continuation
        }
        self.connectionStateContinuation = stateContinuationHolder
    }

    // MARK: - Connection Management

    /// Connect to WebSocket and wait for handshake to complete
    func connect() async throws {
        guard !isConnected else {
            AppLogger.network.warning("Already connected to WebSocket")
            return
        }

        AppLogger.network.info("Connecting to WebSocket: \(self.url.absoluteString)")
        connectionStateContinuation?.yield(.connecting)

        // Create delegate with callback to handle state changes
        let delegate = WebSocketDelegate { [weak self] event in
            Task { [weak self] in
                await self?.handleConnectionEvent(event)
            }
        }
        self.webSocketDelegate = delegate

        // Create URLSession configuration optimized for watchOS
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = WebSocketConfiguration.connectionTimeout
        configuration.timeoutIntervalForResource = WebSocketConfiguration.resourceTimeout

        // On real watchOS hardware, waitsForConnectivity can cause the system to
        // indefinitely wait for a "better" network path (e.g., WiFi instead of BT relay)
        // instead of using what's available. Disable it so we fail fast and can retry.
        configuration.waitsForConnectivity = false

        // Use default network service type. On watchOS, .responsiveData rejects the
        // iPhone Bluetooth relay path (classified as high-latency), causing "Internet
        // connection appears to be offline" errors even when HTTP works fine.
        configuration.networkServiceType = .default

        // Allow connection over cellular (important for cellular Apple Watches)
        configuration.allowsCellularAccess = true

        // Constrained network handling for weak signals
        if #available(watchOS 9.0, *) {
            configuration.allowsConstrainedNetworkAccess = true
            configuration.allowsExpensiveNetworkAccess = true
        }

        // Note: shouldUseExtendedBackgroundIdleMode is intentionally not set here.
        // It requires background mode entitlements, and on watchOS it can cause the
        // system to reject connections when those entitlements are missing.

        // Create session with delegate
        session = URLSession(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: nil  // Use concurrent queue
        )

        // Create request with authentication
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "api-key")
        request.timeoutInterval = 30

        // Create WebSocket task
        guard let session = session else {
            throw WebSocketError.sessionCreationFailed
        }

        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()

        // Wait for delegate callback (didOpenWithProtocol or error) with timeout.
        // On real watchOS hardware, the delegate callback may never fire if the
        // WebSocket upgrade fails silently (e.g., Bluetooth relay, TLS issues).
        let handshakeTimeout = WebSocketConfiguration.connectionTimeout
        try await withThrowingTaskGroup(of: Bool.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    delegate.setConnectionContinuation(continuation)
                }
                return true  // handshake succeeded
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(handshakeTimeout * 1_000_000_000))
                return false  // timed out
            }

            // Take the first result
            let succeeded = try await group.next() ?? false
            // Clear continuation before cancelling to avoid resuming a cancelled continuation
            delegate.clearConnectionContinuation()
            group.cancelAll()

            if !succeeded {
                throw WebSocketError.connectionFailed(
                    NSError(domain: "WebSocket", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "WebSocket handshake timed out after \(Int(handshakeTimeout))s"
                    ])
                )
            }
        }

        // Connection is now established (delegate callback received)
        isConnected = true
        reconnectAttempts = 0
        lastMessageTime = Date()

        connectionStateContinuation?.yield(.connected)
        AppLogger.network.info("WebSocket connected (handshake complete)")

        // Start receiving messages and heartbeat
        startReceiving()
        startHeartbeat()
    }

    /// Disconnect from WebSocket
    /// - Parameter preserveEventStream: If true, keeps the event stream alive for reconnection
    func disconnect(preserveEventStream: Bool = false) async {
        AppLogger.network.info("Disconnecting from WebSocket")

        // Clear continuation to prevent callback after intentional disconnect
        webSocketDelegate?.clearConnectionContinuation()

        // Cancel tasks
        heartbeatTask?.cancel()
        heartbeatTask = nil
        receiveTask?.cancel()
        receiveTask = nil

        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        session?.invalidateAndCancel()
        session = nil

        isConnected = false
        webSocketDelegate = nil

        connectionStateContinuation?.yield(.disconnected)

        // Only finish the event stream if not preserving for reconnection
        if !preserveEventStream {
            eventContinuation?.finish()
        }

        AppLogger.network.info("WebSocket disconnected (preserveEventStream: \(preserveEventStream))")
    }

    /// Send data over WebSocket
    func send(_ data: Data) async throws {
        guard isConnected, let webSocketTask = webSocketTask else {
            throw WebSocketError.notConnected
        }

        let message = URLSessionWebSocketTask.Message.data(data)

        do {
            try await webSocketTask.send(message)
        } catch {
            AppLogger.logError(error, category: AppLogger.network, context: "WebSocket send failed")
            throw WebSocketError.sendFailed(error)
        }
    }

    /// Send text over WebSocket
    func send(_ text: String) async throws {
        guard isConnected, let webSocketTask = webSocketTask else {
            throw WebSocketError.notConnected
        }

        let message = URLSessionWebSocketTask.Message.string(text)

        do {
            try await webSocketTask.send(message)
        } catch {
            AppLogger.logError(error, category: AppLogger.network, context: "WebSocket send failed")
            throw WebSocketError.sendFailed(error)
        }
    }

    // MARK: - Connection Event Handling

    private func handleConnectionEvent(_ event: WebSocketConnectionEvent) {
        switch event {
        case .didOpen:
            // Handled by continuation in connect()
            break

        case .didClose(let closeCode, let reason):
            AppLogger.network.info("WebSocket closed via delegate: \(closeCode.rawValue)")
            if isConnected {
                isConnected = false
                connectionStateContinuation?.yield(.disconnected)
                eventContinuation?.yield(.failure(WebSocketError.connectionClosed(
                    closeCode: closeCode,
                    reason: reason
                )))
            }

        case .didFail(let error):
            AppLogger.network.error("WebSocket failed via delegate: \(error.localizedDescription)")
            if isConnected {
                isConnected = false
                connectionStateContinuation?.yield(.error(error.localizedDescription))
                eventContinuation?.yield(.failure(error))
            }
        }
    }

    // MARK: - Private Methods

    private func startReceiving() {
        receiveTask?.cancel()

        receiveTask = Task {
            guard let webSocketTask = webSocketTask else { return }

            AppLogger.network.debug("Starting to receive WebSocket messages...")

            do {
                while isConnected && !Task.isCancelled {
                    let message = try await webSocketTask.receive()
                    lastMessageTime = Date()

                    switch message {
                    case .data(let data):
                        eventContinuation?.yield(.success(data))

                    case .string(let text):
                        if let data = text.data(using: .utf8) {
                            eventContinuation?.yield(.success(data))
                        }

                    @unknown default:
                        AppLogger.network.warning("Unknown WebSocket message type")
                    }
                }
            } catch {
                if isConnected && !Task.isCancelled {
                    // Log detailed error information
                    if let urlError = error as? URLError {
                        AppLogger.network.error("WebSocket URLError: code=\(urlError.code.rawValue), \(urlError.localizedDescription)")
                        if let underlyingError = urlError.userInfo[NSUnderlyingErrorKey] as? NSError {
                            AppLogger.network.error("Underlying error: \(underlyingError)")
                        }
                    }
                    AppLogger.logError(error, category: AppLogger.network, context: "WebSocket receive failed")
                    eventContinuation?.yield(.failure(error))

                    // Attempt reconnection with exponential backoff
                    await attemptReconnection()
                }
            }
        }
    }

    private func startHeartbeat() {
        heartbeatTask?.cancel()

        heartbeatTask = Task {
            while !Task.isCancelled && isConnected {
                try? await Task.sleep(nanoseconds: UInt64(WebSocketConfiguration.heartbeatInterval * 1_000_000_000))

                guard isConnected && !Task.isCancelled else { break }

                let timeSinceLastMessage = Date().timeIntervalSince(lastMessageTime)
                if timeSinceLastMessage > WebSocketConfiguration.silenceThreshold {
                    AppLogger.network.warning("No messages received in \(WebSocketConfiguration.silenceThreshold)s, connection may be dead")
                    await attemptReconnection()
                    break
                }

                // Send ping to keep connection alive
                webSocketTask?.sendPing { error in
                    if let error = error {
                        AppLogger.network.error("Heartbeat ping failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func attemptReconnection() async {
        guard reconnectAttempts < maxReconnectAttempts else {
            AppLogger.network.error("Max reconnection attempts reached")
            connectionStateContinuation?.yield(.error("Max reconnection attempts reached"))
            eventContinuation?.yield(.failure(WebSocketError.maxReconnectAttemptsReached))
            await disconnect()
            return
        }

        reconnectAttempts += 1

        // Emit reconnecting state
        connectionStateContinuation?.yield(.reconnecting(
            attempt: reconnectAttempts,
            maxAttempts: maxReconnectAttempts
        ))

        let delay = min(pow(2.0, Double(reconnectAttempts)), WebSocketConfiguration.maxReconnectDelay)
        AppLogger.network.info("Reconnecting in \(delay)s (attempt \(self.reconnectAttempts)/\(self.maxReconnectAttempts))")

        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        do {
            // Preserve event stream during reconnection so VoiceLiveConnection can keep listening
            await disconnect(preserveEventStream: true)
            try await connect()
        } catch {
            AppLogger.logError(error, category: AppLogger.network, context: "Reconnection failed")
            await attemptReconnection()
        }
    }

    // MARK: - State

    var connectionState: ConnectionState {
        if isConnected {
            return .connected
        } else if reconnectAttempts > 0 && reconnectAttempts < maxReconnectAttempts {
            return .reconnecting(attempt: reconnectAttempts, maxAttempts: maxReconnectAttempts)
        } else {
            return .disconnected
        }
    }
}
