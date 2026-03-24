import {
  Body,
  Controller,
  Delete,
  Get,
  Logger,
  Param,
  Post,
  Put,
} from '@nestjs/common';
import { AllowAnonymous } from '@thallesp/nestjs-better-auth';
import { ReminderService } from './reminder.service';
import { ApnsService } from '../apns/apns.service';

@Controller('reminders')
export class ReminderController {
  private readonly logger = new Logger(ReminderController.name);

  constructor(
    private readonly reminderService: ReminderService,
    private readonly apnsService: ApnsService,
  ) {}

  @Post()
  @AllowAnonymous()
  async create(
    @Body()
    body: {
      patientId: string;
      type: string;
      title: string;
      notes?: string;
      scheduledTime: string;
      repeatSchedule?: string;
      customDays?: string;
      isEnabled?: boolean;
      sendToWatch?: boolean;
    },
  ) {
    const result = await this.reminderService.create(body);
    this.sendSyncPush(body.patientId, 'reminder_created', body.title);
    return result;
  }

  @Get(':patientId')
  @AllowAnonymous()
  async findAll(@Param('patientId') patientId: string) {
    return this.reminderService.findAll(patientId);
  }

  @Put(':id')
  @AllowAnonymous()
  async update(
    @Param('id') id: string,
    @Body()
    body: Partial<{
      type: string;
      title: string;
      notes: string;
      scheduledTime: string;
      repeatSchedule: string;
      customDays: string;
      isEnabled: boolean;
      isCompleted: boolean;
      sendToWatch: boolean;
    }>,
  ) {
    const result = await this.reminderService.update(id, body);
    if (result.patientId) {
      this.sendSyncPush(result.patientId, 'reminder_updated', id);
    }
    return result;
  }

  @Delete(':id')
  @AllowAnonymous()
  async remove(@Param('id') id: string) {
    const result = await this.reminderService.remove(id);
    if (result.patientId) {
      this.sendSyncPush(result.patientId, 'reminder_deleted', id);
    }
    return result;
  }

  @Post(':id/complete')
  @AllowAnonymous()
  async markComplete(@Param('id') id: string) {
    const result = await this.reminderService.markComplete(id);
    if (result.patientId) {
      this.sendSyncPush(result.patientId, 'reminder_completed', id);
    }
    return result;
  }

  private sendSyncPush(patientId: string, action: string, reminderId: string) {
    // Fire-and-forget: don't block the HTTP response
    this.apnsService
      .notifyPatientDevices(patientId, action, reminderId)
      .catch((err) => {
        this.logger.error(`Failed to send sync push: ${err}`);
      });
  }
}
