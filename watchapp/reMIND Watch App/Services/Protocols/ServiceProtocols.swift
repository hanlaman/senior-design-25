//
//  ServiceProtocols.swift
//  reMIND Watch App
//
//  Service protocol definitions for dependency injection and testability
//

import Foundation
import Combine

// Note: This file references types from other service modules.
// The following types must be imported where this protocol is used:
// - ConnectionState (from AzureCommonTypes)
// - AzureSessionState (from AzureSessionState)
// - AzureServerEvent (from AzureServerEvents)
// - SessionResource, InputAudioBuffer, etc. (from Azure resources)

// MARK: - Voice Connection Protocol

/// Protocol for Azure Voice Live connection service
/// Enables dependency injection and testing with mocks
protocol VoiceConnectionProtocol: Actor {
    /// Current connection state
    var connectionState: ConnectionState { get async }

    /// Current Azure session state
    var sessionState: AzureSessionState { get async }

    /// Stream of Azure server events
    var eventStream: AsyncStream<AzureServerEvent> { get }

    /// Current session ID (derived from session state)
    var sessionId: String? { get async }

    /// Session resource for configuration management
    var session: SessionResource { get }

    /// Input audio buffer resource
    var inputAudioBuffer: InputAudioBuffer { get }

    /// Output audio buffer resource
    var outputAudioBuffer: OutputAudioBuffer { get }

    /// Conversation management resource
    var conversation: Conversation { get }

    /// Response management resource
    var response: Response { get }

    /// Connect to Azure Voice Live service
    /// - Throws: AzureError if connection fails
    func connect() async throws

    /// Disconnect from Azure Voice Live service
    func disconnect() async

    /// Send MCP tool approval response
    /// - Parameters:
    ///   - approve: Whether to approve the tool request
    ///   - approvalRequestId: ID of the approval request
    /// - Throws: AzureError if not connected or encoding fails
    func sendMcpApproval(approve: Bool, approvalRequestId: String) async throws
}

// MARK: - Settings Manager Protocol

/// Protocol for voice settings manager
/// Manages persistence and synchronization of voice settings
protocol SettingsManagerProtocol: AnyObject {
    /// Current voice settings (observable)
    var settings: VoiceSettings { get }

    /// Current synchronization state with active session
    var syncState: VoiceSettingsSyncState { get }

    /// Publisher for settings changes (Combine)
    var objectWillChange: ObservableObjectPublisher { get }

    /// Update speaking rate setting
    /// - Parameter rate: New speaking rate (0.25 to 4.0)
    func updateSpeakingRate(_ rate: Double)

    /// Mark settings as synchronized with active session
    /// - Parameter settings: Settings that are now active on the server
    func markAsSynchronized(_ settings: VoiceSettings)

    /// Clear active session settings (call on disconnect)
    func clearActiveSession()

    /// Compute current sync state
    /// - Returns: Current synchronization state
    func computeSyncState() -> VoiceSettingsSyncState

    /// Get list of changed fields compared to active session
    /// - Returns: Array of metadata for changed fields, or empty if no active session
    func changedFields() -> [SettingMetadata]
}

// MARK: - History Manager Protocol

/// Protocol for conversation history manager
/// Manages persistence of conversation sessions and messages
protocol HistoryManagerProtocol: AnyObject {
    /// Start a new conversation session
    /// - Parameter sessionId: Unique session identifier from Azure
    func startSession(_ sessionId: String)

    /// End an existing conversation session
    /// - Parameter sessionId: Session identifier to end
    func endSession(_ sessionId: String)

    /// Add a message to the conversation history
    /// - Parameters:
    ///   - itemId: Unique message/item identifier
    ///   - role: Message role (user or assistant)
    ///   - content: Message content text
    ///   - sessionId: Session this message belongs to
    func addMessage(
        itemId: String,
        role: ConversationMessage.MessageRole,
        content: String,
        sessionId: String
    )

    /// Delete a specific conversation session
    /// - Parameter sessionId: Session identifier to delete
    func deleteSession(_ sessionId: String)
}
