//
//  AlertRow.swift
//  caregiverapp
//

import SwiftUI

struct AlertRow: View {
    let alert: PatientAlert
    var onAcknowledge: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: alert.type.icon)
                .font(.title3)
                .foregroundStyle(alert.isAcknowledged ? .secondary : alert.type.color)
                .frame(width: 40, height: 40)
                .background((alert.isAcknowledged ? Color.gray : alert.type.color).opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(alert.title).font(.subheadline).fontWeight(.medium).foregroundStyle(alert.isAcknowledged ? .secondary : .primary)
                    if alert.severity >= .high && !alert.isAcknowledged {
                        Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red).font(.caption)
                    }
                }
                Text(alert.message).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(alert.timeAgo).font(.caption2).foregroundStyle(.secondary)
                if !alert.isAcknowledged {
                    Button("OK") { onAcknowledge?() }.font(.caption).buttonStyle(.bordered).controlSize(.mini)
                }
            }
        }
        .padding()
        .background(alert.severity == .critical && !alert.isAcknowledged ? Color.red.opacity(0.05) : Color.clear)
    }
}

struct AlertCard: View {
    let alert: PatientAlert
    var onAcknowledge: (() -> Void)?
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: alert.type.icon).font(.title2).foregroundStyle(alert.type.color)
                VStack(alignment: .leading) {
                    Text(alert.type.displayName).font(.caption).foregroundStyle(.secondary)
                    Text(alert.title).font(.headline)
                }
                Spacer()
                Text(alert.timeAgo).font(.caption).foregroundStyle(.secondary)
            }
            Text(alert.message).font(.subheadline).foregroundStyle(.secondary)
            if !alert.isAcknowledged {
                HStack {
                    Button(action: { onAcknowledge?() }) { Text("Acknowledge").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).tint(alert.type.color)
                    if alert.severity < .critical {
                        Button(action: { onDismiss?() }) { Text("Dismiss").frame(maxWidth: .infinity) }.buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(alert.severity == .critical ? Color.red : Color.clear, lineWidth: 2))
    }
}
