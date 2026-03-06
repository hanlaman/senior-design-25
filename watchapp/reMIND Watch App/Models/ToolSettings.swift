//
//  ToolSettings.swift
//  reMIND Watch App
//
//  Settings model for tool state persistence
//

import Foundation

/// Settings structure for tracking tool enabled/disabled state
public struct ToolSettings: Codable, Sendable {
    /// Map of tool ID to enabled state
    public var enabledTools: [String: Bool]

    /// Last sync timestamp for tracking
    public var lastSyncDate: Date?

    /// Default settings with get_current_time enabled
    public static let defaultSettings = ToolSettings(
        enabledTools: [
            "get_current_time": true
        ],
        lastSyncDate: nil
    )

    public init(
        enabledTools: [String: Bool],
        lastSyncDate: Date? = nil
    ) {
        self.enabledTools = enabledTools
        self.lastSyncDate = lastSyncDate
    }
}
