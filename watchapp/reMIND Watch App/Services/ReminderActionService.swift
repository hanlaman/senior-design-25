//
//  ReminderActionService.swift
//  reMIND Watch App
//
//  Handles reminder notification actions (complete/snooze) from the watch.
//

import Foundation
import os

actor ReminderActionService {
    private let baseURL: String

    init(baseURL: String = BuildConfiguration.apiBaseURL) {
        self.baseURL = baseURL
    }

    func markComplete(reminderId: String) async {
        guard let url = URL(string: "\(baseURL)/reminders/\(reminderId)/complete") else {
            AppLogger.general.error("ReminderActionService: Invalid URL for complete")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                AppLogger.general.info("Reminder \(reminderId) marked complete")
            } else {
                AppLogger.general.warning("Failed to mark reminder complete")
            }
        } catch {
            AppLogger.logError(error, category: AppLogger.general, context: "Failed to mark reminder complete")
        }
    }

    func snooze(reminderId: String, minutes: Int = 15) async {
        guard let url = URL(string: "\(baseURL)/reminders/\(reminderId)") else {
            AppLogger.general.error("ReminderActionService: Invalid URL for snooze")
            return
        }

        let newTime = Date().addingTimeInterval(TimeInterval(minutes * 60))
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "scheduledTime": formatter.string(from: newTime)
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                AppLogger.general.info("Reminder \(reminderId) snoozed \(minutes) minutes")
            } else {
                AppLogger.general.warning("Failed to snooze reminder")
            }
        } catch {
            AppLogger.logError(error, category: AppLogger.general, context: "Failed to snooze reminder")
        }
    }
}
