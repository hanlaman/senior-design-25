import { Module } from '@nestjs/common';
import { ApnsController } from './apns.controller';
import { AlertController } from './alert.controller';
import { ApnsService } from './apns.service';

@Module({
  controllers: [ApnsController, AlertController],
  providers: [ApnsService],
  exports: [ApnsService],
})
export class ApnsModule {}
