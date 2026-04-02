//
//  DebugPageView.swift
//  reMIND Watch App
//
//  Debug diagnostics for troubleshooting connection issues on real hardware
//

import SwiftUI
import WatchConnectivity
import Network
import os

struct DebugPageView: View {
    @ObservedObject var viewModel: VoiceViewModel
    @State private var networkPath: String = "checking..."
    @State private var wifiPath: String = "checking..."
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
                row("WiFi", value: wifiPath, color: wifiPath.starts(with: "OK") ? .green : .red)
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
        // General path monitor
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

        // WiFi-specific path monitor (diagnostic: shows if direct WiFi is available)
        let wifiMonitor = NWPathMonitor(requiredInterfaceType: .wifi)
        wifiMonitor.pathUpdateHandler = { path in
            let status = path.status == .satisfied ? "OK" : "Unavailable"
            DispatchQueue.main.async {
                wifiPath = status
            }
            wifiMonitor.cancel()
        }
        wifiMonitor.start(queue: DispatchQueue.global(qos: .utility))
    }

    /// Tests WebSocket connectivity using NWConnection (same config as production)
    private func testWebSocket() async {
        wsTest = "Connecting..."
        guard let url = BuildConfiguration.websocketURL else {
            wsTest = "Bad URL"
            return
        }

        // Build NWConnection with same config as WebSocketManager
        let wsOptions = NWProtocolWebSocket.Options()
        wsOptions.autoReplyPing = true
        wsOptions.setAdditionalHeaders([("api-key", BuildConfiguration.azureAPIKey)])

        let tlsOptions = NWProtocolTLS.Options()
        let params = NWParameters(tls: tlsOptions)
        params.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)
        params.prohibitExpensivePaths = false
        params.prohibitConstrainedPaths = false
        // Note: no requiredInterfaceType set here — the test should work on
        // any path (including simulator). Production code checks for WiFi/cellular
        // before connecting and shows a user-facing error if only companion is available.

        let endpoint = NWEndpoint.url(url)
        let connection = NWConnection(to: endpoint, using: params)

        let startTime = Date()
        let queue = DispatchQueue(label: "com.remind.ws-test")

        do {
            // Wait for connection ready with timeout.
            // OSAllocatedUnfairLock prevents double-resume since stateUpdateHandler
            // can fire multiple transitions (e.g., .waiting fires repeatedly).
            try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask {
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                        let resumed = OSAllocatedUnfairLock(initialState: false)

                        connection.stateUpdateHandler = { state in
                            switch state {
                            case .ready:
                                connection.receiveMessage { content, _, _, error in
                                    let elapsed = String(format: "%.1f", Date().timeIntervalSince(startTime))
                                    resumed.withLock { didResume in
                                        guard !didResume else { return }
                                        didResume = true
                                        if let error = error {
                                            continuation.resume(returning: "Ready but recv err: \(error.localizedDescription) (\(elapsed)s)")
                                        } else if let data = content {
                                            continuation.resume(returning: "Open! Got \(data.count)B (\(elapsed)s)")
                                        } else {
                                            continuation.resume(returning: "Open! No data (\(elapsed)s)")
                                        }
                                    }
                                }
                            case .failed(let error):
                                let elapsed = String(format: "%.1f", Date().timeIntervalSince(startTime))
                                resumed.withLock { didResume in
                                    guard !didResume else { return }
                                    didResume = true
                                    continuation.resume(returning: "Failed: \(error.localizedDescription) (\(elapsed)s)")
                                }
                            case .waiting(let error):
                                let elapsed = String(format: "%.1f", Date().timeIntervalSince(startTime))
                                resumed.withLock { didResume in
                                    guard !didResume else { return }
                                    didResume = true
                                    continuation.resume(returning: "Waiting: \(error.localizedDescription) (\(elapsed)s)")
                                }
                            default:
                                break
                            }
                        }
                        connection.start(queue: queue)
                    }
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 15_000_000_000)
                    return "Timeout (15s)"
                }
                if let result = try await group.next() {
                    wsTest = result
                    group.cancelAll()
                }
            }
        } catch {
            let elapsed = String(format: "%.1f", Date().timeIntervalSince(startTime))
            wsTest = "\(error.localizedDescription) (\(elapsed)s)"
        }
        connection.stateUpdateHandler = nil
        connection.cancel()
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
