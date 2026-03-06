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

    // Background tasks
    private var audioStateTask: Task<Void, Never>?
    private var bufferOverflowTask: Task<Void, Never>?
    private var audioChunkTask: Task<Void, Never>?

    // Audio processing flag (prevents concurrent chunk processing)
    private var isProcessingAudio = false

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
    }

    /// Stop all audio monitoring tasks
    func stopMonitoring() {
        // Cancel audio state observation
        audioStateTask?.cancel()
        audioStateTask = nil

        // Cancel buffer overflow monitoring
        bufferOverflowTask?.cancel()
        bufferOverflowTask = nil

        // Cancel audio chunk processing
        audioChunkTask?.cancel()
        audioChunkTask = nil
        isProcessingAudio = false

        AppLogger.general.debug("Audio monitoring stopped")
    }

    // MARK: - Audio Chunk Processing

    /// Start processing audio chunks from microphone to Azure
    func startProcessingAudioChunks() async {
        guard !isProcessingAudio else {
            AppLogger.audio.debug("Audio chunk processing already active")
            return
        }

        audioChunkTask?.cancel()

        audioChunkTask = Task { @MainActor [weak self] in
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
        audioChunkTask?.cancel()
        audioChunkTask = nil
        isProcessingAudio = false
        AppLogger.audio.debug("Stopped audio chunk processing")
    }

    // MARK: - Private Monitoring Methods

    /// Start monitoring audio playback state changes
    private func startAudioStateMonitoring() {
        audioStateTask?.cancel()

        AppLogger.general.debug("Starting audio state observation")

        audioStateTask = Task { @MainActor [weak self] in
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
        bufferOverflowTask?.cancel()

        AppLogger.general.debug("Starting buffer overflow monitoring")

        bufferOverflowTask = Task { @MainActor [weak self] in
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
}
