//
//  ActivityView.swift
//  caregiverapp
//

import SwiftUI

struct ActivityView: View {
    @State private var viewModel: HealthViewModel

    init(dataProvider: PatientDataProvider) {
        _viewModel = State(wrappedValue: HealthViewModel(dataProvider: dataProvider))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isInactivityConcerning { inactivityAlert }
                activitySummaryCard
                detailedStatsSection
                lastMovementSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Activity")
        .onAppear { viewModel.onAppear() }
    }

    private var inactivityAlert: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").font(.title2).foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) { Text("Prolonged Inactivity").font(.subheadline).fontWeight(.medium); Text("Patient has been stationary for \(viewModel.inactivityFormatted)").font(.caption).foregroundStyle(.secondary) }
            Spacer()
            Button("Send Reminder") {}.font(.caption).buttonStyle(.borderedProminent).tint(.orange)
        }
        .padding().background(Color.orange.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var activitySummaryCard: some View {
        VStack(spacing: 20) {
            HStack(spacing: 24) {
                ActivityRing(progress: Double(viewModel.steps) / 5000.0, color: .green, icon: "figure.walk", value: viewModel.stepsFormatted, label: "Steps")
                ActivityRing(progress: Double(viewModel.calories) / 1500.0, color: .red, icon: "flame.fill", value: "\(viewModel.calories)", label: "Calories")
                ActivityRing(progress: Double(viewModel.standingHours) / 12.0, color: .blue, icon: "figure.stand", value: "\(viewModel.standingHours)", label: "Standing")
            }
        }
        .padding().background(Color(.systemBackground)).clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var detailedStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(icon: "figure.walk", title: "Steps", value: viewModel.stepsFormatted, unit: "today", color: .green)
                StatCard(icon: "arrow.left.arrow.right", title: "Distance", value: viewModel.distanceFormatted, color: .blue)
                StatCard(icon: "flame.fill", title: "Active Calories", value: "\(viewModel.calories)", unit: "kcal", color: .red)
                StatCard(icon: "moon.fill", title: "Sleep", value: viewModel.sleepFormatted, unit: "last night", color: .indigo)
            }
        }
    }

    private var lastMovementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Movement Status").font(.headline)
            HStack {
                Image(systemName: "clock.fill").foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) { Text("Last Movement Detected").font(.subheadline); Text(viewModel.lastMovement, style: .relative).font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Text(viewModel.inactivityFormatted).font(.title3).fontWeight(.semibold).foregroundStyle(viewModel.isInactivityConcerning ? .orange : .primary)
            }
            .padding().background(Color(.systemBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct ActivityRing: View {
    let progress: Double; let color: Color; let icon: String; let value: String; let label: String

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(color.opacity(0.2), lineWidth: 8)
                Circle().trim(from: 0, to: min(progress, 1.0)).stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90))
                Image(systemName: icon).font(.title3).foregroundStyle(color)
            }.frame(width: 70, height: 70)
            VStack(spacing: 2) { Text(value).font(.subheadline).fontWeight(.semibold); Text(label).font(.caption2).foregroundStyle(.secondary) }
        }
    }
}
