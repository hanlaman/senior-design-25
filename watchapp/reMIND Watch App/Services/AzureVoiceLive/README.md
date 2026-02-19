# AzureVoiceLive SDK

A Swift SDK for integrating Azure Voice Live real-time AI conversations into watchOS applications.

## Overview

The AzureVoiceLive SDK provides a complete implementation of the Azure Voice Live API, enabling real-time voice conversations with Azure's GPT models. This SDK is specifically designed for watchOS and handles WebSocket communication, audio streaming, event processing, and session management.

## Key Features

- **Real-time Voice Conversations**: Stream audio to Azure and receive AI-generated voice responses
- **Complete Event System**: Support for 44+ event types including session, audio, conversation, and response events
- **Voice Activity Detection (VAD)**: Server-side and semantic VAD for natural turn-taking
- **Audio Streaming**: Efficient PCM16 audio streaming with base64 encoding
- **Session Management**: Full control over conversation sessions and configuration
- **MCP Tool Integration**: Support for Model Context Protocol (MCP) tool calling
- **Avatar Support**: Integration with Azure avatar services for visual representations
- **Error Handling**: Comprehensive error handling with detailed error messages
- **Actor-based Concurrency**: Thread-safe implementation using Swift's actor model

## Quick Start

### 1. Configuration

Create an `AzureVoiceLiveConfig` instance with your Azure credentials:

```swift
let config = AzureVoiceLiveConfig(
    apiKey: "YOUR_API_KEY",
    resourceName: "YOUR_RESOURCE_NAME",
    apiVersion: "2025-10-01",
    model: "gpt-realtime-mini"
)

// Validate the configuration
if let error = config.validate() {
    print("Configuration error: \(error)")
}
```

### 2. Initialize the Service

```swift
guard let websocketURL = config.websocketURL else {
    fatalError("Invalid WebSocket URL")
}

let azureService = AzureVoiceLiveService(
    apiKey: config.apiKey,
    websocketURL: websocketURL
)
```

### 3. Connect and Configure

```swift
// Connect to Azure
try await azureService.connect()

// Configure the session with audio settings
try await azureService.updateSession(.basicAudioConversation())

// Wait for session to be ready
try await azureService.waitForSessionCreated()
```

### 4. Process Events

```swift
Task {
    for await event in await azureService.eventStream {
        switch event {
        case .sessionCreated(let session):
            print("Session created: \(session.session.id)")

        case .responseAudioDelta(let audio):
            // Decode and play audio
            if let audioData = AudioConverter.decodeFromBase64(audio.delta) {
                try await audioService.playAudio(audioData)
            }

        case .error(let error):
            print("Error: \(error.error.message)")

        default:
            break
        }
    }
}
```

### 5. Stream Audio

```swift
// Send audio chunks (append to buffer)
try await azureService.sendAudioChunk(audioData)

// Commit buffer when done speaking
try await azureService.commitAudioBuffer()
```

### 6. Disconnect

```swift
await azureService.disconnect()
```

## Configuration

### Session Configuration Helpers

The SDK includes convenient session configuration presets:

```swift
// Basic audio conversation (recommended for most use cases)
try await azureService.updateSession(.basicAudioConversation())

// Custom configuration
try await azureService.updateSession(RealtimeRequestSession(
    modalities: [.audio, .text],
    voice: .alloy,
    inputAudioFormat: .pcm16,
    outputAudioFormat: .pcm16_24000hz,
    turnDetection: .serverVad(threshold: 0.5, silenceDuration: 200),
    temperature: 0.8,
    maxOutputTokens: .integer(2048)
))
```

### Supported Voices

- **OpenAI Voices**: alloy, echo, fable, onyx, nova, shimmer
- **Azure Standard Voices**: Custom Azure TTS voices
- **Azure Personal Voices**: Custom personal voice models

### Audio Formats

**Input**: PCM16, G.711 μ-law, G.711 A-law
**Output**: PCM16 (8kHz, 16kHz, 24kHz), G.711 μ-law, G.711 A-law

### Turn Detection

