//
//  MemoryContextService.swift
//  reMIND Watch App
//
//  Fetches and caches memory context from the backend for injection into agent prompts.
//

import Foundation
import os

/// Response from the memory context API
struct MemoryContextResponse: Codable {
    let memories: [MemoryRecord]
    let formattedContext: String
    let retrievedAt: String
}

/// Individual memory record from the backend
struct MemoryRecord: Codable {
    let id: String
    let patientId: String
    let content: String
    let keywords: [String]?
    let contextDescription: String?
    let suggestedType: String?
    let suggestedCategories: [String]?
    let temporalRelevance: String?
    let eventDate: String?
    let emotionalTone: String?
    let confidence: Double
    let mentionCount: Int
    let isActive: Bool
}

/// Fetches and caches memory context for the agent
actor MemoryContextService {
    static let shared = MemoryContextService()

    private let baseURL: String
    private let patientId: String

    // Cache for memory context
    private var cachedContext: String?
    private var cacheTimestamp: Date?
    private let cacheValiditySeconds: TimeInterval = 24 * 60 * 60 // 24 hours

    init(
        baseURL: String = "http://localhost:3000",
        patientId: String = "demo-patient-1"
    ) {
        self.baseURL = baseURL
        self.patientId = patientId
    }

    /// Fetch greeting context for session initialization
    /// - Returns: Formatted memory context string or nil if fetch fails
    func fetchGreetingContext() async -> String? {
        return await fetchContext(sessionType: "greeting", query: nil)
    }

    /// Fetch context relevant to a specific query (for mid-conversation retrieval)
    /// - Parameter query: The topic or entity to search for
    /// - Returns: Formatted memory context string or nil if fetch fails
    func fetchRelevantContext(query: String) async -> String? {
        return await fetchContext(sessionType: "active", query: query)
    }

    /// Invalidate the cache (call when session ends or context may have changed)
    func invalidateCache() {
        cachedContext = nil
        cacheTimestamp = nil
        AppLogger.general.debug("Memory context cache invalidated")
    }

    /// Get cached context without fetching (for offline fallback)
    func getCachedContext() -> String? {
        return cachedContext
    }

    // MARK: - Private

    private func fetchContext(sessionType: String, query: String?) async -> String? {
        // Check cache first (only for greeting context without query)
        if sessionType == "greeting" && query == nil,
           let cached = cachedContext,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheValiditySeconds {
            AppLogger.general.debug("Using cached memory context")
            return cached
        }

        // Build URL with query parameters
        var urlComponents = URLComponents(string: "\(baseURL)/memory/context/\(patientId)")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "sessionType", value: sessionType)
        ]
        if let query = query {
            queryItems.append(URLQueryItem(name: "query", value: query))
        }
        urlComponents?.queryItems = queryItems

        guard let url = urlComponents?.url else {
            AppLogger.general.error("Invalid URL for memory context fetch")
            return cachedContext // Return cached as fallback
        }

        AppLogger.general.info("🔍 Fetching memory context from: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10 // Short timeout for responsiveness

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                AppLogger.general.warning("Invalid response from memory context API")
                return cachedContext
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                AppLogger.general.warning("Memory context API returned status \(httpResponse.statusCode)")
                return cachedContext
            }

            let contextResponse = try JSONDecoder().decode(MemoryContextResponse.self, from: data)

            // Update cache if this was a greeting context fetch
            if sessionType == "greeting" && query == nil {
                cachedContext = contextResponse.formattedContext
                cacheTimestamp = Date()
            }

            let memoryCount = contextResponse.memories.count
            AppLogger.general.info("Fetched memory context: \(memoryCount) memories, \(contextResponse.formattedContext.count) chars")

            return contextResponse.formattedContext.isEmpty ? nil : contextResponse.formattedContext

        } catch {
            AppLogger.general.error("❌ Memory context fetch failed for URL \(url.absoluteString): \(error.localizedDescription)")
            AppLogger.logError(error, category: AppLogger.general, context: "Failed to fetch memory context")
            return cachedContext // Return cached as fallback (graceful degradation)
        }
    }
}
