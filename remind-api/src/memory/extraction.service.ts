import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { AzureOpenAI } from 'openai';
import { MemoryService } from './memory.service';
import { EmbeddingService } from './embedding.service';
import { ExtractedMemory, ExtractionResult } from './dto/memory.dto';

interface ConversationMessage {
  role: 'user' | 'assistant';
  content: string;
}

@Injectable()
export class ExtractionService implements OnModuleInit {
  private readonly logger = new Logger(ExtractionService.name);
  private client: AzureOpenAI | null = null;
  private deploymentName: string | null = null;

  // Similarity threshold for considering memories as duplicates
  private readonly SIMILARITY_THRESHOLD = 0.85;

  constructor(
    private readonly memoryService: MemoryService,
    private readonly embeddingService: EmbeddingService,
  ) {}

  onModuleInit() {
    const endpoint = process.env.AZURE_OPENAI_ENDPOINT;
    const apiKey = process.env.AZURE_OPENAI_API_KEY;
    this.deploymentName =
      process.env.AZURE_OPENAI_DEPLOYMENT_NAME || 'conversation-summarizer';

    if (!endpoint || !apiKey) {
      this.logger.warn(
        'Azure OpenAI not configured. Memory extraction disabled.',
      );
      return;
    }

    this.client = new AzureOpenAI({
      endpoint,
      apiKey,
      apiVersion: '2024-08-01-preview',
    });

    this.logger.log('Memory extraction service initialized');
  }

  /**
   * Extract memories from a conversation
   */
  async extractMemories(
    patientId: string,
    sessionId: string,
    messages: ConversationMessage[],
  ): Promise<ExtractionResult> {
    const startTime = Date.now();
    const result: ExtractionResult = {
      sessionId,
      memoriesCreated: 0,
      memoriesUpdated: 0,
      linksCreated: 0,
      processingTimeMs: 0,
      memories: [],
    };

    // Check if already extracted
    if (await this.memoryService.hasBeenExtracted(sessionId)) {
      this.logger.log(`Session ${sessionId} already extracted, skipping`);
      return result;
    }

    if (!this.client || !this.deploymentName) {
      this.logger.warn(
        'Memory extraction skipped - Azure OpenAI not configured',
      );
      return result;
    }

    if (messages.length === 0) {
      return result;
    }

    try {
      // Format transcript
      const transcript = messages
        .map(
          (m) => `${m.role === 'user' ? 'Patient' : 'Assistant'}: ${m.content}`,
        )
        .join('\n');

      // Extract memories using LLM
      const extractedMemories = await this.callExtractionLLM(transcript);
      result.memories = extractedMemories;

      // Get existing memories for deduplication
      const existingMemories =
        await this.memoryService.getMemoriesWithEmbeddings(patientId);

      // Process each extracted memory
      const createdMemoryIds: string[] = [];

      // Batch generate embeddings for all extracted memories (single API call)
      const contents = extractedMemories.map((m) => m.content);
      const embeddings =
        await this.embeddingService.generateEmbeddings(contents);

      const embeddingsAvailable = embeddings.some((e) => e !== null);
      if (!embeddingsAvailable && extractedMemories.length > 0) {
        this.logger.warn(
          'Embeddings unavailable - deduplication disabled. Create Azure OpenAI embedding deployment.',
        );
      }

      for (let i = 0; i < extractedMemories.length; i++) {
        const extracted = extractedMemories[i];
        const newEmbedding = embeddings[i];

        // Check for similar existing memories
        let isDuplicate = false;
        let existingMemoryId: string | null = null;

        if (newEmbedding && existingMemories.length > 0) {
          const similar = this.embeddingService.findMostSimilar(
            newEmbedding,
            existingMemories,
            1,
            this.SIMILARITY_THRESHOLD,
          );

          if (similar.length > 0) {
            isDuplicate = true;
            existingMemoryId = similar[0].id;
          }
        }

        if (isDuplicate && existingMemoryId) {
          // Update existing memory
          await this.memoryService.updateMemory(existingMemoryId, {
            keywords: extracted.keywords,
            confidence: Math.min(1.0, (extracted.confidence ?? 0.8) + 0.1), // Increase confidence
            incrementMentionCount: true,
          });
          result.memoriesUpdated++;
          createdMemoryIds.push(existingMemoryId);
        } else {
          // Create new memory
          const created = await this.memoryService.createMemory({
            patientId,
            content: extracted.content,
            keywords: extracted.keywords,
            contextDescription: extracted.contextDescription,
            suggestedType: extracted.suggestedType,
            suggestedCategories: extracted.suggestedCategories,
            temporalRelevance: extracted.temporalRelevance,
            eventDate: extracted.eventDate,
            emotionalTone: extracted.emotionalTone,
            confidence: extracted.confidence ?? 0.8,
            sourceSessionId: sessionId,
          });

          if (created) {
            result.memoriesCreated++;
            createdMemoryIds.push(created.id);
          }
        }
      }

      // Create links between related memories
      result.linksCreated = await this.createMemoryLinks(
        createdMemoryIds,
        extractedMemories,
        existingMemories.map((m) => m.id),
      );

      result.processingTimeMs = Date.now() - startTime;

      // Log extraction
      await this.memoryService.logExtraction(
        sessionId,
        result.memoriesCreated,
        result.memoriesUpdated,
        result.linksCreated,
        result.processingTimeMs,
        this.deploymentName,
      );

      this.logger.log(
        `Extracted ${result.memoriesCreated} new, ${result.memoriesUpdated} updated, ${result.linksCreated} links for session ${sessionId}`,
      );

      return result;
    } catch (error) {
      const errorMessage =
        error instanceof Error ? error.message : String(error);
      this.logger.error(`Memory extraction failed: ${errorMessage}`);

      // Log the error
      await this.memoryService.logExtraction(
        sessionId,
        0,
        0,
        0,
        Date.now() - startTime,
        this.deploymentName || 'unknown',
        errorMessage,
      );

      return result;
    }
  }

