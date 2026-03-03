import { type Kysely } from 'kysely';

export async function up(db: Kysely<any>): Promise<void> {
  await db.schema
    .alterTable('safeZone')
    .addColumn('durationMinutes', 'integer', (col) =>
      col.notNull().defaultTo(15),
    )
    .execute();
}

export async function down(db: Kysely<any>): Promise<void> {
  await db.schema
    .alterTable('safeZone')
    .dropColumn('durationMinutes')
    .execute();
}
