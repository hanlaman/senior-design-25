//
//  MockDataService.swift
//  caregiverapp
//

import Foundation
import Combine

@MainActor
final class MockDataService: PatientDataProvider, ObservableObject {

    @Published private(set) var currentPatient: Patient?
    @Published private(set) var healthData: HealthData = HealthData()
    @Published private(set) var currentLocation: PatientLocation?
    @Published private(set) var safeZones: [SafeZone] = []
    @Published private(set) var alerts: [PatientAlert] = []
    @Published private(set) var reminders: [Reminder] = []
    @Published private(set) var isConnected: Bool = true
    @Published private(set) var lastSyncTime: Date?

    var healthDataPublisher: AnyPublisher<HealthData, Never> { $healthData.eraseToAnyPublisher() }
    var locationPublisher: AnyPublisher<PatientLocation?, Never> { $currentLocation.eraseToAnyPublisher() }
    var alertsPublisher: AnyPublisher<[PatientAlert], Never> { $alerts.eraseToAnyPublisher() }
    var remindersPublisher: AnyPublisher<[Reminder], Never> { $reminders.eraseToAnyPublisher() }
    var connectionPublisher: AnyPublisher<Bool, Never> { $isConnected.eraseToAnyPublisher() }

    private var healthTimer: Timer?

    init() {
        setupMockData()
    }

