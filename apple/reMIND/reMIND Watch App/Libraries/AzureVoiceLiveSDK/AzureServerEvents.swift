//
//  AzureServerEvents.swift
//  reMIND Watch App
//
//  Server events from Azure Voice Live API specification
//  All 44+ server events from the API
//

import Foundation

// MARK: - Event Envelope

public struct AzureEventEnvelope: Codable {
    let type: String

    enum CodingKeys: String, CodingKey {
        case type
    }
}

// MARK: - Error Event

public struct ErrorEvent: Codable, Sendable {
    let type: String
    let error: RealtimeErrorDetails

    enum CodingKeys: String, CodingKey {
        case type
        case error
    }
}

// MARK: - Session Events

public struct SessionCreatedEvent: Codable, Sendable {
    let type: String
    let session: RealtimeResponseSession

    enum CodingKeys: String, CodingKey {
        case type
        case session
    }
}

public struct SessionUpdatedEvent: Codable, Sendable {
    let type: String
    let session: RealtimeResponseSession

    enum CodingKeys: String, CodingKey {
        case type
        case session
    }
}

public struct SessionAvatarConnectingEvent: Codable, Sendable {
    let type: String
    let serverSdp: String

    enum CodingKeys: String, CodingKey {
        case type
        case serverSdp = "server_sdp"
    }
}

// MARK: - Input Audio Buffer Events

public struct InputAudioBufferCommittedEvent: Codable, Sendable {
    let type: String
    let previousItemId: String?
    let itemId: String

    enum CodingKeys: String, CodingKey {
        case type
        case previousItemId = "previous_item_id"
        case itemId = "item_id"
    }
}

public struct InputAudioBufferClearedEvent: Codable, Sendable {
    let type: String

    enum CodingKeys: String, CodingKey {
        case type
    }
}

public struct InputAudioBufferSpeechStartedEvent: Codable, Sendable {
    let type: String
    let audioStartMs: Int
    let itemId: String

    enum CodingKeys: String, CodingKey {
        case type
        case audioStartMs = "audio_start_ms"
        case itemId = "item_id"
    }
}

public struct InputAudioBufferSpeechStoppedEvent: Codable, Sendable {
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

public struct ConversationItemCreatedEvent: Codable, Sendable {
    let type: String
    let previousItemId: String?
    let item: RealtimeConversationResponseItem

    enum CodingKeys: String, CodingKey {
        case type
        case previousItemId = "previous_item_id"
        case item
    }
}

public struct ConversationItemRetrievedEvent: Codable, Sendable {
    let type: String
    let item: RealtimeConversationResponseItem

    enum CodingKeys: String, CodingKey {
        case type
        case item
    }
}

public struct ConversationItemTruncatedEvent: Codable, Sendable {
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

public struct ConversationItemDeletedEvent: Codable, Sendable {
    let type: String
    let itemId: String

    enum CodingKeys: String, CodingKey {
        case type
        case itemId = "item_id"
    }
}

public struct ConversationItemTranscriptionCompletedEvent: Codable, Sendable {
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

public struct ConversationItemTranscriptionDeltaEvent: Codable, Sendable {
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

public struct ConversationItemTranscriptionFailedEvent: Codable, Sendable {
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

public struct ResponseCreatedEvent: Codable, Sendable {
    let type: String
    let response: RealtimeResponse

    enum CodingKeys: String, CodingKey {
        case type
        case response
    }
}

public struct ResponseDoneEvent: Codable, Sendable {
    let type: String
    let response: RealtimeResponse

    enum CodingKeys: String, CodingKey {
        case type
        case response
    }
}

public struct ResponseOutputItemAddedEvent: Codable, Sendable {
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

public struct ResponseOutputItemDoneEvent: Codable, Sendable {
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

public struct ResponseContentPartAddedEvent: Codable, Sendable {
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

public struct ResponseContentPartDoneEvent: Codable, Sendable {
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

public struct ResponseTextDeltaEvent: Codable, Sendable {
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

public struct ResponseTextDoneEvent: Codable, Sendable {
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

public struct ResponseAudioDeltaEvent: Codable, Sendable {
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

public struct ResponseAudioDoneEvent: Codable, Sendable {
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

public struct ResponseAudioTranscriptDeltaEvent: Codable, Sendable {
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

public struct ResponseAudioTranscriptDoneEvent: Codable, Sendable {
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

public struct ResponseAnimationBlendshapesDeltaEvent: Codable, Sendable {
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

public struct ResponseAnimationBlendshapesDoneEvent: Codable, Sendable {
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

public struct ResponseAudioTimestampDeltaEvent: Codable, Sendable {
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

public struct ResponseAudioTimestampDoneEvent: Codable, Sendable {
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

public struct ResponseAnimationVisemeDeltaEvent: Codable, Sendable {
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

public struct ResponseAnimationVisemeDoneEvent: Codable, Sendable {
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

public struct ResponseFunctionCallArgumentsDeltaEvent: Codable, Sendable {
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

public struct ResponseFunctionCallArgumentsDoneEvent: Codable, Sendable {
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

public struct McpListToolsInProgressEvent: Codable, Sendable {
    let type: String
    let itemId: String

    enum CodingKeys: String, CodingKey {
        case type
        case itemId = "item_id"
    }
}

public struct McpListToolsCompletedEvent: Codable, Sendable {
    let type: String
    let itemId: String

    enum CodingKeys: String, CodingKey {
        case type
        case itemId = "item_id"
    }
}

public struct McpListToolsFailedEvent: Codable, Sendable {
    let type: String
    let itemId: String

    enum CodingKeys: String, CodingKey {
        case type
        case itemId = "item_id"
    }
}

// MARK: - MCP Call Events

public struct ResponseMcpCallArgumentsDeltaEvent: Codable, Sendable {
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

public struct ResponseMcpCallArgumentsDoneEvent: Codable, Sendable {
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

public struct ResponseMcpCallInProgressEvent: Codable, Sendable {
    let type: String
    let itemId: String
    let outputIndex: Int

    enum CodingKeys: String, CodingKey {
        case type
        case itemId = "item_id"
        case outputIndex = "output_index"
    }
}

public struct ResponseMcpCallCompletedEvent: Codable, Sendable {
    let type: String
    let itemId: String
    let outputIndex: Int

    enum CodingKeys: String, CodingKey {
        case type
        case itemId = "item_id"
        case outputIndex = "output_index"
    }
}

public struct ResponseMcpCallFailedEvent: Codable, Sendable {
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

public struct RateLimitsUpdatedEvent: Codable, Sendable {
    let type: String
    let rateLimits: [RealtimeRateLimitsItem]

    enum CodingKeys: String, CodingKey {
        case type
        case rateLimits = "rate_limits"
    }
}
