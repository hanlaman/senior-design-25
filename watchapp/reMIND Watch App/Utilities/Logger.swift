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
/// without requiring explicit isolation annotations. All helper methods are marked `nonisolated`
/// to be callable from any actor context.
///
/// **Design:**
/// Using an enum (not instantiable) ensures this type serves only as a namespace for loggers.
///
/// **Usage:**
/// ```swift
/// // From any isolation context (MainActor, actor, or nonisolated)
/// AppLogger.general.info("⚙️ Application started")
/// AppLogger.audio.debug("🔊 Processing audio buffer")
/// AppLogger.logError(error, category: AppLogger.network, context: "Failed to connect")
///
/// // With sampling for high-frequency logs
/// AppLogger.debug("Delta event", category: .azure, every: 20)
/// ```
///
/// **Xcode Filtering:**
/// This app uses OSLog levels strategically to enable effective filtering:
/// - Debug: Verbose diagnostics (use Xcode "TYPE Debug" filter)
/// - Info: Important state changes (use Xcode "TYPE Info" filter)
/// - Warning/Error/Fault: Issues (use Xcode "TYPE Error" filter)
///
/// Recommended filters:
/// - Development: "TYPE Debug" or "TYPE Info AND category:Azure"
/// - Production debugging: "TYPE Info" or "TYPE Error"
/// - Specific subsystem: "subsystem:com.remind.watchapp"
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

    /// Conversation history management events
    /// Use for: history persistence, session management, message storage
    static let history = os.Logger(subsystem: subsystem, category: "History")

    /// Sampling support for high-frequency logs
    private static let logSampler = LogSampler()

    #if DEBUG
    /// Verbose logging enabled in debug builds
    static let enableVerboseLogging = true
    #else
    /// Minimal logging in release builds
    static let enableVerboseLogging = false
    #endif

    /// Enhanced debug logging with optional sampling
    ///
    /// Only logs in DEBUG builds. Supports sampling to reduce high-frequency log spam.
    ///
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The logger category to use
    ///   - every: Optional sampling rate - logs every Nth call (e.g., every: 20 logs 1 out of 20 calls)
    ///
    /// Example:
    /// ```swift
    /// // Log every delta event (verbose)
    /// AppLogger.debug("Delta received", category: .azure)
    ///
    /// // Log only every 20th delta event
    /// AppLogger.debug("Delta received", category: .azure, every: 20)
    /// ```
    nonisolated static func debug(_ message: String, category: os.Logger, every n: Int? = nil) {
        #if DEBUG
        if let n = n {
            guard logSampler.shouldLog(every: n) else { return }
        }
        category.debug("\(message)")
        #endif
    }

    /// Enhanced trace logging for method entry/exit
    ///
    /// Only logs in DEBUG builds. Useful for debugging control flow.
    ///
    /// - Parameters:
    ///   - methodName: The name of the method being traced
    ///   - category: The logger category to use
    ///   - phase: Whether this is entry or exit from the method
    nonisolated static func trace(_ methodName: String, category: os.Logger, phase: TracePhase = .entry) {
        #if DEBUG
        category.debug("[\(phase.rawValue)] \(methodName)")
        #endif
    }

    /// Trace phase indicator
    enum TracePhase: String {
        case entry = "→"
        case exit = "←"
    }

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

// MARK: - Log Sampling Helper

/// Thread-safe log sampling for reducing high-frequency log spam
///
/// Use this to log only every Nth occurrence of a high-frequency event.
/// Thread-safe using NSLock for cross-actor safety.
final class LogSampler: @unchecked Sendable {
    private let lock = NSLock()
    private var counter = 0

    /// Check if this call should be logged based on sampling rate
    ///
    /// - Parameter n: Log every Nth call (e.g., n=20 logs 1 out of 20 calls)
    /// - Returns: true if this call should be logged, false otherwise
    func shouldLog(every n: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        counter += 1
        return counter % n == 1
    }

    /// Reset the counter (useful for starting new sequences)
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        counter = 0
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
//                Use for: Verbose diagnostics, method traces, high-frequency events
//                Xcode filter: "TYPE Debug"
//    - .info:    Important informational messages about app flow
//                Use for: State changes, milestones, user actions
//                Xcode filter: "TYPE Info"
//    - .notice:  Significant but normal events (default level)
//    - .error:   Error conditions that don't crash the app
//                Use for: Errors affecting functionality
//                Xcode filter: "TYPE Error"
//    - .fault:   Critical errors that may lead to crashes
//                Use for: Unrecoverable states, data corruption
//                Xcode filter: "TYPE Fault"
//
// 3. Usage Guidelines:
//    - Use .debug() for verbose logging during development (auto-filtered in Release)
//    - Use .info() ONLY for important state changes (keep these to ~30% of total logs)
//    - Use .warning() for recoverable issues
//    - Use .error() for errors affecting functionality
//    - For high-frequency events (>10/sec), use AppLogger.debug() with sampling:
//      AppLogger.debug("Delta event", category: .azure, every: 20)
//    - Avoid logging in tight loops without sampling
//    - Keep log messages concise but meaningful with context prefixes
//    - Consider log volume impact on device performance and battery
//
// 4. Swift 6 Strict Concurrency (Current Implementation):
//    - os.Logger conforms to Sendable (as of recent SDK updates)
//    - Static let properties with Sendable types are safe for cross-actor access
//    - Static methods use 'nonisolated' to be callable from any actor context
//    - No async/await needed for logging - calls are synchronous and thread-safe
//    - Safe to use from @MainActor, actor types, and nonisolated contexts
//    - Logger is immutable after initialization and internally thread-safe
//    - If you encounter MainActor isolation errors, ensure your SDK is up to date
//
// 5. Privacy:
//    - By default, dynamic strings are redacted in logs for user privacy
//    - Use privacy modifiers to control what gets logged:
//      logger.info("User: \(username, privacy: .public)")
//      logger.info("Token: \(token, privacy: .private)") // explicitly private
//    - Never log sensitive data (passwords, authentication tokens, PII)
//    - Test privacy settings before shipping to production
//
// 6. Debugging & Monitoring with Xcode Filters:
//    **Using Xcode's Built-in TYPE Filters:**
//    - View logs in Xcode Console during development
//    - Use TYPE filters for effective log filtering:
//      * "TYPE Debug" - See verbose diagnostics (debug build only)
//      * "TYPE Info" - See only important state changes (~70 messages)
//      * "TYPE Error" - See only warnings and errors
//    - Combine filters: "TYPE Info AND category:Azure" for specific context
//    - Filter by subsystem: "subsystem:com.remind.watchapp"
//    - Filter by category: "General", "Audio", "Network", "Azure", "UI"
//
//    **Recommended Workflow:**
//    - Development: Start with "TYPE Info" for clean overview
//    - Deep debugging: Switch to "TYPE Debug" for verbose details
//    - Production issues: Use "TYPE Error" to see only problems
//
//    **Other Tools:**
//    - Use Console.app to view logs from physical devices
//    - Use Instruments for performance profiling with log signposts
//
// 7. Historical Context:
//    - Prior to recent SDK updates, os.Logger wasn't marked as Sendable
//    - Earlier workarounds included `nonisolated(unsafe)` annotations or global actor isolation
//    - Current implementation (clean static let) is the preferred approach
//    - References for historical context:
//      * https://developer.apple.com/forums/thread/747816 (Is OSLog Logger Sendable?)
//      * https://forums.swift.org/t/logging-and-structured-concurrency-tasklocal/51215
