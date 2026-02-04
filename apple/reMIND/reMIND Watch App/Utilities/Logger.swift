//
//  Logger.swift
//  reMIND Watch App
//
//  Logging utility using OSLog
//
//  Swift 6 Strict Concurrency Compliance:
//  - os.Logger now conforms to Sendable (as of recent SDK updates)
//  - Static let properties with Sendable types are safe for cross-actor access
//  - No explicit isolation annotations needed for Logger properties
//  - Logger is thread-safe and immutable after initialization
//  - OSLog is optimized for WatchOS battery efficiency and should be preferred over print()
//

import Foundation
import os

/// Centralized logging utility for WatchOS app
///
/// This logger provides category-based logging using Apple's OSLog framework,
/// which is optimized for performance and battery efficiency on WatchOS.
///
/// **Swift 6 Concurrency:**
/// os.Logger conforms to Sendable, making static logger properties safe for cross-actor access
/// without requiring explicit isolation annotations. Logger instances are immutable after
/// initialization and internally thread-safe.
///
/// **Design:**
/// Using an enum (not instantiable) ensures this type serves only as a namespace for loggers.
///
/// **Usage:**
/// ```swift
/// // From any isolation context (MainActor, actor, or nonisolated)
/// AppLogger.general.info("Application started")
/// AppLogger.audio.debug("Processing audio buffer")
/// AppLogger.logError(error, category: AppLogger.network, context: "Failed to connect")
/// ```
enum AppLogger {
    private static let subsystem = "com.remind.watchapp"

    /// General application events
    /// Use for: app lifecycle, configuration, general flow
    static let general = os.Logger(subsystem: subsystem, category: "General")

    /// Audio capture and playback events
    /// Use for: audio engine, buffer management, format conversion
    static let audio = os.Logger(subsystem: subsystem, category: "Audio")

    /// Network communication events
    /// Use for: WebSocket connections, network errors, reconnection logic
    static let network = os.Logger(subsystem: subsystem, category: "Network")

    /// Azure Voice Live API events
    /// Use for: session management, event processing, API communication
    static let azure = os.Logger(subsystem: subsystem, category: "Azure")

    /// User interface events
    /// Use for: view lifecycle, state changes, user interactions
    static let ui = os.Logger(subsystem: subsystem, category: "UI")

    /// Log error with context
    ///
    /// Provides a consistent way to log errors with contextual information.
    /// The error's localized description is automatically included.
    ///
    /// - Parameters:
    ///   - error: The error to log
    ///   - category: The logger category to use (e.g., AppLogger.general)
    ///   - context: Contextual description of where/why the error occurred
    ///
    /// Example:
    /// ```swift
    /// do {
    ///     try await connect()
    /// } catch {
    ///     AppLogger.logError(error, category: AppLogger.network, context: "Failed to connect to server")
    /// }
    /// ```
    nonisolated static func logError(_ error: Error, category: os.Logger, context: String) {
        category.error("\(context): \(error.localizedDescription)")
    }

    /// Log audio buffer processing information
    ///
    /// - Parameters:
    ///   - framesProcessed: Number of audio frames processed
    ///   - bufferSize: Size of the buffer in bytes
    nonisolated static func logAudioBuffer(framesProcessed: Int, bufferSize: Int) {
        audio.debug("Audio buffer: \(framesProcessed) frames processed, \(bufferSize) bytes")
    }

    /// Log WebSocket event
    ///
    /// - Parameters:
    ///   - event: The event name or type
    ///   - details: Optional additional details about the event
    nonisolated static func logWebSocketEvent(_ event: String, details: String? = nil) {
        if let details = details {
            network.info("WebSocket event: \(event) - \(details)")
        } else {
            network.info("WebSocket event: \(event)")
        }
    }

    /// Log Azure event
    ///
    /// - Parameters:
    ///   - eventType: The type of Azure event
    ///   - eventId: The unique event identifier
    nonisolated static func logAzureEvent(_ eventType: String, eventId: String) {
        azure.debug("Azure event: \(eventType) [id: \(eventId)]")
    }

    /// Log state change
    ///
    /// Logs transitions between states, useful for debugging state machines.
    ///
    /// - Parameters:
    ///   - state: The new state
    ///   - oldState: The previous state (optional)
    nonisolated static func logStateChange<T>(_ state: T, from oldState: T? = nil) where T: CustomStringConvertible {
        if let oldState = oldState {
            ui.info("State change: \(String(describing: oldState)) → \(String(describing: state))")
        } else {
            ui.info("State: \(String(describing: state))")
        }
    }
}

// MARK: - WatchOS Logging Best Practices
//
// 1. Performance & Battery:
//    - OSLog is highly optimized and has minimal battery impact on WatchOS
//    - Log levels are filtered at runtime based on system configuration
//    - String interpolation in OSLog is efficient and lazy-evaluated
//    - Logging has minimal memory footprint and doesn't block execution
//
// 2. Log Levels (in order of severity):
//    - .debug:   Detailed information for debugging (filtered out in Release builds)
//    - .info:    Important informational messages about app flow
//    - .notice:  Significant but normal events (default level)
//    - .error:   Error conditions that don't crash the app
//    - .fault:   Critical errors that may lead to crashes
//
// 3. Usage Guidelines:
//    - Use .debug for verbose logging during development
//    - Use .info for important state changes and events
//    - Use .error for recoverable errors
//    - Avoid logging in tight loops (consider sampling or aggregation)
//    - Keep log messages concise but meaningful
//    - Consider log volume impact on device performance
//
// 4. Swift 6 Strict Concurrency (Current Implementation):
//    - os.Logger now conforms to Sendable (no explicit annotations needed)
//    - Static let properties with Sendable types are safe for cross-actor access
//    - Static methods use 'nonisolated' to be callable from any actor context
//    - No async/await needed for logging - calls are synchronous and thread-safe
//    - Safe to use from @MainActor, actor types, and nonisolated contexts
//    - Logger is immutable after initialization and internally thread-safe
//
// 5. Privacy:
//    - By default, dynamic strings are redacted in logs for user privacy
//    - Use privacy modifiers to control what gets logged:
//      logger.info("User: \(username, privacy: .public)")
//      logger.info("Token: \(token, privacy: .private)") // explicitly private
//    - Never log sensitive data (passwords, authentication tokens, PII)
//    - Test privacy settings before shipping to production
//
// 6. Debugging & Monitoring:
//    - View logs in Xcode Console during development
//    - Use Console.app to view logs from physical devices
//    - Filter by subsystem: "com.remind.watchapp"
//    - Filter by category: "General", "Audio", "Network", "Azure", "UI"
//    - Use Instruments for performance profiling with log signposts
//
// 7. Historical Context:
//    - Prior to recent SDK updates, os.Logger wasn't marked as Sendable
//    - Earlier workarounds included `nonisolated(unsafe)` annotations or global actor isolation
//    - Current implementation (clean static let) is the preferred approach
//    - References for historical context:
//      * https://developer.apple.com/forums/thread/747816 (Is OSLog Logger Sendable?)
//      * https://forums.swift.org/t/logging-and-structured-concurrency-tasklocal/51215
