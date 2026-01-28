//
//  PatientDataProvider.swift
//  caregiverapp
//

import Foundation
import Combine

@MainActor
protocol PatientDataProvider: AnyObject {
    var currentPatient: Patient? { get }
    func fetchPatient(id: String) async throws -> Patient

    var healthData: HealthData { get }
    var healthDataPublisher: AnyPublisher<HealthData, Never> { get }
    func startHealthMonitoring()
    func stopHealthMonitoring()

    var currentLocation: PatientLocation? { get }
    var locationPublisher: AnyPublisher<PatientLocation?, Never> { get }
    var safeZones: [SafeZone] { get }
    func addSafeZone(_ zone: SafeZone) async throws
    func removeSafeZone(id: UUID) async throws
    func updateSafeZone(_ zone: SafeZone) async throws

    var alerts: [PatientAlert] { get }
    var alertsPublisher: AnyPublisher<[PatientAlert], Never> { get }
    func acknowledgeAlert(id: UUID) async throws
    func clearAlert(id: UUID) async throws

    var reminders: [Reminder] { get }
    var remindersPublisher: AnyPublisher<[Reminder], Never> { get }
    func addReminder(_ reminder: Reminder) async throws
    func updateReminder(_ reminder: Reminder) async throws
    func deleteReminder(id: UUID) async throws
    func markReminderComplete(id: UUID) async throws

    var isConnected: Bool { get }
    var connectionPublisher: AnyPublisher<Bool, Never> { get }
    var lastSyncTime: Date? { get }
}

enum DataProviderError: Error, LocalizedError {
    case notConnected
    case patientNotFound
    case unauthorized
    case networkError(underlying: Error)
    case unknown

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
