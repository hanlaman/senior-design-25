//
//  AppError.swift
//  reMIND Watch App
//
//  Standardized error handling protocol and types
//

import Foundation
import os

// MARK: - App Error Protocol

/// Protocol for standardized app errors with logging support
protocol AppError: LocalizedError {
    /// Error domain for categorization
    var domain: String { get }

    /// Error code for programmatic handling
    var code: Int { get }

    /// Logger category for this error type
    var loggerCategory: os.Logger { get }

    /// Context string describing where the error occurred
    var context: String { get }

    /// Whether this error is recoverable
    var isRecoverable: Bool { get }
}

extension AppError {
    /// Log this error using the appropriate logger
    func log() {
        AppLogger.logError(self, category: loggerCategory, context: context)
    }

    /// Create NSError representation
    var asNSError: NSError {
        NSError(
            domain: domain,
            code: code,
            userInfo: [NSLocalizedDescriptionKey: errorDescription ?? "Unknown error"]
        )
    }
}

// MARK: - Voice Connection Errors

/// Errors related to voice connection and session management
enum VoiceConnectionError: AppError {
    case configurationInvalid(String)
    case connectionFailed(underlying: Error)
    case sessionNotEstablished
    case sessionIdMissing
    case disconnectionFailed(underlying: Error)

    var domain: String { "VoiceConnection" }

    var code: Int {
        switch self {
        case .configurationInvalid: return 1001
        case .connectionFailed: return 1002
        case .sessionNotEstablished: return 1003
        case .sessionIdMissing: return 1004
        case .disconnectionFailed: return 1005
        }
    }

    var loggerCategory: os.Logger { AppLogger.network }

    var context: String {
        switch self {
        case .configurationInvalid: return "Azure configuration validation"
        case .connectionFailed: return "WebSocket connection"
        case .sessionNotEstablished: return "Session establishment"
        case .sessionIdMissing: return "Session ID retrieval"
        case .disconnectionFailed: return "Disconnection"
        }
    }

    var isRecoverable: Bool {
        switch self {
        case .configurationInvalid: return false
        case .connectionFailed: return true
        case .sessionNotEstablished: return true
        case .sessionIdMissing: return true
        case .disconnectionFailed: return true
        }
    }

    var errorDescription: String? {
        switch self {
        case .configurationInvalid(let message):
            return "Invalid configuration: \(message)"
        case .connectionFailed(let error):
            return "Connection failed: \(error.localizedDescription)"
        case .sessionNotEstablished:
            return "Voice session could not be established"
        case .sessionIdMissing:
            return "Session ID not available"
        case .disconnectionFailed(let error):
            return "Disconnection failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Audio Errors

/// Errors related to audio capture and playback
enum AudioError: AppError {
    case invalidFormat
    case conversionFailed
    case captureNotStarted
    case engineStartFailed(underlying: Error)
    case sessionActivationFailed(underlying: Error)
    case playbackFailed(underlying: Error)

    var domain: String { "Audio" }

    var code: Int {
        switch self {
        case .invalidFormat: return 2001
        case .conversionFailed: return 2002
        case .captureNotStarted: return 2003
        case .engineStartFailed: return 2004
        case .sessionActivationFailed: return 2005
        case .playbackFailed: return 2006
        }
    }

    var loggerCategory: os.Logger { AppLogger.audio }

    var context: String {
        switch self {
        case .invalidFormat: return "Audio format validation"
        case .conversionFailed: return "Audio conversion"
        case .captureNotStarted: return "Audio capture start"
        case .engineStartFailed: return "Audio engine start"
        case .sessionActivationFailed: return "Audio session activation"
        case .playbackFailed: return "Audio playback"
        }
    }

    var isRecoverable: Bool {
        switch self {
        case .invalidFormat: return false
        case .conversionFailed: return true
        case .captureNotStarted: return true
        case .engineStartFailed: return true
        case .sessionActivationFailed: return true
        case .playbackFailed: return true
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid audio format"
        case .conversionFailed:
            return "Audio conversion failed"
        case .captureNotStarted:
            return "Audio capture not started"
        case .engineStartFailed(let error):
            return "Failed to start audio engine: \(error.localizedDescription)"
        case .sessionActivationFailed(let error):
            return "Failed to activate audio session: \(error.localizedDescription)"
        case .playbackFailed(let error):
            return "Audio playback failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Tool Execution Errors

/// Errors related to function/tool execution
enum ToolExecutionError: AppError {
    case toolNotFound(name: String)
    case invalidArguments(details: String)
    case executionFailed(underlying: Error)
    case responseEncodingFailed

    var domain: String { "ToolExecution" }

    var code: Int {
        switch self {
        case .toolNotFound: return 3001
        case .invalidArguments: return 3002
        case .executionFailed: return 3003
        case .responseEncodingFailed: return 3004
        }
    }

    var loggerCategory: os.Logger { AppLogger.azure }

    var context: String {
        switch self {
        case .toolNotFound: return "Tool lookup"
        case .invalidArguments: return "Argument parsing"
        case .executionFailed: return "Tool execution"
        case .responseEncodingFailed: return "Response encoding"
        }
    }

    var isRecoverable: Bool {
        switch self {
        case .toolNotFound: return false
        case .invalidArguments: return false
        case .executionFailed: return true
        case .responseEncodingFailed: return true
        }
    }

    var errorDescription: String? {
        switch self {
        case .toolNotFound(let name):
            return "Tool not found: \(name)"
        case .invalidArguments(let details):
            return "Invalid arguments: \(details)"
        case .executionFailed(let error):
            return "Tool execution failed: \(error.localizedDescription)"
        case .responseEncodingFailed:
            return "Failed to encode tool response"
        }
    }
}

// MARK: - Settings Errors

/// Errors related to settings management
enum SettingsError: AppError {
    case encodingFailed(underlying: Error)
    case decodingFailed(underlying: Error)
    case syncFailed(underlying: Error)
    case invalidValue(field: String, reason: String)

    var domain: String { "Settings" }

    var code: Int {
        switch self {
        case .encodingFailed: return 4001
        case .decodingFailed: return 4002
        case .syncFailed: return 4003
        case .invalidValue: return 4004
        }
    }

    var loggerCategory: os.Logger { AppLogger.general }

    var context: String {
        switch self {
        case .encodingFailed: return "Settings encoding"
        case .decodingFailed: return "Settings decoding"
        case .syncFailed: return "Settings synchronization"
        case .invalidValue: return "Settings validation"
        }
    }

    var isRecoverable: Bool { true }

    var errorDescription: String? {
        switch self {
        case .encodingFailed(let error):
            return "Failed to encode settings: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode settings: \(error.localizedDescription)"
        case .syncFailed(let error):
            return "Failed to sync settings: \(error.localizedDescription)"
        case .invalidValue(let field, let reason):
            return "Invalid value for \(field): \(reason)"
        }
    }
}

// MARK: - Error Result Extension

extension Result where Failure: AppError {
    /// Log the error if this result is a failure
    func logIfFailure() {
        if case .failure(let error) = self {
            error.log()
        }
    }
}
