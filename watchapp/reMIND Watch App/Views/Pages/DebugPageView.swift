//
//  DebugPageView.swift
//  reMIND Watch App
//
//  Debug diagnostics for troubleshooting connection issues on real hardware
//

import SwiftUI

struct DebugPageView: View {
    @ObservedObject var viewModel: VoiceViewModel

    var body: some View {
        List {
            Section("Connection") {
                row("State", value: viewModel.state.description)
                row("Phase", value: viewModel.connectingPhase.isEmpty ? "—" : viewModel.connectingPhase)
                if let error = viewModel.state.errorMessage {
                    row("Error", value: error, color: .red)
                }
            }

            Section("Config") {
                row("Resource", value: BuildConfiguration.azureResourceName)
                row("Model", value: BuildConfiguration.azureModel)
                row("API Ver", value: BuildConfiguration.azureAPIVersion)
                row("Key", value: String(BuildConfiguration.azureAPIKey.prefix(8)) + "...")
                row("API URL", value: String(BuildConfiguration.apiBaseURL.prefix(30)) + "...")
            }

            Section("Network") {
                row("WS URL", value: BuildConfiguration.websocketURL?.host ?? "nil")
                row("Configured", value: BuildConfiguration.isConfigured ? "Yes" : "No",
                    color: BuildConfiguration.isConfigured ? .green : .red)
            }
        }
        .navigationTitle("Debug")
        .listStyle(.carousel)
    }

    private func row(_ label: String, value: String, color: Color = .secondary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .foregroundColor(color)
                .lineLimit(3)
        }
    }
}

#Preview {
    NavigationStack {
        DebugPageView(viewModel: VoiceViewModel())
    }
}
