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
  MEMORY_EXTRACTION: `You are analyzing a conversation between a dementia patient and their AI companion (reMIND).

Extract important information that should be remembered for future conversations. For each piece of memorable information, provide a JSON object.

Focus on:
- People mentioned (names, relationships, roles)
- Routines and habits (daily activities, preferences)
- Events that happened or are coming up (visits, appointments, calls)
- Health-related mentions (NOT diagnoses - just what was said)
- Emotional states or concerns expressed
- Preferences and likes/dislikes
- Places and locations mentioned

For each memory, extract:
{
  "content": "Natural language description of what to remember",
  "keywords": ["open", "vocabulary", "tags"],
  "contextDescription": "Brief context explaining why this matters for future conversations",
  "suggestedType": "fact|episode|routine|preference|concern|relationship",
  "suggestedCategories": ["family", "health", "routine", "emotion", "location", "interest"],
  "temporalRelevance": "past|ongoing|future|timeless",
  "eventDate": "ISO date string if applicable, null otherwise",
  "emotionalTone": "positive|negative|neutral|anxious|null",
  "relatedTo": ["keywords that might connect to other memories"],
  "confidence": 0.0-1.0
}

Guidelines:
- Only extract facts explicitly stated or strongly implied
- Do NOT infer medical diagnoses
- Preserve the patient's own words for preferences when possible
- Note if information seems uncertain (lower confidence)
- Include relationship context (e.g., "Sarah" -> "daughter Sarah")

Respond with a JSON array of extracted memories. If nothing memorable, return empty array [].
Only output valid JSON, no other text.`,

  /**
   * Brief conversation summary generation.
   * Creates 1-2 sentence summaries for session storage.
   *
   * @usedBy SummarizationService.summarize()
   * @model conversation-summarizer deployment (Azure OpenAI)
   * @temperature 0.3
   * @maxTokens 100
   */
  CONVERSATION_SUMMARIZATION: `Summarize this conversation in 1-2 sentences. Be brief and factual.`,

  /**
   * Templates for formatting memory context injected into assistant prompts.
   * Used to structure memories in a readable format for the LLM.
   *
   * @usedBy RetrievalService.formatGreetingContext(), formatQueryResults()
   */
  CONTEXT_TEMPLATES: {
    /** Main header for greeting context (session initialization) */
    GREETING_HEADER: '## What You Know About This User',

    /** Section headers for organized memory display */
    SECTION_KEY_PEOPLE: '### Key People',
    SECTION_DAILY_LIFE: '### Daily Life',
    SECTION_COMING_UP: '### Coming Up',
    SECTION_RECENT_CONVERSATIONS: '### Recent Conversations',
    SECTION_CONCERNS: '### Things to Be Aware Of',

    /** Section header for caregiver-provided facts */
    SECTION_CAREGIVER_FACTS: '## Caregiver-Provided Information',

    /** Query results header template */
    queryResultsHeader: (query: string): string =>
      `## Relevant Memories for "${query}"`,

    /** Empty query results message */
    noMemoriesFound: (query: string): string =>
      `No memories found matching "${query}"`,
  },
} as const;

/** Type for the Prompts object */
export type PromptsType = typeof Prompts;
