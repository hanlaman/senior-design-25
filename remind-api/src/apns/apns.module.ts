import { Module } from '@nestjs/common';
import { ApnsController } from './apns.controller';
import { ApnsService } from './apns.service';

@Module({
  controllers: [ApnsController],
  providers: [ApnsService],
  exports: [ApnsService],
})
export class ApnsModule {}
