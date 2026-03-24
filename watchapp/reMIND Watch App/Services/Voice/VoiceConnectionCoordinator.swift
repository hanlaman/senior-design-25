//
//  VoiceConnectionCoordinator.swift
//  reMIND Watch App
//
//  Coordinates voice connection lifecycle, services, and delegate handling
//  Extracted from VoiceViewModel to separate business logic from UI state
//

import Foundation
import Combine
import os

/// Delegate protocol for voice connection events
@MainActor
protocol VoiceConnectionCoordinatorDelegate: AnyObject {
    /// Called when playback progress updates
    func coordinator(_ coordinator: VoiceConnectionCoordinator, didUpdatePlaybackProgress progress: Double?)

    /// Called when transcription events occur
    func coordinator(_ coordinator: VoiceConnectionCoordinator, didReceiveTranscriptionEvent event: TranscriptionEvent)
}

/// Transcription events forwarded to delegate
enum TranscriptionEvent {
    case conversationItemCreated(itemId: String, role: TranscriptionRole)
    case inputDelta(delta: String, itemId: String)
    case inputCompleted(transcript: String, itemId: String)
    case outputDelta(delta: String, itemId: String)
    case outputDone(transcript: String, itemId: String)
    case agentMessageComplete
    case agentMessageCancelled
}

/// Coordinates all voice connection business logic
@MainActor
class VoiceConnectionCoordinator: ObservableObject {
    // MARK: - Published State

    /// The state machine (exposed for UI observation)
    let stateMachine = VoiceStateMachine()

    /// Current interaction state
    var state: VoiceInteractionState {
        stateMachine.state
    }

    // MARK: - Delegate

    weak var delegate: VoiceConnectionCoordinatorDelegate?

    // MARK: - Services

    private var azureService: VoiceLiveConnection?
    private var audioService: AudioService?
    private let settingsManager: VoiceSettingsManager
    private let toolRegistry: ToolRegistry
    private let historyManager: ConversationHistoryManager

    // MARK: - Coordinators

    private var eventHandler: AzureEventHandler?
    private var audioCoordinator: AudioCoordinator?
    private var settingsSyncCoordinator: SettingsSyncCoordinator?
    private var functionCallCoordinator: FunctionCallCoordinator?
    private var toolSyncCoordinator: ToolSyncCoordinator?

    // MARK: - Factories

    private let azureServiceFactory: (String, String, String, String, VoiceSettings) -> VoiceLiveConnection
    private let audioServiceFactory: () -> AudioService

    // MARK: - State

    private var stateMachineObserver: AnyCancellable?
    private var userCanceledInteraction = false

    // MARK: - Initialization

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
        self.settingsManager = settingsManager
        self.toolRegistry = toolRegistry
        self.historyManager = historyManager
        self.azureServiceFactory = azureServiceFactory
        self.audioServiceFactory = audioServiceFactory

        // Observe state machine changes
        stateMachineObserver = stateMachine.objectWillChange.sink { [weak self] _ in
            guard let self = self else { return }
            self.objectWillChange.send()

            Task { @MainActor in
                self.updateToolSyncInteractionState()
            }
        }

        // Create and start settings sync coordinator
        let coordinator = SettingsSyncCoordinator(settingsManager: settingsManager)
        coordinator.delegate = self
        coordinator.startObserving()
        self.settingsSyncCoordinator = coordinator

