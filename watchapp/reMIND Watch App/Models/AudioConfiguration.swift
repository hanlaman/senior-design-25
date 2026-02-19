//
//  AudioConfiguration.swift
//  reMIND Watch App
//
//  Audio format specifications for Azure Voice Live API
//

import Foundation
import AVFoundation

/// Audio format specifications for Azure Voice Live API
struct AudioConfiguration {
    // MARK: - Audio Format

    /// Sample rate: 24kHz (24000 Hz)
    static let sampleRate: Double = 24000.0

    /// Channels: Mono (1 channel)
    static let channels: UInt32 = 1

    /// Bit depth: 16-bit PCM
    static let bitDepth: UInt32 = 16

    /// Audio format: Linear PCM
    static let formatID = kAudioFormatLinearPCM

    /// Format flags for PCM16
    static let formatFlags: AudioFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked

    /// Bytes per frame: 2 (16-bit = 2 bytes)
    static let bytesPerFrame: UInt32 = 2

    /// Bits per channel: 16
    static let bitsPerChannel: UInt32 = 16

    // MARK: - Chunk Configuration

    /// Chunk duration in milliseconds
    static let chunkDurationMs: Int = 100

    /// Frames per chunk (24000 Hz * 0.1s = 2400 frames)
    static let framesPerChunk: AVAudioFrameCount = AVAudioFrameCount(sampleRate * Double(chunkDurationMs) / 1000.0)

    /// Bytes per chunk (2400 frames * 2 bytes = 4800 bytes)
    static let bytesPerChunk: Int = Int(framesPerChunk) * Int(bytesPerFrame)

    // MARK: - Audio Format Creation

    /// Create AVAudioFormat for capture/playback
    static var audioFormat: AVAudioFormat? {
        AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: true
        )
    }

    /// Create AudioStreamBasicDescription for low-level audio
    static var audioStreamBasicDescription: AudioStreamBasicDescription {
        AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: formatID,
            mFormatFlags: formatFlags,
            mBytesPerPacket: bytesPerFrame,
            mFramesPerPacket: 1,
            mBytesPerFrame: bytesPerFrame,
            mChannelsPerFrame: channels,
            mBitsPerChannel: bitsPerChannel,
            mReserved: 0
        )
    }
}

/// Azure Voice Live session configuration
struct AzureSessionConfiguration: Codable {
    var modalities: [String] = ["text", "audio"]
    var instructions: String?
    var voice: String?
    var inputAudioFormat: String = "pcm16"
    var outputAudioFormat: String = "pcm16"
    var inputAudioTranscription: InputAudioTranscriptionConfig?
    var turnDetection: TurnDetectionConfig?
    var tools: [Tool]?
    var toolChoice: String = "auto"
    var temperature: Double = 0.8
    var maxResponseOutputTokens: Int?

    struct InputAudioTranscriptionConfig: Codable {
        var model: String = "whisper-1"
    }

    struct TurnDetectionConfig: Codable {
        var type: String = "server_vad"
        var threshold: Double = 0.5
        var prefixPaddingMs: Int = 300
        var silenceDurationMs: Int = 500

        enum CodingKeys: String, CodingKey {
            case type
            case threshold
            case prefixPaddingMs = "prefix_padding_ms"
            case silenceDurationMs = "silence_duration_ms"
        }
    }

    struct Tool: Codable {
        var type: String
        var name: String
        var description: String?
        var parameters: [String: AnyCodable]?
    }

    enum CodingKeys: String, CodingKey {
        case modalities
        case instructions
        case voice
        case inputAudioFormat = "input_audio_format"
        case outputAudioFormat = "output_audio_format"
        case inputAudioTranscription = "input_audio_transcription"
        case turnDetection = "turn_detection"
        case tools
        case toolChoice = "tool_choice"
        case temperature
        case maxResponseOutputTokens = "max_response_output_tokens"
    }

    /// Default configuration with VAD enabled
    static var `default`: AzureSessionConfiguration {
        var config = AzureSessionConfiguration()
        config.turnDetection = TurnDetectionConfig()
        config.inputAudioTranscription = InputAudioTranscriptionConfig()
        return config
    }
}
