//
//  SpeakingRateEditorView.swift
//  reMIND Watch App
//
//  Dedicated editor view for adjusting speaking rate with Digital Crown
//

import SwiftUI

/// Speed preset options
enum SpeedPreset: String, CaseIterable, Identifiable {
    case slowest = "Slowest"
    case slower = "Slower"
    case normal = "Normal"
    case faster = "Faster"
    case fastest = "Fastest"

    var id: String { rawValue }

    /// Actual speaking rate multiplier (Azure supports 0.5-1.5)
    var rate: Double {
        switch self {
        case .slowest: return 0.5
        case .slower: return 0.75
        case .normal: return 1.0
        case .faster: return 1.25
        case .fastest: return 1.5
        }
    }

    /// Icon for visual representation
    var icon: String {
        switch self {
        case .slowest: return "tortoise.fill"
        case .slower: return "tortoise"
        case .normal: return "hare"
        case .faster: return "hare.fill"
        case .fastest: return "bolt.fill"
        }
    }

    /// Create preset from a rate value (finds closest match)
    static func from(rate: Double) -> SpeedPreset {
        let presets = SpeedPreset.allCases
        return presets.min(by: { abs($0.rate - rate) < abs($1.rate - rate) }) ?? .normal
    }
}

struct SpeakingRateEditorView: View {
    @ObservedObject var settingsManager: VoiceSettingsManager
    @State private var selectedSpeed: SpeedPreset
    @Environment(\.dismiss) private var dismiss

    init(settingsManager: VoiceSettingsManager) {
        self.settingsManager = settingsManager
        // Initialize from current rate
        _selectedSpeed = State(initialValue: SpeedPreset.from(rate: settingsManager.settings.speakingRate))
    }

    var body: some View {
        VStack(spacing: 16) {
            // Large icon display
            Image(systemName: selectedSpeed.icon)
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .animation(.easeInOut(duration: 0.2), value: selectedSpeed)

            // Speed label
            Text(selectedSpeed.rawValue)
                .font(.title2)
                .fontWeight(.bold)
                .animation(.easeInOut(duration: 0.2), value: selectedSpeed)

            // Rate value
            Text("\(String(format: "%.1f", selectedSpeed.rate))x")
                .font(.title3)
                .foregroundColor(.secondary)

            Spacer()

            // Speed picker (Digital Crown controlled)
            Picker("Speed", selection: $selectedSpeed) {
                ForEach(SpeedPreset.allCases) { preset in
                    HStack {
                        Image(systemName: preset.icon)
                        Text(preset.rawValue)
                    }
                    .tag(preset)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)

            // Instruction hint
            Text("Turn Digital Crown")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .navigationTitle("Speaking Speed")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedSpeed) { oldValue, newValue in
            handleSpeedChange(from: oldValue, to: newValue)
        }
    }

    private func handleSpeedChange(from oldValue: SpeedPreset, to newValue: SpeedPreset) {
        // Haptic feedback
        WKInterfaceDevice.current().play(.click)

        // Extra haptic when crossing normal
        if (oldValue != .normal && newValue == .normal) {
            WKInterfaceDevice.current().play(.success)
        }

        // Save immediately (no debounce needed for discrete values)
        settingsManager.updateSpeakingRate(newValue.rate)
    }
}

#Preview {
    NavigationStack {
        SpeakingRateEditorView(settingsManager: VoiceSettingsManager.shared)
    }
}
