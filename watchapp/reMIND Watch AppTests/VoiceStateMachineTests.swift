//
//  VoiceStateMachineTests.swift
//  reMIND Watch AppTests
//
//  Unit tests for VoiceStateMachine and VoiceInteractionState
//

import XCTest
@testable import reMIND_Watch_App

@MainActor
final class VoiceStateMachineTests: XCTestCase {

    var stateMachine: VoiceStateMachine!
    let testSessionId = "test-session-123"

    override func setUp() {
        super.setUp()
        stateMachine = VoiceStateMachine()
    }

    override func tearDown() {
        stateMachine = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertEqual(stateMachine.state, .disconnected)
        XCTAssertFalse(stateMachine.isConnected)
        XCTAssertFalse(stateMachine.canStartRecording)
        XCTAssertNil(stateMachine.sessionId)
    }

    // MARK: - Valid Transition Tests

    func testConnectionFlow() {
        // disconnected → connecting
        stateMachine.transitionTo(.connecting)
        XCTAssertEqual(stateMachine.state, .connecting)

        // connecting → idle
        stateMachine.transitionTo(.idle(sessionId: testSessionId))
        XCTAssertEqual(stateMachine.sessionId, testSessionId)
        XCTAssertTrue(stateMachine.isConnected)
        XCTAssertTrue(stateMachine.canStartRecording)
    }

    func testRecordingFlow() {
        // Set up: get to idle state
        stateMachine.transitionTo(.connecting)
        stateMachine.transitionTo(.idle(sessionId: testSessionId))

        // idle → recording
        stateMachine.transitionTo(.recording(sessionId: testSessionId, bufferBytes: 1024))
        XCTAssertTrue(stateMachine.isRecording)
        XCTAssertTrue(stateMachine.isActive)
        XCTAssertTrue(stateMachine.canCancel)

        // recording → recording (buffer size update)
        stateMachine.transitionTo(.recording(sessionId: testSessionId, bufferBytes: 2048))
        XCTAssertTrue(stateMachine.isRecording)

        // recording → processing
        stateMachine.transitionTo(.processing(sessionId: testSessionId))
        XCTAssertTrue(stateMachine.isProcessing)
        XCTAssertFalse(stateMachine.isRecording)

        // processing → playing
        stateMachine.transitionTo(.playing(sessionId: testSessionId, activeBuffers: 3))
        XCTAssertTrue(stateMachine.isPlaying)
        XCTAssertTrue(stateMachine.isActive)

        // playing → playing (buffer count update)
        stateMachine.transitionTo(.playing(sessionId: testSessionId, activeBuffers: 2))
        XCTAssertTrue(stateMachine.isPlaying)

        // playing → idle
        stateMachine.transitionTo(.idle(sessionId: testSessionId))
        XCTAssertFalse(stateMachine.isPlaying)
        XCTAssertFalse(stateMachine.isActive)
        XCTAssertTrue(stateMachine.canStartRecording)
    }

    func testCancellationFlow() {
        // Set up: get to recording state
        stateMachine.transitionTo(.connecting)
        stateMachine.transitionTo(.idle(sessionId: testSessionId))
        stateMachine.transitionTo(.recording(sessionId: testSessionId, bufferBytes: 1024))

        // recording → idle (cancellation)
        stateMachine.transitionTo(.idle(sessionId: testSessionId))
        XCTAssertTrue(stateMachine.canStartRecording)
        XCTAssertFalse(stateMachine.isActive)
    }

    func testErrorRecovery() {
        // Set up: get to idle state
        stateMachine.transitionTo(.connecting)
        stateMachine.transitionTo(.idle(sessionId: testSessionId))

        // idle → error
        stateMachine.transitionTo(.error(sessionId: testSessionId, message: "Test error"))
        XCTAssertEqual(stateMachine.errorMessage, "Test error")

        // error → idle (recovery)
        stateMachine.transitionTo(.idle(sessionId: testSessionId))
        XCTAssertNil(stateMachine.errorMessage)
        XCTAssertTrue(stateMachine.canStartRecording)

        // error → disconnected (fatal error)
        stateMachine.transitionTo(.error(sessionId: testSessionId, message: "Fatal error"))
        stateMachine.transitionTo(.disconnected)
        XCTAssertFalse(stateMachine.isConnected)
        XCTAssertNil(stateMachine.sessionId)
    }

    func testConnectionFailureRetry() {
        // disconnected → connecting
        stateMachine.transitionTo(.connecting)

        // connecting → connectionFailed
        stateMachine.transitionTo(.connectionFailed("Network error"))
        XCTAssertEqual(stateMachine.errorMessage, "Network error")
        XCTAssertFalse(stateMachine.isConnected)

        // connectionFailed → connecting (retry)
        stateMachine.transitionTo(.connecting)
        XCTAssertEqual(stateMachine.state, .connecting)

        // connecting → idle (success)
        stateMachine.transitionTo(.idle(sessionId: testSessionId))
        XCTAssertTrue(stateMachine.isConnected)
    }

