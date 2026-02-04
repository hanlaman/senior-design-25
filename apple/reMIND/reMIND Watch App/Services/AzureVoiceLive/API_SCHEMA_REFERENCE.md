# Azure Voice Live API - Complete Schema Reference

This document contains the exact schema from the official API reference.
All implementations MUST match these schemas exactly.

## Client Events (12 total)

1. `session.update` - `{ type, session: RealtimeRequestSession }`
2. `session.avatar.connect` - `{ type, client_sdp: string }`
3. `input_audio_buffer.append` - `{ type, audio: string }`
4. `input_audio_buffer.commit` - `{ type }`
5. `input_audio_buffer.clear` - `{ type }`
6. `conversation.item.create` - `{ type, previous_item_id?: string, item: RealtimeConversationRequestItem }`
7. `conversation.item.retrieve` - `{ type, item_id: string }`
8. `conversation.item.truncate` - `{ type, item_id: string, content_index: integer, audio_end_ms: integer }`
9. `conversation.item.delete` - `{ type, item_id: string }`
10. `response.create` - `{ type, response?: RealtimeResponseOptions }`
11. `response.cancel` - `{ type }`
12. `mcp_approval_response` - `{ type, approve: boolean, approval_request_id: string }`

## Server Events (40+ total)

1. `error` - `{ type, error: { code: string, message: string, param?: string, event_id?: string } }`
2. `session.created` - `{ type, session: RealtimeResponseSession }`
3. `session.updated` - `{ type, session: RealtimeResponseSession }`
4. `session.avatar.connecting` - `{ type, server_sdp: string }`
5. `conversation.item.created` - `{ type, previous_item_id?: string, item: RealtimeConversationResponseItem }`
6. `conversation.item.retrieved` - `{ type, item: RealtimeConversationResponseItem }`
7. `conversation.item.truncated` - `{ type, item_id: string, content_index: integer, audio_end_ms: integer }`
8. `conversation.item.deleted` - `{ type, item_id: string }`
9. `conversation.item.input_audio_transcription.completed` - `{ type, item_id: string, content_index: integer, transcript: string }`
10. `conversation.item.input_audio_transcription.delta` - `{ type, item_id: string, content_index: integer, delta: string }`
11. `conversation.item.input_audio_transcription.failed` - `{ type, item_id: string, content_index: integer, error: object }`
12. `input_audio_buffer.committed` - `{ type, previous_item_id: string, item_id: string }`
13. `input_audio_buffer.cleared` - `{ type }`
14. `input_audio_buffer.speech_started` - `{ type, audio_start_ms: integer, item_id: string }`
15. `input_audio_buffer.speech_stopped` - `{ type, audio_end_ms: integer, item_id: string }`
16. `response.created` - `{ type, response: RealtimeResponse }`
17. `response.done` - `{ type, response: RealtimeResponse }`
18. `response.output_item.added` - `{ type, response_id: string, output_index: integer, item: RealtimeConversationResponseItem }`
19. `response.output_item.done` - `{ type, response_id: string, output_index: integer, item: RealtimeConversationResponseItem }`
20. `response.content_part.added` - `{ type, response_id: string, item_id: string, output_index: integer, content_index: integer, part: RealtimeContentPart }`
21. `response.content_part.done` - `{ type, response_id: string, item_id: string, output_index: integer, content_index: integer, part: RealtimeContentPart }`
22. `response.text.delta` - `{ type, response_id: string, item_id: string, output_index: integer, content_index: integer, delta: string }`
23. `response.text.done` - `{ type, response_id: string, item_id: string, output_index: integer, content_index: integer, text: string }`
24. `response.audio.delta` - `{ type, response_id: string, item_id: string, output_index: integer, content_index: integer, delta: string }`
25. `response.audio.done` - `{ type, response_id: string, item_id: string, output_index: integer, content_index: integer }`
26. `response.audio_transcript.delta` - `{ type, response_id: string, item_id: string, output_index: integer, content_index: integer, delta: string }`
27. `response.audio_transcript.done` - `{ type, response_id: string, item_id: string, output_index: integer, content_index: integer, transcript: string }`
28. `response.animation_blendshapes.delta` - `{ type, response_id: string, item_id: string, output_index: integer, content_index: integer, frame_index: integer, frames: float[][] }`
29. `response.animation_blendshapes.done` - `{ type, response_id: string, item_id: string, output_index: integer }`
30. `response.audio_timestamp.delta` - `{ type, response_id: string, item_id: string, output_index: integer, content_index: integer, audio_offset_ms: integer, audio_duration_ms: integer, text: string, timestamp_type: string }`
31. `response.audio_timestamp.done` - `{ type, response_id: string, item_id: string, output_index: integer, content_index: integer }`
32. `response.animation_viseme.delta` - `{ type, response_id: string, item_id: string, output_index: integer, content_index: integer, audio_offset_ms: integer, viseme_id: integer }`
33. `response.animation_viseme.done` - `{ type, response_id: string, item_id: string, output_index: integer, content_index: integer }`
34. `response.function_call_arguments.delta` - `{ type, response_id: string, item_id: string, output_index: integer, call_id: string, delta: string }`
35. `response.function_call_arguments.done` - `{ type, response_id: string, item_id: string, output_index: integer, call_id: string, arguments: string }`
36. `mcp_list_tools.in_progress` - `{ type, item_id: string }`
37. `mcp_list_tools.completed` - `{ type, item_id: string }`
38. `mcp_list_tools.failed` - `{ type, item_id: string }`
39. `response.mcp_call_arguments.delta` - `{ type, response_id: string, item_id: string, output_index: integer, delta: string }`
40. `response.mcp_call_arguments.done` - `{ type, response_id: string, item_id: string, output_index: integer, arguments: string }`
41. `response.mcp_call.in_progress` - `{ type, item_id: string, output_index: integer }`
42. `response.mcp_call.completed` - `{ type, item_id: string, output_index: integer }`
43. `response.mcp_call.failed` - `{ type, item_id: string, output_index: integer }`
44. `rate_limits.updated` - `{ type, rate_limits: RealtimeRateLimitsItem[] }`

