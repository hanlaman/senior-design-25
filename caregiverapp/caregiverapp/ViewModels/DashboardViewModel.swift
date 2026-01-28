//
//  DashboardViewModel.swift
//  caregiverapp
//

import Foundation
import Combine

@MainActor
@Observable
final class DashboardViewModel {
    private(set) var patient: Patient?
    private(set) var healthData: HealthData = HealthData()
    private(set) var currentLocation: PatientLocation?
    private(set) var recentAlerts: [PatientAlert] = []
    private(set) var upcomingReminders: [Reminder] = []
    private(set) var isConnected: Bool = true
    private(set) var lastSyncTime: Date?
    private(set) var isLoading: Bool = false
    private(set) var error: Error?

    private let dataProvider: PatientDataProvider
    private var cancellables = Set<AnyCancellable>()

    var patientStatus: PatientStatus {
        if !isConnected { return .disconnected }
        if recentAlerts.contains(where: { $0.severity >= .high && !$0.isAcknowledged }) { return .needsAttention }
        if healthData.heartRate.status.isAbnormal { return .warning }
        return .normal
    }

    var connectionStatusText: String {
        if !isConnected { return "Watch Disconnected" }
        if let lastSync = lastSyncTime {
            let interval = Date().timeIntervalSince(lastSync)
            if interval < 60 { return "Last sync: Just now" }
            if interval < 3600 { return "Last sync: \(Int(interval / 60))m ago" }
            return "Last sync: \(Int(interval / 3600))h ago"
        }
        return "Watch Connected"
    }

    init(dataProvider: PatientDataProvider) {
        self.dataProvider = dataProvider
        setupBindings()
    }

    private func setupBindings() {
        dataProvider.healthDataPublisher.receive(on: DispatchQueue.main).sink { [weak self] in self?.healthData = $0 }.store(in: &cancellables)
        dataProvider.locationPublisher.receive(on: DispatchQueue.main).sink { [weak self] in self?.currentLocation = $0 }.store(in: &cancellables)
        dataProvider.alertsPublisher.receive(on: DispatchQueue.main).sink { [weak self] in self?.recentAlerts = Array($0.prefix(5)) }.store(in: &cancellables)
        dataProvider.remindersPublisher.receive(on: DispatchQueue.main).sink { [weak self] reminders in
            self?.upcomingReminders = reminders.filter { !$0.isCompleted && $0.isEnabled }.sorted { $0.scheduledTime < $1.scheduledTime }.prefix(3).map { $0 }
        }.store(in: &cancellables)
        dataProvider.connectionPublisher.receive(on: DispatchQueue.main).sink { [weak self] in self?.isConnected = $0 }.store(in: &cancellables)
    }

    func onAppear() {
        patient = dataProvider.currentPatient
        healthData = dataProvider.healthData
        currentLocation = dataProvider.currentLocation
        recentAlerts = Array(dataProvider.alerts.prefix(5))
        isConnected = dataProvider.isConnected
        lastSyncTime = dataProvider.lastSyncTime
        dataProvider.startHealthMonitoring()
    }

    func onDisappear() { dataProvider.stopHealthMonitoring() }

    func acknowledgeAlert(_ alert: PatientAlert) {
        Task { try? await dataProvider.acknowledgeAlert(id: alert.id) }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        try? await Task.sleep(nanoseconds: 500_000_000)
        lastSyncTime = dataProvider.lastSyncTime
    }
}

enum PatientStatus {
    case normal, warning, needsAttention, disconnected
    var displayText: String {
        switch self {
        case .normal: return "Normal"
        case .warning: return "Warning"
        case .needsAttention: return "Needs Attention"
        case .disconnected: return "Disconnected"
        }
    }
}
