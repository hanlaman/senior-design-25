//
//  ToolExecutors.swift
//  reMIND Watch App
//
//  Static methods for executing function tools
//

import CoreLocation
import Foundation
import os
import WeatherKit
import WatchKit

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

            // Include ISO 8601 offset so the LLM can build correct scheduledTime values
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime]
            isoFormatter.timeZone = .current
            let isoString = isoFormatter.string(from: now)

            let offsetFormatter = DateFormatter()
            offsetFormatter.dateFormat = "xxx" // e.g. "-04:00"
            let tzOffset = offsetFormatter.string(from: now)

            let tzAbbrev = TimeZone.current.abbreviation() ?? ""

            // Create result dictionary
            let result: [String: String] = [
                "current_time": timeString,
                "iso8601": isoString,
                "timezone_offset": tzOffset,
                "timezone": tzAbbrev,
            ]

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

    // MARK: - Get Reminders Tool

    /// Fetch reminders for a given date (defaults to today)
    public static func getReminders(arguments: String) async throws -> String {
        var dateString: String?

        if !arguments.isEmpty, let data = arguments.data(using: .utf8) {
            if let args = try? JSONDecoder().decode(RemindersArguments.self, from: data) {
                dateString = args.date
            }
        }

        // Default to today
        let date = dateString ?? {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: Date())
        }()

        let baseURL = BuildConfiguration.apiBaseURL
        let patientId = BuildConfiguration.patientId

        guard var urlComponents = URLComponents(string: "\(baseURL)/reminders/\(patientId)") else {
            return "{\"error\": \"Could not build request URL\"}"
        }

        let offsetFormatter = DateFormatter()
        offsetFormatter.dateFormat = "xxx"
        let tzOffset = offsetFormatter.string(from: Date())

        urlComponents.queryItems = [
            URLQueryItem(name: "date", value: date),
            URLQueryItem(name: "tz", value: tzOffset),
        ]

        guard let url = urlComponents.url else {
            return "{\"error\": \"Could not build request URL\"}"
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return "{\"error\": \"Could not fetch reminders\"}"
            }

            let reminders = try JSONDecoder().decode([ReminderEntry].self, from: data)

            let timeFormatter = DateFormatter()
            timeFormatter.dateStyle = .none
            timeFormatter.timeStyle = .short

            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            let outputReminders = reminders.map { reminder -> ReminderOutput in
                let timeDisplay: String
                if let parsedDate = isoFormatter.date(from: reminder.scheduledTime) {
                    timeDisplay = timeFormatter.string(from: parsedDate)
                } else {
                    timeDisplay = reminder.scheduledTime
                }
                return ReminderOutput(
                    title: reminder.title,
                    time: timeDisplay,
                    type: reminder.type,
                    notes: reminder.notes
                )
            }

            let result = RemindersResponse(
                date: date,
                reminderCount: outputReminders.count,
                reminders: outputReminders
            )

            let jsonData = try JSONEncoder().encode(result)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw ToolError.executionFailed("Failed to encode reminders as UTF-8")
            }

            AppLogger.general.info("getReminders executed: \(outputReminders.count) reminders for \(date)")
            return jsonString
        } catch let error as ToolError {
            throw error
        } catch {
            AppLogger.general.error("getReminders failed: \(error.localizedDescription)")
            return "{\"error\": \"Could not fetch reminders\"}"
        }
    }

    // MARK: - Create Reminder Tool

    /// Create a new reminder via the backend API
    public static func createReminder(arguments: String) async throws -> String {
        guard !arguments.isEmpty, let data = arguments.data(using: .utf8),
              let args = try? JSONDecoder().decode(CreateReminderArguments.self, from: data),
              !args.title.isEmpty, !args.scheduledTime.isEmpty else {
            return "{\"error\": \"Missing required 'title' and 'scheduledTime' arguments\"}"
        }

        // Validate that scheduledTime is parseable
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        // Also try without timezone for simpler formats like "2026-04-05T15:00:00"
        let fallbackFormatter = DateFormatter()
        fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        guard isoFormatter.date(from: args.scheduledTime) != nil ||
              fallbackFormatter.date(from: args.scheduledTime) != nil else {
            return "{\"error\": \"Invalid scheduledTime format. Use ISO 8601, e.g. '2026-04-05T15:00:00'\"}"
        }

        let baseURL = BuildConfiguration.apiBaseURL
        let patientId = BuildConfiguration.patientId

        guard let url = URL(string: "\(baseURL)/reminders") else {
            return "{\"error\": \"Could not build request URL\"}"
        }

        let body: [String: Any] = [
            "patientId": patientId,
            "type": args.type ?? "custom",
            "title": args.title,
            "scheduledTime": args.scheduledTime,
            "notes": args.notes ?? "",
            "repeatSchedule": args.repeatSchedule ?? "once"
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return "{\"error\": \"Could not create reminder. Please try again.\"}"
            }

            // Format the time for confirmation
            let displayTime: String
            if let date = isoFormatter.date(from: args.scheduledTime) ?? fallbackFormatter.date(from: args.scheduledTime) {
                let displayFormatter = DateFormatter()
                displayFormatter.dateStyle = .medium
                displayFormatter.timeStyle = .short
                displayTime = displayFormatter.string(from: date)
            } else {
                displayTime = args.scheduledTime
            }

            let result: [String: Any] = [
                "success": true,
                "message": "Reminder created: \(args.title) at \(displayTime)"
            ]
            let jsonData = try JSONSerialization.data(withJSONObject: result)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{\"success\": true}"

            AppLogger.general.info("createReminder executed: '\(args.title)' at \(args.scheduledTime)")
            return jsonString
        } catch {
            AppLogger.general.error("createReminder failed: \(error.localizedDescription)")
            return "{\"error\": \"Could not create reminder. Please try again.\"}"
        }
    }

    // MARK: - Notify Caregiver Tool

    /// Throttle: track last alert time to prevent spam
    private static var lastCaregiverAlertTime: Date?
    private static let caregiverAlertCooldown: TimeInterval = 300 // 5 minutes

    /// Send a push notification alert to the caregiver
    public static func notifyCaregiver(arguments: String) async throws -> String {
        guard !arguments.isEmpty, let data = arguments.data(using: .utf8),
              let args = try? JSONDecoder().decode(NotifyCaregiverArguments.self, from: data),
              !args.message.isEmpty else {
            return "{\"error\": \"Missing required 'message' and 'alert_type' arguments\"}"
        }

        // Check throttle
        if let lastAlert = lastCaregiverAlertTime,
           Date().timeIntervalSince(lastAlert) < caregiverAlertCooldown {
            return "{\"already_notified\": true, \"message\": \"Your caregiver was already notified a few minutes ago.\"}"
        }

        let baseURL = BuildConfiguration.apiBaseURL
        let patientId = BuildConfiguration.patientId

        guard let url = URL(string: "\(baseURL)/alerts") else {
            return "{\"error\": \"Could not reach your caregiver right now.\"}"
        }

        let body: [String: String] = [
            "patientId": patientId,
            "message": args.message,
            "alertType": args.alertType
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return "{\"error\": \"Could not reach your caregiver right now.\"}"
            }

            lastCaregiverAlertTime = Date()
            AppLogger.general.info("notifyCaregiver executed: \(args.alertType) - \(args.message)")
            return "{\"success\": true, \"message\": \"Your caregiver has been notified.\"}"
        } catch {
            AppLogger.general.error("notifyCaregiver failed: \(error.localizedDescription)")
            return "{\"error\": \"Could not reach your caregiver right now.\"}"
        }
    }

    // MARK: - Get Weather Tool

    /// Get current weather using WeatherKit
    public static func getWeather(arguments: String) async throws -> String {
        guard let service = locationService else {
            return "{\"error\": \"Location service not available. Cannot determine weather.\"}"
        }

        guard let location = await service.lastLocation else {
            return "{\"error\": \"Location not available yet. Cannot determine weather.\"}"
        }

        do {
            let weatherService = WeatherService.shared
            let weather = try await weatherService.weather(for: location, including: .current, .daily)

            let current = weather.0
            let daily = weather.1

            let temperatureFormatter = MeasurementFormatter()
            temperatureFormatter.unitOptions = .providedUnit
            temperatureFormatter.numberFormatter.maximumFractionDigits = 0

            let currentTemp = temperatureFormatter.string(from: current.temperature)
            let condition = current.condition.description

            var todayForecast: [String: String] = [:]
            if let today = daily.forecast.first {
                todayForecast["high"] = temperatureFormatter.string(from: today.highTemperature)
                todayForecast["low"] = temperatureFormatter.string(from: today.lowTemperature)
                todayForecast["precipitation_chance"] = "\(Int(today.precipitationChance * 100))%"
            }

            let result: [String: Any] = [
                "current": [
                    "temperature": currentTemp,
                    "condition": condition,
                    "humidity": "\(Int(current.humidity * 100))%"
                ],
                "today": todayForecast
            ]

            let jsonData = try JSONSerialization.data(withJSONObject: result)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{\"error\": \"Failed to encode weather\"}"

            AppLogger.general.info("getWeather executed: \(currentTemp), \(condition)")
            return jsonString
        } catch {
            AppLogger.general.error("getWeather failed: \(error.localizedDescription)")
            return "{\"error\": \"Weather information is not available right now.\"}"
        }
    }

    // MARK: - Call Caregiver Tool

    /// Initiate a phone call to the caregiver
    public static func callCaregiver(arguments: String) async throws -> String {
        // Fetch patient facts to find caregiver phone number
        let facts = await PatientFactsFetcher.shared.fetchFacts()

        let phoneFact = facts.first { fact in
            let category = fact.category.lowercased()
            let label = fact.label.lowercased()
            return category.contains("contact") &&
                   (label.contains("phone") || label.contains("caregiver") || label.contains("emergency"))
        }

        guard let fact = phoneFact else {
            AppLogger.general.warning("callCaregiver: no caregiver phone number found in patient facts")
            return "{\"error\": \"No caregiver phone number is set up. Please ask your caregiver to add their phone number.\"}"
        }

        // Sanitize phone number: keep digits and +
        let sanitized = String(fact.value.filter { $0.isNumber || $0 == "+" })

        guard !sanitized.isEmpty, let telURL = URL(string: "tel://\(sanitized)") else {
            return "{\"error\": \"The caregiver phone number on file is not valid.\"}"
        }

        await MainActor.run {
            WKApplication.shared().openSystemURL(telURL)
        }

        AppLogger.general.info("callCaregiver executed: initiating call to \(fact.label)")
        return "{\"success\": true, \"message\": \"Calling your caregiver now.\"}"
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

// MARK: - Supporting Types for Get Reminders

private struct RemindersArguments: Codable {
    let date: String?
}

private struct ReminderEntry: Codable {
    let id: String
    let title: String
    let type: String
    let notes: String?
    let scheduledTime: String
}

private struct ReminderOutput: Codable {
    let title: String
    let time: String
    let type: String
    let notes: String?
}

private struct RemindersResponse: Codable {
    let date: String
    let reminderCount: Int
    let reminders: [ReminderOutput]

    enum CodingKeys: String, CodingKey {
        case date
        case reminderCount = "reminder_count"
        case reminders
    }
}

// MARK: - Supporting Types for Create Reminder

private struct CreateReminderArguments: Codable {
    let title: String
    let scheduledTime: String
    let type: String?
    let notes: String?
    let repeatSchedule: String?
}

// MARK: - Supporting Types for Notify Caregiver

private struct NotifyCaregiverArguments: Codable {
    let message: String
    let alertType: String

    enum CodingKeys: String, CodingKey {
        case message
        case alertType = "alert_type"
    }
}
