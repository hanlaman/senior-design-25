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

    private var azureService: AzureVoiceLiveService?
    private var audioService: AudioService?
    private let settingsManager = VoiceSettingsManager.shared

    // MARK: - State

    private var isInitialized = false
    private var isProcessingAudio = false
    private var audioStateTask: Task<Void, Never>?
    private var stateMachineObserver: AnyCancellable?

    // MARK: - Initialization

    init() {
        // Services will be initialized on connect

        // Observe state machine changes to trigger view updates
        stateMachineObserver = stateMachine.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }

        // Note: Voice settings (including rate) cannot be updated mid-session per Azure API
        // Voice configuration is immutable once session is initialized
        // Settings changes will apply on next connection
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

        guard let websocketURL = config.websocketURL else {
            let errorMsg = "Invalid WebSocket URL"
            stateMachine.transitionTo(.connectionFailed(errorMsg))
            return
        }

        stateMachine.transitionTo(.connecting)

        do {
            // Create services with current settings
            let azure = AzureVoiceLiveService(
                apiKey: config.apiKey,
                websocketURL: websocketURL,
                settings: settingsManager.settings
            )
            let audio = AudioService()

            self.azureService = azure
            self.audioService = audio

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

        // Stop any active recording or playback
        await stopRecording()
        await audioService?.stopPlayback()

        // Disconnect from Azure
        await azureService?.disconnect()

        stateMachine.transitionTo(.disconnected)

        azureService = nil
        audioService = nil

        AppLogger.general.info("Voice assistant disconnected")
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

            // Process audio chunks
            Task {
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
        let bufferStats = await azureService.getAudioBufferStatistics()
        AppLogger.general.info("Buffer statistics: \(bufferStats.durationMs)ms, \(bufferStats.bytes) bytes, \(bufferStats.chunks) chunks")

        // Commit audio buffer to Azure
        do {
            try await azureService.commitAudioBuffer()
            stateMachine.transitionTo(.processing(sessionId: sessionId))
            AppLogger.general.info("Audio buffer committed, processing...")
        } catch let error as AzureError {
            // Handle buffer too small error specifically
            if case .bufferTooSmall = error {
                AppLogger.general.warning("Audio buffer too small, clearing buffer")
                try? await azureService.clearAudioBuffer()
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
        try? await azureService?.cancelResponse()

        // Clear audio buffer
        try? await azureService?.clearAudioBuffer()

        stateMachine.transitionTo(.idle(sessionId: sessionId))
    }

    // MARK: - Private Methods

    private func startObservingAudioState() {
        audioStateTask?.cancel()

        guard let audioService = audioService else {
            AppLogger.general.warning("Cannot start observing audio state: no audio service")
            return
        }

        AppLogger.general.info("Starting audio state observation")

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

    private func processAudioChunks(audioService: AudioService, azureService: AzureVoiceLiveService) async {
        guard !isProcessingAudio else { return }
        isProcessingAudio = true

        for await chunk in await audioService.audioChunkStream {
            guard stateMachine.isRecording else {
                break
            }

            do {
                try await azureService.sendAudioChunk(chunk)
            } catch {
                AppLogger.logError(error, category: AppLogger.audio, context: "Failed to send audio chunk")
            }
        }

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
        switch event {
        case .sessionCreated(let sessionEvent):
            AppLogger.azure.info("Session created: \(sessionEvent.session.id)")
            // State transition handled by AzureVoiceLiveService

        case .sessionUpdated:
            AppLogger.azure.info("Session updated")
            // State transition handled by AzureVoiceLiveService

        case .inputAudioBufferSpeechStarted:
            AppLogger.azure.info("Speech started (VAD)")

        case .inputAudioBufferSpeechStopped:
            AppLogger.azure.info("Speech stopped (VAD)")
            // Server VAD auto-commits the buffer, so just stop capturing
            // Do NOT call stopRecording() as that would try to commit again
            if stateMachine.isRecording {
                await audioService?.stopCapture()
                if let sessionId = stateMachine.sessionId {
                    stateMachine.transitionTo(.processing(sessionId: sessionId))
                }
                AppLogger.general.info("Stopped capture, waiting for server to commit buffer")
            }

        case .inputAudioBufferCommitted:
            AppLogger.azure.info("Audio buffer committed")
            // Server has committed the buffer, transition to processing if not already
            if stateMachine.isRecording {
                if let sessionId = stateMachine.sessionId {
                    stateMachine.transitionTo(.processing(sessionId: sessionId))
                }
            }

        case .conversationItemCreated(let itemEvent):
            AppLogger.azure.info("Conversation item created: \(itemEvent.item.id) (type: \(itemEvent.item.type))")

        case .responseCreated:
            AppLogger.azure.info("Response created")
            // Note: State will transition to processing when audio chunks arrive

        case .responseOutputItemAdded(let itemEvent):
            AppLogger.azure.info("Response output item added: \(itemEvent.item.id) (type: \(itemEvent.item.type))")

        case .responseContentPartAdded(let partEvent):
            AppLogger.azure.info("Response content part added: \(partEvent.part.type)")

        case .responseAudioTranscriptDelta(let transcriptEvent):
            AppLogger.azure.debug("Transcript delta: \(transcriptEvent.delta)")

        case .responseAudioTranscriptDone(let transcriptEvent):
            AppLogger.azure.info("Complete transcript: \(transcriptEvent.transcript)")

        case .responseAudioDelta(let deltaEvent):
            // Decode and play audio
            await handleResponseAudioDelta(deltaEvent)

        case .responseAudioDone:
            AppLogger.azure.info("Response audio done")

        case .responseDone:
            AppLogger.azure.info("Response done")
            // Audio state observation will automatically transition to .idle when playback completes

        case .error(let errorEvent):
            AppLogger.azure.error("Azure error: \(errorEvent.error.message)")
            if let sessionId = stateMachine.sessionId {
                stateMachine.transitionTo(.error(sessionId: sessionId, message: errorEvent.error.message))
            } else {
                stateMachine.transitionTo(.connectionFailed(errorEvent.error.message))
            }

        // Events with default handling (logged but no action needed)
        case .sessionAvatarConnecting:
            AppLogger.azure.info("Avatar connecting")

        case .inputAudioBufferCleared:
            AppLogger.azure.info("Audio buffer cleared")

        case .conversationItemRetrieved:
            AppLogger.azure.info("Conversation item retrieved")

        case .conversationItemTruncated:
            AppLogger.azure.info("Conversation item truncated")

        case .conversationItemDeleted:
            AppLogger.azure.info("Conversation item deleted")

        case .conversationItemTranscriptionCompleted:
            AppLogger.azure.info("Transcription completed")

        case .conversationItemTranscriptionDelta:
            AppLogger.azure.debug("Transcription delta")

        case .conversationItemTranscriptionFailed:
            AppLogger.azure.warning("Transcription failed")

        case .responseOutputItemDone:
            AppLogger.azure.info("Response output item done")

        case .responseContentPartDone:
            AppLogger.azure.info("Response content part done")

        case .responseTextDelta:
            AppLogger.azure.debug("Text delta")

        case .responseTextDone:
            AppLogger.azure.info("Text done")

        case .responseAudioTimestampDelta:
            AppLogger.azure.debug("Audio timestamp delta")

        case .responseAudioTimestampDone:
            AppLogger.azure.info("Audio timestamp done")

        case .responseAnimationBlendshapesDelta:
            AppLogger.azure.debug("Animation blendshapes delta")

        case .responseAnimationBlendshapesDone:
            AppLogger.azure.info("Animation blendshapes done")

        case .responseAnimationVisemeDelta:
            AppLogger.azure.debug("Animation viseme delta")

        case .responseAnimationVisemeDone:
            AppLogger.azure.info("Animation viseme done")

        case .responseFunctionCallArgumentsDelta:
            AppLogger.azure.debug("Function call arguments delta")

        case .responseFunctionCallArgumentsDone:
            AppLogger.azure.info("Function call arguments done")

        case .responseMcpCallArgumentsDelta:
            AppLogger.azure.debug("MCP call arguments delta")

        case .responseMcpCallArgumentsDone:
            AppLogger.azure.info("MCP call arguments done")

        case .responseMcpCallInProgress:
            AppLogger.azure.info("MCP call in progress")

        case .responseMcpCallCompleted:
            AppLogger.azure.info("MCP call completed")

        case .responseMcpCallFailed:
            AppLogger.azure.warning("MCP call failed")

        case .mcpListToolsInProgress:
            AppLogger.azure.info("MCP list tools in progress")

        case .mcpListToolsCompleted:
            AppLogger.azure.info("MCP list tools completed")

        case .mcpListToolsFailed:
            AppLogger.azure.warning("MCP list tools failed")

        case .rateLimitsUpdated:
            AppLogger.azure.info("Rate limits updated")

        case .unknown(let type):
            AppLogger.azure.warning("Unknown event type: \(type)")
        }
    }

    private func handleResponseAudioDelta(_ event: ResponseAudioDeltaEvent) async {
        guard let audioService = audioService else { return }

        // Decode base64 audio
        guard let audioData = AudioConverter.decodeFromBase64(event.delta) else {
            AppLogger.audio.error("Failed to decode base64 audio")
            return
        }

        // Play audio - state transition handled by audio stream observer
        // AudioService will emit playback state changes via playbackStateStream
        // The observer will transition from .processing → .playing when audio starts
        do {
            try await audioService.playAudio(audioData)
        } catch {
            AppLogger.logError(error, category: AppLogger.audio, context: "Failed to play audio")
        }
    }

    // MARK: - Configuration

    var isConfigured: Bool {
        AzureVoiceLiveConfig.fromBuildSettings.isValid
    }
}
