import { type Kysely, sql } from 'kysely';

export async function up(db: Kysely<any>): Promise<void> {
  await db.schema
    .createTable('patientFact')
    .addColumn('id', sql`UNIQUEIDENTIFIER`, (col) =>
      col.primaryKey().defaultTo(sql`NEWID()`),
    )
    .addColumn('patientId', 'varchar(255)', (col) => col.notNull())
    .addColumn('category', 'varchar(50)', (col) => col.notNull())
    .addColumn('label', 'varchar(255)', (col) => col.notNull())
    .addColumn('value', sql`NVARCHAR(MAX)`, (col) => col.notNull())
    .addColumn('createdAt', sql`DATETIME2`, (col) =>
      col.defaultTo(sql`GETDATE()`),
    )
    .addColumn('updatedAt', sql`DATETIME2`, (col) =>
      col.defaultTo(sql`GETDATE()`),
    )
    .execute();

  await db.schema
    .createIndex('idx_patientFact_patientId')
    .on('patientFact')
    .column('patientId')
    .execute();

  await db.schema
    .createIndex('idx_patientFact_category')
    .on('patientFact')
    .columns(['patientId', 'category'])
    .execute();
}

export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.dropTable('patientFact').execute();
}
