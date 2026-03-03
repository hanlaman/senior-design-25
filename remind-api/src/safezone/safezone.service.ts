import { Injectable } from '@nestjs/common';
import { db } from '../db';

@Injectable()
export class SafeZoneService {
  async create(
    patientId: string,
    data: {
      name: string;
      centerLatitude: number;
      centerLongitude: number;
      radiusMeters: number;
      durationMinutes?: number;
    },
  ) {
    await db
      .insertInto('safeZone')
      .values({
        patientId,
        name: data.name,
        centerLatitude: data.centerLatitude,
        centerLongitude: data.centerLongitude,
        radiusMeters: data.radiusMeters,
        durationMinutes: data.durationMinutes ?? 15,
      })
      .execute();

    return { success: true };
  }

  async findAll(patientId: string) {
    return db
      .selectFrom('safeZone')
      .selectAll()
      .where('patientId', '=', patientId)
      .execute();
  }

  async update(
    id: string,
    data: Partial<{
      name: string;
      centerLatitude: number;
      centerLongitude: number;
      radiusMeters: number;
      durationMinutes: number;
      isEnabled: boolean;
    }>,
  ) {
    await db
      .updateTable('safeZone')
      .set({ ...data, updatedAt: new Date() })
      .where('id', '=', id)
      .execute();

    return { success: true };
  }

  async remove(id: string) {
    await db.deleteFrom('safeZone').where('id', '=', id).execute();

    return { success: true };
  }
}
