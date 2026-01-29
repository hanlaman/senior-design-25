//
//  AzureConversationModels.swift
//  reMIND Watch App
//
//  Conversation models from Azure Voice Live API specification
//  Includes RealtimeContentPart and RealtimeConversationItem unions
//

import Foundation

// MARK: - RealtimeContentPart (Union Type)

enum RealtimeContentPart: Codable, Sendable {
    case inputText(RealtimeInputTextContentPart)
    case outputText(RealtimeOutputTextContentPart)
    case inputAudio(RealtimeInputAudioContentPart)
    case outputAudio(RealtimeOutputAudioContentPart)
    case responseAudio(RealtimeResponseAudioContentPart)

    enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "input_text":
            self = .inputText(try RealtimeInputTextContentPart(from: decoder))
        case "text":
            // Could be either output text or response audio - check for audio field
            if let outputText = try? RealtimeOutputTextContentPart(from: decoder) {
                self = .outputText(outputText)
            } else {
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Failed to decode text content part"
                )
            }
        case "input_audio":
            self = .inputAudio(try RealtimeInputAudioContentPart(from: decoder))
        case "audio":
            // Could be either output audio or response audio
            if let outputAudio = try? RealtimeOutputAudioContentPart(from: decoder) {
                self = .outputAudio(outputAudio)
            } else {
                self = .responseAudio(try RealtimeResponseAudioContentPart(from: decoder))
            }
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown content part type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .inputText(let part):
            try part.encode(to: encoder)
        case .outputText(let part):
            try part.encode(to: encoder)
        case .inputAudio(let part):
            try part.encode(to: encoder)
        case .outputAudio(let part):
            try part.encode(to: encoder)
        case .responseAudio(let part):
            try part.encode(to: encoder)
        }
    }

    var type: String {
        switch self {
        case .inputText(let part): return part.type
        case .outputText(let part): return part.type
        case .inputAudio(let part): return part.type
        case .outputAudio(let part): return part.type
        case .responseAudio(let part): return part.type
        }
    }
}

// MARK: - Content Part Types

struct RealtimeInputTextContentPart: Codable, Sendable {
    let type: String = "input_text"
    let text: String

    enum CodingKeys: String, CodingKey {
        case type
        case text
    }

    init(text: String) {
        self.text = text
    }
}

struct RealtimeOutputTextContentPart: Codable, Sendable {
    let type: String = "text"
    let text: String

    enum CodingKeys: String, CodingKey {
        case type
        case text
    }

    init(text: String) {
        self.text = text
    }
}

struct RealtimeInputAudioContentPart: Codable, Sendable {
    let type: String = "input_audio"
    let audio: String?
    let transcript: String?

    enum CodingKeys: String, CodingKey {
        case type
        case audio
        case transcript
    }

    init(audio: String? = nil, transcript: String? = nil) {
        self.audio = audio
        self.transcript = transcript
    }
}

struct RealtimeOutputAudioContentPart: Codable, Sendable {
    let type: String = "audio"
    let audio: String
    let transcript: String?

    enum CodingKeys: String, CodingKey {
        case type
        case audio
        case transcript
    }

    init(audio: String, transcript: String? = nil) {
        self.audio = audio
        self.transcript = transcript
    }
}

struct RealtimeResponseAudioContentPart: Codable, Sendable {
    let type: String = "audio"
    let transcript: String?

    enum CodingKeys: String, CodingKey {
        case type
        case transcript
    }

    init(transcript: String? = nil) {
        self.transcript = transcript
    }
}

// MARK: - RealtimeConversationRequestItem (Union Type)

enum RealtimeConversationRequestItem: Codable, Sendable {
    case systemMessage(RealtimeSystemMessageRequestItem)
    case userMessage(RealtimeUserMessageRequestItem)
    case assistantMessage(RealtimeAssistantMessageRequestItem)
    case functionCall(RealtimeFunctionCallRequestItem)
    case functionCallOutput(RealtimeFunctionCallOutputRequestItem)
    case mcpApprovalResponse(RealtimeMCPApprovalResponseRequestItem)

    enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "message":
            // Need to check role to determine which message type
            enum RoleKey: String, CodingKey {
                case role
            }
            let roleContainer = try decoder.container(keyedBy: RoleKey.self)
            let role = try roleContainer.decode(String.self, forKey: .role)

