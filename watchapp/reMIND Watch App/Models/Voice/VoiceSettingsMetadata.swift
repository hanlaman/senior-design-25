//
//  VoiceSettingsMetadata.swift
//  reMIND Watch App
//
//  Metadata system for voice settings categorization and comparison
//

import Foundation

// Note: VoiceSettings is defined in VoiceSettings.swift
// Note: SettingUpdateStrategy is defined in VoiceSettingsUpdateStrategy.swift

/// Metadata describing a single voice setting field
struct SettingMetadata {
    /// Internal field name
    let name: String

    /// Human-readable display name
    let displayName: String

    /// How this setting should be synchronized
    let updateStrategy: SettingUpdateStrategy

    /// Key path to the setting value in VoiceSettings
    let keyPath: PartialKeyPath<VoiceSettings>
}

// MARK: - VoiceSettings Extension

extension VoiceSettings {
    /// Metadata for all voice settings fields
    /// This declaratively defines how each setting should be synchronized
    static let metadata: [SettingMetadata] = [
        // Voice settings (require reconnection per Azure API)
        SettingMetadata(
            name: "voiceName",
            displayName: "Voice",
            updateStrategy: .requiresReconnection,
            keyPath: \VoiceSettings.voiceName
        ),
        SettingMetadata(
            name: "speakingRate",
            displayName: "Speaking Rate",
            updateStrategy: .requiresReconnection,
            keyPath: \VoiceSettings.speakingRate
        ),
        SettingMetadata(
            name: "voiceTemperature",
            displayName: "Voice Temperature",
            updateStrategy: .requiresReconnection,
            keyPath: \VoiceSettings.voiceTemperature
        ),

        // Session settings (can update via session.update)
        SettingMetadata(
            name: "instructions",
            displayName: "Instructions",
            updateStrategy: .sessionUpdate,
            keyPath: \VoiceSettings.instructions
        ),
        SettingMetadata(
            name: "sessionTemperature",
            displayName: "Session Temperature",
            updateStrategy: .sessionUpdate,
            keyPath: \VoiceSettings.sessionTemperature
        ),
        SettingMetadata(
            name: "vadThreshold",
            displayName: "VAD Threshold",
            updateStrategy: .sessionUpdate,
            keyPath: \VoiceSettings.vadThreshold
        ),
        SettingMetadata(
            name: "vadPrefixPaddingMs",
            displayName: "VAD Prefix Padding",
            updateStrategy: .sessionUpdate,
            keyPath: \VoiceSettings.vadPrefixPaddingMs
        ),
        SettingMetadata(
            name: "vadSilenceDurationMs",
            displayName: "VAD Silence Duration",
            updateStrategy: .sessionUpdate,
            keyPath: \VoiceSettings.vadSilenceDurationMs
        ),

        // Local-only settings (not sent to server)
        SettingMetadata(
            name: "lastSyncDate",
            displayName: "Last Sync Date",
            updateStrategy: .localOnly,
            keyPath: \VoiceSettings.lastSyncDate
        ),
        SettingMetadata(
            name: "remoteVersion",
            displayName: "Remote Version",
            updateStrategy: .localOnly,
            keyPath: \VoiceSettings.remoteVersion
        ),
    ]

    /// Find changed fields compared to another settings instance
    /// - Parameter other: Settings to compare against
    /// - Returns: Array of metadata for fields that differ
    func changedFields(comparedTo other: VoiceSettings) -> [SettingMetadata] {
        Self.metadata.filter { meta in
            !areEqual(keyPath: meta.keyPath, other: other)
        }
    }

    /// Find changed fields by update strategy
    /// - Parameters:
    ///   - other: Settings to compare against
    ///   - strategy: Only return fields with this strategy
    /// - Returns: Array of metadata for fields that differ and match the strategy
    func changedFields(comparedTo other: VoiceSettings, strategy: SettingUpdateStrategy) -> [SettingMetadata] {
        changedFields(comparedTo: other).filter { $0.updateStrategy == strategy }
    }

    /// Check if a specific field is equal between two settings instances
    /// - Parameters:
    ///   - keyPath: Key path to the field to compare
    ///   - other: Other settings instance to compare with
    /// - Returns: True if the values are equal
    private func areEqual(keyPath: PartialKeyPath<VoiceSettings>, other: VoiceSettings) -> Bool {
        // Compare values using key paths
        // We need to handle different types for each field
        switch keyPath {
        case \VoiceSettings.voiceName:
            return self.voiceName == other.voiceName
        case \VoiceSettings.speakingRate:
            return self.speakingRate == other.speakingRate
        case \VoiceSettings.voiceTemperature:
            return self.voiceTemperature == other.voiceTemperature
        case \VoiceSettings.instructions:
            return self.instructions == other.instructions
        case \VoiceSettings.sessionTemperature:
            return self.sessionTemperature == other.sessionTemperature
        case \VoiceSettings.vadThreshold:
            return self.vadThreshold == other.vadThreshold
        case \VoiceSettings.vadPrefixPaddingMs:
            return self.vadPrefixPaddingMs == other.vadPrefixPaddingMs
        case \VoiceSettings.vadSilenceDurationMs:
            return self.vadSilenceDurationMs == other.vadSilenceDurationMs
        case \VoiceSettings.lastSyncDate:
            return self.lastSyncDate == other.lastSyncDate
        case \VoiceSettings.remoteVersion:
            return self.remoteVersion == other.remoteVersion
        default:
            // Unknown key path - assume not equal for safety
            return false
        }
    }
}
