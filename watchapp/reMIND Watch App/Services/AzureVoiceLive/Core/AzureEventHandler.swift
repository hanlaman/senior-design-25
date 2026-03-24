//
//  AzureEventHandler.swift
//  reMIND Watch App
//
//  Handles Azure Voice Live server events in isolation from VoiceViewModel
//  Extracted from VoiceViewModel to reduce complexity and improve testability
//

import Foundation
import os

// MARK: - Focused Delegate Protocols (ISP)

/// Delegate for audio playback events
@MainActor
protocol AzureAudioEventDelegate: AnyObject {
    /// Called when audio delta data is received and should be played
    /// - Parameter data: Decoded PCM audio data ready for playback
    func eventHandler(_ handler: AzureEventHandler, didReceiveAudioDelta data: Data) async
}

/// Delegate for state machine transitions and control events
@MainActor
protocol AzureStateEventDelegate: AnyObject {
    /// Called when event handling triggers a state machine transition
    /// - Parameter state: New state to transition to
    func eventHandler(_ handler: AzureEventHandler, shouldTransitionTo state: VoiceInteractionState)

    /// Called when VAD (voice activity detection) stops capture
    /// - Parameter fromVAD: Whether this was triggered by server VAD
    func eventHandler(_ handler: AzureEventHandler, didStopCaptureForVAD: Bool) async

    /// Called when response completes and pending settings should be applied
    func eventHandler(_ handler: AzureEventHandler, shouldApplyPendingSettings: Bool) async
}

/// Delegate for function call events
@MainActor
protocol AzureFunctionCallDelegate: AnyObject {
    /// Called when a function call is requested by Azure
    /// - Parameter item: The function call conversation item
    func eventHandler(_ handler: AzureEventHandler, didRequestFunctionCall item: RealtimeConversationFunctionCallItem) async
}

/// Delegate for transcription events
@MainActor
protocol AzureTranscriptionDelegate: AnyObject {
    /// Called when a conversation item is created (use to pre-reserve sequence number)
    /// - Parameters:
    ///   - itemId: Azure conversation item ID
    ///   - role: Whether this is a user or agent message
    func eventHandler(_ handler: AzureEventHandler, didCreateConversationItem itemId: String, role: TranscriptionRole)

    /// Called when a delta for user input transcription is received
    func eventHandler(_ handler: AzureEventHandler, didReceiveInputTranscriptionDelta delta: String, itemId: String)

    /// Called when user input transcription is completed
    func eventHandler(_ handler: AzureEventHandler, didReceiveInputTranscriptionCompleted transcript: String, itemId: String)

    /// Called when a delta for agent output transcription is received
    func eventHandler(_ handler: AzureEventHandler, didReceiveOutputTranscriptionDelta delta: String, itemId: String)

    /// Called when agent output transcription is done (full text received)
    func eventHandler(_ handler: AzureEventHandler, didReceiveOutputTranscriptionDone transcript: String, itemId: String)
}

/// Combined delegate protocol for backward compatibility
/// Prefer using the focused protocols for new implementations
@MainActor
protocol AzureEventHandlerDelegate: AzureAudioEventDelegate, AzureStateEventDelegate, AzureFunctionCallDelegate, AzureTranscriptionDelegate {}

/// Handles all Azure Voice Live server events
/// Coordinates with audio service, state machine, and conversation history
@MainActor
class AzureEventHandler {
    // MARK: - Properties

    weak var delegate: AzureEventHandlerDelegate?

    private let audioService: AudioService
    private let stateMachine: VoiceStateMachine
    private let historyManager: ConversationHistoryManager

    /// Tracks the current recording's item ID to filter stale VAD events
    /// When user cancels and starts a new recording, Azure may send speech_stopped
    /// events for the old recording which should be ignored
    private var currentRecordingItemId: String?

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

    // MARK: - Recording State Management