## Core Component Models

### RealtimeRequestSession
```json
{
  "model": "string?",
  "modalities": ["text", "audio", "animation", "avatar"]?,
  "animation": RealtimeAnimation?,
  "voice": RealtimeVoice?,
  "instructions": "string?",
  "input_audio_sampling_rate": integer?,
  "input_audio_format": "pcm16|g711_ulaw|g711_alaw"?,
  "output_audio_format": "pcm16|pcm16_8000hz|pcm16_16000hz|g711_ulaw|g711_alaw"?,
  "input_audio_noise_reduction": RealtimeInputAudioNoiseReductionSettings?,
  "input_audio_echo_cancellation": RealtimeInputAudioEchoCancellationSettings?,
  "input_audio_transcription": RealtimeAudioInputTranscriptionSettings?,
  "turn_detection": RealtimeTurnDetection?,
  "tools": RealtimeTool[]?,
  "tool_choice": "auto|none|required|{type:function,name:string}"?,
  "temperature": number?,
  "max_response_output_tokens": integer|"inf"?,
  "avatar": RealtimeAvatarConfig?,
  "output_audio_timestamp_types": ["word"]?
}
```

### RealtimeResponseSession
```json
{
  "object": "realtime.session",
  "id": "string",
  "model": "string",
  "modalities": ["string"],
  "instructions": "string?",
  "voice": RealtimeVoice?,
  "input_audio_sampling_rate": integer,
  "input_audio_format": "string",
  "output_audio_format": "string",
  "turn_detection": object?,
  "temperature": number,
  "max_response_output_tokens": integer|"inf",
  "avatar": RealtimeAvatarConfig?
}
```

