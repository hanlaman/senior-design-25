import {
  Body,
  Controller,
  Delete,
  Get,
  Logger,
  Param,
  Post,
  Query,
} from '@nestjs/common';
import { AllowAnonymous } from '@thallesp/nestjs-better-auth';
import { ConversationService } from './conversation.service';

interface ConversationMessageInput {
  azureItemId: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: string;
  sequenceNumber: number;
}

interface CreateConversationInput {
  patientId: string;
  azureSessionId: string;
  startTime: string;
  endTime: string | null;
  messages: ConversationMessageInput[];
}

@Controller('conversations')
export class ConversationController {
  private readonly logger = new Logger(ConversationController.name);

  constructor(private readonly conversationService: ConversationService) {}

  @Post()
  @AllowAnonymous()
  async create(@Body() body: CreateConversationInput) {
    this.logger.log(
      `Uploading conversation: ${body.azureSessionId} with ${body.messages.length} messages`,
    );
    return this.conversationService.create(body);
  }

  @Get(':patientId')
  @AllowAnonymous()
  async findAll(
    @Param('patientId') patientId: string,
    @Query('page') page?: string,
    @Query('pageSize') pageSize?: string,
  ) {
    return this.conversationService.findAllForPatient(
      patientId,
      page ? parseInt(page, 10) : 1,
      pageSize ? parseInt(pageSize, 10) : 20,
    );
  }

  @Get(':patientId/:sessionId')
  @AllowAnonymous()
  async findOne(
    @Param('patientId') patientId: string,
    @Param('sessionId') sessionId: string,
  ) {
    const session = await this.conversationService.findOne(
      patientId,
      sessionId,
    );
    if (!session) {
      return { success: false, message: 'Session not found' };
    }
    return session;
  }

  @Delete(':sessionId')
  @AllowAnonymous()
  async remove(@Param('sessionId') sessionId: string) {
    return this.conversationService.remove(sessionId);
  }
}
