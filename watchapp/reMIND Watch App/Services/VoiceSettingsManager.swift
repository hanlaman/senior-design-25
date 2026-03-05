//
//  VoiceSettingsManager.swift
//  reMIND Watch App
//
//  Manages voice settings persistence and synchronization
//

import Foundation
import Combine
import os

/// Manages voice settings persistence and synchronization
class VoiceSettingsManager: ObservableObject {
    // MARK: - Singleton

    static let shared = VoiceSettingsManager()

    // MARK: - Properties

    private let userDefaults = UserDefaults.standard
    private let settingsKey = "voiceSettings"

    /// Current voice settings
    @Published private(set) var settings: VoiceSettings

    /// Current synchronization state between local settings and active session
    @Published private(set) var syncState: VoiceSettingsSyncState = .notConnected

    /// Settings that are currently active on the server (nil if not connected)
    private var activeSessionSettings: VoiceSettings?

    // MARK: - Initialization

    private init() {
        // Load from storage or use defaults
        if let data = userDefaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(VoiceSettings.self, from: data) {
            var loadedSettings = decoded

            // Validate and clamp speaking rate
            if !loadedSettings.isValidSpeakingRate {
                AppLogger.general.warning("Invalid speaking rate \(loadedSettings.speakingRate), clamping to valid range")
                loadedSettings.clampSpeakingRate()
            }

            self.settings = loadedSettings
            AppLogger.general.info("Loaded voice settings from storage: rate=\(loadedSettings.speakingRate)x")
        } else {
            self.settings = VoiceSettings.defaultSettings
            AppLogger.general.info("Using default voice settings: rate=\(VoiceSettings.defaultSettings.speakingRate)x")
        }
    }

    // MARK: - Public Methods

    /// Update speaking rate (primary user-adjustable setting)
    func updateSpeakingRate(_ rate: Double) {
        var newSettings = settings
        newSettings.speakingRate = rate

        // Validate and clamp
        if !newSettings.isValidSpeakingRate {
            AppLogger.general.warning("Invalid speaking rate \(rate), clamping to valid range")
            newSettings.clampSpeakingRate()
        }

        save(newSettings)
    }

    // MARK: - Private Methods

    /// Save settings to persistent storage
    private func save(_ newSettings: VoiceSettings) {
        settings = newSettings

        do {
            let encoded = try JSONEncoder().encode(newSettings)
            userDefaults.set(encoded, forKey: settingsKey)
            AppLogger.general.info("Saved voice settings: rate=\(newSettings.speakingRate)x")

            // Recompute sync state after settings change
            let newState = computeSyncState()
            if syncState != newState {
                syncState = newState
                AppLogger.general.info("Settings sync state changed to: \(newState.debugDescription)")
            }
        } catch {
            AppLogger.logError(error, category: AppLogger.general, context: "Failed to encode voice settings")
        }
    }

    // MARK: - Session Synchronization

    /// Compute current sync state by comparing local settings with active session settings
    /// - Returns: Current sync state
    func computeSyncState() -> VoiceSettingsSyncState {
        guard let active = activeSessionSettings else {
            return .notConnected
        }

        // Find changed fields that require reconnection
        let reconnectionChanges = settings.changedFields(
            comparedTo: active,
            strategy: .requiresReconnection
        )

        // Find changed fields that can be updated via session.update
        let sessionUpdateChanges = settings.changedFields(
            comparedTo: active,
            strategy: .sessionUpdate
        )

        // Prioritize reconnection changes over session updates
        if !reconnectionChanges.isEmpty {
            let fieldNames = reconnectionChanges.map { $0.name }
            return .pendingReconnection(fieldNames)
        } else if !sessionUpdateChanges.isEmpty {
            let fieldNames = sessionUpdateChanges.map { $0.name }
            return .pendingSessionUpdate(fieldNames)
        }

        return .synchronized
    }

    /// Mark settings as synchronized with the active session
    /// Call this after successfully connecting or updating the session
    /// - Parameter settings: Settings that are now active on the server
    func markAsSynchronized(_ settings: VoiceSettings) {
        self.activeSessionSettings = settings
        let newState = computeSyncState()
        if syncState != newState {
            syncState = newState
            AppLogger.general.info("Settings sync state: \(newState.debugDescription)")
        }
    }

    /// Clear active session settings (call on disconnect)
    func clearActiveSession() {
        activeSessionSettings = nil
        syncState = .notConnected
        AppLogger.general.info("Settings sync state: notConnected")
    }

    /// Get list of changed fields compared to active session
    /// - Returns: Array of metadata for changed fields, or empty if no active session
    func changedFields() -> [SettingMetadata] {
        guard let active = activeSessionSettings else {
            return []
        }
        return settings.changedFields(comparedTo: active)
    }

    // MARK: - Remote Sync (Stub for Future Implementation)

    /// Sync settings with remote API
    /// - Note: Stub implementation. To be implemented when remote API is ready.
    func syncWithRemote() async throws {
        AppLogger.general.info("Remote sync requested (not yet implemented)")

        // TODO: Implement remote sync when API is ready
        // Steps to implement:
        // 1. Fetch remote settings from API
        // 2. Compare remoteVersion with local version
        // 3. Merge or overwrite based on strategy (e.g., remote wins if newer)
        // 4. Update lastSyncDate
        // 5. Save updated settings locally
        //
        // Example:
        // let remoteSettings = try await fetchRemoteSettings()
        // if shouldUpdateFromRemote(remoteSettings) {
        //     var updated = remoteSettings
        //     updated.lastSyncDate = Date()
        //     save(updated)
        // }
    }
}
