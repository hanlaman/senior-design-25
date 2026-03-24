import { type Kysely, sql } from 'kysely';

export async function up(db: Kysely<any>): Promise<void> {
  // Create conversation session table
  await db.schema
    .createTable('conversationSession')
    .addColumn('id', sql`UNIQUEIDENTIFIER`, (col) =>
      col.primaryKey().defaultTo(sql`NEWID()`),
    )
    .addColumn('patientId', 'varchar(255)', (col) => col.notNull())
    .addColumn('azureSessionId', 'varchar(255)', (col) => col.notNull())
    .addColumn('startTime', sql`DATETIME2`, (col) => col.notNull())
    .addColumn('endTime', sql`DATETIME2`)
    .addColumn('messageCount', 'integer', (col) => col.notNull().defaultTo(0))
    .addColumn('createdAt', sql`DATETIME2`, (col) =>
      col.defaultTo(sql`GETDATE()`),
    )
    .execute();

  // Create unique index for idempotent uploads
  await sql`CREATE UNIQUE INDEX UQ_conversation_azure_session ON conversationSession(patientId, azureSessionId)`.execute(
    db,
  );

  // Create conversation message table
  await db.schema
    .createTable('conversationMessage')
    .addColumn('id', sql`UNIQUEIDENTIFIER`, (col) =>
      col.primaryKey().defaultTo(sql`NEWID()`),
    )
    .addColumn('sessionId', sql`UNIQUEIDENTIFIER`, (col) => col.notNull())
    .addColumn('azureItemId', 'varchar(255)', (col) => col.notNull())
    .addColumn('role', 'varchar(20)', (col) => col.notNull())
    .addColumn('content', sql`NVARCHAR(MAX)`, (col) => col.notNull())
    .addColumn('messageTimestamp', sql`DATETIME2`, (col) => col.notNull())
    .addColumn('sequenceNumber', 'integer', (col) => col.notNull())
    .addColumn('createdAt', sql`DATETIME2`, (col) =>
      col.defaultTo(sql`GETDATE()`),
    )
    .execute();

  // Add foreign key constraint
  await sql`ALTER TABLE conversationMessage ADD CONSTRAINT FK_conversation_message_session FOREIGN KEY (sessionId) REFERENCES conversationSession(id) ON DELETE CASCADE`.execute(
    db,
  );

  // Create indexes for efficient queries
  await sql`CREATE INDEX IX_conversation_session_patient ON conversationSession(patientId)`.execute(
    db,
  );
  await sql`CREATE INDEX IX_conversation_session_startTime ON conversationSession(patientId, startTime DESC)`.execute(
    db,
  );
  await sql`CREATE INDEX IX_conversation_message_session ON conversationMessage(sessionId, sequenceNumber)`.execute(
    db,
  );
}

export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.dropTable('conversationMessage').execute();
  await db.schema.dropTable('conversationSession').execute();
}
