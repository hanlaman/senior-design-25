//
//  ConversationSyncService.swift
//  reMIND Watch App
//
//  Syncs completed conversation sessions to the backend API.
//

import Foundation
import os

actor ConversationSyncService {
    static let shared = ConversationSyncService()

    private let baseURL: String
    private let patientId: String
    private let historyManager: ConversationHistoryManager

    init(
        baseURL: String = BuildConfiguration.apiBaseURL,
        patientId: String = BuildConfiguration.patientId,
        historyManager: ConversationHistoryManager = .shared
    ) {
        self.baseURL = baseURL
        self.patientId = patientId
        self.historyManager = historyManager
    }

    /// Sync a completed session to the backend
    /// - Parameter session: The conversation session to sync
    /// - Returns: True if sync was successful or session was already synced
    func syncSession(_ session: ConversationSession) async -> Bool {
        // Only sync completed sessions
        guard let endTime = session.endTime else {
            AppLogger.general.warning("Cannot sync incomplete session: \(session.id)")
            return false
        }

        // Skip empty sessions and delete from local storage
        guard !session.messages.isEmpty else {
            AppLogger.general.debug("Skipping empty session: \(session.id), deleting from local storage")
            await MainActor.run {
                historyManager.deleteSession(session.id)
            }
            return true
        }

        let payload = ConversationUploadPayload(
            patientId: patientId,
            azureSessionId: session.id,
            startTime: ISO8601DateFormatter().string(from: session.startTime),
            endTime: ISO8601DateFormatter().string(from: endTime),
            messages: session.messages.enumerated().map { index, msg in
                ConversationMessagePayload(
                    azureItemId: msg.id,
                    role: msg.role.rawValue,
                    content: msg.content,
                    timestamp: ISO8601DateFormatter().string(from: msg.timestamp),
                    sequenceNumber: index
                )
            }
        )

        guard let url = URL(string: "\(baseURL)/conversations") else {
            AppLogger.general.error("Invalid URL for conversation sync")
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(payload)
        } catch {
            AppLogger.logError(error, category: AppLogger.general, context: "Failed to encode conversation payload")
            return false
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    // Try to parse response for session ID
                    if let responseData = try? JSONDecoder().decode(SyncResponse.self, from: data) {
                        AppLogger.general.info("Synced session \(session.id) to server (serverSessionId: \(responseData.sessionId ?? "unknown"), duplicate: \(responseData.duplicate ?? false))")
                    } else {
                        AppLogger.general.info("Synced session \(session.id) to server")
                    }

                    // Clear from local storage after successful sync
                    await MainActor.run {
                        historyManager.deleteSession(session.id)
                    }
                    AppLogger.general.debug("Cleared session \(session.id) from local storage")

                    return true
                } else {
                    AppLogger.general.warning("Conversation sync failed with status \(httpResponse.statusCode)")
                    return false
                }
            }
            return false
        } catch {
            AppLogger.logError(error, category: AppLogger.general, context: "Failed to sync conversation session")
            return false
        }
    }
}

// MARK: - Payload Types

private struct ConversationUploadPayload: Encodable {
    let patientId: String
    let azureSessionId: String
    let startTime: String
    let endTime: String
    let messages: [ConversationMessagePayload]
}

private struct ConversationMessagePayload: Encodable {
    let azureItemId: String
    let role: String
    let content: String
    let timestamp: String
    let sequenceNumber: Int
}

private struct SyncResponse: Decodable {
    let success: Bool?
    let sessionId: String?
    let duplicate: Bool?
}
