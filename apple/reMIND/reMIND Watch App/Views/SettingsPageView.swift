//
//  SettingsPageView.swift
//  reMIND Watch App
//
//  Settings page with connection status and settings list
//

import SwiftUI

struct SettingsPageView: View {
    let connectionState: ConnectionState

    var body: some View {
        List {
            // Connection Status Section
            Section {
                HStack {
                    Image(systemName: wifiSymbol(for: connectionState))
                        .foregroundColor(statusColor(for: connectionState))
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connection")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(connectionState.displayText)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(statusColor(for: connectionState))
                    }
                }
            }
        }
        .listStyle(.carousel)
    }

    // MARK: - Helper Functions

    private func wifiSymbol(for state: ConnectionState) -> String {
        switch state {
        case .connected:
            return "wifi"
        case .connecting:
            return "wifi.exclamationmark"
        case .disconnected:
            return "wifi.slash"
        case .error:
            return "wifi.exclamationmark"
        }
    }

    private func statusColor(for state: ConnectionState) -> Color {
        switch state {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected:
            return .gray
        case .error:
            return .red
        }
    }
}

#Preview {
    SettingsPageView(connectionState: .connected)
}
