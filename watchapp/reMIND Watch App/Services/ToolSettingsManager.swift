//
//  ToolSettingsManager.swift
//  reMIND Watch App
//
//  Manages persistence of tool settings via UserDefaults
//

import Foundation
import Combine
import os

/// Singleton manager for tool settings persistence
@MainActor
public class ToolSettingsManager: ObservableObject {
    /// Shared singleton instance
    public static let shared = ToolSettingsManager()

    /// Published settings that views can observe
    @Published public private(set) var settings: ToolSettings

    private let userDefaults = UserDefaults.standard
    private let settingsKey = "toolSettings"

    private init() {
        // Load from UserDefaults or use defaults
        if let data = userDefaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(ToolSettings.self, from: data) {
            self.settings = decoded
            AppLogger.general.info("Loaded tool settings from UserDefaults")
        } else {
            self.settings = ToolSettings.defaultSettings
            AppLogger.general.info("Initialized with default tool settings")
        }
    }

    /// Update the enabled state for a specific tool
    /// - Parameters:
    ///   - toolId: Unique identifier for the tool
    ///   - enabled: Whether the tool should be enabled
    public func setToolEnabled(_ toolId: String, _ enabled: Bool) {
        settings.enabledTools[toolId] = enabled
        settings.lastSyncDate = Date()
        save()
        AppLogger.general.info("Tool '\(toolId)' enabled state set to: \(enabled)")
    }

    /// Check if a specific tool is enabled
    /// - Parameter toolId: Unique identifier for the tool
    /// - Returns: True if the tool is enabled, false otherwise
    public func isToolEnabled(_ toolId: String) -> Bool {
        return settings.enabledTools[toolId] ?? false
    }

    /// Save current settings to UserDefaults
    private func save() {
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: settingsKey)
            AppLogger.general.debug("Tool settings saved to UserDefaults")
        } else {
            AppLogger.logError(
                NSError(domain: "ToolSettingsManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode settings"]),
                category: AppLogger.general,
                context: "Failed to save tool settings"
            )
        }
    }
}