            switch role {
            case "system":
                self = .systemMessage(try RealtimeSystemMessageRequestItem(from: decoder))
            case "user":
                self = .userMessage(try RealtimeUserMessageRequestItem(from: decoder))
            case "assistant":
                self = .assistantMessage(try RealtimeAssistantMessageRequestItem(from: decoder))
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: RoleKey.role,
                    in: roleContainer,
                    debugDescription: "Unknown message role: \(role)"
                )
            }
        case "function_call":
            self = .functionCall(try RealtimeFunctionCallRequestItem(from: decoder))
        case "function_call_output":
            self = .functionCallOutput(try RealtimeFunctionCallOutputRequestItem(from: decoder))
        case "mcp_approval_response":
            self = .mcpApprovalResponse(try RealtimeMCPApprovalResponseRequestItem(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown conversation request item type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .systemMessage(let item):
            try item.encode(to: encoder)
        case .userMessage(let item):
            try item.encode(to: encoder)
        case .assistantMessage(let item):
            try item.encode(to: encoder)
        case .functionCall(let item):
            try item.encode(to: encoder)
        case .functionCallOutput(let item):
            try item.encode(to: encoder)
        case .mcpApprovalResponse(let item):
            try item.encode(to: encoder)
        }
    }
}

// MARK: - Request Item Types

struct RealtimeSystemMessageRequestItem: Codable, Sendable {
    let type: String = "message"
    let role: String = "system"
    let content: [RealtimeInputTextContentPart]
    let id: String?

    enum CodingKeys: String, CodingKey {
        case type
        case role
        case content
        case id
    }

    init(content: [RealtimeInputTextContentPart], id: String? = nil) {
        self.content = content
        self.id = id
    }
}

struct RealtimeUserMessageRequestItem: Codable, Sendable {
    let type: String = "message"
    let role: String = "user"
    let content: [RealtimeContentPart]
    let id: String?

    enum CodingKeys: String, CodingKey {
        case type
        case role
        case content
        case id
    }

    init(content: [RealtimeContentPart], id: String? = nil) {
        self.content = content
        self.id = id
    }
}

struct RealtimeAssistantMessageRequestItem: Codable, Sendable {
    let type: String = "message"
    let role: String = "assistant"
    let content: [RealtimeOutputTextContentPart]

    enum CodingKeys: String, CodingKey {
        case type
        case role
        case content
    }

    init(content: [RealtimeOutputTextContentPart]) {
        self.content = content
    }
}

struct RealtimeFunctionCallRequestItem: Codable, Sendable {
    let type: String = "function_call"
    let name: String
    let arguments: String
    let callId: String
    let id: String?

    enum CodingKeys: String, CodingKey {
        case type
        case name
        case arguments
        case callId = "call_id"
        case id
    }

    init(name: String, arguments: String, callId: String, id: String? = nil) {
        self.name = name
        self.arguments = arguments
        self.callId = callId
        self.id = id
    }
}

struct RealtimeFunctionCallOutputRequestItem: Codable, Sendable {
    let type: String = "function_call_output"
    let callId: String
    let output: String
    let id: String?

    enum CodingKeys: String, CodingKey {
        case type
        case callId = "call_id"
        case output
        case id
    }

    init(callId: String, output: String, id: String? = nil) {
        self.callId = callId
        self.output = output
        self.id = id
    }
}

struct RealtimeMCPApprovalResponseRequestItem: Codable, Sendable {
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

// MARK: - RealtimeConversationResponseItem (Union Type)

enum RealtimeConversationResponseItem: Codable, Sendable {
    case userMessage(RealtimeConversationUserMessageItem)
    case assistantMessage(RealtimeConversationAssistantMessageItem)
    case systemMessage(RealtimeConversationSystemMessageItem)
    case functionCall(RealtimeConversationFunctionCallItem)
    case functionCallOutput(RealtimeConversationFunctionCallOutputItem)
    case mcpListTools(RealtimeConversationMCPListToolsItem)
    case mcpCall(RealtimeConversationMCPCallItem)
    case mcpApprovalRequest(RealtimeConversationMCPApprovalRequestItem)

