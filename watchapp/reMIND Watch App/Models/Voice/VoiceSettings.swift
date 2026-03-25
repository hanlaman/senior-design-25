//
//  VoiceSettings.swift
//  reMIND Watch App
//
//  Voice assistant configuration settings
//

import Foundation

/// Speed preset options
public enum SpeedPreset: String, CaseIterable, Identifiable {
    case slowest = "Slowest"
    case slower = "Slower"
    case normal = "Normal"
    case faster = "Faster"
    case fastest = "Fastest"

    public var id: String { rawValue }

    /// Actual speaking rate multiplier (Azure supports 0.5-1.5)
    public var rate: Double {
        switch self {
        case .slowest: return 0.5
        case .slower: return 0.75
        case .normal: return 1.0
        case .faster: return 1.25
        case .fastest: return 1.5
        }
    }

    /// Icon for visual representation
    public var icon: String {
        switch self {
        case .slowest: return "tortoise.fill"
        case .slower: return "tortoise"
        case .normal: return "hare"
        case .faster: return "hare.fill"
        case .fastest: return "bolt.fill"
        }
    }

    /// Create preset from a rate value (finds closest match)
    public static func from(rate: Double) -> SpeedPreset {
        let presets = SpeedPreset.allCases
        return presets.min(by: { abs($0.rate - rate) < abs($1.rate - rate) }) ?? .normal
    }
}

/// Voice assistant configuration settings
public struct VoiceSettings: Codable, Sendable {
    // MARK: - Voice Configuration

    /// Azure voice name (fixed to one voice)
    public let voiceName: String

    /// Speaking rate multiplier (0.5x - 1.5x) - Only user-adjustable field
    public var speakingRate: Double

    /// Voice temperature for response variability (0-2)
    public let voiceTemperature: Double

    // MARK: - Interaction Behavior

    /// When enabled, automatically starts recording after playback completes
    public var continuousListeningEnabled: Bool

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
        continuousListeningEnabled: false,
        instructions: """
You are reMIND, a calm and supportive voice companion for older adults with memory challenges.

Speak clearly, warmly, and patiently. Use short, simple sentences. Keep responses reassuring, concise, and easy to understand.

Help with reminders, memory recall, orientation, and simple daily guidance. Repeat or rephrase when needed. Avoid overwhelming the user with too much information at once.

If the user sounds confused or upset, respond gently and guide them one step at a time. Do not provide medical diagnosis. When safety is a concern, encourage contacting a caregiver or trusted person.

IMPORTANT: When the user asks personal questions about themselves (like "what car do I drive?", "who is my wife?", "where do I live?") and you don't see the answer in your context, you MUST use the get_user_memories function to search for that information BEFORE saying you don't know. Never say "I don't know" without first trying to look it up.

Always be respectful, comforting, and clear.
""",
        vadThreshold: 0.5,
        vadPrefixPaddingMs: 300,
        vadSilenceDurationMs: 500,
        sessionTemperature: 0.8,
        lastSyncDate: nil,
        remoteVersion: nil
    )

    // MARK: - Base Instructions

    /// Base system instructions without memory context
    public static let baseInstructions = """
You are reMIND, a calm and supportive voice companion for older adults with memory challenges.

Speak clearly, warmly, and patiently. Use short, simple sentences. Keep responses reassuring, concise, and easy to understand.

Help with reminders, memory recall, orientation, and simple daily guidance. Repeat or rephrase when needed. Avoid overwhelming the user with too much information at once.

If the user sounds confused or upset, respond gently and guide them one step at a time. Do not provide medical diagnosis. When safety is a concern, encourage contacting a caregiver or trusted person.

IMPORTANT: When the user asks personal questions about themselves (like "what car do I drive?", "who is my wife?", "where do I live?") and you don't see the answer in your context, you MUST use the get_user_memories function to search for that information BEFORE saying you don't know. Never say "I don't know" without first trying to look it up.

Always be respectful, comforting, and clear.
"""

    // MARK: - Memory Context

    /// Create instructions with memory context injected
    /// - Parameter memoryContext: The formatted memory context from the backend
    /// - Returns: Full instructions with memory context appended
    public static func instructionsWithMemoryContext(_ memoryContext: String?) -> String {
        guard let context = memoryContext, !context.isEmpty else {
            return baseInstructions
        }

        return """
\(baseInstructions)

\(context)
"""
    }

    /// Create a copy of settings with memory context included in instructions
    /// - Parameter memoryContext: The formatted memory context from the backend
    /// - Returns: New VoiceSettings with updated instructions
    public func withMemoryContext(_ memoryContext: String?) -> VoiceSettings {
        let fullInstructions = VoiceSettings.instructionsWithMemoryContext(memoryContext)

        return VoiceSettings(
            voiceName: voiceName,
            speakingRate: speakingRate,
            voiceTemperature: voiceTemperature,
            continuousListeningEnabled: continuousListeningEnabled,
            instructions: fullInstructions,
            vadThreshold: vadThreshold,
            vadPrefixPaddingMs: vadPrefixPaddingMs,
            vadSilenceDurationMs: vadSilenceDurationMs,
            sessionTemperature: sessionTemperature,
            lastSyncDate: lastSyncDate,
            remoteVersion: remoteVersion
        )
    }

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
