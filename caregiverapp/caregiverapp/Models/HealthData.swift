//
//  HealthData.swift
//  caregiverapp
//
//  ═══════════════════════════════════════════════════════════════════════════════
//  SWIFT BASICS: NESTED TYPES, COMPUTED PROPERTIES, AND ENUMS
//  ═══════════════════════════════════════════════════════════════════════════════

import Foundation

struct HealthData: Codable {
    var heartRate: HeartRateData
    var activity: ActivityData
    var bloodOxygen: Int?       // Optional - might not have this data
    var lastUpdated: Date       // Date is a built-in Foundation type

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ DEFAULT PARAMETER VALUES                                                │
    // │                                                                         │
    // │ Most parameters have defaults, so you can create HealthData with:      │
    // │   HealthData()                          // All defaults                │
    // │   HealthData(bloodOxygen: 98)           // Override one thing          │
    // │   HealthData(heartRate: myData, ...)    // Override multiple           │
    // │                                                                         │
    // │ Date() creates the current date/time - perfect for "lastUpdated"       │
    // └─────────────────────────────────────────────────────────────────────────┘
    init(
        heartRate: HeartRateData = HeartRateData(),
        activity: ActivityData = ActivityData(),
        bloodOxygen: Int? = nil,
        lastUpdated: Date = Date()
    ) {
        self.heartRate = heartRate
        self.activity = activity
        self.bloodOxygen = bloodOxygen
        self.lastUpdated = lastUpdated
    }
}

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ MARK COMMENTS                                                               │
// │                                                                             │
// │ // MARK: - Section Name                                                     │
// │                                                                             │
// │ MARK comments create sections in Xcode's jump bar (minimap).               │
// │ The dash (-) adds a separator line above the section.                      │
// │ This helps organize longer files.                                          │
// │                                                                             │
// │ Other special comments:                                                     │
// │   // TODO: Something to do later                                            │
// │   // FIXME: Something that needs fixing                                     │
// │   // NOTE: Important information                                            │
// │                                                                             │
// │ Xcode shows these in the jump bar and issue navigator.                     │
// └─────────────────────────────────────────────────────────────────────────────┘

// MARK: - Heart Rate

struct HeartRateData: Codable {
    var current: Int
    var min: Int
    var max: Int
    var history: [HeartRateReading]

    init(current: Int = 72, min: Int = 60, max: Int = 80, history: [HeartRateReading] = []) {
        self.current = current
        self.min = min
        self.max = max
        self.history = history
    }

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ COMPUTED PROPERTY                                                       │
    // │                                                                         │
    // │ A computed property doesn't store a value - it calculates one.         │
    // │                                                                         │
    // │ SYNTAX: var name: Type { return calculation }                           │
    // │ SHORTHAND: var name: Type { calculation }  // 'return' optional if 1 line│
    // │                                                                         │
    // │ Computed properties are great for:                                      │
    // │   - Deriving values from other properties                              │
    // │   - Avoiding storing redundant data                                    │
    // │   - Encapsulating logic (status depends on current heart rate)         │
    // │                                                                         │
    // │ READ-ONLY: This property only has a getter, so it can't be set.        │
    // │ You CAN have computed properties with getters AND setters:             │
    // │                                                                         │
    // │   var celsius: Double {                                                 │
    // │       get { (fahrenheit - 32) * 5/9 }                                   │
    // │       set { fahrenheit = newValue * 9/5 + 32 }                          │
    // │   }                                                                      │
    // └─────────────────────────────────────────────────────────────────────────┘
    var status: HeartRateStatus {
        if current < 50 { return .low }
        if current > 100 { return .high }
        return .normal
    }
}

struct HeartRateReading: Identifiable, Codable {
    let id: UUID
    let value: Int
    let timestamp: Date

