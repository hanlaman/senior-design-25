//
//  AlertsViewModel.swift
//  caregiverapp
//
//  ═══════════════════════════════════════════════════════════════════════════════
//  ViewModel for alert management. Demonstrates Dictionary grouping and filtering.
//  ═══════════════════════════════════════════════════════════════════════════════

import Foundation
import Combine

@MainActor
@Observable
final class AlertsViewModel {
    private(set) var alerts: [PatientAlert] = []
    private(set) var isLoading: Bool = false
    private(set) var error: Error?

    // Computed properties for filtered views
    var unacknowledgedCount: Int { alerts.filter { !$0.isAcknowledged }.count }
    var criticalAlerts: [PatientAlert] { alerts.filter { $0.severity == .critical && !$0.isAcknowledged } }
    var hasCriticalAlerts: Bool { !criticalAlerts.isEmpty }

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ DICTIONARY GROUPING                                                     │
    // │                                                                         │
    // │ Dictionary(grouping:by:) creates a dictionary from an array.           │
    // │                                                                         │
    // │ Input: [alert1, alert2, alert3, ...]                                    │
    // │ Output: [Date: [PatientAlert]] where Date is start of day              │
    // │                                                                         │
    // │ Example:                                                                 │
    // │   [                                                                      │
    // │     Jan 15: [alert1, alert3],  // Alerts from Jan 15                   │
    // │     Jan 14: [alert2]           // Alerts from Jan 14                   │
    // │   ]                                                                      │
    // │                                                                         │
    // │ Calendar.current.startOfDay(for:) normalizes dates to midnight,        │
    // │ so all alerts from the same day get the same key.                      │
    // └─────────────────────────────────────────────────────────────────────────┘
    var groupedAlerts: [AlertGroup] {
        let grouped = Dictionary(grouping: alerts) { Calendar.current.startOfDay(for: $0.timestamp) }
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ TRANSFORMING DICTIONARY TO ARRAY                                    │
        // │                                                                     │
        // │ .map transforms each key-value pair into an AlertGroup.            │
        // │ $0 = the key (Date), $1 = the value ([PatientAlert])              │
        // │                                                                     │
        // │ .sorted { } sorts the resulting array by date (newest first).      │
        // └─────────────────────────────────────────────────────────────────────┘
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

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ FOR-IN LOOP WITH WHERE CLAUSE                                           │
    // │                                                                         │
    // │ for alert in alerts where !alert.isAcknowledged                        │
    // │                                                                         │
    // │ The 'where' clause filters the iteration inline.                       │
    // │ Only unacknowledged alerts are processed.                              │
    // │                                                                         │
    // │ Equivalent to:                                                          │
    // │   for alert in alerts.filter({ !$0.isAcknowledged })                   │
    // └─────────────────────────────────────────────────────────────────────────┘
    func acknowledgeAll() { Task { for alert in alerts where !alert.isAcknowledged { try? await dataProvider.acknowledgeAlert(id: alert.id) } } }
    func clearAll() { Task { for alert in alerts { try? await dataProvider.clearAlert(id: alert.id) } } }

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ FUNCTION WITH OPTIONAL PARAMETER                                        │
    // │                                                                         │
    // │ type: AlertType? - Can be an AlertType or nil.                         │
    // │ If nil, return all alerts (no filtering).                              │
    // │                                                                         │
    // │ guard let type = type else { return alerts }                           │
    // │ If type is nil, return early with all alerts.                          │
    // │ Otherwise, filter by the unwrapped type.                               │
    // └─────────────────────────────────────────────────────────────────────────┘
    func filterAlerts(by type: AlertType?) -> [PatientAlert] { guard let type = type else { return alerts }; return alerts.filter { $0.type == type } }
}

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ HELPER STRUCT FOR GROUPED DATA                                              │
// │                                                                             │
// │ AlertGroup packages a date with its alerts.                                │
// │ Making it Identifiable allows use in ForEach.                              │
// └─────────────────────────────────────────────────────────────────────────────┘
struct AlertGroup: Identifiable {
    let id = UUID()
    let date: Date
    let alerts: [PatientAlert]

    var dateFormatted: String {
        let calendar = Calendar.current
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ CALENDAR DATE CHECKS                                                │
        // │                                                                     │
        // │ Calendar provides semantic date comparisons:                       │
        // │   .isDateInToday(date)     - Is this date today?                   │
        // │   .isDateInYesterday(date) - Is this date yesterday?               │
        // │   .isDate(_, inSameDayAs:) - Are two dates the same day?          │
        // │   .isDateInWeekend(date)   - Is this a weekend?                    │
        // │                                                                     │
        // │ These handle timezone and locale correctly.                        │
        // └─────────────────────────────────────────────────────────────────────┘
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
