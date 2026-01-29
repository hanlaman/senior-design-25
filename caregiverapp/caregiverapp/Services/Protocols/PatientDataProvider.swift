//
//  PatientDataProvider.swift
//  caregiverapp
//
//  ═══════════════════════════════════════════════════════════════════════════════
//  SWIFT BASICS: PROTOCOLS, ASYNC/AWAIT, AND COMBINE
//  ═══════════════════════════════════════════════════════════════════════════════
//
//  A PROTOCOL is like a contract or interface. It defines WHAT a type must do,
//  but not HOW it does it. This enables "programming to an interface" - your
//  app depends on the protocol, not specific implementations.
//
//  Benefits:
//    - Swap implementations easily (MockDataService → FirebaseDataService)
//    - Write tests with mock implementations
//    - Decouple components (Views don't care where data comes from)
//

import Foundation
import Combine  // Apple's reactive framework for handling asynchronous events

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ @MainActor                                                                  │
// │                                                                             │
// │ @MainActor ensures all code runs on the MAIN THREAD.                        │
// │ This is critical because:                                                   │
// │   - UI updates MUST happen on the main thread                               │
// │   - Accessing UI-related data from background threads causes crashes       │
// │                                                                             │
// │ When you mark something with @MainActor:                                    │
// │   - All properties and methods run on the main thread                      │
// │   - Swift compiler enforces this at compile time                           │
// │   - Background code calling @MainActor code must use await                 │
// │                                                                             │
// │ ACTORS are Swift's solution for safe concurrent code.                       │
// │ MainActor is a special actor representing the main/UI thread.              │
// └─────────────────────────────────────────────────────────────────────────────┘
@MainActor

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ PROTOCOL DEFINITION                                                         │
// │                                                                             │
// │ Syntax: protocol Name: InheritedProtocol { requirements }                  │
// │                                                                             │
// │ AnyObject constraint means only CLASSES can conform to this protocol.      │
// │ We need this because:                                                       │
// │   1. Services maintain state and should be reference types                 │
// │   2. Multiple views share the same service instance                        │
// │   3. Enables [weak self] captures to avoid memory leaks                    │
// │                                                                             │
// │ Protocol requirements can include:                                          │
// │   - Properties (var name: Type { get } or { get set })                     │
// │   - Methods (func name(params) -> ReturnType)                              │
// │   - Initializers (init(params))                                            │
// │   - Associated types (for generics)                                        │
// └─────────────────────────────────────────────────────────────────────────────┘
protocol PatientDataProvider: AnyObject {

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ PROPERTY REQUIREMENTS                                                   │
    // │                                                                         │
    // │ var name: Type { get }     → read-only (computed or stored)            │
    // │ var name: Type { get set } → read-write (must be settable)             │
    // │                                                                         │
    // │ Note: Protocol only specifies the INTERFACE, not implementation.       │
    // │ A conforming type could implement { get } with:                        │
    // │   - A stored property: var currentPatient: Patient? = nil              │
    // │   - A computed property: var currentPatient: Patient? { fetchFromDB() }│
    // └─────────────────────────────────────────────────────────────────────────┘
    var currentPatient: Patient? { get }

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ ASYNC FUNCTION REQUIREMENTS                                             │
    // │                                                                         │
    // │ 'async' marks a function that can be suspended while waiting.          │
    // │ 'throws' means the function can throw an error.                        │
    // │                                                                         │
    // │ async throws functions must be called with 'try await':                │
    // │   let patient = try await dataProvider.fetchPatient(id: "123")         │
    // │                                                                         │
    // │ WHY ASYNC?                                                              │
    // │ Fetching data might take time (network, database). Without async,      │
    // │ your app would freeze. With async, the function "suspends" and the     │
    // │ app continues running until the data arrives.                          │
    // └─────────────────────────────────────────────────────────────────────────┘
    func fetchPatient(id: String) async throws -> Patient

    // Health Data
    var healthData: HealthData { get }
    var healthDataPublisher: AnyPublisher<HealthData, Never> { get }
    func startHealthMonitoring()
    func stopHealthMonitoring()

    // Location
    var currentLocation: PatientLocation? { get }
    var locationPublisher: AnyPublisher<PatientLocation?, Never> { get }
    var safeZones: [SafeZone] { get }
    func addSafeZone(_ zone: SafeZone) async throws
    func removeSafeZone(id: UUID) async throws
    func updateSafeZone(_ zone: SafeZone) async throws

    // Alerts
    var alerts: [PatientAlert] { get }
    var alertsPublisher: AnyPublisher<[PatientAlert], Never> { get }
    func acknowledgeAlert(id: UUID) async throws
    func clearAlert(id: UUID) async throws

    // Reminders
    var reminders: [Reminder] { get }
    var remindersPublisher: AnyPublisher<[Reminder], Never> { get }
    func addReminder(_ reminder: Reminder) async throws
    func updateReminder(_ reminder: Reminder) async throws
    func deleteReminder(id: UUID) async throws
    func markReminderComplete(id: UUID) async throws

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ COMBINE PUBLISHERS                                                      │
    // │                                                                         │
    // │ AnyPublisher<Output, Failure> is a Combine type that emits values      │
    // │ over time. Think of it like a stream of data.                          │
    // │                                                                         │
    // │ AnyPublisher<Bool, Never>                                               │
    // │   - Output type: Bool (the connection status)                          │
    // │   - Failure type: Never (this publisher never fails)                   │
    // │                                                                         │
    // │ Publishers let views SUBSCRIBE to changes:                             │
    // │   dataProvider.connectionPublisher                                      │
    // │       .sink { isConnected in                                            │
    // │           print("Connection changed: \(isConnected)")                  │
    // │       }                                                                  │
    // │                                                                         │
    // │ This is REACTIVE programming - views react to data changes             │
    // │ instead of polling/checking for updates.                               │
    // └─────────────────────────────────────────────────────────────────────────┘
    var isConnected: Bool { get }
    var connectionPublisher: AnyPublisher<Bool, Never> { get }
    var lastSyncTime: Date? { get }
}

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ CUSTOM ERROR TYPE                                                           │
// │                                                                             │
// │ Enums are great for errors because each case represents a specific error.  │
// │                                                                             │
// │ ERROR PROTOCOL:                                                             │
// │ Required for use with 'throw'. Gives you basic error functionality.        │
// │                                                                             │
// │ LocalizedError PROTOCOL:                                                    │
// │ Adds 'errorDescription' for user-friendly error messages.                  │
// │                                                                             │
// │ ASSOCIATED VALUE FOR CONTEXT:                                               │
// │ .networkError(underlying: Error) wraps the original error so you can      │
// │ access details: "Network error: The Internet connection appears offline"   │
// └─────────────────────────────────────────────────────────────────────────────┘
enum DataProviderError: Error, LocalizedError {
    case notConnected
    case patientNotFound
    case unauthorized
    case networkError(underlying: Error)
    case unknown

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ OPTIONAL COMPUTED PROPERTY                                              │
    // │                                                                         │
    // │ errorDescription is defined by LocalizedError as String? (optional).   │
    // │ Returning nil means "use the default error message".                   │
    // │                                                                         │
    // │ This property is what users see in error dialogs.                      │
    // └─────────────────────────────────────────────────────────────────────────┘
    var errorDescription: String? {
        switch self {
        case .notConnected: return "Not connected to patient data"
        case .patientNotFound: return "Patient not found"
        case .unauthorized: return "Not authorized to access this data"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .unknown: return "An unknown error occurred"
        }
    }
}
