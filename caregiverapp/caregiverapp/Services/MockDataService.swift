//
//  MockDataService.swift
//  caregiverapp
//
//  ═══════════════════════════════════════════════════════════════════════════════
//  SWIFT BASICS: CLASSES, @Published, ObservableObject, CLOSURES, TIMERS
//  ═══════════════════════════════════════════════════════════════════════════════
//
//  This is a MOCK implementation - it generates fake data for testing/demos.
//  A real implementation (FirebaseDataService) would fetch from a server.
//  Because both conform to PatientDataProvider, the rest of the app works
//  the same regardless of which implementation we use.
//

import Foundation
import Combine

@MainActor
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ FINAL CLASS                                                                 │
// │                                                                             │
// │ 'final' prevents subclassing. This class cannot be inherited from.         │
// │ Benefits:                                                                   │
// │   - Compiler optimizations (no vtable lookups)                             │
// │   - Clear intent: this class is complete as-is                             │
// │   - Protocol conformance: some protocols work better with final classes    │
// │                                                                             │
// │ Use 'final' unless you specifically need inheritance.                      │
// └─────────────────────────────────────────────────────────────────────────────┘

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ MULTIPLE PROTOCOL CONFORMANCE                                               │
// │                                                                             │
// │ A class can conform to multiple protocols (comma-separated).               │
// │                                                                             │
// │ PatientDataProvider: Our custom protocol defining data operations          │
// │ ObservableObject: SwiftUI protocol for objects that publish changes        │
// │                                                                             │
// │ ObservableObject works with @Published to notify SwiftUI of changes.       │
// │ When a @Published property changes, any view using this object re-renders. │
// └─────────────────────────────────────────────────────────────────────────────┘
final class MockDataService: PatientDataProvider, ObservableObject {

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ @Published PROPERTY WRAPPER                                             │
    // │                                                                         │
    // │ @Published automatically creates a Combine publisher for this property.│
    // │ When the value changes, all subscribers are notified.                  │
    // │                                                                         │
    // │ @Published private(set) var currentPatient: Patient?                    │
    // │     ↑          ↑        ↑                                               │
    // │  publisher  setter is   anyone can read, only this class can write     │
    // │             private                                                     │
    // │                                                                         │
    // │ private(set) is ACCESS CONTROL:                                         │
    // │   - get is default access (internal or public)                         │
    // │   - set is private (only this file/class can modify)                   │
    // │                                                                         │
    // │ This prevents external code from accidentally modifying the patient.   │
    // └─────────────────────────────────────────────────────────────────────────┘
    @Published private(set) var currentPatient: Patient?
    @Published private(set) var currentLocation: PatientLocation?
    @Published private(set) var safeZones: [SafeZone] = []
    @Published private(set) var alerts: [PatientAlert] = []
    @Published private(set) var reminders: [Reminder] = []
    @Published private(set) var isConnected: Bool = true
    @Published private(set) var lastSyncTime: Date?

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ CREATING PUBLISHERS FROM @Published                                     │
    // │                                                                         │
    // │ $healthData accesses the PUBLISHER, not the value.                     │
    // │ $propertyName is synthesized by @Published.                            │
    // │                                                                         │
    // │ eraseToAnyPublisher() hides the specific publisher type.               │
    // │ This makes code more flexible and hides implementation details.        │
    // │                                                                         │
    // │ Without erasing:                                                        │
    // │   var healthDataPublisher: Published<HealthData>.Publisher             │
    // │                                                                         │
    // │ With erasing:                                                           │
    // │   var healthDataPublisher: AnyPublisher<HealthData, Never>             │
    // │                                                                         │
    // │ The protocol requires AnyPublisher, so we must erase.                  │
    // └─────────────────────────────────────────────────────────────────────────┘
    var locationPublisher: AnyPublisher<PatientLocation?, Never> { $currentLocation.eraseToAnyPublisher() }
    var alertsPublisher: AnyPublisher<[PatientAlert], Never> { $alerts.eraseToAnyPublisher() }
    var remindersPublisher: AnyPublisher<[Reminder], Never> { $reminders.eraseToAnyPublisher() }
    var connectionPublisher: AnyPublisher<Bool, Never> { $isConnected.eraseToAnyPublisher() }

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ OPTIONAL TIMER                                                          │
    // │                                                                         │
    // │ Timer? is optional because:                                             │
    // │   - The timer might not be running (nil)                               │
    // │   - We need to store it to invalidate later                            │
    // │                                                                         │
    // │ private means only this class can access it.                            │
    // └─────────────────────────────────────────────────────────────────────────┘
    private let reminderAPI = ReminderAPIService()

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ INIT (INITIALIZER/CONSTRUCTOR)                                          │
    // │                                                                         │
    // │ init() is called when you create an instance: MockDataService()        │
    // │ Classes must ensure all properties have values when init finishes.     │
    // │                                                                         │
    // │ Unlike structs, classes:                                                │
    // │   - Don't get automatic memberwise initializers                        │
    // │   - Can have deinit (cleanup when object is destroyed)                 │
    // │   - Properties can have default values (= ...) as we do here           │
    // └─────────────────────────────────────────────────────────────────────────┘
    init() {
        setupMockData()
    }

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ PRIVATE METHODS                                                         │
    // │                                                                         │
    // │ 'private' methods are only callable within this class.                 │
    // │ This is ENCAPSULATION - hide internal details from outside code.       │
    // │                                                                         │
    // │ setupMockData() initializes all the fake data.                         │
    // │ It's private because callers shouldn't need to call it directly.       │
    // └─────────────────────────────────────────────────────────────────────────┘
    private func setupMockData() {
        // Create a mock patient
        currentPatient = Patient(
            name: "Mom",
            age: 78,
            conditions: ["Alzheimer's Disease", "Hypertension"],
            emergencyContacts: [
                EmergencyContact(name: "John Smith", relationship: "Son", phoneNumber: "555-0123"),
                EmergencyContact(name: "Dr. Williams", relationship: "Physician", phoneNumber: "555-0456")
            ]
        )

        // Location and safe zones are fetched from the API, not mocked
        currentLocation = nil
        safeZones = []

        // Create mock alerts
        alerts = [
            PatientAlert(type: .medication, severity: .medium, title: "Medication Reminder", message: "Evening medication due in 30 minutes", timestamp: Date()),
            PatientAlert(type: .inactivity, severity: .low, title: "Low Activity", message: "Patient has been stationary for 2 hours", timestamp: Date().addingTimeInterval(-3600))
        ]

        // Fetch reminders from API (falls back to empty array if server unavailable)
        Task {
            reminders = await reminderAPI.fetchReminders()
        }

        lastSyncTime = Date()
    }

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ ASYNC THROWS FUNCTION                                                   │
    // │                                                                         │
    // │ This satisfies the protocol requirement.                               │
    // │ 'async throws' means it can be awaited and can throw errors.           │
    // │                                                                         │
    // │ Even though our mock implementation is simple (no network call),       │
    // │ we keep the async signature for interface consistency with real impl.  │
    // └─────────────────────────────────────────────────────────────────────────┘
    func fetchPatient(id: String) async throws -> Patient {
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ GUARD STATEMENT                                                     │
        // │                                                                     │
        // │ guard let patient = currentPatient else { throw ... }              │
        // │                                                                     │
        // │ Guard is like "if not this, exit early".                           │
        // │ If the condition fails, you MUST exit (return/throw/break/etc.)    │
        // │                                                                     │
        // │ After guard, 'patient' is unwrapped and available for the rest     │
        // │ of the function. This is different from if-let where the           │
        // │ unwrapped value is only in the if block.                           │
        // │                                                                     │
        // │ guard vs if-let:                                                    │
        // │   - guard: Exit early if condition fails, use value after          │
        // │   - if-let: Use value inside block only                            │
        // └─────────────────────────────────────────────────────────────────────┘
        guard let patient = currentPatient else { throw DataProviderError.patientNotFound }
        return patient
    }

