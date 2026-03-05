//
//  VoiceSettingsUpdateStrategy.swift
//  reMIND Watch App
//
//  Defines how different settings should be synchronized with the server
//

import Foundation

/// Defines the synchronization strategy for a voice setting
enum SettingUpdateStrategy {
    /// Setting requires full reconnection to Azure (voice configuration changes)
    /// Example: speakingRate, voiceName, voiceTemperature
    /// These settings are immutable once session is initialized per Azure API
    case requiresReconnection

    /// Setting can be updated mid-session via session.update event
    /// Example: instructions, sessionTemperature, VAD settings
    /// These settings can be changed without reconnecting
    case sessionUpdate

    /// Setting is local-only and not sent to server
    /// Example: UI preferences, display options (future)
    /// These settings don't affect the Azure session
    case localOnly
}
