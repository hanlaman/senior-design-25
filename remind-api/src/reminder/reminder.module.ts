import { Module } from '@nestjs/common';
import { ReminderController } from './reminder.controller';
import { ReminderService } from './reminder.service';
import { ReminderScheduler } from './reminder.scheduler';
import { ApnsModule } from '../apns/apns.module';

@Module({
  imports: [ApnsModule],
  controllers: [ReminderController],
  providers: [ReminderService, ReminderScheduler],
})
export class ReminderModule {}
