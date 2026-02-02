//
//  VoicePageView.swift
//  reMIND Watch App
//
//  Full-screen voice interaction page
//

import SwiftUI
import WatchKit

struct VoicePageView: View {
    @ObservedObject var viewModel: VoiceViewModel
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Background layer: Full-screen color based on voice state
            backgroundColor(for: viewModel.voiceState)
                .ignoresSafeArea()

            // Content layer: Center icon, status text, and error message
            VStack(spacing: 16) {
                Spacer()

                // Large center icon
                Image(systemName: iconName(for: viewModel.voiceState))
                    .font(.system(size: 64, weight: .medium))
                    .foregroundColor(.white)
                    .scaleEffect(isPulsing && viewModel.voiceState.isRecording ? 1.15 : 1.0)
                    .animation(
                        viewModel.voiceState.isRecording ?
                            .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default,
                        value: isPulsing
                    )
                    .onChange(of: viewModel.voiceState) { _, newState in
                        isPulsing = newState.isRecording
                    }

                // Status text below icon
                Text(viewModel.voiceState.displayText)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)

                Spacer()

                // Error message at bottom (only visible if error exists)
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
            }
        }
        .contentShape(Rectangle()) // Make entire area tappable
        .onTapGesture {
            handleTap()
        }
        .allowsHitTesting(canInteract(viewModel.voiceState))
        .animation(.easeInOut(duration: 0.3), value: viewModel.voiceState)
    }

    // MARK: - Helper Functions

    private func backgroundColor(for state: VoiceState) -> Color {
        switch state {
        case .idle:
            return Color.blue
        case .recording:
            return Color.red
        case .processing:
            return Color.orange
        case .playing:
            return Color.green
        case .error:
            return Color.gray
        case .disconnected:
            return Color(white: 0.3) // Dark gray
        case .connecting:
            return Color.blue.opacity(0.6)
        }
    }

    private func iconName(for state: VoiceState) -> String {
        switch state {
        case .idle, .recording:
            return "mic.fill"
        case .processing:
            return "waveform"
        case .playing:
            return "speaker.wave.2.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        case .disconnected:
            return "mic.slash.fill"
        case .connecting:
            return "mic.fill"
        }
    }

    private func canInteract(_ state: VoiceState) -> Bool {
        switch state {
        case .idle, .recording:
            return true
        default:
            return false
        }
    }

    private func handleTap() {
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
    VoicePageView(viewModel: VoiceViewModel())
}