  /**
   * Call LLM to extract memories from transcript
   */
  private async callExtractionLLM(
    transcript: string,
  ): Promise<ExtractedMemory[]> {
    if (!this.client || !this.deploymentName) {
      return [];
    }

    const prompt = `You are analyzing a conversation between a dementia patient and their AI companion (reMIND).

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

Conversation:
${transcript}

Respond with a JSON array of extracted memories. If nothing memorable, return empty array [].
Only output valid JSON, no other text.`;

    try {
      const response = await this.client.chat.completions.create({
        model: this.deploymentName,
        messages: [{ role: 'user', content: prompt }],
        max_tokens: 2000,
        temperature: 0.3,
        response_format: { type: 'json_object' },
      });

      const content = response.choices[0]?.message?.content?.trim();

      if (!content) {
        return [];
      }

      // Parse response - handle both array and object with memories key
      const parsed: unknown = JSON.parse(content);

      let memoriesArray: unknown[];
      if (Array.isArray(parsed)) {
        memoriesArray = parsed;
      } else if (
        typeof parsed === 'object' &&
        parsed !== null &&
        'memories' in parsed &&
        Array.isArray((parsed as { memories: unknown[] }).memories)
      ) {
        memoriesArray = (parsed as { memories: unknown[] }).memories;
      } else {
        return [];
      }

      return memoriesArray.map((m: unknown) => {
        const memory = m as Record<string, unknown>;
        return {
          content: typeof memory.content === 'string' ? memory.content : '',
          keywords: Array.isArray(memory.keywords)
            ? (memory.keywords as string[])
            : [],
          contextDescription:
            typeof memory.contextDescription === 'string'
              ? memory.contextDescription
              : '',
          suggestedType:
            typeof memory.suggestedType === 'string'
              ? memory.suggestedType
              : undefined,
          suggestedCategories: Array.isArray(memory.suggestedCategories)
            ? (memory.suggestedCategories as string[])
            : [],
          temporalRelevance:
            typeof memory.temporalRelevance === 'string'
              ? memory.temporalRelevance
              : undefined,
          eventDate:
            typeof memory.eventDate === 'string' ? memory.eventDate : undefined,
          emotionalTone:
            typeof memory.emotionalTone === 'string'
              ? memory.emotionalTone
              : undefined,
          relatedTo: Array.isArray(memory.relatedTo)
            ? (memory.relatedTo as string[])
            : [],
          confidence:
            typeof memory.confidence === 'number' ? memory.confidence : 0.8,
        };
      });
    } catch (error) {
      this.logger.error(`LLM extraction call failed: ${error}`);
      return [];
    }
  }

  /**
   * Create links between memories based on keywords and relatedTo hints
   */
  private async createMemoryLinks(
    newMemoryIds: string[],
    extractedMemories: ExtractedMemory[],
    _existingMemoryIds: string[],
  ): Promise<number> {
    let linksCreated = 0;

    // Create a map of keywords to memory IDs
    const keywordToMemories = new Map<string, string[]>();

    // Map extracted memories to their IDs (assuming same order)
    for (
      let i = 0;
      i < extractedMemories.length && i < newMemoryIds.length;
      i++
    ) {
      const memory = extractedMemories[i];
      const memoryId = newMemoryIds[i];

      for (const keyword of memory.keywords) {
        const normalized = keyword.toLowerCase();
        if (!keywordToMemories.has(normalized)) {
          keywordToMemories.set(normalized, []);
        }
        keywordToMemories.get(normalized)!.push(memoryId);
      }
    }

    // Create links between memories with shared keywords
    for (const [keyword, memoryIds] of keywordToMemories) {
      if (memoryIds.length > 1) {
        // Link all memories that share this keyword
        for (let i = 0; i < memoryIds.length; i++) {
          for (let j = i + 1; j < memoryIds.length; j++) {
            const link = await this.memoryService.createMemoryLink(
              memoryIds[i],
              memoryIds[j],
              'same_keyword',
              0.8,
              `Both memories mention "${keyword}"`,
            );
            if (link) linksCreated++;
          }
        }
      }
    }

    // Create links based on relatedTo hints
    for (
      let i = 0;
      i < extractedMemories.length && i < newMemoryIds.length;
      i++
    ) {
      const memory = extractedMemories[i];
      const memoryId = newMemoryIds[i];

      for (const related of memory.relatedTo || []) {
        const normalized = related.toLowerCase();
        const relatedMemoryIds = keywordToMemories.get(normalized) || [];

        for (const relatedId of relatedMemoryIds) {
          if (relatedId !== memoryId) {
            const link = await this.memoryService.createMemoryLink(
              memoryId,
              relatedId,
              'related_topic',
              0.7,
              `Memory references "${related}"`,
            );
            if (link) linksCreated++;
          }
        }
      }
    }

    return linksCreated;
  }
}
