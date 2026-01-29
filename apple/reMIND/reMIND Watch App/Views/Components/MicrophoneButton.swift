//
//  MicrophoneButton.swift
//  reMIND Watch App
//
//  Microphone button with state-driven appearance
//

import SwiftUI
import WatchKit

/// Microphone button with 5 states
struct MicrophoneButton: View {
    let state: VoiceState
    let action: () -> Void

    @State private var isPulsing = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(buttonColor)
                    .frame(width: 80, height: 80)
                    .scaleEffect(isPulsing && state.isRecording ? 1.1 : 1.0)
                    .animation(
                        state.isRecording ?
                            .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default,
                        value: isPulsing
                    )

                Image(systemName: iconName)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
        .disabled(!canInteract)
        .onChange(of: state) { _, newState in
            isPulsing = newState.isRecording
        }
        .onAppear {
            isPulsing = state.isRecording
        }
    }

    private var buttonColor: Color {
        switch state {
        case .idle:
            return .blue
        case .recording:
            return .red
        case .processing:
            return .orange
        case .playing:
            return .green
        case .error:
            return .gray
        case .disconnected:
            return .gray
        case .connecting:
            return .blue.opacity(0.6)
        }
    }

    private var iconName: String {
        switch state {
        case .idle:
            return "mic.fill"
        case .recording:
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

    private var canInteract: Bool {
        switch state {
        case .idle, .recording:
            return true
        case .processing, .playing, .error, .disconnected, .connecting:
            return false
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        MicrophoneButton(state: .idle) {}
        MicrophoneButton(state: .recording) {}
        MicrophoneButton(state: .processing) {}
        MicrophoneButton(state: .playing) {}
        MicrophoneButton(state: .disconnected) {}
    }
}
