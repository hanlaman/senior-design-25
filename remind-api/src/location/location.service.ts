import { Injectable } from '@nestjs/common';
import { db } from '../db';

@Injectable()
export class LocationService {
  async createLocation(patientId: string, latitude: number, longitude: number) {
    await db
      .insertInto('location')
      .values({
        patientId,
        latitude,
        longitude,
      })
      .execute();

    return { success: true };
  }

  async getLatestLocation(patientId: string) {
    const location = await db
      .selectFrom('location')
      .selectAll()
      .where('patientId', '=', patientId)
      .orderBy('timestamp', 'desc')
      .top(1)
      .executeTakeFirst();

    return location ?? null;
  }
}
