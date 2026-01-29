//
//  AzureVoiceLiveService.swift
//  reMIND Watch App
//
//  Azure Voice Live API service implementation
//

import Foundation
import os

/// Azure Voice Live service implementation
public actor AzureVoiceLiveService: AzureVoiceLiveProtocol {
    // MARK: - Properties

    private let apiKey: String
    private let websocketURL: URL

    private var webSocketManager: WebSocketManager?

    public private(set) var connectionState: ConnectionState = .disconnected

    // Event stream
    private var eventContinuation: AsyncStream<AzureServerEvent>.Continuation?
    public let eventStream: AsyncStream<AzureServerEvent>

    // Session state
    private var sessionId: String?
    private var isSessionReady = false

    // Audio buffer tracking
    private var audioBufferBytes: Int = 0
    private var audioBufferChunks: Int = 0

    // MARK: - Initialization

    public init(apiKey: String, websocketURL: URL) {
        self.apiKey = apiKey
        self.websocketURL = websocketURL

        // Create event stream
        var continuationHolder: AsyncStream<AzureServerEvent>.Continuation?
        self.eventStream = AsyncStream { continuation in
            continuationHolder = continuation
        }
        self.eventContinuation = continuationHolder
    }

    // MARK: - Connection Management

    public func connect() async throws {
        guard connectionState != .connected else {
            AppLogger.azure.warning("Already connected")
            return
        }

        connectionState = .connecting
        AppLogger.azure.info("Connecting to Azure Voice Live API")

        // Create WebSocket manager
        let manager = WebSocketManager(url: websocketURL, apiKey: apiKey)
        webSocketManager = manager

        // Connect
        try await manager.connect()

        connectionState = .connected
        AppLogger.azure.info("Connected to Azure Voice Live API")

        // Start processing events
        AppLogger.azure.info("Creating Task to process WebSocket events")
        Task {
            AppLogger.azure.info("Task started, calling processWebSocketEvents()")
            await processWebSocketEvents()
            AppLogger.azure.info("processWebSocketEvents() completed")
        }

        // Give WebSocket a moment to be fully ready
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        AppLogger.azure.info("WebSocket ready, will send session.update")
    }

    public func disconnect() async {
        AppLogger.azure.info("Disconnecting from Azure Voice Live API")

        await webSocketManager?.disconnect()
        webSocketManager = nil

        connectionState = .disconnected
        sessionId = nil
        isSessionReady = false

        eventContinuation?.finish()

        AppLogger.azure.info("Disconnected from Azure Voice Live API")
    }

    // MARK: - Session Management

    public func updateSession(_ config: RealtimeRequestSession) async throws {
        guard connectionState == .connected else {
            throw AzureError.notConnected
        }

        AppLogger.azure.info("Sending session.update event with configuration")

        let event = SessionUpdateEvent(session: config)
        try await sendEvent(event)

        AppLogger.azure.info("session.update sent, waiting for response")
    }

    // MARK: - Audio Management

    public func sendAudioChunk(_ audioData: Data) async throws {
        guard connectionState == .connected else {
            throw AzureError.notConnected
        }

        guard isSessionReady else {
            throw AzureError.sessionNotReady
        }

        // Track buffer statistics
        audioBufferBytes += audioData.count
        audioBufferChunks += 1

        // Base64 encode audio data
        let base64Audio = audioData.base64EncodedString()

        let event = InputAudioBufferAppendEvent(audio: base64Audio)
        try await sendEvent(event)
    }

    public func commitAudioBuffer() async throws {
        guard connectionState == .connected else {
            throw AzureError.notConnected
        }

        guard isSessionReady else {
            throw AzureError.sessionNotReady
        }

        // Get buffer statistics
        let stats = getAudioBufferStatistics()

        // Validate minimum buffer size (100ms required by Azure)
        let minimumMs: Double = 100.0
        if stats.durationMs < minimumMs {
            AppLogger.azure.error("Audio buffer too small: \(stats.durationMs)ms (minimum: \(minimumMs)ms), \(stats.bytes) bytes, \(stats.chunks) chunks")
            throw AzureError.bufferTooSmall(durationMs: stats.durationMs, bytes: stats.bytes, minimumMs: minimumMs)
        }

        AppLogger.azure.info("Committing audio buffer: \(stats.durationMs)ms, \(stats.bytes) bytes, \(stats.chunks) chunks")

        let event = InputAudioBufferCommitEvent()
        try await sendEvent(event)
    }

    public func clearAudioBuffer() async throws {
        guard connectionState == .connected else {
            throw AzureError.notConnected
        }

        AppLogger.azure.info("Clearing audio buffer")

        // Reset tracking
        audioBufferBytes = 0
        audioBufferChunks = 0

        let event = InputAudioBufferClearEvent()
        try await sendEvent(event)
    }

    public func cancelResponse() async throws {
        guard connectionState == .connected else {
            throw AzureError.notConnected
        }

        AppLogger.azure.info("Canceling response")

        let event = ResponseCancelEvent()
        try await sendEvent(event)
    }

    // MARK: - Conversation Management

    public func createConversationItem(previousItemId: String?, item: RealtimeConversationRequestItem) async throws {
        guard connectionState == .connected else {
            throw AzureError.notConnected
        }

        guard isSessionReady else {
            throw AzureError.sessionNotReady
        }

        AppLogger.azure.info("Creating conversation item")

        let event = ConversationItemCreateEvent(previousItemId: previousItemId, item: item)
        try await sendEvent(event)
    }

    public func retrieveConversationItem(itemId: String) async throws {
        guard connectionState == .connected else {
            throw AzureError.notConnected
        }

        guard isSessionReady else {
            throw AzureError.sessionNotReady
        }

        AppLogger.azure.info("Retrieving conversation item: \(itemId)")

        let event = ConversationItemRetrieveEvent(itemId: itemId)
        try await sendEvent(event)
    }

    public func truncateConversationItem(itemId: String, contentIndex: Int, audioEndMs: Int) async throws {
        guard connectionState == .connected else {
            throw AzureError.notConnected
        }

        guard isSessionReady else {
            throw AzureError.sessionNotReady
        }

        AppLogger.azure.info("Truncating conversation item: \(itemId) at content index \(contentIndex), audio end: \(audioEndMs)ms")

        let event = ConversationItemTruncateEvent(itemId: itemId, contentIndex: contentIndex, audioEndMs: audioEndMs)
        try await sendEvent(event)
    }

    public func deleteConversationItem(itemId: String) async throws {
        guard connectionState == .connected else {
            throw AzureError.notConnected
        }

        guard isSessionReady else {
            throw AzureError.sessionNotReady
        }

        AppLogger.azure.info("Deleting conversation item: \(itemId)")

        let event = ConversationItemDeleteEvent(itemId: itemId)
        try await sendEvent(event)
    }

    // MARK: - Response Management

    public func createResponse(config: RealtimeResponseOptions?) async throws {
        guard connectionState == .connected else {
            throw AzureError.notConnected
        }

        guard isSessionReady else {
            throw AzureError.sessionNotReady
        }

        AppLogger.azure.info("Creating response")

        let event = ResponseCreateEvent(response: config)
        try await sendEvent(event)
    }

    // MARK: - MCP Tool Management

    public func sendMcpApproval(approve: Bool, approvalRequestId: String) async throws {
        guard connectionState == .connected else {
            throw AzureError.notConnected
        }

        guard isSessionReady else {
            throw AzureError.sessionNotReady
        }

        AppLogger.azure.info("Sending MCP approval: \(approve) for request \(approvalRequestId)")

        let event = McpApprovalResponseEvent(
            approve: approve,
            approvalRequestId: approvalRequestId
        )
        try await sendEvent(event)
    }

    // MARK: - Buffer Statistics

    /// Get current audio buffer statistics
    func getAudioBufferStatistics() -> AudioBufferStatistics {
        let durationMs = calculateAudioDurationMs(bytes: audioBufferBytes)
        return AudioBufferStatistics(
            bytes: audioBufferBytes,
            chunks: audioBufferChunks,
            durationMs: durationMs
        )
    }

    /// Calculate audio duration in milliseconds from bytes
    /// Assumes PCM16 (16-bit), 24kHz sample rate, mono channel
    private func calculateAudioDurationMs(bytes: Int) -> Double {
        // PCM16 = 2 bytes per sample
        // 24kHz = 24000 samples per second
        // Duration (seconds) = samples / sample_rate
        // Duration (ms) = (samples / sample_rate) * 1000

        let bytesPerSample = 2
        let sampleRate = 24000.0

        let samples = Double(bytes) / Double(bytesPerSample)
        let durationSeconds = samples / sampleRate
        let durationMs = durationSeconds * 1000.0

        return durationMs
    }

    // MARK: - Private Methods

    private func sendEvent<T: Encodable>(_ event: T) async throws {
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

            // Handle session events specially
            if case .sessionCreated(let sessionCreated) = event {
                sessionId = sessionCreated.session.id
                isSessionReady = true
                audioBufferBytes = 0
                audioBufferChunks = 0
                AppLogger.azure.info("Session created: \(sessionCreated.session.id) - Session ready!")
            }

            if case .sessionUpdated = event {
                isSessionReady = true
                audioBufferBytes = 0
                audioBufferChunks = 0
                AppLogger.azure.info("Session updated - Session ready!")
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

    public func waitForSessionCreated() async throws {
        AppLogger.azure.info("Waiting for session to be ready...")

        // Poll the isSessionReady flag with timeout
        let startTime = Date()
        let timeout: TimeInterval = 10.0 // 10 seconds

        while !isSessionReady {
            // Check if timed out
            if Date().timeIntervalSince(startTime) > timeout {
                AppLogger.azure.error("Timeout waiting for session ready")
                throw AzureError.connectionTimeout
            }

            // Sleep briefly before checking again
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        AppLogger.azure.info("Session ready, continuing...")
    }
}

// MARK: - Supporting Types

/// Audio buffer statistics
struct AudioBufferStatistics {
    let bytes: Int
    let chunks: Int
    let durationMs: Double
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