        AppLogger.general.info("VoiceConnectionCoordinator initialized")
    }

    // MARK: - Tool Sync State

    private func updateToolSyncInteractionState() {
        let isActive: Bool
        switch stateMachine.state {
        case .recording, .processing, .playing:
            isActive = true
        case .idle, .disconnected, .connecting, .reconnecting, .connectionFailed, .error:
            isActive = false
        }
        toolSyncCoordinator?.setInteractionState(isActive)
    }

    // MARK: - Connection Management

    func connect() async {
        guard !stateMachine.isConnected else { return }

        let config = AzureVoiceLiveConfig.fromBuildSettings
        if let validationError = config.validate() {
            stateMachine.transitionTo(.connectionFailed(validationError))
            return
        }

        stateMachine.transitionTo(.connecting)

        do {
            let (azure, audio) = createServices(with: config)
            createCoordinators(azure: azure, audio: audio)

            await startProcessingEvents()
            let sessionId = try await establishSession(azure: azure)
            onConnectionEstablished(sessionId: sessionId)

            AppLogger.general.info("Voice assistant connected and ready")
        } catch {
            AppLogger.logError(error, category: AppLogger.general, context: "Connection failed")
            stateMachine.transitionTo(.connectionFailed(error.localizedDescription))
            await cleanupOnConnectionFailure()
        }
    }

    func disconnect() async {
        guard stateMachine.isConnected else { return }

        AppLogger.general.info("Disconnecting voice assistant")

        audioCoordinator?.stopMonitoring()
        functionCallCoordinator?.cancelAll()
        functionCallCoordinator = nil

        toolSyncCoordinator?.stopObserving()
        toolSyncCoordinator?.setSessionActive(false)
        toolSyncCoordinator = nil

        await stopRecording()
        await audioService?.stopPlayback()
        await azureService?.disconnect()

        if let sessionId = stateMachine.sessionId {
            historyManager.endSession(sessionId)

            // Sync completed session to backend (fire-and-forget)
            if let session = historyManager.history.sessions.first(where: { $0.id == sessionId }) {
                Task {
                    await ConversationSyncService.shared.syncSession(session)
                }
            }
        }

        stateMachine.transitionTo(.disconnected)
        settingsManager.clearActiveSession()
        settingsSyncCoordinator?.setConnected(false)

        azureService = nil
        audioService = nil

        AppLogger.general.info("Voice assistant disconnected")
    }

    // MARK: - Connection Helpers

    private func createServices(with config: AzureVoiceLiveConfig) -> (VoiceLiveConnection, AudioService) {
        let endpoint = "\(config.resourceName).services.ai.azure.com"
        let azure = azureServiceFactory(
            endpoint,
            config.apiKey,
            config.model,
            config.apiVersion,
            settingsManager.settings
        )
        let audio = audioServiceFactory()

        self.azureService = azure
        self.audioService = audio

        return (azure, audio)
    }

    private func createCoordinators(azure: VoiceLiveConnection, audio: AudioService) {
        let handler = AzureEventHandler(
            audioService: audio,
            stateMachine: stateMachine,
            historyManager: historyManager
        )
        handler.delegate = self
        self.eventHandler = handler

        let audioCoord = AudioCoordinator(audioService: audio, azureService: azure)
        audioCoord.delegate = self
        self.audioCoordinator = audioCoord

        let functionCoord = FunctionCallCoordinator(
            toolRegistry: toolRegistry,
            azureService: azure
        )
        functionCoord.delegate = self
        self.functionCallCoordinator = functionCoord

        let toolSync = ToolSyncCoordinator(
            toolRegistry: toolRegistry,
            settingsManager: settingsManager
        )
        toolSync.delegate = self
        self.toolSyncCoordinator = toolSync
    }

    private func establishSession(azure: VoiceLiveConnection) async throws -> String {
        let enabledTools = toolRegistry.getEnabledTools()
        try await azure.connect()

        let configWithTools = RealtimeRequestSession.fromSettings(settingsManager.settings, tools: enabledTools)
        try await azure.session.update(configWithTools)

        let azureSessionState = await azure.sessionState
        guard let sessionId = azureSessionState.sessionId else {
            throw NSError(domain: "VoiceConnectionCoordinator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Session ID not available"])
        }

        return sessionId
    }

    private func onConnectionEstablished(sessionId: String) {
        stateMachine.transitionTo(.idle(sessionId: sessionId))
        audioCoordinator?.startMonitoring()
        settingsManager.markAsSynchronized(settingsManager.settings)
        settingsSyncCoordinator?.setConnected(true)
        toolSyncCoordinator?.setSessionActive(true)
        toolSyncCoordinator?.startObserving()
        historyManager.startSession(sessionId)
    }

    private func cleanupOnConnectionFailure() async {
        await azureService?.disconnect()
        azureService = nil
        audioService = nil
    }

    // MARK: - Voice Interaction

    func startRecording() async {
        guard stateMachine.canStartRecording else {
            AppLogger.general.warning("Cannot start recording in current state: \(self.stateMachine.state)")
            return
        }

        guard let audioService = audioService, let _ = azureService else {
            AppLogger.general.warning("Services not initialized")
            return
        }

        guard let sessionId = stateMachine.sessionId else {
            AppLogger.general.warning("No active session")
            return
        }

        do {
            AppLogger.general.info("Starting voice recording")
            userCanceledInteraction = false
            stateMachine.transitionTo(.recording(sessionId: sessionId, bufferBytes: 0))
            try await audioService.startCapture()
            await audioCoordinator?.startProcessingAudioChunks()
        } catch {
            AppLogger.logError(error, category: AppLogger.general, context: "Failed to start recording")
            stateMachine.transitionTo(.error(sessionId: sessionId, message: error.localizedDescription))
        }
    }

    func stopRecording() async {
        guard stateMachine.isRecording else { return }

        AppLogger.general.info("Stopping voice recording")
        guard let sessionId = stateMachine.sessionId else { return }

        await audioService?.stopCapture()
        try? await Task.sleep(nanoseconds: UInt64(AudioConfiguration.audioChunkProcessingDelay * 1_000_000_000))

        guard let azureService = azureService else { return }
        let bufferStats = await azureService.inputAudioBuffer.statistics
        AppLogger.general.debug("Buffer statistics: \(bufferStats.durationMs)ms, \(bufferStats.bytes) bytes, \(bufferStats.chunks) chunks")

        do {
            try await azureService.inputAudioBuffer.commit()
            stateMachine.transitionTo(.processing(sessionId: sessionId))
            AppLogger.general.debug("Audio buffer committed, processing...")
        } catch let error as AzureError {
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
        AppLogger.general.info("cancelInteraction() called from state: \(self.stateMachine.state)")
        userCanceledInteraction = true

        guard let sessionId = stateMachine.sessionId else {
            AppLogger.general.warning("cancelInteraction() - No session ID, returning early")
            return
        }

        functionCallCoordinator?.cancelAll()
        eventHandler?.resetRecordingState()
        await audioService?.stopCapture()
        await audioCoordinator?.stopProcessingAudioChunks()
        await audioService?.stopPlayback()

        delegate?.coordinator(self, didReceiveTranscriptionEvent: .agentMessageCancelled)

        try? await azureService?.response.cancel()
        try? await azureService?.inputAudioBuffer.clear()

        delegate?.coordinator(self, didUpdatePlaybackProgress: nil)
        audioCoordinator?.resetProgressTracking()

        if !stateMachine.state.isIdle {
            stateMachine.transitionTo(.idle(sessionId: sessionId))
        }

        AppLogger.general.info("cancelInteraction() completed, state is now: \(self.stateMachine.state)")
    }

    // MARK: - Settings Synchronization

    func performGracefulReconnection(with settings: VoiceSettings) async {
        AppLogger.general.info("Reconnecting to apply settings changes")

        audioCoordinator?.stopMonitoring()

        if stateMachine.isRecording {
            await audioService?.stopCapture()
        }

        try? await azureService?.inputAudioBuffer.clear()
        await audioService?.stopPlayback()

        await disconnect()
        try? await Task.sleep(nanoseconds: 500_000_000)
        await connect()
    }

    func performSessionUpdate(with settings: VoiceSettings) async {
        guard let azure = azureService else {
            AppLogger.general.warning("Azure service not available for session update")
            return
        }

        do {
            let config = RealtimeRequestSession.fromSettings(settings)
            try await azure.session.update(config)
            settingsManager.markAsSynchronized(settings)
            AppLogger.general.info("Session updated successfully with new settings")
        } catch {
            AppLogger.logError(error, category: AppLogger.general, context: "Failed to update session with new settings")
        }
    }

    private func applyPendingSettingsUpdate() async {
        await settingsSyncCoordinator?.applyPendingUpdates()
    }

    // MARK: - Event Processing

    private func startProcessingEvents() async {
        guard let azureService = azureService else { return }

        Task {
            for await event in await azureService.eventStream {
                await eventHandler?.handle(event)
            }
        }
    }

    // MARK: - Configuration

    var isConfigured: Bool {
        AzureVoiceLiveConfig.fromBuildSettings.isValid
    }
}

