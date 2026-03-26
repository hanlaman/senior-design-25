import {
  Body,
  Controller,
  Delete,
  Get,
  Logger,
  Param,
  Post,
  Put,
} from '@nestjs/common';
import { AllowAnonymous } from '@thallesp/nestjs-better-auth';
import { PatientFactService } from './patient-fact.service';

@Controller('patient-facts')
export class PatientFactController {
  private readonly logger = new Logger(PatientFactController.name);

  constructor(private readonly patientFactService: PatientFactService) {}

  @Post()
  @AllowAnonymous()
  async create(
    @Body()
    body: {
      patientId: string;
      category: string;
      label: string;
      value: string;
    },
  ) {
    this.logger.log(
      `Creating patient fact for ${body.patientId}: ${body.label}`,
    );
    return this.patientFactService.create(body);
  }

  @Get(':patientId')
  @AllowAnonymous()
  async findAll(@Param('patientId') patientId: string) {
    return this.patientFactService.findAll(patientId);
  }

  @Put(':id')
  @AllowAnonymous()
  async update(
    @Param('id') id: string,
    @Body()
    body: Partial<{
      category: string;
      label: string;
      value: string;
    }>,
  ) {
    return this.patientFactService.update(id, body);
  }

  @Delete(':id')
  @AllowAnonymous()
  async remove(@Param('id') id: string) {
    return this.patientFactService.remove(id);
  }
}
