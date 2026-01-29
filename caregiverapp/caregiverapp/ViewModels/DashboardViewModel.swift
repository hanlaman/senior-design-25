//
//  DashboardViewModel.swift
//  caregiverapp
//
//  ═══════════════════════════════════════════════════════════════════════════════
//  SWIFT BASICS: VIEWMODELS, @Observable, AND COMBINE SUBSCRIPTIONS
//  ═══════════════════════════════════════════════════════════════════════════════
//
//  ViewModels bridge your data (Models/Services) and your UI (Views).
//  They:
//    - Fetch and transform data for display
//    - Handle user actions
//    - Manage view state (loading, errors)
//    - Keep Views simple and focused on layout
//

import Foundation
import Combine

@MainActor
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ @Observable MACRO (Swift 5.9+)                                              │
// │                                                                             │
// │ @Observable is a MACRO that auto-generates observation code.               │
// │ When properties change, SwiftUI automatically re-renders views.            │
// │                                                                             │
// │ BEFORE @Observable (iOS 16-):                                               │
// │   class ViewModel: ObservableObject {                                      │
// │       @Published var data: String = ""                                     │
// │   }                                                                         │
// │   // In View: @StateObject or @ObservedObject                              │
// │                                                                             │
// │ WITH @Observable (iOS 17+):                                                 │
// │   @Observable class ViewModel {                                            │
// │       var data: String = ""  // No @Published needed!                      │
// │   }                                                                         │
// │   // In View: Just @State                                                   │
// │                                                                             │
// │ Benefits of @Observable:                                                    │
// │   - Less boilerplate (no @Published everywhere)                            │
// │   - More efficient (only re-renders views using changed properties)        │
// │   - Simpler view code                                                      │
// └─────────────────────────────────────────────────────────────────────────────┘
@Observable
final class DashboardViewModel {

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ private(set) - READ-ONLY FROM OUTSIDE                                   │
    // │                                                                         │
    // │ Views can READ these properties but only the ViewModel can WRITE.      │
    // │ This enforces unidirectional data flow:                                │
    // │   User Action → ViewModel Method → Update Properties → View Re-renders │
    // │                                                                         │
    // │ Views should NEVER directly modify ViewModel properties.               │
    // │ Instead, they call methods like acknowledgeAlert().                    │
    // └─────────────────────────────────────────────────────────────────────────┘
    private(set) var patient: Patient?
    private(set) var healthData: HealthData = HealthData()
    private(set) var currentLocation: PatientLocation?
    private(set) var recentAlerts: [PatientAlert] = []
    private(set) var upcomingReminders: [Reminder] = []
    private(set) var isConnected: Bool = true
    private(set) var lastSyncTime: Date?
    private(set) var isLoading: Bool = false
    private(set) var error: Error?

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ DEPENDENCY INJECTION                                                    │
    // │                                                                         │
    // │ The ViewModel receives a PatientDataProvider (protocol type).          │
    // │ It doesn't know or care if it's Mock or Firebase - it just uses        │
    // │ the protocol methods.                                                   │
    // │                                                                         │
    // │ 'private let' means:                                                    │
    // │   - Only this class can access it                                      │
    // │   - It can never be reassigned                                         │
    // └─────────────────────────────────────────────────────────────────────────┘
    private let dataProvider: PatientDataProvider

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ AnyCancellable - COMBINE SUBSCRIPTION STORAGE                           │
    // │                                                                         │
    // │ When you subscribe to a publisher, you get an AnyCancellable.          │
    // │ You MUST store it - if it's deallocated, the subscription is canceled. │
    // │                                                                         │
    // │ Set<AnyCancellable> is a common pattern to store multiple subscriptions.│
    // │ When the ViewModel is deallocated, all subscriptions are automatically │
    // │ canceled.                                                               │
    // │                                                                         │
    // │ .store(in: &cancellables) adds the subscription to this set.           │
    // └─────────────────────────────────────────────────────────────────────────┘
    private var cancellables = Set<AnyCancellable>()

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ COMPUTED PROPERTIES FOR VIEW LOGIC                                      │
    // │                                                                         │
    // │ ViewModels often have computed properties that derive view-specific    │
    // │ information from raw data. This keeps Views simple.                    │
    // └─────────────────────────────────────────────────────────────────────────┘
    var patientStatus: PatientStatus {
        // Check conditions in order of priority
        if !isConnected { return .disconnected }
        if recentAlerts.contains(where: { $0.severity >= .high && !$0.isAcknowledged }) { return .needsAttention }
        if healthData.heartRate.status.isAbnormal { return .warning }
        return .normal
    }

