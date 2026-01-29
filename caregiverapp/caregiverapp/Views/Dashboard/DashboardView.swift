//
//  DashboardView.swift
//  caregiverapp
//
//  ═══════════════════════════════════════════════════════════════════════════════
//  SWIFT BASICS: SWIFTUI VIEWS, MODIFIERS, AND LAYOUT
//  ═══════════════════════════════════════════════════════════════════════════════
//
//  SwiftUI Views are DECLARATIVE - you describe WHAT you want, not HOW to build it.
//  The system figures out the most efficient way to render and update.
//

import SwiftUI

struct DashboardView: View {

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ @State WITH @Observable CLASS                                           │
    // │                                                                         │
    // │ With @Observable (iOS 17+), you use @State for reference types too.    │
    // │ The view re-renders when any @Observable property it reads changes.    │
    // │                                                                         │
    // │ _viewModel = State(wrappedValue: ...) is the UNDERSCORE SYNTAX          │
    // │ for initializing property wrappers in init.                            │
    // │                                                                         │
    // │ Why not @StateObject?                                                   │
    // │ @StateObject is for ObservableObject (old pattern).                    │
    // │ @Observable classes work with plain @State.                            │
    // └─────────────────────────────────────────────────────────────────────────┘
    @State private var viewModel: DashboardViewModel

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ CUSTOM INITIALIZER FOR VIEWS                                            │
    // │                                                                         │
    // │ Views can have custom initializers to receive dependencies.            │
    // │ Here we receive the dataProvider and create the ViewModel.             │
    // │                                                                         │
    // │ _propertyName syntax is required for property wrapper init.            │
    // └─────────────────────────────────────────────────────────────────────────┘
    init(dataProvider: PatientDataProvider) {
        _viewModel = State(wrappedValue: DashboardViewModel(dataProvider: dataProvider))
    }

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ THE BODY PROPERTY                                                       │
    // │                                                                         │
    // │ Every View must have a 'body' that returns 'some View'.                │
    // │ 'some View' is an OPAQUE TYPE - it hides the specific return type.     │
    // │                                                                         │
    // │ The body is RECOMPUTED whenever @State/@Observable properties change.  │
    // │ But SwiftUI is smart - it only re-renders what actually changed.       │
    // └─────────────────────────────────────────────────────────────────────────┘
    var body: some View {

        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ ScrollView - SCROLLABLE CONTENT                                     │
        // │                                                                     │
        // │ ScrollView makes its content scrollable.                           │
        // │ Default direction is vertical. For horizontal: ScrollView(.horizontal)│
        // │                                                                     │
        // │ Unlike List, ScrollView doesn't provide automatic cell reuse.      │
        // │ Use List for long lists, ScrollView for custom layouts.            │
        // └─────────────────────────────────────────────────────────────────────┘
        ScrollView {

            // ┌─────────────────────────────────────────────────────────────────┐
            // │ VStack - VERTICAL STACK                                         │
            // │                                                                 │
            // │ VStack arranges children vertically (top to bottom).           │
            // │ HStack arranges horizontally (leading to trailing).            │
            // │ ZStack arranges in layers (back to front).                     │
            // │                                                                 │
            // │ VStack(spacing: 20) sets 20 points between each child.         │
            // │ Default spacing varies by context.                              │
            // │                                                                 │
            // │ VStack(alignment: .leading, spacing: 20) would left-align       │
            // │ children instead of centering them (default).                  │
            // └─────────────────────────────────────────────────────────────────┘
            VStack(spacing: 20) {
                // Components built as separate computed properties (see below)
                ConnectionStatusBanner(isConnected: viewModel.isConnected, statusText: viewModel.connectionStatusText)
                patientStatusCard
                quickActionsSection

                // ┌─────────────────────────────────────────────────────────────┐
                // │ CONDITIONAL RENDERING WITH 'if'                             │
                // │                                                             │
                // │ SwiftUI supports conditionals directly in view builders.   │
                // │ If the condition is false, the view isn't created at all.  │
                // │                                                             │
                // │ .filter { } keeps only elements matching the condition.    │
                // │ .isEmpty returns true if the array has no elements.        │
                // │ ! negates the boolean (isEmpty → isNotEmpty).              │
                // └─────────────────────────────────────────────────────────────┘
                if !viewModel.recentAlerts.filter({ $0.severity >= .high && !$0.isAcknowledged }).isEmpty { criticalAlertsSection }
                recentAlertsSection
                upcomingRemindersSection
                healthOverviewSection
            }
            // ┌─────────────────────────────────────────────────────────────────┐
            // │ .padding() MODIFIER                                             │
            // │                                                                 │
            // │ Adds space around the view.                                    │
            // │   .padding()         - Default padding on all sides            │
            // │   .padding(20)       - 20 points on all sides                  │
            // │   .padding(.horizontal)  - Only left and right                 │
            // │   .padding(.top, 10)     - 10 points only on top               │
            // └─────────────────────────────────────────────────────────────────┘
            .padding()
        }
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ MODIFIER ORDER MATTERS!                                             │
        // │                                                                     │
        // │ Modifiers are applied in order, from top to bottom.                │
        // │ Each modifier wraps the previous result.                           │
        // │                                                                     │
        // │ .background() then .padding() = Background THEN padding around it  │
        // │ .padding() then .background() = Padding THEN background behind all │
        // │                                                                     │
        // │ Here: background behind entire ScrollView content                  │
        // └─────────────────────────────────────────────────────────────────────┘
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Care Dashboard")

        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ .toolbar MODIFIER                                                   │
        // │                                                                     │
        // │ Adds items to the navigation bar (or other toolbars).              │
        // │                                                                     │
        // │ ToolbarItem(placement:) specifies where the item goes:             │
        // │   .topBarTrailing - Right side of navigation bar                   │
        // │   .topBarLeading  - Left side of navigation bar                    │
        // │   .bottomBar      - Bottom toolbar                                 │
        // │   .keyboard       - Above keyboard                                 │
        // │   .navigationBarBackButtonHidden - Replace back button             │
        // └─────────────────────────────────────────────────────────────────────┘
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(action: {}) { Image(systemName: "gearshape") } } }

        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ .refreshable MODIFIER (PULL TO REFRESH)                             │
        // │                                                                     │
        // │ Enables pull-to-refresh gesture on ScrollView.                     │
        // │ The closure is ASYNC - system shows loading indicator until done.  │
        // │                                                                     │
        // │ await viewModel.refresh() - Wait for the refresh to complete       │
        // └─────────────────────────────────────────────────────────────────────┘
        .refreshable { await viewModel.refresh() }

        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ VIEW LIFECYCLE MODIFIERS                                            │
        // │                                                                     │
        // │ .onAppear { } runs when view first appears on screen.              │
        // │ .onDisappear { } runs when view is removed from screen.            │
        // │                                                                     │
        // │ Perfect for:                                                        │
        // │   - Loading data when screen opens                                 │
        // │   - Starting/stopping timers or subscriptions                      │
        // │   - Analytics tracking                                             │
        // └─────────────────────────────────────────────────────────────────────┘
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
    }

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ COMPUTED PROPERTIES FOR VIEW SECTIONS                                   │
    // │                                                                         │
    // │ Breaking the body into smaller computed properties:                    │
    // │   1. Makes code more readable                                          │
    // │   2. Enables reuse                                                     │
    // │   3. Helps compiler performance (smaller function bodies)              │
    // │                                                                         │
    // │ 'private' restricts access to this file only.                          │
    // │ 'some View' lets Swift infer the specific view type.                   │
    // └─────────────────────────────────────────────────────────────────────────┘
    private var patientStatusCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    // ┌─────────────────────────────────────────────────────────┐
                    // │ NIL COALESCING IN VIEWS                                 │
                    // │                                                         │
                    // │ viewModel.patient?.name ?? "Patient"                    │
                    // │                                                         │
                    // │ If patient is nil OR name is nil, show "Patient"       │
                    // │ Optional chaining (?.) combined with nil coalescing    │
                    // └─────────────────────────────────────────────────────────┘
                    Text(viewModel.patient?.name ?? "Patient").font(.title2).fontWeight(.bold)
                    HStack(spacing: 4) {
                        // ┌─────────────────────────────────────────────────────┐
                        // │ SHAPES AND FRAMES                                   │
                        // │                                                     │
                        // │ Circle() is a built-in shape.                       │
                        // │ .fill(color) fills it with a color.                 │
                        // │ .frame(width:height:) sets the size.               │
                        // │                                                     │
                        // │ Other shapes: Rectangle, Capsule, RoundedRectangle, │
                        // │ Ellipse, or custom shapes with Path.                │
                        // └─────────────────────────────────────────────────────┘
                        Circle().fill(statusColor).frame(width: 8, height: 8)
                        Text("Status: \(viewModel.patientStatus.displayText)").font(.subheadline).foregroundStyle(.secondary)
                    }
                }

                // ┌─────────────────────────────────────────────────────────────┐
                // │ Spacer() - FLEXIBLE SPACE                                   │
                // │                                                             │
                // │ Spacer pushes other views apart. It expands to fill        │
                // │ available space.                                            │
                // │                                                             │
                // │ In HStack: Spacer() pushes items to opposite ends          │
                // │ In VStack: Spacer() pushes items to top/bottom             │
                // │                                                             │
                // │ Spacer(minLength: 10) sets a minimum size.                 │
                // └─────────────────────────────────────────────────────────────┘
                Spacer()

                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        // ┌─────────────────────────────────────────────────────┐
                        // │ SF SYMBOLS                                          │
                        // │                                                     │
                        // │ Image(systemName:) uses SF Symbols - Apple's free  │
                        // │ icon library with 4000+ icons.                      │
                        // │                                                     │
                        // │ Browse at: https://developer.apple.com/sf-symbols/ │
                        // │ Or download the SF Symbols app for Mac.            │
                        // │                                                     │
                        // │ Icons scale with text and support weights/sizes.   │
                        // └─────────────────────────────────────────────────────┘
                        Image(systemName: "heart.fill").foregroundStyle(.red)
                        Text("\(viewModel.healthData.heartRate.current)").font(.title).fontWeight(.bold).monospacedDigit()
                    }
                    Text("BPM").font(.caption).foregroundStyle(.secondary)
                }
            }

            // ┌─────────────────────────────────────────────────────────────────┐
            // │ Divider() - HORIZONTAL OR VERTICAL LINE                         │
            // │                                                                 │
            // │ Divider creates a thin line. In HStack it's vertical,          │
            // │ in VStack it's horizontal.                                     │
            // │                                                                 │
            // │ .frame(height: 40) constrains the Divider's height.            │
            // └─────────────────────────────────────────────────────────────────┘
            Divider()

            HStack(spacing: 0) {
                StatItem(icon: "figure.walk", value: formatNumber(viewModel.healthData.activity.steps), label: "Steps")
                Divider().frame(height: 40)
                StatItem(icon: "bed.double.fill", value: formatSleep(viewModel.healthData.activity.sleepHours), label: "Sleep")
                Divider().frame(height: 40)

                // ┌─────────────────────────────────────────────────────────────┐
                // │ TERNARY OPERATOR                                            │
                // │                                                             │
                // │ condition ? valueIfTrue : valueIfFalse                     │
                // │                                                             │
                // │ A compact if-else for expressions.                         │
                // │ viewModel.currentLocation?.isInSafeZone == true ? "Safe" : "Away"│
                // └─────────────────────────────────────────────────────────────┘
                StatItem(icon: "location.fill", value: viewModel.currentLocation?.isInSafeZone == true ? "Safe" : "Away", label: "Location")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ .clipShape() - MASK VIEW TO SHAPE                                   │
        // │                                                                     │
        // │ Clips the view to the given shape.                                 │
        // │ RoundedRectangle(cornerRadius: 16) creates rounded corners.        │
        // │                                                                     │
        // │ Alternative: .cornerRadius(16) but clipShape is more flexible.     │
        // └─────────────────────────────────────────────────────────────────────┘
        .clipShape(RoundedRectangle(cornerRadius: 16))
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ .shadow() - DROP SHADOW                                             │
        // │                                                                     │
        // │ Adds a shadow behind the view.                                     │
        // │   color: Shadow color (usually black with low opacity)             │
        // │   radius: Blur amount                                               │
        // │   x, y: Offset (y: 5 means shadow below)                           │
        // └─────────────────────────────────────────────────────────────────────┘
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ COMPUTED COLOR PROPERTY                                                 │
    // │                                                                         │
    // │ Using switch on an enum to return different colors.                    │
    // │ This centralizes the color logic for patient status.                   │
    // └─────────────────────────────────────────────────────────────────────────┘
    private var statusColor: Color {
        switch viewModel.patientStatus {
        case .normal: return .green
        case .warning: return .yellow
        case .needsAttention: return .red
        case .disconnected: return .gray
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) { Text("Quick Actions").font(.headline); QuickActionRow() }
    }

    private var criticalAlertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Urgent").font(.headline).foregroundStyle(.red)
            // ┌─────────────────────────────────────────────────────────────────┐
            // │ ForEach - ITERATE OVER COLLECTION                               │
            // │                                                                 │
            // │ ForEach creates views for each item in a collection.           │
            // │ Items must be Identifiable OR you must specify id:             │
            // │                                                                 │
            // │ ForEach(items) { item in ... }  // Identifiable items          │
            // │ ForEach(items, id: \.self) { item in ... }  // Hashable items  │
            // │ ForEach(items, id: \.someProperty) { ... }  // Custom id       │
            // │                                                                 │
            // │ PatientAlert is Identifiable (has 'id' property), so we can    │
            // │ use the simple form.                                           │
            // └─────────────────────────────────────────────────────────────────┘
            ForEach(viewModel.recentAlerts.filter { $0.severity >= .high && !$0.isAcknowledged }) { alert in
                // ┌─────────────────────────────────────────────────────────────┐
                // │ PASSING CLOSURES AS PARAMETERS                              │
                // │                                                             │
                // │ onAcknowledge: { viewModel.acknowledgeAlert(alert) }       │
                // │                                                             │
                // │ This creates a closure that captures 'alert' and calls     │
                // │ the ViewModel method. AlertCard will call this closure     │
                // │ when the user taps the acknowledge button.                 │
                // └─────────────────────────────────────────────────────────────┘
                AlertCard(alert: alert, onAcknowledge: { viewModel.acknowledgeAlert(alert) })
            }
        }
    }

    private var recentAlertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Recent Alerts").font(.headline); Spacer(); NavigationLink("View All") { Text("All Alerts") }.font(.subheadline) }
            if viewModel.recentAlerts.isEmpty {
                HStack { Spacer(); VStack(spacing: 8) { Image(systemName: "checkmark.circle.fill").font(.largeTitle).foregroundStyle(.green); Text("No active alerts").foregroundStyle(.secondary) }.padding(.vertical, 24); Spacer() }.background(Color(.systemBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 0) {
                    // ┌─────────────────────────────────────────────────────────┐
                    // │ CHAINING ARRAY OPERATIONS                               │
                    // │                                                         │
                    // │ .filter { ... }  - Keep only matching elements          │
                    // │ .prefix(3)       - Take first 3                         │
                    // │                                                         │
                    // │ The result is still iterable with ForEach.             │
                    // └─────────────────────────────────────────────────────────┘
                    ForEach(viewModel.recentAlerts.filter { $0.severity < .high || $0.isAcknowledged }.prefix(3)) { alert in
                        AlertRow(alert: alert, onAcknowledge: { viewModel.acknowledgeAlert(alert) })
                        // ┌─────────────────────────────────────────────────────┐
                        // │ CONDITIONAL IN VIEW BUILDER                         │
                        // │                                                     │
                        // │ Show divider only if this isn't the last item.     │
                        // │ alert.id != viewModel.recentAlerts.last?.id        │
                        // └─────────────────────────────────────────────────────┘
                        if alert.id != viewModel.recentAlerts.last?.id { Divider().padding(.leading, 52) }
                    }
                }.background(Color(.systemBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var upcomingRemindersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Upcoming Reminders").font(.headline); Spacer(); NavigationLink("View All") { Text("All Reminders") }.font(.subheadline) }
            if viewModel.upcomingReminders.isEmpty {
                Text("No upcoming reminders").foregroundStyle(.secondary).frame(maxWidth: .infinity).padding().background(Color(.systemBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 8) { ForEach(viewModel.upcomingReminders) { reminder in ReminderCard(reminder: reminder) } }
            }
        }
    }

    private var healthOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Health").font(.headline)
            // ┌─────────────────────────────────────────────────────────────────┐
            // │ LazyVGrid - GRID LAYOUT                                         │
            // │                                                                 │
            // │ Creates a grid that loads items lazily (on demand).            │
            // │ Columns define the grid structure.                              │
            // │                                                                 │
            // │ GridItem(.flexible()) = flexible width column                  │
            // │ Two flexible columns = 2-column grid that splits space evenly  │
            // │                                                                 │
            // │ Other GridItem options:                                         │
            // │   .fixed(100)        - Exactly 100 points wide                 │
            // │   .adaptive(minimum: 100) - As many as fit, min 100 each       │
            // └─────────────────────────────────────────────────────────────────┘
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(icon: "heart.fill", title: "Heart Rate", value: "\(viewModel.healthData.heartRate.min)-\(viewModel.healthData.heartRate.max)", unit: "BPM range", color: .red)
                StatCard(icon: "drop.fill", title: "Blood Oxygen", value: "\(viewModel.healthData.bloodOxygen ?? 0)", unit: "%", color: .blue)
                StatCard(icon: "flame.fill", title: "Calories", value: formatNumber(viewModel.healthData.activity.calories), unit: "kcal", color: .orange)
                StatCard(icon: "moon.fill", title: "Sleep Quality", value: sleepQuality, color: .indigo)
            }
        }
    }

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ HELPER FUNCTIONS                                                        │
    // │                                                                         │
    // │ These format data for display. Private because only this view uses them.│
    // │ They're functions (not computed properties) because they take parameters.│
    // └─────────────────────────────────────────────────────────────────────────┘
    private func formatNumber(_ number: Int) -> String { let f = NumberFormatter(); f.numberStyle = .decimal; return f.string(from: NSNumber(value: number)) ?? "\(number)" }
    private func formatSleep(_ hours: Double?) -> String { guard let hours = hours else { return "N/A" }; return String(format: "%.1fh", hours) }
    private var sleepQuality: String { guard let hours = viewModel.healthData.activity.sleepHours else { return "N/A" }; if hours >= 7 { return "Good" }; if hours >= 5 { return "Fair" }; return "Poor" }
}
