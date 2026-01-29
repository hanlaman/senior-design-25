//
//  HealthViewModel.swift
//  caregiverapp
//
//  ═══════════════════════════════════════════════════════════════════════════════
//  SWIFT BASICS: COMPUTED PROPERTIES FOR DATA TRANSFORMATION
//  ═══════════════════════════════════════════════════════════════════════════════
//
//  ViewModels often have many computed properties that transform raw data
//  into display-ready formats. This keeps Views simple and testable.
//

import Foundation
import Combine

@MainActor
@Observable
final class HealthViewModel {
    private(set) var healthData: HealthData = HealthData()
    private(set) var isMonitoring: Bool = false
    private(set) var error: Error?

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ COMPUTED PROPERTIES AS DATA ACCESSORS                                   │
    // │                                                                         │
    // │ These provide convenient access to nested data.                        │
    // │ Views use viewModel.currentHeartRate instead of                        │
    // │ viewModel.healthData.heartRate.current                                 │
    // │                                                                         │
    // │ This creates a cleaner API and hides internal structure.               │
    // │ If we change how data is stored, views don't need to change.          │
    // └─────────────────────────────────────────────────────────────────────────┘
    var currentHeartRate: Int { healthData.heartRate.current }
    var heartRateRange: String { "\(healthData.heartRate.min)-\(healthData.heartRate.max)" }
    var heartRateStatus: HeartRateStatus { healthData.heartRate.status }
    var heartRateHistory: [HeartRateReading] { healthData.heartRate.history }

    var steps: Int { healthData.activity.steps }

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ NumberFormatter - LOCALE-AWARE NUMBER FORMATTING                        │
    // │                                                                         │
    // │ Formats numbers according to user's locale:                            │
    // │   US: 1,234   Germany: 1.234   France: 1 234                           │
    // │                                                                         │
    // │ .numberStyle = .decimal adds thousands separators                      │
    // │                                                                         │
    // │ Other styles:                                                           │
    // │   .currency   - $1,234.00                                              │
    // │   .percent    - 50%                                                     │
    // │   .scientific - 1.234E3                                                 │
    // │   .ordinal    - 1st, 2nd, 3rd                                          │
    // └─────────────────────────────────────────────────────────────────────────┘
    var stepsFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }

    var calories: Int { healthData.activity.calories }
    var distance: Double { healthData.activity.distance }

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ CONDITIONAL STRING FORMATTING                                           │
    // │                                                                         │
    // │ Show km for distances >= 1000m, otherwise show meters.                 │
    // │                                                                         │
    // │ String(format:) uses C-style format specifiers:                        │
    // │   %.1f = Float with 1 decimal place (1234.5 → "1234.5")               │
    // │   %.0f = Float with 0 decimal places (1234.5 → "1235")                │
    // │   %d   = Integer                                                        │
    // │   %@   = Object (String, etc.)                                         │
    // └─────────────────────────────────────────────────────────────────────────┘
    var distanceFormatted: String { distance >= 1000 ? String(format: "%.1f km", distance / 1000) : String(format: "%.0f m", distance) }

    var sleepHours: Double? { healthData.activity.sleepHours }
    var sleepFormatted: String { guard let hours = sleepHours else { return "N/A" }; return String(format: "%.1fh", hours) }
    var standingHours: Int { healthData.activity.standingHours }
    var bloodOxygen: Int? { healthData.bloodOxygen }

    var lastMovement: Date { healthData.activity.lastMovement }
    var inactivityDuration: TimeInterval { healthData.activity.inactivityDuration }

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ COMPLEX COMPUTED PROPERTY                                               │
    // │                                                                         │
    // │ Computed properties can contain multiple statements.                   │
    // │ Use local variables for intermediate calculations.                     │
    // │                                                                         │
    // │ truncatingRemainder(dividingBy:) is Swift's modulo for floating-point. │
    // │ Unlike % for integers, this works with Double.                         │
    // │                                                                         │
    // │ Example: 3700 seconds                                                   │
    // │   hours = 3700 / 3600 = 1                                              │
    // │   remainder = 3700 % 3600 = 100 seconds                                │
    // │   minutes = 100 / 60 = 1                                               │
    // │   Result: "1h 1m"                                                       │
    // └─────────────────────────────────────────────────────────────────────────┘
    var inactivityFormatted: String {
        let hours = Int(inactivityDuration / 3600)
        let minutes = Int((inactivityDuration.truncatingRemainder(dividingBy: 3600)) / 60)
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    var isInactivityConcerning: Bool { healthData.activity.isInactivityConcerning }
    var lastUpdated: Date { healthData.lastUpdated }

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ RelativeDateTimeFormatter                                               │
    // │                                                                         │
    // │ Formats dates relative to now:                                         │
    // │   "2 minutes ago", "in 3 hours", "yesterday"                           │
    // │                                                                         │
    // │ .unitsStyle controls verbosity:                                        │
    // │   .abbreviated - "2 min. ago"                                          │
    // │   .short       - "2 min. ago"                                          │
    // │   .full        - "2 minutes ago"                                       │
    // │   .spellOut    - "two minutes ago"                                     │
    // └─────────────────────────────────────────────────────────────────────────┘
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

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ GUARD AS EARLY EXIT                                                     │
    // │                                                                         │
    // │ guard !isMonitoring else { return }                                    │
    // │                                                                         │
    // │ This reads as: "Guard that we're NOT monitoring, else return."        │
    // │ It's a common pattern to prevent duplicate operations.                │
    // │                                                                         │
    // │ Alternative without guard:                                              │
    // │   if isMonitoring { return }                                           │
    // │                                                                         │
    // │ Guard is preferred when the condition is a prerequisite to continue.  │
    // └─────────────────────────────────────────────────────────────────────────┘
    func startMonitoring() { guard !isMonitoring else { return }; isMonitoring = true; dataProvider.startHealthMonitoring() }
    func stopMonitoring() { isMonitoring = false; dataProvider.stopHealthMonitoring() }

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ FUNCTION WITH DEFAULT PARAMETER                                         │
    // │                                                                         │
    // │ hours: Int = 24 provides a default value.                              │
    // │ Can call: heartRateChartData() or heartRateChartData(hours: 1)        │
    // │                                                                         │
    // │ RETURNING TUPLES:                                                       │
    // │ -> [(date: Date, value: Int)] returns an array of named tuples.       │
    // │ Named tuples let you access .date and .value by name.                  │
    // │                                                                         │
    // │ The .map { } transforms HeartRateReading → tuple.                      │
    // └─────────────────────────────────────────────────────────────────────────┘
    func heartRateChartData(hours: Int = 24) -> [(date: Date, value: Int)] {
        let cutoff = Date().addingTimeInterval(TimeInterval(-hours * 3600))
        return heartRateHistory.filter { $0.timestamp >= cutoff }.map { (date: $0.timestamp, value: $0.value) }
    }
}