    enum CodingKeys: String, CodingKey {
        case type
        case role
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "message":
            let role = try container.decode(String.self, forKey: .role)
            switch role {
            case "user":
                self = .userMessage(try RealtimeConversationUserMessageItem(from: decoder))
            case "assistant":
                self = .assistantMessage(try RealtimeConversationAssistantMessageItem(from: decoder))
            case "system":
                self = .systemMessage(try RealtimeConversationSystemMessageItem(from: decoder))
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .role,
                    in: container,
                    debugDescription: "Unknown message role: \(role)"
                )
            }
        case "function_call":
            self = .functionCall(try RealtimeConversationFunctionCallItem(from: decoder))
        case "function_call_output":
            self = .functionCallOutput(try RealtimeConversationFunctionCallOutputItem(from: decoder))
        case "mcp_list_tools":
            self = .mcpListTools(try RealtimeConversationMCPListToolsItem(from: decoder))
        case "mcp_call":
            self = .mcpCall(try RealtimeConversationMCPCallItem(from: decoder))
        case "mcp_approval_request":
            self = .mcpApprovalRequest(try RealtimeConversationMCPApprovalRequestItem(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown conversation response item type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .userMessage(let item):
            try item.encode(to: encoder)
        case .assistantMessage(let item):
            try item.encode(to: encoder)
        case .systemMessage(let item):
            try item.encode(to: encoder)
        case .functionCall(let item):
            try item.encode(to: encoder)
        case .functionCallOutput(let item):
            try item.encode(to: encoder)
        case .mcpListTools(let item):
            try item.encode(to: encoder)
        case .mcpCall(let item):
            try item.encode(to: encoder)
        case .mcpApprovalRequest(let item):
            try item.encode(to: encoder)
        }
    }

    var id: String {
        switch self {
        case .userMessage(let item): return item.id
        case .assistantMessage(let item): return item.id
        case .systemMessage(let item): return item.id
        case .functionCall(let item): return item.id
        case .functionCallOutput(let item): return item.id
        case .mcpListTools(let item): return item.id
        case .mcpCall(let item): return item.id
        case .mcpApprovalRequest(let item): return item.id
        }
    }

    var type: String {
        switch self {
        case .userMessage(let item): return item.type
        case .assistantMessage(let item): return item.type
        case .systemMessage(let item): return item.type
        case .functionCall(let item): return item.type
        case .functionCallOutput(let item): return item.type
        case .mcpListTools(let item): return item.type
        case .mcpCall(let item): return item.type
        case .mcpApprovalRequest(let item): return item.type
        }
    }
}

// MARK: - Response Item Types

struct RealtimeConversationUserMessageItem: Codable, Sendable {
    let id: String
    let type: String
    let object: String
    let role: String
    let content: [RealtimeContentPart]
    let status: RealtimeItemStatus

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case object
        case role
        case content
        case status
    }
}

struct RealtimeConversationAssistantMessageItem: Codable, Sendable {
    let id: String
    let type: String
    let object: String
    let role: String
    let content: [RealtimeContentPart]
    let status: RealtimeItemStatus

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case object
        case role
        case content
        case status
    }
}

struct RealtimeConversationSystemMessageItem: Codable, Sendable {
    let id: String
    let type: String
    let object: String
    let role: String
    let content: [RealtimeInputTextContentPart]
    let status: RealtimeItemStatus

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case object
        case role
        case content
        case status
    }
}

struct RealtimeConversationFunctionCallItem: Codable, Sendable {
    let id: String
    let type: String
    let object: String
    let name: String
    let arguments: String
    let callId: String
    let status: RealtimeItemStatus

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case object
        case name
        case arguments
        case callId = "call_id"
        case status
    }
}

struct RealtimeConversationFunctionCallOutputItem: Codable, Sendable {
    let id: String
    let type: String
    let object: String
    let name: String
    let output: String
    let callId: String
    let status: RealtimeItemStatus

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case object
        case name
        case output
        case callId = "call_id"
        case status
    }
}

struct RealtimeConversationMCPListToolsItem: Codable, Sendable {
    let id: String
    let type: String
    let serverLabel: String

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case serverLabel = "server_label"
    }
}

struct RealtimeConversationMCPCallItem: Codable, Sendable {
    let id: String
    let type: String
    let serverLabel: String
    let name: String
    let approvalRequestId: String?
    let arguments: String
    let output: String?
    let error: AnyCodable?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case serverLabel = "server_label"
        case name
        case approvalRequestId = "approval_request_id"
        case arguments
        case output
        case error
    }
}

struct RealtimeConversationMCPApprovalRequestItem: Codable, Sendable {
    let id: String
    let type: String
    let serverLabel: String
    let name: String
    let arguments: String

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case serverLabel = "server_label"
        case name
        case arguments
    }
}
