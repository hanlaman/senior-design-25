/**
 * Centralized LLM Prompts for reMIND Backend API
 *
 * All prompts sent to LLMs are defined here for:
 * - Easy auditing and review of AI behavior
 * - Consistent prompt engineering across services
 * - Single source of truth for LLM instructions
 */

export const Prompts = {
  /**
   * Memory extraction from patient-assistant conversations.
   * Extracts structured memories (people, routines, events, etc.) from transcripts.
   *
   * @usedBy ExtractionService.callExtractionLLM()
   * @model conversation-summarizer deployment (Azure OpenAI)
   * @temperature 0.3
   * @maxTokens 2000
   */
  MEMORY_EXTRACTION: `You are analyzing a conversation between a dementia patient and their AI voice companion (reMIND). Your job is to extract information worth remembering for future conversations.

Extract each distinct piece of memorable information as a JSON object. Focus on what would help the companion be more helpful and personalized in future sessions.

## What to Extract

**People & Relationships**
- Names, relationships, roles (e.g., "daughter Sarah", "Dr. Patel", "neighbor Jim")
- Details about these people (visits, phone calls, what the user said about them)

**Routines & Preferences**
- Daily habits, favorite activities, food preferences, TV shows, music
- What calms or comforts the user
- What agitates or upsets the user

**Events & Plans**
- Appointments, visits, outings — past or upcoming
- Milestones, birthdays, anniversaries mentioned

**Places**
- Home details, frequently visited locations, places with emotional significance

**Health Observations** (not diagnoses)
- What the user reports feeling ("my knee hurts", "I slept well")
- Mentions of medications or treatments in the user's own words

**Emotional & Cognitive Observations**
- Mood during the conversation (happy reminiscing, anxious about something, frustrated)
- Topics that seemed to comfort or distress the user
- Repeated questions within the session (note the topic, not the repetition count)
- Moments of confusion or disorientation and what triggered them

## Output Format

For each memory:
{
  "content": "Natural language description — use the patient's own words where possible",
  "keywords": ["relevant", "search", "terms"],
  "contextDescription": "Why this matters for future conversations",
  "suggestedType": "fact|episode|routine|preference|concern|relationship",
  "suggestedCategories": ["family", "health", "routine", "emotion", "location", "interest", "cognitive"],
  "temporalRelevance": "past|ongoing|future|timeless",
  "eventDate": "ISO date string if a specific date is mentioned or clearly implied, null otherwise",
  "emotionalTone": "positive|negative|neutral|anxious|null",
  "relatedTo": ["keywords connecting to other potential memories"],
  "confidence": 0.0-1.0
}

## Confidence Guidelines
- 0.9-1.0: Explicitly and clearly stated ("My daughter's name is Sarah")
- 0.7-0.8: Strongly implied or stated in passing ("Sarah called again" when Sarah is known to be a daughter)
- 0.5-0.6: Implied but somewhat ambiguous ("I think I used to...")
- Below 0.5: Do not extract — too uncertain to be useful

## Rules
- Only extract facts explicitly stated or strongly implied — never infer
- Do NOT infer medical diagnoses from symptoms
- Preserve the patient's own words for preferences and feelings
- Include relationship context with names (e.g., "daughter Sarah", not just "Sarah")
- If a topic came up that clearly comforted or upset the user, note that as a separate memory with suggestedType "preference" or "concern"

Respond ONLY with a JSON array. If nothing memorable, return [].`,

  /**
   * Brief conversation summary generation.
   * Creates structured summaries for session storage and caregiver review.
   *
   * @usedBy SummarizationService.summarize()
   * @model conversation-summarizer deployment (Azure OpenAI)
   * @temperature 0.3
   * @maxTokens 200
   */
  CONVERSATION_SUMMARIZATION: `Summarize this conversation between a dementia patient and their AI companion (reMIND). Write a brief summary for the patient's caregiver.

Include:
1. **Topics discussed** — What the patient talked about or asked about (1-2 sentences).
2. **Mood** — The patient's general emotional state during the conversation (one word or short phrase: e.g., "calm and cheerful", "anxious about an appointment", "confused but redirectable").
3. **Notable observations** — Anything a caregiver should know: repeated questions about a specific topic, expressed concerns, mentions of pain or discomfort, confusion about time/place/people. Omit this line if nothing notable.

Format:
Topics: ...
Mood: ...
Notable: ...

Keep the entire summary under 100 words. Be factual — do not interpret or diagnose.`,

  /**
   * Templates for formatting memory context injected into assistant prompts.
   * Used to structure memories in a readable format for the LLM.
   *
   * @usedBy RetrievalService.formatGreetingContext(), formatQueryResults()
   */
  CONTEXT_TEMPLATES: {
    /** Main header for greeting context (session initialization) */
    GREETING_HEADER: '## What You Remember About This Person',

    /** Section headers for organized memory display */
    SECTION_KEY_PEOPLE: '### Important People in Their Life',
    SECTION_DAILY_LIFE: '### Routines & Preferences',
    SECTION_COMING_UP: '### Upcoming Events',
    SECTION_RECENT_CONVERSATIONS: '### What You Talked About Recently',
    SECTION_CONCERNS: '### Things to Be Sensitive About',

    /** Section header for caregiver-provided facts — these are verified and authoritative */
    SECTION_CAREGIVER_FACTS:
      '## Verified Facts from Their Caregiver (ground truth — always trust these over memories)',

    /** Query results header template */
    queryResultsHeader: (query: string): string =>
      `## What You Remember About "${query}"`,

    /** Empty query results message */
    noMemoriesFound: (query: string): string =>
      `You don't have any memories related to "${query}". Consider asking the user directly, or suggest they check with their caregiver.`,
  },
} as const;

/** Type for the Prompts object */
export type PromptsType = typeof Prompts;
