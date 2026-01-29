//
//  PatientAlert.swift
//  caregiverapp
//
//  ═══════════════════════════════════════════════════════════════════════════════
//  SWIFT BASICS: ENUMS WITH PROPERTIES, SWITCH STATEMENTS, COMPARABLE
//  ═══════════════════════════════════════════════════════════════════════════════

import Foundation
import SwiftUI  // For Color type

struct PatientAlert: Identifiable, Codable {
    let id: UUID

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ USING CUSTOM ENUMS AS PROPERTY TYPES                                    │
    // │                                                                         │
    // │ Instead of storing type as a String (error-prone, no autocomplete),    │
    // │ we use our AlertType enum. This provides:                              │
    // │   - Type safety (can only be valid values)                             │
    // │   - Autocomplete in Xcode                                              │
    // │   - Compiler catches typos                                             │
    // │   - Associated behavior (icon, color, displayName)                     │
    // └─────────────────────────────────────────────────────────────────────────┘
    let type: AlertType
    let severity: AlertSeverity
    let title: String
    let message: String
    let timestamp: Date

    var isAcknowledged: Bool
    var acknowledgedAt: Date?
    var acknowledgedBy: String?

    init(
        id: UUID = UUID(),
        type: AlertType,
        severity: AlertSeverity,
        title: String,
        message: String,
        timestamp: Date = Date(),
        isAcknowledged: Bool = false,
        acknowledgedAt: Date? = nil,
        acknowledgedBy: String? = nil
    ) {
        self.id = id
        self.type = type
        self.severity = severity
        self.title = title
        self.message = message
        self.timestamp = timestamp
        self.isAcknowledged = isAcknowledged
        self.acknowledgedAt = acknowledgedAt
        self.acknowledgedBy = acknowledgedBy
    }

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ COMPUTED PROPERTY WITH COMPLEX LOGIC                                    │
    // │                                                                         │
    // │ timeAgo calculates a human-readable string like "5m ago", "2h ago"     │
    // │                                                                         │
    // │ MULTIPLE RETURN STATEMENTS:                                             │
    // │ A function/computed property can have multiple return statements.      │
    // │ Execution stops at the first return reached.                           │
    // │                                                                         │
    // │ STRING INTERPOLATION:                                                   │
    // │   "\(expression)" embeds values in strings                             │
    // │   "\(Int(interval / 60))m ago" → "5m ago"                              │
    // │                                                                         │
    // │ TYPE CASTING:                                                           │
    // │   Int(someDouble) converts Double to Int (truncates decimals)          │
    // └─────────────────────────────────────────────────────────────────────────┘
    var timeAgo: String {
        let interval = Date().timeIntervalSince(timestamp)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h ago"
        } else {
            return "\(Int(interval / 86400))d ago"
        }
    }
}

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ CaseIterable PROTOCOL                                                       │
// │                                                                             │
// │ CaseIterable adds 'allCases' - an array of all enum values.                │
// │ Perfect for building menus, filters, or iterating through options.         │
// │                                                                             │
// │   AlertType.allCases  // [.fall, .heartRate, .geofence, ...]              │
// │                                                                             │
// │   ForEach(AlertType.allCases, id: \.self) { type in                        │
// │       Text(type.displayName)                                               │
// │   }                                                                         │
// └─────────────────────────────────────────────────────────────────────────────┘
enum AlertType: String, Codable, CaseIterable {
    case fall = "fall"
    case heartRate = "heart_rate"
    case geofence = "geofence"
    case inactivity = "inactivity"
    case medication = "medication"
    case sos = "sos"
    case connection = "connection"

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ SWITCH STATEMENT                                                        │
    // │                                                                         │
    // │ Swift's switch is powerful and EXHAUSTIVE - you must handle all cases. │
    // │ The compiler will error if you miss one (great for catching bugs!).    │
    // │                                                                         │
    // │ Unlike other languages:                                                 │
    // │   - No 'break' needed (no fall-through by default)                     │
    // │   - Can switch on any type (strings, enums, tuples, etc.)              │
    // │   - Can use ranges, where clauses, and more                            │
    // │                                                                         │
    // │ For computed properties returning from switch, the syntax is clean:    │
    // │   switch self {                                                         │
    // │       case .fall: return "..."                                          │
    // │       case .heartRate: return "..."                                     │
    // │   }                                                                      │
    // │                                                                         │
    // │ 'self' in an enum refers to the current case.                          │
    // └─────────────────────────────────────────────────────────────────────────┘
    var icon: String {
        switch self {
        case .fall: return "figure.fall"
        case .heartRate: return "heart.fill"
        case .geofence: return "location.slash.fill"
        case .inactivity: return "figure.stand"
        case .medication: return "pills.fill"
        case .sos: return "sos"
        case .connection: return "applewatch.slash"
        }
    }

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ SwiftUI Color                                                           │
    // │                                                                         │
    // │ Color is SwiftUI's color type. Built-in colors:                        │
    // │   .red, .blue, .green, .orange, .yellow, .purple, .gray, .white, .black│
    // │                                                                         │
    // │ Custom colors can be defined in Assets.xcassets or with RGB values.    │
    // └─────────────────────────────────────────────────────────────────────────┘
    var color: Color {
        switch self {
        case .fall: return .red
        case .heartRate: return .red
        case .geofence: return .orange
        case .inactivity: return .yellow
        case .medication: return .blue
        case .sos: return .red
        case .connection: return .gray
        }
    }

