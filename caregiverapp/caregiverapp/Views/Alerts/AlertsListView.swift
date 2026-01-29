//
//  AlertsListView.swift
//  caregiverapp
//

import SwiftUI

struct AlertsListView: View {
    @State private var viewModel: AlertsViewModel
    @State private var filterType: AlertType?
    @State private var showingClearConfirmation = false

    init(dataProvider: PatientDataProvider) {
        _viewModel = State(wrappedValue: AlertsViewModel(dataProvider: dataProvider))
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            if viewModel.alerts.isEmpty { emptyState } else { alertsList }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Alerts")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Menu { Button("Acknowledge All") { viewModel.acknowledgeAll() }; Button("Clear All", role: .destructive) { showingClearConfirmation = true } } label: { Image(systemName: "ellipsis.circle") } } }
        .confirmationDialog("Clear all alerts?", isPresented: $showingClearConfirmation) { Button("Clear All", role: .destructive) { viewModel.clearAll() } }
        .onAppear { viewModel.onAppear() }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: filterType == nil, count: viewModel.alerts.count) { filterType = nil }
                ForEach(AlertType.allCases, id: \.self) { type in
                    let count = viewModel.filterAlerts(by: type).count
                    if count > 0 { FilterChip(title: type.displayName, isSelected: filterType == type, count: count, color: type.color) { filterType = type } }
                }
            }.padding()
        }.background(Color(.systemBackground))
    }

    private var emptyState: some View {
        VStack(spacing: 16) { Spacer(); Image(systemName: "checkmark.circle.fill").font(.system(size: 60)).foregroundStyle(.green); Text("No Alerts").font(.title2).fontWeight(.semibold); Text("Everything looks good!").foregroundStyle(.secondary); Spacer() }
    }

    private var alertsList: some View {
        List {
            let criticalAlerts = viewModel.filterAlerts(by: filterType).filter { $0.severity == .critical && !$0.isAcknowledged }
            if !criticalAlerts.isEmpty {
                Section { ForEach(criticalAlerts) { alert in AlertListRow(alert: alert) { viewModel.acknowledge(alert) } onClear: { viewModel.clear(alert) } } } header: { Label("Critical", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red) }
            }
            ForEach(viewModel.groupedAlerts) { group in
                let filteredAlerts = group.alerts.filter { filterType == nil || $0.type == filterType }.filter { $0.severity != .critical || $0.isAcknowledged }
                if !filteredAlerts.isEmpty {
                    Section(group.dateFormatted) { ForEach(filteredAlerts) { alert in AlertListRow(alert: alert) { viewModel.acknowledge(alert) } onClear: { viewModel.clear(alert) } } }
                }
            }
        }.listStyle(.insetGrouped)
    }
}

struct FilterChip: View {
    let title: String; let isSelected: Bool; var count: Int = 0; var color: Color = .blue; let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title).font(.subheadline)
                if count > 0 { Text("\(count)").font(.caption2).padding(.horizontal, 6).padding(.vertical, 2).background(isSelected ? .white.opacity(0.3) : color.opacity(0.2)).clipShape(Capsule()) }
            }
            .padding(.horizontal, 12).padding(.vertical, 8).background(isSelected ? color : Color(.secondarySystemBackground)).foregroundStyle(isSelected ? .white : .primary).clipShape(Capsule())
        }
    }
}

struct AlertListRow: View {
    let alert: PatientAlert; let onAcknowledge: () -> Void; let onClear: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: alert.type.icon).font(.title3).foregroundStyle(alert.isAcknowledged ? .secondary : alert.type.color).frame(width: 36, height: 36).background((alert.isAcknowledged ? Color.gray : alert.type.color).opacity(0.1)).clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                HStack { Text(alert.title).font(.subheadline).fontWeight(.medium).foregroundStyle(alert.isAcknowledged ? .secondary : .primary); if alert.severity >= .high && !alert.isAcknowledged { Image(systemName: "exclamationmark.circle.fill").font(.caption).foregroundStyle(.red) } }
                Text(alert.message).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                Text(alert.timestamp, style: .relative).font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .swipeActions(edge: .trailing) { Button(role: .destructive) { onClear() } label: { Label("Clear", systemImage: "trash") }; if !alert.isAcknowledged { Button { onAcknowledge() } label: { Label("OK", systemImage: "checkmark") }.tint(.green) } }
    }
}
