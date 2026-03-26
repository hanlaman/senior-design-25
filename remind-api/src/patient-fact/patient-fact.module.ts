import { Module } from '@nestjs/common';
import { PatientFactController } from './patient-fact.controller';
import { PatientFactService } from './patient-fact.service';

@Module({
  controllers: [PatientFactController],
  providers: [PatientFactService],
  exports: [PatientFactService],
})
export class PatientFactModule {}
