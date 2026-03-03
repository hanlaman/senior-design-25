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
import { SafeZoneService } from './safezone.service';

@Controller('safezones')
export class SafeZoneController {
  constructor(private readonly safeZoneService: SafeZoneService) {}

  @Post()
  @AllowAnonymous()
  async create(
    @Body()
    body: {
      patientId: string;
      name: string;
      centerLatitude: number;
      centerLongitude: number;
      radiusMeters: number;
      durationMinutes?: number;
    },
  ) {
    return this.safeZoneService.create(body.patientId, {
      name: body.name,
      centerLatitude: body.centerLatitude,
      centerLongitude: body.centerLongitude,
      radiusMeters: body.radiusMeters,
      durationMinutes: body.durationMinutes,
    });
  }

  @Get(':patientId')
  @AllowAnonymous()
  async findAll(@Param('patientId') patientId: string) {
    return this.safeZoneService.findAll(patientId);
  }

  @Put(':id')
  @AllowAnonymous()
  async update(
    @Param('id') id: string,
    @Body()
    body: Partial<{
      name: string;
      centerLatitude: number;
      centerLongitude: number;
      radiusMeters: number;
      durationMinutes: number;
      isEnabled: boolean;
    }>,
  ) {
    return this.safeZoneService.update(id, body);
  }

  @Delete(':id')
  @AllowAnonymous()
  async remove(@Param('id') id: string) {
    return this.safeZoneService.remove(id);
  }
}
