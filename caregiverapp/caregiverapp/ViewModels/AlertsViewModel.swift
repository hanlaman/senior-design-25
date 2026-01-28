//
//  AlertsViewModel.swift
//  caregiverapp
//

import Foundation
import Combine

@MainActor
@Observable
final class AlertsViewModel {
    private(set) var alerts: [PatientAlert] = []
    private(set) var isLoading: Bool = false
    private(set) var error: Error?

    var unacknowledgedCount: Int { alerts.filter { !$0.isAcknowledged }.count }
    var criticalAlerts: [PatientAlert] { alerts.filter { $0.severity == .critical && !$0.isAcknowledged } }
    var hasCriticalAlerts: Bool { !criticalAlerts.isEmpty }

    var groupedAlerts: [AlertGroup] {
        let grouped = Dictionary(grouping: alerts) { Calendar.current.startOfDay(for: $0.timestamp) }
        return grouped.map { AlertGroup(date: $0, alerts: $1.sorted { $0.timestamp > $1.timestamp }) }.sorted { $0.date > $1.date }
    }

    private let dataProvider: PatientDataProvider
    private var cancellables = Set<AnyCancellable>()

    init(dataProvider: PatientDataProvider) {
        self.dataProvider = dataProvider
        setupBindings()
    }

    private func setupBindings() {
        dataProvider.alertsPublisher.receive(on: DispatchQueue.main).sink { [weak self] in self?.alerts = $0 }.store(in: &cancellables)
    }

    func onAppear() { alerts = dataProvider.alerts }
    func acknowledge(_ alert: PatientAlert) { Task { try? await dataProvider.acknowledgeAlert(id: alert.id) } }
    func clear(_ alert: PatientAlert) { Task { try? await dataProvider.clearAlert(id: alert.id) } }
    func acknowledgeAll() { Task { for alert in alerts where !alert.isAcknowledged { try? await dataProvider.acknowledgeAlert(id: alert.id) } } }
    func clearAll() { Task { for alert in alerts { try? await dataProvider.clearAlert(id: alert.id) } } }
    func filterAlerts(by type: AlertType?) -> [PatientAlert] { guard let type = type else { return alerts }; return alerts.filter { $0.type == type } }
}

struct AlertGroup: Identifiable {
    let id = UUID()
    let date: Date
    let alerts: [PatientAlert]

    var dateFormatted: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
