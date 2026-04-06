import { type Kysely, sql } from 'kysely';

export async function up(db: Kysely<any>): Promise<void> {
  await sql`
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'contact')
    BEGIN
      CREATE TABLE contact (
        id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        patientId VARCHAR(255) NOT NULL,
        role VARCHAR(50) NOT NULL,
        name VARCHAR(255) NOT NULL,
        phoneNumber VARCHAR(50) NOT NULL,
        createdAt DATETIME2 DEFAULT GETDATE(),
        updatedAt DATETIME2 DEFAULT GETDATE()
      )
    END
  `.execute(db);
}

export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.dropTable('contact').execute();
}
