import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { AzureOpenAI } from 'openai';

@Injectable()
export class EmbeddingService implements OnModuleInit {
  private readonly logger = new Logger(EmbeddingService.name);
  private client: AzureOpenAI | null = null;
  private embeddingDeployment: string | null = null;

  // Embedding dimension for text-embedding-3-small
  static readonly EMBEDDING_DIMENSION = 1536;

  onModuleInit() {
    const endpoint = process.env.AZURE_OPENAI_ENDPOINT;
    const apiKey = process.env.AZURE_OPENAI_API_KEY;
    this.embeddingDeployment =
      process.env.AZURE_OPENAI_EMBEDDING_DEPLOYMENT || 'text-embedding-3-small';

    if (!endpoint || !apiKey) {
      this.logger.warn(
        'Azure OpenAI environment variables not set. Embedding generation disabled.',
      );
      return;
    }

    this.client = new AzureOpenAI({
      endpoint,
      apiKey,
      apiVersion: '2024-08-01-preview',
    });

    this.logger.log(
      `Embedding service initialized with deployment: ${this.embeddingDeployment}. ` +
      `Note: Create this deployment in Azure OpenAI if embeddings fail.`,
    );
  }

  /**
   * Generate embedding vector for text content
   */
  async generateEmbedding(text: string): Promise<number[] | null> {
    if (!this.client || !this.embeddingDeployment) {
      this.logger.warn('Embedding skipped - Azure OpenAI not configured');
      return null;
    }

    if (!text || text.trim().length === 0) {
      return null;
    }

    try {
      const response = await this.client.embeddings.create({
        model: this.embeddingDeployment,
        input: text.trim(),
      });

      const embedding = response.data[0]?.embedding;

      if (
        !embedding ||
        embedding.length !== EmbeddingService.EMBEDDING_DIMENSION
      ) {
        this.logger.warn(
          `Unexpected embedding dimension: ${embedding?.length ?? 0}`,
        );
        return null;
      }

      return embedding;
    } catch (error) {
      this.logger.error(`Embedding generation failed: ${error}`);
      return null;
    }
  }

  /**
   * Convert embedding array to Buffer for database storage
   */
  embeddingToBuffer(embedding: number[]): Buffer {
    const buffer = Buffer.alloc(embedding.length * 4); // 4 bytes per float
    embedding.forEach((val, i) => {
      buffer.writeFloatLE(val, i * 4);
    });
    return buffer;
  }

  /**
   * Convert Buffer from database back to embedding array
   */
  bufferToEmbedding(buffer: Buffer): number[] {
    const embedding: number[] = [];
    for (let i = 0; i < buffer.length; i += 4) {
      embedding.push(buffer.readFloatLE(i));
    }
    return embedding;
  }

  /**
   * Calculate cosine similarity between two embeddings
   */
  cosineSimilarity(a: number[], b: number[]): number {
    if (a.length !== b.length) {
      throw new Error('Embeddings must have same dimension');
    }

    let dotProduct = 0;
    let magnitudeA = 0;
    let magnitudeB = 0;

    for (let i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      magnitudeA += a[i] * a[i];
      magnitudeB += b[i] * b[i];
    }

    magnitudeA = Math.sqrt(magnitudeA);
    magnitudeB = Math.sqrt(magnitudeB);

    if (magnitudeA === 0 || magnitudeB === 0) {
      return 0;
    }

    return dotProduct / (magnitudeA * magnitudeB);
  }

  /**
   * Find most similar items from a list based on query embedding
   */
  findMostSimilar<T extends { embedding: Buffer | null }>(
    queryEmbedding: number[],
    items: T[],
    topK: number = 10,
    minSimilarity: number = 0,
  ): Array<T & { similarity: number }> {
    const results = items
      .filter((item) => item.embedding !== null)
      .map((item) => {
        const itemEmbedding = this.bufferToEmbedding(item.embedding!);
        const similarity = this.cosineSimilarity(queryEmbedding, itemEmbedding);
        return { ...item, similarity };
      })
      .filter((item) => item.similarity >= minSimilarity)
      .sort((a, b) => b.similarity - a.similarity)
      .slice(0, topK);

    return results;
  }
}
