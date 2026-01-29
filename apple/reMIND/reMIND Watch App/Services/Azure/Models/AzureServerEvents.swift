//
//  AzureServerEvents.swift
//  reMIND Watch App
//
//  Server events from Azure Voice Live API specification
//  All 44+ server events from the API
//

import Foundation

// MARK: - Event Envelope

struct AzureEventEnvelope: Codable {
    let type: String

    enum CodingKeys: String, CodingKey {
        case type
    }
}

// MARK: - Error Event

struct ErrorEvent: Codable, Sendable {
    let type: String
    let error: RealtimeErrorDetails

    enum CodingKeys: String, CodingKey {
        case type
        case error
    }
}

// MARK: - Session Events

struct SessionCreatedEvent: Codable, Sendable {
    let type: String
    let session: RealtimeResponseSession

    enum CodingKeys: String, CodingKey {
        case type
        case session
    }
}

struct SessionUpdatedEvent: Codable, Sendable {
    let type: String
    let session: RealtimeResponseSession

    enum CodingKeys: String, CodingKey {
        case type
        case session
    }
}

struct SessionAvatarConnectingEvent: Codable, Sendable {
    let type: String
    let serverSdp: String

    enum CodingKeys: String, CodingKey {
        case type
        case serverSdp = "server_sdp"
    }
}

// MARK: - Input Audio Buffer Events

struct InputAudioBufferCommittedEvent: Codable, Sendable {
    let type: String
    let previousItemId: String?
    let itemId: String

    enum CodingKeys: String, CodingKey {
        case type
        case previousItemId = "previous_item_id"
        case itemId = "item_id"
    }
}

struct InputAudioBufferClearedEvent: Codable, Sendable {
    let type: String

    enum CodingKeys: String, CodingKey {
        case type
    }
}

struct InputAudioBufferSpeechStartedEvent: Codable, Sendable {
    let type: String
    let audioStartMs: Int
    let itemId: String

    enum CodingKeys: String, CodingKey {
        case type
        case audioStartMs = "audio_start_ms"
        case itemId = "item_id"
    }
}

struct InputAudioBufferSpeechStoppedEvent: Codable, Sendable {
    let type: String
    let audioEndMs: Int
    let itemId: String

    enum CodingKeys: String, CodingKey {
        case type
        case audioEndMs = "audio_end_ms"
        case itemId = "item_id"
    }
}

// MARK: - Conversation Item Events

struct ConversationItemCreatedEvent: Codable, Sendable {
    let type: String
    let previousItemId: String?
    let item: RealtimeConversationResponseItem

    enum CodingKeys: String, CodingKey {
        case type
        case previousItemId = "previous_item_id"
        case item
    }
}

struct ConversationItemRetrievedEvent: Codable, Sendable {
    let type: String
    let item: RealtimeConversationResponseItem

    enum CodingKeys: String, CodingKey {
        case type
        case item
    }
}

struct ConversationItemTruncatedEvent: Codable, Sendable {
    let type: String
    let itemId: String
    let contentIndex: Int
    let audioEndMs: Int

    enum CodingKeys: String, CodingKey {
        case type
        case itemId = "item_id"
        case contentIndex = "content_index"
        case audioEndMs = "audio_end_ms"
    }
}

struct ConversationItemDeletedEvent: Codable, Sendable {
    let type: String
    let itemId: String

    enum CodingKeys: String, CodingKey {
        case type
        case itemId = "item_id"
    }
}

struct ConversationItemTranscriptionCompletedEvent: Codable, Sendable {
    let type: String
    let itemId: String
    let contentIndex: Int
    let transcript: String

    enum CodingKeys: String, CodingKey {
        case type
        case itemId = "item_id"
        case contentIndex = "content_index"
        case transcript
    }
}

struct ConversationItemTranscriptionDeltaEvent: Codable, Sendable {
    let type: String
    let itemId: String
    let contentIndex: Int
    let delta: String

    enum CodingKeys: String, CodingKey {
        case type
        case itemId = "item_id"
        case contentIndex = "content_index"
        case delta
    }
}

struct ConversationItemTranscriptionFailedEvent: Codable, Sendable {
    let type: String
    let itemId: String
    let contentIndex: Int
    let error: AnyCodable

    enum CodingKeys: String, CodingKey {
        case type
        case itemId = "item_id"
        case contentIndex = "content_index"
        case error
    }
}

// MARK: - Response Events

struct ResponseCreatedEvent: Codable, Sendable {
    let type: String
    let response: RealtimeResponse

    enum CodingKeys: String, CodingKey {
        case type
        case response
    }
}

struct ResponseDoneEvent: Codable, Sendable {
    let type: String
    let response: RealtimeResponse

