-- Create the remind_db database if it doesn't exist
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'remind_db')
BEGIN
    CREATE DATABASE remind_db;
END
GO

USE remind_db;
GO

-- Location tracking table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'location')
BEGIN
    CREATE TABLE location (
        id INT IDENTITY(1,1) PRIMARY KEY,
        patientId NVARCHAR(255) NOT NULL,
        latitude FLOAT NOT NULL,
        longitude FLOAT NOT NULL,
        timestamp DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        createdAt DATETIME2 NOT NULL DEFAULT GETUTCDATE()
    );

    CREATE INDEX IX_location_patientId_timestamp
        ON location (patientId, timestamp DESC);
END
GO
