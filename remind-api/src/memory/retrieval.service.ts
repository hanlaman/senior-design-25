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

  // Scoring weights
  private readonly SIMILARITY_WEIGHT = 0.5;
  private readonly RECENCY_WEIGHT = 0.3;
  private readonly MENTION_WEIGHT = 0.2;

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

    // Score memories based on query (if provided), recency, and mention count
    let scoredMemories: ScoredMemory[];

    if (options.query) {
      scoredMemories = await this.scoreMemoriesWithQuery(
        allMemories,
        options.query,
        maxMemories,
      );
    } else {
      scoredMemories = this.scoreMemoriesWithoutQuery(allMemories, maxMemories);
    }

    // Also include time-relevant memories (upcoming/recent events)
    const timeRelevant = await this.memoryService.getTimeRelevantMemories(
      patientId,
      this.TIME_RELEVANCE_DAYS,
      this.TIME_RELEVANCE_DAYS,
    );

    // Merge time-relevant memories that aren't already in the list
    const existingIds = new Set(scoredMemories.map((m) => m.id));
    for (const memory of timeRelevant) {
      if (!existingIds.has(memory.id)) {
        scoredMemories.push({
          ...memory,
          similarity: 0,
          recencyScore: 1.0, // Time-relevant memories get high recency score
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
          totalScore: 0.5, // Lower score for linked memories
        });
      }
    }

    // Final limit
    scoredMemories = scoredMemories.slice(0, maxMemories);

    // Format for prompt injection
    const formattedContext = this.formatMemoryContext(
      scoredMemories,
      options.sessionType,
    );

    return {
      memories: scoredMemories,
      formattedContext,
      retrievedAt: new Date(),
    };
  }

  /**
   * Score memories using semantic similarity to a query
   */
  private async scoreMemoriesWithQuery(
    memories: Array<MemoryRecord & { embedding: Buffer | null }>,
    query: string,
    maxMemories: number,
  ): Promise<ScoredMemory[]> {
    const queryEmbedding = await this.embeddingService.generateEmbedding(query);

    if (!queryEmbedding) {
      return this.scoreMemoriesWithoutQuery(memories, maxMemories);
    }

    const now = new Date();
    const maxAge = 90 * 24 * 60 * 60 * 1000; // 90 days in ms

    return memories
      .map((memory) => {
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

        // Calculate recency score (0-1, higher is more recent)
        const age = now.getTime() - memory.lastMentioned.getTime();
        const recencyScore = Math.max(0, 1 - age / maxAge);

        // Calculate mention bonus (capped)
        const mentionBonus = Math.min(memory.mentionCount / 10, 1);

        // Total score
        const totalScore =
          similarity * this.SIMILARITY_WEIGHT +
          recencyScore * this.RECENCY_WEIGHT +
          mentionBonus * this.MENTION_WEIGHT;

        return {
          ...memory,
          embedding: undefined, // Remove embedding from response
          similarity,
          recencyScore,
          totalScore,
        } as ScoredMemory;
      })
      .sort((a, b) => (b.totalScore || 0) - (a.totalScore || 0))
      .slice(0, maxMemories);
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
  private formatMemoryContext(
    memories: ScoredMemory[],
    sessionType?: string,
  ): string {
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
    const episodes = groups.get('episode') || [];
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

    // Build final context
    if (sections.length === 0) {
      return '';
    }

    return '## What You Know About This User\n\n' + sections.join('\n\n');
  }
}