// MARK: - Azure Event Handler Delegate

extension VoiceConnectionCoordinator: AzureEventHandlerDelegate {
    func eventHandler(_ handler: AzureEventHandler, didReceiveAudioDelta data: Data) async {
        guard let audioService = audioService else { return }

        do {
            try await audioService.playAudio(data)
        } catch {
            AppLogger.logError(error, category: AppLogger.audio, context: "Failed to play audio")

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

    func eventHandler(_ handler: AzureEventHandler, didRequestFunctionCall item: RealtimeConversationFunctionCallItem) async {
        await functionCallCoordinator?.handleFunctionCall(item)
    }

    func eventHandler(_ handler: AzureEventHandler, didCreateConversationItem itemId: String, role: TranscriptionRole) {
        delegate?.coordinator(self, didReceiveTranscriptionEvent: .conversationItemCreated(itemId: itemId, role: role))
    }

    func eventHandler(_ handler: AzureEventHandler, didReceiveInputTranscriptionDelta delta: String, itemId: String) {
        delegate?.coordinator(self, didReceiveTranscriptionEvent: .inputDelta(delta: delta, itemId: itemId))
    }

    func eventHandler(_ handler: AzureEventHandler, didReceiveInputTranscriptionCompleted transcript: String, itemId: String) {
        delegate?.coordinator(self, didReceiveTranscriptionEvent: .inputCompleted(transcript: transcript, itemId: itemId))
    }

    func eventHandler(_ handler: AzureEventHandler, didReceiveOutputTranscriptionDelta delta: String, itemId: String) {
        delegate?.coordinator(self, didReceiveTranscriptionEvent: .outputDelta(delta: delta, itemId: itemId))
    }

    func eventHandler(_ handler: AzureEventHandler, didReceiveOutputTranscriptionDone transcript: String, itemId: String) {
        delegate?.coordinator(self, didReceiveTranscriptionEvent: .outputDone(transcript: transcript, itemId: itemId))
    }
}

// MARK: - Audio Coordinator Delegate

extension VoiceConnectionCoordinator: AudioCoordinatorDelegate {
    var sessionId: String? {
        stateMachine.sessionId
    }

    func audioCoordinator(_ coordinator: AudioCoordinator, didChangePlaybackState isPlaying: Bool, bufferCount: Int) {
        guard let sessionId = stateMachine.sessionId else {
            AppLogger.general.warning("No session ID during audio state change")
            return
        }

        if isPlaying {
            if !stateMachine.isPlaying {
                stateMachine.transitionTo(.playing(sessionId: sessionId, activeBuffers: bufferCount))
            }
        } else {
            if stateMachine.isPlaying {
                stateMachine.transitionTo(.idle(sessionId: sessionId))
                delegate?.coordinator(self, didUpdatePlaybackProgress: nil)
                audioCoordinator?.resetProgressTracking()
                delegate?.coordinator(self, didReceiveTranscriptionEvent: .agentMessageComplete)
                handlePlaybackCompleted()
            }
        }
    }

    private func handlePlaybackCompleted() {
        if userCanceledInteraction {
            userCanceledInteraction = false
            AppLogger.general.debug("Skipping auto-listen: user canceled interaction")
            return
        }

        guard settingsManager.settings.continuousListeningEnabled else { return }
        guard stateMachine.canStartRecording else {
            AppLogger.general.debug("Cannot auto-start recording: not in valid state")
            return
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)

            guard self.stateMachine.canStartRecording,
                  self.settingsManager.settings.continuousListeningEnabled else {
                return
            }

            AppLogger.general.info("Continuous listening: auto-starting recording")
            await self.startRecording()
        }
    }

    func audioCoordinator(_ coordinator: AudioCoordinator, didDetectOverflow event: BufferOverflowEvent) {
        // Overflow already logged by coordinator
    }

    func audioCoordinator(_ coordinator: AudioCoordinator, didUpdateProgress progress: Double) {
        delegate?.coordinator(self, didUpdatePlaybackProgress: progress)
    }
}

// MARK: - Function Call Coordinator Delegate

extension VoiceConnectionCoordinator: FunctionCallCoordinatorDelegate {
    func functionCallCoordinator(_ coordinator: FunctionCallCoordinator, didCompleteFunctionCall callId: String) {
        AppLogger.azure.info("Function call completed: \(callId)")
    }
}

// MARK: - Tool Sync Coordinator Delegate

extension VoiceConnectionCoordinator: ToolSyncCoordinatorDelegate {
    func toolSyncCoordinatorDidRequestSync(_ coordinator: ToolSyncCoordinator) async {
        guard let azure = azureService else {
            AppLogger.general.warning("Azure service not available for tool sync")
            return
        }

        do {
            let enabledTools = toolRegistry.getEnabledTools()
            let updatedConfig = RealtimeRequestSession.fromSettings(
                settingsManager.settings,
                tools: enabledTools
            )
            try await azure.session.update(updatedConfig)
            AppLogger.general.info("Tools synchronized successfully (\(enabledTools.count) enabled)")
        } catch {
            AppLogger.logError(error, category: AppLogger.general, context: "Tool sync failed")
        }
    }
}

// MARK: - Settings Sync Coordinator Delegate

extension VoiceConnectionCoordinator: SettingsSyncCoordinatorDelegate {
    var isActiveInteraction: Bool {
        get async {
            return stateMachine.isActive
        }
    }

    func performReconnection(with settings: VoiceSettings) async {
        await performGracefulReconnection(with: settings)
    }
}
