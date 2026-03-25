//
//  ToolExecutors.swift
//  reMIND Watch App
//
//  Static methods for executing function tools
//

import Foundation
import os

/// Namespace for tool executor implementations
public enum ToolExecutors {

    // MARK: - Shared State for Hidden Tools

    /// Reference to the transcription provider (set by VoiceViewModel)
    @MainActor
    public static weak var transcriptionProvider: TranscriptionProvider?

    // MARK: - Get Current Time Tool

    /// Get the current local time in a human-readable format
    /// - Parameter arguments: JSON string containing function arguments (unused for this tool)
    /// - Returns: JSON string with current time: {"current_time": "..."}
    /// - Throws: ToolError if execution fails
    public static func getCurrentTime(arguments: String) async throws -> String {
        do {
            // Create formatter for current locale
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
            formatter.locale = Locale.current

            // Get current time
            let now = Date()
            let timeString = formatter.string(from: now)

            // Create result dictionary
            let result: [String: String] = ["current_time": timeString]

            // Encode to JSON
            let jsonData = try JSONEncoder().encode(result)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw ToolError.executionFailed("Failed to encode result as UTF-8")
            }

            AppLogger.general.info("getCurrentTime executed: \(timeString)")
            return jsonString

        } catch let error as ToolError {
            throw error
        } catch {
            throw ToolError.executionFailed("Failed to get current time: \(error.localizedDescription)")
        }
    }

    // MARK: - Get Session Transcript Tool

    /// Get the transcript of the current voice session
    /// - Parameter arguments: JSON string with optional "max_messages"
    /// - Returns: JSON string with transcript array
    @MainActor
    public static func getSessionTranscript(arguments: String) async throws -> String {
        // Parse arguments
        var maxMessages: Int?

        if !arguments.isEmpty, let data = arguments.data(using: .utf8) {
            if let args = try? JSONDecoder().decode(TranscriptArguments.self, from: data) {
                maxMessages = args.maxMessages
            }
        }

        // Get transcript from provider
        guard let provider = transcriptionProvider else {
            AppLogger.general.warning("TranscriptionProvider not set for getSessionTranscript")
            return "{\"error\": \"Transcript service not available\", \"messages\": []}"
        }

        var messages = provider.getTranscriptMessages()

        // Apply max_messages limit if specified
        if let max = maxMessages, max > 0, messages.count > max {
            messages = Array(messages.suffix(max))
        }

        // Build response
        let response = TranscriptResponse(
            messageCount: messages.count,
            messages: messages.map { entry in
                TranscriptMessageOutput(
                    role: entry.role,
                    text: entry.text,
                    order: entry.sequenceNumber
                )
            }
        )

        let jsonData = try JSONEncoder().encode(response)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw ToolError.executionFailed("Failed to encode transcript as UTF-8")
        }

        AppLogger.general.info("getSessionTranscript executed: returned \(messages.count) messages")
        return jsonString
    }

    // MARK: - Get User Memories Tool

    /// Fetch relevant memories about the user based on a query
    /// - Parameter arguments: JSON string with "query" field
    /// - Returns: JSON string with relevant memories
    public static func getUserMemories(arguments: String) async throws -> String {
        // Parse arguments
        var query: String?

        if !arguments.isEmpty, let data = arguments.data(using: .utf8) {
            if let args = try? JSONDecoder().decode(MemoriesArguments.self, from: data) {
                query = args.query
            }
        }

        guard let queryString = query, !queryString.isEmpty else {
            return "{\"error\": \"Missing required 'query' argument\", \"memories\": []}"
        }

        // Fetch memories from service
        let memoryContext = await MemoryContextService.shared.fetchRelevantContext(query: queryString)

        if let context = memoryContext, !context.isEmpty {
            let response = MemoriesResponse(
                query: queryString,
                found: true,
                context: context
            )

            let jsonData = try JSONEncoder().encode(response)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw ToolError.executionFailed("Failed to encode memories as UTF-8")
            }

            AppLogger.general.info("getUserMemories executed: found context for '\(queryString)'")
            return jsonString
        } else {
            let response = MemoriesResponse(
                query: queryString,
                found: false,
                context: "No relevant memories found for '\(queryString)'"
            )

            let jsonData = try JSONEncoder().encode(response)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw ToolError.executionFailed("Failed to encode memories as UTF-8")
            }

            AppLogger.general.info("getUserMemories executed: no memories found for '\(queryString)'")
            return jsonString
        }
    }

    // MARK: - Future Tool Executors

    // Future tool implementations will be added here as static methods
}

// MARK: - Supporting Types for Get User Memories

private struct MemoriesArguments: Codable {
    let query: String?
}

private struct MemoriesResponse: Codable {
    let query: String
    let found: Bool
    let context: String
}

// MARK: - Supporting Types for Get Session Transcript

private struct TranscriptArguments: Codable {
    let maxMessages: Int?

    enum CodingKeys: String, CodingKey {
        case maxMessages = "max_messages"
    }
}

private struct TranscriptResponse: Codable {
    let messageCount: Int
    let messages: [TranscriptMessageOutput]

    enum CodingKeys: String, CodingKey {
        case messageCount = "message_count"
        case messages
    }
}

private struct TranscriptMessageOutput: Codable {
    let role: String
    let text: String
    let order: Int
}
