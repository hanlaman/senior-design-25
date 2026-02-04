//
//  AudioBufferManager.swift
//  reMIND Watch App
//
//  Thread-safe audio buffer management using actors
//

import Foundation
import AVFoundation
import os

/// Actor-based thread-safe audio buffer manager
actor AudioBufferManager {
    // MARK: - Properties

    private var captureBuffer: [Data] = []
    private var playbackBuffers: [Data] = []

    private let maxCaptureBufferSize = 100 // ~10 seconds at 100ms chunks
    private let maxPlaybackBufferSize = 50 // ~5 seconds at 100ms chunks

    // MARK: - Capture Buffer Management

    /// Add audio data to capture buffer
    func addToCaptureBuffer(_ data: Data) {
        captureBuffer.append(data)

        // Prevent buffer overflow
        if captureBuffer.count > maxCaptureBufferSize {
            let excess = captureBuffer.count - maxCaptureBufferSize
            captureBuffer.removeFirst(excess)
            AppLogger.audio.warning("Capture buffer overflow, removed \(excess) chunks")
        }
    }

    /// Get and clear all captured audio data
    func drainCaptureBuffer() -> [Data] {
        let data = captureBuffer
        captureBuffer.removeAll()
        return data
    }

    /// Clear capture buffer
    func clearCaptureBuffer() {
        let count = captureBuffer.count
        captureBuffer.removeAll()
        AppLogger.audio.debug("Cleared capture buffer: \(count) chunks")
    }

    /// Get capture buffer size
    func getCaptureBufferSize() -> Int {
        captureBuffer.count
    }

    // MARK: - Playback Buffer Management

    /// Add audio data to playback buffer
    func addToPlaybackBuffer(_ data: Data) {
        playbackBuffers.append(data)

        // Prevent buffer overflow
        if playbackBuffers.count > maxPlaybackBufferSize {
            let excess = playbackBuffers.count - maxPlaybackBufferSize
            playbackBuffers.removeFirst(excess)
            AppLogger.audio.warning("Playback buffer overflow, removed \(excess) chunks")
        }
    }

    /// Get next playback buffer
    func getNextPlaybackBuffer() -> Data? {
        guard !playbackBuffers.isEmpty else { return nil }
        return playbackBuffers.removeFirst()
    }

    /// Clear playback buffer
    func clearPlaybackBuffer() {
        let count = playbackBuffers.count
        playbackBuffers.removeAll()
        AppLogger.audio.debug("Cleared playback buffer: \(count) chunks")
    }

    /// Get playback buffer size
    func getPlaybackBufferSize() -> Int {
        playbackBuffers.count
    }

    /// Check if playback buffer has data
    func hasPlaybackData() -> Bool {
        !playbackBuffers.isEmpty
    }

    // MARK: - Statistics

    /// Get buffer statistics
    func getStatistics() -> BufferStatistics {
        BufferStatistics(
            captureBufferSize: captureBuffer.count,
            playbackBufferSize: playbackBuffers.count,
            captureBytesBuffered: captureBuffer.reduce(0) { $0 + $1.count },
            playbackBytesBuffered: playbackBuffers.reduce(0) { $0 + $1.count }
        )
    }

    struct BufferStatistics {
        let captureBufferSize: Int
        let playbackBufferSize: Int
        let captureBytesBuffered: Int
        let playbackBytesBuffered: Int
    }
}
