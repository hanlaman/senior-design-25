//
//  InputAudioBuffer.swift
//  reMIND Watch App
//
//  Input audio buffer management for Azure Voice Live
//

import Foundation
import os

/// Manages input audio buffer for Azure Voice Live
public final class InputAudioBuffer {
    // MARK: - Properties

    private unowned let connection: VoiceLiveConnection

    // Audio buffer tracking
    private var bufferBytes: Int = 0
    private var bufferChunks: Int = 0

    // MARK: - Initialization

    init(connection: VoiceLiveConnection) {
        self.connection = connection
    }

    // MARK: - Audio Buffer Management

    /// Append audio data to the input buffer
    /// - Parameter audioData: PCM16 audio data to append
    /// - Throws: `AzureError` if not connected or session not ready
    public func append(_ audioData: Data) async throws {
        guard await connection.connectionState == .connected else {
            throw AzureError.notConnected
        }

        guard await connection.sessionState.canAcceptAudio else {
            throw AzureError.sessionNotReady
        }

        // Track buffer statistics
        bufferBytes += audioData.count
        bufferChunks += 1

        // Base64 encode audio data (Azure requires text messages)
        let base64Audio = audioData.base64EncodedString()

        let event = InputAudioBufferAppendEvent(audio: base64Audio)
        try await connection.sendEvent(event)
    }

    /// Commit the audio buffer, creating a user message in the conversation
    /// - Throws: `AzureError` if not connected, session not ready, or buffer too small
    public func commit() async throws {
        guard await connection.connectionState == .connected else {
            throw AzureError.notConnected
        }

        guard await connection.sessionState.canAcceptAudio else {
            throw AzureError.sessionNotReady
        }

        // Get buffer statistics
        let stats = statistics

        // Validate minimum buffer size (100ms required by Azure)
        let minimumMs: Double = 100.0
        if stats.durationMs < minimumMs {
            AppLogger.azure.error("Audio buffer too small: \(stats.durationMs)ms (minimum: \(minimumMs)ms), \(stats.bytes) bytes, \(stats.chunks) chunks")
            throw AzureError.bufferTooSmall(durationMs: stats.durationMs, bytes: stats.bytes, minimumMs: minimumMs)
        }

        AppLogger.azure.info("Committing audio buffer: \(stats.durationMs)ms, \(stats.bytes) bytes, \(stats.chunks) chunks")

        let event = InputAudioBufferCommitEvent()
        try await connection.sendEvent(event)
    }

    /// Clear the audio buffer
    /// - Throws: `AzureError` if not connected
    public func clear() async throws {
        guard await connection.connectionState == .connected else {
            throw AzureError.notConnected
        }

        AppLogger.azure.info("Clearing audio buffer")

        // Reset tracking
        bufferBytes = 0
        bufferChunks = 0

        let event = InputAudioBufferClearEvent()
        try await connection.sendEvent(event)
    }

    // MARK: - Buffer Statistics

    /// Current audio buffer statistics
    public var statistics: AudioBufferStatistics {
        let durationMs = calculateDuration(bytes: bufferBytes)
        return AudioBufferStatistics(
            bytes: bufferBytes,
            chunks: bufferChunks,
            durationMs: durationMs
        )
    }

    /// Reset buffer tracking (called when session becomes ready)
    func resetTracking() {
        bufferBytes = 0
        bufferChunks = 0
    }

    // MARK: - Private Methods

    /// Calculate audio duration in milliseconds from bytes
    /// Assumes PCM16 (16-bit), 24kHz sample rate, mono channel
    private func calculateDuration(bytes: Int) -> Double {
        // PCM16 = 2 bytes per sample
        // 24kHz = 24000 samples per second
        // Duration (seconds) = samples / sample_rate
        // Duration (ms) = (samples / sample_rate) * 1000

        let bytesPerSample = 2
        let sampleRate = 24000.0

        let samples = Double(bytes) / Double(bytesPerSample)
        let durationSeconds = samples / sampleRate
        let durationMs = durationSeconds * 1000.0

        return durationMs
    }
}

// MARK: - Supporting Types

/// Audio buffer statistics
public struct AudioBufferStatistics {
    public let bytes: Int
    public let chunks: Int
    public let durationMs: Double
}