    private func setupMockData() {
        currentPatient = Patient(
            name: "Mom",
            age: 78,
            conditions: ["Alzheimer's Disease", "Hypertension"],
            emergencyContacts: [
                EmergencyContact(name: "John Smith", relationship: "Son", phoneNumber: "555-0123"),
                EmergencyContact(name: "Dr. Williams", relationship: "Physician", phoneNumber: "555-0456")
            ]
        )

        currentLocation = PatientLocation(
            coordinate: Coordinate(latitude: 37.7749, longitude: -122.4194),
            isInSafeZone: true,
            currentZoneName: "Home",
            address: "123 Main Street, San Francisco, CA"
        )

        safeZones = [
            SafeZone(name: "Home", center: Coordinate(latitude: 37.7749, longitude: -122.4194), radiusMeters: 100),
            SafeZone(name: "Park", center: Coordinate(latitude: 37.7694, longitude: -122.4862), radiusMeters: 200)
        ]

        alerts = [
            PatientAlert(type: .medication, severity: .medium, title: "Medication Reminder", message: "Evening medication due in 30 minutes", timestamp: Date()),
            PatientAlert(type: .inactivity, severity: .low, title: "Low Activity", message: "Patient has been stationary for 2 hours", timestamp: Date().addingTimeInterval(-3600))
        ]

        let calendar = Calendar.current
        let today = Date()

        reminders = [
            Reminder(type: .medication, title: "Morning Medication", notes: "Aricept 10mg with breakfast", scheduledTime: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today) ?? today, repeatSchedule: .daily, isCompleted: true, completedAt: calendar.date(bySettingHour: 8, minute: 15, second: 0, of: today)),
            Reminder(type: .medication, title: "Evening Medication", notes: "Blood pressure medication", scheduledTime: calendar.date(bySettingHour: 20, minute: 0, second: 0, of: today) ?? today, repeatSchedule: .daily),
            Reminder(type: .hydration, title: "Drink Water", scheduledTime: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: today) ?? today, repeatSchedule: .daily),
            Reminder(type: .activity, title: "Afternoon Walk", notes: "15 minute walk around the block", scheduledTime: calendar.date(bySettingHour: 16, minute: 0, second: 0, of: today) ?? today, repeatSchedule: .daily),
            Reminder(type: .appointment, title: "Doctor Appointment", notes: "Dr. Williams - Annual checkup", scheduledTime: calendar.date(byAdding: .day, value: 3, to: today) ?? today, repeatSchedule: .once)
        ]

        healthData = HealthData(
            heartRate: HeartRateData(current: 72, min: 65, max: 78, history: generateMockHeartRateHistory()),
            activity: ActivityData(steps: 3240, distance: 2100, calories: 1240, standingHours: 6, lastMovement: Date().addingTimeInterval(-1800), sleepHours: 7.5),
            bloodOxygen: 98,
            lastUpdated: Date()
        )

        lastSyncTime = Date()
    }

    private func generateMockHeartRateHistory() -> [HeartRateReading] {
        var readings: [HeartRateReading] = []
        let now = Date()
        for i in 0..<24 {
            let timestamp = now.addingTimeInterval(TimeInterval(-i * 3600))
            let value = 70 + Int.random(in: -10...15)
            readings.append(HeartRateReading(value: value, timestamp: timestamp))
        }
        return readings.reversed()
    }

    func fetchPatient(id: String) async throws -> Patient {
        guard let patient = currentPatient else { throw DataProviderError.patientNotFound }
        return patient
    }

    func startHealthMonitoring() {
        healthTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMockHealthData()
            }
        }
    }

    func stopHealthMonitoring() {
        healthTimer?.invalidate()
        healthTimer = nil
    }

    private func updateMockHealthData() {
        let variation = Int.random(in: -3...3)
        let newHeartRate = max(55, min(95, healthData.heartRate.current + variation))

        var newHealthData = healthData
        newHealthData.heartRate.current = newHeartRate
        newHealthData.heartRate.min = min(newHealthData.heartRate.min, newHeartRate)
        newHealthData.heartRate.max = max(newHealthData.heartRate.max, newHeartRate)
        newHealthData.heartRate.history.append(HeartRateReading(value: newHeartRate, timestamp: Date()))
        newHealthData.activity.steps += Int.random(in: 0...20)
        newHealthData.lastUpdated = Date()

        healthData = newHealthData
        lastSyncTime = Date()
    }

    func addSafeZone(_ zone: SafeZone) async throws { safeZones.append(zone) }
    func removeSafeZone(id: UUID) async throws { safeZones.removeAll { $0.id == id } }
    func updateSafeZone(_ zone: SafeZone) async throws {
        if let index = safeZones.firstIndex(where: { $0.id == zone.id }) { safeZones[index] = zone }
    }

    func acknowledgeAlert(id: UUID) async throws {
        if let index = alerts.firstIndex(where: { $0.id == id }) {
            alerts[index].isAcknowledged = true
            alerts[index].acknowledgedAt = Date()
        }
    }

    func clearAlert(id: UUID) async throws { alerts.removeAll { $0.id == id } }

    func addReminder(_ reminder: Reminder) async throws {
        reminders.append(reminder)
        reminders.sort { $0.scheduledTime < $1.scheduledTime }
    }

    func updateReminder(_ reminder: Reminder) async throws {
        if let index = reminders.firstIndex(where: { $0.id == reminder.id }) { reminders[index] = reminder }
    }

    func deleteReminder(id: UUID) async throws { reminders.removeAll { $0.id == id } }

    func markReminderComplete(id: UUID) async throws {
        if let index = reminders.firstIndex(where: { $0.id == id }) {
            reminders[index].isCompleted = true
            reminders[index].completedAt = Date()
        }
    }

    // MARK: - Demo Actions

    func simulateFall() {
        alerts.insert(PatientAlert(type: .fall, severity: .critical, title: "Fall Detected", message: "A fall was detected. Patient has not responded.", timestamp: Date()), at: 0)
    }

    func simulateGeofenceExit() {
        currentLocation = PatientLocation(coordinate: Coordinate(latitude: 37.7849, longitude: -122.4094), isInSafeZone: false, address: "456 Oak Street, San Francisco, CA")
        alerts.insert(PatientAlert(type: .geofence, severity: .high, title: "Left Safe Zone", message: "Patient has left the 'Home' safe zone", timestamp: Date()), at: 0)
    }

    func simulateAbnormalHeartRate() {
        var newHealthData = healthData
        newHealthData.heartRate.current = 115
        newHealthData.heartRate.max = 115
        healthData = newHealthData
        alerts.insert(PatientAlert(type: .heartRate, severity: .high, title: "High Heart Rate", message: "Heart rate elevated to 115 BPM for 5+ minutes", timestamp: Date()), at: 0)
    }

    func simulateConnectionLost() {
        isConnected = false
        alerts.insert(PatientAlert(type: .connection, severity: .medium, title: "Connection Lost", message: "Unable to reach patient's Apple Watch", timestamp: Date()), at: 0)
    }

    func restoreConnection() {
        isConnected = true
        lastSyncTime = Date()
    }
}
