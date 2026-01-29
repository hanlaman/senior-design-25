//
//  AzureConfigurationHelpers.swift
//  reMIND Watch App
//
//  Helper methods and default configurations for Azure Voice Live API
//

import Foundation

// MARK: - Configuration Presets

extension RealtimeRequestSession {

    /// Basic audio conversation configuration with default settings
    static func basicAudioConversation(instructions: String? = nil) -> RealtimeRequestSession {
        return RealtimeRequestSession(
            modalities: [.text, .audio],
            voice: .openai(RealtimeOpenAIVoice(name: "alloy")),
            instructions: instructions,
            inputAudioFormat: .pcm16,
            outputAudioFormat: .pcm16,
            inputAudioTranscription: RealtimeAudioInputTranscriptionSettings(model: "whisper-1"),
            turnDetection: .serverVAD(RealtimeServerVAD(
                threshold: 0.5,
                prefixPaddingMs: 300,
                silenceDurationMs: 500
            )),
            temperature: 0.8
        )
    }

    /// Configuration with semantic VAD for more natural conversations
    static func semanticVADConversation(
        instructions: String? = nil,
        eagerness: String = "auto"
    ) -> RealtimeRequestSession {
        return RealtimeRequestSession(
            modalities: [.text, .audio],
            voice: .openai(RealtimeOpenAIVoice(name: "alloy")),
            instructions: instructions,
            inputAudioFormat: .pcm16,
            outputAudioFormat: .pcm16,
            inputAudioTranscription: RealtimeAudioInputTranscriptionSettings(model: "whisper-1"),
            turnDetection: .semanticVAD(RealtimeSemanticVAD(
                eagerness: eagerness,
                interruptResponse: true
            )),
            temperature: 0.8
        )
    }

    /// Configuration with Azure Semantic VAD
    static func azureSemanticVAD(
        instructions: String? = nil,
        removeFillerWords: Bool = false
    ) -> RealtimeRequestSession {
        return RealtimeRequestSession(
            modalities: [.text, .audio],
            voice: .openai(RealtimeOpenAIVoice(name: "alloy")),
            instructions: instructions,
            inputAudioFormat: .pcm16,
            outputAudioFormat: .pcm16,
            inputAudioTranscription: RealtimeAudioInputTranscriptionSettings(model: "azure-speech"),
            turnDetection: .azureSemanticVAD(RealtimeAzureSemanticVAD(
                threshold: 0.5,
                prefixPaddingMs: 300,
                silenceDurationMs: 500,
                speechDurationMs: 1000,
                removeFillerWords: removeFillerWords,
                languages: ["English"]
            )),
            temperature: 0.8
        )
    }

    /// Manual turn control (no VAD)
    static func manualTurnControl(instructions: String? = nil) -> RealtimeRequestSession {
        return RealtimeRequestSession(
            modalities: [.text, .audio],
            voice: .openai(RealtimeOpenAIVoice(name: "alloy")),
            instructions: instructions,
            inputAudioFormat: .pcm16,
            outputAudioFormat: .pcm16,
            inputAudioTranscription: RealtimeAudioInputTranscriptionSettings(model: "whisper-1"),
            turnDetection: nil,
            temperature: 0.8
        )
    }

    /// Configuration with custom Azure voice
    static func customVoiceConversation(
        voiceName: String,
        endpointId: String,
        instructions: String? = nil,
        style: String? = nil,
        temperature: Double = 0.8
    ) -> RealtimeRequestSession {
        return RealtimeRequestSession(
            modalities: [.text, .audio],
            voice: .azureCustom(RealtimeAzureCustomVoice(
                name: voiceName,
                endpointId: endpointId,
                temperature: temperature,
                style: style
            )),
            instructions: instructions,
            inputAudioFormat: .pcm16,
            outputAudioFormat: .pcm16,
            inputAudioTranscription: RealtimeAudioInputTranscriptionSettings(model: "azure-speech"),
            turnDetection: .serverVAD(RealtimeServerVAD(
                threshold: 0.5,
                prefixPaddingMs: 300,
                silenceDurationMs: 500
            )),
            temperature: temperature
        )
    }
}

// MARK: - Conversation Item Helpers

extension RealtimeConversationRequestItem {

    /// Create a user text message
    static func userTextMessage(_ text: String, id: String? = nil) -> RealtimeConversationRequestItem {
        return .userMessage(RealtimeUserMessageRequestItem(
            content: [.inputText(RealtimeInputTextContentPart(text: text))],
            id: id
        ))
    }

