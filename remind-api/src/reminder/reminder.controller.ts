import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
} from '@nestjs/common';
import { AllowAnonymous } from '@thallesp/nestjs-better-auth';
import { ReminderService } from './reminder.service';

@Controller('reminders')
export class ReminderController {
  constructor(private readonly reminderService: ReminderService) {}

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
    return this.reminderService.create(body);
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
    return this.reminderService.update(id, body);
  }

  @Delete(':id')
  @AllowAnonymous()
  async remove(@Param('id') id: string) {
    return this.reminderService.remove(id);
  }

  @Post(':id/complete')
  @AllowAnonymous()
  async markComplete(@Param('id') id: string) {
    return this.reminderService.markComplete(id);
  }
}
