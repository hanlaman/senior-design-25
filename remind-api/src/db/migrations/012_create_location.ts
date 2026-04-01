import { type Kysely, sql } from 'kysely';

export async function up(db: Kysely<any>): Promise<void> {
  await db.schema
    .createTable('location')
    .addColumn('id', 'integer', (col) => col.primaryKey().identity())
    .addColumn('patientId', 'varchar(255)', (col) => col.notNull())
    .addColumn('latitude', sql`FLOAT`, (col) => col.notNull())
    .addColumn('longitude', sql`FLOAT`, (col) => col.notNull())
    .addColumn('timestamp', sql`DATETIME2`, (col) =>
      col.notNull().defaultTo(sql`GETDATE()`),
    )
    .addColumn('createdAt', sql`DATETIME2`, (col) =>
      col.defaultTo(sql`GETDATE()`),
    )
    .execute();
}

export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.dropTable('location').execute();
}
