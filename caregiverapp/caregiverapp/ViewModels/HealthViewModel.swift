//
//  HealthViewModel.swift
//  caregiverapp
//

import Foundation
import Combine

@MainActor
@Observable
final class HealthViewModel {
    private(set) var healthData: HealthData = HealthData()
    private(set) var isMonitoring: Bool = false
    private(set) var error: Error?

    var currentHeartRate: Int { healthData.heartRate.current }
    var heartRateRange: String { "\(healthData.heartRate.min)-\(healthData.heartRate.max)" }
    var heartRateStatus: HeartRateStatus { healthData.heartRate.status }
    var heartRateHistory: [HeartRateReading] { healthData.heartRate.history }

    var steps: Int { healthData.activity.steps }
    var stepsFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }
    var calories: Int { healthData.activity.calories }
    var distance: Double { healthData.activity.distance }
    var distanceFormatted: String { distance >= 1000 ? String(format: "%.1f km", distance / 1000) : String(format: "%.0f m", distance) }
    var sleepHours: Double? { healthData.activity.sleepHours }
    var sleepFormatted: String { guard let hours = sleepHours else { return "N/A" }; return String(format: "%.1fh", hours) }
    var standingHours: Int { healthData.activity.standingHours }
    var bloodOxygen: Int? { healthData.bloodOxygen }

    var lastMovement: Date { healthData.activity.lastMovement }
    var inactivityDuration: TimeInterval { healthData.activity.inactivityDuration }
    var inactivityFormatted: String {
        let hours = Int(inactivityDuration / 3600)
        let minutes = Int((inactivityDuration.truncatingRemainder(dividingBy: 3600)) / 60)
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
    var isInactivityConcerning: Bool { healthData.activity.isInactivityConcerning }
    var lastUpdated: Date { healthData.lastUpdated }
    var lastUpdatedFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastUpdated, relativeTo: Date())
    }

    private let dataProvider: PatientDataProvider
    private var cancellables = Set<AnyCancellable>()

    init(dataProvider: PatientDataProvider) {
        self.dataProvider = dataProvider
        setupBindings()
    }

    private func setupBindings() {
        dataProvider.healthDataPublisher.receive(on: DispatchQueue.main).sink { [weak self] in self?.healthData = $0 }.store(in: &cancellables)
    }

    func onAppear() { healthData = dataProvider.healthData; startMonitoring() }
    func onDisappear() { stopMonitoring() }
    func startMonitoring() { guard !isMonitoring else { return }; isMonitoring = true; dataProvider.startHealthMonitoring() }
    func stopMonitoring() { isMonitoring = false; dataProvider.stopHealthMonitoring() }

    func heartRateChartData(hours: Int = 24) -> [(date: Date, value: Int)] {
        let cutoff = Date().addingTimeInterval(TimeInterval(-hours * 3600))
        return heartRateHistory.filter { $0.timestamp >= cutoff }.map { (date: $0.timestamp, value: $0.value) }
    }
}
