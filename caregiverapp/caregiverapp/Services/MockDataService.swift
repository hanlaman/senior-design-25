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
    @Published private(set) var healthData: HealthData = HealthData()
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
    var healthDataPublisher: AnyPublisher<HealthData, Never> { $healthData.eraseToAnyPublisher() }
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
    private var healthTimer: Timer?

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

        // Create mock location
        currentLocation = PatientLocation(
            coordinate: Coordinate(latitude: 37.7749, longitude: -122.4194),
            isInSafeZone: true,
            currentZoneName: "Home",
            address: "123 Main Street, San Francisco, CA"
        )

        // Create mock safe zones
        safeZones = [
            SafeZone(name: "Home", center: Coordinate(latitude: 37.7749, longitude: -122.4194), radiusMeters: 100),
            SafeZone(name: "Park", center: Coordinate(latitude: 37.7694, longitude: -122.4862), radiusMeters: 200)
        ]

        // Create mock alerts
        alerts = [
            PatientAlert(type: .medication, severity: .medium, title: "Medication Reminder", message: "Evening medication due in 30 minutes", timestamp: Date()),
            PatientAlert(type: .inactivity, severity: .low, title: "Low Activity", message: "Patient has been stationary for 2 hours", timestamp: Date().addingTimeInterval(-3600))
        ]

        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ Calendar - DATE MANIPULATION                                        │
        // │                                                                     │
        // │ Calendar provides date math operations:                             │
        // │   .current - The user's current calendar (Gregorian in US)         │
        // │   .date(bySettingHour:minute:second:of:) - Set time of a date      │
        // │   .date(byAdding:value:to:) - Add days/months/years                │
        // │   .isDateInToday(date) - Check if date is today                    │
        // │   .startOfDay(for:) - Midnight of that date                        │
        // │                                                                     │
        // │ Using 'let' for calendar since we don't modify it.                 │
        // └─────────────────────────────────────────────────────────────────────┘
        let calendar = Calendar.current
        let today = Date()

        // Create mock reminders
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ NIL-COALESCING OPERATOR (??)                                        │
        // │                                                                     │
        // │ calendar.date(...) returns Date? (might fail)                       │
        // │ ?? today provides a default if the result is nil                   │
        // │                                                                     │
        // │ result ?? default                                                   │
        // │   - If result is non-nil: use result (unwrapped)                   │
        // │   - If result is nil: use default                                  │
        // └─────────────────────────────────────────────────────────────────────┘
        reminders = [
            Reminder(type: .medication, title: "Morning Medication", notes: "Aricept 10mg with breakfast", scheduledTime: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today) ?? today, repeatSchedule: .daily, isCompleted: true, completedAt: calendar.date(bySettingHour: 8, minute: 15, second: 0, of: today)),
            Reminder(type: .medication, title: "Evening Medication", notes: "Blood pressure medication", scheduledTime: calendar.date(bySettingHour: 20, minute: 0, second: 0, of: today) ?? today, repeatSchedule: .daily),
            Reminder(type: .hydration, title: "Drink Water", scheduledTime: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: today) ?? today, repeatSchedule: .daily),
            Reminder(type: .activity, title: "Afternoon Walk", notes: "15 minute walk around the block", scheduledTime: calendar.date(bySettingHour: 16, minute: 0, second: 0, of: today) ?? today, repeatSchedule: .daily),
            Reminder(type: .appointment, title: "Doctor Appointment", notes: "Dr. Williams - Annual checkup", scheduledTime: calendar.date(byAdding: .day, value: 3, to: today) ?? today, repeatSchedule: .once)
        ]

        // Create mock health data
        healthData = HealthData(
            heartRate: HeartRateData(current: 72, min: 65, max: 78, history: generateMockHeartRateHistory()),
            activity: ActivityData(steps: 3240, distance: 2100, calories: 1240, standingHours: 6, lastMovement: Date().addingTimeInterval(-1800), sleepHours: 7.5),
            bloodOxygen: 98,
            lastUpdated: Date()
        )

        lastSyncTime = Date()
    }

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ PRIVATE HELPER METHOD                                                   │
    // │                                                                         │
    // │ generateMockHeartRateHistory() creates fake heart rate readings.       │
    // │ It's private because it's an internal implementation detail.           │
    // │                                                                         │
    // │ -> [HeartRateReading] specifies the return type.                       │
    // └─────────────────────────────────────────────────────────────────────────┘
    private func generateMockHeartRateHistory() -> [HeartRateReading] {
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ EMPTY ARRAY LITERAL                                                 │
        // │                                                                     │
        // │ var readings: [HeartRateReading] = []                              │
        // │                                                                     │
        // │ Creates an empty array. Type annotation is optional here because   │
        // │ Swift infers from the function return type.                        │
        // │                                                                     │
        // │ Could also write: var readings = [HeartRateReading]()              │
        // └─────────────────────────────────────────────────────────────────────┘
        var readings: [HeartRateReading] = []
        let now = Date()

        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ FOR-IN LOOP WITH RANGE                                              │
        // │                                                                     │
        // │ 0..<24 creates a Range: 0, 1, 2, ... 23 (excludes 24)              │
        // │ 0...24 would include 24 (closed range)                             │
        // │                                                                     │
        // │ The loop variable 'i' is automatically created.                    │
        // │ You can use _ if you don't need the value: for _ in 0..<24         │
        // └─────────────────────────────────────────────────────────────────────┘
        for i in 0..<24 {
            // Calculate a timestamp i hours ago
            let timestamp = now.addingTimeInterval(TimeInterval(-i * 3600))

            // ┌─────────────────────────────────────────────────────────────────┐
            // │ RANDOM NUMBER GENERATION                                        │
            // │                                                                 │
            // │ Int.random(in: -10...15) returns a random Int from -10 to 15   │
            // │ This adds variety to mock data.                                │
            // │                                                                 │
            // │ Also available:                                                 │
            // │   Double.random(in: 0.0...1.0)                                 │
            // │   Bool.random()                                                 │
            // │   array.randomElement()                                         │
            // │   array.shuffled()                                             │
            // └─────────────────────────────────────────────────────────────────┘
            let value = 70 + Int.random(in: -10...15)
            readings.append(HeartRateReading(value: value, timestamp: timestamp))
        }

        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ ARRAY METHODS                                                       │
        // │                                                                     │
        // │ reversed() returns readings in opposite order.                     │
        // │ We built oldest-first but want newest-first for display.           │
        // │                                                                     │
        // │ Other useful array methods:                                         │
        // │   sorted()           - Sort in natural order                       │
        // │   sorted(by:)        - Sort with custom comparison                 │
        // │   filter { }         - Keep elements matching condition            │
        // │   map { }            - Transform each element                      │
        // │   compactMap { }     - Transform and remove nils                   │
        // │   reduce(initial) { } - Combine all elements into one value        │
        // └─────────────────────────────────────────────────────────────────────┘
        return readings.reversed()
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

    func startHealthMonitoring() {
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ Timer.scheduledTimer - REPEATED EXECUTION                           │
        // │                                                                     │
        // │ Creates a timer that fires every 5 seconds.                        │
        // │ The closure { ... } runs each time it fires.                       │
        // │                                                                     │
        // │ Parameters:                                                         │
        // │   withTimeInterval: 5.0  - Fire every 5 seconds                    │
        // │   repeats: true          - Keep firing (false = fire once)         │
        // │   { _ in ... }           - Code to run (underscore ignores timer)  │
        // └─────────────────────────────────────────────────────────────────────┘
        healthTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            // ┌─────────────────────────────────────────────────────────────────┐
            // │ [weak self] - CAPTURE LIST                                      │
            // │                                                                 │
            // │ Closures can "capture" variables from their surrounding scope. │
            // │ By default, closures create STRONG references to captured      │
            // │ objects, which can cause MEMORY LEAKS (retain cycles).         │
            // │                                                                 │
            // │ [weak self] creates a WEAK reference:                          │
            // │   - self becomes optional (self?)                              │
            // │   - If the object is deallocated, self becomes nil             │
            // │   - Prevents retain cycles                                      │
            // │                                                                 │
            // │ RETAIN CYCLE (memory leak):                                     │
            // │   Timer holds closure → closure holds self → self holds timer  │
            // │   Nothing can be freed!                                         │
            // │                                                                 │
            // │ WITH [weak self]:                                               │
            // │   Timer holds closure → closure holds WEAK self                │
            // │   self can be freed, then closure's self? becomes nil          │
            // └─────────────────────────────────────────────────────────────────┘

            // ┌─────────────────────────────────────────────────────────────────┐
            // │ Task { @MainActor ... }                                         │
            // │                                                                 │
            // │ Task creates an asynchronous context.                           │
            // │ @MainActor ensures the code runs on the main thread.           │
            // │                                                                 │
            // │ Timer callbacks run on a background thread by default,         │
            // │ but our @MainActor class requires main thread access.          │
            // │                                                                 │
            // │ [weak self] is repeated to capture self weakly in this Task.   │
            // └─────────────────────────────────────────────────────────────────┘
            Task { @MainActor [weak self] in
                // ┌─────────────────────────────────────────────────────────────┐
                // │ OPTIONAL CHAINING: self?.method()                           │
                // │                                                             │
                // │ If self is nil (object was deallocated), the whole         │
                // │ expression returns nil and nothing happens.                │
                // │ If self is non-nil, the method is called normally.         │
                // └─────────────────────────────────────────────────────────────┘
                self?.updateMockHealthData()
            }
        }
    }

    func stopHealthMonitoring() {
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ INVALIDATING A TIMER                                                │
        // │                                                                     │
        // │ invalidate() stops the timer permanently.                          │
        // │ After invalidation, the timer object is no longer useful.          │
        // │ Setting to nil allows ARC to deallocate it.                        │
        // │                                                                     │
        // │ Optional chaining: healthTimer?.invalidate()                       │
        // │ This safely does nothing if healthTimer is already nil.            │
        // └─────────────────────────────────────────────────────────────────────┘
        healthTimer?.invalidate()
        healthTimer = nil
    }

    private func updateMockHealthData() {
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ MAX AND MIN FUNCTIONS                                               │
        // │                                                                     │
        // │ max(a, b) returns the larger value                                 │
        // │ min(a, b) returns the smaller value                                │
        // │                                                                     │
        // │ max(55, min(95, value)) clamps value between 55 and 95:            │
        // │   1. min(95, value) - ensures value doesn't exceed 95              │
        // │   2. max(55, ...) - ensures value is at least 55                   │
        // └─────────────────────────────────────────────────────────────────────┘
        let variation = Int.random(in: -3...3)
        let newHeartRate = max(55, min(95, healthData.heartRate.current + variation))

        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ MODIFYING STRUCT PROPERTIES                                         │
        // │                                                                     │
        // │ Structs are value types. To modify, we:                            │
        // │   1. Copy to a new var                                             │
        // │   2. Modify the copy                                               │
        // │   3. Assign back to @Published property                            │
        // │                                                                     │
        // │ The assignment to healthData triggers @Published,                  │
        // │ notifying all subscribers of the change.                           │
        // └─────────────────────────────────────────────────────────────────────┘
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

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ ASYNC FUNCTIONS WITH SIMPLE IMPLEMENTATIONS                             │
    // │                                                                         │
    // │ These are marked async throws to satisfy the protocol, even though     │
    // │ our mock implementation is synchronous.                                │
    // │                                                                         │
    // │ In a real implementation, these would make network calls.              │
    // └─────────────────────────────────────────────────────────────────────────┘
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

    func addReminder(_ reminder: Reminder) async throws {
        reminders.append(reminder)
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ SORTING WITH KEYPATH                                                │
        // │                                                                     │
        // │ sort { $0.scheduledTime < $1.scheduledTime }                       │
        // │                                                                     │
        // │ $0 = first element being compared                                  │
        // │ $1 = second element being compared                                 │
        // │ Returns true if $0 should come before $1                           │
        // │                                                                     │
        // │ This sorts reminders by scheduledTime (earliest first).            │
        // └─────────────────────────────────────────────────────────────────────┘
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
