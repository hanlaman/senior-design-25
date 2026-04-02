//
//  SettingsPageView.swift
//  reMIND Watch App
//
//  Settings page with connection status and voice settings
//

import SwiftUI
import WatchKit

struct SettingsPageView: View {
    @ObservedObject var viewModel: VoiceViewModel
    @ObservedObject var locationViewModel: LocationViewModel
    @Binding var currentPage: ContentView.NavigationPage?

    @ObservedObject private var settingsManager = VoiceSettingsManager.shared

    // Computed property for cleaner access to state
    private var state: VoiceInteractionState { viewModel.state }

    // State for the picker binding
    @State private var selectedSpeed: SpeedPreset = .normal
    @State private var continuousListeningEnabled: Bool = false

    var body: some View {
        List {
            // Location Tracking Section
            Section {
                HStack {
                    Image(systemName: locationViewModel.isTracking ? "location.fill" : "location.slash")
                        .foregroundColor(locationViewModel.isTracking ? .green : .gray)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(locationViewModel.isTracking ? locationViewModel.locationText : "Not tracking")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(locationViewModel.isTracking ? .green : .gray)
                    }
                }
            }

            // Agent Settings Section
            Section {
                // Connection Status Row (tappable - performs action directly)
                Button {
                    WKInterfaceDevice.current().play(.click)
                    handleConnectionTap()
                } label: {
                    HStack {
                        Image(systemName: wifiSymbol(for: state))
                            .font(.title3)
                            .foregroundColor(statusColor(for: state))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(connectionStatusText(for: state))
                                .font(.body)
                                .foregroundColor(.primary)
                            Text(connectionActionHint(for: state))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(!canPerformConnectionAction(for: state))

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

                Toggle(isOn: $continuousListeningEnabled) {
                    HStack {
                        Image(systemName: "mic.badge.plus")
                            .font(.title3)
                            .foregroundColor(.blue)
                        Text("Auto-Listen")
                            .font(.body)
                    }
                }
                .onChange(of: continuousListeningEnabled) { _, newValue in
                    WKInterfaceDevice.current().play(.click)
                    settingsManager.updateContinuousListening(newValue)
                }
            } header: {
                Text("Agent")
            }

            // Tools Navigation
            Section {
                NavigationLink {
                    ToolsPageView()
                } label: {
                    HStack {
                        Image(systemName: "wrench.and.screwdriver")
                            .font(.title3)
                            .foregroundColor(.blue)
                        Text("Tools")
                            .font(.body)
                    }
                }

                NavigationLink {
                    DebugPageView(viewModel: viewModel)
                } label: {
                    HStack {
                        Image(systemName: "ant")
                            .font(.title3)
                            .foregroundColor(.orange)
                        Text("Debug")
                            .font(.body)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    WKInterfaceDevice.current().play(.click)
                    currentPage = .voice
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
        }
        .listStyle(.carousel)
        .onAppear {
            // Initialize picker selection from current settings
            selectedSpeed = SpeedPreset.from(rate: settingsManager.settings.speakingRate)
            continuousListeningEnabled = settingsManager.settings.continuousListeningEnabled
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
        case .connecting, .reconnecting:
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
        case .connecting, .reconnecting:
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
        case .reconnecting(let attempt, let maxAttempts):
            return "Reconnecting (\(attempt)/\(maxAttempts))..."
        case .connectionFailed:
            return "Connection Failed"
        case .idle, .recording, .processing, .playing:
            return "Connected"
        case .error:
            return "Error"
        }
    }

    // MARK: - Connection Action Helpers

    private func connectionActionHint(for state: VoiceInteractionState) -> String {
        switch state {
        case .idle, .recording, .processing, .playing:
            return "Tap to disconnect"
        case .disconnected:
            return "Tap to connect"
        case .connecting:
            return "Tap to cancel"
        case .reconnecting:
            return "Tap to cancel"
        case .connectionFailed, .error:
            return "Tap to retry"
        }
    }

    private func canPerformConnectionAction(for state: VoiceInteractionState) -> Bool {
        switch state {
        case .idle, .recording, .processing, .playing:
            return true  // Can disconnect
        case .disconnected:
            return true  // Can connect
        case .connecting, .reconnecting:
            return true  // Can cancel
        case .connectionFailed, .error:
            return true  // Can retry
        }
    }

    private func handleConnectionTap() {
        Task {
            switch state {
            case .idle, .recording, .processing, .playing:
                // Connected - disconnect
                await viewModel.disconnect()
            case .disconnected, .connectionFailed, .error:
                // Disconnected/Failed/Error - connect/retry
                await viewModel.connect()
            case .connecting, .reconnecting:
                // In progress - cancel
                await viewModel.disconnect()
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsPageView(
            viewModel: VoiceViewModel(),
            locationViewModel: LocationViewModel(),
            currentPage: .constant(.settings)
        )
    }
}
