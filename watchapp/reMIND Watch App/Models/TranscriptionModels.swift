//
//  TranscriptionModels.swift
//  reMIND Watch App
//
//  Data models for live transcription messages
//

import Foundation

/// Role of the speaker in a transcription
enum TranscriptionRole: Equatable, Sendable, CustomStringConvertible {
    case user
    case agent

    var description: String {
        switch self {
        case .user: return "user"
        case .agent: return "agent"
        }
    }
}

/// A transcription message displayed in the captions view
struct TranscriptionMessage: Identifiable, Equatable {
    let id: UUID
    let role: TranscriptionRole
    let itemId: String

    /// Sequence number for ordering (incremented for each new message)
    let sequenceNumber: Int

    /// The progressive text accumulated from delta events.
    /// For user messages, this is the displayed text.
    /// For agent messages, this is shown during playback (may have bad formatting).
    var text: String

    /// Agent messages only: the full correctly-formatted text from response.audio_transcript.done.
    /// This arrives early (before/during playback) and replaces `text` when playback finishes.
    var completeText: String?

    /// Agent messages only: when true, show completeText instead of text.
    /// Set to true when audio playback finishes.
    var isComplete: Bool

    /// The text to display in the UI
    var displayText: String {
        if role == .agent, isComplete, let complete = completeText, !complete.isEmpty {
            return complete
        }
        return text
    }

    /// Create a new transcription message
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - role: Speaker role (user or agent)
    ///   - itemId: Azure conversation item ID
    ///   - sequenceNumber: Order in the conversation
    ///   - text: Initial text content
    ///   - completeText: Complete formatted text (agent messages only)
    ///   - isComplete: Whether the message is complete
    init(
        id: UUID = UUID(),
        role: TranscriptionRole,
        itemId: String,
        sequenceNumber: Int = 0,
        text: String = "",
        completeText: String? = nil,
        isComplete: Bool = false
    ) {
        self.id = id
        self.role = role
        self.itemId = itemId
        self.sequenceNumber = sequenceNumber
        self.text = text
        self.completeText = completeText
        self.isComplete = isComplete
    }
}