### RealtimeConversationRequestItem (Union)
One of:
- `{ type: "message", role: "system", content: [{type:"input_text",text:"..."}], id?: string }`
- `{ type: "message", role: "user", content: [{type:"input_text"|"input_audio",text?:"...",audio?:"...",transcript?:"..."}], id?: string }`
- `{ type: "message", role: "assistant", content: [{type:"text",text:"..."}] }`
- `{ type: "function_call", name: string, arguments: string, call_id: string, id?: string }`
- `{ type: "function_call_output", call_id: string, output: string, id?: string }`
- `{ type: "mcp_approval_response", approve: boolean, approval_request_id: string }`

### RealtimeConversationResponseItem (Union)
One of:
- UserMessage: `{ id, type:"message", object:"conversation.item", role:"user", content: RealtimeInputTextContentPart[], status }`
- AssistantMessage: `{ id, type:"message", object:"conversation.item", role:"assistant", content: RealtimeOutputTextContentPart[]|RealtimeOutputAudioContentPart[], status }`
- SystemMessage: `{ id, type:"message", object:"conversation.item", role:"system", content: RealtimeInputTextContentPart[], status }`
- FunctionCall: `{ id, type:"function_call", object:"conversation.item", name, arguments, call_id, status }`
- FunctionCallOutput: `{ id, type:"function_call_output", object:"conversation.item", name, output, call_id, status }`
- MCPListTools: `{ id, type:"mcp_list_tools", server_label }`
- MCPCall: `{ id, type:"mcp_call", server_label, name, approval_request_id, arguments, output, error }`
- MCPApprovalRequest: `{ id, type:"mcp_approval_request", server_label, name, arguments }`

### RealtimeContentPart (Union)
- InputText: `{ type: "input_text", text: string }`
- OutputText: `{ type: "text", text: string }`
- InputAudio: `{ type: "input_audio", audio?: string, transcript?: string }`
- OutputAudio: `{ type: "audio", audio: string, transcript?: string }`
- ResponseAudio: `{ type: "audio", transcript?: string }`

### RealtimeResponse
```json
{
  "id": "string?",
  "object": "realtime.response?",
  "status": "in_progress|completed|cancelled|incomplete|failed?",
  "status_details": RealtimeResponseStatusDetails?,
  "output": RealtimeConversationResponseItem[]?,
  "usage": RealtimeUsage?,
  "conversation_id": "string?",
  "voice": RealtimeVoice?,
  "modalities": ["string"]?,
  "output_audio_format": string?,
  "temperature": number?,
  "max_response_output_tokens": integer|"inf"?
}
```

### RealtimeResponseOptions
```json
{
  "modalities": ["text","audio"]?,
  "instructions": "string?",
  "voice": RealtimeVoice?,
  "tools": RealtimeTool[]?,
  "tool_choice": "auto|none|required|{type,name}"?,
  "temperature": number?,
  "max_response_output_tokens": integer|"inf"?,
  "conversation": "auto|none"?,
  "metadata": {key:value}?
}
```

### RealtimeUsage
```json
{
  "total_tokens": integer,
  "input_tokens": integer,
  "output_tokens": integer,
  "input_token_details": TokenDetails?,
  "output_token_details": TokenDetails?
}
```

### TokenDetails
```json
{
  "cached_tokens": integer?,
  "text_tokens": integer?,
  "audio_tokens": integer?
}
```

### RealtimeVoice (Union)
One of:
- OpenAI: `{ type: "openai", name: "alloy|ash|ballad|coral|echo|sage|shimmer|verse|marin|cedar" }`
- AzureStandard: `{ type: "azure-standard", name, temperature?, custom_lexicon_url?, prefer_locales?, locale?, style?, pitch?, rate?, volume? }`
- AzureCustom: `{ type: "azure-custom", name, endpoint_id, temperature?, custom_lexicon_url?, prefer_locales?, locale?, style?, pitch?, rate?, volume? }`
- AzurePersonal: `{ type: "azure-personal", name, temperature?, model, custom_lexicon_url?, prefer_locales?, locale?, pitch?, rate?, volume? }`