    /// Create a system message
    static func systemMessage(_ text: String, id: String? = nil) -> RealtimeConversationRequestItem {
        return .systemMessage(RealtimeSystemMessageRequestItem(
            content: [RealtimeInputTextContentPart(text: text)],
            id: id
        ))
    }

    /// Create a function call output
    static func functionOutput(callId: String, output: String, id: String? = nil) -> RealtimeConversationRequestItem {
        return .functionCallOutput(RealtimeFunctionCallOutputRequestItem(
            callId: callId,
            output: output,
            id: id
        ))
    }
}

// MARK: - Response Options Helpers

extension RealtimeResponseOptions {

    /// Default response options
    static func `default`() -> RealtimeResponseOptions {
        return RealtimeResponseOptions(
            modalities: ["text", "audio"],
            temperature: 0.8
        )
    }

    /// Text-only response
    static func textOnly(instructions: String? = nil) -> RealtimeResponseOptions {
        return RealtimeResponseOptions(
            modalities: ["text"],
            instructions: instructions,
            temperature: 0.8
        )
    }

    /// Response with custom instructions
    static func withInstructions(_ instructions: String) -> RealtimeResponseOptions {
        return RealtimeResponseOptions(
            modalities: ["text", "audio"],
            instructions: instructions,
            temperature: 0.8
        )
    }
}

// MARK: - Audio Format Utilities

extension RealtimeAudioFormat {
    /// Get sample rate for this audio format
    var sampleRate: Int {
        switch self {
        case .pcm16:
            return 24000
        case .g711Ulaw, .g711Alaw:
            return 8000
        }
    }

    /// Get bytes per sample
    var bytesPerSample: Int {
        switch self {
        case .pcm16:
            return 2
        case .g711Ulaw, .g711Alaw:
            return 1
        }
    }

    /// Calculate bytes for a given duration in milliseconds
    func bytes(forDurationMs durationMs: Double) -> Int {
        let samplesPerSecond = Double(sampleRate)
        let samples = Int(samplesPerSecond * durationMs / 1000.0)
        return samples * bytesPerSample
    }

    /// Calculate duration in milliseconds for a given number of bytes
    func durationMs(forBytes bytes: Int) -> Double {
        let samples = Double(bytes) / Double(bytesPerSample)
        return (samples / Double(sampleRate)) * 1000.0
    }
}

// MARK: - Common Voice Presets

extension RealtimeVoice {
    /// OpenAI Alloy voice (default)
    static let alloy = RealtimeVoice.openai(RealtimeOpenAIVoice(name: "alloy"))

    /// OpenAI Echo voice
    static let echo = RealtimeVoice.openai(RealtimeOpenAIVoice(name: "echo"))

    /// OpenAI Shimmer voice
    static let shimmer = RealtimeVoice.openai(RealtimeOpenAIVoice(name: "shimmer"))

    /// OpenAI Sage voice
    static let sage = RealtimeVoice.openai(RealtimeOpenAIVoice(name: "sage"))
}

// MARK: - Example Usage Documentation

/*
 EXAMPLE USAGE:

 // 1. Create and connect service
 let service = AzureVoiceLiveService(
     apiKey: BuildConfiguration.azureAPIKey,
     websocketURL: URL(string: "wss://\(BuildConfiguration.azureResourceName).services.ai.azure.com/voice-live/realtime?api-version=\(BuildConfiguration.azureAPIVersion)&model=gpt-realtime")!
 )

 try await service.connect()

 // 2. Configure session
 let config = RealtimeRequestSession.basicAudioConversation(
     instructions: "You are a helpful assistant for elderly users. Speak clearly and warmly."
 )
 try await service.updateSession(config)

 // 3. Listen to events
 Task {
     for await event in service.eventStream {
         switch event {
         case .sessionCreated(let session):
             print("Session created: \(session.session.id)")

         case .inputAudioBufferSpeechStarted(let speech):
             print("User started speaking at \(speech.audioStartMs)ms")

         case .responseAudioTranscriptDelta(let delta):
             print("Assistant: \(delta.delta)")

         case .responseAudioDelta(let audio):
             if let audioData = Data(base64Encoded: audio.delta) {
                 // Play audio
             }

         case .error(let error):
             print("Error: \(error.error.message)")

         default:
             break
         }
     }
 }

 // 4. Send audio
 try await service.sendAudioChunk(audioData)
 try await service.commitAudioBuffer()

 // 5. Send text message
 let message = RealtimeConversationRequestItem.userTextMessage(
     "What's the weather like today?"
 )
 try await service.createConversationItem(previousItemId: nil, item: message)

 // 6. Trigger response
 try await service.createResponse(config: nil)

 // 7. Cleanup
 await service.disconnect()
 */