    init(id: UUID = UUID(), value: Int, timestamp: Date = Date()) {
        self.id = id
        self.value = value
        self.timestamp = timestamp
    }
}

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ ENUMS (ENUMERATIONS)                                                        │
// │                                                                             │
// │ Enums define a type with a fixed set of possible values.                   │
// │ They're perfect for things like status, category, mode, etc.               │
// │                                                                             │
// │ Swift enums are MUCH more powerful than in other languages:                │
// │   - Can have raw values (String, Int, etc.)                                │
// │   - Can have associated values (different data per case)                   │
// │   - Can have computed properties and methods                               │
// │   - Can conform to protocols                                               │
// │                                                                             │
// │ RAW VALUE SYNTAX:                                                           │
// │   enum Name: RawType { case x = "value" }                                  │
// │                                                                             │
// │ Here, HeartRateStatus: String means each case has a String raw value.      │
// │ .normal.rawValue == "Normal"                                               │
// │                                                                             │
// │ CODABLE with raw values: Swift auto-generates encoding/decoding!           │
// │ When encoded to JSON, you get the raw value: "Normal", "Low", "High"       │
// └─────────────────────────────────────────────────────────────────────────────┘
enum HeartRateStatus: String, Codable {
    case low = "Low"
    case normal = "Normal"
    case high = "High"

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ ENUM WITH COMPUTED PROPERTY                                             │
    // │                                                                         │
    // │ Enums can have properties and methods just like structs!               │
    // │ This keeps related logic together with the type.                       │
    // │                                                                         │
    // │ self != .normal                                                         │
    // │   - 'self' is the current enum value                                   │
    // │   - .normal is shorthand for HeartRateStatus.normal                    │
    // │   - Swift infers the type from context                                 │
    // └─────────────────────────────────────────────────────────────────────────┘
    var isAbnormal: Bool {
        self != .normal
    }
}

// MARK: - Activity

struct ActivityData: Codable {
    var steps: Int
    var distance: Double         // Double = floating-point number (decimals)
    var calories: Int
    var standingHours: Int
    var lastMovement: Date
    var sleepHours: Double?

    init(
        steps: Int = 0,
        distance: Double = 0,
        calories: Int = 0,
        standingHours: Int = 0,
        lastMovement: Date = Date(),
        sleepHours: Double? = nil
    ) {
        self.steps = steps
        self.distance = distance
        self.calories = calories
        self.standingHours = standingHours
        self.lastMovement = lastMovement
        self.sleepHours = sleepHours
    }

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ TimeInterval                                                            │
    // │                                                                         │
    // │ TimeInterval is a type alias for Double, representing seconds.         │
    // │ Date math in Swift works with seconds:                                 │
    // │                                                                         │
    // │   date.timeIntervalSince(otherDate)  // Seconds between dates          │
    // │   date.addingTimeInterval(3600)      // Add 1 hour (3600 seconds)      │
    // │                                                                         │
    // │ Common conversions:                                                     │
    // │   1 minute = 60 seconds                                                │
    // │   1 hour   = 3600 seconds (60 * 60)                                    │
    // │   1 day    = 86400 seconds (60 * 60 * 24)                              │
    // └─────────────────────────────────────────────────────────────────────────┘
    var inactivityDuration: TimeInterval {
        Date().timeIntervalSince(lastMovement)
    }

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ BOOLEAN EXPRESSIONS                                                     │
    // │                                                                         │
    // │ The > operator returns a Bool (true/false).                            │
    // │ 2 * 60 * 60 = 7200 seconds = 2 hours                                   │
    // │                                                                         │
    // │ This is cleaner than:                                                   │
    // │   var isInactivityConcerning: Bool {                                   │
    // │       if inactivityDuration > 7200 { return true }                     │
    // │       else { return false }                                             │
    // │   }                                                                      │
    // └─────────────────────────────────────────────────────────────────────────┘
    var isInactivityConcerning: Bool {
        inactivityDuration > 2 * 60 * 60  // More than 2 hours
    }
}
