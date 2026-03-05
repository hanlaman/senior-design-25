//
//  Conversation.swift
//  reMIND Watch App
//
//  Conversation management for Azure Voice Live
//

import Foundation

/// Manages conversation for Azure Voice Live
/// Provides access to conversation items
public final class Conversation {
    // MARK: - Properties

    /// Access to conversation items
    public let items: ConversationItems

    // MARK: - Initialization

    init(connection: VoiceLiveConnection) {
        self.items = ConversationItems(connection: connection)
    }
}
