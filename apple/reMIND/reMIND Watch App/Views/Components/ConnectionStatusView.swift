//
//  ConnectionStatusView.swift
//  reMIND Watch App
//
//  Connection status indicator
//

import SwiftUI

/// Connection status indicator
struct ConnectionStatusView: View {
    let connectionState: ConnectionState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(connectionState.displayText)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var statusColor: Color {
        switch connectionState {
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
    VStack(spacing: 16) {
        ConnectionStatusView(connectionState: .connected)
        ConnectionStatusView(connectionState: .connecting)
        ConnectionStatusView(connectionState: .disconnected)
        ConnectionStatusView(connectionState: .error("Connection failed"))
    }
}
