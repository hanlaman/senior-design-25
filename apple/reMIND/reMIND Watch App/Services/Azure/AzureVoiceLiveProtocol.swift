//
//  AzureVoiceLiveProtocol.swift
//  reMIND Watch App
//
//  Protocol definition for Azure Voice Live service
//

import Foundation

/// Protocol for Azure Voice Live service
protocol AzureVoiceLiveProtocol: Actor {
    /// Connection state
    var connectionState: ConnectionState { get }

    /// Stream of events from Azure
    var eventStream: AsyncStream<AzureServerEvent> { get }

    // MARK: - Connection Management

    /// Connect to Azure Voice Live API
    func connect() async throws

    /// Disconnect from Azure Voice Live API
    func disconnect() async

    // MARK: - Session Management

    /// Update session configuration
    func updateSession(_ config: RealtimeRequestSession) async throws

    // MARK: - Audio Streaming

    /// Send audio chunk to Azure (appends to buffer)
    func sendAudioChunk(_ audioData: Data) async throws

    /// Commit audio buffer for processing
    func commitAudioBuffer() async throws

    /// Clear audio buffer
    func clearAudioBuffer() async throws

    // MARK: - Conversation Management

    /// Create a conversation item
    func createConversationItem(previousItemId: String?, item: RealtimeConversationRequestItem) async throws

    /// Retrieve a conversation item by ID
    func retrieveConversationItem(itemId: String) async throws

    /// Truncate assistant audio response
    func truncateConversationItem(itemId: String, contentIndex: Int, audioEndMs: Int) async throws

    /// Delete a conversation item
    func deleteConversationItem(itemId: String) async throws

    // MARK: - Response Management

    /// Manually trigger response generation
    func createResponse(config: RealtimeResponseOptions?) async throws

    /// Cancel current response
    func cancelResponse() async throws

    // MARK: - MCP Tool Management

    /// Approve or reject an MCP tool call
    func sendMcpApproval(approve: Bool, approvalRequestId: String) async throws
}

/// Azure server events - Complete set of all 44+ events
enum AzureServerEvent {
    // Session events (3)
    case sessionCreated(SessionCreatedEvent)
    case sessionUpdated(SessionUpdatedEvent)
    case sessionAvatarConnecting(SessionAvatarConnectingEvent)

    // Input audio buffer events (4)
    case inputAudioBufferCommitted(InputAudioBufferCommittedEvent)
    case inputAudioBufferCleared(InputAudioBufferClearedEvent)
    case inputAudioBufferSpeechStarted(InputAudioBufferSpeechStartedEvent)
    case inputAudioBufferSpeechStopped(InputAudioBufferSpeechStoppedEvent)

    // Conversation events (7)
    case conversationItemCreated(ConversationItemCreatedEvent)
    case conversationItemRetrieved(ConversationItemRetrievedEvent)
    case conversationItemTruncated(ConversationItemTruncatedEvent)
    case conversationItemDeleted(ConversationItemDeletedEvent)
    case conversationItemTranscriptionCompleted(ConversationItemTranscriptionCompletedEvent)
    case conversationItemTranscriptionDelta(ConversationItemTranscriptionDeltaEvent)
    case conversationItemTranscriptionFailed(ConversationItemTranscriptionFailedEvent)

    // Response events (6)
    case responseCreated(ResponseCreatedEvent)
    case responseDone(ResponseDoneEvent)
    case responseOutputItemAdded(ResponseOutputItemAddedEvent)
    case responseOutputItemDone(ResponseOutputItemDoneEvent)
    case responseContentPartAdded(ResponseContentPartAddedEvent)
    case responseContentPartDone(ResponseContentPartDoneEvent)

    // Text streaming (2)
    case responseTextDelta(ResponseTextDeltaEvent)
    case responseTextDone(ResponseTextDoneEvent)

    // Audio streaming (4)
    case responseAudioDelta(ResponseAudioDeltaEvent)
    case responseAudioDone(ResponseAudioDoneEvent)
    case responseAudioTranscriptDelta(ResponseAudioTranscriptDeltaEvent)
    case responseAudioTranscriptDone(ResponseAudioTranscriptDoneEvent)

    // Audio timestamp (2)
    case responseAudioTimestampDelta(ResponseAudioTimestampDeltaEvent)
    case responseAudioTimestampDone(ResponseAudioTimestampDoneEvent)

    // Animation (4)
    case responseAnimationBlendshapesDelta(ResponseAnimationBlendshapesDeltaEvent)
    case responseAnimationBlendshapesDone(ResponseAnimationBlendshapesDoneEvent)
    case responseAnimationVisemeDelta(ResponseAnimationVisemeDeltaEvent)
    case responseAnimationVisemeDone(ResponseAnimationVisemeDoneEvent)

