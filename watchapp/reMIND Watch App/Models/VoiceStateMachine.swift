//
//  VoiceStateMachine.swift
//  reMIND Watch App
//
//  State machine coordinator that validates and manages state transitions
//
//  ## State Diagram
//
//  ```
//                              ┌─────────────┐
//                              │ disconnected│
//                              └──────┬──────┘
//                                     │ connect()
//                                     ▼
//                              ┌─────────────┐
//                   ┌──────────│  connecting │──────────┐
//                   │          └──────┬──────┘          │
//                   │ fail            │ success         │ error
//                   ▼                 ▼                 ▼
//          ┌────────────────┐  ┌─────────────┐   ┌───────────┐
//          │connectionFailed│  │    idle     │◄──│   error   │
//          └────────┬───────┘  └──────┬──────┘   └───────────┘
//                   │ retry           │ tap (start recording)
//                   └─────────────────┤
//                                     ▼
//                              ┌─────────────┐
//                              │  recording  │◄───┐ (buffer updates)
//                              └──────┬──────┘────┘
//                                     │ release (commit)
//                                     ▼
//                              ┌─────────────┐
//                              │ processing  │
//                              └──────┬──────┘
//                                     │ audio received
//                                     ▼
//                              ┌─────────────┐
//                              │   playing   │◄───┐ (buffer updates)
//                              └──────┬──────┘────┘
//                                     │ playback complete
//                                     └──────► back to idle
//
//  ### Reconnecting (can occur from idle, recording, processing, playing)
//
//                    ┌──────────────┐
//          ──────────│ reconnecting │◄───┐ (attempt updates)
//          WebSocket └──────┬───────┘────┘
//          disconnect       │
//                           │ success → idle
//                           │ fail → connectionFailed
//  ```
//
//  ## State Descriptions
//
//  - **disconnected**: Initial state, no connection to Azure
//  - **connecting**: Establishing WebSocket connection and session
//  - **connectionFailed**: Connection attempt failed, can retry
//  - **idle**: Connected and ready to record
//  - **recording**: Capturing audio from microphone
//  - **processing**: Audio committed, waiting for response
//  - **playing**: Playing back response audio
//  - **reconnecting**: WebSocket lost, attempting to reconnect
//  - **error**: Recoverable error occurred
//
//  ## Cancellation
//
//  User can cancel from: recording, processing, playing → returns to idle
//

import Foundation
import SwiftUI
import Combine
import os

/// State machine that validates and coordinates voice interaction state transitions
///
/// This class serves as the single source of truth for voice interaction state.
/// All state transitions must go through this class, which validates them
/// against the allowed transitions defined in `isValidTransition()`.
///
/// - Note: Use `transitionTo()` for normal transitions with validation.
///         Use `forceTransition()` only when you need to bypass validation.
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

    /// Validates whether a state transition is allowed.
    ///
    /// Valid transitions follow these rules:
    /// - From disconnected: can only connect
    /// - From connecting: can succeed (idle), fail, or be cancelled
    /// - From idle: can start recording or disconnect
    /// - From recording: can commit (processing), cancel (idle), or handle errors
    /// - From processing: can receive audio (playing), cancel, or handle errors
    /// - From playing: can complete (idle), cancel, or handle errors
    /// - From any active state: can transition to reconnecting on WebSocket loss
    /// - From error: can recover to idle, disconnect, or retry connection
    ///
    /// See the state diagram in the file header for visual representation.
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

        // MARK: To Reconnecting

        case (.idle, .reconnecting):
            // WebSocket disconnected while idle
            return true
        case (.recording, .reconnecting):
            // WebSocket disconnected while recording
            return true
        case (.processing, .reconnecting):
            // WebSocket disconnected while processing
            return true
        case (.playing, .reconnecting):
            // WebSocket disconnected while playing
            return true

        // MARK: From Reconnecting

        case (.reconnecting, .reconnecting):
            // Update attempt count
            return true
        case (.reconnecting, .idle):
            // Reconnection succeeded
            return true
        case (.reconnecting, .connectionFailed):
            // Reconnection ultimately failed
            return true
        case (.reconnecting, .disconnected):
            // User cancelled during reconnection
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
