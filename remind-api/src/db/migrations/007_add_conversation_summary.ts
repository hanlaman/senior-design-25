import { type Kysely, sql } from 'kysely';

export async function up(db: Kysely<any>): Promise<void> {
  await sql`ALTER TABLE conversationSession ADD summary NVARCHAR(MAX)`.execute(
    db,
  );
  await sql`ALTER TABLE conversationSession ADD summarizedAt DATETIME2`.execute(
    db,
  );
}

export async function down(db: Kysely<any>): Promise<void> {
  await sql`ALTER TABLE conversationSession DROP COLUMN summarizedAt`.execute(
    db,
  );
  await sql`ALTER TABLE conversationSession DROP COLUMN summary`.execute(db);
}
