//
//  ToolSyncCoordinator.swift
//  reMIND Watch App
//
//  Auto-sync tool changes mid-session
//

import Foundation
import Combine
import os

// MARK: - ToolSyncCoordinatorDelegate

/// Delegate protocol for tool sync coordinator events
@MainActor
protocol ToolSyncCoordinatorDelegate: AnyObject {
    /// Called when tools configuration changes and session should be updated
    /// - Parameter coordinator: The coordinator instance
    func toolSyncCoordinatorDidRequestSync(_ coordinator: ToolSyncCoordinator) async
}

// MARK: - ToolSyncCoordinator

/// Coordinates automatic synchronization of tool changes to active session
@MainActor
class ToolSyncCoordinator {
    /// Delegate for sync events
    weak var delegate: ToolSyncCoordinatorDelegate?

    private let toolRegistry: ToolRegistry
    private let settingsManager: VoiceSettingsManager

    private var toolsObserver: AnyCancellable?
    private var isSessionActive: Bool = false
    private var isInActiveInteraction: Bool = false

    /// Whether a sync is pending (queued during active interaction)
    private var hasPendingSync: Bool = false

    /// Initialize coordinator
    /// - Parameters:
    ///   - toolRegistry: Registry of available tools
    ///   - settingsManager: Voice settings manager
    init(toolRegistry: ToolRegistry, settingsManager: VoiceSettingsManager) {
        self.toolRegistry = toolRegistry
        self.settingsManager = settingsManager
    }

    /// Start observing tool registry changes
    func startObserving() {
        toolsObserver = toolRegistry.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                await self?.handleToolsChange()
            }
        }

        AppLogger.general.info("ToolSyncCoordinator started observing tool changes")
    }

    /// Stop observing tool registry changes
    func stopObserving() {
        toolsObserver?.cancel()
        toolsObserver = nil

        AppLogger.general.debug("ToolSyncCoordinator stopped observing")
    }

    /// Update session active state
    /// - Parameter active: Whether a session is currently active
    func setSessionActive(_ active: Bool) {
        isSessionActive = active

        if active {
            AppLogger.general.debug("ToolSyncCoordinator: Session is now active")
        } else {
            AppLogger.general.debug("ToolSyncCoordinator: Session is now inactive")
        }
    }

    /// Update interaction state
    /// - Parameter isActive: Whether user is in active interaction (recording/processing/playing)
    func setInteractionState(_ isActive: Bool) {
        let wasActive = isInActiveInteraction
        isInActiveInteraction = isActive

        if isActive {
            AppLogger.general.debug("ToolSyncCoordinator: Interaction is now active")
        } else {
            AppLogger.general.debug("ToolSyncCoordinator: Interaction is now idle")

            // Apply pending sync if interaction just ended
            if wasActive && hasPendingSync {
                Task { @MainActor in
                    await applyPendingSync()
                }
            }
        }
    }

    /// Apply any pending tool sync
    private func applyPendingSync() async {
        guard hasPendingSync else { return }
        guard isSessionActive else {
            hasPendingSync = false
            return
        }

        hasPendingSync = false
        AppLogger.general.info("Applying pending tool sync after interaction ended")
        await delegate?.toolSyncCoordinatorDidRequestSync(self)
    }

    // MARK: - Private Helpers

    /// Handle tool registry changes
    private func handleToolsChange() async {
        // Only sync if session is active
        guard isSessionActive else {
            AppLogger.general.debug("Tools changed but session not active, skipping sync")
            return
        }

        // Queue sync if in active interaction (recording, processing, playing)
        if isInActiveInteraction {
            hasPendingSync = true
            AppLogger.general.info("Tools changed during interaction, queued for sync when idle")
            return
        }

        AppLogger.general.info("Tools configuration changed, requesting session update...")
        await delegate?.toolSyncCoordinatorDidRequestSync(self)
    }
}
