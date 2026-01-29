//
//  AzureResponseModels.swift
//  reMIND Watch App
//
//  Response models from Azure Voice Live API specification
//

import Foundation

// MARK: - RealtimeResponse

public struct RealtimeResponse: Codable, Sendable {
    let id: String?
    let object: String?
    let status: RealtimeResponseStatus?
    let statusDetails: RealtimeResponseStatusDetails?
    let output: [RealtimeConversationResponseItem]?
    let usage: RealtimeUsage?
    let conversationId: String?
    let voice: RealtimeVoice?
    let modalities: [String]?
    let outputAudioFormat: RealtimeOutputAudioFormat?
    let temperature: Double?
    let maxResponseOutputTokens: MaxOutputTokens?

    enum CodingKeys: String, CodingKey {
        case id
        case object
        case status
        case statusDetails = "status_details"
        case output
        case usage
        case conversationId = "conversation_id"
        case voice
        case modalities
        case outputAudioFormat = "output_audio_format"
        case temperature
        case maxResponseOutputTokens = "max_response_output_tokens"
    }
}

// MARK: - Response Status Details

public struct RealtimeResponseStatusDetails: Codable, Sendable {
    let type: String?
    let reason: String?
    let error: RealtimeErrorDetails?

    enum CodingKeys: String, CodingKey {
        case type
        case reason
        case error
    }
}

// MARK: - Response Options

public struct RealtimeResponseOptions: Codable, Sendable {
    let modalities: [String]?
    let instructions: String?
    let voice: RealtimeVoice?
    let tools: [RealtimeTool]?
    let toolChoice: RealtimeToolChoice?
    let temperature: Double?
    let maxResponseOutputTokens: MaxOutputTokens?
    let conversation: String?
    let metadata: [String: String]?
    let animation: RealtimeAnimation?

    enum CodingKeys: String, CodingKey {
        case modalities
        case instructions
        case voice
        case tools
        case toolChoice = "tool_choice"
        case temperature
        case maxResponseOutputTokens = "max_response_output_tokens"
        case conversation
        case metadata
        case animation
    }

    public init(
        modalities: [String]? = nil,
        instructions: String? = nil,
        voice: RealtimeVoice? = nil,
        tools: [RealtimeTool]? = nil,
        toolChoice: RealtimeToolChoice? = nil,
        temperature: Double? = nil,
        maxResponseOutputTokens: MaxOutputTokens? = nil,
        conversation: String? = nil,
        metadata: [String: String]? = nil,
        animation: RealtimeAnimation? = nil
    ) {
        self.modalities = modalities
        self.instructions = instructions
        self.voice = voice
        self.tools = tools
        self.toolChoice = toolChoice
        self.temperature = temperature
        self.maxResponseOutputTokens = maxResponseOutputTokens
        self.conversation = conversation
        self.metadata = metadata
        self.animation = animation
    }
}

// MARK: - Usage

public struct RealtimeUsage: Codable, Sendable {
    let totalTokens: Int
    let inputTokens: Int
    let outputTokens: Int
    let inputTokenDetails: TokenDetails?
    let outputTokenDetails: TokenDetails?

    enum CodingKeys: String, CodingKey {
        case totalTokens = "total_tokens"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case inputTokenDetails = "input_token_details"
        case outputTokenDetails = "output_token_details"
    }
}

// MARK: - Token Details

public struct TokenDetails: Codable, Sendable {
    let cachedTokens: Int?
    let textTokens: Int?
    let audioTokens: Int?

    enum CodingKeys: String, CodingKey {
        case cachedTokens = "cached_tokens"
        case textTokens = "text_tokens"
        case audioTokens = "audio_tokens"
    }
}

// MARK: - Error Details

public struct RealtimeErrorDetails: Codable, Sendable {
    let type: String
    let code: String?
    let message: String
    let param: String?
    let eventId: String?

    enum CodingKeys: String, CodingKey {
        case type
        case code
        case message
        case param
        case eventId = "event_id"
    }
}

// MARK: - Rate Limits

public struct RealtimeRateLimitsItem: Codable, Sendable {
    let name: String
    let limit: Int
    let remaining: Int
    let resetSeconds: Int

    enum CodingKeys: String, CodingKey {
        case name
        case limit
        case remaining
        case resetSeconds = "reset_seconds"
    }
}
