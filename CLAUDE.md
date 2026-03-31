# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

reMIND is a wearable AI companion system for dementia support, consisting of three main components:
- **Watch App** (`watchapp/`): Apple Watch voice-activated AI assistant using Azure OpenAI Realtime API
- **Caregiver App** (`caregiverapp/`): iOS app for caregivers to monitor patients, manage reminders, and receive alerts
- **Backend API** (`remind-api/`): NestJS server with MSSQL database for location tracking, safe zones, reminders, and push notifications
- **Infrastructure** (`infra/`): Pulumi IaC for Azure Cognitive Services deployment

## Build & Run Commands

### Backend API (remind-api)
```bash
cd remind-api
npm install
cp .env.example .env
npm run docker:up           # Start MSSQL container (wait ~30s on first run)
npm run db:migrate:kysely   # Run migrations
npm run start:dev           # Dev server at http://localhost:3000
npm run lint                # ESLint with auto-fix
npm run test                # Jest tests
npm run docker:down         # Stop database
```

### Watch App & Caregiver App
Open respective `.xcodeproj` files in Xcode. Both require iOS 18+ and Swift 6.

For the watch app, configure Azure credentials via one of:
1. Edit `watchapp/reMIND Watch App/Configuration/BuildConfiguration.swift` (gitignored)
2. Add `AZURE_API_KEY`, `AZURE_RESOURCE_NAME`, `AZURE_API_VERSION` to Info.plist

### Infrastructure
```bash
cd infra
npm install
pulumi up                   # Deploy Azure resources
```

## Architecture

### Watch App
- **Pattern**: MVVM with protocol-based dependency injection and Swift actors for concurrency
- **Voice Pipeline**: Microphone → AVAudioEngine → WebSocket (Azure OpenAI Realtime) → Speaker
- **Key Services**: `AzureVoiceLiveService` (WebSocket communication), `TranscriptionManager`, `LocationViewModel`, `ReminderService`
- **Audio**: PCM16 at 24kHz with noise reduction and echo cancellation
- **Location**: CoreLocation with geofencing support

### Caregiver App
- **Pattern**: MVVM with `PatientDataProvider` protocol abstraction
- **Data Services**: `MockDataService` for development, swap to production implementation via protocol
- **Features**: Dashboard, MapKit location view, Swift Charts health visualizations, alert management, reminder scheduling

### Backend API
- **Framework**: NestJS 11 with modular structure
- **Database**: MSSQL via Kysely (type-safe query builder)
- **Auth**: Better-Auth integration
- **Modules**: `location/`, `safezone/`, `reminder/`, `apns/`, `patient-fact/`, `conversation/`, `memory/`
- **Migrations**: `remind-api/src/db/migrations/`

### Data Flow
```
Apple Watch ← WebSocket → Azure OpenAI Realtime API
Apple Watch → Backend API → Caregiver App (via polling/push)
```

## Key Files

- `watchapp/reMIND Watch App/Services/AzureVoiceLive/` - Azure Realtime WebSocket SDK
- `watchapp/reMIND Watch App/ViewModels/VoiceViewModel.swift` - Main voice assistant logic
- `caregiverapp/caregiverapp/Services/Protocols/PatientDataProvider.swift` - Data abstraction protocol
- `remind-api/src/app.module.ts` - API module registration
- `remind-api/src/db/migrations/` - Database schema migrations

## LLM Prompts

All LLM system prompts and tool descriptions are centralized for easy review and modification:

### Watch App
- **File**: `watchapp/reMIND Watch App/Configuration/LLMPrompts.swift`
- **Contents**:
  - `assistantSystemPrompt` - Main reMIND assistant persona and behavior guidelines
  - `Tools.getCurrentTime` - Tool description for time retrieval
  - `Tools.getSessionTranscript` - Tool description for conversation history
  - `Tools.getUserMemories` - Tool description for memory search

### Backend API
- **File**: `remind-api/src/prompts/index.ts`
- **Contents**:
  - `MEMORY_EXTRACTION` - Prompt for extracting memories from conversations
  - `CONVERSATION_SUMMARIZATION` - Prompt for summarizing sessions
  - `CONTEXT_TEMPLATES` - Templates for formatting memory context in prompts

## Testing

- **API**: `npm run test` (Jest)
- **iOS/watchOS**: XCTest via Xcode (Cmd+U)
- **Caregiver Demo**: `MockDataService` has simulation methods: `simulateFall()`, `simulateGeofenceExit()`, `simulateHighHeartRate()`, `simulateLowHeartRate()`