- **Server VAD**: Automatic voice activity detection by Azure
- **Semantic VAD**: Context-aware turn detection
- **Manual**: Client-controlled turn completion

## Architecture

### Core Components

- **AzureVoiceLiveService**: Main service actor handling WebSocket communication and API interactions
- **AzureVoiceLiveProtocol**: Protocol defining the public API surface
- **WebSocketManager**: Internal WebSocket connection management
- **AzureVoiceLiveConfig**: Configuration structure with validation

### Event System

The SDK emits 44+ event types organized into categories:

- **Session Events** (3): session.created, session.updated, session.avatar.connecting
- **Audio Buffer Events** (4): committed, cleared, speech_started, speech_stopped
- **Conversation Events** (7): item.created, item.deleted, transcription events
- **Response Events** (6): response.created, response.done, output_item events
- **Streaming Events** (12): text.delta, audio.delta, transcript.delta, etc.
- **Animation Events** (4): blendshapes, visemes
- **Tool Calling Events** (10): function_call, mcp_call events
- **System Events** (2): error, rate_limits.updated

### Model Types

The SDK includes comprehensive model definitions for:

- Session configuration and state
- Conversation items (text, audio, function calls)
- Response options and status
- Audio settings and formats
- Voice configuration
- Turn detection settings
- Avatar and animation data
- MCP tool definitions

## Error Handling

The SDK provides detailed error information through the `AzureError` enum:

```swift
do {
    try await azureService.commitAudioBuffer()
} catch let error as AzureError {
    switch error {
    case .notConnected:
        print("Not connected to Azure")
    case .bufferTooSmall:
        print("Audio buffer too small (minimum 200ms)")
    case .invalidConfiguration(let message):
        print("Configuration error: \(message)")
    case .apiError(let message):
        print("API error: \(message)")
    }
}
```

## Advanced Usage

### Audio Buffer Management

```swift
// Get buffer statistics
let stats = await azureService.getAudioBufferStatistics()
print("Buffer: \(stats.durationMs)ms, \(stats.bytes) bytes, \(stats.chunks) chunks")

// Clear buffer without processing
try await azureService.clearAudioBuffer()
```

### Conversation Management

```swift
// Create a conversation item
try await azureService.createConversationItem(
    previousItemId: nil,
    item: .message(.user(text: "Hello"))
)

// Delete a conversation item
try await azureService.deleteConversationItem(itemId: "item_123")

// Truncate assistant audio response
try await azureService.truncateConversationItem(
    itemId: "item_456",
    contentIndex: 0,
    audioEndMs: 5000
)
```

### Manual Response Generation

```swift
// Trigger response manually (without audio input)
try await azureService.createResponse(config: RealtimeResponseOptions(
    modalities: [.audio, .text],
    temperature: 0.7,
    maxOutputTokens: .integer(1024)
))

// Cancel ongoing response
try await azureService.cancelResponse()
```

### MCP Tool Integration

```swift
// Approve or reject MCP tool calls
try await azureService.sendMcpApproval(
    approve: true,
    approvalRequestId: "approval_123"
)
```

## API Reference

See [API_SCHEMA_REFERENCE.md](API_SCHEMA_REFERENCE.md) for detailed API documentation including all event types, request models, and response models.

## Requirements

- watchOS 10.0+
- Swift 6.0+
- Xcode 16.0+

## Integration

This SDK is designed as an internal library within the reMIND Watch App. It can be easily extracted into a Swift Package Manager package for reuse in other projects:

1. Copy the `Libraries/AzureVoiceLiveSDK` directory
2. Create a `Package.swift` file
3. Add package dependencies as needed
4. Update import statements in your app

## Implementation Notes

- **Thread Safety**: All service methods are actor-isolated for thread-safe access
- **Event Streaming**: Events are delivered via `AsyncStream` for efficient async processing
- **Audio Format**: Audio is streamed as base64-encoded PCM16 at 24kHz by default
- **Buffer Management**: Audio chunks are buffered until committed or cleared
- **Session Lifecycle**: Session must be configured before sending audio

## License

See the main project license.

## Support

For issues, questions, or contributions, see the main reMIND Watch App repository.
