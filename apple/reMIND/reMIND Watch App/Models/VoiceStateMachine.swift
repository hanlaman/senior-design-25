//
//  VoiceStateMachine.swift
//  reMIND Watch App
//
//  State machine coordinator that validates and manages state transitions
//

import Foundation
import SwiftUI
import Combine
import os

/// State machine that validates and coordinates voice interaction state transitions
@MainActor
final class VoiceStateMachine: ObservableObject {
    // MARK: - Published State

    @Published private(set) var state: VoiceInteractionState = .disconnected

    // MARK: - State Transition Methods

    /// Transition to a new state with validation
    func transitionTo(_ newState: VoiceInteractionState) {
        guard isValidTransition(from: state, to: newState) else {
            AppLogger.general.error("Invalid state transition: \(self.state) -> \(newState)")
            return
        }

        AppLogger.general.info("State transition: \(self.state) -> \(newState)")
        state = newState
    }

    /// Force transition without validation (use with caution)
    func forceTransition(_ newState: VoiceInteractionState) {
        AppLogger.general.warning("Forced state transition: \(self.state) -> \(newState)")
        state = newState
    }

    // MARK: - Transition Validation

    private func isValidTransition(
        from current: VoiceInteractionState,
        to next: VoiceInteractionState
    ) -> Bool {
        switch (current, next) {
        // MARK: From Disconnected

        case (.disconnected, .connecting):
            return true

        // MARK: From Connecting

        case (.connecting, .idle):
            return true
        case (.connecting, .connectionFailed):
            return true
        case (.connecting, .disconnected):
            // User cancelled connection
            return true
        case (.connecting, .error):
            return true

        // MARK: From Connection Failed

        case (.connectionFailed, .connecting):
            // Retry connection
            return true
        case (.connectionFailed, .disconnected):
            // Give up, go back to disconnected
            return true

        // MARK: From Idle

        case (.idle, .recording):
            return true
        case (.idle, .disconnected):
            // User disconnected
            return true
        case (.idle, .error):
            return true

        // MARK: From Recording

        case (.recording, .recording):
            // Allow same-state transitions (buffer size updates)
            return true
        case (.recording, .processing):
            // Stopped recording, committed buffer
            return true
        case (.recording, .idle):
            // Cancelled recording
            return true
        case (.recording, .error):
            return true

        // MARK: From Processing

        case (.processing, .playing):
            // Response audio arrived
            return true
        case (.processing, .idle):
            // Cancelled or buffer too small
            return true
        case (.processing, .error):
            return true

        // MARK: From Playing

        case (.playing, .playing):
            // Allow same-state transitions (buffer count updates)
            return true
        case (.playing, .idle):
            // Playback complete or cancelled
            return true
        case (.playing, .error):
            return true

        // MARK: From Error

        case (.error, .idle):
            // Recovered from error, back to idle
            return true
        case (.error, .disconnected):
            // Fatal error, disconnect
            return true
        case (.error, .connecting):
            // Retry after error
            return true

        // MARK: Invalid Transitions

        default:
            return false
        }
    }
}

// MARK: - State Queries

extension VoiceStateMachine {
    /// Current session ID
    var sessionId: String? {
        state.sessionId
    }

    /// Can start recording
    var canStartRecording: Bool {
        state.canStartRecording
    }

    /// Currently recording
    var isRecording: Bool {
        state.isRecording
    }

    /// Currently processing
    var isProcessing: Bool {
        state.isProcessing
    }

    /// Currently playing
    var isPlaying: Bool {
        state.isPlaying
    }

    /// Connected to Azure
    var isConnected: Bool {
        state.isConnected
    }

    /// Any active interaction
    var isActive: Bool {
        state.isActive
    }

    /// Can cancel current interaction
    var canCancel: Bool {
        state.canCancel
    }

    /// Display text
    var displayText: String {
        state.displayText
    }

    /// Error message if any
    var errorMessage: String? {
        state.errorMessage
    }
}
