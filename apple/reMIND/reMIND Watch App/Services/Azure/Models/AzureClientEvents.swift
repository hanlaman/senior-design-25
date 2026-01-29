//
//  AzureClientEvents.swift
//  reMIND Watch App
//
//  Client events from Azure Voice Live API specification
//  All 12 client events that can be sent to the API
//

import Foundation

// MARK: - Session Management Events

struct SessionUpdateEvent: Codable, Sendable {
    let type: String = "session.update"
    let session: RealtimeRequestSession

    enum CodingKeys: String, CodingKey {
        case type
        case session
    }

    init(session: RealtimeRequestSession) {
        self.session = session
    }
}

struct SessionAvatarConnectEvent: Codable, Sendable {
    let type: String = "session.avatar.connect"
    let clientSdp: String

    enum CodingKeys: String, CodingKey {
        case type
        case clientSdp = "client_sdp"
    }

    init(clientSdp: String) {
        self.clientSdp = clientSdp
    }
}

// MARK: - Audio Buffer Events

struct InputAudioBufferAppendEvent: Codable, Sendable {
    let type: String = "input_audio_buffer.append"
    let audio: String

    enum CodingKeys: String, CodingKey {
        case type
        case audio
    }

    init(audio: String) {
        self.audio = audio
    }
}

struct InputAudioBufferCommitEvent: Codable, Sendable {
    let type: String = "input_audio_buffer.commit"

    enum CodingKeys: String, CodingKey {
        case type
    }

    init() {}
}

struct InputAudioBufferClearEvent: Codable, Sendable {
    let type: String = "input_audio_buffer.clear"

    enum CodingKeys: String, CodingKey {
        case type
    }

    init() {}
}

// MARK: - Conversation Management Events

struct ConversationItemCreateEvent: Codable, Sendable {
    let type: String = "conversation.item.create"
    let previousItemId: String?
    let item: RealtimeConversationRequestItem

    enum CodingKeys: String, CodingKey {
        case type
        case previousItemId = "previous_item_id"
        case item
    }

    init(previousItemId: String? = nil, item: RealtimeConversationRequestItem) {
        self.previousItemId = previousItemId
        self.item = item
    }
}

struct ConversationItemRetrieveEvent: Codable, Sendable {
    let type: String = "conversation.item.retrieve"
    let itemId: String

    enum CodingKeys: String, CodingKey {
        case type
        case itemId = "item_id"
    }

    init(itemId: String) {
        self.itemId = itemId
    }
}

struct ConversationItemTruncateEvent: Codable, Sendable {
    let type: String = "conversation.item.truncate"
    let itemId: String
    let contentIndex: Int
    let audioEndMs: Int

    enum CodingKeys: String, CodingKey {
        case type
        case itemId = "item_id"
        case contentIndex = "content_index"
        case audioEndMs = "audio_end_ms"
    }

    init(itemId: String, contentIndex: Int, audioEndMs: Int) {
        self.itemId = itemId
        self.contentIndex = contentIndex
        self.audioEndMs = audioEndMs
    }
}

struct ConversationItemDeleteEvent: Codable, Sendable {
    let type: String = "conversation.item.delete"
    let itemId: String

    enum CodingKeys: String, CodingKey {
        case type
        case itemId = "item_id"
    }

    init(itemId: String) {
        self.itemId = itemId
    }
}

// MARK: - Response Management Events

struct ResponseCreateEvent: Codable, Sendable {
    let type: String = "response.create"
    let response: RealtimeResponseOptions?

    enum CodingKeys: String, CodingKey {
        case type
        case response
    }

    init(response: RealtimeResponseOptions? = nil) {
        self.response = response
    }
}

struct ResponseCancelEvent: Codable, Sendable {
    let type: String = "response.cancel"

    enum CodingKeys: String, CodingKey {
        case type
    }

    init() {}
}

// MARK: - MCP Tool Approval Event

struct McpApprovalResponseEvent: Codable, Sendable {
    let type: String = "mcp_approval_response"
    let approve: Bool
    let approvalRequestId: String

    enum CodingKeys: String, CodingKey {
        case type
        case approve
        case approvalRequestId = "approval_request_id"
    }

    init(approve: Bool, approvalRequestId: String) {
        self.approve = approve
        self.approvalRequestId = approvalRequestId
    }
}
