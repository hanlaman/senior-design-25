//
//  DashboardView.swift
//  caregiverapp
//

import SwiftUI

struct DashboardView: View {
    @State private var viewModel: DashboardViewModel

    init(dataProvider: PatientDataProvider) {
        _viewModel = State(wrappedValue: DashboardViewModel(dataProvider: dataProvider))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ConnectionStatusBanner(isConnected: viewModel.isConnected, statusText: viewModel.connectionStatusText)
                patientStatusCard
                quickActionsSection
                if !viewModel.recentAlerts.filter({ $0.severity >= .high && !$0.isAcknowledged }).isEmpty { criticalAlertsSection }
                recentAlertsSection
                upcomingRemindersSection
                healthOverviewSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Care Dashboard")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(action: {}) { Image(systemName: "gearshape") } } }
        .refreshable { await viewModel.refresh() }
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
    }

    private var patientStatusCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.patient?.name ?? "Patient").font(.title2).fontWeight(.bold)
                    HStack(spacing: 4) {
                        Circle().fill(statusColor).frame(width: 8, height: 8)
                        Text("Status: \(viewModel.patientStatus.displayText)").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill").foregroundStyle(.red)
                        Text("\(viewModel.healthData.heartRate.current)").font(.title).fontWeight(.bold).monospacedDigit()
                    }
                    Text("BPM").font(.caption).foregroundStyle(.secondary)
                }
            }
            Divider()
            HStack(spacing: 0) {
                StatItem(icon: "figure.walk", value: formatNumber(viewModel.healthData.activity.steps), label: "Steps")
                Divider().frame(height: 40)
                StatItem(icon: "bed.double.fill", value: formatSleep(viewModel.healthData.activity.sleepHours), label: "Sleep")
                Divider().frame(height: 40)
                StatItem(icon: "location.fill", value: viewModel.currentLocation?.isInSafeZone == true ? "Safe" : "Away", label: "Location")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

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
            ForEach(viewModel.recentAlerts.filter { $0.severity >= .high && !$0.isAcknowledged }) { alert in
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
                    ForEach(viewModel.recentAlerts.filter { $0.severity < .high || $0.isAcknowledged }.prefix(3)) { alert in
                        AlertRow(alert: alert, onAcknowledge: { viewModel.acknowledgeAlert(alert) })
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
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(icon: "heart.fill", title: "Heart Rate", value: "\(viewModel.healthData.heartRate.min)-\(viewModel.healthData.heartRate.max)", unit: "BPM range", color: .red)
                StatCard(icon: "drop.fill", title: "Blood Oxygen", value: "\(viewModel.healthData.bloodOxygen ?? 0)", unit: "%", color: .blue)
                StatCard(icon: "flame.fill", title: "Calories", value: formatNumber(viewModel.healthData.activity.calories), unit: "kcal", color: .orange)
                StatCard(icon: "moon.fill", title: "Sleep Quality", value: sleepQuality, color: .indigo)
            }
        }
    }

    private func formatNumber(_ number: Int) -> String { let f = NumberFormatter(); f.numberStyle = .decimal; return f.string(from: NSNumber(value: number)) ?? "\(number)" }
    private func formatSleep(_ hours: Double?) -> String { guard let hours = hours else { return "N/A" }; return String(format: "%.1fh", hours) }
    private var sleepQuality: String { guard let hours = viewModel.healthData.activity.sleepHours else { return "N/A" }; if hours >= 7 { return "Good" }; if hours >= 5 { return "Fair" }; return "Poor" }
}
