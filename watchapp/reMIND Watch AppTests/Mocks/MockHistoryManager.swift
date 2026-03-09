//
//  MockHistoryManager.swift
//  reMIND Watch AppTests
//
//  Mock implementation of HistoryManagerProtocol for testing
//

import Foundation
@testable import reMIND_Watch_App

/// Mock history manager for testing
class MockHistoryManager: HistoryManagerProtocol {
    // MARK: - Test Control Properties

    /// Whether startSession was called
    private(set) var startSessionCalled = false

    /// Session IDs passed to startSession
    private(set) var startedSessionIds: [String] = []

    /// Whether endSession was called
    private(set) var endSessionCalled = false

    /// Session IDs passed to endSession
    private(set) var endedSessionIds: [String] = []

    /// Whether addMessage was called
    private(set) var addMessageCalled = false

    /// All messages added via addMessage
    private(set) var addedMessages: [(itemId: String, role: ConversationMessage.MessageRole, content: String, sessionId: String)] = []

    /// Whether deleteSession was called
    private(set) var deleteSessionCalled = false

    /// Session IDs passed to deleteSession
    private(set) var deletedSessionIds: [String] = []

    // MARK: - Protocol Methods

    func startSession(_ sessionId: String) {
        startSessionCalled = true
        startedSessionIds.append(sessionId)
    }

    func endSession(_ sessionId: String) {
        endSessionCalled = true
        endedSessionIds.append(sessionId)
    }

    func addMessage(
        itemId: String,
        role: ConversationMessage.MessageRole,
        content: String,
        sessionId: String
    ) {
        addMessageCalled = true
        addedMessages.append((itemId: itemId, role: role, content: content, sessionId: sessionId))
    }

    func deleteSession(_ sessionId: String) {
        deleteSessionCalled = true
        deletedSessionIds.append(sessionId)
    }

    // MARK: - Test Control Methods

    /// Reset all test state
    func reset() {
        startSessionCalled = false
        startedSessionIds.removeAll()
        endSessionCalled = false
        endedSessionIds.removeAll()
        addMessageCalled = false
        addedMessages.removeAll()
        deleteSessionCalled = false
        deletedSessionIds.removeAll()
    }

    /// Check if a session was started
    func wasSessionStarted(_ sessionId: String) -> Bool {
        startedSessionIds.contains(sessionId)
    }

    /// Check if a session was ended
    func wasSessionEnded(_ sessionId: String) -> Bool {
        endedSessionIds.contains(sessionId)
    }

    /// Get messages for a specific session
    func messagesForSession(_ sessionId: String) -> [(itemId: String, role: ConversationMessage.MessageRole, content: String)] {
        addedMessages
            .filter { $0.sessionId == sessionId }
            .map { (itemId: $0.itemId, role: $0.role, content: $0.content) }
    }
}
