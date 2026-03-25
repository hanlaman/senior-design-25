import { type Kysely, sql } from 'kysely';

export async function up(db: Kysely<any>): Promise<void> {
  // Create memory link table - dynamic relationships between memories
  await db.schema
    .createTable('memoryLink')
    .addColumn('id', sql`UNIQUEIDENTIFIER`, (col) =>
      col.primaryKey().defaultTo(sql`NEWID()`),
    )
    .addColumn('fromMemoryId', sql`UNIQUEIDENTIFIER`, (col) => col.notNull())
    .addColumn('toMemoryId', sql`UNIQUEIDENTIFIER`, (col) => col.notNull())
    .addColumn('linkType', 'varchar(50)', (col) => col.notNull()) // same_person, same_topic, causal, temporal_sequence
    .addColumn('linkStrength', sql`FLOAT`, (col) =>
      col.notNull().defaultTo(1.0),
    )
    .addColumn('linkReason', sql`NVARCHAR(MAX)`) // LLM explanation: "Both mention Sarah"
    .addColumn('createdAt', sql`DATETIME2`, (col) =>
      col.defaultTo(sql`GETDATE()`),
    )
    .execute();

  // Add foreign key constraints with cascade delete
  await sql`ALTER TABLE memoryLink ADD CONSTRAINT FK_memory_link_from FOREIGN KEY (fromMemoryId) REFERENCES patientMemory(id) ON DELETE CASCADE`.execute(
    db,
  );

  // Note: Can't have two cascade deletes to same table in MSSQL, so use NO ACTION for toMemoryId
  // Links will be orphaned when target memory is deleted, clean up via scheduled job or trigger
  await sql`ALTER TABLE memoryLink ADD CONSTRAINT FK_memory_link_to FOREIGN KEY (toMemoryId) REFERENCES patientMemory(id) ON DELETE NO ACTION`.execute(
    db,
  );

  // Create unique index to prevent duplicate links
  await sql`CREATE UNIQUE INDEX UQ_memory_link_pair ON memoryLink(fromMemoryId, toMemoryId)`.execute(
    db,
  );

  // Create indexes for efficient traversal
  await sql`CREATE INDEX IX_memory_link_from ON memoryLink(fromMemoryId)`.execute(
    db,
  );
  await sql`CREATE INDEX IX_memory_link_to ON memoryLink(toMemoryId)`.execute(
    db,
  );
}

export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.dropTable('memoryLink').execute();
}
