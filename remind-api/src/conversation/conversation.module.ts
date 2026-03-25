import { Module } from '@nestjs/common';
import { ConversationController } from './conversation.controller';
import { ConversationService } from './conversation.service';
import { SummarizationModule } from '../summarization/summarization.module';
import { MemoryModule } from '../memory/memory.module';

@Module({
  imports: [SummarizationModule, MemoryModule],
  controllers: [ConversationController],
  providers: [ConversationService],
})
export class ConversationModule {}
