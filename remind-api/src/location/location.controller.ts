import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { AllowAnonymous } from '@thallesp/nestjs-better-auth';
import { LocationService } from './location.service';

@Controller('location')
export class LocationController {
  constructor(private readonly locationService: LocationService) {}

  @Post()
  @AllowAnonymous()
  async postLocation(
    @Body() body: { patientId: string; latitude: number; longitude: number },
  ) {
    return this.locationService.createLocation(
      body.patientId,
      body.latitude,
      body.longitude,
    );
  }

  @Get(':patientId')
  @AllowAnonymous()
  async getLocation(@Param('patientId') patientId: string) {
    return this.locationService.getLatestLocation(patientId);
  }
}
