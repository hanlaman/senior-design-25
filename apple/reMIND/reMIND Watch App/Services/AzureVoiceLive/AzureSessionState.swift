//
//  AzureSessionState.swift
//  reMIND Watch App
//
//  Azure session lifecycle state machine
//

import Foundation

/// Azure Voice Live session state machine
public enum AzureSessionState: Sendable, Equatable {
    /// No session exists - WebSocket not connected
    case uninitialized

    /// WebSocket connected, waiting for session.created event
    case establishing(sessionId: String?)

    /// Session created and configured, ready for audio/conversation operations
    case ready(sessionId: String)

    /// Session encountered an error
    case error(String)

    /// Session is being torn down
    case terminating

    // MARK: - Helper Properties

    /// Whether the session can accept audio operations
    public var canAcceptAudio: Bool {
        if case .ready = self { return true }
        return false
    }

    /// Whether the session can accept conversation operations
    public var canAcceptConversation: Bool {
        if case .ready = self { return true }
        return false
    }

    /// Whether the session exists (has a sessionId)
    public var isEstablished: Bool {
        switch self {
        case .establishing(let id):
            return id != nil
        case .ready:
            return true
        default:
            return false
        }
    }

    /// Current session ID if available
    public var sessionId: String? {
        switch self {
        case .establishing(let id):
            return id
        case .ready(let id):
            return id
        default:
            return nil
        }
    }

    /// Display text for debugging
    public var displayText: String {
        switch self {
        case .uninitialized:
            return "Uninitialized"
        case .establishing(let id):
            return "Establishing (id: \(id ?? "pending"))"
        case .ready(let id):
            return "Ready (id: \(id))"
        case .error(let message):
            return "Error: \(message)"
        case .terminating:
            return "Terminating"
        }
    }
}
