//
//  AzureCommonTypes.swift
//  reMIND Watch App
//
//  Common types and enums from Azure Voice Live API specification
//

import Foundation

// MARK: - Enumerations

enum RealtimeItemStatus: String, Codable, Sendable {
    case inProgress = "in_progress"
    case completed = "completed"
    case incomplete = "incomplete"
}

enum RealtimeResponseStatus: String, Codable, Sendable {
    case inProgress = "in_progress"
    case completed = "completed"
    case cancelled = "cancelled"
    case incomplete = "incomplete"
    case failed = "failed"
}

enum RealtimeModality: String, Codable, Sendable {
    case text = "text"
    case audio = "audio"
    case animation = "animation"
    case avatar = "avatar"
}

enum RealtimeAudioFormat: String, Codable, Sendable {
    case pcm16 = "pcm16"
    case g711Ulaw = "g711_ulaw"
    case g711Alaw = "g711_alaw"
}

enum RealtimeOutputAudioFormat: String, Codable, Sendable {
    case pcm16 = "pcm16"
    case pcm16_8000hz = "pcm16_8000hz"
    case pcm16_16000hz = "pcm16_16000hz"
    case g711Ulaw = "g711_ulaw"
    case g711Alaw = "g711_alaw"
}

enum RealtimeAudioTimestampType: String, Codable, Sendable {
    case word = "word"
}

enum RealtimeAnimationOutputType: String, Codable, Sendable {
    case blendshapes = "blendshapes"
    case visemeId = "viseme_id"
}

// MARK: - Max Output Tokens

enum MaxOutputTokens: Codable, Sendable, Equatable {
    case integer(Int)
    case inf

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .integer(intValue)
        } else if let stringValue = try? container.decode(String.self), stringValue == "inf" {
            self = .inf
        } else {
            throw DecodingError.typeMismatch(
                MaxOutputTokens.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected Int or 'inf'"
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .integer(let value):
            try container.encode(value)
        case .inf:
            try container.encode("inf")
        }
    }
}

// MARK: - Helper for Arbitrary JSON

struct AnyCodable: Codable, Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported type"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Unsupported type"
                )
            )
        }
    }
}

// MARK: - Connection State

enum ConnectionState: Sendable, Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)

    var displayText: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}
