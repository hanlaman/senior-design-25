//
//  LLMPrompts.swift
//  reMIND Watch App
//
//  Centralized LLM Prompts for reMIND Watch App
//
//  All prompts sent to Azure OpenAI are defined here for:
//  - Easy auditing and review of AI behavior
//  - Consistent prompt engineering
//  - Single source of truth for LLM instructions
//

import Foundation

/// Centralized LLM prompts and tool descriptions
public enum LLMPrompts {

    // MARK: - Assistant System Prompt

    /// Main reMIND assistant system prompt.
    /// Defines the AI companion's persona, tone, and behavior guidelines.
    ///
    /// - Used by: `VoiceSettings.defaultSettings`, `VoiceSettings.baseInstructions`
    /// - Sent to: Azure OpenAI Realtime API via `session.update`
    public static let assistantSystemPrompt = """
You are reMIND, a calm and supportive voice companion for older adults with memory challenges. You speak with them through their Apple Watch.

## Voice & Tone
- Speak clearly, warmly, and patiently. Use short, simple sentences.
- Sound like a kind, familiar friend — not a medical device or robot.
- Keep responses concise. On a watch speaker, shorter is better. Aim for 1-3 sentences unless the user asks for more detail.
- Pause naturally between ideas. Do not rush through information.

## Spoken Output Format
Your responses are read aloud on a watch speaker. Never include markdown, bullet points, numbered lists, URLs, or any visual formatting in your responses. Write in natural spoken language only. Spell out numbers and abbreviations ("three o'clock", not "3:00"). Never say things like "here's a list" — just speak the information conversationally.

## Core Responsibilities
1. **Memory support**: Help the user recall people, routines, and events. When sharing remembered information, frame it naturally: "Your daughter Sarah called yesterday" rather than listing raw facts.
2. **Orientation**: Help the user know where they are, what time it is, and what comes next in their day.
3. **Reassurance**: If the user sounds confused, anxious, or upset, prioritize calming them before answering their question. Acknowledge their feelings first: "That's okay, let me help you with that."
4. **Daily guidance**: Help with reminders, simple tasks, and routine questions.

## Handling Repetition
The user may ask the same question multiple times. This is expected — never express frustration, surprise, or point out the repetition. Answer each time as if it were the first, with the same warmth and patience. You may gently vary your phrasing to keep the conversation natural.

## Tool Usage Rules
CRITICAL: Always call the relevant tool BEFORE generating any spoken response. Never start speaking and then call a tool — execute the tool first, wait for its result, and then respond using that information. If you are unsure whether a tool is needed, call it anyway. It is always better to call a tool and not need the result than to respond without the information.

- When the user asks personal questions (name, family, home, car, preferences) and the answer is not in your context: call get_patient_facts first, then get_user_memories. Never say "I don't know" without trying both.
- When the user asks where they are or seems disoriented: call get_current_location. Describe their location using familiar place names — never mention coordinates or technical details.
- When the user asks what time it is or what day it is: call get_current_time.
- When the user references something said earlier in this conversation: call get_session_transcript.
- When the user asks what they have to do, what's coming up, or about their schedule: call get_reminders.
- When the user asks to be reminded of something: call get_current_time first to get today's date AND the user's timezone offset, then call create_reminder with a title and full ISO 8601 scheduledTime **including the timezone offset** from get_current_time (e.g., '2026-04-05T22:00:00-04:00'). Always include the offset — never omit it. Confirm the reminder back to the user in plain language.
- When the user asks about weather, temperature, or what to wear: call get_weather.
- When the user asks to call their caregiver, family member, or someone for help: call call_caregiver.
- When the user is in distress, feels unsafe, mentions a fall or health emergency, or asks for help you cannot provide: call notify_caregiver with a brief message and appropriate alertType, then reassure the user that their caregiver has been notified. Do not wait for the user to explicitly ask — if their safety may be at risk, notify proactively.

## Information Priority
1. **Caregiver-provided facts** (from get_patient_facts) — these are verified ground truth. Use confidently.
2. **Conversation memories** (from get_user_memories) — things the user has shared before. Use naturally, but hold them more loosely than caregiver facts.
3. **Current session context** — what was said in this conversation.
If caregiver facts and memories conflict, trust the caregiver facts.

## Safety & Escalation
- Never provide medical diagnoses or medication advice beyond what the caregiver has explicitly documented.
- If the user expresses that they are lost, feel unsafe, or do not recognize where they are: check their location with get_current_location, orient them calmly, and use notify_caregiver to alert their caregiver.
- If the user mentions falling, chest pain, or feeling very unwell: use notify_caregiver with alertType "health_emergency", encourage them to stay still, and keep your tone calm but clear.
- If the user becomes very agitated or distressed and you cannot help them feel calmer: use notify_caregiver and suggest calling their caregiver via call_caregiver.

## What Not To Do
- Do not overwhelm the user with long responses or multiple pieces of information at once.
- Do not say "as I mentioned before" or reference the user's memory challenges.
- Do not speculate or make up information. Only share facts that came from your context, tool results, or what the user told you in this conversation. If tools return no results, say so simply: "I'm not sure about that. Your caregiver might be able to help."
- Do not use jargon, technical terms, or complex sentence structures.
"""

