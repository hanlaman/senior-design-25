import { type Kysely, sql } from 'kysely';

export async function up(db: Kysely<any>): Promise<void> {
  await db.schema
    .createTable('reminder')
    .addColumn('id', sql`UNIQUEIDENTIFIER`, (col) =>
      col.primaryKey().defaultTo(sql`NEWID()`),
    )
    .addColumn('patientId', 'varchar(255)', (col) => col.notNull())
    .addColumn('type', 'varchar(50)', (col) => col.notNull())
    .addColumn('title', 'varchar(255)', (col) => col.notNull())
    .addColumn('notes', sql`NVARCHAR(1000)`)
    .addColumn('scheduledTime', sql`DATETIME2`, (col) => col.notNull())
    .addColumn('repeatSchedule', 'varchar(50)', (col) =>
      col.notNull().defaultTo('once'),
    )
    .addColumn('customDays', 'varchar(50)')
    .addColumn('isEnabled', sql`BIT`, (col) =>
      col.notNull().defaultTo(sql`1`),
    )
    .addColumn('isCompleted', sql`BIT`, (col) =>
      col.notNull().defaultTo(sql`0`),
    )
    .addColumn('completedAt', sql`DATETIME2`)
    .addColumn('sendToWatch', sql`BIT`, (col) =>
      col.notNull().defaultTo(sql`1`),
    )
    .addColumn('lastNotifiedAt', sql`DATETIME2`)
    .addColumn('createdAt', sql`DATETIME2`, (col) =>
      col.defaultTo(sql`GETDATE()`),
    )
    .addColumn('updatedAt', sql`DATETIME2`, (col) =>
      col.defaultTo(sql`GETDATE()`),
    )
    .execute();
}

export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.dropTable('reminder').execute();
}