    // Function/Tool calling (7)
    case responseFunctionCallArgumentsDelta(ResponseFunctionCallArgumentsDeltaEvent)
    case responseFunctionCallArgumentsDone(ResponseFunctionCallArgumentsDoneEvent)
    case responseMcpCallArgumentsDelta(ResponseMcpCallArgumentsDeltaEvent)
    case responseMcpCallArgumentsDone(ResponseMcpCallArgumentsDoneEvent)
    case responseMcpCallInProgress(ResponseMcpCallInProgressEvent)
    case responseMcpCallCompleted(ResponseMcpCallCompletedEvent)
    case responseMcpCallFailed(ResponseMcpCallFailedEvent)

    // MCP tool management (3)
    case mcpListToolsInProgress(McpListToolsInProgressEvent)
    case mcpListToolsCompleted(McpListToolsCompletedEvent)
    case mcpListToolsFailed(McpListToolsFailedEvent)

    // System events (2)
    case error(ErrorEvent)
    case rateLimitsUpdated(RateLimitsUpdatedEvent)

    case unknown(String)

    var eventType: String {
        switch self {
        // Session events
        case .sessionCreated: return "session.created"
        case .sessionUpdated: return "session.updated"
        case .sessionAvatarConnecting: return "session.avatar.connecting"

        // Input audio buffer events
        case .inputAudioBufferCommitted: return "input_audio_buffer.committed"
        case .inputAudioBufferCleared: return "input_audio_buffer.cleared"
        case .inputAudioBufferSpeechStarted: return "input_audio_buffer.speech_started"
        case .inputAudioBufferSpeechStopped: return "input_audio_buffer.speech_stopped"

        // Conversation events
        case .conversationItemCreated: return "conversation.item.created"
        case .conversationItemRetrieved: return "conversation.item.retrieved"
        case .conversationItemTruncated: return "conversation.item.truncated"
        case .conversationItemDeleted: return "conversation.item.deleted"
        case .conversationItemTranscriptionCompleted: return "conversation.item.input_audio_transcription.completed"
        case .conversationItemTranscriptionDelta: return "conversation.item.input_audio_transcription.delta"
        case .conversationItemTranscriptionFailed: return "conversation.item.input_audio_transcription.failed"

        // Response events
        case .responseCreated: return "response.created"
        case .responseDone: return "response.done"
        case .responseOutputItemAdded: return "response.output_item.added"
        case .responseOutputItemDone: return "response.output_item.done"
        case .responseContentPartAdded: return "response.content_part.added"
        case .responseContentPartDone: return "response.content_part.done"

        // Text streaming
        case .responseTextDelta: return "response.text.delta"
        case .responseTextDone: return "response.text.done"

        // Audio streaming
        case .responseAudioDelta: return "response.audio.delta"
        case .responseAudioDone: return "response.audio.done"
        case .responseAudioTranscriptDelta: return "response.audio_transcript.delta"
        case .responseAudioTranscriptDone: return "response.audio_transcript.done"

        // Audio timestamp
        case .responseAudioTimestampDelta: return "response.audio_timestamp.delta"
        case .responseAudioTimestampDone: return "response.audio_timestamp.done"

        // Animation
        case .responseAnimationBlendshapesDelta: return "response.animation_blendshapes.delta"
        case .responseAnimationBlendshapesDone: return "response.animation_blendshapes.done"
        case .responseAnimationVisemeDelta: return "response.animation_viseme.delta"
        case .responseAnimationVisemeDone: return "response.animation_viseme.done"

        // Function/Tool calling
        case .responseFunctionCallArgumentsDelta: return "response.function_call_arguments.delta"
        case .responseFunctionCallArgumentsDone: return "response.function_call_arguments.done"
        case .responseMcpCallArgumentsDelta: return "response.mcp_call_arguments.delta"
        case .responseMcpCallArgumentsDone: return "response.mcp_call_arguments.done"
        case .responseMcpCallInProgress: return "response.mcp_call.in_progress"
        case .responseMcpCallCompleted: return "response.mcp_call.completed"
        case .responseMcpCallFailed: return "response.mcp_call.failed"

        // MCP tool management
        case .mcpListToolsInProgress: return "mcp_list_tools.in_progress"
        case .mcpListToolsCompleted: return "mcp_list_tools.completed"
        case .mcpListToolsFailed: return "mcp_list_tools.failed"

        // System events
        case .error: return "error"
        case .rateLimitsUpdated: return "rate_limits.updated"

        case .unknown(let type): return type
        }
    }
}
