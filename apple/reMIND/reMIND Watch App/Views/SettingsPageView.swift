//
//  SettingsPageView.swift
//  reMIND Watch App
//
//  Settings page with connection status and settings list
//

import SwiftUI

struct SettingsPageView: View {
    let state: VoiceInteractionState

    var body: some View {
        List {
            // Connection Status Section
            Section {
                HStack {
                    Image(systemName: wifiSymbol(for: state))
                        .foregroundColor(statusColor(for: state))
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connection")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(connectionStatusText(for: state))
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(statusColor(for: state))
                    }
                }
            }
        }
        .listStyle(.carousel)
    }

    // MARK: - Helper Functions

    private func wifiSymbol(for state: VoiceInteractionState) -> String {
        switch state {
        case .disconnected:
            return "wifi.slash"
        case .connecting:
            return "wifi.exclamationmark"
        case .connectionFailed:
            return "wifi.exclamationmark"
        case .idle, .recording, .processing, .playing:
            return "wifi"
        case .error:
            return "wifi.exclamationmark"
        }
    }

    private func statusColor(for state: VoiceInteractionState) -> Color {
        switch state {
        case .disconnected:
            return .gray
        case .connecting:
            return .orange
        case .connectionFailed:
            return .red
        case .idle, .recording, .processing, .playing:
            return .green
        case .error:
            return .red
        }
    }

    private func connectionStatusText(for state: VoiceInteractionState) -> String {
        switch state {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connectionFailed(let message):
            return "Failed: \(message)"
        case .idle, .recording, .processing, .playing:
            return "Connected"
        case .error(_, let message):
            return "Error: \(message)"
        }
    }
}

#Preview {
    SettingsPageView(state: .idle(sessionId: "preview-session"))
}
