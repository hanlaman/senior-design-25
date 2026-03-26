import { Injectable } from '@nestjs/common';
import { db } from '../db';
import { haversineDistance } from '../lib/geo';

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

  async getLocationContext(patientId: string) {
    const location = await this.getLatestLocation(patientId);

    if (!location) {
      return { currentLocation: null, insideZone: null, nearbyZones: [] };
    }

    const zones = await db
      .selectFrom('safeZone')
      .selectAll()
      .where('patientId', '=', patientId)
      .where('isEnabled', '=', true)
      .execute();

    let insideZone: { name: string; distance: number } | null = null;
    const nearbyZones: { name: string; distance: number }[] = [];
    const nearbyThresholdMeters = 1000;

    for (const zone of zones) {
      const distance = haversineDistance(
        location.latitude,
        location.longitude,
        zone.centerLatitude,
        zone.centerLongitude,
      );

      if (distance <= zone.radiusMeters) {
        if (!insideZone || distance < insideZone.distance) {
          insideZone = { name: zone.name, distance: Math.round(distance) };
        }
      } else if (distance <= nearbyThresholdMeters) {
        nearbyZones.push({
          name: zone.name,
          distance: Math.round(distance),
        });
      }
    }

    nearbyZones.sort((a, b) => a.distance - b.distance);

    return {
      currentLocation: {
        latitude: location.latitude,
        longitude: location.longitude,
        timestamp: location.timestamp,
      },
      insideZone,
      nearbyZones,
    };
  }
}
