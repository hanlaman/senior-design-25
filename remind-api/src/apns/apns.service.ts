import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import * as apn from '@parse/node-apn';
import { db } from '../db';

@Injectable()
export class ApnsService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(ApnsService.name);
  private provider: apn.Provider | null = null;

  onModuleInit() {
    const keyContents = process.env.APNS_KEY_CONTENTS;
    const keyId = process.env.APNS_KEY_ID;
    const teamId = process.env.APNS_TEAM_ID;

    if (!keyContents || !keyId || !teamId) {
      this.logger.warn(
        'APNs environment variables not set (APNS_KEY_CONTENTS, APNS_KEY_ID, APNS_TEAM_ID). Push notifications disabled.',
      );
      return;
    }

    // Support PEM keys stored with literal \n in env vars
    const keyPem = keyContents.replace(/\\n/g, '\n');

    this.provider = new apn.Provider({
      token: {
        key: Buffer.from(keyPem, 'utf-8'),
        keyId,
        teamId,
      },
      production: process.env.NODE_ENV === 'production',
    });

    this.logger.log('APNs provider initialized');
  }

  onModuleDestroy() {
    if (this.provider) {
      this.provider.shutdown();
      this.provider = null;
    }
  }

  async sendReminderNotification(
    deviceToken: string,
    bundleId: string,
    reminder: { id: string; type: string; title: string; notes: string | null },
  ) {
    if (!this.provider) {
      this.logger.warn('APNs provider not initialized, skipping push');
      return;
    }

    const notification = new apn.Notification();
    notification.topic = bundleId;
    notification.pushType = 'alert';
    notification.expiry = Math.floor(Date.now() / 1000) + 3600; // 1 hour
    notification.sound = 'default';
    notification.alert = {
      title: reminder.title,
      body: reminder.notes || `Time for your ${reminder.type} reminder`,
    };
    (notification as any).category = 'REMINDER';
    notification.payload = {
      reminderId: reminder.id,
      reminderType: reminder.type,
    };

    const result = await this.provider.send(notification, deviceToken);

    if (result.failed.length > 0) {
      const failure = result.failed[0];
      this.logger.error(
        `APNs send failed: ${JSON.stringify(failure.response)}`,
      );
      throw new Error(`APNs send failed: ${failure.response?.reason}`);
    }

    this.logger.debug(`APNs push sent for reminder ${reminder.id}`);
  }

  async sendSyncNotification(
    deviceToken: string,
    bundleId: string,
    action: string,
    reminderId: string,
  ) {
    if (!this.provider) {
      this.logger.warn('APNs provider not initialized, skipping sync push');
      return;
    }

    const notification = new apn.Notification();
    notification.topic = bundleId;
    notification.pushType = 'background';
    notification.expiry = Math.floor(Date.now() / 1000) + 3600;
    notification.contentAvailable = true;
    notification.payload = { action, reminderId };

    const result = await this.provider.send(notification, deviceToken);

    if (result.failed.length > 0) {
      const failure = result.failed[0];
      this.logger.error(
        `APNs sync push failed: ${JSON.stringify(failure.response)}`,
      );
    } else {
      this.logger.debug(
        `APNs sync push sent (${action}) for reminder ${reminderId}`,
      );
    }
  }

  async notifyPatientDevices(patientId: string, action: string, reminderId: string) {
    const devices = await db
      .selectFrom('deviceToken')
      .selectAll()
      .where('patientId', '=', patientId)
      .execute();

    for (const device of devices) {
      try {
        await this.sendSyncNotification(device.token, device.bundleId, action, reminderId);
      } catch (error) {
        this.logger.error(
          `Failed to send sync push to ${device.platform} device: ${error}`,
        );
      }
    }
  }

  async registerDeviceToken(
    patientId: string,
    token: string,
    platform: string,
  ) {
    const bundleId =
      platform === 'watchos'
        ? (process.env.APNS_BUNDLE_ID_WATCH ?? 'com.remind.patientwatch')
        : (process.env.APNS_BUNDLE_ID_IOS ?? 'com.remind.caregiver');

    // Upsert by (patientId, platform)
    const existing = await db
      .selectFrom('deviceToken')
      .selectAll()
      .where('patientId', '=', patientId)
      .where('platform', '=', platform)
      .executeTakeFirst();

    if (existing) {
      await db
        .updateTable('deviceToken')
        .set({ token, bundleId, updatedAt: new Date() })
        .where('id', '=', existing.id)
        .execute();
    } else {
      await db
        .insertInto('deviceToken')
        .values({ patientId, token, platform, bundleId })
        .execute();
    }

    return { success: true };
  }
}
