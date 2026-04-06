//
//  LocationConfiguration.swift
//  reMIND Watch App
//
//  Configuration constants for location service
//

import Foundation

/// Configuration constants for location service
enum LocationConfiguration {
    /// Timeout for location update API requests (seconds)
    static var requestTimeout: TimeInterval { DebugSettings.shared.timeoutsDisabled ? .infinity : 10 }

    /// Interval between periodic location sends to the server (seconds)
    static let updateInterval: TimeInterval = 30

    /// Minimum distance change to trigger a location update (meters)
    static let distanceFilter: Double = 100
}
