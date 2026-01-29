//
//  AzureTurnDetectionModels.swift
//  reMIND Watch App
//
//  Turn detection models from Azure Voice Live API specification
//  RealtimeTurnDetection is a discriminated union
//

import Foundation

// MARK: - RealtimeTurnDetection (Union Type)

enum RealtimeTurnDetection: Codable, Sendable {
    case serverVAD(RealtimeServerVAD)
    case semanticVAD(RealtimeSemanticVAD)
    case azureSemanticVAD(RealtimeAzureSemanticVAD)
    case azureSemanticVADMultilingual(RealtimeAzureSemanticVADMultilingual)

    enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "server_vad":
            self = .serverVAD(try RealtimeServerVAD(from: decoder))
        case "semantic_vad":
            self = .semanticVAD(try RealtimeSemanticVAD(from: decoder))
        case "azure_semantic_vad":
            self = .azureSemanticVAD(try RealtimeAzureSemanticVAD(from: decoder))
        case "azure_semantic_vad_multilingual":
            self = .azureSemanticVADMultilingual(try RealtimeAzureSemanticVADMultilingual(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown turn detection type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .serverVAD(let config):
            try config.encode(to: encoder)
        case .semanticVAD(let config):
            try config.encode(to: encoder)
        case .azureSemanticVAD(let config):
            try config.encode(to: encoder)
        case .azureSemanticVADMultilingual(let config):
            try config.encode(to: encoder)
        }
    }
}

// MARK: - Server VAD

struct RealtimeServerVAD: Codable, Sendable {
    let type: String = "server_vad"
    let threshold: Double?
    let prefixPaddingMs: Int?
    let silenceDurationMs: Int?
    let endOfUtteranceDetection: RealtimeEOUDetection?
    let createResponse: Bool?
    let interruptResponse: Bool?
    let autoTruncate: Bool?

    enum CodingKeys: String, CodingKey {
        case type
        case threshold
        case prefixPaddingMs = "prefix_padding_ms"
        case silenceDurationMs = "silence_duration_ms"
        case endOfUtteranceDetection = "end_of_utterance_detection"
        case createResponse = "create_response"
        case interruptResponse = "interrupt_response"
        case autoTruncate = "auto_truncate"
    }

    init(
        threshold: Double? = nil,
        prefixPaddingMs: Int? = nil,
        silenceDurationMs: Int? = nil,
        endOfUtteranceDetection: RealtimeEOUDetection? = nil,
        createResponse: Bool? = nil,
        interruptResponse: Bool? = nil,
        autoTruncate: Bool? = nil
    ) {
        self.threshold = threshold
        self.prefixPaddingMs = prefixPaddingMs
        self.silenceDurationMs = silenceDurationMs
        self.endOfUtteranceDetection = endOfUtteranceDetection
        self.createResponse = createResponse
        self.interruptResponse = interruptResponse
        self.autoTruncate = autoTruncate
    }
}

// MARK: - Semantic VAD

struct RealtimeSemanticVAD: Codable, Sendable {
    let type: String = "semantic_vad"
    let eagerness: String?
    let createResponse: Bool?
    let interruptResponse: Bool?

    enum CodingKeys: String, CodingKey {
        case type
        case eagerness
        case createResponse = "create_response"
        case interruptResponse = "interrupt_response"
    }

    init(
        eagerness: String? = nil,
        createResponse: Bool? = nil,
        interruptResponse: Bool? = nil
    ) {
        self.eagerness = eagerness
        self.createResponse = createResponse
        self.interruptResponse = interruptResponse
    }
}

// MARK: - Azure Semantic VAD

struct RealtimeAzureSemanticVAD: Codable, Sendable {
    let type: String = "azure_semantic_vad"
    let threshold: Double?
    let prefixPaddingMs: Int?
    let silenceDurationMs: Int?
    let endOfUtteranceDetection: RealtimeEOUDetection?
    let speechDurationMs: Int?
    let removeFillerWords: Bool?
    let languages: [String]?
    let createResponse: Bool?
    let interruptResponse: Bool?
    let autoTruncate: Bool?

