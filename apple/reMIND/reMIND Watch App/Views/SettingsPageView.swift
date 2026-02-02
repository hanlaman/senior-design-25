//
//  SettingsPageView.swift
//  reMIND Watch App
//
//  Settings page with connection status and voice settings
//

import SwiftUI

struct SettingsPageView: View {
    let state: VoiceInteractionState

    @ObservedObject private var settingsManager = VoiceSettingsManager.shared

    // State for the picker binding
    @State private var selectedSpeed: SpeedPreset = .normal

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

            // Voice Settings Section
            Section {
                // Simple inline picker for speaking speed
                Picker(selection: $selectedSpeed) {
                    ForEach(SpeedPreset.allCases) { preset in
                        Text(preset.rawValue)
                            .tag(preset)
                    }
                } label: {
                    HStack {
                        Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                            .font(.title3)
                            .foregroundColor(.blue)
                        Text("Speaking Speed")
                            .font(.body)
                    }
                }
                .pickerStyle(.navigationLink)
                .onChange(of: selectedSpeed) { oldValue, newValue in
                    handleSpeedChange(newValue)
                }
            } header: {
                Text("Voice Settings")
            } footer: {
                Text("Reconnect required for changes to take effect")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.carousel)
        .onAppear {
            // Initialize picker selection from current settings
            selectedSpeed = SpeedPreset.from(rate: settingsManager.settings.speakingRate)
        }
    }

    // MARK: - Helper Functions

    private func handleSpeedChange(_ newSpeed: SpeedPreset) {
        // Haptic feedback for better accessibility
        WKInterfaceDevice.current().play(.click)

        // Save the new speed
        settingsManager.updateSpeakingRate(newSpeed.rate)
    }

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
    NavigationStack {
        SettingsPageView(state: .idle(sessionId: "preview-session"))
    }
}
