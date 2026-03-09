//
//  ConversationHistoryManager.swift
//  reMIND Watch App
//
//  Created by Claude Code
//

import Foundation
import Combine
import os

class ConversationHistoryManager: ObservableObject {
    static let shared = ConversationHistoryManager()

    @Published private(set) var history: ConversationHistoryData

    private let userDefaults = UserDefaults.standard
    private let historyKey = "conversationHistory"

    private init() {
        self.history = Self.load()
        AppLogger.history.info("ConversationHistoryManager initialized with \(self.history.sessions.count) sessions")
    }

    // MARK: - Session Lifecycle

    /// Start a new conversation session
    func startSession(_ sessionId: String) {
        let newSession = ConversationSession(
            id: sessionId,
            startTime: Date(),
            endTime: nil,
            messages: []
        )

        history.sessions.append(newSession)
        enforceMemoryLimits()
        save()

        AppLogger.history.info("Started conversation session: \(sessionId)")
    }

    /// End an existing conversation session
    func endSession(_ sessionId: String) {
        guard let index = history.sessions.firstIndex(where: { $0.id == sessionId }) else {
            AppLogger.history.warning("Cannot end session \(sessionId): not found")
            return
        }

        history.sessions[index].endTime = Date()
        save()

        AppLogger.history.info("Ended conversation session: \(sessionId)")
    }

    // MARK: - Message Management

    /// Add a message to the conversation history
    func addMessage(itemId: String, role: ConversationMessage.MessageRole, content: String, sessionId: String) {
        guard let sessionIndex = history.sessions.firstIndex(where: { $0.id == sessionId }) else {
            AppLogger.history.warning("Cannot add message: session \(sessionId) not found")
            return
        }

        let message = ConversationMessage(
            id: itemId,
            role: role,
            content: content,
            timestamp: Date(),
            sessionId: sessionId
        )

        history.sessions[sessionIndex].messages.append(message)

        // Enforce per-session message limit
        let messageCount = history.sessions[sessionIndex].messages.count
        if messageCount > history.maxMessagesPerSession {
            let excessCount = messageCount - history.maxMessagesPerSession
            history.sessions[sessionIndex].messages.removeFirst(excessCount)
            AppLogger.history.debug("Removed \(excessCount) old message(s) from session \(sessionId) (FIFO eviction)")
        }

        save()

        AppLogger.history.debug("Added \(role.rawValue) message to session \(sessionId): \(content.prefix(50))...")
    }

    // MARK: - Session Deletion

    /// Delete a specific conversation session
    func deleteSession(_ sessionId: String) {
        guard let index = history.sessions.firstIndex(where: { $0.id == sessionId }) else {
            AppLogger.history.warning("Cannot delete session \(sessionId): not found")
            return
        }

        history.sessions.remove(at: index)
        save()

        AppLogger.history.info("Deleted conversation session: \(sessionId)")
    }

    // MARK: - Persistence

    /// Save conversation history to UserDefaults
    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(self.history)
            userDefaults.set(data, forKey: historyKey)
            AppLogger.history.debug("Saved conversation history (\(self.history.sessions.count) sessions)")
        } catch {
            AppLogger.history.error("Failed to save conversation history: \(error.localizedDescription)")
        }
    }

    /// Load conversation history from UserDefaults
    private static func load() -> ConversationHistoryData {
        guard let data = UserDefaults.standard.data(forKey: "conversationHistory") else {
            AppLogger.history.info("No saved conversation history found, starting fresh")
            return ConversationHistoryData()
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let history = try decoder.decode(ConversationHistoryData.self, from: data)
            AppLogger.history.info("Loaded conversation history with \(history.sessions.count) sessions")
            return history
        } catch {
            AppLogger.history.error("Failed to load conversation history: \(error.localizedDescription)")
            return ConversationHistoryData()
        }
    }

    // MARK: - Memory Management

    /// Enforce memory limits using FIFO eviction
    private func enforceMemoryLimits() {
        // Remove oldest sessions if exceeding limit
        if self.history.sessions.count > self.history.maxSessions {
            let excessCount = self.history.sessions.count - self.history.maxSessions

            // Sort by start time to ensure oldest are removed
            self.history.sessions.sort { $0.startTime < $1.startTime }
            self.history.sessions.removeFirst(excessCount)

            AppLogger.history.info("Removed \(excessCount) old session(s) (FIFO eviction, max: \(self.history.maxSessions))")
        }
    }
}

// MARK: - Protocol Conformance

extension ConversationHistoryManager: HistoryManagerProtocol {
    // All protocol requirements already implemented in the class
}
