//
//  NetworkConfiguration.swift
//  reMIND Watch App
//
//  Centralized configuration constants for network and timing parameters
//

import Foundation

// MARK: - WebSocket Configuration

/// Configuration constants for WebSocket connection management
enum WebSocketConfiguration {
    /// Maximum number of reconnection attempts before giving up
    static let maxReconnectAttempts = 5

    /// Timeout for initial connection request (seconds)
    static let connectionTimeout: TimeInterval = 30

    /// Timeout for resource (total connection lifetime, seconds)
    /// Set high for long-lived WebSocket connections
    static let resourceTimeout: TimeInterval = 600  // 10 minutes

    /// Interval between heartbeat pings (seconds)
    static let heartbeatInterval: TimeInterval = 30

    /// Maximum silence duration before considering connection dead (seconds)
    static let silenceThreshold: TimeInterval = 60

    /// Maximum delay between reconnection attempts (seconds)
    /// Used with exponential backoff: min(2^attempt, maxReconnectDelay)
    static let maxReconnectDelay: TimeInterval = 30
}

// MARK: - Session Configuration

/// Configuration constants for Azure session management
enum SessionConfiguration {
    /// Timeout waiting for session to be established (seconds)
    static let establishmentTimeout: TimeInterval = 10.0

    /// Small delay for session state polling (seconds)
    static let statePollingDelay: TimeInterval = 0.1
}

// MARK: - Location Configuration

/// Configuration constants for location service
enum LocationConfiguration {
    /// Timeout for location update API requests (seconds)
    static let requestTimeout: TimeInterval = 10
}
