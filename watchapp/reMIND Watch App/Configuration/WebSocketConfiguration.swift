//
//  WebSocketConfiguration.swift
//  reMIND Watch App
//
//  Configuration constants for WebSocket connection management
//

import Foundation

/// Configuration constants for WebSocket connection management
enum WebSocketConfiguration {
    /// Whether debug timeouts-disabled mode is active
    private static var timeoutsDisabled: Bool { DebugSettings.shared.timeoutsDisabled }

    /// Maximum number of reconnection attempts before giving up
    static let maxReconnectAttempts = 5

    /// Timeout for initial connection request (seconds)
    static var connectionTimeout: TimeInterval { timeoutsDisabled ? .infinity : 30 }

    /// Timeout for resource (total connection lifetime, seconds)
    /// Set high for long-lived WebSocket connections
    static var resourceTimeout: TimeInterval { timeoutsDisabled ? .infinity : 600 }

    /// Interval between heartbeat pings (seconds)
    static let heartbeatInterval: TimeInterval = 30

    /// Maximum silence duration before considering connection dead (seconds)
    static var silenceThreshold: TimeInterval { timeoutsDisabled ? .infinity : 60 }

    /// Maximum delay between reconnection attempts (seconds)
    /// Used with exponential backoff: min(2^attempt, maxReconnectDelay)
    static let maxReconnectDelay: TimeInterval = 30
}