    var connectionStatusText: String {
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ NESTED IF-LET                                                       │
        // │                                                                     │
        // │ if let lastSync = lastSyncTime {                                   │
        // │     // lastSync is non-optional here                               │
        // │ }                                                                   │
        // │                                                                     │
        // │ This pattern unwraps the optional and gives you a safe value.      │
        // └─────────────────────────────────────────────────────────────────────┘
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

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ COMBINE SUBSCRIPTIONS                                                   │
    // │                                                                         │
    // │ This method sets up reactive data flow using Combine.                  │
    // │ When the dataProvider publishes new data, our properties update.       │
    // │                                                                         │
    // │ CHAIN EXPLANATION:                                                      │
    // │   dataProvider.healthDataPublisher    // Get the publisher             │
    // │       .receive(on: DispatchQueue.main)  // Ensure main thread          │
    // │       .sink { value in ... }            // Handle each new value       │
    // │       .store(in: &cancellables)         // Store to keep alive         │
    // │                                                                         │
    // │ .sink creates a subscription that calls the closure for each value.   │
    // │ [weak self] prevents retain cycles (ViewModel → closure → ViewModel).  │
    // └─────────────────────────────────────────────────────────────────────────┘
    private func setupBindings() {
        dataProvider.healthDataPublisher.receive(on: DispatchQueue.main).sink { [weak self] in self?.healthData = $0 }.store(in: &cancellables)
        dataProvider.locationPublisher.receive(on: DispatchQueue.main).sink { [weak self] in self?.currentLocation = $0 }.store(in: &cancellables)

        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ SHORTHAND CLOSURE SYNTAX                                            │
        // │                                                                     │
        // │ .sink { [weak self] in self?.recentAlerts = Array($0.prefix(5)) }  │
        // │                                                                     │
        // │ $0 is the first (and only) parameter - the new alerts array.       │
        // │ Array($0.prefix(5)) takes the first 5 alerts.                      │
        // │                                                                     │
        // │ Full syntax would be:                                               │
        // │   .sink { [weak self] (alerts: [PatientAlert]) in                  │
        // │       self?.recentAlerts = Array(alerts.prefix(5))                 │
        // │   }                                                                 │
        // └─────────────────────────────────────────────────────────────────────┘
        dataProvider.alertsPublisher.receive(on: DispatchQueue.main).sink { [weak self] in self?.recentAlerts = Array($0.prefix(5)) }.store(in: &cancellables)

        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ MULTI-LINE CLOSURE WITH TRANSFORMATION                              │
        // │                                                                     │
        // │ This closure does several transformations:                          │
        // │   1. Filter out completed reminders                                 │
        // │   2. Filter out disabled reminders                                  │
        // │   3. Sort by scheduled time                                         │
        // │   4. Take the first 3                                               │
        // │   5. Convert to Array                                               │
        // │                                                                     │
        // │ CHAINED ARRAY OPERATIONS:                                           │
        // │   .filter { condition }  - Keep elements where condition is true   │
        // │   .sorted { a, b in compare }  - Sort with custom comparison       │
        // │   .prefix(n)  - Take first n elements (returns ArraySlice)         │
        // │   .map { }  - Transform each element (here: identity, for Array)   │
        // └─────────────────────────────────────────────────────────────────────┘
        dataProvider.remindersPublisher.receive(on: DispatchQueue.main).sink { [weak self] reminders in
            self?.upcomingReminders = reminders.filter { !$0.isCompleted && $0.isEnabled }.sorted { $0.scheduledTime < $1.scheduledTime }.prefix(3).map { $0 }
        }.store(in: &cancellables)

        dataProvider.connectionPublisher.receive(on: DispatchQueue.main).sink { [weak self] in self?.isConnected = $0 }.store(in: &cancellables)
    }

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ VIEW LIFECYCLE METHODS                                                  │
    // │                                                                         │
    // │ These are called from SwiftUI's .onAppear and .onDisappear modifiers.  │
    // │ They handle setup and cleanup for the view's lifetime.                 │
    // │                                                                         │
    // │ onAppear:                                                               │
    // │   - Load initial data                                                   │
    // │   - Start real-time updates                                            │
    // │                                                                         │
    // │ onDisappear:                                                            │
    // │   - Stop updates to save battery/resources                             │
    // └─────────────────────────────────────────────────────────────────────────┘
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

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ ACTION METHODS                                                          │
    // │                                                                         │
    // │ Views call these methods when users interact.                          │
    // │ The ViewModel handles the business logic.                              │
    // └─────────────────────────────────────────────────────────────────────────┘
    func acknowledgeAlert(_ alert: PatientAlert) {
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ Task { }                                                            │
        // │                                                                     │
        // │ Creates an asynchronous context from synchronous code.             │
        // │ We need this because acknowledgeAlert is async.                    │
        // │                                                                     │
        // │ try? ignores errors (returns nil instead of throwing).             │
        // │ This is a simple way to call async functions when you don't        │
        // │ need to handle errors specifically.                                │
        // └─────────────────────────────────────────────────────────────────────┘
        Task { try? await dataProvider.acknowledgeAlert(id: alert.id) }
    }

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ ASYNC FUNCTION WITH LOADING STATE                                       │
    // │                                                                         │
    // │ 'async' means this function can be awaited.                            │
    // │ It's called from SwiftUI's .refreshable modifier.                      │
    // │                                                                         │
    // │ DEFER STATEMENT:                                                        │
    // │   defer { isLoading = false }                                          │
    // │                                                                         │
    // │ Code in defer runs when the scope exits - whether by:                  │
    // │   - Normal completion (reaching the end)                               │
    // │   - Early return                                                       │
    // │   - Throwing an error                                                  │
    // │                                                                         │
    // │ This guarantees isLoading is set to false even if something fails.    │
    // └─────────────────────────────────────────────────────────────────────────┘
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ Task.sleep - ASYNC SLEEP                                            │
        // │                                                                     │
        // │ Unlike Thread.sleep, Task.sleep doesn't block the thread.          │
        // │ Other tasks can run while this one "sleeps".                       │
        // │                                                                     │
        // │ The parameter is in nanoseconds:                                   │
        // │   500_000_000 nanoseconds = 0.5 seconds                            │
        // │                                                                     │
        // │ Underscores in numbers are for readability (like commas in 500,000)│
        // └─────────────────────────────────────────────────────────────────────┘
        try? await Task.sleep(nanoseconds: 500_000_000)
        lastSyncTime = dataProvider.lastSyncTime
    }
}

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ SIMPLE ENUM FOR VIEW STATE                                                  │
// │                                                                             │
// │ This enum represents the overall patient status for the dashboard.         │
// │ It simplifies the view logic - instead of checking multiple conditions,    │
// │ the view just checks the status enum.                                      │
// └─────────────────────────────────────────────────────────────────────────────┘
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
