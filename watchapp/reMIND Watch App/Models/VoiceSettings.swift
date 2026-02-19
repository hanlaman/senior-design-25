//
//  VoiceSettings.swift
//  reMIND Watch App
//
//  Voice assistant configuration settings
//

import Foundation

/// Voice assistant configuration settings
public struct VoiceSettings: Codable, Sendable {
    // MARK: - Voice Configuration

    /// Azure voice name (fixed to one voice)
    public let voiceName: String

    /// Speaking rate multiplier (0.5x - 1.5x) - Only user-adjustable field
    public var speakingRate: Double

    /// Voice temperature for response variability (0-2)
    public let voiceTemperature: Double

    // MARK: - Instructions

    /// System instructions for the voice assistant
    public let instructions: String

    // MARK: - Turn Detection (VAD)

    /// Voice activity detection threshold (0-1)
    public let vadThreshold: Double

    /// Prefix padding in milliseconds
    public let vadPrefixPaddingMs: Int

    /// Silence duration in milliseconds
    public let vadSilenceDurationMs: Int

    // MARK: - Session Configuration

    /// Session temperature for response generation (0-2)
    public let sessionTemperature: Double

    // MARK: - Remote Sync Tracking

    /// Last successful sync with remote API (prepared for future)
    public var lastSyncDate: Date?

    /// Remote configuration version number (prepared for future)
    public var remoteVersion: Int?

    // MARK: - Default Configuration

    /// Default settings with reasonable values optimized for elderly users
    public static let defaultSettings = VoiceSettings(
        voiceName: "en-US-AvaMultilingualNeural",
        speakingRate: 1.0,
        voiceTemperature: 0.8,
        instructions: "You are a helpful voice assistant for elderly users. Speak clearly, warmly, and patiently. Keep responses concise and easy to understand.",
        vadThreshold: 0.5,
        vadPrefixPaddingMs: 300,
        vadSilenceDurationMs: 500,
        sessionTemperature: 0.8,
        lastSyncDate: nil,
        remoteVersion: nil
    )

    // MARK: - Validation

    /// Validate speaking rate is within acceptable range (Azure API: 0.5-1.5)
    public var isValidSpeakingRate: Bool {
        speakingRate >= 0.5 && speakingRate <= 1.5
    }

    /// Clamp speaking rate to valid range (Azure API: 0.5-1.5)
    public mutating func clampSpeakingRate() {
        speakingRate = min(max(speakingRate, 0.5), 1.5)
    }
}
