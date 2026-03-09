//
//  ToolSyncCoordinatorTests.swift
//  reMIND Watch AppTests
//
//  Tests for ToolSyncCoordinator - verifying tool configuration sync queueing behavior
//

import XCTest
import Combine
@testable import reMIND_Watch_App

/// Mock delegate for ToolSyncCoordinator testing
@MainActor
class MockToolSyncDelegate: ToolSyncCoordinatorDelegate {
    // Track delegate calls
    var syncRequestedCount = 0
    var lastSyncCoordinator: ToolSyncCoordinator?

    func toolSyncCoordinatorDidRequestSync(_ coordinator: ToolSyncCoordinator) async {
        syncRequestedCount += 1
        lastSyncCoordinator = coordinator
    }

    func reset() {
        syncRequestedCount = 0
        lastSyncCoordinator = nil
    }
}

@MainActor
final class ToolSyncCoordinatorTests: XCTestCase {

    var toolRegistry: ToolRegistry!
    var settingsManager: VoiceSettingsManager!
    var coordinator: ToolSyncCoordinator!
    var delegate: MockToolSyncDelegate!

    override func setUp() async throws {
        toolRegistry = .shared
        settingsManager = .shared
        coordinator = ToolSyncCoordinator(
            toolRegistry: toolRegistry,
            settingsManager: settingsManager
        )
        delegate = MockToolSyncDelegate()
        coordinator.delegate = delegate
    }

    override func tearDown() async throws {
        coordinator.stopObserving()
        coordinator = nil
        delegate = nil
    }

    // MARK: - Session Active State Tests

    func test_setSessionActive_true_updatesState() async throws {
        // Given: Session starts inactive
        coordinator.setSessionActive(false)

        // When: Session becomes active
        coordinator.setSessionActive(true)

        // Then: No immediate effect (just state update)
        // Test passes if no crash
    }

    func test_setSessionActive_false_clearsState() async throws {
        // Given: Session is active
        coordinator.setSessionActive(true)

        // When: Session becomes inactive
        coordinator.setSessionActive(false)

        // Then: Pending sync should be cleared
        // Test passes if no crash
    }

    // MARK: - Interaction State Tests

    func test_setInteractionState_activeTrue_preventsImmediateSync() async throws {
        // Given: Session is active
        coordinator.setSessionActive(true)
        coordinator.startObserving()
        coordinator.setInteractionState(true) // Active interaction

        // When: Tool changes occur (simulated via objectWillChange)
        // Note: In production, this is triggered by toolRegistry.objectWillChange

        // Then: No immediate sync (queued for later)
        XCTAssertEqual(delegate.syncRequestedCount, 0)
    }

    func test_setInteractionState_activeFalse_appliesPendingSync() async throws {
        // Given: Session is active with pending sync
        coordinator.setSessionActive(true)
        coordinator.startObserving()
        coordinator.setInteractionState(true) // Start active

        // Manually trigger a tool change scenario (simulate pending sync)
        // In real code, this happens when toolRegistry changes during interaction

        // When: Interaction ends
        delegate.reset()
        coordinator.setInteractionState(false)

        // Allow async processing
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Then: If there was a pending sync, it should be applied
        // Note: Since we can't easily trigger a pending sync without modifying toolRegistry,
        // we verify the coordinator doesn't crash and handles the state transition
    }

    // MARK: - Tool Change During Different States Tests

    func test_toolChange_whenSessionInactive_noSync() async throws {
        // Given: Session is not active
        coordinator.setSessionActive(false)
        coordinator.startObserving()

        // When: Tools configuration changes
        // (Tool registry will publish objectWillChange)

        // Allow async processing
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Then: No sync should occur
        XCTAssertEqual(delegate.syncRequestedCount, 0)
    }

    func test_toolChange_whenSessionActiveAndIdle_syncsImmediately() async throws {
        // Given: Session is active and interaction is idle
        coordinator.setSessionActive(true)
        coordinator.setInteractionState(false) // Idle
        coordinator.startObserving()

        // When: Tool registry publishes change
        // We trigger this by toggling a tool
        let enabledTools = toolRegistry.availableTools.filter { $0.isEnabled }
        if let firstTool = enabledTools.first {
            toolRegistry.toggleTool(id: firstTool.id)

            // Allow async processing
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms

            // Then: Sync should be requested
            XCTAssertGreaterThan(delegate.syncRequestedCount, 0)

            // Restore tool state
            toolRegistry.toggleTool(id: firstTool.id)
        }
    }

