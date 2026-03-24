import { Module } from '@nestjs/common';
import { ApnsModule } from '../apns/apns.module';
import { LocationController } from './location.controller';
import { LocationService } from './location.service';
import { GeofenceService } from './geofence.service';

@Module({
  imports: [ApnsModule],
  controllers: [LocationController],
  providers: [LocationService, GeofenceService],
})
export class LocationModule {}
