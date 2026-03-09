//
//  MockSettingsManager.swift
//  reMIND Watch AppTests
//
//  Mock implementation of SettingsManagerProtocol for testing
//

import Foundation
import Combine
@testable import reMIND_Watch_App

/// Mock settings manager for testing
class MockSettingsManager: SettingsManagerProtocol, ObservableObject {
    // MARK: - Test Control Properties

    /// Whether markAsSynchronized was called
    private(set) var markAsSynchronizedCalled = false

    /// Settings passed to markAsSynchronized
    private(set) var synchronizedSettings: VoiceSettings?

    /// Whether clearActiveSession was called
    private(set) var clearActiveSessionCalled = false

    /// Whether updateSpeakingRate was called
    private(set) var updateSpeakingRateCalled = false

    /// The last speaking rate passed to updateSpeakingRate
    private(set) var lastSpeakingRate: Double?

    // MARK: - Protocol Properties

    private(set) var settings: VoiceSettings

    private(set) var syncState: VoiceSettingsSyncState = .notConnected

    let objectWillChange = ObservableObjectPublisher()

    // MARK: - Initialization

    init(settings: VoiceSettings = .defaultSettings) {
        self.settings = settings
    }

    // MARK: - Protocol Methods

    func updateSpeakingRate(_ rate: Double) {
        updateSpeakingRateCalled = true
        lastSpeakingRate = rate
        settings.speakingRate = rate
        objectWillChange.send()
    }

    func markAsSynchronized(_ settings: VoiceSettings) {
        markAsSynchronizedCalled = true
        synchronizedSettings = settings
        syncState = .synchronized
    }

    func clearActiveSession() {
        clearActiveSessionCalled = true
        syncState = .notConnected
    }

    func computeSyncState() -> VoiceSettingsSyncState {
        return syncState
    }

    func changedFields() -> [SettingMetadata] {
        return []
    }

    // MARK: - Test Control Methods

    /// Set the sync state for testing
    func setSyncState(_ state: VoiceSettingsSyncState) {
        syncState = state
        objectWillChange.send()
    }

    /// Update settings for testing
    func setSettings(_ settings: VoiceSettings) {
        self.settings = settings
        objectWillChange.send()
    }

    /// Enable or disable continuous listening for testing
    func setContinuousListening(_ enabled: Bool) {
        settings.continuousListeningEnabled = enabled
        objectWillChange.send()
    }

    /// Reset all test state
    func reset() {
        markAsSynchronizedCalled = false
        synchronizedSettings = nil
        clearActiveSessionCalled = false
        updateSpeakingRateCalled = false
        lastSpeakingRate = nil
        settings = .defaultSettings
        syncState = .notConnected
    }
}