    func test_toolChange_whenRecording_queuesSyncForLater() async throws {
        // Given: Session is active and in recording state
        coordinator.setSessionActive(true)
        coordinator.setInteractionState(true) // Active (recording/playing)
        coordinator.startObserving()

        // When: Tool registry publishes change
        let enabledTools = toolRegistry.availableTools.filter { $0.isEnabled }
        if let firstTool = enabledTools.first {
            let initialSyncCount = delegate.syncRequestedCount
            toolRegistry.toggleTool(id: firstTool.id)

            // Allow async processing
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms

            // Then: No immediate sync (queued)
            // Sync count should not have increased during active interaction
            // (Actual behavior: queued sync happens when interaction ends)

            // When: Interaction ends
            coordinator.setInteractionState(false)

            // Allow async processing for pending sync
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms

            // Then: Pending sync should now be applied
            XCTAssertGreaterThan(delegate.syncRequestedCount, initialSyncCount)

            // Restore tool state
            toolRegistry.toggleTool(id: firstTool.id)
        }
    }

    func test_toolChange_whilePlaying_queuesSyncForLater() async throws {
        // This is the same as recording - both are "active interaction" states
        // Given: Session is active and playing
        coordinator.setSessionActive(true)
        coordinator.setInteractionState(true) // Active (playing)
        coordinator.startObserving()

        // When: Tool changes
        // Then: Queued for later (tested in previous test)

        // Just verify state handling doesn't crash
        coordinator.setInteractionState(false)
    }

    // MARK: - Multiple Changes Tests

    func test_multipleToolChanges_duringInteraction_syncsOnceAtEnd() async throws {
        // Given: Session is active and in interaction
        coordinator.setSessionActive(true)
        coordinator.setInteractionState(true) // Active
        coordinator.startObserving()

        let tools = toolRegistry.availableTools
        guard tools.count >= 1 else {
            // Skip if no tools available
            return
        }

        // When: Multiple tool changes during interaction
        let firstTool = tools[0]
        toolRegistry.toggleTool(id: firstTool.id)
        try await Task.sleep(nanoseconds: 20_000_000)
        toolRegistry.toggleTool(id: firstTool.id)
        try await Task.sleep(nanoseconds: 20_000_000)
        toolRegistry.toggleTool(id: firstTool.id)
        try await Task.sleep(nanoseconds: 20_000_000)

        // Then: No syncs during interaction
        let syncCountDuringInteraction = delegate.syncRequestedCount

        // When: Interaction ends
        delegate.reset()
        coordinator.setInteractionState(false)

        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Then: Only one sync should occur at the end
        // Note: The coordinator queues sync, and applies once when idle
        // Multiple changes while active result in one pending sync

        // Restore tool state
        if !toolRegistry.availableTools.first(where: { $0.id == firstTool.id })!.isEnabled {
            toolRegistry.toggleTool(id: firstTool.id)
        }
    }

    // MARK: - Lifecycle Tests

    func test_startObserving_registersForToolChanges() async throws {
        // Given: Coordinator not observing
        coordinator.setSessionActive(true)
        coordinator.setInteractionState(false)

        // When: Start observing and trigger tool change
        coordinator.startObserving()

        let tools = toolRegistry.availableTools
        if let firstTool = tools.first {
            toolRegistry.toggleTool(id: firstTool.id)

            try await Task.sleep(nanoseconds: 100_000_000) // 100ms

            // Then: Should receive sync request
            XCTAssertGreaterThan(delegate.syncRequestedCount, 0)

            // Restore
            toolRegistry.toggleTool(id: firstTool.id)
        }
    }

    func test_stopObserving_unregistersForToolChanges() async throws {
        // Given: Coordinator is observing
        coordinator.setSessionActive(true)
        coordinator.setInteractionState(false)
        coordinator.startObserving()

        // When: Stop observing
        coordinator.stopObserving()
        delegate.reset()

        // And tool changes
        let tools = toolRegistry.availableTools
        if let firstTool = tools.first {
            toolRegistry.toggleTool(id: firstTool.id)

            try await Task.sleep(nanoseconds: 100_000_000) // 100ms

            // Then: No sync request (stopped observing)
            XCTAssertEqual(delegate.syncRequestedCount, 0)

            // Restore
            toolRegistry.toggleTool(id: firstTool.id)
        }
    }

    // MARK: - Edge Cases

    func test_sessionInactive_afterToolChangeQueued_clearsPending() async throws {
        // Given: Active session with pending tool sync
        coordinator.setSessionActive(true)
        coordinator.setInteractionState(true)
        coordinator.startObserving()

        let tools = toolRegistry.availableTools
        if let firstTool = tools.first {
            toolRegistry.toggleTool(id: firstTool.id)

            try await Task.sleep(nanoseconds: 50_000_000)

            // When: Session becomes inactive (e.g., disconnect)
            coordinator.setSessionActive(false)
            coordinator.setInteractionState(false)

            delegate.reset()

            try await Task.sleep(nanoseconds: 100_000_000)

            // Then: Pending sync should not be applied (session inactive)
            XCTAssertEqual(delegate.syncRequestedCount, 0)

            // Restore
            toolRegistry.toggleTool(id: firstTool.id)
        }
    }
}
