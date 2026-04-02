//
//  DebugPageView.swift
//  reMIND Watch App
//
//  Debug diagnostics for troubleshooting connection issues on real hardware
//

import SwiftUI
import WatchConnectivity
import Network

struct DebugPageView: View {
    @ObservedObject var viewModel: VoiceViewModel
    @State private var networkPath: String = "checking..."
    @State private var connectivityTest: String = "—"

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
            }

            Section("Network") {
                row("WS Host", value: BuildConfiguration.websocketURL?.host ?? "nil")
                row("Path", value: networkPath)
                row("Configured", value: BuildConfiguration.isConfigured ? "Yes" : "No",
                    color: BuildConfiguration.isConfigured ? .green : .red)
                row("Endpoint Test", value: connectivityTest)
            }

            Section {
                Button("Test Azure Endpoint") {
                    Task { await testEndpoint() }
                }
                .foregroundColor(.blue)

                Button("Retry Connection") {
                    Task { await viewModel.connect() }
                }
                .foregroundColor(.green)
            }
        }
        .navigationTitle("Debug")
        .listStyle(.carousel)
        .onAppear { checkNetworkPath() }
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

    private func checkNetworkPath() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            var parts: [String] = []
            if path.usesInterfaceType(.wifi) { parts.append("WiFi") }
            if path.usesInterfaceType(.cellular) { parts.append("Cellular") }
            if path.usesInterfaceType(.other) { parts.append("Other") }
            let status = path.status == .satisfied ? "OK" : "No network"
            let interfaces = parts.isEmpty ? "Unknown" : parts.joined(separator: ", ")
            DispatchQueue.main.async {
                networkPath = "\(status) via \(interfaces)"
            }
            monitor.cancel()
        }
        monitor.start(queue: DispatchQueue.global(qos: .utility))
    }

    /// Tests basic HTTPS connectivity to the Azure endpoint (not WebSocket)
    private func testEndpoint() async {
        connectivityTest = "Testing..."
        let urlString = "https://\(BuildConfiguration.azureResourceName).services.ai.azure.com/openai/models?api-version=2024-10-21"
        guard let url = URL(string: urlString) else {
            connectivityTest = "Bad URL"
            return
        }

        var request = URLRequest(url: url)
        request.setValue(BuildConfiguration.azureAPIKey, forHTTPHeaderField: "api-key")
        request.timeoutInterval = 10

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                connectivityTest = "HTTP \(http.statusCode)"
            } else {
                connectivityTest = "No HTTP response"
            }
        } catch {
            connectivityTest = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        DebugPageView(viewModel: VoiceViewModel())
    }
}
