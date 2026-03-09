//
//  SessionResource.swift
//  reMIND Watch App
//
//  Session configuration management for Azure Voice Live
//

import Foundation
import os

/// Manages session configuration for Azure Voice Live
public final class SessionResource {
    // MARK: - Properties

    private unowned let connection: VoiceLiveConnection

    // MARK: - Initialization

    init(connection: VoiceLiveConnection) {
        self.connection = connection
    }

    // MARK: - Session Management

    /// Update session configuration
    /// - Parameter config: Session configuration to apply
    /// - Throws: `AzureError` if not connected or configuration fails
    /// - Note: Voice configuration cannot be updated mid-session per Azure API documentation.
    ///         Voice settings changes require disconnect and reconnect to take effect.
    public func update(_ config: RealtimeRequestSession) async throws {
        guard await connection.connectionState == .connected else {
            throw AzureError.notConnected
        }

        // Log configuration details for debugging
        let voiceInfo: String
        if let voice = config.voice {
            switch voice {
            case .openai(let v):
                voiceInfo = "openai:\(v.name)"
            case .azureStandard(let v):
                voiceInfo = "azure-standard:\(v.name)"
            case .azureCustom(let v):
                voiceInfo = "azure-custom:\(v.name)/\(v.endpointId)"
            case .azurePersonal(let v):
                voiceInfo = "azure-personal:\(v.name)/\(v.model)"
            }
        } else {
            voiceInfo = "default"
        }

        let instructionsPreview = config.instructions?.prefix(50).description ?? "none"
        AppLogger.azure.info("Sending session.update event with configuration: voice=\(voiceInfo), instructions=\(instructionsPreview)...")

        let event = SessionUpdateEvent(session: config)
        try await connection.sendEvent(event)

        AppLogger.azure.debug("session.update event sent, waiting for server acknowledgment")
    }

    /// Wait for session to become ready
    /// - Throws: `AzureError.connectionTimeout` if session doesn't become ready within timeout
    func waitForReady() async throws {
        AppLogger.azure.debug("Waiting for session to be ready...")

        // Poll the session state with timeout
        let startTime = Date()
        let timeout = SessionConfiguration.establishmentTimeout

        while !(await connection.sessionState.canAcceptAudio) {
            // Check if timed out
            if Date().timeIntervalSince(startTime) > timeout {
                let currentState = await connection.sessionState.displayText
                AppLogger.azure.error("Timeout waiting for session ready, current state: \(currentState)")
                throw AzureError.connectionTimeout
            }

            // Sleep briefly before checking again
            try await Task.sleep(nanoseconds: UInt64(SessionConfiguration.statePollingDelay * 1_000_000_000))
        }

        let currentState = await connection.sessionState.displayText
        AppLogger.azure.info("Session ready: \(currentState)")
    }
}
