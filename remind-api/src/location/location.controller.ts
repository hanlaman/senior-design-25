import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { AllowAnonymous } from '@thallesp/nestjs-better-auth';
import { LocationService } from './location.service';
import { GeofenceService } from './geofence.service';

@Controller('location')
export class LocationController {
  constructor(
    private readonly locationService: LocationService,
    private readonly geofenceService: GeofenceService,
  ) {}

  @Post()
  @AllowAnonymous()
  async postLocation(
    @Body() body: { patientId: string; latitude: number; longitude: number },
  ) {
    const result = await this.locationService.createLocation(
      body.patientId,
      body.latitude,
      body.longitude,
    );

    this.geofenceService
      .checkGeofence(body.patientId, body.latitude, body.longitude)
      .catch((err) => {
        // fire-and-forget: don't block the location response
      });

    return result;
  }

  @Get(':patientId')
  @AllowAnonymous()
  async getLocation(@Param('patientId') patientId: string) {
    return this.locationService.getLatestLocation(patientId);
  }
}
