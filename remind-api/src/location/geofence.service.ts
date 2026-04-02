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
    this.logger.log(
      `Geofence check: patient=${patientId} lat=${latitude} lng=${longitude}`,
    );

    const zones = await db
      .selectFrom('safeZone')
      .selectAll()
      .where('patientId', '=', patientId)
      .where('isEnabled', '=', true)
      .execute();

    if (zones.length === 0) {
      this.logger.log(`No enabled safe zones for patient ${patientId} — skipping`);
      return;
    }

    // Log distance to each zone for diagnostics
    for (const zone of zones) {
      const dist = haversineDistance(
        latitude,
        longitude,
        zone.centerLatitude,
        zone.centerLongitude,
      );
      this.logger.log(
        `Zone "${zone.name}": distance=${dist.toFixed(1)}m, radius=${zone.radiusMeters}m, durationMinutes=${zone.durationMinutes}, ${dist <= zone.radiusMeters ? 'INSIDE' : 'OUTSIDE'}`,
      );
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

    // If there's a stale notified breach, clear it so we treat this as a fresh exit.
    // This prevents an old breach from permanently blocking new notifications.
    if (breach?.notified) {
      const breachAge = Date.now() - new Date(breach.exitedAt).getTime();
      const STALE_THRESHOLD_MS = 30 * 60 * 1000; // 30 minutes

      if (breachAge > STALE_THRESHOLD_MS) {
        this.logger.log(
          `Clearing stale breach for patient ${patientId} (zone "${breach.closestZoneName}", age ${Math.round(breachAge / 60000)}m) — will re-evaluate`,
        );
        await db
          .deleteFrom('geofenceBreach')
          .where('patientId', '=', patientId)
          .execute();
        // Fall through to fresh exit logic below
      } else {
        this.logger.debug(
          `Breach already notified for patient ${patientId} (zone "${breach.closestZoneName}", ${Math.round(breachAge / 1000)}s ago) — skipping`,
        );
        return;
      }
    }

    if (!breach || breach.notified) {
      // Fresh exit (no breach, or stale breach was just cleared)
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
    this.logger.log(
      `Looking up iOS device tokens for patient ${patientId} to send geofence alert`,
    );

    const devices = await db
      .selectFrom('deviceToken')
      .selectAll()
      .where('patientId', '=', patientId)
      .where('platform', '=', 'ios')
      .execute();

    if (devices.length === 0) {
      this.logger.warn(
        `No iOS device tokens found for patient ${patientId} — cannot send geofence alert`,
      );
      return;
    }

    this.logger.log(
      `Found ${devices.length} iOS device(s) for patient ${patientId}, sending geofence alert for zone "${zoneName}"`,
    );

    for (const device of devices) {
      this.logger.debug(
        `Sending geofence alert to device token ${device.token.substring(0, 8)}... (bundleId: ${device.bundleId})`,
      );
      try {
        await this.apnsService.sendGeofenceAlertNotification(
          device.token,
          device.bundleId,
          zoneName,
        );
        this.logger.log(
          `Geofence alert sent successfully to device ${device.token.substring(0, 8)}...`,
        );
      } catch (error) {
        this.logger.error(
          `Failed to send geofence alert to iOS device ${device.token.substring(0, 8)}...: ${error}`,
        );
      }
    }
  }
}
