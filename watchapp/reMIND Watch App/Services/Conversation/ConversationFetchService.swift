//
//  ConversationFetchService.swift
//  reMIND Watch App
//
//  Fetches conversation history from the backend API.
//

import Foundation
import os

actor ConversationFetchService {
    static let shared = ConversationFetchService()

    private let baseURL: String
    private let patientId: String

    init(
        baseURL: String = "http://localhost:3000",
        patientId: String = "demo-patient-1"
    ) {
        self.baseURL = baseURL
        self.patientId = patientId
    }

    /// Fetch list of conversation sessions from backend
    func fetchSessions() async throws -> [ServerConversationSession] {
        guard let url = URL(string: "\(baseURL)/conversations/\(patientId)") else {
            throw ConversationFetchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ConversationFetchError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            AppLogger.general.warning("Fetch sessions failed with status \(httpResponse.statusCode)")
            throw ConversationFetchError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let result = try decoder.decode(SessionListResponse.self, from: data)
        AppLogger.general.info("Fetched \(result.sessions.count) sessions from server")
        return result.sessions
    }

    /// Fetch a single session with all messages from backend
    func fetchSession(sessionId: String) async throws -> ServerConversationSessionDetail {
        guard let url = URL(string: "\(baseURL)/conversations/\(patientId)/\(sessionId)") else {
            throw ConversationFetchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ConversationFetchError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            AppLogger.general.warning("Fetch session detail failed with status \(httpResponse.statusCode)")
            throw ConversationFetchError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let session = try decoder.decode(ServerConversationSessionDetail.self, from: data)
        AppLogger.general.info("Fetched session \(sessionId) with \(session.messages.count) messages")
        return session
    }

    /// Delete a conversation session from the backend
    func deleteSession(sessionId: String) async throws {
        guard let url = URL(string: "\(baseURL)/conversations/\(sessionId)") else {
            throw ConversationFetchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 15

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ConversationFetchError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            AppLogger.general.warning("Delete session failed with status \(httpResponse.statusCode)")
            throw ConversationFetchError.httpError(httpResponse.statusCode)
        }

        AppLogger.general.info("Deleted session \(sessionId) from server")
    }
}

// MARK: - Error Types

enum ConversationFetchError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "Server error: \(code)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}

// MARK: - Response Types

struct SessionListResponse: Decodable {
    let sessions: [ServerConversationSession]
    let pagination: Pagination

    struct Pagination: Decodable {
        let page: Int
        let pageSize: Int
        let total: Int
    }
}

struct ServerConversationSession: Decodable, Identifiable {
    let id: String
    let startTime: Date
    let endTime: Date?
    let messageCount: Int
    let preview: String

    /// Display text for session (relative time)
    var displayText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: startTime, relativeTo: Date())
    }
}

struct ServerConversationSessionDetail: Decodable, Identifiable {
    let id: String
    let startTime: Date
    let endTime: Date?
    let messageCount: Int
    let summary: String?
    let summarizedAt: Date?
    let messages: [ServerConversationMessage]
}

struct ServerConversationMessage: Decodable, Identifiable {
    let id: String
    let azureItemId: String
    let role: String
    let content: String
    let timestamp: Date
    let sequenceNumber: Int

    var messageRole: ConversationMessage.MessageRole {
        role == "user" ? .user : .assistant
    }
}
