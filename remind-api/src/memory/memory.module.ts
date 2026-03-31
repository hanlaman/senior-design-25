import { Module } from '@nestjs/common';
import { MemoryController } from './memory.controller';
import { MemoryService } from './memory.service';
import { EmbeddingService } from './embedding.service';
import { ExtractionService } from './extraction.service';
import { RetrievalService } from './retrieval.service';
import { PatientFactModule } from '../patient-fact/patient-fact.module';

@Module({
  imports: [PatientFactModule],
  controllers: [MemoryController],
  providers: [
    MemoryService,
    EmbeddingService,
    ExtractionService,
    RetrievalService,
  ],
  exports: [MemoryService, ExtractionService, RetrievalService],
})
export class MemoryModule {}
