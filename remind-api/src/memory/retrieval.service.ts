import { Injectable, Logger } from '@nestjs/common';
import { MemoryService } from './memory.service';
import { EmbeddingService } from './embedding.service';
import {
  MemoryRecord,
  ScoredMemory,
  MemoryContextResponse,
  GetMemoryContextQuery,
} from './dto/memory.dto';

@Injectable()
export class RetrievalService {
  private readonly logger = new Logger(RetrievalService.name);

  // Scoring weights for greeting context (no query)
  private readonly RECENCY_WEIGHT = 0.6;
  private readonly MENTION_WEIGHT = 0.4;

  // Query-based retrieval settings
  private readonly QUERY_MIN_SIMILARITY = 0.3; // Minimum similarity to include
  private readonly QUERY_MAX_RESULTS = 5; // Fewer, more focused results for queries

  // Default limits
  private readonly DEFAULT_MAX_MEMORIES = 15;
  private readonly TIME_RELEVANCE_DAYS = 14;

  constructor(
    private readonly memoryService: MemoryService,
    private readonly embeddingService: EmbeddingService,
  ) {}

  /**
   * Get memory context for a patient
   */
  async getMemoryContext(
    patientId: string,
    options: GetMemoryContextQuery = {},
  ): Promise<MemoryContextResponse> {
    const maxMemories = options.maxMemories || this.DEFAULT_MAX_MEMORIES;

    // Get all memories with embeddings for scoring
    const allMemories =
      await this.memoryService.getMemoriesWithEmbeddings(patientId);

    if (allMemories.length === 0) {
      return {
        memories: [],
        formattedContext: '',
        retrievedAt: new Date(),
      };
    }

    let scoredMemories: ScoredMemory[];

    if (options.query) {
      // Query-based retrieval: return only semantically relevant memories
      scoredMemories = await this.scoreMemoriesWithQuery(
        allMemories,
        options.query,
      );
      // Don't add time-relevant or linked memories for focused queries
    } else {
      // Greeting context: broader context with recency/mention scoring
      scoredMemories = this.scoreMemoriesWithoutQuery(allMemories, maxMemories);

      // Add time-relevant memories (upcoming/recent events)
      const timeRelevant = await this.memoryService.getTimeRelevantMemories(
        patientId,
        this.TIME_RELEVANCE_DAYS,
        this.TIME_RELEVANCE_DAYS,
      );

      const existingIds = new Set(scoredMemories.map((m) => m.id));
      for (const memory of timeRelevant) {
        if (!existingIds.has(memory.id)) {
          scoredMemories.push({
            ...memory,
            similarity: 0,
            recencyScore: 1.0,
            totalScore: 0.8,
          });
        }
      }

      // Re-sort and limit
      scoredMemories.sort((a, b) => (b.totalScore || 0) - (a.totalScore || 0));
      scoredMemories = scoredMemories.slice(0, maxMemories);

      // Fetch linked memories for top results (1 hop)
      const linkedMemories = await this.fetchLinkedMemories(
        scoredMemories.slice(0, 5),
      );
      const linkedIds = new Set(scoredMemories.map((m) => m.id));
      for (const linked of linkedMemories) {
        if (!linkedIds.has(linked.id)) {
          scoredMemories.push({
            ...linked,
            totalScore: 0.5,
          });
        }
      }

      // Final limit
      scoredMemories = scoredMemories.slice(0, maxMemories);
    }

    // Format for prompt injection
    const formattedContext = options.query
      ? this.formatQueryResults(scoredMemories, options.query)
      : this.formatGreetingContext(scoredMemories);

    return {
      memories: scoredMemories,
      formattedContext,
      retrievedAt: new Date(),
    };
  }

  /**
   * Format query results - simple list of matching memories
   */
  private formatQueryResults(memories: ScoredMemory[], query: string): string {
    if (memories.length === 0) {
      return `No memories found matching "${query}"`;
    }

    const items = memories.map((m) => `- ${m.content}`).join('\n');
    return `## Relevant Memories for "${query}"\n\n${items}`;
  }

  /**
   * Score memories using semantic similarity to a query.
   * Only returns memories above a similarity threshold, sorted by similarity.
   */
  private async scoreMemoriesWithQuery(
    memories: Array<MemoryRecord & { embedding: Buffer | null }>,
    query: string,
  ): Promise<ScoredMemory[]> {
    const queryEmbedding = await this.embeddingService.generateEmbedding(query);

    if (!queryEmbedding) {
      this.logger.warn('Failed to generate query embedding, returning empty');
      return [];
    }

    const allScored = memories.map((memory) => {
      // Calculate similarity
      let similarity = 0;
      if (memory.embedding) {
        const memoryEmbedding = this.embeddingService.bufferToEmbedding(
          memory.embedding,
        );
        similarity = this.embeddingService.cosineSimilarity(
          queryEmbedding,
          memoryEmbedding,
        );
      }

      return {
        ...memory,
        embedding: undefined,
        similarity,
        totalScore: similarity,
      } as ScoredMemory;
    });

    // Log all similarities for debugging
    this.logger.log(
      `Query "${query}" similarity scores:\n` +
        allScored
          .sort((a, b) => (b.similarity ?? 0) - (a.similarity ?? 0))
          .map((m) => `  ${(m.similarity ?? 0).toFixed(3)}: ${m.content.substring(0, 50)}`)
          .join('\n'),
    );

    const scored = allScored
      // Filter by minimum similarity threshold
      .filter((m) => (m.similarity ?? 0) >= this.QUERY_MIN_SIMILARITY)
      // Sort by similarity descending
      .sort((a, b) => (b.similarity || 0) - (a.similarity || 0))
      // Return limited results
      .slice(0, this.QUERY_MAX_RESULTS);

    this.logger.log(
      `Query "${query}" matched ${scored.length} memories above threshold ${this.QUERY_MIN_SIMILARITY}`,
    );

    return scored;
  }

