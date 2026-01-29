//
//  AzureToolModels.swift
//  reMIND Watch App
//
//  Tool configuration models from Azure Voice Live API specification
//  RealtimeTool is a discriminated union
//

import Foundation

// MARK: - RealtimeTool (Union Type)

enum RealtimeTool: Codable, Sendable {
    case function(RealtimeFunctionTool)
    case mcp(RealtimeMCPTool)

    enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "function":
            self = .function(try RealtimeFunctionTool(from: decoder))
        case "mcp":
            self = .mcp(try RealtimeMCPTool(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown tool type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .function(let tool):
            try tool.encode(to: encoder)
        case .mcp(let tool):
            try tool.encode(to: encoder)
        }
    }
}

// MARK: - Function Tool

struct RealtimeFunctionTool: Codable, Sendable {
    let type: String = "function"
    let name: String
    let description: String
    let parameters: [String: AnyCodable]

    enum CodingKeys: String, CodingKey {
        case type
        case name
        case description
        case parameters
    }

    init(
        name: String,
        description: String,
        parameters: [String: AnyCodable]
    ) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

// MARK: - MCP Tool

struct RealtimeMCPTool: Codable, Sendable {
    let type: String = "mcp"
    let serverLabel: String
    let serverUrl: String
    let allowedTools: [String]?
    let headers: [String: String]?
    let authorization: String?
    let requireApproval: RequireApproval?

    enum CodingKeys: String, CodingKey {
        case type
        case serverLabel = "server_label"
        case serverUrl = "server_url"
        case allowedTools = "allowed_tools"
        case headers
        case authorization
        case requireApproval = "require_approval"
    }

    init(
        serverLabel: String,
        serverUrl: String,
        allowedTools: [String]? = nil,
        headers: [String: String]? = nil,
        authorization: String? = nil,
        requireApproval: RequireApproval? = nil
    ) {
        self.serverLabel = serverLabel
        self.serverUrl = serverUrl
        self.allowedTools = allowedTools
        self.headers = headers
        self.authorization = authorization
        self.requireApproval = requireApproval
    }
}

// MARK: - Require Approval

enum RequireApproval: Codable, Sendable {
    case string(String)
    case detailed(RequireApprovalDetailed)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let detailed = try? container.decode(RequireApprovalDetailed.self) {
            self = .detailed(detailed)
        } else {
            throw DecodingError.typeMismatch(
                RequireApproval.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected String or RequireApprovalDetailed"
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .detailed(let value):
            try container.encode(value)
        }
    }
}

struct RequireApprovalDetailed: Codable, Sendable {
    let never: [String]
    let always: [String]

    enum CodingKeys: String, CodingKey {
        case never
        case always
    }

    init(never: [String], always: [String]) {
        self.never = never
        self.always = always
    }
}

// MARK: - Tool Choice

enum RealtimeToolChoice: Codable, Sendable {
    case string(String)
    case function(RealtimeToolChoiceFunction)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let functionChoice = try? container.decode(RealtimeToolChoiceFunction.self) {
            self = .function(functionChoice)
        } else {
            throw DecodingError.typeMismatch(
                RealtimeToolChoice.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected String or RealtimeToolChoiceFunction"
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .function(let value):
            try container.encode(value)
        }
    }
}

struct RealtimeToolChoiceFunction: Codable, Sendable {
    let type: String = "function"
    let name: String

    enum CodingKeys: String, CodingKey {
        case type
        case name
    }

    init(name: String) {
        self.name = name
    }
}
