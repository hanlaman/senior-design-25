//
//  AzureEventHandler.swift
//  reMIND Watch App
//
//  Handles Azure Voice Live server events in isolation from VoiceViewModel
//  Extracted from VoiceViewModel to reduce complexity and improve testability
//

import Foundation
import os

/// Delegate protocol for Azure event handler callbacks
@MainActor
protocol AzureEventHandlerDelegate: AnyObject {
    /// Called when audio delta data is received and should be played
    /// - Parameter data: Decoded PCM audio data ready for playback
    func eventHandler(_ handler: AzureEventHandler, didReceiveAudioDelta data: Data) async

    /// Called when event handling triggers a state machine transition
    /// - Parameter state: New state to transition to
    func eventHandler(_ handler: AzureEventHandler, shouldTransitionTo state: VoiceInteractionState)

    /// Called when VAD (voice activity detection) stops capture
    /// - Parameter fromVAD: Whether this was triggered by server VAD
    func eventHandler(_ handler: AzureEventHandler, didStopCaptureForVAD: Bool) async

    /// Called when response completes and pending settings should be applied
    func eventHandler(_ handler: AzureEventHandler, shouldApplyPendingSettings: Bool) async

    /// Called when a function call is requested by Azure
    /// - Parameter item: The function call conversation item
    func eventHandler(_ handler: AzureEventHandler, didRequestFunctionCall item: RealtimeConversationFunctionCallItem) async
}

/// Handles all Azure Voice Live server events
/// Coordinates with audio service, state machine, and conversation history
@MainActor
class AzureEventHandler {
    // MARK: - Properties

    weak var delegate: AzureEventHandlerDelegate?

    private let audioService: AudioService
    private let stateMachine: VoiceStateMachine
    private let historyManager: ConversationHistoryManager

    // MARK: - Initialization

    init(
        audioService: AudioService,
        stateMachine: VoiceStateMachine,
        historyManager: ConversationHistoryManager
    ) {
        self.audioService = audioService
        self.stateMachine = stateMachine
        self.historyManager = historyManager
    }

    // MARK: - Event Handling

