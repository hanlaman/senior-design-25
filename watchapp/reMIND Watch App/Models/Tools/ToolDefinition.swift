//
//  ToolDefinition.swift
//  reMIND Watch App
//
//  Tool definition system for Azure Voice Live function calling
//

import Foundation

// MARK: - Toolset

/// A group of related tools for organization
public struct Toolset: Identifiable, Sendable {
    public let id: String     // e.g., "Utilities" (display-friendly)
    public let icon: String?  // Optional SF Symbol name

    public init(id: String, icon: String? = nil) {
        self.id = id
        self.icon = icon
    }
}

// MARK: - ToolHandler Enum

/// Enum mapping tool names to their implementations
public enum ToolHandler: String, Codable, Sendable {
    case getCurrentTime
    case getSessionTranscript
    case getUserMemories
    case getPatientFacts

    /// Execute the tool with given arguments
    /// - Parameter arguments: JSON string containing function arguments
    /// - Returns: JSON string containing function result
    func execute(arguments: String) async throws -> String {
        switch self {
        case .getCurrentTime:
            return try await ToolExecutors.getCurrentTime(arguments: arguments)
        case .getSessionTranscript:
            return try await ToolExecutors.getSessionTranscript(arguments: arguments)
        case .getUserMemories:
            return try await ToolExecutors.getUserMemories(arguments: arguments)
        case .getPatientFacts:
            return try await ToolExecutors.getPatientFacts(arguments: arguments)
        }
    }
}

// MARK: - LocalFunctionTool

/// Definition of a local function tool that can be executed by the assistant
public struct LocalFunctionTool: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String              // Azure function name (e.g., "get_current_time")
    public let description: String       // Full description for LLM
    public let displayName: String       // UI name (e.g., "Current Time")
    public let shortDescription: String  // Brief UI description (e.g., "Get the time")
    public let toolsetId: String         // Group identifier (e.g., "utilities")
    public var isEnabled: Bool
    public let isHidden: Bool            // Hidden tools are always enabled and not shown in UI
    public let parameters: [String: AnyCodable]
    public let handler: ToolHandler

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case displayName
        case shortDescription
        case toolsetId
        case isEnabled
        case isHidden
        case parameters
        case handler
    }

    public init(
        id: String,
        name: String,
        description: String,
        displayName: String,
        shortDescription: String,
        toolsetId: String,
        isEnabled: Bool,
        isHidden: Bool = false,
        parameters: [String: AnyCodable],
        handler: ToolHandler
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.displayName = displayName
        self.shortDescription = shortDescription
        self.toolsetId = toolsetId
        self.isEnabled = isEnabled
        self.isHidden = isHidden
        self.parameters = parameters
        self.handler = handler
    }

    /// Convert this tool to Azure API format
    public func toRealtimeTool() -> RealtimeTool {
        return .function(RealtimeFunctionTool(
            name: name,
            description: description,
            parameters: parameters
        ))
    }

    /// Execute the function with given arguments
    /// - Parameter arguments: JSON string containing function arguments
    /// - Returns: JSON string containing function result
    public func execute(arguments: String) async throws -> String {
        return try await handler.execute(arguments: arguments)
    }
}

// MARK: - Tool Errors

public enum ToolError: LocalizedError, Sendable {
    case executionFailed(String)
    case invalidArguments(String)
    case toolNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .executionFailed(let message):
            return "Tool execution failed: \(message)"
        case .invalidArguments(let message):
            return "Invalid arguments: \(message)"
        case .toolNotFound(let name):
            return "Tool not found: \(name)"
        }
    }
}