  /**
   * Score memories without a query (for greeting context)
   */
  private scoreMemoriesWithoutQuery(
    memories: Array<MemoryRecord & { embedding: Buffer | null }>,
    maxMemories: number,
  ): ScoredMemory[] {
    const now = new Date();
    const maxAge = 90 * 24 * 60 * 60 * 1000;

    return memories
      .map((memory) => {
        const age = now.getTime() - memory.lastMentioned.getTime();
        const recencyScore = Math.max(0, 1 - age / maxAge);
        const mentionBonus = Math.min(memory.mentionCount / 10, 1);

        // Without query, weight recency and mentions more heavily
        const totalScore = recencyScore * 0.6 + mentionBonus * 0.4;

        return {
          ...memory,
          embedding: undefined,
          similarity: 0,
          recencyScore,
          totalScore,
        } as ScoredMemory;
      })
      .sort((a, b) => (b.totalScore || 0) - (a.totalScore || 0))
      .slice(0, maxMemories);
  }

  /**
   * Fetch linked memories for a set of memories
   */
  private async fetchLinkedMemories(
    memories: MemoryRecord[],
  ): Promise<MemoryRecord[]> {
    const linkedSet = new Map<string, MemoryRecord>();

    for (const memory of memories) {
      const linked = await this.memoryService.getLinkedMemories(memory.id);
      for (const l of linked) {
        if (!linkedSet.has(l.id)) {
          linkedSet.set(l.id, l);
        }
      }
    }

    return Array.from(linkedSet.values());
  }

  /**
   * Format memories into a context string for prompt injection
   */
  /**
   * Format greeting context - organized by category for session initialization
   */
  private formatGreetingContext(memories: ScoredMemory[]): string {
    if (memories.length === 0) {
      return '';
    }

    // Group memories by suggested type for organization
    const groups = new Map<string, ScoredMemory[]>();

    for (const memory of memories) {
      const type = memory.suggestedType || 'general';
      if (!groups.has(type)) {
        groups.set(type, []);
      }
      groups.get(type)!.push(memory);
    }

    // Format sections
    const sections: string[] = [];

    // Key people (relationships)
    const relationships = groups.get('relationship') || [];
    const facts = groups.get('fact') || [];
    const people = [...relationships, ...facts].filter(
      (m) =>
        m.suggestedCategories?.includes('family') ||
        m.keywords?.some((k) =>
          [
            'family',
            'daughter',
            'son',
            'wife',
            'husband',
            'caregiver',
          ].includes(k.toLowerCase()),
        ),
    );
    if (people.length > 0) {
      sections.push(
        '### Key People\n' + people.map((m) => `- ${m.content}`).join('\n'),
      );
    }

    // Daily life (routines, preferences)
    const routines = groups.get('routine') || [];
    const preferences = groups.get('preference') || [];
    const dailyLife = [...routines, ...preferences];
    if (dailyLife.length > 0) {
      sections.push(
        '### Daily Life\n' + dailyLife.map((m) => `- ${m.content}`).join('\n'),
      );
    }

    // Coming up (future events)
    const upcoming = memories.filter(
      (m) =>
        m.temporalRelevance === 'future' ||
        (m.eventDate && m.eventDate > new Date()),
    );
    if (upcoming.length > 0) {
      sections.push(
        '### Coming Up\n' +
          upcoming
            .sort((a, b) => {
              if (!a.eventDate) return 1;
              if (!b.eventDate) return -1;
              return a.eventDate.getTime() - b.eventDate.getTime();
            })
            .map((m) => {
              const dateStr = m.eventDate
                ? m.eventDate.toLocaleDateString('en-US', {
                    weekday: 'long',
                    month: 'short',
                    day: 'numeric',
                  })
                : '';
              return `- ${dateStr ? dateStr + ': ' : ''}${m.content}`;
            })
            .join('\n'),
      );
    }

    // Recent conversations (past episodes)
    const recent = memories.filter(
      (m) =>
        m.suggestedType === 'episode' &&
        m.temporalRelevance !== 'future' &&
        (!m.eventDate || m.eventDate <= new Date()),
    );
    if (recent.length > 0) {
      sections.push(
        '### Recent Conversations\n' +
          recent
            .slice(0, 5)
            .map((m) => `- ${m.content}`)
            .join('\n'),
      );
    }

    // Concerns
    const concerns = groups.get('concern') || [];
    if (concerns.length > 0) {
      sections.push(
        '### Things to Be Aware Of\n' +
          concerns.map((m) => `- ${m.content}`).join('\n'),
      );
    }

    // Note: Other facts (car, hobbies, etc.) are not included in greeting context.
    // They should be retrieved via query-based retrieval (get_user_memories tool).

    // Build final context
    if (sections.length === 0) {
      return '';
    }

    return '## What You Know About This User\n\n' + sections.join('\n\n');
  }
}
