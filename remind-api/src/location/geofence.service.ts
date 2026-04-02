import { Injectable, Logger } from '@nestjs/common';
import { ApnsService } from '../apns/apns.service';
import { db } from '../db';
import { haversineDistance } from '../lib/geo';

@Injectable()
export class GeofenceService {
  private readonly logger = new Logger(GeofenceService.name);

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

    const breach = await db
      .selectFrom('geofenceBreach')
      .selectAll()
      .where('patientId', '=', patientId)
      .executeTakeFirst();

    if (insideAnyZone) {
      // Patient is inside a zone — clear any breach state
      if (breach) {
        await db
          .deleteFrom('geofenceBreach')
          .where('patientId', '=', patientId)
          .execute();
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

      const gracePeriodMinutes = Math.max(
        ...zones.map((z) => z.durationMinutes),
      );
      const gracePeriodMs = gracePeriodMinutes * 60 * 1000;

      // Immediate notification when grace period is 0
      if (gracePeriodMs === 0) {
        await db
          .insertInto('geofenceBreach')
          .values({
            patientId,
            exitedAt: new Date(),
            notified: true,
            closestZoneName: closestZone.name,
            gracePeriodMs: 0,
          })
          .execute();

        this.logger.warn(
          `Patient ${patientId} left safe zone "${closestZone.name}" — notifying caregiver immediately`,
        );

        await this.notifyCaregiverDevices(patientId, closestZone.name);
        return;
      }

      await db
        .insertInto('geofenceBreach')
        .values({
          patientId,
          exitedAt: new Date(),
          notified: false,
          closestZoneName: closestZone.name,
          gracePeriodMs,
        })
        .execute();

      this.logger.log(
        `Patient ${patientId} left safe zones — grace period ${gracePeriodMinutes}m started`,
      );
      return;
    }

    if (breach.notified) {
      return;
    }

    // Check if grace period has elapsed
    const elapsed = Date.now() - new Date(breach.exitedAt).getTime();
    if (elapsed >= breach.gracePeriodMs) {
      await db
        .updateTable('geofenceBreach')
        .set({ notified: true })
        .where('patientId', '=', patientId)
        .execute();

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
