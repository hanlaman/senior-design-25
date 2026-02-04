# Cross-Check Issues Found

## Issues to Fix

### 1. AzureResponseModels.swift

#### RealtimeResponseOptions
**Missing field:**
- `animation: RealtimeAnimation?` - Optional field per spec

**Type issues:**
- `modalities` should remain `[String]?` ✓ (correct as-is)

#### RealtimeResponse
**Type issues:**
- `outputAudioFormat` should be `RealtimeOutputAudioFormat?` not `String?`

### 2. AzureSessionModels.swift

#### RealtimeResponseSession
**Type issues:**
- `modalities` should be `[RealtimeModality]` not `[String]` - spec says `RealtimeModality[]` (non-optional)
- `inputAudioFormat` should be `RealtimeAudioFormat` not `String` - spec says `RealtimeAudioFormat` (non-optional)
- `outputAudioFormat` should be `RealtimeOutputAudioFormat` not `String` - spec says `RealtimeOutputAudioFormat` (non-optional)
- `turnDetection` should be `RealtimeTurnDetection?` not `AnyCodable?` - spec says `RealtimeTurnDetection` (optional)

### 3. AzureConversationModels.swift

#### RealtimeConversationMCPCallItem
**Optionality issues:**
- `approvalRequestId` should be `String?` (optional) - spec says "Yes" in optional column
- `output` should be `String?` (optional) - spec says "Yes" in optional column

## Verification Summary

### ✅ Correct Models
- AzureCommonTypes.swift - All enums match spec exactly
- AzureVoiceModels.swift - All 4 voice variants match spec
- AzureTurnDetectionModels.swift - All 4 turn detection variants match spec
- AzureAudioModels.swift - All audio config models match spec
- AzureAvatarModels.swift - All avatar/animation models match spec
- AzureToolModels.swift - All tool models match spec
- AzureClientEvents.swift - All 12 client events match spec
- AzureServerEvents.swift - All 44 server events match spec
- RealtimeRequestSession - All fields match spec ✓
- RealtimeUsage - All fields match spec ✓
- TokenDetails - All fields match spec ✓
- RealtimeErrorDetails - All fields match spec ✓
- RealtimeRateLimitsItem - All fields match spec ✓
- RealtimeResponseStatusDetails - All fields match spec ✓

### 🔧 Models Needing Fixes
1. RealtimeResponseOptions - Missing `animation` field
2. RealtimeResponse - Wrong type for `outputAudioFormat`
3. RealtimeResponseSession - Wrong types for `modalities`, `inputAudioFormat`, `outputAudioFormat`, `turnDetection`
4. RealtimeConversationMCPCallItem - Wrong optionality for `approvalRequestId` and `output`

## Total Issues: 8 fields across 4 structs

These are all minor type/optionality corrections. The overall structure and field names are correct.
