//
//  AudioService.swift
//  reMIND Watch App
//
//  Audio capture and playback service using AVAudioEngine
//

import Foundation
import AVFoundation
import os

/// Audio service implementation using AVAudioEngine
actor AudioService: AudioServiceProtocol {
    // MARK: - Properties

    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let bufferManager = AudioBufferManager()
    private let sessionManager = AudioSessionManager()

    private(set) var isCapturing = false
    private(set) var isPlaying = false
    private var isEngineRunning = false

    private var audioFormat: AVAudioFormat?

    // Buffer tracking with UUID tokens (prevents race conditions)
    private var activeBuffers: Set<UUID> = []

    // Public accessor for active buffer count
    var activeBufferCount: Int {
        activeBuffers.count
    }

    // Session timeout configuration
    private let sessionTimeoutSeconds: TimeInterval = AudioConfiguration.sessionTimeout
    private var sessionTimeoutTask: Task<Void, Never>?

    // When true, prevents audio session deactivation (held during WebSocket lifetime on watchOS)
    private var sessionHeld = false

    // Audio chunk stream (recreated each capture session)
    private var chunkContinuation: AsyncStream<Data>.Continuation?
    private(set) var audioChunkStream: AsyncStream<Data>

    // Playback state stream
    private var playbackStateContinuation: AsyncStream<Bool>.Continuation?
    let playbackStateStream: AsyncStream<Bool>

    // Buffer overflow stream
    var bufferOverflowStream: AsyncStream<BufferOverflowEvent> {
        bufferManager.overflowStream
    }

    // Buffer event stream (for progress tracking)
    private var bufferEventContinuation: AsyncStream<BufferEvent>.Continuation?
    let bufferEventStream: AsyncStream<BufferEvent>

    // MARK: - Initialization

    init() {
        // Create audio chunk stream using makeStream for guaranteed synchronous delivery
        let (chunkStream, chunkCont) = AsyncStream<Data>.makeStream()
        self.audioChunkStream = chunkStream
        self.chunkContinuation = chunkCont

        // Create playback state stream
        let (stateStream, stateCont) = AsyncStream<Bool>.makeStream()
        self.playbackStateStream = stateStream
        self.playbackStateContinuation = stateCont

        // Create buffer event stream (for progress tracking)
        let (bufferStream, bufferCont) = AsyncStream<BufferEvent>.makeStream()
        self.bufferEventStream = bufferStream
        self.bufferEventContinuation = bufferCont

        // Set up session manager callbacks
        sessionManager.onInterruptionBegan = { [weak self] in
            await self?.handleInterruptionBegan()
        }

        sessionManager.onInterruptionEnded = { [weak self] shouldResume in
            await self?.handleInterruptionEnded(shouldResume: shouldResume)
        }

        sessionManager.onRouteChange = { [weak self] reason in
            await self?.handleRouteChange(reason)
        }
    }

    // MARK: - Playback State Management

    private func setPlayingState(_ playing: Bool) {
        isPlaying = playing
        playbackStateContinuation?.yield(playing)
    }

    // MARK: - Audio Chunk Stream Management

    /// Reset the audio chunk stream for a new capture session
    /// AsyncStream can only be iterated once, so we create a fresh one each time
    private func resetAudioChunkStream() {
        // Finish the old continuation if it exists (safe to call multiple times)
        chunkContinuation?.finish()
        chunkContinuation = nil

        // Create new stream using makeStream for guaranteed synchronous continuation delivery
        // This is safer than the closure-based pattern which can have timing issues
        let (stream, continuation) = AsyncStream<Data>.makeStream()
        self.audioChunkStream = stream
        self.chunkContinuation = continuation

        AppLogger.audio.debug("Audio chunk stream reset for new capture session")
    }

    // MARK: - Audio Session Configuration (delegated to AudioSessionManager)

    /// Activate the audio session without starting capture.
    /// On watchOS, this must be called before opening a WebSocket connection
    /// because the WebSocket connection requires an active AVAudioSession.
    func activateSession() throws {
        try configureAudioSession()
    }

    /// Hold the audio session active for the lifetime of the WebSocket connection.
    /// While held, stopPlayback() and session timeouts will not deactivate it.
    func holdSession() {
        sessionHeld = true
        AppLogger.audio.info("Audio session held (WebSocket lifetime)")
    }

    /// Release the audio session hold and deactivate if idle.
    func releaseSession() {
        sessionHeld = false
        AppLogger.audio.info("Audio session hold released")
        if !isCapturing && !isPlaying {
            stopEngineIfNeeded()
            deactivateAudioSession()
        }
    }

    private func configureAudioSession() throws {
        try sessionManager.activate()
    }

    private func deactivateAudioSession() {
        guard !sessionHeld else {
            AppLogger.audio.debug("Audio session deactivation skipped (session held)")
            return
        }
        sessionManager.deactivate()
    }

    // MARK: - Session Event Handlers (called by AudioSessionManager callbacks)

    private func handleRouteChange(_ reason: AVAudioSession.RouteChangeReason) async {
        let audioSession = AVAudioSession.sharedInstance()
        let currentRoute = audioSession.currentRoute

        switch reason {
        case .newDeviceAvailable:
            AppLogger.audio.debug("Audio route: New device available")
            if let newDevice = currentRoute.inputs.first {
                AppLogger.audio.debug("New input device: \(newDevice.portName) (\(newDevice.portType.rawValue))")
            }

        case .oldDeviceUnavailable:
            AppLogger.audio.warning("Audio route: Device disconnected")
            if isCapturing || isPlaying {
                AppLogger.audio.debug("Audio session affected by route change")
            }

        case .categoryChange:
            AppLogger.audio.debug("Audio route: Category changed")

        case .override:
            AppLogger.audio.debug("Audio route: Override")

        case .wakeFromSleep:
            AppLogger.audio.debug("Audio route: Wake from sleep")

        case .noSuitableRouteForCategory:
            AppLogger.audio.warning("Audio route: No suitable route for category")

        case .routeConfigurationChange:
            AppLogger.audio.debug("Audio route: Configuration change")

        @unknown default:
            AppLogger.audio.warning("Audio route: Unknown reason")
        }
    }

    private func handleInterruptionBegan() async {
        // Stop any active playback
        if isPlaying {
            playerNode.stop()
            setPlayingState(false)
            activeBuffers.removeAll()
            await bufferManager.clearPlaybackBuffer()
        }

        // Stop any active capture
        if isCapturing {
            audioEngine.inputNode.removeTap(onBus: 0)
            isCapturing = false
            await bufferManager.clearCaptureBuffer()
        }

        // Stop engine
        if isEngineRunning {
            audioEngine.stop()
            isEngineRunning = false
        }
    }

    private func handleInterruptionEnded(shouldResume: Bool) async {
        if shouldResume {
            // Try to reactivate audio session via session manager
            do {
                try sessionManager.reactivate()

                // Restart audio engine if it was running before interruption
                if (isCapturing || isPlaying) && !isEngineRunning {
                    try startEngineIfNeeded()
                    AppLogger.audio.debug("Audio engine restarted after interruption")
                }
            } catch {
                AppLogger.logError(error, category: AppLogger.audio, context: "Failed to reactivate audio session after interruption")
            }
        }
    }

    // MARK: - Audio Capture

    func startCapture() async throws {
        guard !isCapturing else {
            AppLogger.audio.warning("Already capturing audio")
            return
        }

        AppLogger.audio.info("Starting audio capture")

        // Request microphone permission before proceeding
        let permissionGranted: Bool
        if #available(watchOS 10.0, *) {
            permissionGranted = await AVAudioApplication.requestRecordPermission()
        } else {
            permissionGranted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }

        guard permissionGranted else {
            AppLogger.audio.error("Microphone permission denied")
            throw AudioServiceError.microphonePermissionDenied
        }

        // Create fresh audio chunk stream for this capture session
        // AsyncStream can only be iterated once, so we need a new one each time
        resetAudioChunkStream()

        // Configure audio session
        try configureAudioSession()

        // Get Azure audio format
        guard let targetFormat = AudioConfiguration.audioFormat else {
            throw AudioServiceError.invalidFormat
        }

        audioFormat = targetFormat

        // Get input node
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        AppLogger.audio.debug("Input format: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount) channels")
        AppLogger.audio.debug("Target format: \(targetFormat.sampleRate)Hz, \(targetFormat.channelCount) channels")

        // Create audio converter if formats don't match
        let converter = AVAudioConverter(from: inputFormat, to: targetFormat)

        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: AudioConfiguration.framesPerChunk, format: inputFormat) { [weak self] buffer, time in
            Task {
                await self?.processCapturedAudio(buffer: buffer, converter: converter, targetFormat: targetFormat)
            }
        }

        // Attach player node for playback if not already attached
        if !audioEngine.attachedNodes.contains(playerNode) {
            audioEngine.attach(playerNode)
            audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: targetFormat)
        }

        // Start audio engine
        try startEngineIfNeeded()

        isCapturing = true
        AppLogger.audio.info("Audio capture started")
    }

    func stopCapture() async {
        guard isCapturing else { return }

        AppLogger.audio.info("Stopping audio capture")

        // Remove tap
        audioEngine.inputNode.removeTap(onBus: 0)

        isCapturing = false

        // Note: Don't finish the continuation here - let resetAudioChunkStream() handle it
        // when a new capture session starts. This avoids race conditions with the for-await loop.

        // Clear capture buffer
        await bufferManager.clearCaptureBuffer()

        // Start timeout to cleanup if no playback occurs
        startSessionTimeout()

        AppLogger.audio.info("Audio capture stopped, session will timeout in \(self.sessionTimeoutSeconds)s if no playback")
    }

    private func processCapturedAudio(buffer: AVAudioPCMBuffer, converter: AVAudioConverter?, targetFormat: AVAudioFormat) async {
        // Convert to target format if needed
        let processedBuffer: AVAudioPCMBuffer
        if let converter = converter {
            guard let converted = AudioConverter.convert(buffer: buffer, to: targetFormat) else {
                AppLogger.audio.error("Failed to convert audio format")
                return
            }
            processedBuffer = converted
        } else {
            processedBuffer = buffer
        }

        // Convert buffer to data
        guard let audioData = AudioConverter.bufferToData(processedBuffer) else {
            AppLogger.audio.error("Failed to convert buffer to data")
            return
        }

        // Chunk audio data
        let chunks = AudioConverter.chunk(data: audioData, chunkSize: AudioConfiguration.bytesPerChunk)

        // Send chunks to stream
        for chunk in chunks {
            await bufferManager.addToCaptureBuffer(chunk)
            chunkContinuation?.yield(chunk)
        }

        // Audio captured successfully (reduced logging)
    }

    // MARK: - Audio Playback

    func playAudio(_ data: Data) async throws {
        guard let format = audioFormat ?? AudioConfiguration.audioFormat else {
            throw AudioServiceError.invalidFormat
        }

        // Log entry state for debugging intermittent playback issues
        AppLogger.audio.debug("playAudio called: isPlaying=\(self.isPlaying), isEngineRunning=\(self.isEngineRunning), activeBuffers=\(self.activeBuffers.count)")

        // Cancel session timeout since playback is starting
        cancelSessionTimeout()

        // Convert data to buffer
        guard let buffer = AudioConverter.dataToBuffer(data, format: format) else {
            throw AudioServiceError.conversionFailed
        }

        // Ensure audio session is active
        if !isCapturing {
            try configureAudioSession()
        }

        // Attach and connect player node if not already attached
        if !audioEngine.attachedNodes.contains(playerNode) {
            audioEngine.attach(playerNode)
            audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
            AppLogger.audio.info("Player node attached and connected to mixer")
        }

        // Start audio engine if needed
        try startEngineIfNeeded()

        // Start player node if not already playing
        if !isPlaying {
            playerNode.play()
            setPlayingState(true)
            AppLogger.audio.info("Player node started")
        } else {
            AppLogger.audio.debug("Player node already playing (isPlaying=true)")
        }

        // Schedule buffer for playback with UUID token
        let bufferID = UUID()
        activeBuffers.insert(bufferID)

        // Emit scheduled event for progress tracking
        bufferEventContinuation?.yield(.scheduled(bufferID))

        playerNode.scheduleBuffer(buffer) { [weak self, bufferID] in
            Task {
                await self?.handleBufferComplete(bufferID)
            }
        }

        await bufferManager.addToPlaybackBuffer(data)

        AppLogger.audio.debug("Scheduled buffer \(bufferID) - \(self.activeBuffers.count) active buffers")
    }

    func stopPlayback() async {
        guard isPlaying else { return }

        AppLogger.audio.info("Stopping audio playback")

        playerNode.stop()
        setPlayingState(false)

        // Clear active buffers
        activeBuffers.removeAll()

        await bufferManager.clearPlaybackBuffer()

        // Stop engine and deactivate audio session if not capturing
        if !isCapturing {
            stopEngineIfNeeded()
            deactivateAudioSession()
        }
    }

    private func handleBufferComplete(_ bufferID: UUID) async {
        activeBuffers.remove(bufferID)

        // Emit completed event for progress tracking
        bufferEventContinuation?.yield(.completed(bufferID))

        AppLogger.audio.debug("Buffer \(bufferID) completed - \(self.activeBuffers.count) remaining")

        await handlePlaybackComplete()
    }

    private func handlePlaybackComplete() async {
        // Check if all buffers have completed AND we're still in playing state
        // (stopPlayback may have already set isPlaying=false and cleared buffers)
        if activeBuffers.isEmpty && isPlaying {
            AppLogger.audio.info("Audio playback complete - all buffers finished")
            setPlayingState(false)

            // Keep engine and session active for subsequent playback
            // Only deactivate if explicitly stopped or disconnected
        }
    }

    // MARK: - Audio Engine Management

    private func startEngineIfNeeded() throws {
        guard !isEngineRunning else {
            AppLogger.audio.debug("Audio engine already running")
            return
        }

        do {
            try audioEngine.start()
            isEngineRunning = true
            AppLogger.audio.info("Audio engine started")
        } catch {
            AppLogger.logError(error, category: AppLogger.audio, context: "Failed to start audio engine")
            throw AudioServiceError.engineStartFailed(error)
        }
    }

    private func stopEngineIfNeeded() {
        guard isEngineRunning else {
            AppLogger.audio.debug("Audio engine not running")
            return
        }

        audioEngine.stop()
        isEngineRunning = false
        AppLogger.audio.info("Audio engine stopped")
    }

    // MARK: - Session Timeout Management

    private func startSessionTimeout() {
        cancelSessionTimeout()

        sessionTimeoutTask = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(10.0 * 1_000_000_000))

                await self.checkAndCleanupSession()
            } catch {
                AppLogger.audio.debug("Session timeout cancelled")
            }
        }
    }

    private func checkAndCleanupSession() {
        if !isCapturing && !isPlaying {
            AppLogger.audio.info("Session timeout expired, cleaning up audio resources")
            stopEngineIfNeeded()
            deactivateAudioSession()
        } else {
            AppLogger.audio.debug("Session timeout expired but audio is active")
        }
    }

    private func cancelSessionTimeout() {
        sessionTimeoutTask?.cancel()
        sessionTimeoutTask = nil
    }
}

// MARK: - Errors

enum AudioServiceError: LocalizedError {
    case invalidFormat
    case conversionFailed
    case captureNotStarted
    case engineStartFailed(Error)
    case microphonePermissionDenied

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
        case .microphonePermissionDenied:
            return "Microphone permission was denied. Please enable it in Settings."
        }
    }
}

