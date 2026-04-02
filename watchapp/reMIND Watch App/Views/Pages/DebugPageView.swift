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
    @State private var wsTest: String = "—"

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
                row("WS Test", value: wsTest)
            }

            Section {
                Button("Test HTTP") {
                    Task { await testEndpoint() }
                }
                .foregroundColor(.blue)

                Button("Test WebSocket") {
                    Task { await testWebSocket() }
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

    /// Tests WebSocket connectivity to the Azure endpoint using URLSession.shared
    private func testWebSocket() async {
        wsTest = "Connecting..."
        let urlString = "wss://\(BuildConfiguration.azureResourceName).services.ai.azure.com/voice-live/realtime?api-version=\(BuildConfiguration.azureAPIVersion)&model=\(BuildConfiguration.azureModel)"
        guard let url = URL(string: urlString) else {
            wsTest = "Bad URL"
            return
        }

        var request = URLRequest(url: url)
        request.setValue(BuildConfiguration.azureAPIKey, forHTTPHeaderField: "api-key")
        request.timeoutInterval = 15

        // Test 1: Use URLSession.shared (simplest possible config)
        let task = URLSession.shared.webSocketTask(with: request)
        task.resume()

        // Wait up to 15 seconds for the handshake
        let startTime = Date()
        do {
            try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask {
                    // Try to receive — if handshake succeeds, this will either
                    // get a message or wait for one
                    let msg = try await task.receive()
                    switch msg {
                    case .string(let s): return "Open! Got: \(s.prefix(30))"
                    case .data(let d): return "Open! Got \(d.count)B"
                    @unknown default: return "Open! Unknown msg"
                    }
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 15_000_000_000)
                    return "Timeout (15s)"
                }
                if let result = try await group.next() {
                    let elapsed = String(format: "%.1f", Date().timeIntervalSince(startTime))
                    wsTest = "\(result) (\(elapsed)s)"
                    group.cancelAll()
                }
            }
        } catch {
            let elapsed = String(format: "%.1f", Date().timeIntervalSince(startTime))
            let errDesc: String
            if let urlError = error as? URLError {
                errDesc = "URLErr \(urlError.code.rawValue): \(urlError.localizedDescription)"
            } else {
                errDesc = error.localizedDescription
            }
            wsTest = "\(errDesc) (\(elapsed)s)"
        }
        task.cancel(with: .goingAway, reason: nil)
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
