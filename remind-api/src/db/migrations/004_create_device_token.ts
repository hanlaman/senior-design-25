import { type Kysely, sql } from 'kysely';

export async function up(db: Kysely<any>): Promise<void> {
  await db.schema
    .createTable('deviceToken')
    .addColumn('id', sql`UNIQUEIDENTIFIER`, (col) =>
      col.primaryKey().defaultTo(sql`NEWID()`),
    )
    .addColumn('patientId', 'varchar(255)', (col) => col.notNull())
    .addColumn('token', 'varchar(500)', (col) => col.notNull())
    .addColumn('platform', 'varchar(20)', (col) => col.notNull())
    .addColumn('bundleId', 'varchar(255)', (col) => col.notNull())
    .addColumn('createdAt', sql`DATETIME2`, (col) =>
      col.defaultTo(sql`GETDATE()`),
    )
    .addColumn('updatedAt', sql`DATETIME2`, (col) =>
      col.defaultTo(sql`GETDATE()`),
    )
    .execute();
}

export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.dropTable('deviceToken').execute();
}
