import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { ReminderService } from './reminder.service';
import { ApnsService } from '../apns/apns.service';
import { db } from '../db';

@Injectable()
export class ReminderScheduler implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(ReminderScheduler.name);
  private intervalId: ReturnType<typeof setInterval> | null = null;

  constructor(
    private readonly reminderService: ReminderService,
    private readonly apnsService: ApnsService,
  ) {}

  onModuleInit() {
    this.logger.log('Starting reminder scheduler (30s interval)');
    this.intervalId = setInterval(() => this.checkDueReminders(), 30_000);
  }

  onModuleDestroy() {
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
    }
  }

  private async checkDueReminders() {
    try {
      const dueReminders = await this.reminderService.findDueReminders();

      for (const reminder of dueReminders) {
        // Find watchOS device token for this patient
        const deviceToken = await db
          .selectFrom('deviceToken')
          .selectAll()
          .where('patientId', '=', reminder.patientId)
          .where('platform', '=', 'watchos')
          .executeTakeFirst();

        if (!deviceToken) {
          this.logger.debug(
            `No watchOS device token for patient ${reminder.patientId}`,
          );
          continue;
        }

        try {
          await this.apnsService.sendReminderNotification(
            deviceToken.token,
            deviceToken.bundleId,
            {
              id: reminder.id,
              type: reminder.type,
              title: reminder.title,
              notes: reminder.notes,
            },
          );

          await this.reminderService.updateLastNotifiedAt(reminder.id);
          this.logger.log(
            `Sent push for reminder "${reminder.title}" to patient ${reminder.patientId}`,
          );
        } catch (error) {
          this.logger.error(
            `Failed to send push for reminder ${reminder.id}: ${error}`,
          );
        }
      }
    } catch (error) {
      this.logger.error(`Scheduler error: ${error}`);
    }
  }
}
