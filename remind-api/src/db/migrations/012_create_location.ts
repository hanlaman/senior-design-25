import { type Kysely, sql } from 'kysely';

export async function up(db: Kysely<any>): Promise<void> {
  await sql`
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'location')
    BEGIN
      CREATE TABLE location (
        id INT IDENTITY(1,1) PRIMARY KEY,
        patientId VARCHAR(255) NOT NULL,
        latitude FLOAT NOT NULL,
        longitude FLOAT NOT NULL,
        [timestamp] DATETIME2 NOT NULL DEFAULT GETDATE(),
        createdAt DATETIME2 DEFAULT GETDATE()
      )
    END
  `.execute(db);
}

export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.dropTable('location').execute();
}
