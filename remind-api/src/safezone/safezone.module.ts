import { Module } from '@nestjs/common';
import { SafeZoneController } from './safezone.controller';
import { SafeZoneService } from './safezone.service';

@Module({
  controllers: [SafeZoneController],
  providers: [SafeZoneService],
})
export class SafeZoneModule {}
