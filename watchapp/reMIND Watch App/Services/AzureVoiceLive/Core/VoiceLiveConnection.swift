//
//  VoiceLiveConnection.swift
//  reMIND Watch App
//
//  Azure Voice Live connection with resource-based API
//

import Foundation
import os

/// Azure Voice Live connection with resource-based organization
public actor VoiceLiveConnection {
    // MARK: - Properties

    private let apiKey: String
    private let endpoint: String
    private let model: String
    private let apiVersion: String
    private var settings: VoiceSettings

    private var webSocketManager: WebSocketManager?

    /// Observer for WebSocket connection state changes
    private var connectionStateObserver: Task<Void, Never>?

    public private(set) var connectionState: ConnectionState = .disconnected
    public private(set) var sessionState: AzureSessionState = .uninitialized

    // Event stream
    private var eventContinuation: AsyncStream<AzureServerEvent>.Continuation?
    public let eventStream: AsyncStream<AzureServerEvent>

    // MARK: - Resources

    /// Session configuration management
    public lazy var session: SessionResource = SessionResource(connection: self)

    /// Input audio buffer management
    public lazy var inputAudioBuffer: InputAudioBuffer = InputAudioBuffer(connection: self)

    /// Output audio buffer management
    public lazy var outputAudioBuffer: OutputAudioBuffer = OutputAudioBuffer(connection: self)

    /// Conversation management
    public lazy var conversation: Conversation = Conversation(connection: self)

    /// Response management
    public lazy var response: Response = Response(connection: self)

    // MARK: - Initialization

    /// Initialize a new Voice Live connection
    /// - Parameters:
    ///   - endpoint: Azure resource endpoint (e.g., "your-resource.services.ai.azure.com")
    ///   - apiKey: Azure API key
    ///   - model: Model to use (e.g., "gpt-4o-realtime-preview")
    ///   - apiVersion: API version (defaults to "2024-10-01-preview")
    ///   - settings: Voice settings configuration
    public init(
        endpoint: String,
        apiKey: String,
        model: String,
        apiVersion: String = "2024-10-01-preview",
        settings: VoiceSettings
    ) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.model = model
        self.apiVersion = apiVersion
        self.settings = settings

        // Create event stream
        var continuationHolder: AsyncStream<AzureServerEvent>.Continuation?
        self.eventStream = AsyncStream { continuation in
            continuationHolder = continuation
        }
        self.eventContinuation = continuationHolder

        // Resources are lazy and will be initialized when first accessed
    }

    // MARK: - Connection Management

    public func connect() async throws {
        guard connectionState != .connected else {
            AppLogger.azure.warning("Already connected")
            return
        }

        guard sessionState == .uninitialized else {
            AppLogger.azure.warning("Session already exists: \(self.sessionState.displayText)")
            return
        }

        connectionState = .connecting
        sessionState = .establishing(sessionId: nil)
        AppLogger.azure.info("Connecting to Azure Voice Live API")

        // Build WebSocket URL
        let urlString = "wss://\(endpoint)/voice-live/realtime?api-version=\(apiVersion)&model=\(model)"
        guard let websocketURL = URL(string: urlString) else {
            throw AzureError.invalidConfiguration
        }

        // Create WebSocket manager
        let manager = WebSocketManager(url: websocketURL, apiKey: apiKey)
        webSocketManager = manager

        // Start observing connection state changes from WebSocketManager
        startObservingConnectionState(manager)

        // Connect (now awaits handshake completion via delegate)
        try await manager.connect()

        connectionState = .connected
        AppLogger.azure.info("Connected to Azure Voice Live API, waiting for session.created")

        // Start processing events
        AppLogger.azure.debug("Creating Task to process WebSocket events")
        Task {
            AppLogger.azure.debug("Task started, calling processWebSocketEvents()")
            await processWebSocketEvents()
            AppLogger.azure.debug("processWebSocketEvents() completed")
        }

        // Give WebSocket a moment to be fully ready
        try await Task.sleep(nanoseconds: UInt64(AudioConfiguration.audioChunkProcessingDelay * 1_000_000_000))

        // Send session.update to configure the session with user settings
        AppLogger.azure.info("Sending session.update to configure session with settings (rate: \(self.settings.speakingRate)x)")
        try await session.update(.fromSettings(self.settings))

        // Wait for session to be ready (session.created and session.updated)
        try await session.waitForReady()

        AppLogger.azure.info("Session ready: \(self.sessionState.displayText)")
    }

    public func disconnect() async {
        AppLogger.azure.info("Disconnecting from Azure Voice Live API")

        sessionState = .terminating

        // Stop observing connection state
        connectionStateObserver?.cancel()
        connectionStateObserver = nil

        await webSocketManager?.disconnect()
        webSocketManager = nil

        connectionState = .disconnected
        sessionState = .uninitialized

        eventContinuation?.finish()

        AppLogger.azure.info("Disconnected from Azure Voice Live API")
    }

    /// Re-establish session after WebSocket reconnection
    private func reestablishSession() async {
        AppLogger.azure.info("Re-establishing session after WebSocket reconnection")

        sessionState = .reconnecting

        do {
            // Give WebSocket a moment to be fully ready
            // Note: Azure sends session.created immediately on connect, which will
            // transition us from .reconnecting to .establishing(sessionId: newId)
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

            // Send session.update to re-configure the session
            // Don't overwrite sessionState here - the event handler sets it when session.created arrives
            AppLogger.azure.info("Sending session.update to re-configure session (current state: \(self.sessionState.displayText))")
            try await session.update(.fromSettings(self.settings))

            // Wait for session.created and session.updated events
            try await session.waitForReady()

            AppLogger.azure.info("Session re-established successfully: \(self.sessionState.displayText)")
        } catch {
            AppLogger.logError(error, category: AppLogger.azure, context: "Failed to re-establish session")
            sessionState = .error("Session re-establishment failed: \(error.localizedDescription)")
        }
    }

    // MARK: - MCP Tool Management

    public func sendMcpApproval(approve: Bool, approvalRequestId: String) async throws {
        guard connectionState == .connected else {
            throw AzureError.notConnected
        }

        guard sessionState.canAcceptConversation else {
            throw AzureError.sessionNotReady
        }

        AppLogger.azure.debug("Sending MCP approval: \(approve) for request \(approvalRequestId)")

        let event = McpApprovalResponseEvent(
            approve: approve,
            approvalRequestId: approvalRequestId
        )
        try await sendEvent(event)
    }

    // MARK: - Internal Methods (for resources)

    /// Send an event to the Azure Voice Live API
    /// - Parameter event: The event to send
    /// - Throws: `AzureError` if encoding or sending fails
    internal func sendEvent<T: Encodable>(_ event: T) async throws {
        guard let manager = webSocketManager else {
            throw AzureError.notConnected
        }

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys

        do {
            let data = try encoder.encode(event)

            // Convert to String and send as text (Azure requires text messages, not binary)
            guard let jsonString = String(data: data, encoding: .utf8) else {
                throw AzureError.encodingFailed(NSError(domain: "AzureVoiceLive", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert JSON to string"]))
            }

            try await manager.send(jsonString)
        } catch {
            AppLogger.logError(error, category: AppLogger.azure, context: "Failed to send event")
            throw AzureError.encodingFailed(error)
        }
    }

    // MARK: - Connection State Observation

    private func startObservingConnectionState(_ manager: WebSocketManager) {
        connectionStateObserver?.cancel()

        connectionStateObserver = Task {
            for await state in await manager.connectionStateStream {
                await handleWebSocketStateChange(state)
            }
        }
    }

    private func handleWebSocketStateChange(_ state: ConnectionState) {
        switch state {
        case .reconnecting(let attempt, let maxAttempts):
            connectionState = .reconnecting(attempt: attempt, maxAttempts: maxAttempts)
            AppLogger.azure.info("WebSocket reconnecting: attempt \(attempt)/\(maxAttempts)")

        case .disconnected:
            // Only update if we weren't already disconnected (avoid duplicate transitions)
            if connectionState != .disconnected {
                connectionState = .disconnected
                sessionState = .uninitialized
                AppLogger.azure.warning("WebSocket unexpectedly disconnected")
            }

        case .error(let message):
            connectionState = .error(message)
            AppLogger.azure.error("WebSocket error: \(message)")

        case .connected:
            connectionState = .connected
            // After reconnection, re-establish session if it was lost
            if sessionState == .uninitialized {
                AppLogger.azure.info("WebSocket reconnected, re-establishing session")
                Task {
                    await reestablishSession()
                }
            }

        case .connecting:
            // Initial connection is handled by connect() flow
            break
        }
    }

    // MARK: - Private Methods

    private func processWebSocketEvents() async {
        guard let manager = webSocketManager else { return }

        for await result in manager.eventStream {
            switch result {
            case .success(let data):
                await handleEventData(data)

            case .failure(let error):
                AppLogger.logError(error, category: AppLogger.azure, context: "WebSocket event error")
                connectionState = .error(error.localizedDescription)
                eventContinuation?.yield(.error(ErrorEvent(
                    type: "error",
                    error: RealtimeErrorDetails(
                        type: "websocket_error",
                        code: "websocket_error",
                        message: error.localizedDescription,
                        param: nil,
                        eventId: UUID().uuidString
                    )
                )))
            }
        }
    }

    private func handleEventData(_ data: Data) async {
        do {
            // Decode event envelope to get type
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys

            let envelope = try decoder.decode(AzureEventEnvelope.self, from: data)

            // Decode specific event based on type
            let event = try decodeEvent(type: envelope.type, data: data, decoder: decoder)

            // Handle session state transitions
            switch event {
            case .sessionCreated(let sessionCreated):
                let newSessionId = sessionCreated.session.id

                // Transition from establishing or reconnecting → establishing(with ID)
                // Note: Azure sends session.created immediately on WebSocket connect, before we send session.update
                if case .establishing = sessionState {
                    sessionState = .establishing(sessionId: newSessionId)
                    AppLogger.azure.info("Session created: \(newSessionId) - Waiting for session.updated")
                } else if case .reconnecting = sessionState {
                    sessionState = .establishing(sessionId: newSessionId)
                    AppLogger.azure.info("Session created during reconnection: \(newSessionId) - Waiting for session.updated")
                } else {
                    AppLogger.azure.warning("Received session.created in unexpected state: \(self.sessionState.displayText)")
                }

            case .sessionUpdated:
                // Transition from establishing → ready, or acknowledge mid-session update
                if case .establishing(let id) = sessionState, let sessionId = id {
                    sessionState = .ready(sessionId: sessionId)
                    await inputAudioBuffer.resetTracking()
                    AppLogger.azure.info("Session ready: \(sessionId)")
                } else if case .ready(let sessionId) = sessionState {
                    AppLogger.azure.info("Session configuration updated successfully (mid-session): \(sessionId)")
                } else {
                    AppLogger.azure.warning("Received session.updated in unexpected state: \(self.sessionState.displayText)")
                }

            case .error(let errorEvent):
                sessionState = .error(errorEvent.error.message)

            default:
                break
            }

            // Yield event to stream
            eventContinuation?.yield(event)

        } catch let error as DecodingError {
            // Detailed decoding error logging
            let jsonString = String(data: data, encoding: .utf8) ?? "<unable to decode data as UTF-8>"

            switch error {
            case .keyNotFound(let key, let context):
                AppLogger.azure.error("Decoding error - Key not found: '\(key.stringValue)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                AppLogger.azure.error("Raw JSON: \(jsonString)")

            case .typeMismatch(let type, let context):
                AppLogger.azure.error("Decoding error - Type mismatch: expected '\(type)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                AppLogger.azure.error("Description: \(context.debugDescription)")
                AppLogger.azure.error("Raw JSON: \(jsonString)")

            case .valueNotFound(let type, let context):
                AppLogger.azure.error("Decoding error - Value not found: expected '\(type)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                AppLogger.azure.error("Description: \(context.debugDescription)")
                AppLogger.azure.error("Raw JSON: \(jsonString)")

            case .dataCorrupted(let context):
                AppLogger.azure.error("Decoding error - Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                AppLogger.azure.error("Description: \(context.debugDescription)")
                AppLogger.azure.error("Raw JSON: \(jsonString)")

            @unknown default:
                AppLogger.azure.error("Decoding error - Unknown: \(error.localizedDescription)")
                AppLogger.azure.error("Raw JSON: \(jsonString)")
            }
        } catch {
            let jsonString = String(data: data, encoding: .utf8) ?? "<unable to decode data as UTF-8>"
            AppLogger.logError(error, category: AppLogger.azure, context: "Failed to decode event")
            AppLogger.azure.error("Raw JSON: \(jsonString)")
        }
    }

    private func decodeEvent(type: String, data: Data, decoder: JSONDecoder) throws -> AzureServerEvent {
        switch type {
        // Session events
        case "session.created":
            let event = try decoder.decode(SessionCreatedEvent.self, from: data)
            return .sessionCreated(event)

        case "session.updated":
            let event = try decoder.decode(SessionUpdatedEvent.self, from: data)
            return .sessionUpdated(event)

        case "session.avatar.connecting":
            let event = try decoder.decode(SessionAvatarConnectingEvent.self, from: data)
            return .sessionAvatarConnecting(event)

        // Input audio buffer events
        case "input_audio_buffer.committed":
            let event = try decoder.decode(InputAudioBufferCommittedEvent.self, from: data)
            return .inputAudioBufferCommitted(event)

        case "input_audio_buffer.cleared":
            let event = try decoder.decode(InputAudioBufferClearedEvent.self, from: data)
            return .inputAudioBufferCleared(event)

        case "input_audio_buffer.speech_started":
            let event = try decoder.decode(InputAudioBufferSpeechStartedEvent.self, from: data)
            return .inputAudioBufferSpeechStarted(event)

        case "input_audio_buffer.speech_stopped":
            let event = try decoder.decode(InputAudioBufferSpeechStoppedEvent.self, from: data)
            return .inputAudioBufferSpeechStopped(event)

        // Conversation events
        case "conversation.item.created":
            let event = try decoder.decode(ConversationItemCreatedEvent.self, from: data)
            return .conversationItemCreated(event)

        case "conversation.item.retrieved":
            let event = try decoder.decode(ConversationItemRetrievedEvent.self, from: data)
            return .conversationItemRetrieved(event)

        case "conversation.item.truncated":
            let event = try decoder.decode(ConversationItemTruncatedEvent.self, from: data)
            return .conversationItemTruncated(event)

        case "conversation.item.deleted":
            let event = try decoder.decode(ConversationItemDeletedEvent.self, from: data)
            return .conversationItemDeleted(event)

        case "conversation.item.input_audio_transcription.completed":
            let event = try decoder.decode(ConversationItemTranscriptionCompletedEvent.self, from: data)
            return .conversationItemTranscriptionCompleted(event)

        case "conversation.item.input_audio_transcription.delta":
            let event = try decoder.decode(ConversationItemTranscriptionDeltaEvent.self, from: data)
            return .conversationItemTranscriptionDelta(event)

        case "conversation.item.input_audio_transcription.failed":
            let event = try decoder.decode(ConversationItemTranscriptionFailedEvent.self, from: data)
            return .conversationItemTranscriptionFailed(event)

        // Response events
        case "response.created":
            let event = try decoder.decode(ResponseCreatedEvent.self, from: data)
            return .responseCreated(event)

        case "response.done":
            let event = try decoder.decode(ResponseDoneEvent.self, from: data)
            return .responseDone(event)

        case "response.output_item.added":
            let event = try decoder.decode(ResponseOutputItemAddedEvent.self, from: data)
            return .responseOutputItemAdded(event)

        case "response.output_item.done":
            let event = try decoder.decode(ResponseOutputItemDoneEvent.self, from: data)
            return .responseOutputItemDone(event)

        case "response.content_part.added":
            let event = try decoder.decode(ResponseContentPartAddedEvent.self, from: data)
            return .responseContentPartAdded(event)

        case "response.content_part.done":
            let event = try decoder.decode(ResponseContentPartDoneEvent.self, from: data)
            return .responseContentPartDone(event)

        // Text streaming events
        case "response.text.delta":
            let event = try decoder.decode(ResponseTextDeltaEvent.self, from: data)
            return .responseTextDelta(event)

        case "response.text.done":
            let event = try decoder.decode(ResponseTextDoneEvent.self, from: data)
            return .responseTextDone(event)

        // Audio streaming events
        case "response.audio.delta":
            let event = try decoder.decode(ResponseAudioDeltaEvent.self, from: data)
            return .responseAudioDelta(event)

        case "response.audio.done":
            let event = try decoder.decode(ResponseAudioDoneEvent.self, from: data)
            return .responseAudioDone(event)

        case "response.audio_transcript.delta":
            let event = try decoder.decode(ResponseAudioTranscriptDeltaEvent.self, from: data)
            return .responseAudioTranscriptDelta(event)

        case "response.audio_transcript.done":
            let event = try decoder.decode(ResponseAudioTranscriptDoneEvent.self, from: data)
            return .responseAudioTranscriptDone(event)

        // Audio timestamp events
        case "response.audio_timestamp.delta":
            let event = try decoder.decode(ResponseAudioTimestampDeltaEvent.self, from: data)
            return .responseAudioTimestampDelta(event)

        case "response.audio_timestamp.done":
            let event = try decoder.decode(ResponseAudioTimestampDoneEvent.self, from: data)
            return .responseAudioTimestampDone(event)

        // Animation events
        case "response.animation_blendshapes.delta":
            let event = try decoder.decode(ResponseAnimationBlendshapesDeltaEvent.self, from: data)
            return .responseAnimationBlendshapesDelta(event)

        case "response.animation_blendshapes.done":
            let event = try decoder.decode(ResponseAnimationBlendshapesDoneEvent.self, from: data)
            return .responseAnimationBlendshapesDone(event)

        case "response.animation_viseme.delta":
            let event = try decoder.decode(ResponseAnimationVisemeDeltaEvent.self, from: data)
            return .responseAnimationVisemeDelta(event)

        case "response.animation_viseme.done":
            let event = try decoder.decode(ResponseAnimationVisemeDoneEvent.self, from: data)
            return .responseAnimationVisemeDone(event)

        // Function/Tool calling events
        case "response.function_call_arguments.delta":
            let event = try decoder.decode(ResponseFunctionCallArgumentsDeltaEvent.self, from: data)
            return .responseFunctionCallArgumentsDelta(event)

        case "response.function_call_arguments.done":
            let event = try decoder.decode(ResponseFunctionCallArgumentsDoneEvent.self, from: data)
            return .responseFunctionCallArgumentsDone(event)

        case "response.mcp_call_arguments.delta":
            let event = try decoder.decode(ResponseMcpCallArgumentsDeltaEvent.self, from: data)
            return .responseMcpCallArgumentsDelta(event)

        case "response.mcp_call_arguments.done":
            let event = try decoder.decode(ResponseMcpCallArgumentsDoneEvent.self, from: data)
            return .responseMcpCallArgumentsDone(event)

        case "response.mcp_call.in_progress":
            let event = try decoder.decode(ResponseMcpCallInProgressEvent.self, from: data)
            return .responseMcpCallInProgress(event)

        case "response.mcp_call.completed":
            let event = try decoder.decode(ResponseMcpCallCompletedEvent.self, from: data)
            return .responseMcpCallCompleted(event)

        case "response.mcp_call.failed":
            let event = try decoder.decode(ResponseMcpCallFailedEvent.self, from: data)
            return .responseMcpCallFailed(event)

        // MCP tool management events
        case "mcp_list_tools.in_progress":
            let event = try decoder.decode(McpListToolsInProgressEvent.self, from: data)
            return .mcpListToolsInProgress(event)

        case "mcp_list_tools.completed":
            let event = try decoder.decode(McpListToolsCompletedEvent.self, from: data)
            return .mcpListToolsCompleted(event)

        case "mcp_list_tools.failed":
            let event = try decoder.decode(McpListToolsFailedEvent.self, from: data)
            return .mcpListToolsFailed(event)

        // System events
        case "error":
            let event = try decoder.decode(ErrorEvent.self, from: data)
            return .error(event)

        case "rate_limits.updated":
            let event = try decoder.decode(RateLimitsUpdatedEvent.self, from: data)
            return .rateLimitsUpdated(event)

        default:
            AppLogger.azure.warning("Unknown event type: \(type)")
            return .unknown(type)
        }
    }
}

// MARK: - Errors

public enum AzureError: LocalizedError {
    case notConnected
    case invalidConfiguration
    case sessionNotReady
    case encodingFailed(Error)
    case decodingFailed(Error)
    case connectionTimeout
    case connectionFailed
    case bufferTooSmall(durationMs: Double, bytes: Int, minimumMs: Double)

    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to Azure"
        case .invalidConfiguration:
            return "Invalid Azure configuration"
        case .sessionNotReady:
            return "Session not ready"
        case .encodingFailed(let error):
            return "Failed to encode event: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode event: \(error.localizedDescription)"
        case .connectionTimeout:
            return "Connection timeout"
        case .connectionFailed:
            return "Connection failed"
        case .bufferTooSmall(let durationMs, let bytes, let minimumMs):
            return "Audio buffer too small: \(String(format: "%.1f", durationMs))ms of audio (\(bytes) bytes). Minimum required: \(String(format: "%.0f", minimumMs))ms. Please speak for longer."
        }
    }
}

// MARK: - Protocol Conformance

extension VoiceLiveConnection: VoiceConnectionProtocol {
    /// Current session ID (derived from session state)
    public var sessionId: String? {
        get async {
            return await sessionState.sessionId
        }
    }
}

// MARK: - Task.select Extension

extension Task where Success == Never, Failure == Never {
    static func select<T>(_ task1: Task<T, Error>, _ task2: Task<T, Error>) -> Task<T, Error> {
        Task<T, Error> {
            try await withThrowingTaskGroup(of: T.self) { group in
                group.addTask { try await task1.value }
                group.addTask { try await task2.value }

                let result = try await group.next()!
                group.cancelAll()
                return result
            }
        }
    }
}
