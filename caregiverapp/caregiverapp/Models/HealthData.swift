//
//  HealthData.swift
//  caregiverapp
//

import Foundation

struct HealthData: Codable {
    var heartRate: HeartRateData
    var activity: ActivityData
    var bloodOxygen: Int?
    var lastUpdated: Date

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

enum HeartRateStatus: String, Codable {
    case low = "Low"
    case normal = "Normal"
    case high = "High"

    var isAbnormal: Bool {
        self != .normal
    }
}

// MARK: - Activity

struct ActivityData: Codable {
    var steps: Int
    var distance: Double
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

    var inactivityDuration: TimeInterval {
        Date().timeIntervalSince(lastMovement)
    }

    var isInactivityConcerning: Bool {
        inactivityDuration > 2 * 60 * 60
    }
}
