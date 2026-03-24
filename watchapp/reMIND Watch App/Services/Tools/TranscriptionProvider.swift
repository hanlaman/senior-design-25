//
//  TranscriptionProvider.swift
//  reMIND Watch App
//
//  Protocol for providing transcript data to hidden tools
//

import Foundation

/// Protocol for providing session transcript data to tools
@MainActor
public protocol TranscriptionProvider: AnyObject {
    /// Get all messages from the current session
    func getTranscriptMessages() -> [TranscriptEntry]
}

/// A single entry in the transcript
public struct TranscriptEntry: Codable, Sendable {
    public let role: String        // "user" or "assistant"
    public let text: String
    public let sequenceNumber: Int

    public init(role: String, text: String, sequenceNumber: Int) {
        self.role = role
        self.text = text
        self.sequenceNumber = sequenceNumber
    }
}
