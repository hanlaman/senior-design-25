import { Body, Controller, Post } from '@nestjs/common';
import { AllowAnonymous } from '@thallesp/nestjs-better-auth';
import { ApnsService } from './apns.service';

@Controller('device-tokens')
export class ApnsController {
  constructor(private readonly apnsService: ApnsService) {}

  @Post()
  @AllowAnonymous()
  async registerDeviceToken(
    @Body() body: { patientId: string; token: string; platform: string },
  ) {
    return this.apnsService.registerDeviceToken(
      body.patientId,
      body.token,
      body.platform,
    );
  }
}
