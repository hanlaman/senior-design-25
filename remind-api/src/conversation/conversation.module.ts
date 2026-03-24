import { Module } from '@nestjs/common';
import { ConversationController } from './conversation.controller';
import { ConversationService } from './conversation.service';
import { SummarizationModule } from '../summarization/summarization.module';

@Module({
  imports: [SummarizationModule],
  controllers: [ConversationController],
  providers: [ConversationService],
})
export class ConversationModule {}