    func addSafeZone(_ zone: SafeZone) async throws { safeZones.append(zone) }
    func removeSafeZone(id: UUID) async throws { safeZones.removeAll { $0.id == id } }
    func updateSafeZone(_ zone: SafeZone) async throws {
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ firstIndex(where:) WITH CLOSURE                                     │
        // │                                                                     │
        // │ Returns the index of the first element matching the condition.     │
        // │ Returns nil if no match found.                                     │
        // │                                                                     │
        // │ { $0.id == zone.id }                                               │
        // │   ↑    ↑                                                            │
        // │   $0 = first closure parameter (each SafeZone)                     │
        // │   Shorthand closure syntax for single expressions                  │
        // │                                                                     │
        // │ Full form would be:                                                │
        // │   { (safeZone: SafeZone) -> Bool in                                │
        // │       return safeZone.id == zone.id                                │
        // │   }                                                                 │
        // └─────────────────────────────────────────────────────────────────────┘
        if let index = safeZones.firstIndex(where: { $0.id == zone.id }) { safeZones[index] = zone }
    }

    func acknowledgeAlert(id: UUID) async throws {
        if let index = alerts.firstIndex(where: { $0.id == id }) {
            alerts[index].isAcknowledged = true
            alerts[index].acknowledgedAt = Date()
        }
    }

