import { type Kysely, sql } from 'kysely';

export async function up(db: Kysely<any>): Promise<void> {
  // Create patient memory table - flexible atomic memory notes
  await db.schema
    .createTable('patientMemory')
    .addColumn('id', sql`UNIQUEIDENTIFIER`, (col) =>
      col.primaryKey().defaultTo(sql`NEWID()`),
    )
    .addColumn('patientId', 'varchar(255)', (col) => col.notNull())

    // Core flexible content
    .addColumn('content', sql`NVARCHAR(MAX)`, (col) => col.notNull())
    .addColumn('keywords', sql`NVARCHAR(MAX)`) // JSON array of LLM-generated keywords
    .addColumn('contextDescription', sql`NVARCHAR(MAX)`) // LLM-generated context
    .addColumn('embedding', sql`VARBINARY(6144)`) // 1536 floats * 4 bytes for text-embedding-3-small

    // Optional computed facets (for UI/queries, not rigid constraints)
    .addColumn('suggestedType', 'varchar(50)') // fact, episode, routine, preference, concern, relationship
    .addColumn('suggestedCategories', sql`NVARCHAR(MAX)`) // JSON array - can have multiple!
    .addColumn('temporalRelevance', 'varchar(20)') // past, ongoing, future, timeless
    .addColumn('eventDate', sql`DATETIME2`) // If time-specific (appointments, events)
    .addColumn('emotionalTone', 'varchar(20)') // positive, negative, neutral, anxious

    // Metadata
    .addColumn('confidence', sql`FLOAT`, (col) => col.notNull().defaultTo(1.0))
    .addColumn('sourceSessionId', sql`UNIQUEIDENTIFIER`) // FK to conversationSession
    .addColumn('mentionCount', 'integer', (col) => col.notNull().defaultTo(1))
    .addColumn('firstMentioned', sql`DATETIME2`, (col) => col.notNull())
    .addColumn('lastMentioned', sql`DATETIME2`, (col) => col.notNull())
    .addColumn('isActive', sql`BIT`, (col) => col.notNull().defaultTo(sql`1`))
    .addColumn('createdAt', sql`DATETIME2`, (col) =>
      col.defaultTo(sql`GETDATE()`),
    )
    .addColumn('updatedAt', sql`DATETIME2`, (col) =>
      col.defaultTo(sql`GETDATE()`),
    )
    .execute();

  // Add foreign key to conversationSession (optional - memory can exist without session)
  await sql`ALTER TABLE patientMemory ADD CONSTRAINT FK_patient_memory_session FOREIGN KEY (sourceSessionId) REFERENCES conversationSession(id) ON DELETE SET NULL`.execute(
    db,
  );

  // Create indexes for common query patterns
  await sql`CREATE INDEX IX_patient_memory_patient ON patientMemory(patientId)`.execute(
    db,
  );
  await sql`CREATE INDEX IX_patient_memory_last_mentioned ON patientMemory(patientId, lastMentioned DESC)`.execute(
    db,
  );
  await sql`CREATE INDEX IX_patient_memory_type ON patientMemory(patientId, suggestedType)`.execute(
    db,
  );
  await sql`CREATE INDEX IX_patient_memory_event_date ON patientMemory(patientId, eventDate DESC) WHERE eventDate IS NOT NULL`.execute(
    db,
  );
  await sql`CREATE INDEX IX_patient_memory_active ON patientMemory(patientId, isActive) WHERE isActive = 1`.execute(
    db,
  );
}

export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.dropTable('patientMemory').execute();
}
