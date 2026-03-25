import { type Kysely, sql } from 'kysely';

export async function up(db: Kysely<any>): Promise<void> {
  // Create memory extraction log table - tracks extraction processing
  await db.schema
    .createTable('memoryExtractionLog')
    .addColumn('id', sql`UNIQUEIDENTIFIER`, (col) =>
      col.primaryKey().defaultTo(sql`NEWID()`),
    )
    .addColumn('sessionId', sql`UNIQUEIDENTIFIER`, (col) => col.notNull())
    .addColumn('extractedAt', sql`DATETIME2`, (col) => col.notNull())
    .addColumn('memoriesCreated', 'integer', (col) =>
      col.notNull().defaultTo(0),
    )
    .addColumn('memoriesUpdated', 'integer', (col) =>
      col.notNull().defaultTo(0),
    )
    .addColumn('linksCreated', 'integer', (col) => col.notNull().defaultTo(0))
    .addColumn('processingTimeMs', 'integer')
    .addColumn('extractionModel', 'varchar(100)') // e.g., "gpt-4o-mini"
    .addColumn('error', sql`NVARCHAR(MAX)`) // Error message if extraction failed
    .execute();

  // Add foreign key constraint
  await sql`ALTER TABLE memoryExtractionLog ADD CONSTRAINT FK_memory_extraction_session FOREIGN KEY (sessionId) REFERENCES conversationSession(id) ON DELETE CASCADE`.execute(
    db,
  );

  // Create index for finding extraction status by session
  await sql`CREATE INDEX IX_memory_extraction_session ON memoryExtractionLog(sessionId)`.execute(
    db,
  );
}

export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.dropTable('memoryExtractionLog').execute();
}
