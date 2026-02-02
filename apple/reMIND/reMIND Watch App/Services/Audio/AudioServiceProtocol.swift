//
//  AudioServiceProtocol.swift
//  reMIND Watch App
//
//  Protocol definition for audio service
//

import Foundation
import AVFoundation

/// Protocol for audio capture and playback service
protocol AudioServiceProtocol: Actor {
    /// Audio chunk stream (captured audio ready for transmission)
    var audioChunkStream: AsyncStream<Data> { get }

    /// Playback state stream (emits true when playback starts, false when it ends)
    var playbackStateStream: AsyncStream<Bool> { get }

    /// Start capturing audio from microphone
    func startCapture() async throws

    /// Stop capturing audio
    func stopCapture() async

    /// Play audio data (PCM16)
    func playAudio(_ data: Data) async throws

    /// Stop audio playback
    func stopPlayback() async

    /// Check if currently capturing
    var isCapturing: Bool { get }

    /// Check if currently playing
    var isPlaying: Bool { get }
}
