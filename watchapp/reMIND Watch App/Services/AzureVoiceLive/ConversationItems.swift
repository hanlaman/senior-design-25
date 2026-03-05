//
//  ConversationItems.swift
//  reMIND Watch App
//
//  Conversation item management for Azure Voice Live
//

import Foundation
import os

/// Manages conversation items (messages, function calls, etc.) for Azure Voice Live
public final class ConversationItems {
    // MARK: - Properties

    private unowned let connection: VoiceLiveConnection

    // MARK: - Initialization

    init(connection: VoiceLiveConnection) {
        self.connection = connection
    }

    // MARK: - Conversation Item Management

    /// Create a new conversation item
    /// - Parameters:
    ///   - item: The conversation item to create
    ///   - previousItemId: Optional ID of the previous item to insert after
    /// - Throws: `AzureError` if not connected or session not ready
    public func create(_ item: RealtimeConversationRequestItem, after previousItemId: String? = nil) async throws {
        guard await connection.connectionState == .connected else {
            throw AzureError.notConnected
        }

        guard await connection.sessionState.canAcceptConversation else {
            throw AzureError.sessionNotReady
        }

        AppLogger.azure.debug("Creating conversation item")

        let event = ConversationItemCreateEvent(previousItemId: previousItemId, item: item)
        try await connection.sendEvent(event)
    }

    /// Retrieve a conversation item by ID
    /// - Parameter id: The item ID to retrieve
    /// - Throws: `AzureError` if not connected or session not ready
    public func retrieve(id: String) async throws {
        guard await connection.connectionState == .connected else {
            throw AzureError.notConnected
        }

        guard await connection.sessionState.canAcceptConversation else {
            throw AzureError.sessionNotReady
        }

        AppLogger.azure.debug("Retrieving conversation item: \(id)")

        let event = ConversationItemRetrieveEvent(itemId: id)
        try await connection.sendEvent(event)
    }

    /// Truncate a conversation item
    /// - Parameters:
    ///   - id: The item ID to truncate
    ///   - contentIndex: The content index to truncate at
    ///   - audioEndMs: The audio end time in milliseconds
    /// - Throws: `AzureError` if not connected or session not ready
    public func truncate(id: String, contentIndex: Int, audioEndMs: Int) async throws {
        guard await connection.connectionState == .connected else {
            throw AzureError.notConnected
        }

        guard await connection.sessionState.canAcceptConversation else {
            throw AzureError.sessionNotReady
        }

        AppLogger.azure.debug("Truncating conversation item: \(id) at content index \(contentIndex), audio end: \(audioEndMs)ms")

        let event = ConversationItemTruncateEvent(itemId: id, contentIndex: contentIndex, audioEndMs: audioEndMs)
        try await connection.sendEvent(event)
    }

    /// Delete a conversation item
    /// - Parameter id: The item ID to delete
    /// - Throws: `AzureError` if not connected or session not ready
    public func delete(id: String) async throws {
        guard await connection.connectionState == .connected else {
            throw AzureError.notConnected
        }

        guard await connection.sessionState.canAcceptConversation else {
            throw AzureError.sessionNotReady
        }

        AppLogger.azure.debug("Deleting conversation item: \(id)")

        let event = ConversationItemDeleteEvent(itemId: id)
        try await connection.sendEvent(event)
    }
}
