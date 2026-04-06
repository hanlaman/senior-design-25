import {
  Body,
  Controller,
  Delete,
  Get,
  Logger,
  Param,
  Put,
} from '@nestjs/common';
import { AllowAnonymous } from '@thallesp/nestjs-better-auth';
import { ContactService } from './contact.service';

@Controller('contacts')
export class ContactController {
  private readonly logger = new Logger(ContactController.name);

  constructor(private readonly contactService: ContactService) {}

  @Put()
  @AllowAnonymous()
  async upsert(
    @Body()
    body: {
      patientId: string;
      role: string;
      name: string;
      phoneNumber: string;
    },
  ) {
    this.logger.log(
      `Upserting contact for patient ${body.patientId}: ${body.role}`,
    );
    return this.contactService.upsert(body);
  }

  @Get(':patientId')
  @AllowAnonymous()
  async findAll(@Param('patientId') patientId: string) {
    return this.contactService.findAll(patientId);
  }

  @Get(':patientId/:role')
  @AllowAnonymous()
  async findByRole(
    @Param('patientId') patientId: string,
    @Param('role') role: string,
  ) {
    return this.contactService.findByRole(patientId, role);
  }

  @Delete(':id')
  @AllowAnonymous()
  async remove(@Param('id') id: string) {
    return this.contactService.remove(id);
  }
}
