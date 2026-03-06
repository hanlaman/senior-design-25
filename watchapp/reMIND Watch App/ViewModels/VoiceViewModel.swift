//
//  VoiceViewModel.swift
//  reMIND Watch App
//
//  Voice assistant view model coordinating services and managing state
//

import Foundation
import SwiftUI
import Combine
import os

/// Voice assistant view model
@MainActor
class VoiceViewModel: ObservableObject {
    // MARK: - Published Properties

    // Unified state machine (single source of truth)
    private let stateMachine = VoiceStateMachine()

    // Computed property for new code to access unified state
    var state: VoiceInteractionState {
        stateMachine.state
    }

    // MARK: - Services

    private var azureService: VoiceLiveConnection?
    private var audioService: AudioService?
    private let settingsManager = VoiceSettingsManager.shared

    // Coordinators
    private var eventHandler: AzureEventHandler?
    private var audioCoordinator: AudioCoordinator?
    private var settingsSyncCoordinator: SettingsSyncCoordinator?

    // MARK: - State

    private var stateMachineObserver: AnyCancellable?

    // MARK: - Initialization

    init() {
        // Services will be initialized on connect

        // Observe state machine changes to trigger view updates
        stateMachineObserver = stateMachine.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }

        // Create and start settings sync coordinator
        let coordinator = SettingsSyncCoordinator(settingsManager: settingsManager)
        coordinator.delegate = self
        coordinator.startObserving()
        self.settingsSyncCoordinator = coordinator

