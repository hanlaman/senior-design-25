//
//  ContentView.swift
//  reMIND Watch App
//
//  Main view for voice assistant
//

import SwiftUI
import WatchKit

struct ContentView: View {
    @StateObject private var viewModel = VoiceViewModel()

    var body: some View {
        VStack(spacing: 20) {
            // Connection status
            ConnectionStatusView(connectionState: viewModel.connectionState)

            Spacer()

            // Status text
            Text(viewModel.voiceState.displayText)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(statusTextColor)

            // Microphone button
            MicrophoneButton(state: viewModel.voiceState) {
                handleMicrophoneButtonTap()
            }

            Spacer()

            // Error message
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .padding()
        .task {
            // Auto-connect on appear
            await viewModel.connect()
        }
    }

    private var statusTextColor: Color {
        switch viewModel.voiceState {
        case .error:
            return .red
        case .disconnected:
            return .gray
        default:
            return .primary
        }
    }

    private func handleMicrophoneButtonTap() {
        // Play haptic feedback
        WKInterfaceDevice.current().play(.click)

        Task {
            switch viewModel.voiceState {
            case .idle:
                // Start recording
                await viewModel.startRecording()

            case .recording:
                // Stop recording (user manual override)
                await viewModel.stopRecording()

            default:
                // Do nothing in other states
                break
            }
        }
    }
}

#Preview {
    ContentView()
}