    /// Handle an Azure server event
    /// - Parameter event: The Azure server event to process
    func handle(_ event: AzureServerEvent) async {
        switch event {
        case .sessionCreated(let sessionEvent):
            AppLogger.azure.info("Session created: \(sessionEvent.session.id)")
            // State transition handled by VoiceLiveConnection

        case .sessionUpdated:
            AppLogger.azure.debug("Session updated")
            // State transition handled by VoiceLiveConnection

        case .inputAudioBufferSpeechStarted:
            AppLogger.azure.debug("Speech started (VAD)")

        case .inputAudioBufferSpeechStopped:
            AppLogger.azure.debug("Speech stopped (VAD)")
            // Server VAD auto-commits the buffer, so just stop capturing
            // Do NOT call stopRecording() as that would try to commit again
            if stateMachine.isRecording {
                await delegate?.eventHandler(self, didStopCaptureForVAD: true)
                if let sessionId = stateMachine.sessionId {
                    delegate?.eventHandler(self, shouldTransitionTo: .processing(sessionId: sessionId))
                }
                AppLogger.general.debug("Stopped capture, waiting for server to commit buffer")
            }

        case .inputAudioBufferCommitted:
            AppLogger.azure.debug("Audio buffer committed")
            // Server has committed the buffer, transition to processing if not already
            if stateMachine.isRecording {
                if let sessionId = stateMachine.sessionId {
                    delegate?.eventHandler(self, shouldTransitionTo: .processing(sessionId: sessionId))
                }
            }

        case .conversationItemCreated(let itemEvent):
            AppLogger.azure.debug("Conversation item created: \(itemEvent.item.id) (type: \(itemEvent.item.type))")

            // Check if this is a function call
            if case .functionCall(let functionCallItem) = itemEvent.item {
                AppLogger.azure.info("🔧 Function call requested: \(functionCallItem.name) (call_id: \(functionCallItem.callId))")
                await delegate?.eventHandler(self, didRequestFunctionCall: functionCallItem)
            }

            // Add to conversation history
            if let sessionId = stateMachine.sessionId {
                if let (role, content) = extractMessageData(from: itemEvent.item) {
                    historyManager.addMessage(
                        itemId: itemEvent.item.id,
                        role: role,
                        content: content,
                        sessionId: sessionId
                    )
                }
            }

        case .responseCreated:
            AppLogger.azure.debug("Response created")
            // Note: State will transition to processing when audio chunks arrive

        case .responseOutputItemAdded(let itemEvent):
            AppLogger.azure.debug("Response output item added: \(itemEvent.item.id) (type: \(itemEvent.item.type))")

        case .responseContentPartAdded(let partEvent):
            AppLogger.azure.debug("Response content part added: \(partEvent.part.type)")

        case .responseAudioTranscriptDelta(let transcriptEvent):
            // High-frequency event - logging removed to reduce spam (fires 100s of times per interaction)
            // Uncomment for debugging: AppLogger.debug("Transcript delta: \(transcriptEvent.delta)", category: .azure, every: 20)
            break

        case .responseAudioTranscriptDone(let transcriptEvent):
            AppLogger.azure.info("✓ Transcript complete: \(transcriptEvent.transcript)")

        case .responseAudioDelta(let deltaEvent):
            // Decode and play audio
            await handleAudioDelta(deltaEvent)

        case .responseAudioDone:
            AppLogger.azure.info("✓ Audio streaming complete")

        case .responseDone:
            AppLogger.azure.info("Response done")
            // Audio state observation will automatically transition to .idle when playback completes

            // Check for pending settings updates to apply after interaction completes
            await delegate?.eventHandler(self, shouldApplyPendingSettings: true)

        case .error(let errorEvent):
            AppLogger.azure.error("Azure error: \(errorEvent.error.message)")
            if let sessionId = stateMachine.sessionId {
                delegate?.eventHandler(self, shouldTransitionTo: .error(sessionId: sessionId, message: errorEvent.error.message))
            } else {
                delegate?.eventHandler(self, shouldTransitionTo: .connectionFailed(errorEvent.error.message))
            }

        // Events with default handling (logged but no action needed)
        case .sessionAvatarConnecting:
            AppLogger.azure.debug("Avatar connecting")

        case .inputAudioBufferCleared:
            AppLogger.azure.debug("Audio buffer cleared")

        case .conversationItemRetrieved:
            AppLogger.azure.debug("Conversation item retrieved")

        case .conversationItemTruncated:
            AppLogger.azure.debug("Conversation item truncated")

        case .conversationItemDeleted:
            AppLogger.azure.debug("Conversation item deleted")

        case .conversationItemTranscriptionCompleted:
            AppLogger.azure.debug("Transcription completed")

        case .conversationItemTranscriptionDelta:
            // High-frequency event - logging removed to reduce spam
            break

        case .conversationItemTranscriptionFailed:
            AppLogger.azure.warning("Transcription failed")

        case .responseOutputItemDone:
            AppLogger.azure.debug("Response output item done")

        case .responseContentPartDone:
            AppLogger.azure.debug("Response content part done")

        case .responseTextDelta:
            // High-frequency event - logging removed to reduce spam
            break

        case .responseTextDone:
            AppLogger.azure.debug("Text done")

        case .responseAudioTimestampDelta:
            // High-frequency event - logging removed to reduce spam
            break

        case .responseAudioTimestampDone:
            AppLogger.azure.debug("Audio timestamp done")

        case .responseAnimationBlendshapesDelta:
            // High-frequency event - logging removed to reduce spam
            break

        case .responseAnimationBlendshapesDone:
            AppLogger.azure.debug("Animation blendshapes done")

        case .responseAnimationVisemeDelta:
            // High-frequency event - logging removed to reduce spam
            break

        case .responseAnimationVisemeDone:
            AppLogger.azure.debug("Animation viseme done")

        case .responseFunctionCallArgumentsDelta:
            // High-frequency event - logging removed to reduce spam
            break

        case .responseFunctionCallArgumentsDone(let event):
            AppLogger.azure.info("Function call arguments complete: call_id=\(event.callId), args=\(event.arguments)")

        case .responseMcpCallArgumentsDelta:
            // High-frequency event - logging removed to reduce spam
            break

        case .responseMcpCallArgumentsDone:
            AppLogger.azure.debug("MCP call arguments done")

        case .responseMcpCallInProgress:
            AppLogger.azure.debug("MCP call in progress")

        case .responseMcpCallCompleted:
            AppLogger.azure.debug("MCP call completed")

        case .responseMcpCallFailed:
            AppLogger.azure.warning("MCP call failed")

        case .mcpListToolsInProgress:
            AppLogger.azure.debug("MCP list tools in progress")

        case .mcpListToolsCompleted:
            AppLogger.azure.debug("MCP list tools completed")

        case .mcpListToolsFailed:
            AppLogger.azure.warning("MCP list tools failed")

        case .rateLimitsUpdated:
            AppLogger.azure.debug("Rate limits updated")

        case .unknown(let type):
            AppLogger.azure.warning("Unknown event type: \(type)")
        }
    }

    // MARK: - Audio Handling

    /// Handle response audio delta event
    /// - Parameter event: Audio delta event with base64-encoded audio data
    private func handleAudioDelta(_ event: ResponseAudioDeltaEvent) async {
        // Decode base64 audio
        guard let audioData = AudioConverter.decodeFromBase64(event.delta) else {
            AppLogger.audio.error("Failed to decode base64 audio")
            return
        }

        // Delegate will play audio - state transition handled by audio stream observer
        // AudioService will emit playback state changes via playbackStateStream
        // The observer will transition from .processing → .playing when audio starts
        await delegate?.eventHandler(self, didReceiveAudioDelta: audioData)
    }

    // MARK: - Message Extraction

    /// Extract role and transcript content from conversation item
    /// - Parameter item: Conversation item from Azure
    /// - Returns: Tuple of (role, content) or nil if item has no extractable content
    private func extractMessageData(
        from item: RealtimeConversationResponseItem
    ) -> (role: ConversationMessage.MessageRole, content: String)? {
        switch item {
        case .userMessage(let msg):
            let transcript = msg.content.compactMap { part -> String? in
                if case .inputAudio(let audio) = part {
                    return audio.transcript
                } else if case .inputText(let text) = part {
                    return text.text
                }
                return nil
            }.joined(separator: " ")

            return transcript.isEmpty ? nil : (.user, transcript)

        case .assistantMessage(let msg):
            let transcript = msg.content.compactMap { part -> String? in
                if case .outputAudio(let audio) = part {
                    return audio.transcript
                } else if case .outputText(let text) = part {
                    return text.text
                } else if case .responseAudio(let audio) = part {
                    return audio.transcript
                }
                return nil
            }.joined(separator: " ")

            return transcript.isEmpty ? nil : (.assistant, transcript)

        default:
            return nil  // Skip system messages, function calls, etc.
        }
    }
}
