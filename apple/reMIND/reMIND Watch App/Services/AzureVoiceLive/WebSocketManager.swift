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
    private let maxReconnectAttempts = 5

    // Event stream
    private var eventContinuation: AsyncStream<Result<Data, Error>>.Continuation?
    let eventStream: AsyncStream<Result<Data, Error>>

    // Heartbeat tracking
    private var heartbeatTask: Task<Void, Never>?
    private var lastMessageTime = Date()
    private var receiveTask: Task<Void, Never>?

    // MARK: - Initialization

    init(url: URL, apiKey: String) {
        self.url = url
        self.apiKey = apiKey

        // Create event stream
        var continuationHolder: AsyncStream<Result<Data, Error>>.Continuation?
        self.eventStream = AsyncStream { continuation in
            continuationHolder = continuation
        }
        self.eventContinuation = continuationHolder
    }

    // MARK: - Connection Management

    /// Connect to WebSocket
    func connect() async throws {
        guard !isConnected else {
            AppLogger.network.warning("Already connected to WebSocket")
            return
        }

        AppLogger.network.info("Connecting to WebSocket: \(self.url.absoluteString)")

        // Create URLSession configuration
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300

        session = URLSession(configuration: configuration)

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

        isConnected = true
        reconnectAttempts = 0
        lastMessageTime = Date()

        AppLogger.network.info("WebSocket connected")

        // Start receiving messages and heartbeat
        startReceiving()
        startHeartbeat()
    }

    /// Disconnect from WebSocket
    func disconnect() async {
        guard isConnected else { return }

        AppLogger.network.info("Disconnecting from WebSocket")

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
        eventContinuation?.finish()

        AppLogger.network.info("WebSocket disconnected")
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

    // MARK: - Private Methods

    private func startReceiving() {
        receiveTask?.cancel()

        receiveTask = Task {
            guard let webSocketTask = webSocketTask else { return }

            AppLogger.network.info("Starting to receive WebSocket messages...")

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
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30s

                guard isConnected && !Task.isCancelled else { break }

                let timeSinceLastMessage = Date().timeIntervalSince(lastMessageTime)
                if timeSinceLastMessage > 60 {
                    AppLogger.network.warning("No messages received in 60s, connection may be dead")
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
            eventContinuation?.yield(.failure(WebSocketError.maxReconnectAttemptsReached))
            await disconnect()
            return
        }

        reconnectAttempts += 1
        let delay = min(pow(2.0, Double(reconnectAttempts)), 30.0) // Max 30 seconds
        AppLogger.network.info("Reconnecting in \(delay) seconds (attempt \(self.reconnectAttempts)/\(self.maxReconnectAttempts))")

        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        do {
            await disconnect()
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
        } else if reconnectAttempts > 0 {
            return .connecting
        } else {
            return .disconnected
        }
    }
}

// MARK: - Errors

enum WebSocketError: LocalizedError {
    case notConnected
    case sessionCreationFailed
    case sendFailed(Error)
    case receiveFailed(Error)
    case maxReconnectAttemptsReached

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "WebSocket is not connected"
        case .sessionCreationFailed:
            return "Failed to create URLSession"
        case .sendFailed(let error):
            return "Failed to send message: \(error.localizedDescription)"
        case .receiveFailed(let error):
            return "Failed to receive message: \(error.localizedDescription)"
        case .maxReconnectAttemptsReached:
            return "Maximum reconnection attempts reached"
        }
    }
}
