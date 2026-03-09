//
//  MockVoiceLiveConnection.swift
//  reMIND Watch AppTests
//
//  Mock implementation of VoiceLiveConnection for testing
//

import Foundation
@testable import reMIND_Watch_App

/// Mock voice live connection for testing
/// Note: This creates testable mock resources instead of using the real implementations
actor MockVoiceLiveConnection: VoiceConnectionProtocol {
    // MARK: - Test Control Properties

    /// Whether connect was called
    private(set) var connectCalled = false

    /// Whether disconnect was called
    private(set) var disconnectCalled = false

    /// Whether sendMcpApproval was called
    private(set) var sendMcpApprovalCalled = false

    /// MCP approval details
    private(set) var mcpApprovalDetails: [(approve: Bool, requestId: String)] = []

    /// Error to throw when connect is called
    var connectError: Error?

    /// Whether connection should succeed
    var shouldFailConnect = false

    // MARK: - Protocol Properties

    private var _connectionState: ConnectionState = .disconnected
    var connectionState: ConnectionState {
        get async { _connectionState }
    }

    private var _sessionState: AzureSessionState = .uninitialized
    var sessionState: AzureSessionState {
        get async { _sessionState }
    }

    private var eventContinuation: AsyncStream<AzureServerEvent>.Continuation?
    private(set) var eventStream: AsyncStream<AzureServerEvent>

    var sessionId: String? {
        get async {
            switch _sessionState {
            case .ready(let id):
                return id
            case .establishing(let id):
                return id
            default:
                return nil
            }
        }
    }

    // MARK: - Mock Resources

    let session: SessionResource
    let inputAudioBuffer: InputAudioBuffer
    let outputAudioBuffer: OutputAudioBuffer
    let conversation: Conversation
    let response: Response

    /// Mock session resource for testing
    private let mockSession: MockSessionResource
    private let mockInputAudioBuffer: MockInputAudioBuffer
    private let mockResponse: MockResponse

    // MARK: - Initialization

    init() {
        // Create event stream
        let (stream, continuation) = AsyncStream<AzureServerEvent>.makeStream()
        self.eventStream = stream
        self.eventContinuation = continuation

        // Create mock resources
        // Note: We need to work around the fact that real resources require VoiceLiveConnection
        // For now, we'll create placeholder resources and use the mock versions internally
        self.mockSession = MockSessionResource()
        self.mockInputAudioBuffer = MockInputAudioBuffer()
        self.mockResponse = MockResponse()

        // These will be nil in the mock - tests should use the mock resource accessors
        // In production code, VoiceConnectionCoordinator creates its own VoiceLiveConnection
        // which has real resources. For testing, we test the coordinator behavior.
        fatalError("MockVoiceLiveConnection cannot create real resources. Use factory injection instead.")
    }

    /// Initialize with injected mock resources (for factory pattern)
    init(skipResourceInit: Bool) {
        // Create event stream
        let (stream, continuation) = AsyncStream<AzureServerEvent>.makeStream()
        self.eventStream = stream
        self.eventContinuation = continuation

        // Create mock resources
        self.mockSession = MockSessionResource()
        self.mockInputAudioBuffer = MockInputAudioBuffer()
        self.mockResponse = MockResponse()

        // These are placeholder - real resources cannot be created without a real connection
        // The coordinator tests will use mocked factory functions
        self.session = unsafeBitCast(mockSession, to: SessionResource.self)
        self.inputAudioBuffer = unsafeBitCast(mockInputAudioBuffer, to: InputAudioBuffer.self)
        self.outputAudioBuffer = unsafeBitCast(mockInputAudioBuffer, to: OutputAudioBuffer.self)
        self.conversation = unsafeBitCast(mockSession, to: Conversation.self)
        self.response = unsafeBitCast(mockResponse, to: Response.self)
    }

    // MARK: - Protocol Methods

    func connect() async throws {
        connectCalled = true

        if let error = connectError {
            throw error
        }

        if shouldFailConnect {
            throw AzureError.connectionFailed
        }

        _connectionState = .connected
        _sessionState = .ready(sessionId: "mock-session-\(UUID().uuidString)")
    }

    func disconnect() async {
        disconnectCalled = true
        _connectionState = .disconnected
        _sessionState = .uninitialized
    }

    func sendMcpApproval(approve: Bool, approvalRequestId: String) async throws {
        sendMcpApprovalCalled = true
        mcpApprovalDetails.append((approve: approve, requestId: approvalRequestId))
    }

    // MARK: - Test Control Methods

    /// Emit an event for testing
    func emitEvent(_ event: AzureServerEvent) {
        eventContinuation?.yield(event)
    }

    /// Set connection state for testing
    func setConnectionState(_ state: ConnectionState) {
        _connectionState = state
    }

    /// Set session state for testing
    func setSessionState(_ state: AzureSessionState) {
        _sessionState = state
    }

    /// Complete the event stream
    func finishEventStream() {
        eventContinuation?.finish()
    }

    /// Reset all test state
    func reset() {
        connectCalled = false
        disconnectCalled = false
        sendMcpApprovalCalled = false
        mcpApprovalDetails.removeAll()
        connectError = nil
        shouldFailConnect = false
        _connectionState = .disconnected
        _sessionState = .uninitialized
    }
}

