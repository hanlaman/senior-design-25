import { Injectable, Logger } from '@nestjs/common';
import { ApnsService } from '../apns/apns.service';
import { db } from '../db';

interface BreachState {
  exitedAt: Date;
  notified: boolean;
  closestZoneName: string;
  gracePeriodMs: number;
}

@Injectable()
export class GeofenceService {
  private readonly logger = new Logger(GeofenceService.name);
  private readonly patientBreachState = new Map<string, BreachState>();

  constructor(private readonly apnsService: ApnsService) {}

  async checkGeofence(
    patientId: string,
    latitude: number,
    longitude: number,
  ): Promise<void> {
    const zones = await db
      .selectFrom('safeZone')
      .selectAll()
      .where('patientId', '=', patientId)
      .where('isEnabled', '=', true)
      .execute();

    if (zones.length === 0) {
      return;
    }

    const insideAnyZone = zones.some(
      (zone) =>
        haversineDistance(
          latitude,
          longitude,
          zone.centerLatitude,
          zone.centerLongitude,
        ) <= zone.radiusMeters,
    );

    const breach = this.patientBreachState.get(patientId);

    if (insideAnyZone) {
      // Patient is inside a zone — clear any breach state
      if (breach) {
        this.patientBreachState.delete(patientId);
        this.logger.log(`Patient ${patientId} has returned to a safe zone`);
      }
      return;
    }

    // Patient is outside all zones
    if (!breach) {
      // First exit — start the grace period
      const closestZone = zones.reduce((closest, zone) => {
        const dist = haversineDistance(
          latitude,
          longitude,
          zone.centerLatitude,
          zone.centerLongitude,
        );
        const closestDist = haversineDistance(
          latitude,
          longitude,
          closest.centerLatitude,
          closest.centerLongitude,
        );
        return dist < closestDist ? zone : closest;
      });

      // Use the max durationMinutes across all zones as the grace period
      const gracePeriodMinutes = Math.max(
        ...zones.map((z) => z.durationMinutes),
      );

      this.patientBreachState.set(patientId, {
        exitedAt: new Date(),
        notified: false,
        closestZoneName: closestZone.name,
        gracePeriodMs: gracePeriodMinutes * 60 * 1000,
      });

      this.logger.log(
        `Patient ${patientId} left safe zones — grace period ${gracePeriodMinutes}m started`,
      );
      return;
    }

    if (breach.notified) {
      // Already sent the notification for this breach
      return;
    }

    // Check if grace period has elapsed
    const elapsed = Date.now() - breach.exitedAt.getTime();
    if (elapsed >= breach.gracePeriodMs) {
      breach.notified = true;

      this.logger.warn(
        `Patient ${patientId} has been outside safe zone "${breach.closestZoneName}" for ${Math.round(elapsed / 60000)}m — notifying caregiver`,
      );

      await this.notifyCaregiverDevices(patientId, breach.closestZoneName);
    }
  }

  private async notifyCaregiverDevices(
    patientId: string,
    zoneName: string,
  ): Promise<void> {
    const devices = await db
      .selectFrom('deviceToken')
      .selectAll()
      .where('patientId', '=', patientId)
      .where('platform', '=', 'ios')
      .execute();

    for (const device of devices) {
      try {
        await this.apnsService.sendGeofenceAlertNotification(
          device.token,
          device.bundleId,
          zoneName,
        );
      } catch (error) {
        this.logger.error(
          `Failed to send geofence alert to iOS device: ${error}`,
        );
      }
    }
  }
}

function haversineDistance(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
): number {
  const R = 6371000; // Earth radius in meters
  const toRad = (deg: number) => (deg * Math.PI) / 180;

  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}