    enum CodingKeys: String, CodingKey {
        case type
        case response
    }
}

struct ResponseOutputItemAddedEvent: Codable, Sendable {
    let type: String
    let responseId: String
    let outputIndex: Int
    let item: RealtimeConversationResponseItem

    enum CodingKeys: String, CodingKey {
        case type
        case responseId = "response_id"
        case outputIndex = "output_index"
        case item
    }
}

struct ResponseOutputItemDoneEvent: Codable, Sendable {
    let type: String
    let responseId: String
    let outputIndex: Int
    let item: RealtimeConversationResponseItem

    enum CodingKeys: String, CodingKey {
        case type
        case responseId = "response_id"
        case outputIndex = "output_index"
        case item
    }
}

struct ResponseContentPartAddedEvent: Codable, Sendable {
    let type: String
    let responseId: String
    let itemId: String
    let outputIndex: Int
    let contentIndex: Int
    let part: RealtimeContentPart

    enum CodingKeys: String, CodingKey {
        case type
        case responseId = "response_id"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case contentIndex = "content_index"
        case part
    }
}

struct ResponseContentPartDoneEvent: Codable, Sendable {
    let type: String
    let responseId: String
    let itemId: String
    let outputIndex: Int
    let contentIndex: Int
    let part: RealtimeContentPart

    enum CodingKeys: String, CodingKey {
        case type
        case responseId = "response_id"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case contentIndex = "content_index"
        case part
    }
}

// MARK: - Text Streaming Events

struct ResponseTextDeltaEvent: Codable, Sendable {
    let type: String
    let responseId: String
    let itemId: String
    let outputIndex: Int
    let contentIndex: Int
    let delta: String

    enum CodingKeys: String, CodingKey {
        case type
        case responseId = "response_id"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case contentIndex = "content_index"
        case delta
    }
}

struct ResponseTextDoneEvent: Codable, Sendable {
    let type: String
    let responseId: String
    let itemId: String
    let outputIndex: Int
    let contentIndex: Int
    let text: String

    enum CodingKeys: String, CodingKey {
        case type
        case responseId = "response_id"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case contentIndex = "content_index"
        case text
    }
}

// MARK: - Audio Streaming Events

struct ResponseAudioDeltaEvent: Codable, Sendable {
    let type: String
    let responseId: String
    let itemId: String
    let outputIndex: Int
    let contentIndex: Int
    let delta: String

    enum CodingKeys: String, CodingKey {
        case type
        case responseId = "response_id"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case contentIndex = "content_index"
        case delta
    }
}

struct ResponseAudioDoneEvent: Codable, Sendable {
    let type: String
    let responseId: String
    let itemId: String
    let outputIndex: Int
    let contentIndex: Int

    enum CodingKeys: String, CodingKey {
        case type
        case responseId = "response_id"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case contentIndex = "content_index"
    }
}

struct ResponseAudioTranscriptDeltaEvent: Codable, Sendable {
    let type: String
    let responseId: String
    let itemId: String
    let outputIndex: Int
    let contentIndex: Int
    let delta: String

    enum CodingKeys: String, CodingKey {
        case type
        case responseId = "response_id"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case contentIndex = "content_index"
        case delta
    }
}

struct ResponseAudioTranscriptDoneEvent: Codable, Sendable {
    let type: String
    let responseId: String
    let itemId: String
    let outputIndex: Int
    let contentIndex: Int
    let transcript: String

    enum CodingKeys: String, CodingKey {
        case type
        case responseId = "response_id"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case contentIndex = "content_index"
        case transcript
    }
}

// MARK: - Animation Blendshapes Events

struct ResponseAnimationBlendshapesDeltaEvent: Codable, Sendable {
    let type: String
    let responseId: String
    let itemId: String
    let outputIndex: Int
    let contentIndex: Int
    let frameIndex: Int
    let frames: [[Double]]

    enum CodingKeys: String, CodingKey {
        case type
        case responseId = "response_id"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case contentIndex = "content_index"
        case frameIndex = "frame_index"
        case frames
    }
}

struct ResponseAnimationBlendshapesDoneEvent: Codable, Sendable {
    let type: String
    let responseId: String
    let itemId: String
    let outputIndex: Int

    enum CodingKeys: String, CodingKey {
        case type
        case responseId = "response_id"
        case itemId = "item_id"
        case outputIndex = "output_index"
    }
}

// MARK: - Audio Timestamp Events

struct ResponseAudioTimestampDeltaEvent: Codable, Sendable {
    let type: String
    let responseId: String
    let itemId: String
    let outputIndex: Int
    let contentIndex: Int
    let audioOffsetMs: Int
    let audioDurationMs: Int
    let text: String
    let timestampType: String