    func clearAlert(id: UUID) async throws { alerts.removeAll { $0.id == id } }
    func addAlert(_ alert: PatientAlert) async throws { alerts.insert(alert, at: 0) }

    func addReminder(_ reminder: Reminder) async throws {
        let success = await reminderAPI.createReminder(reminder)
        if success {
            reminders = await reminderAPI.fetchReminders()
        } else {
            // Fallback to local-only if API unavailable
            reminders.append(reminder)
            reminders.sort { $0.scheduledTime < $1.scheduledTime }
        }
    }

    func updateReminder(_ reminder: Reminder) async throws {
        let success = await reminderAPI.updateReminder(reminder)
        if success {
            reminders = await reminderAPI.fetchReminders()
        } else if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders[index] = reminder
        }
    }

    func deleteReminder(id: UUID) async throws {
        let success = await reminderAPI.deleteReminder(id: id)
        if success {
            reminders = await reminderAPI.fetchReminders()
        } else {
            reminders.removeAll { $0.id == id }
        }
    }

    func markReminderComplete(id: UUID) async throws {
        let success = await reminderAPI.markComplete(id: id)
        if success {
            reminders = await reminderAPI.fetchReminders()
        } else if let index = reminders.firstIndex(where: { $0.id == id }) {
            reminders[index].isCompleted = true
            reminders[index].completedAt = Date()
        }
    }

    // MARK: - Demo Actions
    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ SIMULATION METHODS FOR TESTING/DEMOS                                    │
    // │                                                                         │
    // │ These methods let you trigger events manually to test the app.         │
    // │ In a real app, these events would come from the Watch/Firebase.        │
    // └─────────────────────────────────────────────────────────────────────────┘

    func simulateFall() {
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ insert(at: 0) - ADD TO BEGINNING                                    │
        // │                                                                     │
        // │ Inserts at index 0 (beginning of array).                           │
        // │ New alerts should appear first (most recent at top).               │
        // └─────────────────────────────────────────────────────────────────────┘
        alerts.insert(PatientAlert(type: .fall, severity: .critical, title: "Fall Detected", message: "A fall was detected. Patient has not responded.", timestamp: Date()), at: 0)
    }

    func simulateGeofenceExit() {
        currentLocation = PatientLocation(coordinate: Coordinate(latitude: 37.7849, longitude: -122.4094), isInSafeZone: false, address: "456 Oak Street, San Francisco, CA")
        alerts.insert(PatientAlert(type: .geofence, severity: .high, title: "Left Safe Zone", message: "Patient has left the 'Home' safe zone", timestamp: Date()), at: 0)
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
