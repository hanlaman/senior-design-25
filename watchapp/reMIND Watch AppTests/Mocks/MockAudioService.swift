//
//  MockAudioService.swift
//  reMIND Watch AppTests
//
//  Mock implementation of AudioServiceProtocol for testing
//

import Foundation
@testable import reMIND_Watch_App

/// Mock audio service for testing
actor MockAudioService: AudioServiceProtocol {
    // MARK: - Test Control Properties

    /// Whether startCapture has been called
    private(set) var startCaptureCalled = false

    /// Whether stopCapture has been called
    private(set) var stopCaptureCalled = false

    /// Whether playAudio has been called
    private(set) var playAudioCalled = false

    /// Whether stopPlayback has been called
    private(set) var stopPlaybackCalled = false

    /// All audio data passed to playAudio
    private(set) var playedAudioData: [Data] = []

    /// Error to throw when startCapture is called
    var startCaptureError: Error?

    /// Error to throw when playAudio is called
    var playAudioError: Error?

    // MARK: - Protocol Properties

    private(set) var isCapturing = false
    private(set) var isPlaying = false

    private var _activeBufferCount = 0
    var activeBufferCount: Int {
        _activeBufferCount
    }

    // MARK: - Streams

    private var audioChunkContinuation: AsyncStream<Data>.Continuation?
    private(set) var audioChunkStream: AsyncStream<Data>

    private var playbackStateContinuation: AsyncStream<Bool>.Continuation?
    let playbackStateStream: AsyncStream<Bool>

    private var bufferOverflowContinuation: AsyncStream<BufferOverflowEvent>.Continuation?
    let bufferOverflowStream: AsyncStream<BufferOverflowEvent>

    private var bufferEventContinuation: AsyncStream<BufferEvent>.Continuation?
    let bufferEventStream: AsyncStream<BufferEvent>

    // MARK: - Initialization

    init() {
        // Create audio chunk stream
        let (chunkStream, chunkCont) = AsyncStream<Data>.makeStream()
        self.audioChunkStream = chunkStream
        self.audioChunkContinuation = chunkCont

        // Create playback state stream
        let (stateStream, stateCont) = AsyncStream<Bool>.makeStream()
        self.playbackStateStream = stateStream
        self.playbackStateContinuation = stateCont

        // Create buffer overflow stream
        let (overflowStream, overflowCont) = AsyncStream<BufferOverflowEvent>.makeStream()
        self.bufferOverflowStream = overflowStream
        self.bufferOverflowContinuation = overflowCont

        // Create buffer event stream
        let (eventStream, eventCont) = AsyncStream<BufferEvent>.makeStream()
        self.bufferEventStream = eventStream
        self.bufferEventContinuation = eventCont
    }

    // MARK: - Protocol Methods

    func startCapture() async throws {
        startCaptureCalled = true

        if let error = startCaptureError {
            throw error
        }

        isCapturing = true
    }

    func stopCapture() async {
        stopCaptureCalled = true
        isCapturing = false
    }

    func playAudio(_ data: Data) async throws {
        playAudioCalled = true
        playedAudioData.append(data)

        if let error = playAudioError {
            throw error
        }

        _activeBufferCount += 1

        if !isPlaying {
            isPlaying = true
            playbackStateContinuation?.yield(true)
        }
    }

    func stopPlayback() async {
        stopPlaybackCalled = true
        isPlaying = false
        _activeBufferCount = 0
        playbackStateContinuation?.yield(false)
    }

    // MARK: - Test Control Methods

    /// Emit an audio chunk for testing
    func emitAudioChunk(_ data: Data) {
        audioChunkContinuation?.yield(data)
    }

    /// Emit a playback state change for testing
    func emitPlaybackState(_ playing: Bool) {
        isPlaying = playing
        playbackStateContinuation?.yield(playing)
    }

    /// Emit a buffer overflow event for testing
    func emitBufferOverflow(_ event: BufferOverflowEvent) {
        bufferOverflowContinuation?.yield(event)
    }

    /// Emit a buffer event for testing
    func emitBufferEvent(_ event: BufferEvent) {
        bufferEventContinuation?.yield(event)
    }

    /// Simulate buffer completion
    func simulateBufferComplete() {
        _activeBufferCount = max(0, _activeBufferCount - 1)

        if _activeBufferCount == 0 && isPlaying {
            isPlaying = false
            playbackStateContinuation?.yield(false)
        }
    }

    /// Reset all test state
    func reset() {
        startCaptureCalled = false
        stopCaptureCalled = false
        playAudioCalled = false
        stopPlaybackCalled = false
        playedAudioData.removeAll()
        startCaptureError = nil
        playAudioError = nil
        isCapturing = false
        isPlaying = false
        _activeBufferCount = 0
    }

    /// Finish all streams
    func finishStreams() {
        audioChunkContinuation?.finish()
        playbackStateContinuation?.finish()
        bufferOverflowContinuation?.finish()
        bufferEventContinuation?.finish()
    }
}
