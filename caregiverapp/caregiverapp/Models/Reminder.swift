//
//  Reminder.swift
//  caregiverapp
//
//  ═══════════════════════════════════════════════════════════════════════════════
//  SWIFT BASICS: ENUMS WITH ASSOCIATED VALUES, DateFormatter
//  ═══════════════════════════════════════════════════════════════════════════════

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

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ DateFormatter - CONVERTING DATES TO STRINGS                             │
    // │                                                                         │
    // │ Dates are stored as numbers (seconds since 1970), but users need       │
    // │ readable strings like "3:30 PM" or "January 15, 2025".                 │
    // │                                                                         │
    // │ DateFormatter converts between Date and String:                         │
    // │   - formatter.string(from: date)  → "3:30 PM"                          │
    // │   - formatter.date(from: string)  → Date (or nil if invalid)           │
    // │                                                                         │
    // │ COMMON STYLES:                                                          │
    // │   .short  → "1/15/25", "3:30 PM"                                       │
    // │   .medium → "Jan 15, 2025", "3:30:00 PM"                               │
    // │   .long   → "January 15, 2025", "3:30:00 PM EST"                       │
    // │   .full   → "Wednesday, January 15, 2025"                              │
    // │                                                                         │
    // │ You can also use custom formats:                                        │
    // │   formatter.dateFormat = "yyyy-MM-dd HH:mm"  → "2025-01-15 15:30"      │
    // └─────────────────────────────────────────────────────────────────────────┘
    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short   // "3:30 PM"
        return formatter.string(from: scheduledTime)
    }

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ BOOLEAN EXPRESSIONS WITH MULTIPLE CONDITIONS                            │
    // │                                                                         │
    // │ && means AND - both conditions must be true                             │
    // │ || means OR - at least one condition must be true                      │
    // │ ! means NOT - inverts the boolean                                       │
    // │                                                                         │
    // │ !isCompleted && scheduledTime < Date()                                  │
    // │   ↑              ↑                                                      │
    // │   NOT completed  AND  time has passed                                   │
    // │                                                                         │
    // │ Order of operations: !, then &&, then ||                                │
    // │ Use parentheses for clarity: (a && b) || c                              │
    // └─────────────────────────────────────────────────────────────────────────┘
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

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ ENUMS WITH ASSOCIATED VALUES                                                │
// │                                                                             │
// │ Swift enums can hold different data for different cases!                   │
// │ This is incredibly powerful and not available in most languages.           │
// │                                                                             │
// │ Here, most cases have no data, but .custom(days:) holds an array           │
// │ of day numbers (0=Sunday, 1=Monday, etc.).                                 │
// │                                                                             │
// │ USAGE:                                                                       │
// │   let schedule = RepeatSchedule.custom(days: [1, 3, 5])  // Mon, Wed, Fri  │
// │                                                                             │
// │ EXTRACTING ASSOCIATED VALUES with switch:                                   │
// │   switch schedule {                                                         │
// │   case .once: print("Once")                                                │
// │   case .daily: print("Every day")                                          │
// │   case .weekly: print("Every week")                                        │
// │   case .custom(let days): print("On days: \(days)")                        │
// │   }                                                                         │
// │                                                                             │
// │ Note: Enums with associated values need explicit Codable conformance       │
// │ OR all associated types must be Codable (Swift 5.5+).                      │
// │ Here [Int] is Codable, so Swift auto-generates the Codable code.           │
// └─────────────────────────────────────────────────────────────────────────────┘
enum RepeatSchedule: Codable, Equatable, Hashable {
    case once
    case daily
    case weekly
    case custom(days: [Int])  // Associated value: array of day numbers

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ SWITCHING ON ASSOCIATED VALUES                                          │
    // │                                                                         │
    // │ For cases without associated values, use case .name:                    │
    // │ For cases with associated values, use case .name: (pattern doesn't     │
    // │ matter for displayName since we're not using the days)                 │
    // └─────────────────────────────────────────────────────────────────────────┘
    var displayName: String {
        switch self {
        case .once: return "Once"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .custom: return "Custom"  // Don't need the days for display name
        }
    }
}

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ ADDITIONAL DATA MODEL                                                       │
// │                                                                             │
// │ Medication is a separate type that CONTAINS Reminders.                     │
// │ This shows composition - building complex types from simpler ones.         │
// │                                                                             │
// │ One Medication can have multiple Reminders (morning dose, evening dose).   │
// └─────────────────────────────────────────────────────────────────────────────┘
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