    /// Reset recording state (call when user cancels or recording ends)
    func resetRecordingState() {
        AppLogger.azure.debug("Resetting recording state, clearing itemId: \(self.currentRecordingItemId ?? "nil")")
        currentRecordingItemId = nil
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

        case .inputAudioBufferSpeechStarted(let speechStartedEvent):
            AppLogger.azure.debug("Speech started (VAD) - itemId: \(speechStartedEvent.itemId)")
            // Track the current recording's item ID to filter stale events after cancel
            currentRecordingItemId = speechStartedEvent.itemId

        case .inputAudioBufferSpeechStopped(let speechStoppedEvent):
            AppLogger.azure.debug("Speech stopped (VAD) - itemId: \(speechStoppedEvent.itemId)")

            // Ignore stale speech_stopped events from a previous (canceled) recording
            if let currentId = currentRecordingItemId, currentId != speechStoppedEvent.itemId {
                AppLogger.azure.warning("Ignoring stale speech_stopped event (expected: \(currentId), got: \(speechStoppedEvent.itemId))")
                return
            }

            // Server VAD auto-commits the buffer, so just stop capturing
            // Do NOT call stopRecording() as that would try to commit again
            if stateMachine.isRecording {
                await delegate?.eventHandler(self, didStopCaptureForVAD: true)
                if let sessionId = stateMachine.sessionId {
                    delegate?.eventHandler(self, shouldTransitionTo: .processing(sessionId: sessionId))
                }
                // Clear the item ID since this recording is now complete
                currentRecordingItemId = nil
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

            // Pre-create transcription message for user/assistant messages (reserves sequence number)
            let itemId = String(itemEvent.item.id)
            switch itemEvent.item {
            case .userMessage:
                delegate?.eventHandler(self, didCreateConversationItem: itemId, role: .user)
            case .assistantMessage:
                delegate?.eventHandler(self, didCreateConversationItem: itemId, role: .agent)
            default:
                break  // Skip function calls, etc.
            }

            // Note: Messages are added to history when transcription completes
            // (see conversationItemTranscriptionCompleted and responseAudioTranscriptDone)
            // because transcript content is not available at item creation time

        case .responseCreated:
            AppLogger.azure.debug("Response created")
            // Note: State will transition to processing when audio chunks arrive

        case .responseOutputItemAdded(let itemEvent):
            AppLogger.azure.debug("Response output item added: \(itemEvent.item.id) (type: \(itemEvent.item.type))")

        case .responseContentPartAdded(let partEvent):
            AppLogger.azure.debug("Response content part added: \(partEvent.part.type)")

        case .responseAudioTranscriptDelta(let transcriptEvent):
            // Forward to delegate for live captioning (copy strings to avoid memory issues)
            let delta = String(transcriptEvent.delta)
            let itemId = String(transcriptEvent.itemId)
            delegate?.eventHandler(self, didReceiveOutputTranscriptionDelta: delta, itemId: itemId)

        case .responseAudioTranscriptDone(let transcriptEvent):
            AppLogger.azure.info("✓ Transcript complete: \(transcriptEvent.transcript)")
            // Forward to delegate for live captioning (copy strings to avoid memory issues)
            let transcript = String(transcriptEvent.transcript)
            let itemId = String(transcriptEvent.itemId)
            delegate?.eventHandler(self, didReceiveOutputTranscriptionDone: transcript, itemId: itemId)

            // Store completed assistant message to history
            if let sessionId = stateMachine.sessionId, !transcript.isEmpty {
                historyManager.addMessage(
                    itemId: itemId,
                    role: .assistant,
                    content: transcript,
                    sessionId: sessionId
                )
            }

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

        case .conversationItemTranscriptionCompleted(let transcriptEvent):
            AppLogger.azure.debug("Transcription completed: \(transcriptEvent.itemId)")
            // Forward to delegate for live captioning (copy strings to avoid memory issues)
            let transcript = String(transcriptEvent.transcript)
            let itemId = String(transcriptEvent.itemId)
            delegate?.eventHandler(self, didReceiveInputTranscriptionCompleted: transcript, itemId: itemId)

            // Store completed user message to history
            if let sessionId = stateMachine.sessionId, !transcript.isEmpty {
                historyManager.addMessage(
                    itemId: itemId,
                    role: .user,
                    content: transcript,
                    sessionId: sessionId
                )
            }

        case .conversationItemTranscriptionDelta(let transcriptEvent):
            // Forward to delegate for live captioning (copy strings to avoid memory issues)
            let delta = String(transcriptEvent.delta)
            let itemId = String(transcriptEvent.itemId)
            delegate?.eventHandler(self, didReceiveInputTranscriptionDelta: delta, itemId: itemId)

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
        // Ignore audio if interaction was canceled (state is now idle)
        guard stateMachine.isActive else {
            AppLogger.azure.debug("Ignoring audio delta after cancellation")
            return
        }

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
