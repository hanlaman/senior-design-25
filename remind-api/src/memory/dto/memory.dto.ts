// Extracted memory from LLM
export interface ExtractedMemory {
  content: string;
  keywords: string[];
  contextDescription: string;
  suggestedType?: string;
  suggestedCategories?: string[];
  temporalRelevance?: string;
  eventDate?: string;
  emotionalTone?: string;
  relatedTo?: string[];
  confidence?: number;
}

// Full memory record from database
export interface MemoryRecord {
  id: string;
  patientId: string;
  content: string;
  keywords: string[] | null;
  contextDescription: string | null;
  suggestedType: string | null;
  suggestedCategories: string[] | null;
  temporalRelevance: string | null;
  eventDate: Date | null;
  emotionalTone: string | null;
  confidence: number;
  sourceSessionId: string | null;
  mentionCount: number;
  firstMentioned: Date;
  lastMentioned: Date;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}

// Memory with similarity score for retrieval
export interface ScoredMemory extends MemoryRecord {
  similarity?: number;
  recencyScore?: number;
  totalScore?: number;
}

// Memory link record
export interface MemoryLinkRecord {
  id: string;
  fromMemoryId: string;
  toMemoryId: string;
  linkType: string;
  linkStrength: number;
  linkReason: string | null;
  createdAt: Date;
}

// Request to create a memory
export interface CreateMemoryInput {
  patientId: string;
  content: string;
  keywords?: string[];
  contextDescription?: string;
  suggestedType?: string;
  suggestedCategories?: string[];
  temporalRelevance?: string;
  eventDate?: string;
  emotionalTone?: string;
  confidence?: number;
  sourceSessionId?: string;
}

// Response for memory context endpoint
export interface MemoryContextResponse {
  memories: ScoredMemory[];
  formattedContext: string;
  retrievedAt: Date;
}

// Request for memory context
export interface GetMemoryContextQuery {
  query?: string;
  sessionType?: 'greeting' | 'active' | 'followup';
  maxMemories?: number;
}

// Extraction result from a conversation
export interface ExtractionResult {
  sessionId: string;
  memoriesCreated: number;
  memoriesUpdated: number;
  linksCreated: number;
  processingTimeMs: number;
  memories: ExtractedMemory[];
}
