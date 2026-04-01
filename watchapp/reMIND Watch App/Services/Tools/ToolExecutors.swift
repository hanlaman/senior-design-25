//
//  ToolExecutors.swift
//  reMIND Watch App
//
//  Static methods for executing function tools
//

import CoreLocation
import Foundation
import os

/// Namespace for tool executor implementations
public enum ToolExecutors {

    // MARK: - Shared State for Hidden Tools

    /// Reference to the transcription provider (set by VoiceViewModel)
    @MainActor
    public static weak var transcriptionProvider: TranscriptionProvider?

    /// Reference to the location service (set by LocationViewModel)
    static var locationService: LocationService?

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

    // MARK: - Get Patient Facts Tool

    /// Fetch the latest caregiver-provided patient facts from the backend
    /// - Parameter arguments: JSON string (no arguments required)
    /// - Returns: JSON string with patient facts
    public static func getPatientFacts(arguments: String) async throws -> String {
        let facts = await PatientFactsFetcher.shared.fetchFacts()

        let response = PatientFactsResponse(
            found: !facts.isEmpty,
            factCount: facts.count,
            facts: facts
        )

        let jsonData = try JSONEncoder().encode(response)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw ToolError.executionFailed("Failed to encode patient facts as UTF-8")
        }

        AppLogger.general.info("getPatientFacts executed: \(facts.count) facts returned")
        return jsonString
    }

<<<<<<< Updated upstream
=======
// MARK: - Supporting Types for Get Patient Facts

private struct PatientFactsResponse: Codable {
    let found: Bool
    let factCount: Int
    let facts: [PatientFactEntry]

    enum CodingKeys: String, CodingKey {
        case found
        case factCount = "fact_count"
        case facts
    }
}

struct PatientFactEntry: Codable {
    let category: String
    let label: String
    let value: String
}

/// Lightweight fetcher for patient facts from the backend API
actor PatientFactsFetcher {
    static let shared = PatientFactsFetcher()

    private let baseURL: String
    private let patientId: String

    init(
        baseURL: String = "http://localhost:3000",
        patientId: String = "demo-patient-1"
    ) {
        self.baseURL = baseURL
        self.patientId = patientId
    }

    func fetchFacts() async -> [PatientFactEntry] {
        guard let url = URL(string: "\(baseURL)/patient-facts/\(patientId)") else {
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return []
            }
            let rawFacts = try JSONDecoder().decode([RawPatientFact].self, from: data)
            return rawFacts.map { PatientFactEntry(category: $0.category, label: $0.label, value: $0.value) }
        } catch {
            AppLogger.general.error("Failed to fetch patient facts: \(error.localizedDescription)")
            return []
        }
    }
}

extension ToolExecutors {
>>>>>>> Stashed changes
    // MARK: - Get Current Location Tool

    /// Get the user's current location in a human-friendly format
    /// - Parameter arguments: JSON string (unused — no parameters)
    /// - Returns: JSON string with place description, safe zone status, and nearby zones
    public static func getCurrentLocation(arguments: String) async throws -> String {
        // 1. Get current device location
        guard let service = locationService else {
            throw ToolError.executionFailed("Location service not available")
        }

        guard let location = await service.lastLocation else {
            return "{\"error\": \"Location not available yet. Location tracking may still be starting up.\"}"
        }

        // 2. Reverse geocode for a human-friendly place name
        let placeDescription = await reverseGeocode(location: location)

        // 3. Fetch safe zone context from backend
        let zoneContext = await fetchLocationContext()

        // 4. Build response
        var response = LocationResponse(
            placeDescription: placeDescription,
            safeZone: nil,
            safeZoneStatus: "unknown",
            nearbyZones: []
        )

        if let context = zoneContext {
            if let inside = context.insideZone {
                response.safeZone = inside.name
                response.safeZoneStatus = "inside"
            } else {
                response.safeZoneStatus = "outside_all_zones"
            }

            response.nearbyZones = context.nearbyZones.map { zone in
                let walkingMinutes = max(1, Int(round(Double(zone.distance) / 80.0)))
                let distanceDescription: String
                if walkingMinutes <= 1 {
                    distanceDescription = "about a minute walk away"
                } else {
                    distanceDescription = "about \(walkingMinutes) minutes walk away"
                }
                return NearbyZoneOutput(name: zone.name, distanceDescription: distanceDescription)
            }
        }

        let jsonData = try JSONEncoder().encode(response)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw ToolError.executionFailed("Failed to encode location as UTF-8")
        }

