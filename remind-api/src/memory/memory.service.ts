import { Injectable, Logger } from '@nestjs/common';
import { db, Database } from '../db';
import { Selectable, sql } from 'kysely';
import { EmbeddingService } from './embedding.service';
import {
  CreateMemoryInput,
  MemoryRecord,
  MemoryLinkRecord,
} from './dto/memory.dto';

type PatientMemoryRow = Selectable<Database['patientMemory']>;

@Injectable()
export class MemoryService {
  private readonly logger = new Logger(MemoryService.name);

  constructor(private readonly embeddingService: EmbeddingService) {}

  /**
   * Create a new memory record
   */
  async createMemory(input: CreateMemoryInput): Promise<MemoryRecord | null> {
    const now = new Date();

    // Generate embedding for the content
    const embeddingArray = await this.embeddingService.generateEmbedding(
      input.content,
    );
    const embeddingBuffer = embeddingArray
      ? this.embeddingService.embeddingToBuffer(embeddingArray)
      : null;

    try {
      // Build values object - handle embedding specially for MSSQL VARBINARY
      const values: Record<string, unknown> = {
        patientId: input.patientId,
        content: input.content,
        keywords: input.keywords ? JSON.stringify(input.keywords) : null,
        contextDescription: input.contextDescription ?? null,
        suggestedType: input.suggestedType ?? null,
        suggestedCategories: input.suggestedCategories
          ? JSON.stringify(input.suggestedCategories)
          : null,
        temporalRelevance: input.temporalRelevance ?? null,
        eventDate: input.eventDate ? new Date(input.eventDate) : null,
        emotionalTone: input.emotionalTone ?? null,
        confidence: input.confidence ?? 1.0,
        sourceSessionId: input.sourceSessionId ?? null,
        mentionCount: 1,
        firstMentioned: now,
        lastMentioned: now,
        isActive: true,
      };

      // For VARBINARY column, use explicit cast to avoid type conversion issues
      if (embeddingBuffer) {
        values.embedding = embeddingBuffer;
      } else {
        // Use CAST(NULL AS VARBINARY(MAX)) for MSSQL compatibility
        values.embedding = sql`CAST(NULL AS VARBINARY(MAX))`
      }

      await db
        .insertInto('patientMemory')
        .values(values as any)
        .execute();

      // Fetch the created memory
      const created = await db
        .selectFrom('patientMemory')
        .selectAll()
        .where('patientId', '=', input.patientId)
        .where('content', '=', input.content)
        .where('firstMentioned', '=', now)
        .executeTakeFirst();

      if (!created) {
        return null;
      }

      return this.mapToMemoryRecord(created);
    } catch (error) {
      this.logger.error(`Failed to create memory: ${error}`);
      return null;
    }
  }

  /**
   * Update an existing memory (merge new information)
   */
  async updateMemory(
    memoryId: string,
    updates: {
      keywords?: string[];
      contextDescription?: string;
      confidence?: number;
      incrementMentionCount?: boolean;
    },
  ): Promise<boolean> {
    try {
      const updateValues: Record<string, any> = {
        updatedAt: new Date(),
        lastMentioned: new Date(),
      };

      if (updates.keywords) {
        // Merge keywords with existing
        const existing = await this.getMemoryById(memoryId);
        if (existing) {
          const mergedKeywords = [
            ...new Set([...(existing.keywords || []), ...updates.keywords]),
          ];
          updateValues.keywords = JSON.stringify(mergedKeywords);
        }
      }

      if (updates.contextDescription) {
        updateValues.contextDescription = updates.contextDescription;
      }

      if (updates.confidence !== undefined) {
        updateValues.confidence = updates.confidence;
      }

      await db
        .updateTable('patientMemory')
        .set(updateValues)
        .where('id', '=', memoryId)
        .execute();

      if (updates.incrementMentionCount) {
        await db
          .updateTable('patientMemory')
          .set((eb) => ({
            mentionCount: eb('mentionCount', '+', 1),
          }))
          .where('id', '=', memoryId)
          .execute();
      }

      return true;
    } catch (error) {
      this.logger.error(`Failed to update memory ${memoryId}: ${error}`);
      return false;
    }
  }

  /**
   * Get a memory by ID
   */
  async getMemoryById(memoryId: string): Promise<MemoryRecord | null> {
    const memory = await db
      .selectFrom('patientMemory')
      .selectAll()
      .where('id', '=', memoryId)
      .executeTakeFirst();

    return memory ? this.mapToMemoryRecord(memory) : null;
  }

  /**
   * Get all active memories for a patient
   */
  async getMemoriesForPatient(patientId: string): Promise<MemoryRecord[]> {
    const memories = await db
      .selectFrom('patientMemory')
      .selectAll()
      .where('patientId', '=', patientId)
      .where('isActive', '=', true)
      .orderBy('lastMentioned', 'desc')
      .execute();

    return memories.map((m) => this.mapToMemoryRecord(m));
  }

  /**
   * Get memories with their embeddings for similarity search
   */
  async getMemoriesWithEmbeddings(
    patientId: string,
  ): Promise<Array<MemoryRecord & { embedding: Buffer | null }>> {
    const memories = await db
      .selectFrom('patientMemory')
      .selectAll()
      .where('patientId', '=', patientId)
      .where('isActive', '=', true)
      .execute();

    return memories.map((m) => ({
      ...this.mapToMemoryRecord(m),
      embedding: m.embedding,
    }));
  }