    func testDisconnectionFromIdle() {
        // Set up: get to idle state
        stateMachine.transitionTo(.connecting)
        stateMachine.transitionTo(.idle(sessionId: testSessionId))

        // idle → disconnected
        stateMachine.transitionTo(.disconnected)
        XCTAssertEqual(stateMachine.state, .disconnected)
        XCTAssertFalse(stateMachine.isConnected)
        XCTAssertNil(stateMachine.sessionId)
    }

    // MARK: - Invalid Transition Tests

    func testInvalidTransition_DisconnectedToRecording() {
        // Cannot go directly from disconnected to recording
        stateMachine.transitionTo(.recording(sessionId: testSessionId, bufferBytes: 0))
        XCTAssertEqual(stateMachine.state, .disconnected) // Should remain disconnected
    }

    func testInvalidTransition_DisconnectedToPlaying() {
        // Cannot go directly from disconnected to playing
        stateMachine.transitionTo(.playing(sessionId: testSessionId, activeBuffers: 1))
        XCTAssertEqual(stateMachine.state, .disconnected) // Should remain disconnected
    }

    func testInvalidTransition_PlayingToRecording() {
        // Set up: get to playing state
        stateMachine.transitionTo(.connecting)
        stateMachine.transitionTo(.idle(sessionId: testSessionId))
        stateMachine.transitionTo(.recording(sessionId: testSessionId, bufferBytes: 1024))
        stateMachine.transitionTo(.processing(sessionId: testSessionId))
        stateMachine.transitionTo(.playing(sessionId: testSessionId, activeBuffers: 1))

        // Cannot go from playing to recording
        stateMachine.transitionTo(.recording(sessionId: testSessionId, bufferBytes: 0))
        XCTAssertTrue(stateMachine.isPlaying) // Should remain playing
        XCTAssertFalse(stateMachine.isRecording)
    }

    func testInvalidTransition_RecordingToPlaying() {
        // Set up: get to recording state
        stateMachine.transitionTo(.connecting)
        stateMachine.transitionTo(.idle(sessionId: testSessionId))
        stateMachine.transitionTo(.recording(sessionId: testSessionId, bufferBytes: 1024))

        // Cannot go directly from recording to playing (must go through processing)
        stateMachine.transitionTo(.playing(sessionId: testSessionId, activeBuffers: 1))
        XCTAssertTrue(stateMachine.isRecording) // Should remain recording
        XCTAssertFalse(stateMachine.isPlaying)
    }

    // MARK: - State Property Tests

    func testStateProperties_Disconnected() {
        XCTAssertEqual(stateMachine.state, .disconnected)
        XCTAssertFalse(stateMachine.isConnected)
        XCTAssertFalse(stateMachine.canStartRecording)
        XCTAssertFalse(stateMachine.isRecording)
        XCTAssertFalse(stateMachine.isProcessing)
        XCTAssertFalse(stateMachine.isPlaying)
        XCTAssertFalse(stateMachine.isActive)
        XCTAssertFalse(stateMachine.canCancel)
        XCTAssertNil(stateMachine.sessionId)
        XCTAssertNil(stateMachine.errorMessage)
        XCTAssertEqual(stateMachine.displayText, "Disconnected")
    }

    func testStateProperties_Idle() {
        stateMachine.transitionTo(.connecting)
        stateMachine.transitionTo(.idle(sessionId: testSessionId))

        XCTAssertTrue(stateMachine.isConnected)
        XCTAssertTrue(stateMachine.canStartRecording)
        XCTAssertFalse(stateMachine.isRecording)
        XCTAssertFalse(stateMachine.isProcessing)
        XCTAssertFalse(stateMachine.isPlaying)
        XCTAssertFalse(stateMachine.isActive)
        XCTAssertFalse(stateMachine.canCancel)
        XCTAssertEqual(stateMachine.sessionId, testSessionId)
        XCTAssertNil(stateMachine.errorMessage)
        XCTAssertEqual(stateMachine.displayText, "Ready")
    }

    func testStateProperties_Recording() {
        stateMachine.transitionTo(.connecting)
        stateMachine.transitionTo(.idle(sessionId: testSessionId))
        stateMachine.transitionTo(.recording(sessionId: testSessionId, bufferBytes: 2048))

        XCTAssertTrue(stateMachine.isConnected)
        XCTAssertFalse(stateMachine.canStartRecording)
        XCTAssertTrue(stateMachine.isRecording)
        XCTAssertFalse(stateMachine.isProcessing)
        XCTAssertFalse(stateMachine.isPlaying)
        XCTAssertTrue(stateMachine.isActive)
        XCTAssertTrue(stateMachine.canCancel)
        XCTAssertEqual(stateMachine.sessionId, testSessionId)
        XCTAssertNil(stateMachine.errorMessage)
        XCTAssertTrue(stateMachine.displayText.contains("Listening"))
    }

