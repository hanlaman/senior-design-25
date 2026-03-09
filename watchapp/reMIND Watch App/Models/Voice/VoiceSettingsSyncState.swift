//
//  VoiceSettingsSyncState.swift
//  reMIND Watch App
//
//  Tracks synchronization state between local settings and active Azure session
//

import Foundation

/// Represents the synchronization state between local settings and active session
enum VoiceSettingsSyncState: Equatable {
    /// All settings are synchronized with the active session
    case synchronized

    /// Voice settings have changed and require full reconnection
    /// Associated value contains names of changed settings for logging
    case pendingReconnection([String])

    /// Non-voice settings have changed and can be updated via session.update
    /// Associated value contains names of changed settings for logging
    case pendingSessionUpdate([String])

    /// No active session to synchronize with
    case notConnected

    /// Whether this state requires action (reconnection or session update)
    var needsAction: Bool {
        switch self {
        case .synchronized, .notConnected:
            return false
        case .pendingReconnection, .pendingSessionUpdate:
            return true
        }
    }

    /// Debug description for logging
    var debugDescription: String {
        switch self {
        case .synchronized:
            return "synchronized"
        case .pendingReconnection(let fields):
            return "pendingReconnection(\(fields.joined(separator: ", ")))"
        case .pendingSessionUpdate(let fields):
            return "pendingSessionUpdate(\(fields.joined(separator: ", ")))"
        case .notConnected:
            return "notConnected"
        }
    }
}
