//
//  Response.swift
//  reMIND Watch App
//
//  Response management for Azure Voice Live
//

import Foundation
import os

/// Manages response creation and cancellation for Azure Voice Live
public final class Response {
    // MARK: - Properties

    private unowned let connection: VoiceLiveConnection

    // MARK: - Initialization

    init(connection: VoiceLiveConnection) {
        self.connection = connection
    }

    // MARK: - Response Management

    /// Create a new response from the model
    /// - Parameter options: Optional response configuration
    /// - Throws: `AzureError` if not connected or session not ready
    public func create(options: RealtimeResponseOptions? = nil) async throws {
        guard await connection.connectionState == .connected else {
            throw AzureError.notConnected
        }

        guard await connection.sessionState.canAcceptConversation else {
            throw AzureError.sessionNotReady
        }

        AppLogger.azure.debug("Creating response")

        let event = ResponseCreateEvent(response: options)
        try await connection.sendEvent(event)
    }

    /// Cancel an in-progress response
    /// - Throws: `AzureError` if not connected
    public func cancel() async throws {
        guard await connection.connectionState == .connected else {
            throw AzureError.notConnected
        }

        AppLogger.azure.info("Canceling response")

        let event = ResponseCancelEvent()
        try await connection.sendEvent(event)
    }
}
