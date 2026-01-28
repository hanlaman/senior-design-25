//
//  Reminder.swift
//  caregiverapp
//

import Foundation
import SwiftUI

struct Reminder: Identifiable, Codable {
    let id: UUID
    var type: ReminderType
    var title: String
    var notes: String?
    var scheduledTime: Date
    var repeatSchedule: RepeatSchedule
    var isEnabled: Bool
    var isCompleted: Bool
    var completedAt: Date?
    var sendToWatch: Bool

    init(
        id: UUID = UUID(),
        type: ReminderType,
        title: String,
        notes: String? = nil,
        scheduledTime: Date,
        repeatSchedule: RepeatSchedule = .daily,
        isEnabled: Bool = true,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        sendToWatch: Bool = true
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.notes = notes
        self.scheduledTime = scheduledTime
        self.repeatSchedule = repeatSchedule
        self.isEnabled = isEnabled
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.sendToWatch = sendToWatch
    }

    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: scheduledTime)
    }

    var isOverdue: Bool {
        !isCompleted && scheduledTime < Date()
    }
}

enum ReminderType: String, Codable, CaseIterable {
    case medication = "medication"
    case appointment = "appointment"
    case activity = "activity"
    case hydration = "hydration"
    case meal = "meal"
    case custom = "custom"

    var icon: String {
        switch self {
        case .medication: return "pills.fill"
        case .appointment: return "calendar"
        case .activity: return "figure.walk"
        case .hydration: return "drop.fill"
        case .meal: return "fork.knife"
        case .custom: return "bell.fill"
        }
    }

    var color: Color {
        switch self {
        case .medication: return .red
        case .appointment: return .purple
        case .activity: return .green
        case .hydration: return .blue
        case .meal: return .orange
        case .custom: return .gray
        }
    }

    var displayName: String {
        switch self {
        case .medication: return "Medication"
        case .appointment: return "Appointment"
        case .activity: return "Activity"
        case .hydration: return "Hydration"
        case .meal: return "Meal"
        case .custom: return "Custom"
        }
    }
}

enum RepeatSchedule: Codable, Equatable, Hashable {
    case once
    case daily
    case weekly
    case custom(days: [Int])

    var displayName: String {
        switch self {
        case .once: return "Once"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .custom: return "Custom"
        }
    }
}

struct Medication: Identifiable, Codable {
    let id: UUID
    var name: String
    var dosage: String
    var instructions: String?
    var reminders: [Reminder]
    var refillDate: Date?
    var prescribedBy: String?

    init(
        id: UUID = UUID(),
        name: String,
        dosage: String,
        instructions: String? = nil,
        reminders: [Reminder] = [],
        refillDate: Date? = nil,
        prescribedBy: String? = nil
    ) {
        self.id = id
        self.name = name
        self.dosage = dosage
        self.instructions = instructions
        self.reminders = reminders
        self.refillDate = refillDate
        self.prescribedBy = prescribedBy
    }
}
