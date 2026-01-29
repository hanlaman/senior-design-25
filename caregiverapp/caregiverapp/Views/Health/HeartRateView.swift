//
//  HeartRateView.swift
//  caregiverapp
//
//  ═══════════════════════════════════════════════════════════════════════════════
//  SWIFT BASICS: SWIFT CHARTS AND PICKER CONTROLS
//  ═══════════════════════════════════════════════════════════════════════════════

import SwiftUI
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ CHARTS FRAMEWORK                                                            │
// │                                                                             │
// │ Swift Charts (iOS 16+) provides declarative chart creation.                │
// │ It's SwiftUI-native, so charts are just views with data-driven marks.      │
// │                                                                             │
// │ Available mark types:                                                       │
// │   - LineMark (line chart)                                                  │
// │   - BarMark (bar chart)                                                    │
// │   - PointMark (scatter plot)                                               │
// │   - AreaMark (filled area under line)                                      │
// │   - RectangleMark (heat maps)                                              │
// │   - RuleMark (horizontal/vertical reference lines)                         │
// └─────────────────────────────────────────────────────────────────────────────┘
import Charts

struct HeartRateView: View {
    @State private var viewModel: HealthViewModel

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ @State FOR PICKER SELECTION                                             │
    // │                                                                         │
    // │ This tracks which time range is selected in the segmented picker.      │
    // │ When it changes, the chart updates to show different data.             │
    // └─────────────────────────────────────────────────────────────────────────┘
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
                        // ┌─────────────────────────────────────────────────────┐
                        // │ SF SYMBOL EFFECTS                                   │
                        // │                                                     │
                        // │ .symbolEffect(.pulse) adds animation to SF Symbols. │
                        // │ The heart icon pulses to simulate a heartbeat.     │
                        // │                                                     │
                        // │ Other effects:                                      │
                        // │   .bounce      - Bouncy animation                   │
                        // │   .scale       - Grows/shrinks                      │
                        // │   .variableColor - Animates multi-color symbols     │
                        // │   .replace     - Animates symbol changes            │
                        // └─────────────────────────────────────────────────────┘
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

                // ┌─────────────────────────────────────────────────────────────┐
                // │ PICKER WITH SEGMENTED STYLE                                 │
                // │                                                             │
                // │ Picker creates a selection control.                         │
                // │ .pickerStyle(.segmented) makes it a segmented control.     │
                // │                                                             │
                // │ 'selection: $selectedTimeRange' is a two-way binding -     │
                // │ Picker both reads AND writes to selectedTimeRange.         │
                // │                                                             │
                // │ ForEach creates options from the enum's allCases.          │
                // │ .tag() associates each Text with its enum value.           │
                // │                                                             │
                // │ Other picker styles:                                        │
                // │   .menu        - Dropdown menu                              │
                // │   .wheel       - iOS-style scroll wheel                     │
                // │   .inline      - Embedded in form                           │
                // │   .automatic   - Platform default                           │
                // └─────────────────────────────────────────────────────────────┘
                Picker("Time Range", selection: $selectedTimeRange) { ForEach(TimeRange.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented).frame(width: 150)
            }

