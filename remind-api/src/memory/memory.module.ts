import { Module } from '@nestjs/common';
import { MemoryController } from './memory.controller';
import { MemoryService } from './memory.service';
import { EmbeddingService } from './embedding.service';
import { ExtractionService } from './extraction.service';
import { RetrievalService } from './retrieval.service';

@Module({
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