// MARK: - Mock Resource Classes

/// Mock session resource for testing
class MockSessionResource {
    var updateCalled = false
    var lastConfig: RealtimeRequestSession?
    var updateError: Error?

    func update(_ config: RealtimeRequestSession) async throws {
        updateCalled = true
        lastConfig = config

        if let error = updateError {
            throw error
        }
    }
}

/// Mock input audio buffer for testing
class MockInputAudioBuffer {
    var appendCalled = false
    var appendedData: [Data] = []
    var commitCalled = false
    var clearCalled = false
    var appendError: Error?
    var commitError: Error?

    private var _statistics = AudioBufferStatistics(bytes: 0, chunks: 0, durationMs: 0)
    var statistics: AudioBufferStatistics { _statistics }

    func append(_ data: Data) async throws {
        appendCalled = true
        appendedData.append(data)

        if let error = appendError {
            throw error
        }

        // Update statistics
        let newBytes = _statistics.bytes + data.count
        let newChunks = _statistics.chunks + 1
        let newDurationMs = Double(newBytes) / 2.0 / 24000.0 * 1000.0
        _statistics = AudioBufferStatistics(bytes: newBytes, chunks: newChunks, durationMs: newDurationMs)
    }

    func commit() async throws {
        commitCalled = true

        if let error = commitError {
            throw error
        }

        // Check minimum duration
        if _statistics.durationMs < 100.0 {
            throw AzureError.bufferTooSmall(durationMs: _statistics.durationMs, bytes: _statistics.bytes, minimumMs: 100.0)
        }
    }

    func clear() async throws {
        clearCalled = true
        _statistics = AudioBufferStatistics(bytes: 0, chunks: 0, durationMs: 0)
        appendedData.removeAll()
    }

    func reset() {
        appendCalled = false
        appendedData.removeAll()
        commitCalled = false
        clearCalled = false
        appendError = nil
        commitError = nil
        _statistics = AudioBufferStatistics(bytes: 0, chunks: 0, durationMs: 0)
    }
}

/// Mock response resource for testing
class MockResponse {
    var createCalled = false
    var cancelCalled = false
    var createError: Error?
    var cancelError: Error?

    func create(options: RealtimeResponseOptions? = nil) async throws {
        createCalled = true

        if let error = createError {
            throw error
        }
    }

    func cancel() async throws {
        cancelCalled = true

        if let error = cancelError {
            throw error
        }
    }

    func reset() {
        createCalled = false
        cancelCalled = false
        createError = nil
        cancelError = nil
    }
}
