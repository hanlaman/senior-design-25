//
//  AudioServiceProtocol.swift
//  reMIND Watch App
//
//  Protocol definition for audio service
//

import Foundation
import AVFoundation

/// Events for tracking audio buffer lifecycle (for progress tracking)
enum BufferEvent {
    case scheduled(UUID)
    case completed(UUID)
}

/// Protocol for audio capture and playback service
protocol AudioServiceProtocol: Actor {
    /// Audio chunk stream (captured audio ready for transmission)
    var audioChunkStream: AsyncStream<Data> { get }

    /// Playback state stream (emits true when playback starts, false when it ends)
    var playbackStateStream: AsyncStream<Bool> { get }

    /// Buffer overflow stream (emits when buffers overflow)
    var bufferOverflowStream: AsyncStream<BufferOverflowEvent> { get }

    /// Buffer event stream (emits when buffers are scheduled/completed for progress tracking)
    var bufferEventStream: AsyncStream<BufferEvent> { get }

    /// Start capturing audio from microphone
    func startCapture() async throws

    /// Stop capturing audio
    func stopCapture() async

    /// Play audio data (PCM16)
    func playAudio(_ data: Data) async throws

    /// Stop audio playback
    func stopPlayback() async

    /// Activate the audio session without starting capture (required before WebSocket on watchOS)
    func activateSession() throws

    /// Hold the audio session active for the WebSocket connection lifetime
    func holdSession()

    /// Release the audio session hold and deactivate if idle
    func releaseSession()

    /// Check if currently capturing
    var isCapturing: Bool { get }

    /// Check if currently playing
    var isPlaying: Bool { get }

    /// Number of active audio buffers currently queued for playback
    var activeBufferCount: Int { get async }
}
