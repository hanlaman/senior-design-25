//
//  VoiceViewModel.swift
//  reMIND Watch App
//
//  Voice assistant view model - thin wrapper for UI state management
//  Business logic delegated to VoiceConnectionCoordinator
//

import Foundation
import SwiftUI
import Combine
import os

/// Voice assistant view model - manages UI state and forwards actions to coordinator
@MainActor
class VoiceViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Audio playback progress (0.0 = complete, 1.0 = just started, nil = not playing)
    @Published var playbackProgress: Double?

    /// Whether live captions are enabled
    @Published var captionsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(captionsEnabled, forKey: "captionsEnabled")
        }
    }

    /// Transcription manager for live captioning
    let transcriptionManager = TranscriptionManager()

    // MARK: - Coordinator

    private let coordinator: VoiceConnectionCoordinator
    private var coordinatorObserver: AnyCancellable?

    // MARK: - Computed Properties

    /// Current voice interaction state
    var state: VoiceInteractionState {
        coordinator.state
    }

    /// Whether Azure is properly configured
    var isConfigured: Bool {
        coordinator.isConfigured
    }

    // MARK: - Initialization

    /// Initialize VoiceViewModel with optional dependency injection for testability
    init(
        settingsManager: VoiceSettingsManager = .shared,
        toolRegistry: ToolRegistry = .shared,
        historyManager: ConversationHistoryManager = .shared,
        azureServiceFactory: @escaping (String, String, String, String, VoiceSettings) -> VoiceLiveConnection = {
            endpoint, apiKey, model, apiVersion, settings in
            VoiceLiveConnection(
                endpoint: endpoint,
                apiKey: apiKey,
                model: model,
                apiVersion: apiVersion,
                settings: settings
            )
        },
        audioServiceFactory: @escaping () -> AudioService = { AudioService() }
    ) {
        // Load captions preference
        self.captionsEnabled = UserDefaults.standard.bool(forKey: "captionsEnabled")

        // Create coordinator with all dependencies
        self.coordinator = VoiceConnectionCoordinator(
            settingsManager: settingsManager,
            toolRegistry: toolRegistry,
            historyManager: historyManager,
            azureServiceFactory: azureServiceFactory,
            audioServiceFactory: audioServiceFactory
        )

        // Set up coordinator delegate
        coordinator.delegate = self

        // Observe coordinator state changes to trigger view updates
        coordinatorObserver = coordinator.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }

        AppLogger.general.info("VoiceViewModel initialized")
    }

    // MARK: - Connection Actions

    /// Connect to Azure voice service
    func connect() async {
        await coordinator.connect()
    }

    /// Disconnect from Azure voice service
    func disconnect() async {
        await coordinator.disconnect()
    }

    // MARK: - Voice Interaction Actions

    /// Start recording audio
    func startRecording() async {
        await coordinator.startRecording()
    }

    /// Stop recording and submit audio
    func stopRecording() async {
        await coordinator.stopRecording()
    }

    /// Cancel current interaction
    func cancelInteraction() async {
        await coordinator.cancelInteraction()
    }
}

// MARK: - Voice Connection Coordinator Delegate

extension VoiceViewModel: VoiceConnectionCoordinatorDelegate {
    func coordinator(_ coordinator: VoiceConnectionCoordinator, didUpdatePlaybackProgress progress: Double?) {
        playbackProgress = progress

        // Update transcription reveal progress (progress goes 1.0 → 0.0, reveal goes 0.0 → 1.0)
        if let progress = progress {
            transcriptionManager.updateRevealProgress(1.0 - progress)
        }
    }

    func coordinator(_ coordinator: VoiceConnectionCoordinator, didReceiveTranscriptionEvent event: TranscriptionEvent) {
        switch event {
        case .conversationItemCreated(let itemId, let role):
            transcriptionManager.handleConversationItemCreated(itemId: itemId, role: role)

        case .inputDelta(let delta, let itemId):
            transcriptionManager.handleInputTranscriptionDelta(delta: delta, itemId: itemId)

        case .inputCompleted(let transcript, let itemId):
            transcriptionManager.handleInputTranscriptionCompleted(transcript: transcript, itemId: itemId)

        case .outputDelta(let delta, let itemId):
            transcriptionManager.handleOutputTranscriptionDelta(delta: delta, itemId: itemId)

        case .outputDone(let transcript, let itemId):
            transcriptionManager.handleOutputTranscriptionDone(transcript: transcript, itemId: itemId)

        case .agentMessageComplete:
            transcriptionManager.markAgentMessageComplete()

        case .agentMessageCancelled:
            transcriptionManager.markAgentMessageCancelled()
        }
    }
}
