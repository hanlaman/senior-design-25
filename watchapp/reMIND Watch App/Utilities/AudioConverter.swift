//
//  AudioConverter.swift
//  reMIND Watch App
//
//  Audio format conversion and base64 encoding/decoding utilities
//

import Foundation
import AVFoundation
import os

/// Audio format conversion utilities
struct AudioConverter {
    // MARK: - Format Conversion

    /// Convert AVAudioPCMBuffer to Data (PCM16)
    static func bufferToData(_ buffer: AVAudioPCMBuffer) -> Data? {
        guard let channelData = buffer.int16ChannelData else {
            AppLogger.audio.error("Failed to get channel data from buffer")
            return nil
        }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        let bytesPerFrame = MemoryLayout<Int16>.size * channelCount

        let dataSize = frameCount * bytesPerFrame
        var data = Data(count: dataSize)

        data.withUnsafeMutableBytes { rawBufferPointer in
            guard let destination = rawBufferPointer.baseAddress?.assumingMemoryBound(to: Int16.self) else {
                return
            }

            let source = channelData[0]

            // Copy audio data
            for frame in 0..<frameCount {
                destination[frame] = source[frame]
            }
        }

        return data
    }

    /// Convert Data (PCM16) to AVAudioPCMBuffer
    static func dataToBuffer(_ data: Data, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frameCount = data.count / Int(format.streamDescription.pointee.mBytesPerFrame)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            AppLogger.audio.error("Failed to create PCM buffer")
            return nil
        }

        buffer.frameLength = AVAudioFrameCount(frameCount)

        guard let channelData = buffer.int16ChannelData else {
            AppLogger.audio.error("Failed to get channel data from buffer")
            return nil
        }

        data.withUnsafeBytes { rawBufferPointer in
            guard let source = rawBufferPointer.baseAddress?.assumingMemoryBound(to: Int16.self) else {
                return
            }

            let destination = channelData[0]

            // Copy audio data
            for frame in 0..<frameCount {
                destination[frame] = source[frame]
            }
        }

        return buffer
    }

    /// Convert audio buffer to target format using AVAudioConverter
    static func convert(buffer: AVAudioPCMBuffer, to targetFormat: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let converter = AVAudioConverter(from: buffer.format, to: targetFormat) else {
            AppLogger.audio.error("Failed to create audio converter")
            return nil
        }

        let inputFrameCount = buffer.frameLength
        let outputFrameCapacity = AVAudioFrameCount(targetFormat.sampleRate) * inputFrameCount / AVAudioFrameCount(buffer.format.sampleRate)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCapacity) else {
            AppLogger.audio.error("Failed to create output buffer")
            return nil
        }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        if status == .error {
            AppLogger.audio.error("Audio conversion failed: \(error?.localizedDescription ?? "unknown error")")
            return nil
        }

        return outputBuffer
    }

    // MARK: - Base64 Encoding/Decoding

    /// Encode audio data to base64 string
    static func encodeToBase64(_ data: Data) -> String {
        data.base64EncodedString()
    }

    /// Decode base64 string to audio data
    static func decodeFromBase64(_ base64String: String) -> Data? {
        Data(base64Encoded: base64String)
    }

    // MARK: - Chunking

    /// Split audio data into chunks of specified size
    static func chunk(data: Data, chunkSize: Int) -> [Data] {
        var chunks: [Data] = []
        var offset = 0

        while offset < data.count {
            let length = min(chunkSize, data.count - offset)
            let chunk = data.subdata(in: offset..<(offset + length))
            chunks.append(chunk)
            offset += length
        }

        return chunks
    }

    /// Chunk audio buffer into fixed-size frames
    static func chunk(buffer: AVAudioPCMBuffer, framesPerChunk: AVAudioFrameCount) -> [Data] {
        guard let data = bufferToData(buffer) else {
            return []
        }

        let bytesPerFrame = Int(buffer.format.streamDescription.pointee.mBytesPerFrame)
        let bytesPerChunk = Int(framesPerChunk) * bytesPerFrame

        return chunk(data: data, chunkSize: bytesPerChunk)
    }

    // MARK: - Validation

    /// Validate audio format matches Azure requirements
    static func validateFormat(_ format: AVAudioFormat) -> Bool {
        guard format.sampleRate == AudioConfiguration.sampleRate else {
            AppLogger.audio.error("Invalid sample rate: \(format.sampleRate), expected \(AudioConfiguration.sampleRate)")
            return false
        }

        guard format.channelCount == AudioConfiguration.channels else {
            AppLogger.audio.error("Invalid channel count: \(format.channelCount), expected \(AudioConfiguration.channels)")
            return false
        }

        guard format.commonFormat == .pcmFormatInt16 else {
            AppLogger.audio.error("Invalid format: expected PCM16")
            return false
        }

        return true
    }
}
