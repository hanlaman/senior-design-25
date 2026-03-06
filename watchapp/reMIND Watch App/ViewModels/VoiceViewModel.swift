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

    // MARK: - State

    private var isInitialized = false
    private var isProcessingAudio = false
    private var audioStateTask: Task<Void, Never>?
    private var bufferOverflowTask: Task<Void, Never>?
    private var audioChunkTask: Task<Void, Never>?
    private var stateMachineObserver: AnyCancellable?

    // Settings synchronization
    private var settingsObserver: AnyCancellable?
    private var pendingSettingsUpdate: VoiceSettings?

    // MARK: - Initialization

    init() {
        // Services will be initialized on connect

        // Observe state machine changes to trigger view updates
        stateMachineObserver = stateMachine.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }

        // Observe settings changes for automatic synchronization
        settingsObserver = settingsManager.$settings
            .sink { [weak self] newSettings in
                guard let self = self else { return }
                Task { @MainActor in
                    await self.handleSettingsChange(newSettings)
                }
            }

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

            // Start observing audio state changes
            startObservingAudioState()

            // Start monitoring buffer overflow
            startMonitoringBufferOverflow()

            // Mark settings as synchronized with active session
            settingsManager.markAsSynchronized(settingsManager.settings)

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

        // Cancel audio state observation
        audioStateTask?.cancel()
        audioStateTask = nil

        // Cancel buffer overflow monitoring
        bufferOverflowTask?.cancel()
        bufferOverflowTask = nil

        // Cancel audio chunk processing
        audioChunkTask?.cancel()
        audioChunkTask = nil
        isProcessingAudio = false

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

        azureService = nil
        audioService = nil

        AppLogger.general.info("Voice assistant disconnected")
    }

    // MARK: - Settings Synchronization

    /// Handle settings changes and automatically synchronize with active session
    private func handleSettingsChange(_ newSettings: VoiceSettings) async {
        // Only sync if connected
        guard stateMachine.isConnected else {
            // Settings saved locally, will apply on next connection
            return
        }

        // Compute what type of sync is needed
        let syncState = settingsManager.computeSyncState()

        // Check if we're in active interaction (recording, processing, or playing)
        let isActiveInteraction = stateMachine.isActive

        switch syncState {
        case .pendingReconnection(let fields):
            if isActiveInteraction {
                // Defer reconnection until interaction completes
                pendingSettingsUpdate = newSettings
                AppLogger.general.info("Settings changed (\(fields.joined(separator: ", "))), will reconnect after current interaction")
            } else {
                // Safe to reconnect now
                AppLogger.general.info("Settings changed (\(fields.joined(separator: ", "))), reconnecting...")
                await performGracefulReconnection(with: newSettings)
            }

        case .pendingSessionUpdate(let fields):
            if isActiveInteraction {
                // Defer session update until interaction completes
                pendingSettingsUpdate = newSettings
                AppLogger.general.info("Settings changed (\(fields.joined(separator: ", "))), will update session after current interaction")
            } else {
                // Safe to update session now
                AppLogger.general.info("Settings changed (\(fields.joined(separator: ", "))), updating session...")
                await performSessionUpdate(with: newSettings)
            }

        case .synchronized:
            // No changes needed
            pendingSettingsUpdate = nil

        case .notConnected:
            // No active session to sync
            break
        }
    }

    /// Perform graceful reconnection with new settings
    private func performGracefulReconnection(with settings: VoiceSettings) async {
        AppLogger.general.info("Reconnecting to apply settings changes")

        // Cancel any ongoing tasks
        audioStateTask?.cancel()
        audioStateTask = nil
        bufferOverflowTask?.cancel()
        bufferOverflowTask = nil
        audioChunkTask?.cancel()
        audioChunkTask = nil
        isProcessingAudio = false

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
    private func performSessionUpdate(with settings: VoiceSettings) async {
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
        guard let pending = pendingSettingsUpdate else {
            return
        }

        pendingSettingsUpdate = nil
        AppLogger.general.debug("Applying pending settings update")
        await handleSettingsChange(pending)
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

            // Process audio chunks (store task reference for cancellation)
            audioChunkTask = Task {
                await processAudioChunks(audioService: audioService, azureService: azureService)
            }

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

    private func startObservingAudioState() {
        audioStateTask?.cancel()

        guard let audioService = audioService else {
            AppLogger.general.warning("Cannot start observing audio state: no audio service")
            return
        }

        AppLogger.general.debug("Starting audio state observation")

        audioStateTask = Task { @MainActor [weak self] in
            for await isPlaying in await audioService.playbackStateStream {
                guard let self = self else { break }

                // Get current session ID
                guard let sessionId = self.stateMachine.sessionId else {
                    AppLogger.general.warning("No session ID during audio state change")
                    continue
                }

                // Audio stream is the single source of truth for playback state
                if isPlaying {
                    // Audio started - transition to playing if not already
                    if !self.stateMachine.isPlaying {
                        let bufferCount = await audioService.activeBufferCount
                        self.stateMachine.transitionTo(.playing(sessionId: sessionId, activeBuffers: bufferCount))
                        AppLogger.general.info("Voice state: playing")
                    }
                } else {
                    // Audio stopped - transition to idle if we're playing
                    if self.stateMachine.isPlaying {
                        self.stateMachine.transitionTo(.idle(sessionId: sessionId))
                        AppLogger.general.info("Voice state: idle")
                    }
                }
            }
        }
    }

    private func startMonitoringBufferOverflow() {
        bufferOverflowTask?.cancel()

        guard let audioService = audioService else {
            AppLogger.general.warning("Cannot start monitoring buffer overflow: no audio service")
            return
        }

        AppLogger.general.debug("Starting buffer overflow monitoring")

        bufferOverflowTask = Task { @MainActor [weak self] in
            for await event in await audioService.bufferOverflowStream {
                guard let self = self else { break }

                switch event {
                case .captureOverflow(let droppedChunks, let bufferSize):
                    AppLogger.audio.warning("Capture buffer overflow: dropped \(droppedChunks) chunks (max: \(bufferSize))")

                case .playbackOverflow(let droppedChunks, let bufferSize):
                    AppLogger.audio.warning("Playback buffer overflow: dropped \(droppedChunks) chunks (max: \(bufferSize))")
                }
            }
        }
    }

    private func processAudioChunks(audioService: AudioService, azureService: VoiceLiveConnection) async {
        guard !isProcessingAudio else { return }
        isProcessingAudio = true

        for await chunk in await audioService.audioChunkStream {
            guard stateMachine.isRecording else {
                break
            }

            do {
                try await azureService.inputAudioBuffer.append(chunk)
            } catch {
                AppLogger.logError(error, category: AppLogger.audio, context: "Failed to send audio chunk")
            }
        }

        isProcessingAudio = false

        isProcessingAudio = false
    }

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