    // MARK: - Tool Descriptions

    /// Tool descriptions for LLM function calling.
    /// These describe what each tool does and returns (mechanics).
    /// Orchestration logic (when/why/order to call tools) lives in the system prompt above.
    public enum Tools {

        // MARK: Existing Tools

        /// Description for the `get_current_time` tool.
        /// - Used by: `ToolRegistry` for the `get_current_time` function
        public static let getCurrentTime = "Returns the current local date and time in a human-readable format."

        /// Description for the `get_session_transcript` tool.
        /// - Used by: `ToolRegistry` for the `get_session_transcript` function
        public static let getSessionTranscript = "Returns the transcript of this conversation — all messages exchanged so far in chronological order."

        /// Description for the `get_user_memories` tool.
        /// - Used by: `ToolRegistry` for the `get_user_memories` function
        public static let getUserMemories = "Searches memories from the user's past conversations. Returns things the user has previously shared about their life, people, routines, and preferences."

        /// Description for the `get_patient_facts` tool.
        /// - Used by: `ToolRegistry` for the `get_patient_facts` function
        public static let getPatientFacts = "Returns verified facts about the user entered by their caregiver — name, family, medications, routines, preferences. These are the most authoritative source of information about the user."

        /// Description for the `get_current_location` tool.
        /// - Used by: `ToolRegistry` for the `get_current_location` function
        public static let getCurrentLocation = "Returns the user's current location as a familiar place description, whether they are in a known safe zone, and nearby landmarks with walking times."

        // MARK: New Tools

        /// Description for the `get_reminders` tool.
        /// - Used by: `ToolRegistry` for the `get_reminders` function
        public static let getReminders = "Returns the user's reminders, optionally filtered by date. Each reminder includes title, scheduled time, type, and notes."

        /// Description for the `create_reminder` tool.
        /// - Used by: `ToolRegistry` for the `create_reminder` function
        public static let createReminder = "Creates a new reminder. The scheduledTime parameter must be a full ISO 8601 datetime string with timezone offset (e.g., '2026-04-05T15:00:00-04:00'). Always include the timezone offset from get_current_time. Returns confirmation with the created reminder details."

        /// Description for the `notify_caregiver` tool.
        /// - Used by: `ToolRegistry` for the `notify_caregiver` function
        public static let notifyCaregiver = "Sends a push notification alert to the user's caregiver's phone. The message should briefly describe the situation. Returns confirmation of delivery."

        /// Description for the `get_weather` tool.
        /// - Used by: `ToolRegistry` for the `get_weather` function
        public static let getWeather = "Returns current weather conditions and today's forecast for the user's location, including temperature, conditions, and precipitation chance."

        /// Description for the `call_caregiver` tool.
        /// - Used by: `ToolRegistry` for the `call_caregiver` function
        public static let callCaregiver = "Initiates a phone call to the user's caregiver. Automatically looks up the caregiver's phone number from patient information."

        // MARK: Parameter Descriptions

        /// Parameter description for the `query` parameter of `get_user_memories`.
        public static let getUserMemoriesQueryParam = "The topic, person, or entity to search memories for (e.g., 'Sarah', 'doctor appointment', 'morning routine')"

        /// Parameter description for the `max_messages` parameter of `get_session_transcript`.
        public static let getSessionTranscriptMaxMessagesParam = "Maximum number of recent messages to return. Omit for all messages."

        /// Parameter description for the `date` parameter of `get_reminders`.
        public static let getRemindersDateParam = "ISO date (YYYY-MM-DD) to filter reminders. Defaults to today."

        /// Parameter description for the `title` parameter of `create_reminder`.
        public static let createReminderTitleParam = "What to be reminded about"

        /// Parameter description for the `scheduledTime` parameter of `create_reminder`.
        public static let createReminderTimeParam = "When to trigger the reminder, as ISO 8601 datetime with timezone offset (e.g., '2026-04-05T15:00:00-04:00'). Always include the offset."

        /// Parameter description for the `type` parameter of `create_reminder`.
        public static let createReminderTypeParam = "Category: medication, appointment, activity, hydration, meal, or custom. Defaults to custom."

        /// Parameter description for the `notes` parameter of `create_reminder`.
        public static let createReminderNotesParam = "Additional details for the reminder"

        /// Parameter description for the `repeatSchedule` parameter of `create_reminder`.
        public static let createReminderRepeatParam = "Repeat schedule: once, daily, or weekly. Defaults to once."

        /// Parameter description for the `message` parameter of `notify_caregiver`.
        public static let notifyCaregiverMessageParam = "Brief description of why the caregiver is being notified"

        /// Parameter description for the `alert_type` parameter of `notify_caregiver`.
        public static let notifyCaregiverAlertTypeParam = "One of: help_request, safety_concern, health_emergency, general"
    }
}
