//
//  ReminderAPIService.swift
//  caregiverapp
//
//  Fetches and manages reminders via the backend API.
//

import Foundation

struct ReminderResponse: Codable {
    let id: String
    let patientId: String
    let type: String
    let title: String
    let notes: String?
    let scheduledTime: String
    let repeatSchedule: String
    let customDays: String?
    let isEnabled: Bool
    let isCompleted: Bool
    let completedAt: String?
    let sendToWatch: Bool
    let lastNotifiedAt: String?
    let createdAt: String
    let updatedAt: String
}

@MainActor
final class ReminderAPIService {
    private let baseURL: String
    private let patientId: String

    init(baseURL: String = "http://localhost:3000", patientId: String = "demo-patient-1") {
        self.baseURL = baseURL
        self.patientId = patientId
    }

    func fetchReminders() async -> [Reminder] {
        guard let url = URL(string: "\(baseURL)/reminders/\(patientId)") else { return [] }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return [] }
            let responses = try JSONDecoder().decode([ReminderResponse].self, from: data)
            return responses.compactMap { mapToReminder($0) }
        } catch {
            print("[ReminderAPIService] Failed to fetch reminders: \(error.localizedDescription)")
            return []
        }
    }

    func createReminder(_ reminder: Reminder) async -> Bool {
        guard let url = URL(string: "\(baseURL)/reminders") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "patientId": patientId,
            "type": reminder.type.rawValue,
            "title": reminder.title,
            "scheduledTime": iso8601String(from: reminder.scheduledTime),
            "repeatSchedule": repeatScheduleToString(reminder.repeatSchedule),
            "isEnabled": reminder.isEnabled,
            "sendToWatch": reminder.sendToWatch
        ]
        if let notes = reminder.notes {
            body["notes"] = notes
        }
        if case .custom(let days) = reminder.repeatSchedule {
            body["customDays"] = days.map(String.init).joined(separator: ",")
        }

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 201
        } catch {
            print("[ReminderAPIService] Failed to create reminder: \(error.localizedDescription)")
            return false
        }
    }

    func updateReminder(_ reminder: Reminder) async -> Bool {
        guard let url = URL(string: "\(baseURL)/reminders/\(reminder.id.uuidString)") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "type": reminder.type.rawValue,
            "title": reminder.title,
            "scheduledTime": iso8601String(from: reminder.scheduledTime),
            "repeatSchedule": repeatScheduleToString(reminder.repeatSchedule),
            "isEnabled": reminder.isEnabled,
            "isCompleted": reminder.isCompleted,
            "sendToWatch": reminder.sendToWatch
        ]
        if let notes = reminder.notes {
            body["notes"] = notes
        }
        if case .custom(let days) = reminder.repeatSchedule {
            body["customDays"] = days.map(String.init).joined(separator: ",")
        }

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            print("[ReminderAPIService] Failed to update reminder: \(error.localizedDescription)")
            return false
        }
    }

    func deleteReminder(id: UUID) async -> Bool {
        guard let url = URL(string: "\(baseURL)/reminders/\(id.uuidString)") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            print("[ReminderAPIService] Failed to delete reminder: \(error.localizedDescription)")
            return false
        }
    }

    func markComplete(id: UUID) async -> Bool {
        guard let url = URL(string: "\(baseURL)/reminders/\(id.uuidString)/complete") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 201 || (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            print("[ReminderAPIService] Failed to mark complete: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Helpers

    private func mapToReminder(_ r: ReminderResponse) -> Reminder? {
        guard let uuid = UUID(uuidString: r.id),
              let type = ReminderType(rawValue: r.type) else { return nil }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let scheduledTime = isoFormatter.date(from: r.scheduledTime) ?? Date()
        let completedAt = r.completedAt.flatMap { isoFormatter.date(from: $0) }

        let repeatSchedule: RepeatSchedule
        switch r.repeatSchedule {
        case "daily": repeatSchedule = .daily
        case "weekly": repeatSchedule = .weekly
        case "custom":
            let days = (r.customDays ?? "").split(separator: ",").compactMap { Int($0) }
            repeatSchedule = .custom(days: days)
        default: repeatSchedule = .once
        }

        return Reminder(
            id: uuid,
            type: type,
            title: r.title,
            notes: r.notes,
            scheduledTime: scheduledTime,
            repeatSchedule: repeatSchedule,
            isEnabled: r.isEnabled,
            isCompleted: r.isCompleted,
            completedAt: completedAt,
            sendToWatch: r.sendToWatch
        )
    }

    private func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private func repeatScheduleToString(_ schedule: RepeatSchedule) -> String {
        switch schedule {
        case .once: return "once"
        case .daily: return "daily"
        case .weekly: return "weekly"
        case .custom: return "custom"
        }
    }
}
