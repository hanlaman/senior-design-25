//
//  VoiceState.swift
//  reMIND Watch App
//
//  App state management
//

import Foundation

/// Application state for voice interaction
enum VoiceState: Equatable, CustomStringConvertible {
    /// Idle state - ready to start recording
    case idle

    /// Recording audio from microphone
    case recording

    /// Processing audio (sending to Azure, waiting for response)
    case processing

    /// Playing response audio
    case playing

    /// Error state with message
    case error(String)

    /// Disconnected from Azure
    case disconnected

    /// Connecting to Azure
    case connecting

    // MARK: - Helper Properties

    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }

    var isProcessing: Bool {
        if case .processing = self { return true }
        return false
    }

    var isPlaying: Bool {
        if case .playing = self { return true }
        return false
    }

    var isActive: Bool {
        switch self {
        case .recording, .processing, .playing:
            return true
        default:
            return false
        }
    }

    var canStartRecording: Bool {
        switch self {
        case .idle:
            return true
        default:
            return false
        }
    }

    var displayText: String {
        switch self {
        case .idle:
            return "Ready"
        case .recording:
            return "Listening..."
        case .processing:
            return "Processing..."
        case .playing:
            return "Playing..."
        case .error(let message):
            return "Error: \(message)"
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        }
    }

    var description: String {
        displayText
    }
}