    enum CodingKeys: String, CodingKey {
        case type
        case responseId = "response_id"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case contentIndex = "content_index"
        case audioOffsetMs = "audio_offset_ms"
        case audioDurationMs = "audio_duration_ms"
        case text
        case timestampType = "timestamp_type"
    }
}

struct ResponseAudioTimestampDoneEvent: Codable, Sendable {
    let type: String
    let responseId: String
    let itemId: String
    let outputIndex: Int
    let contentIndex: Int

    enum CodingKeys: String, CodingKey {
        case type
        case responseId = "response_id"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case contentIndex = "content_index"
    }
}

// MARK: - Animation Viseme Events

struct ResponseAnimationVisemeDeltaEvent: Codable, Sendable {
    let type: String
    let responseId: String
    let itemId: String
    let outputIndex: Int
    let contentIndex: Int
    let audioOffsetMs: Int
    let visemeId: Int

    enum CodingKeys: String, CodingKey {
        case type
        case responseId = "response_id"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case contentIndex = "content_index"
        case audioOffsetMs = "audio_offset_ms"
        case visemeId = "viseme_id"
    }
}

struct ResponseAnimationVisemeDoneEvent: Codable, Sendable {
    let type: String
    let responseId: String
    let itemId: String
    let outputIndex: Int
    let contentIndex: Int

    enum CodingKeys: String, CodingKey {
        case type
        case responseId = "response_id"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case contentIndex = "content_index"
    }
}

// MARK: - Function Call Events

struct ResponseFunctionCallArgumentsDeltaEvent: Codable, Sendable {
    let type: String
    let responseId: String
    let itemId: String
    let outputIndex: Int
    let callId: String
    let delta: String

    enum CodingKeys: String, CodingKey {
        case type
        case responseId = "response_id"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case callId = "call_id"
        case delta
    }
}

struct ResponseFunctionCallArgumentsDoneEvent: Codable, Sendable {
    let type: String
    let responseId: String
    let itemId: String
    let outputIndex: Int
    let callId: String
    let arguments: String

    enum CodingKeys: String, CodingKey {
        case type
        case responseId = "response_id"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case callId = "call_id"
        case arguments
    }
}

// MARK: - MCP List Tools Events

struct McpListToolsInProgressEvent: Codable, Sendable {
    let type: String
    let itemId: String

    enum CodingKeys: String, CodingKey {
        case type
        case itemId = "item_id"
    }
}

struct McpListToolsCompletedEvent: Codable, Sendable {
    let type: String
    let itemId: String

    enum CodingKeys: String, CodingKey {
        case type
        case itemId = "item_id"
    }
}

struct McpListToolsFailedEvent: Codable, Sendable {
    let type: String
    let itemId: String

    enum CodingKeys: String, CodingKey {
        case type
        case itemId = "item_id"
    }
}

// MARK: - MCP Call Events

struct ResponseMcpCallArgumentsDeltaEvent: Codable, Sendable {
    let type: String
    let responseId: String
    let itemId: String
    let outputIndex: Int
    let delta: String

    enum CodingKeys: String, CodingKey {
        case type
        case responseId = "response_id"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case delta
    }
}

struct ResponseMcpCallArgumentsDoneEvent: Codable, Sendable {
    let type: String
    let responseId: String
    let itemId: String
    let outputIndex: Int
    let arguments: String

    enum CodingKeys: String, CodingKey {
        case type
        case responseId = "response_id"
        case itemId = "item_id"
        case outputIndex = "output_index"
        case arguments
    }
}

struct ResponseMcpCallInProgressEvent: Codable, Sendable {
    let type: String
    let itemId: String
    let outputIndex: Int

    enum CodingKeys: String, CodingKey {
        case type
        case itemId = "item_id"
        case outputIndex = "output_index"
    }
}

struct ResponseMcpCallCompletedEvent: Codable, Sendable {
    let type: String
    let itemId: String
    let outputIndex: Int

    enum CodingKeys: String, CodingKey {
        case type
        case itemId = "item_id"
        case outputIndex = "output_index"
    }
}

struct ResponseMcpCallFailedEvent: Codable, Sendable {
    let type: String
    let itemId: String
    let outputIndex: Int

    enum CodingKeys: String, CodingKey {
        case type
        case itemId = "item_id"
        case outputIndex = "output_index"
    }
}

// MARK: - Rate Limits Event

struct RateLimitsUpdatedEvent: Codable, Sendable {
    let type: String
    let rateLimits: [RealtimeRateLimitsItem]

    enum CodingKeys: String, CodingKey {
        case type
        case rateLimits = "rate_limits"
    }
}
