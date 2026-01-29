//
//  ConnectionStatusBanner.swift
//  caregiverapp
//

import SwiftUI

struct ConnectionStatusBanner: View {
    let isConnected: Bool
    let statusText: String

    var body: some View {
        HStack {
            Image(systemName: isConnected ? "applewatch.radiowaves.left.and.right" : "applewatch.slash")
                .foregroundStyle(isConnected ? .green : .red)
            Text(isConnected ? "Watch Connected" : "Watch Disconnected").font(.subheadline).fontWeight(.medium)
            Spacer()
            if isConnected {
                Text(statusText).font(.caption).foregroundStyle(.secondary)
            } else {
                Button("Retry") {}.font(.caption).buttonStyle(.bordered).controlSize(.mini)
            }
        }
        .padding()
        .background(isConnected ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