        AppLogger.general.info("getCurrentLocation executed: \(placeDescription ?? "unknown place"), zone: \(response.safeZone ?? "none")")
        return jsonString
    }

    // MARK: - Location Helpers

    private static func reverseGeocode(location: CLLocation) async -> String? {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }

            var parts: [String] = []
            if let name = placemark.name { parts.append(name) }
            if let locality = placemark.locality, !parts.contains(locality) { parts.append(locality) }

            return parts.isEmpty ? nil : parts.joined(separator: ", ")
        } catch {
            AppLogger.general.warning("Reverse geocoding failed: \(error.localizedDescription)")
            return nil
        }
    }

    private static func fetchLocationContext() async -> LocationContextResponse? {
        let baseURL = BuildConfiguration.apiBaseURL
        let patientId = BuildConfiguration.patientId

        guard let url = URL(string: "\(baseURL)/location/context/\(patientId)") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else { return nil }
            return try JSONDecoder().decode(LocationContextResponse.self, from: data)
        } catch {
            AppLogger.general.warning("Location context fetch failed: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Supporting Types for Get Patient Facts

private struct PatientFactsResponse: Codable {
    let found: Bool
    let factCount: Int
    let facts: [PatientFactEntry]

    enum CodingKeys: String, CodingKey {
        case found
        case factCount = "fact_count"
        case facts
    }
}

struct PatientFactEntry: Codable {
    let category: String
    let label: String
    let value: String
}

/// Lightweight fetcher for patient facts from the backend API
actor PatientFactsFetcher {
    static let shared = PatientFactsFetcher()

    private let baseURL: String
    private let patientId: String

    init(
        baseURL: String = BuildConfiguration.apiBaseURL,
        patientId: String = BuildConfiguration.patientId
    ) {
        self.baseURL = baseURL
        self.patientId = patientId
    }

    func fetchFacts() async -> [PatientFactEntry] {
        guard let url = URL(string: "\(baseURL)/patient-facts/\(patientId)") else {
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return []
            }
            let rawFacts = try JSONDecoder().decode([RawPatientFact].self, from: data)
            return rawFacts.map { PatientFactEntry(category: $0.category, label: $0.label, value: $0.value) }
        } catch {
            AppLogger.general.error("Failed to fetch patient facts: \(error.localizedDescription)")
            return []
        }
    }
}

private struct RawPatientFact: Codable {
    let id: String
    let patientId: String
    let category: String
    let label: String
    let value: String
    let createdAt: String
    let updatedAt: String
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

// MARK: - Supporting Types for Get Current Location

private struct LocationResponse: Codable {
    let placeDescription: String?
    var safeZone: String?
    var safeZoneStatus: String
    var nearbyZones: [NearbyZoneOutput]

    enum CodingKeys: String, CodingKey {
        case placeDescription = "place_description"
        case safeZone = "safe_zone"
        case safeZoneStatus = "safe_zone_status"
        case nearbyZones = "nearby_zones"
    }
}

private struct NearbyZoneOutput: Codable {
    let name: String
    let distanceDescription: String

    enum CodingKeys: String, CodingKey {
        case name
        case distanceDescription = "distance_description"
    }
}

private struct LocationContextResponse: Codable {
    let currentLocation: LocationCoordinate?
    let insideZone: ZoneInfo?
    let nearbyZones: [ZoneInfo]
}

private struct LocationCoordinate: Codable {
    let latitude: Double
    let longitude: Double
    let timestamp: String
}

private struct ZoneInfo: Codable {
    let name: String
    let distance: Int
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