    enum CodingKeys: String, CodingKey {
        case type
        case threshold
        case prefixPaddingMs = "prefix_padding_ms"
        case silenceDurationMs = "silence_duration_ms"
        case endOfUtteranceDetection = "end_of_utterance_detection"
        case speechDurationMs = "speech_duration_ms"
        case removeFillerWords = "remove_filler_words"
        case languages
        case createResponse = "create_response"
        case interruptResponse = "interrupt_response"
        case autoTruncate = "auto_truncate"
    }

    init(
        threshold: Double? = nil,
        prefixPaddingMs: Int? = nil,
        silenceDurationMs: Int? = nil,
        endOfUtteranceDetection: RealtimeEOUDetection? = nil,
        speechDurationMs: Int? = nil,
        removeFillerWords: Bool? = nil,
        languages: [String]? = nil,
        createResponse: Bool? = nil,
        interruptResponse: Bool? = nil,
        autoTruncate: Bool? = nil
    ) {
        self.threshold = threshold
        self.prefixPaddingMs = prefixPaddingMs
        self.silenceDurationMs = silenceDurationMs
        self.endOfUtteranceDetection = endOfUtteranceDetection
        self.speechDurationMs = speechDurationMs
        self.removeFillerWords = removeFillerWords
        self.languages = languages
        self.createResponse = createResponse
        self.interruptResponse = interruptResponse
        self.autoTruncate = autoTruncate
    }
}

// MARK: - Azure Semantic VAD Multilingual

struct RealtimeAzureSemanticVADMultilingual: Codable, Sendable {
    let type: String = "azure_semantic_vad_multilingual"
    let threshold: Double?
    let prefixPaddingMs: Int?
    let silenceDurationMs: Int?
    let endOfUtteranceDetection: RealtimeEOUDetection?
    let speechDurationMs: Int?
    let removeFillerWords: Bool?
    let languages: [String]?
    let createResponse: Bool?
    let interruptResponse: Bool?
    let autoTruncate: Bool?

    enum CodingKeys: String, CodingKey {
        case type
        case threshold
        case prefixPaddingMs = "prefix_padding_ms"
        case silenceDurationMs = "silence_duration_ms"
        case endOfUtteranceDetection = "end_of_utterance_detection"
        case speechDurationMs = "speech_duration_ms"
        case removeFillerWords = "remove_filler_words"
        case languages
        case createResponse = "create_response"
        case interruptResponse = "interrupt_response"
        case autoTruncate = "auto_truncate"
    }

    init(
        threshold: Double? = nil,
        prefixPaddingMs: Int? = nil,
        silenceDurationMs: Int? = nil,
        endOfUtteranceDetection: RealtimeEOUDetection? = nil,
        speechDurationMs: Int? = nil,
        removeFillerWords: Bool? = nil,
        languages: [String]? = nil,
        createResponse: Bool? = nil,
        interruptResponse: Bool? = nil,
        autoTruncate: Bool? = nil
    ) {
        self.threshold = threshold
        self.prefixPaddingMs = prefixPaddingMs
        self.silenceDurationMs = silenceDurationMs
        self.endOfUtteranceDetection = endOfUtteranceDetection
        self.speechDurationMs = speechDurationMs
        self.removeFillerWords = removeFillerWords
        self.languages = languages
        self.createResponse = createResponse
        self.interruptResponse = interruptResponse
        self.autoTruncate = autoTruncate
    }
}

// MARK: - End of Utterance Detection

struct RealtimeEOUDetection: Codable, Sendable {
    let model: String
    let thresholdLevel: String?
    let timeoutMs: Double?

    enum CodingKeys: String, CodingKey {
        case model
        case thresholdLevel = "threshold_level"
        case timeoutMs = "timeout_ms"
    }

    init(
        model: String,
        thresholdLevel: String? = nil,
        timeoutMs: Double? = nil
    ) {
        self.model = model
        self.thresholdLevel = thresholdLevel
        self.timeoutMs = timeoutMs
    }
}
