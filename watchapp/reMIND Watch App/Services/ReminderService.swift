//
//  ReminderService.swift
//  reMIND Watch App
//
//  Fetches reminders from the backend API for display on the watch.
//

import Foundation
import os

actor ReminderService {
    static let shared = ReminderService()

    private let baseURL: String
    private let patientId: String

    init(
        baseURL: String = "http://localhost:3000",
        patientId: String = "demo-patient-1"
    ) {
        self.baseURL = baseURL
        self.patientId = patientId
    }

    func fetchReminders() async -> [WatchReminder] {
        guard let url = URL(string: "\(baseURL)/reminders/\(patientId)") else {
            AppLogger.general.error("ReminderService: Invalid URL")
            return []
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                AppLogger.general.warning("ReminderService: Unexpected status code")
                return []
            }
            let responses = try JSONDecoder().decode([ReminderResponse].self, from: data)
            return responses.compactMap { mapToReminder($0) }
        } catch {
            AppLogger.logError(error, category: AppLogger.general, context: "Failed to fetch reminders")
            return []
        }
    }

    private func mapToReminder(_ r: ReminderResponse) -> WatchReminder? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let scheduledTime = isoFormatter.date(from: r.scheduledTime) else { return nil }
        let completedAt = r.completedAt.flatMap { isoFormatter.date(from: $0) }

        return WatchReminder(
            id: r.id,
            type: r.type,
            title: r.title,
            notes: r.notes,
            scheduledTime: scheduledTime,
            repeatSchedule: r.repeatSchedule,
            isCompleted: r.isCompleted,
            completedAt: completedAt
        )
    }
}

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

struct WatchReminder: Identifiable {
    let id: String
    let type: String
    let title: String
    let notes: String?
    let scheduledTime: Date
    let repeatSchedule: String
    let isCompleted: Bool
    let completedAt: Date?

    var isOverdue: Bool {
        !isCompleted && scheduledTime < Date()
    }

    var typeIcon: String {
        switch type {
        case "medication": return "pill.fill"
        case "appointment": return "calendar"
        case "activity": return "figure.walk"
        case "hydration": return "drop.fill"
        case "meal": return "fork.knife"
        default: return "bell.fill"
        }
    }

    var typeColor: String {
        switch type {
        case "medication": return "blue"
        case "appointment": return "purple"
        case "activity": return "green"
        case "hydration": return "cyan"
        case "meal": return "orange"
        default: return "gray"
        }
    }

    var repeatLabel: String {
        switch repeatSchedule {
        case "daily": return "Daily"
        case "weekly": return "Weekly"
        case "custom": return "Custom"
        default: return "Once"
        }
    }

    var dateTimeString: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(scheduledTime) {
            formatter.dateFormat = "'Today at' h:mm a"
        } else if calendar.isDateInTomorrow(scheduledTime) {
            formatter.dateFormat = "'Tomorrow at' h:mm a"
        } else if calendar.isDate(scheduledTime, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE 'at' h:mm a"  // e.g. "Thursday at 2:30 PM"
        } else {
            formatter.dateFormat = "MMM d 'at' h:mm a"  // e.g. "Mar 15 at 2:30 PM"
        }

        return formatter.string(from: scheduledTime)
    }

    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: scheduledTime)
    }
}
