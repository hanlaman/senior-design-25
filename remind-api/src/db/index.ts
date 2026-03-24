import { Generated, Kysely } from 'kysely';
import { dialect } from './dialect';

// Database table interfaces
interface UserTable {
  id: string;
  email: string;
  emailVerified: boolean;
  name: string;
  firstName: string;
  lastName: string;
  image: string | null;
  createdAt: Date;
  updatedAt: Date;
}

interface SessionTable {
  id: string;
  userId: string;
  token: string;
  expiresAt: Date;
  ipAddress: string | null;
  userAgent: string | null;
  createdAt: Date;
  updatedAt: Date;
}

interface AccountTable {
  id: string;
  userId: string;
  accountId: string;
  providerId: string;
  accessToken: string | null;
  refreshToken: string | null;
  accessTokenExpiresAt: Date | null;
  refreshTokenExpiresAt: Date | null;
  scope: string | null;
  idToken: string | null;
  password: string | null;
  createdAt: Date;
  updatedAt: Date;
}

interface VerificationTable {
  id: string;
  identifier: string;
  value: string;
  expiresAt: Date;
  createdAt: Date;
  updatedAt: Date;
}

interface LocationTable {
  id: Generated<number>;
  patientId: string;
  latitude: number;
  longitude: number;
  timestamp: Generated<Date>;
  createdAt: Generated<Date>;
}

interface SafeZoneTable {
  id: Generated<string>;
  patientId: string;
  name: string;
  centerLatitude: number;
  centerLongitude: number;
  radiusMeters: number;
  durationMinutes: Generated<number>;
  isEnabled: Generated<boolean>;
  createdAt: Generated<Date>;
  updatedAt: Generated<Date>;
}

interface ReminderTable {
  id: Generated<string>;
  patientId: string;
  type: string;
  title: string;
  notes: string | null;
  scheduledTime: Date;
  repeatSchedule: string;
  customDays: string | null;
  isEnabled: Generated<boolean>;
  isCompleted: Generated<boolean>;
  completedAt: Date | null;
  sendToWatch: Generated<boolean>;
  lastNotifiedAt: Date | null;
  createdAt: Generated<Date>;
  updatedAt: Generated<Date>;
}

interface DeviceTokenTable {
  id: Generated<string>;
  patientId: string;
  token: string;
  platform: string;
  bundleId: string;
  createdAt: Generated<Date>;
  updatedAt: Generated<Date>;
}

interface GeofenceBreachTable {
  id: Generated<string>;
  patientId: string;
  exitedAt: Date;
  notified: boolean;
  closestZoneName: string;
  gracePeriodMs: number;
}

// Database interface combining all tables
export interface Database {
  user: UserTable;
  session: SessionTable;
  account: AccountTable;
  verification: VerificationTable;
  location: LocationTable;
  safeZone: SafeZoneTable;
  reminder: ReminderTable;
  deviceToken: DeviceTokenTable;
  geofenceBreach: GeofenceBreachTable;
}

// Export the Kysely database instance
export const db = new Kysely<Database>({ dialect });
