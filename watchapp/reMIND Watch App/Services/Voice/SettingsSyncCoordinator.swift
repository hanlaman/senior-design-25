//
//  SettingsSyncCoordinator.swift
//  reMIND Watch App
//
//  Coordinates voice settings synchronization with active Azure session
//  Extracted from VoiceViewModel to reduce complexity and improve testability
//

import Foundation
import Combine
import os

/// Delegate protocol for settings sync coordinator callbacks
@MainActor
protocol SettingsSyncCoordinatorDelegate: AnyObject {
    /// Check if currently in an active interaction (recording, processing, or playing)
    var isActiveInteraction: Bool { get async }

    /// Perform graceful reconnection with new settings
    /// - Parameter settings: New settings to apply via reconnection
    func performReconnection(with settings: VoiceSettings) async

    /// Perform session update with new settings (no reconnection needed)
    /// - Parameter settings: New settings to apply via session.update
    func performSessionUpdate(with settings: VoiceSettings) async
}

/// Coordinates settings synchronization between local settings and active Azure session
@MainActor
class SettingsSyncCoordinator {
    // MARK: - Properties

    weak var delegate: SettingsSyncCoordinatorDelegate?

    private let settingsManager: VoiceSettingsManager
    private var settingsObserver: AnyCancellable?
    private(set) var pendingSettings: VoiceSettings?
    private(set) var isConnected = false

    // MARK: - Initialization

    init(settingsManager: VoiceSettingsManager = .shared) {
        self.settingsManager = settingsManager
    }

    // MARK: - Lifecycle

    /// Start observing settings changes
    func startObserving() {
        settingsObserver = settingsManager.$settings
            .sink { [weak self] newSettings in
                guard let self = self else { return }
                Task { @MainActor in
                    await self.handleSettingsChange(newSettings)
                }
            }

        AppLogger.general.debug("Settings sync coordinator started observing")
    }

    /// Stop observing settings changes
    func stopObserving() {
        settingsObserver?.cancel()
        settingsObserver = nil
        AppLogger.general.debug("Settings sync coordinator stopped observing")
    }

    /// Notify coordinator of connection state changes
    /// - Parameter connected: Whether currently connected to Azure
    func setConnected(_ connected: Bool) {
        isConnected = connected
        if !connected {
            // Clear pending updates on disconnect
            pendingSettings = nil
        }
    }

    // MARK: - Pending Updates

    /// Apply any pending settings updates
    /// Should be called after active interactions complete
    func applyPendingUpdates() async {
        guard let pending = pendingSettings else {
            return
        }

        pendingSettings = nil
        AppLogger.general.debug("Applying pending settings update")
        await handleSettingsChange(pending)
    }

    // MARK: - Private Methods

    /// Handle settings changes and determine synchronization strategy
    /// - Parameter newSettings: New settings to synchronize
    private func handleSettingsChange(_ newSettings: VoiceSettings) async {
        // Only sync if connected
        guard isConnected else {
            // Settings saved locally, will apply on next connection
            return
        }

        // Compute what type of sync is needed
        let syncState = settingsManager.computeSyncState()

        // Check if we're in active interaction (recording, processing, or playing)
        guard let delegate = delegate else {
            AppLogger.general.warning("Settings sync coordinator has no delegate")
            return
        }

        let isActiveInteraction = await delegate.isActiveInteraction

        switch syncState {
        case .pendingReconnection(let fields):
            if isActiveInteraction {
                // Defer reconnection until interaction completes
                pendingSettings = newSettings
                AppLogger.general.info("Settings changed (\(fields.joined(separator: ", "))), will reconnect after current interaction")
            } else {
                // Safe to reconnect now
                AppLogger.general.info("Settings changed (\(fields.joined(separator: ", "))), reconnecting...")
                await delegate.performReconnection(with: newSettings)
            }

        case .pendingSessionUpdate(let fields):
            if isActiveInteraction {
                // Defer session update until interaction completes
                pendingSettings = newSettings
                AppLogger.general.info("Settings changed (\(fields.joined(separator: ", "))), will update session after current interaction")
            } else {
                // Safe to update session now
                AppLogger.general.info("Settings changed (\(fields.joined(separator: ", "))), updating session...")
                await delegate.performSessionUpdate(with: newSettings)
            }

        case .synchronized:
            // No changes needed
            pendingSettings = nil

        case .notConnected:
            // No active session to sync
            break
        }
    }
}
