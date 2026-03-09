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

    var body: some View {
        ZStack {
            // Background layer: Consistent dark background
            Color.black
                .ignoresSafeArea()

            // Captions view layer (scrollable)
            if viewModel.captionsEnabled {
                CaptionsView(transcriptionManager: viewModel.transcriptionManager)
            }

            // Content layer (only when captions OFF)
            if !viewModel.captionsEnabled {
                VStack(spacing: 0) {
                    // Action hint
                    if let hint = viewModel.state.actionHint {
                        Text(hint)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.top, 8)
                    }

                    Spacer()

                    // Large center icon with colored background circle
                    centerIconView

                    Spacer()

                    // Error message (if any)
                    if let errorMessage = viewModel.state.errorMessage {
                        Text(errorMessage)
                            .font(.caption2)
                            .foregroundColor(.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal)
                    }
                }
            }
        }
        // Full-screen tap gesture only when captions OFF
        .contentShape(Rectangle())
        .highPriorityGesture(
            viewModel.captionsEnabled ? nil : TapGesture().onEnded { _ in handleTap() }
        )
        .allowsHitTesting(canInteract(viewModel.state))
        .animation(.easeInOut(duration: 0.3), value: viewModel.state)
        .animation(.easeInOut(duration: 0.2), value: viewModel.captionsEnabled)
        .navigationTitle("")  // State display moved to bottom toolbar
        .toolbar {
            // History button (top-left)
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    WKInterfaceDevice.current().play(.click)
                    currentPage = .history
                } label: {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.title3)
                        .foregroundColor(viewModel.state.isActive ? .blue.opacity(0.3) : .blue)
                }
                .disabled(viewModel.state.isActive)
            }

            // Settings button (top-right)
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    WKInterfaceDevice.current().play(.click)
                    currentPage = .settings
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundColor(viewModel.state.isActive ? .blue.opacity(0.3) : .blue)
                }
                .disabled(viewModel.state.isActive)
            }

            // Bottom toolbar
            ToolbarItem(placement: .bottomBar) {
                HStack {
                    // Voice controls button (visible when captions enabled, invisible otherwise for centering)
                    Button {
                        WKInterfaceDevice.current().play(.click)
                        handleTap()
                    } label: {
                        Image(systemName: iconName(for: viewModel.state))
                            .font(.title3)
                            .foregroundColor(iconColor(for: viewModel.state))
                    }
                    .opacity(viewModel.captionsEnabled ? 1 : 0)
                    .disabled(!viewModel.captionsEnabled)

                    Spacer()

                    // Voice state display (always shown in center)
                    Text(viewModel.state.displayText)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))

                    Spacer()

                    // Captions toggle button
                    Button {
                        WKInterfaceDevice.current().play(.click)
                        viewModel.captionsEnabled.toggle()
                    } label: {
                        Image(systemName: viewModel.captionsEnabled ? "captions.bubble.fill" : "captions.bubble")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }

    // MARK: - Center Icon View

    /// The large center icon with animations (extracted for conditional display)
    private var centerIconView: some View {
        ZStack {
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
        case .idle:
            return "mic.fill"
        case .recording:
            return "ear.fill"
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
