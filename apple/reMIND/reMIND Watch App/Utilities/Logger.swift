//
//  Logger.swift
//  reMIND Watch App
//
//  Logging utility using OSLog
//

import Foundation
import os

/// Centralized logging utility
struct AppLogger {
    private static let subsystem = "com.remind.watchapp"

    static let general = os.Logger(subsystem: subsystem, category: "General")
    static let audio = os.Logger(subsystem: subsystem, category: "Audio")
    static let network = os.Logger(subsystem: subsystem, category: "Network")
    static let azure = os.Logger(subsystem: subsystem, category: "Azure")
    static let ui = os.Logger(subsystem: subsystem, category: "UI")

    /// Log error with context
    static func logError(_ error: Error, category: os.Logger, context: String) {
        category.error("\(context): \(error.localizedDescription)")
    }

    /// Log audio buffer info
    static func logAudioBuffer(framesProcessed: Int, bufferSize: Int) {
        audio.debug("Audio buffer: \(framesProcessed) frames processed, \(bufferSize) bytes")
    }

    /// Log WebSocket event
    static func logWebSocketEvent(_ event: String, details: String? = nil) {
        if let details = details {
            network.info("WebSocket event: \(event) - \(details)")
        } else {
            network.info("WebSocket event: \(event)")
        }
    }

    /// Log Azure event
    static func logAzureEvent(_ eventType: String, eventId: String) {
        azure.debug("Azure event: \(eventType) [id: \(eventId)]")
    }

    /// Log state change
    static func logStateChange<T>(_ state: T, from oldState: T? = nil) where T: CustomStringConvertible {
        if let oldState = oldState {
            ui.info("State change: \(String(describing: oldState)) → \(String(describing: state))")
        } else {
            ui.info("State: \(String(describing: state))")
        }
    }
}
