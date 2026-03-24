import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { AzureOpenAI } from 'openai';

interface ConversationMessage {
  role: 'user' | 'assistant';
  content: string;
}

@Injectable()
export class SummarizationService implements OnModuleInit {
  private readonly logger = new Logger(SummarizationService.name);
  private client: AzureOpenAI | null = null;
  private deploymentName: string | null = null;

  onModuleInit() {
    const endpoint = process.env.AZURE_OPENAI_ENDPOINT;
    const apiKey = process.env.AZURE_OPENAI_API_KEY;
    this.deploymentName =
      process.env.AZURE_OPENAI_DEPLOYMENT_NAME || 'conversation-summarizer';

    if (!endpoint || !apiKey) {
      this.logger.warn(
        'Azure OpenAI environment variables not set (AZURE_OPENAI_ENDPOINT, AZURE_OPENAI_API_KEY). Summarization disabled.',
      );
      return;
    }

    this.client = new AzureOpenAI({
      endpoint,
      apiKey,
      apiVersion: '2024-08-01-preview',
    });

    this.logger.log('Azure OpenAI client initialized for summarization');
  }

  async summarize(messages: ConversationMessage[]): Promise<string | null> {
    if (!this.client || !this.deploymentName) {
      this.logger.warn('Summarization skipped - Azure OpenAI not configured');
      return null;
    }

    if (messages.length === 0) {
      return null;
    }

    const formattedMessages = messages
      .map(
        (m) => `${m.role === 'user' ? 'Patient' : 'Assistant'}: ${m.content}`,
      )
      .join('\n');

    const prompt = `You are an AI assistant helping caregivers of dementia patients.
Summarize the following conversation between a dementia patient and their AI companion.

Focus on:
- Key topics discussed or questions asked
- Any signs of confusion, disorientation, or distress
- Mentions of people, places, or events
- Any health concerns or physical symptoms mentioned
- The patient's emotional state during the conversation

Keep the summary concise (2-4 sentences) and factual. Use third person (e.g., "The patient asked about...").
If the conversation is too short or lacks meaningful content, simply state that.

Conversation:
${formattedMessages}

Summary:`;

    try {
      const response = await this.client.chat.completions.create({
        model: this.deploymentName,
        messages: [{ role: 'user', content: prompt }],
        max_tokens: 300,
        temperature: 0.3,
      });

      const summary = response.choices[0]?.message?.content?.trim();

      if (!summary) {
        this.logger.warn('Empty summary received from Azure OpenAI');
        return null;
      }

      return summary;
    } catch (error) {
      this.logger.error(`Summarization failed: ${error}`);
      return null;
    }
  }
}
