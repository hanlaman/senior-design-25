//
//  SessionConfiguration.swift
//  reMIND Watch App
//
//  Configuration constants for Azure session management
//

import Foundation

/// Configuration constants for Azure session management
enum SessionConfiguration {
    /// Timeout waiting for session to be established (seconds)
    static var establishmentTimeout: TimeInterval { DebugSettings.shared.timeoutsDisabled ? .infinity : 10.0 }

    /// Small delay for session state polling (seconds)
    static let statePollingDelay: TimeInterval = 0.1
}
