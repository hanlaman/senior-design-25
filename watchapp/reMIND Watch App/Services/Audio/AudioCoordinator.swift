//
//  AudioCoordinator.swift
//  reMIND Watch App
//
//  Coordinates audio capture, playback monitoring, and buffer overflow detection
//  Extracted from VoiceViewModel to reduce complexity and improve testability
//

import Foundation
import os

/// Delegate protocol for audio coordinator callbacks
@MainActor
protocol AudioCoordinatorDelegate: AnyObject {
    /// Called when playback state changes
    /// - Parameters:
    ///   - isPlaying: Whether audio is currently playing
    ///   - bufferCount: Number of active audio buffers queued
    func audioCoordinator(
        _ coordinator: AudioCoordinator,
        didChangePlaybackState isPlaying: Bool,
        bufferCount: Int
    )

    /// Called when buffer overflow is detected
    /// - Parameter event: The overflow event details
    func audioCoordinator(
        _ coordinator: AudioCoordinator,
        didDetectOverflow event: BufferOverflowEvent
    )

    /// Called when playback progress updates
    /// - Parameter progress: Progress from 0.0 (complete) to 1.0 (just started)
    func audioCoordinator(
        _ coordinator: AudioCoordinator,
        didUpdateProgress progress: Double
    )

    /// Get current session ID for state transitions
    var sessionId: String? { get }
}

/// Coordinates audio capture, playback, and monitoring lifecycle
@MainActor
class AudioCoordinator {
    // MARK: - Properties

    weak var delegate: AudioCoordinatorDelegate?

    private let audioService: AudioService
    private let azureService: VoiceLiveConnection

    // Background tasks (using enum keys for type-safe access)
    private enum TaskKey: CaseIterable {
        case audioState
        case bufferOverflow
        case audioChunk
        case bufferEvent
    }
    private var tasks: [TaskKey: Task<Void, Never>] = [:]

    // Audio processing flag (prevents concurrent chunk processing)
    private var isProcessingAudio = false

    // Progress tracking
    private var totalBuffersScheduled: Int = 0
    private var buffersCompleted: Int = 0

    // MARK: - Initialization

    init(audioService: AudioService, azureService: VoiceLiveConnection) {
        self.audioService = audioService
        self.azureService = azureService
    }

    // MARK: - Monitoring Lifecycle

    /// Start all audio monitoring tasks
    func startMonitoring() {
        startAudioStateMonitoring()
        startBufferOverflowMonitoring()
        startBufferEventMonitoring()
    }

    /// Stop all audio monitoring tasks
    func stopMonitoring() {
        cancelAllTasks()
        isProcessingAudio = false
        resetProgressTracking()
        AppLogger.general.debug("Audio monitoring stopped")
    }

    /// Cancel all running tasks
    private func cancelAllTasks() {
        for (_, task) in tasks {
            task.cancel()
        }
        tasks.removeAll()
    }

    /// Cancel a specific task
    private func cancelTask(_ key: TaskKey) {
        tasks[key]?.cancel()
        tasks[key] = nil
    }

    /// Reset progress tracking for new playback session
    func resetProgressTracking() {
        totalBuffersScheduled = 0
        buffersCompleted = 0
    }

    // MARK: - Audio Chunk Processing

    /// Start processing audio chunks from microphone to Azure
    func startProcessingAudioChunks() async {
        guard !isProcessingAudio else {
            AppLogger.audio.debug("Audio chunk processing already active")
            return
        }

        cancelTask(.audioChunk)

        tasks[.audioChunk] = Task { @MainActor [weak self] in
            guard let self = self else { return }

            self.isProcessingAudio = true
            AppLogger.audio.debug("Started audio chunk processing")

            for await chunk in await self.audioService.audioChunkStream {
                // Check if we should continue processing
                // The delegate will determine if recording is active
                guard !Task.isCancelled else {
                    AppLogger.audio.debug("Audio chunk processing cancelled")
                    break
                }

                do {
                    try await self.azureService.inputAudioBuffer.append(chunk)
                } catch {
                    AppLogger.logError(error, category: AppLogger.audio, context: "Failed to send audio chunk")
                }
            }

            self.isProcessingAudio = false
            AppLogger.audio.debug("Audio chunk processing completed")
        }
    }

    /// Stop processing audio chunks
    func stopProcessingAudioChunks() async {
        cancelTask(.audioChunk)
        isProcessingAudio = false
        AppLogger.audio.debug("Stopped audio chunk processing")
    }

    // MARK: - Private Monitoring Methods

    /// Start monitoring audio playback state changes
    private func startAudioStateMonitoring() {
        cancelTask(.audioState)

        AppLogger.general.debug("Starting audio state observation")

        tasks[.audioState] = Task { @MainActor [weak self] in
            guard let self = self else { return }

            for await isPlaying in await self.audioService.playbackStateStream {
                guard let delegate = self.delegate else { continue }

                // Get current session ID
                guard let sessionId = delegate.sessionId else {
                    AppLogger.general.warning("No session ID during audio state change")
                    continue
                }

                // Get buffer count for state transition
                let bufferCount = await self.audioService.activeBufferCount

                // Notify delegate of playback state change
                delegate.audioCoordinator(
                    self,
                    didChangePlaybackState: isPlaying,
                    bufferCount: bufferCount
                )

                if isPlaying {
                    AppLogger.general.info("Voice state: playing")
                } else {
                    AppLogger.general.info("Voice state: idle")
                }
            }

            AppLogger.general.debug("Audio state observation ended")
        }
    }

    /// Start monitoring buffer overflow events
    private func startBufferOverflowMonitoring() {
        cancelTask(.bufferOverflow)

        AppLogger.general.debug("Starting buffer overflow monitoring")

        tasks[.bufferOverflow] = Task { @MainActor [weak self] in
            guard let self = self else { return }

            for await event in await self.audioService.bufferOverflowStream {
                guard let delegate = self.delegate else { continue }

                // Log overflow event
                switch event {
                case .captureOverflow(let droppedChunks, let bufferSize):
                    AppLogger.audio.warning("Capture buffer overflow: dropped \(droppedChunks) chunks (max: \(bufferSize))")

                case .playbackOverflow(let droppedChunks, let bufferSize):
                    AppLogger.audio.warning("Playback buffer overflow: dropped \(droppedChunks) chunks (max: \(bufferSize))")
                }

                // Notify delegate
                delegate.audioCoordinator(self, didDetectOverflow: event)
            }

            AppLogger.general.debug("Buffer overflow monitoring ended")
        }
    }

    /// Start monitoring buffer events for progress tracking
    private func startBufferEventMonitoring() {
        cancelTask(.bufferEvent)

        AppLogger.general.debug("Starting buffer event monitoring for progress tracking")

        tasks[.bufferEvent] = Task { @MainActor [weak self] in
            guard let self = self else { return }

            for await event in await self.audioService.bufferEventStream {
                guard let delegate = self.delegate else { continue }

                switch event {
                case .scheduled:
                    self.totalBuffersScheduled += 1
                case .completed:
                    self.buffersCompleted += 1
                }

                // Calculate and report progress
                // Progress = remaining / total (1.0 = just started, 0.0 = complete)
                if self.totalBuffersScheduled > 0 {
                    let remaining = self.totalBuffersScheduled - self.buffersCompleted
                    let progress = Double(remaining) / Double(self.totalBuffersScheduled)
                    delegate.audioCoordinator(self, didUpdateProgress: max(0, progress))
                }
            }

            AppLogger.general.debug("Buffer event monitoring ended")
        }
    }
}