  /**
   * Get time-relevant memories (events within date range)
   */
  async getTimeRelevantMemories(
    patientId: string,
    daysBack: number = 14,
    daysForward: number = 14,
  ): Promise<MemoryRecord[]> {
    const now = new Date();
    const pastDate = new Date(now.getTime() - daysBack * 24 * 60 * 60 * 1000);
    const futureDate = new Date(
      now.getTime() + daysForward * 24 * 60 * 60 * 1000,
    );

    const memories = await db
      .selectFrom('patientMemory')
      .selectAll()
      .where('patientId', '=', patientId)
      .where('isActive', '=', true)
      .where('eventDate', 'is not', null)
      .where('eventDate', '>=', pastDate)
      .where('eventDate', '<=', futureDate)
      .orderBy('eventDate', 'asc')
      .execute();

    return memories.map((m) => this.mapToMemoryRecord(m));
  }

  /**
   * Get frequently mentioned memories
   */
  async getFrequentMemories(
    patientId: string,
    minMentions: number = 3,
  ): Promise<MemoryRecord[]> {
    const memories = await db
      .selectFrom('patientMemory')
      .selectAll()
      .where('patientId', '=', patientId)
      .where('isActive', '=', true)
      .where('mentionCount', '>=', minMentions)
      .orderBy('mentionCount', 'desc')
      .execute();

    return memories.map((m) => this.mapToMemoryRecord(m));
  }

  /**
   * Soft delete a memory
   */
  async deactivateMemory(memoryId: string): Promise<boolean> {
    try {
      await db
        .updateTable('patientMemory')
        .set({ isActive: false, updatedAt: new Date() })
        .where('id', '=', memoryId)
        .execute();
      return true;
    } catch (error) {
      this.logger.error(`Failed to deactivate memory ${memoryId}: ${error}`);
      return false;
    }
  }

  /**
   * Create a link between two memories
   */
  async createMemoryLink(
    fromMemoryId: string,
    toMemoryId: string,
    linkType: string,
    linkStrength: number = 1.0,
    linkReason?: string,
  ): Promise<MemoryLinkRecord | null> {
    try {
      await db
        .insertInto('memoryLink')
        .values({
          fromMemoryId,
          toMemoryId,
          linkType,
          linkStrength,
          linkReason: linkReason ?? null,
        })
        .execute();

      const created = await db
        .selectFrom('memoryLink')
        .selectAll()
        .where('fromMemoryId', '=', fromMemoryId)
        .where('toMemoryId', '=', toMemoryId)
        .executeTakeFirst();

      return created
        ? {
            id: created.id,
            fromMemoryId: created.fromMemoryId,
            toMemoryId: created.toMemoryId,
            linkType: created.linkType,
            linkStrength: created.linkStrength,
            linkReason: created.linkReason,
            createdAt: created.createdAt,
          }
        : null;
    } catch {
      // Likely duplicate link, ignore
      this.logger.debug(
        `Link already exists or failed: ${fromMemoryId} -> ${toMemoryId}`,
      );
      return null;
    }
  }

  /**
   * Get linked memories for a given memory
   */
  async getLinkedMemories(memoryId: string): Promise<MemoryRecord[]> {
    // Get memories linked from this memory
    const outgoingLinks = await db
      .selectFrom('memoryLink')
      .innerJoin('patientMemory', 'patientMemory.id', 'memoryLink.toMemoryId')
      .selectAll('patientMemory')
      .where('memoryLink.fromMemoryId', '=', memoryId)
      .where('patientMemory.isActive', '=', true)
      .execute();

    // Get memories that link to this memory
    const incomingLinks = await db
      .selectFrom('memoryLink')
      .innerJoin('patientMemory', 'patientMemory.id', 'memoryLink.fromMemoryId')
      .selectAll('patientMemory')
      .where('memoryLink.toMemoryId', '=', memoryId)
      .where('patientMemory.isActive', '=', true)
      .execute();

    const allLinked = [...outgoingLinks, ...incomingLinks];
    const uniqueById = new Map(allLinked.map((m) => [m.id, m]));

    return Array.from(uniqueById.values()).map((m) =>
      this.mapToMemoryRecord(m),
    );
  }

  /**
   * Log extraction results
   */
  async logExtraction(
    sessionId: string,
    memoriesCreated: number,
    memoriesUpdated: number,
    linksCreated: number,
    processingTimeMs: number,
    extractionModel: string,
    error?: string,
  ): Promise<void> {
    await db
      .insertInto('memoryExtractionLog')
      .values({
        sessionId,
        extractedAt: new Date(),
        memoriesCreated,
        memoriesUpdated,
        linksCreated,
        processingTimeMs,
        extractionModel,
        error: error ?? null,
      })
      .execute();
  }

  /**
   * Check if extraction has already been done for a session
   */
  async hasBeenExtracted(sessionId: string): Promise<boolean> {
    const log = await db
      .selectFrom('memoryExtractionLog')
      .select(['id'])
      .where('sessionId', '=', sessionId)
      .where('error', 'is', null)
      .executeTakeFirst();

    return !!log;
  }

  /**
   * Map database row to MemoryRecord
   */
  private mapToMemoryRecord(row: PatientMemoryRow): MemoryRecord {
    return {
      id: row.id,
      patientId: row.patientId,
      content: row.content,
      keywords: row.keywords
        ? (JSON.parse(row.keywords) as string[])
        : null,
      contextDescription: row.contextDescription,
      suggestedType: row.suggestedType,
      suggestedCategories: row.suggestedCategories
        ? (JSON.parse(row.suggestedCategories) as string[])
        : null,
      temporalRelevance: row.temporalRelevance,
      eventDate: row.eventDate,
      emotionalTone: row.emotionalTone,
      confidence: row.confidence,
      sourceSessionId: row.sourceSessionId,
      mentionCount: row.mentionCount,
      firstMentioned: row.firstMentioned,
      lastMentioned: row.lastMentioned,
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    };
  }
}
