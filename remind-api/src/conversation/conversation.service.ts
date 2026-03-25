import { Injectable, Logger } from '@nestjs/common';
import { db } from '../db';
import { SummarizationService } from '../summarization/summarization.service';
import { ExtractionService } from '../memory/extraction.service';

interface ConversationMessageInput {
  azureItemId: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: string;
  sequenceNumber: number;
}

interface CreateConversationInput {
  patientId: string;
  azureSessionId: string;
  startTime: string;
  endTime: string | null;
  messages: ConversationMessageInput[];
}

@Injectable()
export class ConversationService {
  private readonly logger = new Logger(ConversationService.name);

  constructor(
    private readonly summarizationService: SummarizationService,
    private readonly extractionService: ExtractionService,
  ) {}

  async create(data: CreateConversationInput) {
    // Check if session already exists (idempotent upload)
    const existing = await db
      .selectFrom('conversationSession')
      .select(['id'])
      .where('patientId', '=', data.patientId)
      .where('azureSessionId', '=', data.azureSessionId)
      .executeTakeFirst();

    if (existing) {
      this.logger.log(
        `Session ${data.azureSessionId} already exists, returning existing ID`,
      );
      return { success: true, sessionId: existing.id, duplicate: true };
    }

    // Insert session (MSSQL doesn't support RETURNING, so we query after insert)
    await db
      .insertInto('conversationSession')
      .values({
        patientId: data.patientId,
        azureSessionId: data.azureSessionId,
        startTime: new Date(data.startTime),
        endTime: data.endTime ? new Date(data.endTime) : null,
        messageCount: data.messages.length,
      })
      .execute();

    // Query for the inserted session using the unique constraint
    const insertedSession = await db
      .selectFrom('conversationSession')
      .select(['id'])
      .where('patientId', '=', data.patientId)
      .where('azureSessionId', '=', data.azureSessionId)
      .executeTakeFirst();

    if (!insertedSession) {
      throw new Error('Failed to create conversation session');
    }

    const sessionId = insertedSession.id;

    // Insert messages if any
    if (data.messages.length > 0) {
      await db
        .insertInto('conversationMessage')
        .values(
          data.messages.map((msg) => ({
            sessionId,
            azureItemId: msg.azureItemId,
            role: msg.role,
            content: msg.content,
            messageTimestamp: new Date(msg.timestamp),
            sequenceNumber: msg.sequenceNumber,
          })),
        )
        .execute();
    }

    // Generate summary
    let summarized = false;
    if (data.messages.length > 0) {
      const summary = await this.summarizationService.summarize(
        data.messages.map((m) => ({ role: m.role, content: m.content })),
      );

      if (summary) {
        await db
          .updateTable('conversationSession')
          .set({
            summary,
            summarizedAt: new Date(),
          })
          .where('id', '=', sessionId)
          .execute();
        summarized = true;
        this.logger.log(`Generated summary for session ${sessionId}`);
      }

      // Extract memories from conversation (async, non-blocking)
      this.extractionService
        .extractMemories(
          data.patientId,
          sessionId,
          data.messages.map((m) => ({ role: m.role, content: m.content })),
        )
        .then((result) => {
          if (result.memoriesCreated > 0 || result.memoriesUpdated > 0) {
            this.logger.log(
              `Memory extraction for session ${sessionId}: ${result.memoriesCreated} created, ${result.memoriesUpdated} updated`,
            );
          }
        })
        .catch((error) => {
          this.logger.error(
            `Memory extraction failed for session ${sessionId}: ${error}`,
          );
        });
    }

    this.logger.log(
      `Created conversation session ${sessionId} with ${data.messages.length} messages`,
    );

    return { success: true, sessionId, summarized };
  }

  async findAllForPatient(
    patientId: string,
    page: number = 1,
    pageSize: number = 20,
  ) {
    // MSSQL doesn't support LIMIT/OFFSET syntax, fetch all and handle in code
    const sessions = await db
      .selectFrom('conversationSession')
      .selectAll()
      .where('patientId', '=', patientId)
      .orderBy('startTime', 'desc')
      .execute();

    // Get preview (first assistant message) for each session
    const sessionsWithPreviews = await Promise.all(
      sessions.map(async (session) => {
        const messages = await db
          .selectFrom('conversationMessage')
          .select(['content'])
          .where('sessionId', '=', session.id)
          .where('role', '=', 'assistant')
          .orderBy('sequenceNumber', 'asc')
          .execute();

        const firstMessage = messages[0];

        return {
          id: session.id,
          startTime: session.startTime,
          endTime: session.endTime,
          messageCount: session.messageCount,
          summary: session.summary,
          summarizedAt: session.summarizedAt,
          preview: firstMessage?.content?.substring(0, 100) ?? '',
        };
      }),
    );

    return {
      sessions: sessionsWithPreviews,
      pagination: {
        page,
        pageSize,
        total: sessions.length,
      },
    };
  }

  async findOne(patientId: string, sessionId: string) {
    const session = await db
      .selectFrom('conversationSession')
      .selectAll()
      .where('id', '=', sessionId)
      .where('patientId', '=', patientId)
      .executeTakeFirst();

    if (!session) {
      return null;
    }

    const messages = await db
      .selectFrom('conversationMessage')
      .selectAll()
      .where('sessionId', '=', sessionId)
      .orderBy('sequenceNumber', 'asc')
      .execute();

    return {
      ...session,
      messages: messages.map((msg) => ({
        id: msg.id,
        azureItemId: msg.azureItemId,
        role: msg.role,
        content: msg.content,
        timestamp: msg.messageTimestamp,
        sequenceNumber: msg.sequenceNumber,
      })),
    };
  }

  async remove(sessionId: string) {
    const session = await db
      .selectFrom('conversationSession')
      .select(['patientId'])
      .where('id', '=', sessionId)
      .executeTakeFirst();

    if (!session) {
      return { success: false, message: 'Session not found' };
    }

    // Messages will be deleted via CASCADE
    await db
      .deleteFrom('conversationSession')
      .where('id', '=', sessionId)
      .execute();

    this.logger.log(`Deleted conversation session ${sessionId}`);

    return { success: true, patientId: session.patientId };
  }
}
