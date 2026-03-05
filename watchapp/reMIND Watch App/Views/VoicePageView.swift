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
    @Binding var currentPage: ContentView.NavigationPage?
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Background layer: Consistent dark background
            Color.black
                .ignoresSafeArea()

            // Content layer: Center icon, status text, and error message
            VStack(spacing: 16) {
                Spacer()

                // Large center icon with colored background circle
                ZStack {
                    // Subtle circular background for recording state
                    if viewModel.state.isRecording {
                        Circle()
                            .fill(iconColor(for: viewModel.state).opacity(0.15))
                            .frame(width: 120, height: 120)
                            .scaleEffect(isPulsing ? 1.1 : 1.0)
                            .animation(
                                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                value: isPulsing
                            )
                    }

                    // Icon
                    Image(systemName: iconName(for: viewModel.state))
                        .font(.system(size: 64, weight: .medium))
                        .foregroundColor(iconColor(for: viewModel.state))
                        .scaleEffect(isPulsing && viewModel.state.isRecording ? 1.15 : 1.0)
                        .animation(
                            viewModel.state.isRecording ?
                                .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default,
                            value: isPulsing
                        )
                }
                .onChange(of: viewModel.state) { _, newState in
                    isPulsing = newState.isRecording
                }

                // Status text below icon
                Text(viewModel.state.displayText)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)

                Spacer()

                // Error message at bottom (only visible if error exists)
                if let errorMessage = viewModel.state.errorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundColor(.red.opacity(0.9))
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
        .allowsHitTesting(canInteract(viewModel.state))
        .animation(.easeInOut(duration: 0.3), value: viewModel.state)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !viewModel.state.isRecording {
                    Button {
                        WKInterfaceDevice.current().play(.click)
                        currentPage = .settings
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }

    // MARK: - Helper Functions

    private func iconColor(for state: VoiceInteractionState) -> Color {
        switch state {
        case .idle:
            return .blue
        case .recording:
            return .red
        case .processing:
            return .orange
        case .playing:
            return .green
        case .error, .connectionFailed:
            return .red
        case .disconnected:
            return .gray
        case .connecting:
            return .blue.opacity(0.6)
        }
    }

    private func iconName(for state: VoiceInteractionState) -> String {
        switch state {
        case .idle, .recording:
            return "mic.fill"
        case .processing:
            return "waveform"
        case .playing:
            return "speaker.wave.2.fill"
        case .error, .connectionFailed:
            return "exclamationmark.triangle.fill"
        case .disconnected:
            return "mic.slash.fill"
        case .connecting:
            return "mic.fill"
        }
    }

    private func canInteract(_ state: VoiceInteractionState) -> Bool {
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
            switch viewModel.state {
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
    NavigationStack {
        VoicePageView(viewModel: VoiceViewModel(), currentPage: .constant(.voice))
    }
}
