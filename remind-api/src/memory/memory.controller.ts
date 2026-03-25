import { Controller, Get, Param, Query, Delete, Logger } from '@nestjs/common';
import { AllowAnonymous } from '@thallesp/nestjs-better-auth';
import { RetrievalService } from './retrieval.service';
import { MemoryService } from './memory.service';
import { MemoryContextResponse, GetMemoryContextQuery } from './dto/memory.dto';

@Controller('memory')
export class MemoryController {
  private readonly logger = new Logger(MemoryController.name);

  constructor(
    private readonly retrievalService: RetrievalService,
    private readonly memoryService: MemoryService,
  ) {}

  /**
   * Get memory context for a patient
   * Used by watch app to inject context into system prompt
   */
  @Get('context/:patientId')
  @AllowAnonymous()
  async getMemoryContext(
    @Param('patientId') patientId: string,
    @Query('query') query?: string,
    @Query('sessionType') sessionType?: 'greeting' | 'active' | 'followup',
    @Query('maxMemories') maxMemories?: string,
  ): Promise<MemoryContextResponse> {
    this.logger.log(
      `Fetching memory context for patient ${patientId}, sessionType: ${sessionType}`,
    );

    const options: GetMemoryContextQuery = {
      query,
      sessionType,
      maxMemories: maxMemories ? parseInt(maxMemories, 10) : undefined,
    };

    return this.retrievalService.getMemoryContext(patientId, options);
  }

  /**
   * Get all memories for a patient
   */
  @Get(':patientId')
  async getMemories(@Param('patientId') patientId: string) {
    this.logger.log(`Fetching all memories for patient ${patientId}`);
    const memories = await this.memoryService.getMemoriesForPatient(patientId);
    return {
      patientId,
      count: memories.length,
      memories,
    };
  }

  /**
   * Get a specific memory by ID
   */
  @Get(':patientId/:memoryId')
  async getMemory(
    @Param('patientId') patientId: string,
    @Param('memoryId') memoryId: string,
  ) {
    const memory = await this.memoryService.getMemoryById(memoryId);

    if (!memory || memory.patientId !== patientId) {
      return { error: 'Memory not found' };
    }

    // Also fetch linked memories
    const linkedMemories = await this.memoryService.getLinkedMemories(memoryId);

    return {
      memory,
      linkedMemories,
    };
  }

  /**
   * Deactivate (soft delete) a memory
   */
  @Delete(':patientId/:memoryId')
  async deactivateMemory(
    @Param('patientId') patientId: string,
    @Param('memoryId') memoryId: string,
  ) {
    const memory = await this.memoryService.getMemoryById(memoryId);

    if (!memory || memory.patientId !== patientId) {
      return { success: false, error: 'Memory not found' };
    }

    const success = await this.memoryService.deactivateMemory(memoryId);
    return { success, patientId, memoryId };
  }
}
