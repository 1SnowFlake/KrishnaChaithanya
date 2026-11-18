// ============================================================
// Shared TypeScript Types for AI Learning Assistant Edge Functions
// ============================================================

export interface CandidateVideo {
  videoId: string;
  title: string;
  description: string;
  channelTitle: string;
  durationSeconds: number;
  hasCaptions: boolean;
  thumbnailUrl: string;
}

export interface ScoredVideo {
  videoId: string;
  title: string;
  channelTitle: string;
  durationSeconds: number;
  thumbnailUrl: string;
  score: number;                      // 0 - 100
  reason: string;                     // 1-2 sentence accessibility assessment
  accessibilityTags: string[];        // e.g. ["Clear Narration", "High Contrast Visuals", "Captioned"]
  warnings: string[];                 // e.g. ["Pacing is slightly fast", "Mild background music"]
}

export interface LessonScene {
  sceneNumber: number;
  durationSeconds: number;            // 10 - 25s per scene
  narrationText: string;              // Simple spoken text for TTS
  onScreenText: string;               // Large, readable text on slide
  imagePrompt: string;                // Descriptive prompt for image generation
  visualDescription: string;          // For visually impaired audio-description
}

export interface LessonScript {
  title: string;
  topic: string;
  targetNeeds: string[];
  ageGroup: string;
  language: string;
  scenes: LessonScene[];
  pedagogicalNotes: string;           // Note for teacher on how to reinforce
}

export interface AiUsageRecord {
  feature: "suggest_videos" | "generate_script" | "generate_video";
  tokensUsed: number;
  estimatedCostUsd: number;
  metadata?: Record<string, unknown>;
}
