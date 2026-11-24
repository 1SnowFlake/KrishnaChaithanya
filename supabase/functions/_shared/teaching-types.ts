// ============================================================
// TypeScript Definitions for AI Teaching Tools (Lesson Plan, Worksheet, Quiz)
// ============================================================

export type ContentType = "lesson_plan" | "worksheet" | "quiz";

// ── 1. LESSON PLAN TYPES ─────────────────────────────────────
export interface LessonStep {
  stepName: "warm_up" | "introduction" | "main_activity" | "practice" | "assessment" | "wrap_up";
  title: string;
  durationMinutes: number;
  instructions: string;
  teacherActions: string;
  studentActions: string;
}

export interface AccommodationDetail {
  need: string;                       // e.g. 'autism_spectrum', 'visual_impairment'
  strategy: string;                   // Educational recommendation
  materialsSuggested: string[];
}

export interface LessonPlanContent {
  title: string;
  subject: string;
  grade: string;
  durationMinutes: number;
  language: string;
  objectives: string[];
  prerequisiteKnowledge: string[];
  materialsList: string[];
  steps: LessonStep[];
  accommodations: AccommodationDetail[];
  questionsToAsk: string[];
  homeworkOrExtension: string;
  assessmentIdeas: string;
  noteForParents: string;
  pedagogicalDisclaimer: string;      // "Educational suggestions only; not medical or diagnostic therapy."
}

// ── 2. WORKSHEET TYPES ───────────────────────────────────────
export type WorksheetQuestionType =
  | "fill_in_the_blanks"
  | "match_the_following"
  | "true_false"
  | "short_answer"
  | "circle_or_tick"
  | "trace_and_write"
  | "drawing_prompt";

export interface WorksheetQuestion {
  questionNumber: number;
  type: WorksheetQuestionType;
  prompt: string;
  options?: string[];                 // For circle/tick, match, true/false
  matchingPairs?: Array<{ left: string; right: string }>; // For matching
  answerSpaceLines?: number;          // For printable student answer space
  picturePromptUrl?: string;          // Optional icon or diagram prompt
  hint?: string;                      // Extra scaffold for special education
  answer: string;                     // Detailed answer for answer key
}

export interface WorksheetSection {
  sectionTitle: string;
  instructions: string;
  questions: WorksheetQuestion[];
}

export interface WorksheetContent {
  title: string;
  subject: string;
  grade: string;
  language: string;
  isLargePrintFriendly: boolean;
  instructions: string;
  sections: WorksheetSection[];
  answerKey: Array<{ questionNumber: number; answer: string; explanation?: string }>;
  teacherNotes: string;
}

// ── 3. QUIZ TYPES ────────────────────────────────────────────
export type QuizQuestionType = "multiple_choice" | "true_false" | "short_answer";

export interface QuizQuestion {
  questionNumber: number;
  type: QuizQuestionType;
  question: string;
  options: string[];                  // 2-4 options
  correctAnswerIndex: number;         // 0-based index of correct option
  correctAnswerText: string;
  explanation: string;                // Gentle 1-line explanation for learning
  difficulty: "easy" | "medium" | "hard";
  readAloudText: string;              // Simplified phonetic text for device TTS
}

export interface QuizContent {
  title: string;
  subject: string;
  grade: string;
  language: string;
  timeLimitMinutes?: number;          // Optional, no pressure by default
  questions: QuizQuestion[];
  celebrationMessage: string;         // Gentle encouraging closing message
}

// ── 4. GENERATION REQUEST & RESPONSE ─────────────────────────
export interface GenerateContentRequest {
  type: ContentType;
  subject: string;
  topic: string;
  grade: string;
  language?: string;                  // 'en', 'hi', 'kn'
  learnerNeeds?: string[];
  durationMinutes?: number;           // For lesson plans
  learningObjectives?: string;        // Optional teacher notes
  materialsAvailable?: string;        // Optional
  classSize?: number;

  // Worksheet / Quiz specific
  numberOfQuestions?: number;
  questionTypes?: string[];
  difficulty?: "easy" | "medium" | "mixed";
  isLargePrint?: boolean;
  timeLimitMinutes?: number;
}
