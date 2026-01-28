//
//  HeartRateView.swift
//  caregiverapp
//

import SwiftUI
import Charts

struct HeartRateView: View {
    @State private var viewModel: HealthViewModel
    @State private var selectedTimeRange: TimeRange = .day

    init(dataProvider: PatientDataProvider) {
        _viewModel = State(wrappedValue: HealthViewModel(dataProvider: dataProvider))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) { currentHeartRateCard; heartRateChart; statsSection; historySection }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Heart Rate")
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
    }

    private var currentHeartRateCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current").font(.subheadline).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "heart.fill").font(.title).foregroundStyle(.red).symbolEffect(.pulse)
                        Text("\(viewModel.currentHeartRate)").font(.system(size: 56, weight: .bold)).monospacedDigit()
                        Text("BPM").font(.title3).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(spacing: 4) { Circle().fill(statusColor).frame(width: 12, height: 12); Text(viewModel.heartRateStatus.rawValue).font(.caption).foregroundStyle(.secondary) }
            }
            HStack {
                Text("Updated \(viewModel.lastUpdatedFormatted)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if viewModel.isMonitoring { HStack(spacing: 4) { Circle().fill(.green).frame(width: 6, height: 6); Text("Live").font(.caption).foregroundStyle(.green) } }
            }
        }
        .padding().background(Color(.systemBackground)).clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var statusColor: Color {
        switch viewModel.heartRateStatus { case .low: return .blue; case .normal: return .green; case .high: return .red }
    }

    private var heartRateChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Trend").font(.headline)
                Spacer()
                Picker("Time Range", selection: $selectedTimeRange) { ForEach(TimeRange.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented).frame(width: 150)
            }
            Chart {
                ForEach(viewModel.heartRateChartData(hours: selectedTimeRange.hours), id: \.date) { reading in
                    LineMark(x: .value("Time", reading.date), y: .value("BPM", reading.value)).foregroundStyle(.red)
                    AreaMark(x: .value("Time", reading.date), y: .value("BPM", reading.value)).foregroundStyle(.linearGradient(colors: [.red.opacity(0.3), .red.opacity(0.0)], startPoint: .top, endPoint: .bottom))
                }
                RuleMark(y: .value("Low Normal", 60)).foregroundStyle(.green.opacity(0.3)).lineStyle(StrokeStyle(dash: [5, 5]))
                RuleMark(y: .value("High Normal", 100)).foregroundStyle(.green.opacity(0.3)).lineStyle(StrokeStyle(dash: [5, 5]))
            }
            .chartYScale(domain: 40...120).frame(height: 200)
        }
        .padding().background(Color(.systemBackground)).clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Stats").font(.headline)
            HStack(spacing: 12) { StatCard(icon: "arrow.down", title: "Minimum", value: "\(viewModel.healthData.heartRate.min)", unit: "BPM", color: .blue); StatCard(icon: "arrow.up", title: "Maximum", value: "\(viewModel.healthData.heartRate.max)", unit: "BPM", color: .orange) }
            HStack(spacing: 12) { StatCard(icon: "waveform.path.ecg", title: "Range", value: viewModel.heartRateRange, unit: "BPM", color: .purple); StatCard(icon: "chart.line.uptrend.xyaxis", title: "Readings", value: "\(viewModel.heartRateHistory.count)", color: .gray) }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Readings").font(.headline)
            VStack(spacing: 0) {
                ForEach(viewModel.heartRateHistory.suffix(10).reversed()) { reading in
                    HStack { Text("\(reading.value) BPM").font(.subheadline).fontWeight(.medium); Spacer(); Text(reading.timestamp, style: .time).font(.caption).foregroundStyle(.secondary) }.padding()
                    Divider()
                }
            }.background(Color(.systemBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

enum TimeRange: String, CaseIterable { case hour = "1H", day = "24H", week = "7D"; var hours: Int { switch self { case .hour: return 1; case .day: return 24; case .week: return 168 } } }
