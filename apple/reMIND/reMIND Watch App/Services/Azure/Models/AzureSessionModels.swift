//
//  AzureSessionModels.swift
//  reMIND Watch App
//
//  Session models from Azure Voice Live API specification
//

import Foundation

// MARK: - RealtimeRequestSession

struct RealtimeRequestSession: Codable, Sendable {
    let model: String?
    let modalities: [RealtimeModality]?
    let animation: RealtimeAnimation?
    let voice: RealtimeVoice?
    let instructions: String?
    let inputAudioSamplingRate: Int?
    let inputAudioFormat: RealtimeAudioFormat?
    let outputAudioFormat: RealtimeOutputAudioFormat?
    let inputAudioNoiseReduction: RealtimeInputAudioNoiseReductionSettings?
    let inputAudioEchoCancellation: RealtimeInputAudioEchoCancellationSettings?
    let inputAudioTranscription: RealtimeAudioInputTranscriptionSettings?
    let turnDetection: RealtimeTurnDetection?
    let tools: [RealtimeTool]?
    let toolChoice: RealtimeToolChoice?
    let temperature: Double?
    let maxResponseOutputTokens: MaxOutputTokens?
    let avatar: RealtimeAvatarConfig?
    let outputAudioTimestampTypes: [RealtimeAudioTimestampType]?

    enum CodingKeys: String, CodingKey {
        case model
        case modalities
        case animation
        case voice
        case instructions
        case inputAudioSamplingRate = "input_audio_sampling_rate"
        case inputAudioFormat = "input_audio_format"
        case outputAudioFormat = "output_audio_format"
        case inputAudioNoiseReduction = "input_audio_noise_reduction"
        case inputAudioEchoCancellation = "input_audio_echo_cancellation"
        case inputAudioTranscription = "input_audio_transcription"
        case turnDetection = "turn_detection"
        case tools
        case toolChoice = "tool_choice"
        case temperature
        case maxResponseOutputTokens = "max_response_output_tokens"
        case avatar
        case outputAudioTimestampTypes = "output_audio_timestamp_types"
    }

    init(
        model: String? = nil,
        modalities: [RealtimeModality]? = nil,
        animation: RealtimeAnimation? = nil,
        voice: RealtimeVoice? = nil,
        instructions: String? = nil,
        inputAudioSamplingRate: Int? = nil,
        inputAudioFormat: RealtimeAudioFormat? = nil,
        outputAudioFormat: RealtimeOutputAudioFormat? = nil,
        inputAudioNoiseReduction: RealtimeInputAudioNoiseReductionSettings? = nil,
        inputAudioEchoCancellation: RealtimeInputAudioEchoCancellationSettings? = nil,
        inputAudioTranscription: RealtimeAudioInputTranscriptionSettings? = nil,
        turnDetection: RealtimeTurnDetection? = nil,
        tools: [RealtimeTool]? = nil,
        toolChoice: RealtimeToolChoice? = nil,
        temperature: Double? = nil,
        maxResponseOutputTokens: MaxOutputTokens? = nil,
        avatar: RealtimeAvatarConfig? = nil,
        outputAudioTimestampTypes: [RealtimeAudioTimestampType]? = nil
    ) {
        self.model = model
        self.modalities = modalities
        self.animation = animation
        self.voice = voice
        self.instructions = instructions
        self.inputAudioSamplingRate = inputAudioSamplingRate
        self.inputAudioFormat = inputAudioFormat
        self.outputAudioFormat = outputAudioFormat
        self.inputAudioNoiseReduction = inputAudioNoiseReduction
        self.inputAudioEchoCancellation = inputAudioEchoCancellation
        self.inputAudioTranscription = inputAudioTranscription
        self.turnDetection = turnDetection
        self.tools = tools
        self.toolChoice = toolChoice
        self.temperature = temperature
        self.maxResponseOutputTokens = maxResponseOutputTokens
        self.avatar = avatar
        self.outputAudioTimestampTypes = outputAudioTimestampTypes
    }
}

// MARK: - RealtimeResponseSession

struct RealtimeResponseSession: Codable, Sendable {
    let object: String
    let id: String
    let model: String
    let modalities: [RealtimeModality]
    let instructions: String?
    let voice: RealtimeVoice?
    let inputAudioFormat: RealtimeAudioFormat
    let outputAudioFormat: RealtimeOutputAudioFormat
    let inputAudioSamplingRate: Int
    let turnDetection: RealtimeTurnDetection?
    let temperature: Double
    let maxResponseOutputTokens: MaxOutputTokens
    let avatar: RealtimeAvatarConfig?

    enum CodingKeys: String, CodingKey {
        case object
        case id
        case model
        case modalities
        case instructions
        case voice
        case inputAudioFormat = "input_audio_format"
        case outputAudioFormat = "output_audio_format"
        case inputAudioSamplingRate = "input_audio_sampling_rate"
        case turnDetection = "turn_detection"
        case temperature
        case maxResponseOutputTokens = "max_response_output_tokens"
        case avatar
    }
}
