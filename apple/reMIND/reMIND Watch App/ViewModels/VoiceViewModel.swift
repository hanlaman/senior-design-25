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

    @Published private(set) var voiceState: VoiceState = .disconnected
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var errorMessage: String?

    // MARK: - Services

    private var azureService: AzureVoiceLiveService?
    private var audioService: AudioService?

    // MARK: - State

    private var isInitialized = false
    private var isProcessingAudio = false

    // MARK: - Initialization

    init() {
        // Services will be initialized on connect
    }

    // MARK: - Connection Management

    func connect() async {
        guard connectionState != .connected else { return }

        // Validate configuration
        let config = AzureVoiceLiveConfig.fromBuildSettings
        if let validationError = config.validate() {
            errorMessage = validationError
            voiceState = .error(validationError)
            return
        }

        guard let websocketURL = config.websocketURL else {
            errorMessage = "Invalid WebSocket URL"
            voiceState = .error("Invalid WebSocket URL")
            return
        }

        connectionState = .connecting
        voiceState = .connecting

        do {
            // Create services
            let azure = AzureVoiceLiveService(apiKey: config.apiKey, websocketURL: websocketURL)
            let audio = AudioService()

            self.azureService = azure
            self.audioService = audio

            // Connect to Azure WebSocket
            try await azure.connect()

            // Start processing events immediately
            await startProcessingEvents()

            // Send session.update to configure the session (required as first message)
            AppLogger.general.info("Sending session.update to configure session")
            try await azure.updateSession(.basicAudioConversation())

            // Wait for session.created event (with 10 second timeout)
            AppLogger.general.info("Waiting for session.created event...")
            try await azure.waitForSessionCreated()

            // Mark as ready
            connectionState = .connected
            voiceState = .idle

            AppLogger.general.info("Voice assistant connected and ready")

        } catch {
            AppLogger.logError(error, category: AppLogger.general, context: "Connection failed")
            connectionState = .error(error.localizedDescription)
            voiceState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    func disconnect() async {
        guard connectionState == .connected else { return }

        AppLogger.general.info("Disconnecting voice assistant")

        // Stop any active recording or playback
        await stopRecording()
        await audioService?.stopPlayback()

        // Disconnect from Azure
        await azureService?.disconnect()

        connectionState = .disconnected
        voiceState = .disconnected

        azureService = nil
        audioService = nil

        AppLogger.general.info("Voice assistant disconnected")
    }

    // MARK: - Voice Interaction

    func startRecording() async {
        guard connectionState == .connected else {
            errorMessage = "Not connected to Azure"
            return
        }

        guard voiceState.canStartRecording else {
            AppLogger.general.warning("Cannot start recording in current state: \(self.voiceState)")
            return
        }

        guard let audioService = audioService, let azureService = azureService else {
            errorMessage = "Services not initialized"
            return
        }

        do {
            AppLogger.general.info("Starting voice recording")

            voiceState = .recording

            // Start audio capture
            try await audioService.startCapture()

            // Process audio chunks
            Task {
                await processAudioChunks(audioService: audioService, azureService: azureService)
            }

        } catch {
            AppLogger.logError(error, category: AppLogger.general, context: "Failed to start recording")
            voiceState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    func stopRecording() async {
        guard voiceState.isRecording else { return }

        AppLogger.general.info("Stopping voice recording")

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
            voiceState = .processing
            AppLogger.general.info("Audio buffer committed, processing...")
        } catch let error as AzureError {
            // Handle buffer too small error specifically
            if case .bufferTooSmall = error {
                AppLogger.general.warning("Audio buffer too small, clearing buffer")
                try? await azureService.clearAudioBuffer()
                voiceState = .idle
                errorMessage = error.localizedDescription
            } else {
                AppLogger.logError(error, category: AppLogger.general, context: "Failed to commit audio buffer")
                voiceState = .error(error.localizedDescription)
                errorMessage = error.localizedDescription
            }
        } catch {
            AppLogger.logError(error, category: AppLogger.general, context: "Failed to commit audio buffer")
            voiceState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    func cancelInteraction() async {
        AppLogger.general.info("Canceling interaction")

        // Stop recording if active
        await audioService?.stopCapture()

        // Stop playback if active
        await audioService?.stopPlayback()

        // Cancel Azure response
        try? await azureService?.cancelResponse()

        // Clear audio buffer
        try? await azureService?.clearAudioBuffer()

        voiceState = .idle
    }

    // MARK: - Private Methods

    private func processAudioChunks(audioService: AudioService, azureService: AzureVoiceLiveService) async {
        guard !isProcessingAudio else { return }
        isProcessingAudio = true

        for await chunk in await audioService.audioChunkStream {
            guard voiceState.isRecording else {
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
            // State transition happens in connect() after waitForSessionCreated()

        case .sessionUpdated:
            AppLogger.azure.info("Session updated")
            // State transition happens in connect() after waitForSessionCreated()

        case .inputAudioBufferSpeechStarted:
            AppLogger.azure.info("Speech started (VAD)")

        case .inputAudioBufferSpeechStopped:
            AppLogger.azure.info("Speech stopped (VAD)")
            // Server VAD auto-commits the buffer, so just stop capturing
            // Do NOT call stopRecording() as that would try to commit again
            if voiceState.isRecording {
                await audioService?.stopCapture()
                voiceState = .processing
                AppLogger.general.info("Stopped capture, waiting for server to commit buffer")
            }

        case .inputAudioBufferCommitted:
            AppLogger.azure.info("Audio buffer committed")
            // Server has committed the buffer, transition to processing if not already
            if voiceState.isRecording {
                voiceState = .processing
            }

        case .conversationItemCreated(let itemEvent):
            AppLogger.azure.info("Conversation item created: \(itemEvent.item.id) (type: \(itemEvent.item.type))")

        case .responseCreated:
            AppLogger.azure.info("Response created")
            voiceState = .processing

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
            // Wait a bit for playback to finish
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            if voiceState.isPlaying {
                voiceState = .idle
            }

        case .error(let errorEvent):
            AppLogger.azure.error("Azure error: \(errorEvent.error.message)")
            voiceState = .error(errorEvent.error.message)
            errorMessage = errorEvent.error.message

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

        // Update state to playing if not already
        if !voiceState.isPlaying {
            voiceState = .playing
        }

        // Play audio
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
