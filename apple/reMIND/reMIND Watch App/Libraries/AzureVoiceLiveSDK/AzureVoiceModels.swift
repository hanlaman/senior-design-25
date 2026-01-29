//
//  AzureVoiceModels.swift
//  reMIND Watch App
//
//  Voice configuration models from Azure Voice Live API specification
//  RealtimeVoice is a discriminated union
//

import Foundation

// MARK: - RealtimeVoice (Union Type)

public enum RealtimeVoice: Codable, Sendable {
    case openai(RealtimeOpenAIVoice)
    case azureStandard(RealtimeAzureStandardVoice)
    case azureCustom(RealtimeAzureCustomVoice)
    case azurePersonal(RealtimeAzurePersonalVoice)

    enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "openai":
            self = .openai(try RealtimeOpenAIVoice(from: decoder))
        case "azure-standard":
            self = .azureStandard(try RealtimeAzureStandardVoice(from: decoder))
        case "azure-custom":
            self = .azureCustom(try RealtimeAzureCustomVoice(from: decoder))
        case "azure-personal":
            self = .azurePersonal(try RealtimeAzurePersonalVoice(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown voice type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .openai(let voice):
            try voice.encode(to: encoder)
        case .azureStandard(let voice):
            try voice.encode(to: encoder)
        case .azureCustom(let voice):
            try voice.encode(to: encoder)
        case .azurePersonal(let voice):
            try voice.encode(to: encoder)
        }
    }
}

// MARK: - OpenAI Voice

public struct RealtimeOpenAIVoice: Codable, Sendable {
    let type: String = "openai"
    let name: String

    enum CodingKeys: String, CodingKey {
        case type
        case name
    }

    public init(name: String) {
        self.name = name
    }
}

// MARK: - Azure Standard Voice

public struct RealtimeAzureStandardVoice: Codable, Sendable {
    let type: String = "azure-standard"
    let name: String
    let temperature: Double?
    let customLexiconUrl: String?
    let preferLocales: [String]?
    let locale: String?
    let style: String?
    let pitch: String?
    let rate: String?
    let volume: String?

    enum CodingKeys: String, CodingKey {
        case type
        case name
        case temperature
        case customLexiconUrl = "custom_lexicon_url"
        case preferLocales = "prefer_locales"
        case locale
        case style
        case pitch
        case rate
        case volume
    }

    init(
        name: String,
        temperature: Double? = nil,
        customLexiconUrl: String? = nil,
        preferLocales: [String]? = nil,
        locale: String? = nil,
        style: String? = nil,
        pitch: String? = nil,
        rate: String? = nil,
        volume: String? = nil
    ) {
        self.name = name
        self.temperature = temperature
        self.customLexiconUrl = customLexiconUrl
        self.preferLocales = preferLocales
        self.locale = locale
        self.style = style
        self.pitch = pitch
        self.rate = rate
        self.volume = volume
    }
}

// MARK: - Azure Custom Voice

public struct RealtimeAzureCustomVoice: Codable, Sendable {
    let type: String = "azure-custom"
    let name: String
    let endpointId: String
    let temperature: Double?
    let customLexiconUrl: String?
    let preferLocales: [String]?
    let locale: String?
    let style: String?
    let pitch: String?
    let rate: String?
    let volume: String?

    enum CodingKeys: String, CodingKey {
        case type
        case name
        case endpointId = "endpoint_id"
        case temperature
        case customLexiconUrl = "custom_lexicon_url"
        case preferLocales = "prefer_locales"
        case locale
        case style
        case pitch
        case rate
        case volume
    }

    init(
        name: String,
        endpointId: String,
        temperature: Double? = nil,
        customLexiconUrl: String? = nil,
        preferLocales: [String]? = nil,
        locale: String? = nil,
        style: String? = nil,
        pitch: String? = nil,
        rate: String? = nil,
        volume: String? = nil
    ) {
        self.name = name
        self.endpointId = endpointId
        self.temperature = temperature
        self.customLexiconUrl = customLexiconUrl
        self.preferLocales = preferLocales
        self.locale = locale
        self.style = style
        self.pitch = pitch
        self.rate = rate
        self.volume = volume
    }
}

// MARK: - Azure Personal Voice

public struct RealtimeAzurePersonalVoice: Codable, Sendable {
    let type: String = "azure-personal"
    let name: String
    let model: String
    let temperature: Double?
    let customLexiconUrl: String?
    let preferLocales: [String]?
    let locale: String?
    let pitch: String?
    let rate: String?
    let volume: String?

    enum CodingKeys: String, CodingKey {
        case type
        case name
        case model
        case temperature
        case customLexiconUrl = "custom_lexicon_url"
        case preferLocales = "prefer_locales"
        case locale
        case pitch
        case rate
        case volume
    }

    init(
        name: String,
        model: String,
        temperature: Double? = nil,
        customLexiconUrl: String? = nil,
        preferLocales: [String]? = nil,
        locale: String? = nil,
        pitch: String? = nil,
        rate: String? = nil,
        volume: String? = nil
    ) {
        self.name = name
        self.model = model
        self.temperature = temperature
        self.customLexiconUrl = customLexiconUrl
        self.preferLocales = preferLocales
        self.locale = locale
        self.pitch = pitch
        self.rate = rate
        self.volume = volume
    }
}