        AppLogger.general.info("VoiceViewModel initialized with automatic settings sync")
    }

    // MARK: - Connection Management

    func connect() async {
        guard !stateMachine.isConnected else { return }

        // Validate configuration
        let config = AzureVoiceLiveConfig.fromBuildSettings
        if let validationError = config.validate() {
            stateMachine.transitionTo(.connectionFailed(validationError))
            return
        }

        stateMachine.transitionTo(.connecting)

        do {
            // Create services with current settings
            // Build endpoint from resource name
            let endpoint = "\(config.resourceName).services.ai.azure.com"
            let azure = VoiceLiveConnection(
                endpoint: endpoint,
                apiKey: config.apiKey,
                model: config.model,
                apiVersion: config.apiVersion,
                settings: settingsManager.settings
            )
            let audio = AudioService()

            self.azureService = azure
            self.audioService = audio

            // Create event handler
            let handler = AzureEventHandler(
                audioService: audio,
                stateMachine: stateMachine,
                historyManager: ConversationHistoryManager.shared
            )
            handler.delegate = self
            self.eventHandler = handler

            // Create audio coordinator
            let coordinator = AudioCoordinator(audioService: audio, azureService: azure)
            coordinator.delegate = self
            self.audioCoordinator = coordinator

            // Start processing events before connect (to receive session.created/updated events)
            await startProcessingEvents()

            // Connect to Azure WebSocket and establish session
            // This now handles the entire flow: WebSocket connect → session.created → session.update → ready
            try await azure.connect()

            // Get session ID from Azure
            let azureSessionState = await azure.sessionState
            guard let sessionId = azureSessionState.sessionId else {
                throw NSError(domain: "VoiceViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Session ID not available"])
            }

            // Session is now ready, update UI state
            stateMachine.transitionTo(.idle(sessionId: sessionId))

            // Start audio monitoring (playback state and buffer overflow)
            audioCoordinator?.startMonitoring()

            // Mark settings as synchronized with active session
            settingsManager.markAsSynchronized(settingsManager.settings)

            // Notify settings coordinator that we're connected
            settingsSyncCoordinator?.setConnected(true)

            // Start conversation history session
            ConversationHistoryManager.shared.startSession(sessionId)

            AppLogger.general.info("Voice assistant connected and ready")

        } catch {
            AppLogger.logError(error, category: AppLogger.general, context: "Connection failed")
            stateMachine.transitionTo(.connectionFailed(error.localizedDescription))

            // Clean up on failure
            await azureService?.disconnect()
            azureService = nil
            audioService = nil
        }
    }

    func disconnect() async {
        guard stateMachine.isConnected else { return }

        AppLogger.general.info("Disconnecting voice assistant")

        // Stop audio monitoring and processing
        audioCoordinator?.stopMonitoring()

        // Stop any active recording or playback
        await stopRecording()
        await audioService?.stopPlayback()

        // Disconnect from Azure
        await azureService?.disconnect()

        // End conversation history session
        if let sessionId = stateMachine.sessionId {
            ConversationHistoryManager.shared.endSession(sessionId)
        }

        stateMachine.transitionTo(.disconnected)

        // Clear active session from settings manager
        settingsManager.clearActiveSession()

        // Notify settings coordinator that we're disconnected
        settingsSyncCoordinator?.setConnected(false)

        azureService = nil
        audioService = nil

        AppLogger.general.info("Voice assistant disconnected")
    }

    // MARK: - Settings Synchronization

    /// Perform graceful reconnection with new settings
    func performGracefulReconnection(with settings: VoiceSettings) async {
        AppLogger.general.info("Reconnecting to apply settings changes")

        // Stop audio monitoring and processing
        audioCoordinator?.stopMonitoring()

        // Stop audio capture and clear buffer
        if stateMachine.isRecording {
            await audioService?.stopCapture()
        }

        // Clear audio buffer to prevent overflow on reconnect
        try? await azureService?.inputAudioBuffer.clear()

        // Stop playback if active
        await audioService?.stopPlayback()

        // Disconnect and reconnect
        await disconnect()
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s cleanup delay
        await connect()
    }

    /// Perform session update with new settings
    func performSessionUpdate(with settings: VoiceSettings) async {
        guard let azure = azureService else {
            AppLogger.general.warning("Azure service not available for session update")
            return
        }

        do {
            // Send session.update with new configuration
            let config = RealtimeRequestSession.fromSettings(settings)
            try await azure.session.update(config)

            // Mark as synchronized
            settingsManager.markAsSynchronized(settings)

            AppLogger.general.info("Session updated successfully with new settings")

        } catch {
            AppLogger.logError(error, category: AppLogger.general, context: "Failed to update session with new settings")
            // Keep sync state as pending - will retry on next change or interaction end
        }
    }

    /// Check for and apply pending settings updates
    private func applyPendingSettingsUpdate() async {
        await settingsSyncCoordinator?.applyPendingUpdates()
    }

    // MARK: - Voice Interaction

    func startRecording() async {
        guard stateMachine.canStartRecording else {
            AppLogger.general.warning("Cannot start recording in current state: \(self.stateMachine.state)")
            return
        }

        guard let audioService = audioService, let azureService = azureService else {
            AppLogger.general.warning("Services not initialized")
            return
        }

        // Get session ID for state machine
        guard let sessionId = stateMachine.sessionId else {
            AppLogger.general.warning("No active session")
            return
        }

        do {
            AppLogger.general.info("Starting voice recording")

            stateMachine.transitionTo(.recording(sessionId: sessionId, bufferBytes: 0))

            // Start audio capture
            try await audioService.startCapture()

            // Start processing audio chunks
            await audioCoordinator?.startProcessingAudioChunks()

        } catch {
            AppLogger.logError(error, category: AppLogger.general, context: "Failed to start recording")
            stateMachine.transitionTo(.error(sessionId: sessionId, message: error.localizedDescription))
        }
    }

    func stopRecording() async {
        guard stateMachine.isRecording else { return }

        AppLogger.general.info("Stopping voice recording")

        // Get session ID
        guard let sessionId = stateMachine.sessionId else { return }

        // Stop audio capture
        await audioService?.stopCapture()

        // Small delay to allow in-flight audio chunks to be processed
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Get buffer statistics before committing
        guard let azureService = azureService else { return }
        let bufferStats = await azureService.inputAudioBuffer.statistics
        AppLogger.general.debug("Buffer statistics: \(bufferStats.durationMs)ms, \(bufferStats.bytes) bytes, \(bufferStats.chunks) chunks")

        // Commit audio buffer to Azure
        do {
            try await azureService.inputAudioBuffer.commit()
            stateMachine.transitionTo(.processing(sessionId: sessionId))
            AppLogger.general.debug("Audio buffer committed, processing...")
        } catch let error as AzureError {
            // Handle buffer too small error specifically
            if case .bufferTooSmall = error {
                AppLogger.general.warning("Audio buffer too small, clearing buffer")
                try? await azureService.inputAudioBuffer.clear()
                stateMachine.transitionTo(.idle(sessionId: sessionId))
            } else {
                AppLogger.logError(error, category: AppLogger.general, context: "Failed to commit audio buffer")
                stateMachine.transitionTo(.error(sessionId: sessionId, message: error.localizedDescription))
            }
        } catch {
            AppLogger.logError(error, category: AppLogger.general, context: "Failed to commit audio buffer")
            stateMachine.transitionTo(.error(sessionId: sessionId, message: error.localizedDescription))
        }
    }

    func cancelInteraction() async {
        AppLogger.general.info("Canceling interaction")

        // Get session ID
        guard let sessionId = stateMachine.sessionId else { return }

        // Stop recording if active
        await audioService?.stopCapture()

        // Stop playback if active
        await audioService?.stopPlayback()

        // Cancel Azure response
        try? await azureService?.response.cancel()

        // Clear audio buffer
        try? await azureService?.inputAudioBuffer.clear()

        stateMachine.transitionTo(.idle(sessionId: sessionId))
    }

    // MARK: - Private Methods

    private func startProcessingEvents() async {
        guard let azureService = azureService else { return }

        Task {
            for await event in await azureService.eventStream {
                await handleAzureEvent(event)
            }
        }
    }

    private func handleAzureEvent(_ event: AzureServerEvent) async {
        // Delegate all event handling to AzureEventHandler
        await eventHandler?.handle(event)
    }

    // MARK: - Configuration

    var isConfigured: Bool {
        AzureVoiceLiveConfig.fromBuildSettings.isValid
    }
}

