import { Body, Controller, Post } from '@nestjs/common';
import { AllowAnonymous } from '@thallesp/nestjs-better-auth';
import { ApnsService } from './apns.service';

@Controller('alerts')
export class AlertController {
  constructor(private readonly apnsService: ApnsService) {}

  @Post()
  @AllowAnonymous()
  async sendCaregiverAlert(
    @Body() body: { patientId: string; message: string; alertType: string },
  ) {
    return this.apnsService.sendCaregiverAlert(
      body.patientId,
      body.message,
      body.alertType,
    );
  }
}