            // ┌─────────────────────────────────────────────────────────────────┐
            // │ Chart { } - SWIFT CHARTS                                        │
            // │                                                                 │
            // │ Chart is a container for chart marks.                          │
            // │ Inside, you create marks for your data points.                 │
            // │                                                                 │
            // │ Each mark has:                                                   │
            // │   x: .value("Label", xValue) - X-axis position                 │
            // │   y: .value("Label", yValue) - Y-axis position                 │
            // │                                                                 │
            // │ You can layer multiple marks for combined visualizations.      │
            // └─────────────────────────────────────────────────────────────────┘
            Chart {
                // ┌─────────────────────────────────────────────────────────────┐
                // │ ForEach IN CHART                                            │
                // │                                                             │
                // │ ForEach iterates over data to create marks.                │
                // │ id: \.date uniquely identifies each data point.            │
                // │                                                             │
                // │ viewModel.heartRateChartData(hours:) returns tuples:       │
                // │   (date: Date, value: Int)                                 │
                // └─────────────────────────────────────────────────────────────┘
                ForEach(viewModel.heartRateChartData(hours: selectedTimeRange.hours), id: \.date) { reading in
                    // ┌─────────────────────────────────────────────────────────┐
                    // │ LineMark - LINE CHART                                   │
                    // │                                                         │
                    // │ Creates a line connecting all data points.             │
                    // │ .foregroundStyle(.red) colors the line red.            │
                    // └─────────────────────────────────────────────────────────┘
                    LineMark(x: .value("Time", reading.date), y: .value("BPM", reading.value)).foregroundStyle(.red)

                    // ┌─────────────────────────────────────────────────────────┐
                    // │ AreaMark - FILLED AREA                                  │
                    // │                                                         │
                    // │ Fills the area below the line with a gradient.         │
                    // │ Combined with LineMark for a polished look.            │
                    // │                                                         │
                    // │ .linearGradient creates a color gradient:              │
                    // │   - Red at top (opacity 0.3)                            │
                    // │   - Fading to transparent at bottom                    │
                    // └─────────────────────────────────────────────────────────┘
                    AreaMark(x: .value("Time", reading.date), y: .value("BPM", reading.value)).foregroundStyle(.linearGradient(colors: [.red.opacity(0.3), .red.opacity(0.0)], startPoint: .top, endPoint: .bottom))
                }

                // ┌─────────────────────────────────────────────────────────────┐
                // │ RuleMark - REFERENCE LINES                                  │
                // │                                                             │
                // │ RuleMark creates horizontal or vertical lines.             │
                // │ Perfect for showing thresholds, averages, or targets.      │
                // │                                                             │
                // │ y: .value(...) creates a horizontal line                   │
                // │ x: .value(...) would create a vertical line                │
                // │                                                             │
                // │ .lineStyle(StrokeStyle(dash: [5, 5])) makes it dashed.     │
                // └─────────────────────────────────────────────────────────────┘
                RuleMark(y: .value("Low Normal", 60)).foregroundStyle(.green.opacity(0.3)).lineStyle(StrokeStyle(dash: [5, 5]))
                RuleMark(y: .value("High Normal", 100)).foregroundStyle(.green.opacity(0.3)).lineStyle(StrokeStyle(dash: [5, 5]))
            }
            // ┌─────────────────────────────────────────────────────────────────┐
            // │ CHART MODIFIERS                                                 │
            // │                                                                 │
            // │ .chartYScale(domain: 40...120) sets Y-axis range.             │
            // │ Without this, the chart would auto-scale to data.             │
            // │ Fixed range makes charts comparable over time.                 │
            // │                                                                 │
            // │ .frame(height: 200) gives the chart a fixed height.           │
            // │ Charts expand to fill available width by default.             │
            // └─────────────────────────────────────────────────────────────────┘
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
                // ┌─────────────────────────────────────────────────────────────┐
                // │ ARRAY OPERATIONS: suffix, reversed                          │
                // │                                                             │
                // │ .suffix(10) - Take the LAST 10 elements                    │
                // │ .reversed() - Reverse the order (newest first)             │
                // │                                                             │
                // │ Combined: Last 10 readings, most recent at top             │
                // └─────────────────────────────────────────────────────────────┘
                ForEach(viewModel.heartRateHistory.suffix(10).reversed()) { reading in
                    HStack { Text("\(reading.value) BPM").font(.subheadline).fontWeight(.medium); Spacer(); Text(reading.timestamp, style: .time).font(.caption).foregroundStyle(.secondary) }.padding()
                    Divider()
                }
            }.background(Color(.systemBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ ENUM FOR PICKER OPTIONS                                                     │
// │                                                                             │
// │ CaseIterable provides .allCases for iteration.                             │
// │ Raw value (String) is displayed in the picker.                             │
// │                                                                             │
// │ The computed property 'hours' converts the selection to an Int            │
// │ for use in data filtering.                                                 │
// └─────────────────────────────────────────────────────────────────────────────┘
enum TimeRange: String, CaseIterable { case hour = "1H", day = "24H", week = "7D"; var hours: Int { switch self { case .hour: return 1; case .day: return 24; case .week: return 168 } } }
