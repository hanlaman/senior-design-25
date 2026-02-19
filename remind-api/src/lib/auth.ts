import { betterAuth } from 'better-auth';
import { bearer } from 'better-auth/plugins';
import { dialect } from '../db/dialect';

export const auth = betterAuth({
  database: {
    dialect,
    type: 'mssql',
  },
  user: {
    additionalFields: {
      firstName: {
        type: 'string',
        required: true,
      },
      lastName: {
        type: 'string',
        required: true,
      },
    },
  },
  emailAndPassword: {
    enabled: true,
    minPasswordLength: 8,
    maxPasswordLength: 128,
  },
  basePath: '/api/auth',
  advanced: {
    disableOriginCheck: process.env.NODE_ENV !== 'production',
  },
  plugins: [bearer()],
});

export type Session = typeof auth.$Infer.Session;
export type User = typeof auth.$Infer.Session.user;
