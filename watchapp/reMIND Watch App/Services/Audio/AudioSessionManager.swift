//
//  AudioSessionManager.swift
//  reMIND Watch App
//
//  Manages AVAudioSession lifecycle, interruptions, and route changes
//  Extracted from AudioService to improve single responsibility
//

import Foundation
import AVFoundation
import os

/// Delegate protocol for audio session events
/// Note: Using @Sendable closures instead of actor delegate for simpler integration
protocol AudioSessionManagerDelegate: AnyObject, Sendable {
    /// Called when audio interruption begins
    func audioSessionManagerDidBeginInterruption(_ manager: AudioSessionManager) async

    /// Called when audio interruption ends
    /// - Parameter shouldResume: Whether the session should resume playback
    func audioSessionManager(_ manager: AudioSessionManager, didEndInterruptionWithShouldResume shouldResume: Bool) async

    /// Called when audio route changes
    /// - Parameter reason: The reason for the route change
    func audioSessionManager(_ manager: AudioSessionManager, didChangeRouteWithReason reason: AVAudioSession.RouteChangeReason) async
}

/// Manages AVAudioSession configuration, interruptions, and route changes
final class AudioSessionManager: Sendable {
    // MARK: - Properties

    /// Callback for interruption began event (set by AudioService)
    nonisolated(unsafe) var onInterruptionBegan: (@Sendable () async -> Void)?

    /// Callback for interruption ended event
    nonisolated(unsafe) var onInterruptionEnded: (@Sendable (_ shouldResume: Bool) async -> Void)?

    /// Callback for route change event
    nonisolated(unsafe) var onRouteChange: (@Sendable (_ reason: AVAudioSession.RouteChangeReason) async -> Void)?

    private let lock = NSLock()
    private var _interruptionTask: Task<Void, Never>?
    private var _routeChangeTask: Task<Void, Never>?
    private var _isActive = false

    private var interruptionTask: Task<Void, Never>? {
        get { lock.withLock { _interruptionTask } }
        set { lock.withLock { _interruptionTask = newValue } }
    }

    private var routeChangeTask: Task<Void, Never>? {
        get { lock.withLock { _routeChangeTask } }
        set { lock.withLock { _routeChangeTask = newValue } }
    }

    var isActive: Bool {
        get { lock.withLock { _isActive } }
        set { lock.withLock { _isActive = newValue } }
    }

    init() {}

    // MARK: - Session Configuration

    /// Configure and activate the audio session for voice chat
    func activate() throws {
        let audioSession = AVAudioSession.sharedInstance()

        // Build options with availability-safe flags
        let options: AVAudioSession.CategoryOptions
        if #available(watchOS 11.0, *) {
            options = [.allowBluetooth, .allowBluetoothHFP, .allowBluetoothA2DP]
        } else {
            options = [.allowBluetoothA2DP]
        }

        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: options)
        try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])

        isActive = true

        AppLogger.audio.info("Audio session activated: category=playAndRecord, mode=voiceChat")
        AppLogger.audio.debug("Current route: \(audioSession.currentRoute)")

        // Start monitoring
        startMonitoringInterruptions()
        startMonitoringRouteChanges()
    }

    /// Deactivate the audio session
    func deactivate() {
        stopMonitoringInterruptions()
        stopMonitoringRouteChanges()

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            AppLogger.audio.debug("Audio session deactivated")
        } catch {
            AppLogger.logError(error, category: AppLogger.audio, context: "Failed to deactivate audio session")
        }

        isActive = false
    }

    /// Reactivate after interruption
    func reactivate() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
        AppLogger.audio.debug("Audio session reactivated after interruption")
    }

    /// Check if the session is currently active
    var isSessionActive: Bool {
        isActive
    }

    // MARK: - Interruption Handling

    private func startMonitoringInterruptions() {
        interruptionTask?.cancel()

        interruptionTask = Task { [weak self] in
            let notificationCenter = NotificationCenter.default
            let notifications = notificationCenter.notifications(named: AVAudioSession.interruptionNotification)

            for await notification in notifications {
                await self?.handleInterruption(notification)
            }
        }

        AppLogger.audio.info("Started monitoring audio interruptions")
    }

    private func stopMonitoringInterruptions() {
        interruptionTask?.cancel()
        interruptionTask = nil
        AppLogger.audio.info("Stopped monitoring audio interruptions")
    }

    private func handleInterruption(_ notification: Notification) async {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            AppLogger.audio.warning("Audio session interrupted")
            await onInterruptionBegan?()

        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                let shouldResume = options.contains(.shouldResume)
                AppLogger.audio.debug("Audio session interruption ended - shouldResume: \(shouldResume)")
                await onInterruptionEnded?(shouldResume)
            }

        @unknown default:
            AppLogger.audio.warning("Unknown interruption type received")
        }
    }

    // MARK: - Route Change Handling

    private func startMonitoringRouteChanges() {
        routeChangeTask?.cancel()

        routeChangeTask = Task { [weak self] in
            let notificationCenter = NotificationCenter.default
            let notifications = notificationCenter.notifications(named: AVAudioSession.routeChangeNotification)

            for await notification in notifications {
                await self?.handleRouteChange(notification)
            }
        }

        AppLogger.audio.debug("Started monitoring audio route changes")
    }

    private func stopMonitoringRouteChanges() {
        routeChangeTask?.cancel()
        routeChangeTask = nil
        AppLogger.audio.debug("Stopped monitoring audio route changes")
    }

    private func handleRouteChange(_ notification: Notification) async {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        let audioSession = AVAudioSession.sharedInstance()
        let currentRoute = audioSession.currentRoute

        switch reason {
        case .newDeviceAvailable:
            AppLogger.audio.debug("Audio route: New device available")
            if let newDevice = currentRoute.inputs.first {
                AppLogger.audio.debug("New input device: \(newDevice.portName) (\(newDevice.portType.rawValue))")
            }

        case .oldDeviceUnavailable:
            AppLogger.audio.warning("Audio route: Device disconnected")

        case .categoryChange:
            AppLogger.audio.debug("Audio route: Category changed")

        case .override:
            AppLogger.audio.debug("Audio route: Override")

        case .wakeFromSleep:
            AppLogger.audio.debug("Audio route: Wake from sleep")

        case .noSuitableRouteForCategory:
            AppLogger.audio.warning("Audio route: No suitable route for category")

        case .routeConfigurationChange:
            AppLogger.audio.debug("Audio route: Configuration change")

        @unknown default:
            AppLogger.audio.warning("Audio route: Unknown reason (\(reasonValue))")
        }

        await onRouteChange?(reason)
    }
}
