//
//  AzureAudioModels.swift
//  reMIND Watch App
//
//  Audio configuration models from Azure Voice Live API specification
//

import Foundation

// MARK: - Audio Input Transcription Settings

struct RealtimeAudioInputTranscriptionSettings: Codable, Sendable {
    let model: String
    let language: String?
    let customSpeech: AnyCodable?
    let phraseList: [String]?
    let prompt: String?

    enum CodingKeys: String, CodingKey {
        case model
        case language
        case customSpeech = "custom_speech"
        case phraseList = "phrase_list"
        case prompt
    }

    init(
        model: String,
        language: String? = nil,
        customSpeech: AnyCodable? = nil,
        phraseList: [String]? = nil,
        prompt: String? = nil
    ) {
        self.model = model
        self.language = language
        self.customSpeech = customSpeech
        self.phraseList = phraseList
        self.prompt = prompt
    }
}

// MARK: - Input Audio Noise Reduction (Union Type)

enum RealtimeInputAudioNoiseReductionSettings: Codable, Sendable {
    case openai(RealtimeOpenAINoiseReduction)
    case azure(RealtimeAzureDeepNoiseSuppression)

    enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "near_field", "far_field":
            self = .openai(try RealtimeOpenAINoiseReduction(from: decoder))
        case "azure_deep_noise_suppression":
            self = .azure(try RealtimeAzureDeepNoiseSuppression(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown noise reduction type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .openai(let config):
            try config.encode(to: encoder)
        case .azure(let config):
            try config.encode(to: encoder)
        }
    }
}

struct RealtimeOpenAINoiseReduction: Codable, Sendable {
    let type: String

    enum CodingKeys: String, CodingKey {
        case type
    }

    init(type: String) {
        self.type = type
    }
}

struct RealtimeAzureDeepNoiseSuppression: Codable, Sendable {
    let type: String = "azure_deep_noise_suppression"

    enum CodingKeys: String, CodingKey {
        case type
    }
}

// MARK: - Input Audio Echo Cancellation

struct RealtimeInputAudioEchoCancellationSettings: Codable, Sendable {
    let type: String = "server_echo_cancellation"

    enum CodingKeys: String, CodingKey {
        case type
    }
}
