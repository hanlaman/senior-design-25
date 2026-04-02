//
//  WebSocketManager.swift
//  reMIND Watch App
//
//  WebSocket connection manager using Network.framework NWConnection.
//  Per TN3135, an active AVAudioSession enables low-level networking on watchOS.
//  The caller (VoiceConnectionCoordinator) activates the audio session before connecting.
//

import Foundation
import Network
import os

/// WebSocket connection manager using Network.framework
actor WebSocketManager {
    // MARK: - Properties

    private var connection: NWConnection?
    private let url: URL
    private let apiKey: String

    private var isConnected = false
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = WebSocketConfiguration.maxReconnectAttempts

    // Dispatch queue for NWConnection callbacks
    private let networkQueue = DispatchQueue(label: "com.remind.websocket", qos: .userInteractive)

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

        guard url.host != nil else {
            throw WebSocketError.invalidURL("Missing host in URL")
        }

        // Configure WebSocket protocol options
        let wsOptions = NWProtocolWebSocket.Options()
        wsOptions.autoReplyPing = true
        wsOptions.setAdditionalHeaders([
            ("api-key", apiKey)
        ])

        // Configure TLS
        let tlsOptions = NWProtocolTLS.Options()

        // Build network parameters. Per TN3135, an active AVAudioSession enables
        // all networking APIs on watchOS — including through the companion tunnel.
        // Don't restrict interface types; let the system choose the best path.
        let params = NWParameters(tls: tlsOptions)
        params.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)
        params.prohibitExpensivePaths = false
        params.prohibitConstrainedPaths = false
        params.serviceClass = .interactiveVoice

        // Create endpoint with full path
        let endpoint = NWEndpoint.url(url)

        // Create connection
        let nwConnection = NWConnection(to: endpoint, using: params)
        self.connection = nwConnection

        // Await connection ready state with timeout.
        // Use OSAllocatedUnfairLock to ensure the continuation is only resumed once,
        // since stateUpdateHandler can fire multiple state transitions.
        try await withThrowingTaskGroup(of: Bool.self) { group in
            group.addTask { [networkQueue] in
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
                    let resumed = OSAllocatedUnfairLock(initialState: false)

                    nwConnection.stateUpdateHandler = { state in
                        switch state {
                        case .ready:
                            AppLogger.network.info("NWConnection ready (WebSocket handshake complete)")
                            resumed.withLock { didResume in
                                guard !didResume else { return }
                                didResume = true
                                continuation.resume(returning: true)
                            }
                        case .failed(let error):
                            AppLogger.network.error("NWConnection failed: \(error.localizedDescription)")
                            resumed.withLock { didResume in
                                guard !didResume else { return }
                                didResume = true
                                continuation.resume(throwing: WebSocketError.connectionFailed(error))
                            }
                        case .waiting(let error):
                            // On watchOS, .waiting means no suitable path (e.g., no WiFi available)
                            AppLogger.network.warning("NWConnection waiting: \(error.localizedDescription)")
                            resumed.withLock { didResume in
                                guard !didResume else { return }
                                didResume = true
                                continuation.resume(throwing: WebSocketError.connectionFailed(error))
                            }
                        case .preparing:
                            AppLogger.network.debug("NWConnection preparing...")
                        case .setup:
                            break
                        case .cancelled:
                            resumed.withLock { didResume in
                                guard !didResume else { return }
                                didResume = true
                                continuation.resume(throwing: WebSocketError.connectionCancelled)
                            }
                        @unknown default:
                            break
                        }
                    }
                    nwConnection.start(queue: networkQueue)
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(WebSocketConfiguration.connectionTimeout * 1_000_000_000))
                return false  // timed out
            }

            let succeeded = try await group.next() ?? false
            group.cancelAll()

            if !succeeded {
                nwConnection.cancel()
                throw WebSocketError.connectionFailed(
                    NWError.posix(.ETIMEDOUT)
                )
            }
        }

        // Install permanent handlers for post-connection lifecycle events
        nwConnection.stateUpdateHandler = { [weak self] state in
            Task { [weak self] in
                await self?.handleConnectionStateChange(state)
            }
        }

        // Viability handler fires immediately when the connection can no longer
        // send/receive (e.g., WiFi drops). Much faster than heartbeat detection.
        nwConnection.viabilityUpdateHandler = { [weak self] isViable in
            if !isViable {
                AppLogger.network.warning("NWConnection is no longer viable (network path lost)")
                Task { [weak self] in
                    guard let self = self, await self.isConnected else { return }
                    await self.handleConnectionLost()
                }
            }
        }

        // Better path handler notifies when a higher-quality path becomes available
        // (e.g., WiFi restored after cellular fallback). Log it for diagnostics.
        nwConnection.betterPathUpdateHandler = { hasBetterPath in
            if hasBetterPath {
                AppLogger.network.info("NWConnection: better network path available")
            }
        }

        // Connection is now established
        isConnected = true
        reconnectAttempts = 0
        lastMessageTime = Date()

        connectionStateContinuation?.yield(.connected)
        AppLogger.network.info("WebSocket connected via NWConnection")

        // Start receiving messages and heartbeat
        startReceiving()
        startHeartbeat()
    }

    /// Disconnect from WebSocket
    /// - Parameter preserveEventStream: If true, keeps the event stream alive for reconnection
    func disconnect(preserveEventStream: Bool = false) async {
        AppLogger.network.info("Disconnecting from WebSocket")

        // Cancel tasks
        heartbeatTask?.cancel()
        heartbeatTask = nil
        receiveTask?.cancel()
        receiveTask = nil

        // Send close frame, clear handlers, and cancel connection
        if let connection = connection {
            // Clear handlers to break retain cycles before cancellation
            connection.stateUpdateHandler = nil
            connection.viabilityUpdateHandler = nil
            connection.betterPathUpdateHandler = nil

            let metadata = NWProtocolWebSocket.Metadata(opcode: .close)
            metadata.closeCode = .protocolCode(.goingAway)
            let context = NWConnection.ContentContext(
                identifier: "close",
                metadata: [metadata]
            )
            connection.send(content: nil, contentContext: context, isComplete: true, completion: .idempotent)
            connection.cancel()
        }
        connection = nil

        isConnected = false

        connectionStateContinuation?.yield(.disconnected)

        // Only finish the event stream if not preserving for reconnection
        if !preserveEventStream {
            eventContinuation?.finish()
        }

        AppLogger.network.info("WebSocket disconnected (preserveEventStream: \(preserveEventStream))")
    }

    /// Send data over WebSocket
    func send(_ data: Data) async throws {
        guard isConnected, let connection = connection else {
            throw WebSocketError.notConnected
        }

        let metadata = NWProtocolWebSocket.Metadata(opcode: .binary)
        let context = NWConnection.ContentContext(
            identifier: "binaryMessage",
            metadata: [metadata]
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { error in
                if let error = error {
                    AppLogger.logError(error, category: AppLogger.network, context: "WebSocket send (data) failed")
                    continuation.resume(throwing: WebSocketError.sendFailed(error))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    /// Send text over WebSocket
    func send(_ text: String) async throws {
        guard isConnected, let connection = connection else {
            throw WebSocketError.notConnected
        }

        guard let data = text.data(using: .utf8) else {
            throw WebSocketError.sendFailed(
                NSError(domain: "WebSocket", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode text as UTF-8"])
            )
        }

        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(
            identifier: "textMessage",
            metadata: [metadata]
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { error in
                if let error = error {
                    AppLogger.logError(error, category: AppLogger.network, context: "WebSocket send (text) failed")
                    continuation.resume(throwing: WebSocketError.sendFailed(error))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    // MARK: - Connection State Handling

    /// Called when viabilityUpdateHandler reports the connection is no longer viable
    private func handleConnectionLost() async {
        guard isConnected else { return }
        isConnected = false
        connectionStateContinuation?.yield(.disconnected)
        eventContinuation?.yield(.failure(WebSocketError.connectionFailed(
            NWError.posix(.ENETDOWN)
        )))

        // Attempt automatic reconnection
        await attemptReconnection()
    }

    private func handleConnectionStateChange(_ state: NWConnection.State) {
        switch state {
        case .failed(let error):
            AppLogger.network.error("WebSocket connection failed: \(error.localizedDescription)")
            if isConnected {
                isConnected = false
                connectionStateContinuation?.yield(.error(error.localizedDescription))
                eventContinuation?.yield(.failure(WebSocketError.connectionFailed(error)))
            }

        case .waiting(let error):
            AppLogger.network.warning("WebSocket connection waiting: \(error.localizedDescription)")
            if isConnected {
                isConnected = false
                connectionStateContinuation?.yield(.disconnected)
                eventContinuation?.yield(.failure(WebSocketError.connectionFailed(error)))
            }

        case .cancelled:
            if isConnected {
                isConnected = false
                connectionStateContinuation?.yield(.disconnected)
            }

        default:
            break
        }
    }

    // MARK: - Private Methods

    private func startReceiving() {
        receiveTask?.cancel()

        receiveTask = Task { [weak self] in
            AppLogger.network.debug("Starting to receive WebSocket messages...")

            while let self = self, await self.isConnected, !Task.isCancelled {
                do {
                    let data = try await self.receiveMessage()
                    await self.handleReceivedData(data)
                } catch {
                    if await self.isConnected && !Task.isCancelled {
                        AppLogger.logError(error, category: AppLogger.network, context: "WebSocket receive failed")
                        await self.eventContinuation?.yield(.failure(error))
                        // Spawn reconnection in a separate task so that disconnect()
                        // cancelling receiveTask doesn't cancel the reconnection itself.
                        Task { [weak self] in
                            await self?.attemptReconnection()
                        }
                    }
                    break
                }
            }
        }
    }

    private func receiveMessage() async throws -> Data {
        guard let connection = connection else {
            throw WebSocketError.notConnected
        }

        // Loop to skip control frames (pong, etc.) that have no payload
        while true {
            let data: Data? = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data?, Error>) in
                connection.receiveMessage { content, context, isComplete, error in
                    if let error = error {
                        continuation.resume(throwing: WebSocketError.receiveFailed(error))
                        return
                    }

                    // Check for WebSocket close frame
                    if let metadata = context?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata {
                        if metadata.opcode == .close {
                            let closeCode = metadata.closeCode
                            continuation.resume(throwing: WebSocketError.connectionClosed(
                                closeCode: closeCode,
                                reason: "Server closed connection"
                            ))
                            return
                        }

                        // Control frames (pong, etc.) have no payload — return nil to skip
                        if metadata.opcode == .pong {
                            continuation.resume(returning: nil)
                            return
                        }
                    }

                    if let data = content {
                        continuation.resume(returning: data)
                    } else {
                        // Nil content without error or close frame — treat as control frame
                        continuation.resume(returning: nil)
                    }
                }
            }

            // If we got actual data, return it; otherwise it was a control frame —
            // update lastMessageTime (proves connection is alive) and loop.
            if let data = data {
                return data
            }
            lastMessageTime = Date()
        }
    }

    private func handleReceivedData(_ data: Data) {
        lastMessageTime = Date()
        eventContinuation?.yield(.success(data))
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
                    // Spawn in separate task so disconnect() cancelling heartbeatTask
                    // doesn't cancel the reconnection itself.
                    Task { [weak self] in
                        await self?.attemptReconnection()
                    }
                    break
                }

                // Send ping to keep connection alive
                await sendPing()
            }
        }
    }

    private func sendPing() {
        guard let connection = connection else { return }

        let metadata = NWProtocolWebSocket.Metadata(opcode: .ping)
        let context = NWConnection.ContentContext(
            identifier: "ping",
            metadata: [metadata]
        )
        connection.send(content: Data(), contentContext: context, isComplete: true, completion: .contentProcessed { error in
            if let error = error {
                AppLogger.network.error("Heartbeat ping failed: \(error.localizedDescription)")
            }
        })
    }

    private func attemptReconnection() async {
        while reconnectAttempts < maxReconnectAttempts {
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
                return // Success — exit the loop
            } catch {
                AppLogger.logError(error, category: AppLogger.network, context: "Reconnection failed")
                // Loop continues to next attempt
            }
        }

        // All attempts exhausted
        AppLogger.network.error("Max reconnection attempts reached")
        connectionStateContinuation?.yield(.error("Max reconnection attempts reached"))
        eventContinuation?.yield(.failure(WebSocketError.maxReconnectAttemptsReached))
        await disconnect()
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

// MARK: - WebSocket Errors

enum WebSocketError: LocalizedError {
    case notConnected
    case noDirectNetwork
    case invalidURL(String)
    case sendFailed(Error)
    case receiveFailed(Error)
    case maxReconnectAttemptsReached
    case connectionCancelled
    case connectionFailed(Error)
    case connectionClosed(closeCode: NWProtocolWebSocket.CloseCode, reason: String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "WebSocket is not connected"
        case .noDirectNetwork:
            return "Voice requires WiFi or cellular. Connect your Apple Watch to WiFi and try again."
        case .invalidURL(let detail):
            return "Invalid WebSocket URL: \(detail)"
        case .sendFailed(let error):
            return "Failed to send message: \(error.localizedDescription)"
        case .receiveFailed(let error):
            return "Failed to receive message: \(error.localizedDescription)"
        case .maxReconnectAttemptsReached:
            return "Maximum reconnection attempts reached"
        case .connectionCancelled:
            return "Connection was cancelled"
        case .connectionFailed(let error):
            return "Connection failed: \(error.localizedDescription)"
        case .connectionClosed(let closeCode, let reason):
            return "Connection closed: code=\(closeCode), reason=\(reason)"
        }
    }
}
