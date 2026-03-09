//
//  TranscriptionManager.swift
//  reMIND Watch App
//
//  Manages live transcription state for the captions view
//

import Foundation
import Combine
import os

/// Manages live transcription messages for display in the captions view
@MainActor
class TranscriptionManager: ObservableObject {
    // MARK: - Published Properties

    /// All transcription messages in the current session
    @Published var messages: [TranscriptionMessage] = []

    /// Progress for typewriter reveal effect (0.0 to 1.0)
    @Published var revealProgress: Double = 0.0

    // MARK: - Private Properties

    /// Item ID of the current in-progress user message
    private var currentUserItemId: String?

    /// Item ID of the current in-progress agent message
    private var currentAgentItemId: String?

    /// Sequence counter for ordering messages
    private var nextSequenceNumber: Int = 0

    /// Sorted messages for display (sorted by sequence number)
    var sortedMessages: [TranscriptionMessage] {
        messages.sorted { $0.sequenceNumber < $1.sequenceNumber }
    }

    // MARK: - Conversation Item Creation

    /// Pre-create a message when a conversation item is created (reserves sequence number)
    /// This ensures messages appear in the correct chronological order
    /// - Parameters:
    ///   - itemId: Azure conversation item ID
    ///   - role: Whether this is a user or agent message
    func handleConversationItemCreated(itemId: String, role: TranscriptionRole) {
        // Only create if we don't already have a message for this item
        guard messages.firstIndex(where: { $0.itemId == itemId }) == nil else {
            return
        }

        // Pre-create message with reserved sequence number
        let message = TranscriptionMessage(
            role: role,
            itemId: itemId,
            sequenceNumber: nextSequenceNumber,
            text: ""  // Will be filled in by transcription deltas
        )
        nextSequenceNumber += 1
        messages.append(message)

        // Track current in-progress message
        if role == .user {
            currentUserItemId = itemId
        } else {
            currentAgentItemId = itemId
        }

        AppLogger.general.debug("Pre-created \(role) message from conversation item: \(itemId) seq: \(message.sequenceNumber)")
    }

    // MARK: - Transcription Delta Handling

    /// Generic handler for transcription deltas (both user and agent)
    /// - Parameters:
    ///   - delta: The partial transcription text to append
    ///   - itemId: Azure conversation item ID
    ///   - role: Whether this is a user or agent message
    private func handleTranscriptionDelta(delta: String, itemId: String, role: TranscriptionRole) {
        // Find existing message or create new one
        if let index = messages.firstIndex(where: { $0.itemId == itemId }) {
            // Append delta to existing message
            messages[index].text += delta
        } else {
            // Create new message with next sequence number (fallback if speech_started was missed)
            let message = TranscriptionMessage(
                role: role,
                itemId: itemId,
                sequenceNumber: nextSequenceNumber,
                text: delta
            )
            nextSequenceNumber += 1
            messages.append(message)

            // Track current in-progress message
            if role == .user {
                currentUserItemId = itemId
            } else {
                currentAgentItemId = itemId
            }

            AppLogger.general.debug("Created new \(role) transcription message: \(itemId) seq: \(message.sequenceNumber)")
        }
    }

    // MARK: - Input Transcription (User Speech)

    /// Handle incoming delta for user input transcription
    /// - Parameters:
    ///   - delta: The partial transcription text
    ///   - itemId: Azure conversation item ID
    func handleInputTranscriptionDelta(delta: String, itemId: String) {
        handleTranscriptionDelta(delta: delta, itemId: itemId, role: .user)
    }

    /// Handle completion of user input transcription
    /// - Parameters:
    ///   - transcript: The complete transcription text
    ///   - itemId: Azure conversation item ID
    func handleInputTranscriptionCompleted(transcript: String, itemId: String) {
        if let index = messages.firstIndex(where: { $0.itemId == itemId }) {
            // Replace with final clean transcript
            messages[index].text = transcript
            messages[index].isComplete = true
            AppLogger.general.debug("User transcription completed: \(itemId)")
        } else {
            // Create complete message if we missed the deltas
            let message = TranscriptionMessage(
                role: .user,
                itemId: itemId,
                sequenceNumber: nextSequenceNumber,
                text: transcript,
                isComplete: true
            )
            nextSequenceNumber += 1
            messages.append(message)
            AppLogger.general.debug("Created completed user transcription: \(itemId)")
        }

        // Clear current user item
        if currentUserItemId == itemId {
            currentUserItemId = nil
        }
    }

