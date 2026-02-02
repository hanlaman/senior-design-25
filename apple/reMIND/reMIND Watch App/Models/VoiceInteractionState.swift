//
//  VoiceInteractionState.swift
//  reMIND Watch App
//
//  Unified state machine for voice interaction
//  Replaces scattered state across VoiceState, ConnectionState, and boolean flags
//

import Foundation

/// Unified state machine representing the entire voice interaction system
enum VoiceInteractionState: Equatable {
    // MARK: - Connection Lifecycle

    /// Disconnected from Azure - no session active
    case disconnected

    /// Connecting to Azure WebSocket
    case connecting

    /// Connection failed with error message
    case connectionFailed(String)

    // MARK: - Ready State

    /// Connected and ready to start recording
    case idle(sessionId: String)

    // MARK: - Interaction States

    /// Recording audio from microphone
    case recording(sessionId: String, bufferBytes: Int)

    /// Processing recorded audio (committed to Azure, waiting for response)
    case processing(sessionId: String)

    /// Playing response audio from Azure
    case playing(sessionId: String, activeBuffers: Int)

    // MARK: - Error State

    /// Error occurred with message
    case error(sessionId: String?, message: String)

    // MARK: - Computed Properties

    /// Session ID if connected
    var sessionId: String? {
        switch self {
        case .idle(let id),
             .recording(let id, _),
             .processing(let id),
             .playing(let id, _):
            return id
        case .error(let id, _):
            return id
        case .disconnected, .connecting, .connectionFailed:
            return nil
        }
    }

    /// Can start recording in current state
    var canStartRecording: Bool {
        if case .idle = self {
            return true
        }
        return false
    }

    /// Currently recording audio
    var isRecording: Bool {
        if case .recording = self {
            return true
        }
        return false
    }

    /// Currently processing recorded audio
    var isProcessing: Bool {
        if case .processing = self {
            return true
        }
        return false
    }

    /// Currently playing response audio
    var isPlaying: Bool {
        if case .playing = self {
            return true
        }
        return false
    }

    /// Connected to Azure (has session)
    var isConnected: Bool {
        switch self {
        case .idle, .recording, .processing, .playing:
            return true
        case .disconnected, .connecting, .connectionFailed, .error:
            return false
        }
    }

    /// Any active interaction (recording, processing, or playing)
    var isActive: Bool {
        switch self {
        case .recording, .processing, .playing:
            return true
        default:
            return false
        }
    }

    /// Can cancel current interaction
    var canCancel: Bool {
        return isActive
    }

    /// Display text for UI
    var displayText: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connectionFailed(let message):
            return "Failed: \(message)"
        case .idle:
            return "Ready"
        case .recording(_, let bytes):
            if bytes > 0 {
                return "Listening... (\(formatBytes(bytes)))"
            } else {
                return "Listening..."
            }
        case .processing:
            return "Processing..."
        case .playing(_, let buffers):
            if buffers > 0 {
                return "Playing... (\(buffers) chunks)"
            } else {
                return "Playing..."
            }
        case .error(_, let message):
            return "Error: \(message)"
        }
    }

    /// Error message if in error state
    var errorMessage: String? {
        switch self {
        case .connectionFailed(let message), .error(_, let message):
            return message
        default:
            return nil
        }
    }

    // MARK: - Helper Methods

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes)B"
        } else if bytes < 1024 * 1024 {
            return "\(bytes / 1024)KB"
        } else {
            return "\(bytes / (1024 * 1024))MB"
        }
    }
}

// MARK: - CustomStringConvertible

extension VoiceInteractionState: CustomStringConvertible {
    var description: String {
        switch self {
        case .disconnected:
            return "disconnected"
        case .connecting:
            return "connecting"
        case .connectionFailed(let message):
            return "connectionFailed(\(message))"
        case .idle(let sessionId):
            return "idle(session: \(sessionId.prefix(8))...)"
        case .recording(let sessionId, let bytes):
            return "recording(session: \(sessionId.prefix(8))..., \(bytes) bytes)"
        case .processing(let sessionId):
            return "processing(session: \(sessionId.prefix(8))...)"
        case .playing(let sessionId, let buffers):
            return "playing(session: \(sessionId.prefix(8))..., \(buffers) buffers)"
        case .error(let sessionId, let message):
            if let id = sessionId {
                return "error(session: \(id.prefix(8))..., \(message))"
            } else {
                return "error(\(message))"
            }
        }
    }
}
