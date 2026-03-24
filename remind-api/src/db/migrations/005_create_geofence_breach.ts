import { type Kysely, sql } from 'kysely';

export async function up(db: Kysely<any>): Promise<void> {
  await db.schema
    .createTable('geofenceBreach')
    .addColumn('id', sql`UNIQUEIDENTIFIER`, (col) =>
      col.primaryKey().defaultTo(sql`NEWID()`),
    )
    .addColumn('patientId', 'varchar(255)', (col) => col.notNull().unique())
    .addColumn('exitedAt', sql`DATETIME2`, (col) => col.notNull())
    .addColumn('notified', sql`BIT`, (col) => col.notNull().defaultTo(sql`0`))
    .addColumn('closestZoneName', 'varchar(255)', (col) => col.notNull())
    .addColumn('gracePeriodMs', 'integer', (col) => col.notNull())
    .execute();
}

export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.dropTable('geofenceBreach').execute();
}