    // MARK: - Output Transcription (Agent Speech)

    /// Handle incoming delta for agent output transcription
    /// - Parameters:
    ///   - delta: The partial transcription text
    ///   - itemId: Azure conversation item ID
    func handleOutputTranscriptionDelta(delta: String, itemId: String) {
        handleTranscriptionDelta(delta: delta, itemId: itemId, role: .agent)
    }

    /// Handle completion of agent output transcription (full text received)
    /// - Parameters:
    ///   - transcript: The complete correctly-formatted transcription text
    ///   - itemId: Azure conversation item ID
    func handleOutputTranscriptionDone(transcript: String, itemId: String) {
        if let index = messages.firstIndex(where: { $0.itemId == itemId }) {
            // Store complete text (but don't show it yet - wait for playback to finish)
            messages[index].completeText = transcript
            AppLogger.general.debug("Agent transcription done event received: \(itemId)")
        } else {
            // Create message with complete text if we missed the deltas
            let message = TranscriptionMessage(
                role: .agent,
                itemId: itemId,
                sequenceNumber: nextSequenceNumber,
                text: transcript,
                completeText: transcript
            )
            nextSequenceNumber += 1
            messages.append(message)
            currentAgentItemId = itemId
            AppLogger.general.debug("Created agent transcription from done event: \(itemId) seq: \(message.sequenceNumber)")
        }
    }

    /// Mark the current agent message as complete (call when playback finishes naturally)
    /// This swaps the displayed text from progressive to clean completeText
    func markAgentMessageComplete() {
        guard let itemId = currentAgentItemId,
              let index = messages.firstIndex(where: { $0.itemId == itemId }) else {
            AppLogger.general.debug("No current agent message to mark complete")
            return
        }

        messages[index].isComplete = true
        currentAgentItemId = nil
        revealProgress = 1.0  // Ensure fully revealed
        AppLogger.general.debug("Marked agent message complete: \(itemId)")
    }

    /// Mark the current agent message as cancelled (call when user cancels playback)
    /// Truncates text to what was actually revealed/played, doesn't swap to completeText
    func markAgentMessageCancelled() {
        guard let itemId = currentAgentItemId,
              let index = messages.firstIndex(where: { $0.itemId == itemId }) else {
            AppLogger.general.debug("No current agent message to mark cancelled")
            return
        }

        // Truncate text to only what was revealed during playback
        let fullText = messages[index].text
        if !fullText.isEmpty && revealProgress < 1.0 {
            let revealedCount = Int(Double(fullText.count) * revealProgress)
            messages[index].text = String(fullText.prefix(max(1, revealedCount)))
            AppLogger.general.debug("Truncated agent message to \(revealedCount) chars at \(self.revealProgress) progress")
        }

        // Mark as complete so it displays the truncated text
        messages[index].isComplete = true
        messages[index].completeText = nil  // Clear so displayText uses truncated text
        currentAgentItemId = nil
        revealProgress = 1.0
        AppLogger.general.debug("Marked agent message cancelled: \(itemId)")
    }

    // MARK: - Reveal Progress (Typewriter Effect)

    /// Update the reveal progress for typewriter effect
    /// - Parameter progress: Progress from 0.0 (nothing revealed) to 1.0 (fully revealed)
    func updateRevealProgress(_ progress: Double) {
        revealProgress = max(0.0, min(1.0, progress))
    }

    /// Get the revealed text for the current agent message based on revealProgress
    /// - Returns: The portion of text that should be visible, or nil if no current message
    func revealedAgentText() -> String? {
        guard let itemId = currentAgentItemId,
              let message = messages.first(where: { $0.itemId == itemId }) else {
            return nil
        }

        let text = message.text
        guard !text.isEmpty else { return "" }

        let revealedCount = Int(Double(text.count) * revealProgress)
        return String(text.prefix(revealedCount))
    }

    /// Check if there's an active agent message being revealed
    var hasActiveAgentMessage: Bool {
        currentAgentItemId != nil
    }

    /// The item ID of the current agent message (for UI to check which message to animate)
    var activeAgentItemId: String? {
        currentAgentItemId
    }

    // MARK: - Session Management

    /// Clear all messages (call when starting a new session)
    func clearMessages() {
        messages.removeAll()
        currentUserItemId = nil
        currentAgentItemId = nil
        revealProgress = 0.0
        nextSequenceNumber = 0
        AppLogger.general.debug("Cleared all transcription messages")
    }
}