### RealtimeTurnDetection (Union)
One of:
- ServerVAD: `{ type: "server_vad", threshold?, prefix_padding_ms?, silence_duration_ms?, end_of_utterance_detection?, create_response?, interrupt_response?, auto_truncate? }`
- SemanticVAD: `{ type: "semantic_vad", eagerness?: "auto|low|high", create_response?, interrupt_response? }`
- AzureSemanticVAD: `{ type: "azure_semantic_vad", threshold?, prefix_padding_ms?, silence_duration_ms?, end_of_utterance_detection?, speech_duration_ms?, remove_filler_words?, languages?, create_response?, interrupt_response?, auto_truncate? }`
- AzureSemanticVADMultilingual: `{ type: "azure_semantic_vad_multilingual", threshold?, prefix_padding_ms?, silence_duration_ms?, end_of_utterance_detection?, speech_duration_ms?, remove_filler_words?, languages?, create_response?, interrupt_response?, auto_truncate? }`

### RealtimeEOUDetection
```json
{
  "model": "semantic_detection_v1|semantic_detection_v1_multilingual",
  "threshold_level": "low|medium|high|default?",
  "timeout_ms": number?
}
```

### RealtimeAudioInputTranscriptionSettings
```json
{
  "model": "whisper-1|gpt-4o-transcribe|gpt-4o-mini-transcribe|gpt-4o-transcribe-diarize|azure-speech",
  "language": "string?",
  "custom_speech": object?,
  "phrase_list": ["string"]?,
  "prompt": "string?"
}
```

### RealtimeInputAudioNoiseReductionSettings (Union)
- OpenAI: `{ type: "near_field|far_field" }`
- Azure: `{ type: "azure_deep_noise_suppression" }`

### RealtimeInputAudioEchoCancellationSettings
```json
{
  "type": "server_echo_cancellation"
}
```

### RealtimeAnimation
```json
{
  "model_name": "string?",
  "outputs": ["blendshapes","viseme_id"]?
}
```

### RealtimeAvatarConfig
```json
{
  "ice_servers": RealtimeIceServer[]?,
  "character": "string",
  "style": "string?",
  "customized": boolean,
  "video": RealtimeVideoParams?
}
```

### RealtimeIceServer
```json
{
  "urls": ["string"],
  "username": "string?",
  "credential": "string?"
}
```

### RealtimeVideoParams
```json
{
  "bitrate": integer?,
  "codec": "string?",
  "crop": RealtimeVideoCrop?,
  "resolution": RealtimeVideoResolution?
}
```

### RealtimeVideoCrop
```json
{
  "top_left": [x, y],
  "bottom_right": [x, y]
}
```

### RealtimeVideoResolution
```json
{
  "width": integer,
  "height": integer
}
```

### RealtimeTool (Union)
- Function: `{ type: "function", name, description, parameters: JSONSchema }`
- MCP: `{ type: "mcp", server_label, server_url, allowed_tools?, headers?, authorization?, require_approval?: "never|always|{never:[],always:[]}" }`

### RealtimeRateLimitsItem
```json
{
  "name": "string",
  "limit": integer,
  "remaining": integer,
  "reset_seconds": integer
}
```

### RealtimeErrorDetails
```json
{
  "type": "string",
  "code": "string?",
  "message": "string",
  "param": "string?",
  "event_id": "string?"
}
```

### RealtimeResponseStatusDetails
```json
{
  "type": "string?",
  "reason": "string?",
  "error": RealtimeErrorDetails?
}
```

## Enumerations

- RealtimeItemStatus: `in_progress | completed | incomplete`
- RealtimeResponseStatus: `in_progress | completed | cancelled | incomplete | failed`
- RealtimeModality: `text | audio | animation | avatar`
- RealtimeAudioFormat: `pcm16 | g711_ulaw | g711_alaw`
- RealtimeOutputAudioFormat: `pcm16 | pcm16_8000hz | pcm16_16000hz | g711_ulaw | g711_alaw`
- RealtimeAudioTimestampType: `word`
- RealtimeAnimationOutputType: `blendshapes | viseme_id`