// MARK: - Azure Event Handler Delegate

extension VoiceViewModel: AzureEventHandlerDelegate {
    func eventHandler(_ handler: AzureEventHandler, didReceiveAudioDelta data: Data) async {
        guard let audioService = audioService else { return }

        // Play audio - state transition handled by audio stream observer
        // AudioService will emit playback state changes via playbackStateStream
        // The observer will transition from .processing → .playing when audio starts
        do {
            try await audioService.playAudio(data)
        } catch {
            AppLogger.logError(error, category: AppLogger.audio, context: "Failed to play audio")

            // Transition to error state if engine failed
            if let audioError = error as? AudioServiceError,
               case .engineStartFailed = audioError {
                if let sessionId = stateMachine.sessionId {
                    stateMachine.transitionTo(.error(sessionId: sessionId, message: "Audio engine failed"))
                }
            }
        }
    }

    func eventHandler(_ handler: AzureEventHandler, shouldTransitionTo state: VoiceInteractionState) {
        stateMachine.transitionTo(state)
    }

    func eventHandler(_ handler: AzureEventHandler, didStopCaptureForVAD: Bool) async {
        await audioService?.stopCapture()
    }

    func eventHandler(_ handler: AzureEventHandler, shouldApplyPendingSettings: Bool) async {
        await applyPendingSettingsUpdate()
    }
}

// MARK: - Audio Coordinator Delegate

extension VoiceViewModel: AudioCoordinatorDelegate {
    var sessionId: String? {
        stateMachine.sessionId
    }

    func audioCoordinator(
        _ coordinator: AudioCoordinator,
        didChangePlaybackState isPlaying: Bool,
        bufferCount: Int
    ) {
        guard let sessionId = stateMachine.sessionId else {
            AppLogger.general.warning("No session ID during audio state change")
            return
        }

        // Audio stream is the single source of truth for playback state
        if isPlaying {
            // Audio started - transition to playing if not already
            if !stateMachine.isPlaying {
                stateMachine.transitionTo(.playing(sessionId: sessionId, activeBuffers: bufferCount))
            }
        } else {
            // Audio stopped - transition to idle if we're playing
            if stateMachine.isPlaying {
                stateMachine.transitionTo(.idle(sessionId: sessionId))
            }
        }
    }

    func audioCoordinator(
        _ coordinator: AudioCoordinator,
        didDetectOverflow event: BufferOverflowEvent
    ) {
        // Overflow is already logged by coordinator
        // Could add additional handling here if needed (e.g., show user notification)
    }
}

// MARK: - Settings Sync Coordinator Delegate

extension VoiceViewModel: SettingsSyncCoordinatorDelegate {
    var isActiveInteraction: Bool {
        get async {
            return stateMachine.isActive
        }
    }

    // Note: performReconnection and performSessionUpdate are implemented as:
    // - performGracefulReconnection(with:)
    // - performSessionUpdate(with:)
    // These already exist in the class body above, so we just need to rename them
    // or add wrapper methods here

    func performReconnection(with settings: VoiceSettings) async {
        await performGracefulReconnection(with: settings)
    }
}