    func testStateProperties_Processing() {
        stateMachine.transitionTo(.connecting)
        stateMachine.transitionTo(.idle(sessionId: testSessionId))
        stateMachine.transitionTo(.recording(sessionId: testSessionId, bufferBytes: 1024))
        stateMachine.transitionTo(.processing(sessionId: testSessionId))

        XCTAssertTrue(stateMachine.isConnected)
        XCTAssertFalse(stateMachine.canStartRecording)
        XCTAssertFalse(stateMachine.isRecording)
        XCTAssertTrue(stateMachine.isProcessing)
        XCTAssertFalse(stateMachine.isPlaying)
        XCTAssertTrue(stateMachine.isActive)
        XCTAssertTrue(stateMachine.canCancel)
        XCTAssertEqual(stateMachine.sessionId, testSessionId)
        XCTAssertEqual(stateMachine.displayText, "Processing...")
    }

    func testStateProperties_Playing() {
        stateMachine.transitionTo(.connecting)
        stateMachine.transitionTo(.idle(sessionId: testSessionId))
        stateMachine.transitionTo(.recording(sessionId: testSessionId, bufferBytes: 1024))
        stateMachine.transitionTo(.processing(sessionId: testSessionId))
        stateMachine.transitionTo(.playing(sessionId: testSessionId, activeBuffers: 5))

        XCTAssertTrue(stateMachine.isConnected)
        XCTAssertFalse(stateMachine.canStartRecording)
        XCTAssertFalse(stateMachine.isRecording)
        XCTAssertFalse(stateMachine.isProcessing)
        XCTAssertTrue(stateMachine.isPlaying)
        XCTAssertTrue(stateMachine.isActive)
        XCTAssertTrue(stateMachine.canCancel)
        XCTAssertEqual(stateMachine.sessionId, testSessionId)
        XCTAssertTrue(stateMachine.displayText.contains("Playing"))
    }

    func testStateProperties_Error() {
        stateMachine.transitionTo(.connecting)
        stateMachine.transitionTo(.idle(sessionId: testSessionId))
        stateMachine.transitionTo(.error(sessionId: testSessionId, message: "Test error"))

        XCTAssertFalse(stateMachine.isConnected)
        XCTAssertFalse(stateMachine.canStartRecording)
        XCTAssertFalse(stateMachine.isRecording)
        XCTAssertFalse(stateMachine.isProcessing)
        XCTAssertFalse(stateMachine.isPlaying)
        XCTAssertFalse(stateMachine.isActive)
        XCTAssertFalse(stateMachine.canCancel)
        XCTAssertEqual(stateMachine.sessionId, testSessionId)
        XCTAssertEqual(stateMachine.errorMessage, "Test error")
        XCTAssertTrue(stateMachine.displayText.contains("Error"))
    }

    // MARK: - Force Transition Tests

    func testForceTransition() {
        // Force an invalid transition
        stateMachine.forceTransition(.playing(sessionId: testSessionId, activeBuffers: 1))

        // Should succeed despite being invalid
        XCTAssertTrue(stateMachine.isPlaying)
        XCTAssertEqual(stateMachine.sessionId, testSessionId)
    }

    // MARK: - Display Text Tests

    func testDisplayText_WithBufferInfo() {
        stateMachine.transitionTo(.connecting)
        stateMachine.transitionTo(.idle(sessionId: testSessionId))

        // Recording with small buffer
        stateMachine.transitionTo(.recording(sessionId: testSessionId, bufferBytes: 512))
        XCTAssertTrue(stateMachine.displayText.contains("512B"))

        // Recording with KB buffer
        stateMachine.transitionTo(.recording(sessionId: testSessionId, bufferBytes: 2048))
        XCTAssertTrue(stateMachine.displayText.contains("2KB"))

        // Processing
        stateMachine.transitionTo(.processing(sessionId: testSessionId))

        // Playing with multiple buffers
        stateMachine.transitionTo(.playing(sessionId: testSessionId, activeBuffers: 3))
        XCTAssertTrue(stateMachine.displayText.contains("3 chunks"))
    }

    // MARK: - Equatable Tests

    func testEquatable() {
        let state1: VoiceInteractionState = .disconnected
        let state2: VoiceInteractionState = .disconnected
        XCTAssertEqual(state1, state2)

        let state3: VoiceInteractionState = .idle(sessionId: "session-1")
        let state4: VoiceInteractionState = .idle(sessionId: "session-1")
        XCTAssertEqual(state3, state4)

        let state5: VoiceInteractionState = .idle(sessionId: "session-1")
        let state6: VoiceInteractionState = .idle(sessionId: "session-2")
        XCTAssertNotEqual(state5, state6)
    }
}
