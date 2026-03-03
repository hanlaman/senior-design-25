import { type Kysely, sql } from 'kysely';

export async function up(db: Kysely<any>): Promise<void> {
  await db.schema
    .createTable('safeZone')
    .addColumn('id', sql`UNIQUEIDENTIFIER`, (col) =>
      col.primaryKey().defaultTo(sql`NEWID()`),
    )
    .addColumn('patientId', 'varchar(255)', (col) => col.notNull())
    .addColumn('name', 'varchar(255)', (col) => col.notNull())
    .addColumn('centerLatitude', sql`FLOAT`, (col) => col.notNull())
    .addColumn('centerLongitude', sql`FLOAT`, (col) => col.notNull())
    .addColumn('radiusMeters', sql`FLOAT`, (col) =>
      col.notNull().defaultTo(100),
    )
    .addColumn('isEnabled', sql`BIT`, (col) =>
      col.notNull().defaultTo(sql`1`),
    )
    .addColumn('createdAt', sql`DATETIME2`, (col) =>
      col.defaultTo(sql`GETDATE()`),
    )
    .addColumn('updatedAt', sql`DATETIME2`, (col) =>
      col.defaultTo(sql`GETDATE()`),
    )
    .execute();
}

export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.dropTable('safeZone').execute();
}
