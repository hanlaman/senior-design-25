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

    private(set) var isCapturing = false
    private(set) var isPlaying = false
    private var isEngineRunning = false

    private var audioFormat: AVAudioFormat?
    private var scheduledBufferCount = 0
    private var completedBufferCount = 0

    // Audio chunk stream
    private var chunkContinuation: AsyncStream<Data>.Continuation?
    let audioChunkStream: AsyncStream<Data>

    // Playback state stream
    private var playbackStateContinuation: AsyncStream<Bool>.Continuation?
    let playbackStateStream: AsyncStream<Bool>

    // MARK: - Initialization

    init() {
        // Create audio chunk stream
        var continuationHolder: AsyncStream<Data>.Continuation?
        self.audioChunkStream = AsyncStream { continuation in
            continuationHolder = continuation
        }
        self.chunkContinuation = continuationHolder

        // Create playback state stream
        var stateContinuation: AsyncStream<Bool>.Continuation?
        self.playbackStateStream = AsyncStream { continuation in
            stateContinuation = continuation
        }
        self.playbackStateContinuation = stateContinuation
    }

    // MARK: - Playback State Management

    private func setPlayingState(_ playing: Bool) {
        isPlaying = playing
        playbackStateContinuation?.yield(playing)
    }

    // MARK: - Audio Session Configuration

    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()

        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetoothHFP, .allowBluetoothA2DP])
        try audioSession.setActive(true)

        AppLogger.audio.info("Audio session configured: category=playAndRecord, mode=voiceChat")
    }

    private func deactivateAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            AppLogger.audio.info("Audio session deactivated")
        } catch {
            AppLogger.logError(error, category: AppLogger.audio, context: "Failed to deactivate audio session")
        }
    }

    // MARK: - Audio Capture

    func startCapture() async throws {
        guard !isCapturing else {
            AppLogger.audio.warning("Already capturing audio")
            return
        }

        AppLogger.audio.info("Starting audio capture")

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

        AppLogger.audio.info("Input format: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount) channels")
        AppLogger.audio.info("Target format: \(targetFormat.sampleRate)Hz, \(targetFormat.channelCount) channels")

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
        startEngineIfNeeded()

        isCapturing = true
        AppLogger.audio.info("Audio capture started")
    }

    func stopCapture() async {
        guard isCapturing else { return }

        AppLogger.audio.info("Stopping audio capture")

        // Remove tap
        audioEngine.inputNode.removeTap(onBus: 0)

        isCapturing = false

        // Clear capture buffer
        await bufferManager.clearCaptureBuffer()

        // Keep engine and session active for incoming audio response
        // They will be cleaned up on disconnect or explicit stop
        AppLogger.audio.info("Audio capture stopped, keeping engine/session active for response")
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
        }

        // Start audio engine if needed
        startEngineIfNeeded()

        // Start player node if not already playing
        if !isPlaying {
            playerNode.play()
            setPlayingState(true)
        }

        // Schedule buffer for playback
        scheduledBufferCount += 1
        let bufferNum = scheduledBufferCount
        playerNode.scheduleBuffer(buffer) { [weak self] in
            Task {
                await self?.handleBufferComplete(bufferNum: bufferNum)
            }
        }

        await bufferManager.addToPlaybackBuffer(data)
    }

    func stopPlayback() async {
        guard isPlaying else { return }

        AppLogger.audio.info("Stopping audio playback")

        playerNode.stop()
        setPlayingState(false)

        await bufferManager.clearPlaybackBuffer()

        // Stop engine and deactivate audio session if not capturing
        if !isCapturing {
            stopEngineIfNeeded()
            deactivateAudioSession()
        }
    }

    private func handleBufferComplete(bufferNum: Int) async {
        self.completedBufferCount += 1
        await self.handlePlaybackComplete()
    }

    private func handlePlaybackComplete() async {
        // Check if all scheduled buffers have completed
        let allBuffersComplete = (self.completedBufferCount >= self.scheduledBufferCount)

        if allBuffersComplete {
            AppLogger.audio.info("Audio playback complete")
            setPlayingState(false)

            // Reset counters for next playback
            self.scheduledBufferCount = 0
            self.completedBufferCount = 0

            // Keep engine and session active for subsequent playback
            // Only deactivate if explicitly stopped or disconnected
        }
    }

    // MARK: - Audio Engine Management

    private func startEngineIfNeeded() {
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
}

// MARK: - Errors

enum AudioServiceError: LocalizedError {
    case invalidFormat
    case conversionFailed
    case captureNotStarted
    case engineStartFailed(Error)

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
        }
    }
}
