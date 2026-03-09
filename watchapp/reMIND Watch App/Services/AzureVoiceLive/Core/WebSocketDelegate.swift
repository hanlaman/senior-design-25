//
//  WebSocketDelegate.swift
//  reMIND Watch App
//
//  Delegate class that bridges URLSessionWebSocketDelegate callbacks to WebSocketManager actor
//

import Foundation
import os

/// Events emitted by the WebSocket delegate to notify the actor
enum WebSocketConnectionEvent: Sendable {
    case didOpen
    case didClose(closeCode: URLSessionWebSocketTask.CloseCode, reason: String)
    case didFail(error: Error)
}

/// Delegate class that bridges URLSessionWebSocketDelegate callbacks to WebSocketManager actor
final class WebSocketDelegate: NSObject, URLSessionWebSocketDelegate, Sendable {
    // MARK: - Properties

    /// Continuation for awaiting connection open
    private let connectionContinuation = OSAllocatedUnfairLock<CheckedContinuation<Void, Error>?>(initialState: nil)

    /// Callback to notify actor of connection state changes
    private let onConnectionStateChange: @Sendable (WebSocketConnectionEvent) -> Void

    // MARK: - Initialization

    init(onConnectionStateChange: @escaping @Sendable (WebSocketConnectionEvent) -> Void) {
        self.onConnectionStateChange = onConnectionStateChange
        super.init()
    }

    // MARK: - Continuation Management

    /// Set a continuation to be resumed when connection opens or fails
    func setConnectionContinuation(_ continuation: CheckedContinuation<Void, Error>) {
        connectionContinuation.withLock { existingContinuation in
            // Cancel any existing continuation
            existingContinuation?.resume(throwing: WebSocketError.connectionCancelled)
            existingContinuation = continuation
        }
    }

    /// Clear the continuation (called when connection is manually closed)
    func clearConnectionContinuation() {
        connectionContinuation.withLock { continuation in
            continuation = nil
        }
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        AppLogger.network.info("WebSocket handshake completed (protocol: \(`protocol` ?? "none"))")

        // Resume continuation - connection is now established
        connectionContinuation.withLock { continuation in
            continuation?.resume()
            continuation = nil
        }

        // Notify actor of state change
        onConnectionStateChange(.didOpen)
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "none"
        AppLogger.network.info("WebSocket closed: code=\(closeCode.rawValue), reason=\(reasonString)")

        // Resume continuation with error if still waiting
        connectionContinuation.withLock { continuation in
            let error = WebSocketError.connectionClosed(closeCode: closeCode, reason: reasonString)
            continuation?.resume(throwing: error)
            continuation = nil
        }

        // Notify actor of state change
        onConnectionStateChange(.didClose(closeCode: closeCode, reason: reasonString))
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error = error else { return }

        AppLogger.network.error("WebSocket task failed: \(error.localizedDescription)")

        // Resume continuation with error if still waiting
        connectionContinuation.withLock { continuation in
            continuation?.resume(throwing: WebSocketError.connectionFailed(error))
            continuation = nil
        }

        // Notify actor of state change
        onConnectionStateChange(.didFail(error: error))
    }
}

// MARK: - WebSocket Errors

enum WebSocketError: LocalizedError {
    case notConnected
    case sessionCreationFailed
    case sendFailed(Error)
    case receiveFailed(Error)
    case maxReconnectAttemptsReached
    case connectionCancelled
    case connectionFailed(Error)
    case connectionClosed(closeCode: URLSessionWebSocketTask.CloseCode, reason: String)

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
        case .connectionCancelled:
            return "Connection was cancelled"
        case .connectionFailed(let error):
            return "Connection failed: \(error.localizedDescription)"
        case .connectionClosed(let closeCode, let reason):
            return "Connection closed: code=\(closeCode.rawValue), reason=\(reason)"
        }
    }
}
