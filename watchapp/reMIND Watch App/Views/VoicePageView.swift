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

                    // Radial progress ring for playing state
                    if viewModel.state.isPlaying, let progress = viewModel.playbackProgress, progress > 0 {
                        RadialProgressView(
                            progress: progress,
                            lineWidth: 4,
                            color: .green.opacity(0.8)
                        )
                        .frame(width: 100, height: 100)
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

                // Action hint below status
                if let hint = viewModel.state.actionHint {
                    Text(hint)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }

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
        .highPriorityGesture(
            TapGesture()
                .onEnded { _ in
                    handleTap()
                }
        )
        .allowsHitTesting(canInteract(viewModel.state))
        .animation(.easeInOut(duration: 0.3), value: viewModel.state)
        .toolbar {
            // History button (top-left)
            ToolbarItem(placement: .topBarLeading) {
                if !viewModel.state.isRecording {
                    Button {
                        WKInterfaceDevice.current().play(.click)
                        currentPage = .history
                    } label: {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
            }

            // Settings button (top-right)
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
        case .connecting, .reconnecting:
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
        case .connecting, .reconnecting:
            return "mic.fill"
        }
    }

    private func canInteract(_ state: VoiceInteractionState) -> Bool {
        switch state {
        case .idle, .recording, .processing, .playing:
            return true
        case .connectionFailed:
            // Allow tap to retry connection
            return true
        default:
            return false
        }
    }

    private func handleTap() {
        // Debug: Log that tap was received
        print("DEBUG: handleTap called, current state: \(viewModel.state)")

        // Play haptic immediately to confirm tap was detected
        let currentState = viewModel.state

        Task {
            switch currentState {
            case .idle:
                // Start recording
                WKInterfaceDevice.current().play(.click)
                print("DEBUG: Starting recording from idle")
                await viewModel.startRecording()

            case .recording:
                // Cancel recording
                WKInterfaceDevice.current().play(.directionUp)
                print("DEBUG: Canceling from recording state")
                await viewModel.cancelInteraction()

            case .processing, .playing:
                // Cancel interaction
                WKInterfaceDevice.current().play(.directionUp)
                print("DEBUG: Canceling from \(currentState)")
                await viewModel.cancelInteraction()

            case .connectionFailed:
                // Retry connection on tap
                WKInterfaceDevice.current().play(.click)
                print("DEBUG: Retrying connection from connectionFailed state")
                await viewModel.connect()

            default:
                print("DEBUG: Tap ignored for state: \(currentState)")
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
