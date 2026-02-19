import { MssqlDialect } from 'kysely';
import * as Tedious from 'tedious';
import * as Tarn from 'tarn';
import 'dotenv/config';

// Shared MSSQL dialect configuration
export const dialect = new MssqlDialect({
  tarn: {
    ...Tarn,
    options: { min: 0, max: 10 },
  },
  tedious: {
    ...Tedious,
    connectionFactory: () =>
      new Tedious.Connection({
        authentication: {
          options: {
            password: process.env.MSSQL_PASSWORD!,
            userName: process.env.MSSQL_USER!,
          },
          type: 'default',
        },
        options: {
          database: process.env.MSSQL_DATABASE!,
          port: parseInt(process.env.MSSQL_PORT || '1433'),
          trustServerCertificate: true,
          encrypt: false,
        },
        server: process.env.MSSQL_HOST || 'localhost',
      }),
  },
});
