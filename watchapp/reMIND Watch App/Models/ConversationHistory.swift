//
//  ConversationHistory.swift
//  reMIND Watch App
//
//  Created by Claude Code
//

import Foundation

/// Individual message in conversation history
struct ConversationMessage: Codable, Identifiable, Sendable, Equatable {
    let id: String                    // Azure item.id
    let role: MessageRole             // user or assistant
    let content: String               // Transcript text
    let timestamp: Date               // When message was created
    let sessionId: String             // Session this message belongs to

    enum MessageRole: String, Codable {
        case user
        case assistant
    }
}

/// Session grouping for conversation messages
struct ConversationSession: Codable, Identifiable, Sendable, Equatable {
    let id: String                    // Session ID
    let startTime: Date               // Session start timestamp
    var endTime: Date?                // Session end (nil if active)
    var messages: [ConversationMessage]

    /// Computed property for display
    var messageCount: Int {
        messages.count
    }

    /// Display text for session (relative time)
    var displayText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: startTime, relativeTo: Date())
    }
}

/// Container for all conversation history
struct ConversationHistoryData: Codable, Sendable {
    var sessions: [ConversationSession]
    let maxMessagesPerSession: Int
    let maxSessions: Int

    /// Initialize with default memory limits
    init(sessions: [ConversationSession] = [], maxMessagesPerSession: Int = 50, maxSessions: Int = 10) {
        self.sessions = sessions
        self.maxMessagesPerSession = maxMessagesPerSession
        self.maxSessions = maxSessions
    }

    /// Get current active session
    func activeSession(for sessionId: String) -> ConversationSession? {
        sessions.first { $0.id == sessionId && $0.endTime == nil }
    }
}