    var displayName: String {
        switch self {
        case .fall: return "Fall Detected"
        case .heartRate: return "Heart Rate"
        case .geofence: return "Location"
        case .inactivity: return "Inactivity"
        case .medication: return "Medication"
        case .sos: return "Emergency SOS"
        case .connection: return "Connection"
        }
    }
}

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ COMPARABLE PROTOCOL                                                         │
// │                                                                             │
// │ Comparable lets you use <, >, <=, >= operators with your type.             │
// │ You must implement the < operator; Swift derives the others.               │
// │                                                                             │
// │ With Comparable, you can:                                                   │
// │   - Compare: if alert1.severity > alert2.severity { ... }                  │
// │   - Sort: alerts.sorted { $0.severity > $1.severity }                      │
// │   - Use min/max: alerts.max(by: { $0.severity < $1.severity })             │
// └─────────────────────────────────────────────────────────────────────────────┘
enum AlertSeverity: String, Codable, Comparable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ STATIC FUNCTION FOR COMPARABLE                                          │
    // │                                                                         │
    // │ 'static' means this function belongs to the TYPE, not instances.       │
    // │ Static functions/properties are called on the type itself:             │
    // │   AlertSeverity < anotherSeverity   (not severity1 < severity2)        │
    // │                                                                         │
    // │ Wait, but we DO use severity1 < severity2... how?                      │
    // │ Swift automatically converts that to:                                   │
    // │   AlertSeverity.<(severity1, severity2)                                │
    // │                                                                         │
    // │ OPERATOR FUNCTION:                                                      │
    // │ The < is a function name! Yes, operators are functions in Swift.       │
    // │ func < (lhs: Type, rhs: Type) -> Bool                                  │
    // │   lhs = left-hand side                                                  │
    // │   rhs = right-hand side                                                 │
    // └─────────────────────────────────────────────────────────────────────────┘
    static func < (lhs: AlertSeverity, rhs: AlertSeverity) -> Bool {
        // Create an ordered array and compare positions
        let order: [AlertSeverity] = [.low, .medium, .high, .critical]

        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ FORCE UNWRAP WITH !                                                 │
        // │                                                                     │
        // │ firstIndex(of:) returns an Optional (Int?) because the item might  │
        // │ not be in the array. The ! force-unwraps it.                       │
        // │                                                                     │
        // │ This is SAFE here because:                                          │
        // │   1. 'order' contains ALL AlertSeverity cases                      │
        // │   2. lhs and rhs are AlertSeverity values                          │
        // │   3. So they MUST be in the array                                  │
        // │                                                                     │
        // │ Only use ! when you're 100% certain the value isn't nil.           │
        // └─────────────────────────────────────────────────────────────────────┘
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }

    var color: Color {
        switch self {
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}
