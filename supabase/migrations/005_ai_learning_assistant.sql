-- ============================================================
-- School Attendance App – Migration 005: AI Learning Assistant
-- Run this in your Supabase SQL Editor.
-- Adds tables, RLS policies, indexes, and storage bucket
-- for YouTube accessibility search and accessible video generator.
-- ============================================================

-- ── 1. VIDEO SEARCH CACHE ────────────────────────────────────
-- YouTube API search results are cached for 7 days to conserve
-- quota and speed up repeated queries for common special-ed topics.
CREATE TABLE IF NOT EXISTS video_search_cache (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cache_key      TEXT NOT NULL UNIQUE,       -- SHA256 / MD5 of (keywords + needs + language)
  query_keywords TEXT NOT NULL,
  learner_needs  TEXT[] NOT NULL,
  language       TEXT NOT NULL DEFAULT 'en',
  results        JSONB NOT NULL,             -- Array of top 5 scored videos
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at     TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '7 days')
);

CREATE INDEX IF NOT EXISTS idx_video_cache_key ON video_search_cache(cache_key);
CREATE INDEX IF NOT EXISTS idx_video_cache_expires ON video_search_cache(expires_at);

-- ── 2. SAVED VIDEOS (Class & Teacher Playlists) ──────────────
-- Videos bookmarked by teachers with AI accessibility metadata.
CREATE TABLE IF NOT EXISTS saved_videos (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  video_id           TEXT NOT NULL,          -- YouTube Video ID (e.g., 'dQw4w9WgXcQ')
  title              TEXT NOT NULL,
  channel_title      TEXT,
  thumbnail_url      TEXT,
  duration_seconds   INTEGER,
  accessibility_tags TEXT[] NOT NULL DEFAULT '{}',
  ai_score           INTEGER CHECK (ai_score BETWEEN 0 AND 100),
  ai_reason          TEXT,
  warning_notes      TEXT[] NOT NULL DEFAULT '{}',
  class_id           UUID REFERENCES classes(id) ON DELETE SET NULL,
  created_by         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  teacher_notes      TEXT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_saved_videos_user ON saved_videos(created_by);
CREATE INDEX IF NOT EXISTS idx_saved_videos_class ON saved_videos(class_id);
CREATE INDEX IF NOT EXISTS idx_saved_videos_vid ON saved_videos(video_id);

-- ── 3. VIDEO FEEDBACK & AUDIT ────────────────────────────────
-- Teachers mark videos as 'not_suitable' or 'reported'.
-- Used to penalize ranking or flag for admin review.
CREATE TABLE IF NOT EXISTS video_feedback (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  video_id      TEXT NOT NULL,
  feedback_type TEXT NOT NULL CHECK (feedback_type IN ('not_suitable', 'reported', 'helpful', 'favorite')),
  reason        TEXT,
  learner_needs TEXT[] NOT NULL DEFAULT '{}',
  created_by    UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_video_feedback_vid ON video_feedback(video_id);
CREATE INDEX IF NOT EXISTS idx_video_feedback_user ON video_feedback(created_by);

-- ── 4. GENERATED VIDEOS (Accessible Lesson Videos) ───────────
-- Holds script drafts, generation status, and stored media paths.
CREATE TABLE IF NOT EXISTS generated_videos (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  topic                  TEXT NOT NULL,
  learner_needs          TEXT[] NOT NULL DEFAULT '{}',
  age_group              TEXT NOT NULL,
  learning_level         TEXT NOT NULL DEFAULT 'beginner', -- 'beginner' | 'intermediate'
  language               TEXT NOT NULL DEFAULT 'en',
  script                 JSONB NOT NULL,                   -- Complete scene-by-scene script
  status                 TEXT NOT NULL CHECK (status IN ('draft', 'generating', 'ready', 'failed', 'approved')) DEFAULT 'draft',
  video_storage_path     TEXT,                             -- Path inside storage bucket
  caption_storage_path   TEXT,                             -- .vtt or .srt caption file
  thumbnail_storage_path TEXT,
  duration_seconds       INTEGER,
  error_message          TEXT,
  created_by             UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  approved_by            UUID REFERENCES profiles(id) ON DELETE SET NULL,
  approved_at            TIMESTAMPTZ,
  class_id               UUID REFERENCES classes(id) ON DELETE SET NULL,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_generated_videos_user ON generated_videos(created_by);
CREATE INDEX IF NOT EXISTS idx_generated_videos_status ON generated_videos(status);

-- ── 5. AI USAGE LOG (Cost Control & Daily Rate Limits) ──────
-- Tracks every AI invocation to protect against abuse and excessive API cost.
CREATE TABLE IF NOT EXISTS ai_usage_log (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  feature             TEXT NOT NULL CHECK (feature IN ('suggest_videos', 'generate_script', 'generate_video')),
  tokens_used         INTEGER NOT NULL DEFAULT 0,
  estimated_cost_usd  NUMERIC(8, 5) NOT NULL DEFAULT 0.00000,
  request_metadata    JSONB,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_usage_user_date ON ai_usage_log(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_ai_usage_feature ON ai_usage_log(feature);

-- ── 6. AI RATE LIMIT CONFIG ──────────────────────────────────
-- Allows admins to configure maximum daily AI requests per teacher.
CREATE TABLE IF NOT EXISTS ai_rate_limits (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  feature                  TEXT NOT NULL UNIQUE,
  daily_limit_per_teacher  INTEGER NOT NULL,
  description              TEXT,
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed default safe limits (e.g. 15 YouTube searches/day, 5 script generations/day)
INSERT INTO ai_rate_limits (feature, daily_limit_per_teacher, description)
VALUES
  ('suggest_videos', 15, 'Maximum YouTube searches with AI accessibility scoring per teacher/day'),
  ('generate_script', 5, 'Maximum AI lesson scripts written per teacher/day'),
  ('generate_video', 3, 'Maximum video render jobs queued per teacher/day')
ON CONFLICT (feature) DO NOTHING;

-- ── 7. ROW LEVEL SECURITY (RLS) POLICIES ─────────────────────

ALTER TABLE video_search_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_videos       ENABLE ROW LEVEL SECURITY;
ALTER TABLE video_feedback     ENABLE ROW LEVEL SECURITY;
ALTER TABLE generated_videos   ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_usage_log       ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_rate_limits     ENABLE ROW LEVEL SECURITY;

-- ── video_search_cache policies ──
-- Authenticated active users can read and insert search cache
CREATE POLICY "authenticated_read_video_cache"
  ON video_search_cache FOR SELECT
  USING (is_active_user());

CREATE POLICY "authenticated_insert_video_cache"
  ON video_search_cache FOR INSERT
  WITH CHECK (is_active_user());

-- ── saved_videos policies ──
-- Teachers manage their own saved videos; Admins have full oversight
CREATE POLICY "admin_all_saved_videos"
  ON saved_videos FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "teacher_manage_own_saved_videos"
  ON saved_videos FOR ALL
  USING (is_active_user() AND created_by = auth.uid())
  WITH CHECK (is_active_user() AND created_by = auth.uid());

CREATE POLICY "teacher_read_class_saved_videos"
  ON saved_videos FOR SELECT
  USING (
    is_active_user()
    AND (
      created_by = auth.uid()
      OR (class_id IS NOT NULL AND teacher_has_class_access(class_id))
    )
  );

-- ── video_feedback policies ──
CREATE POLICY "admin_all_video_feedback"
  ON video_feedback FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "teacher_manage_own_feedback"
  ON video_feedback FOR ALL
  USING (is_active_user() AND created_by = auth.uid())
  WITH CHECK (is_active_user() AND created_by = auth.uid());

-- ── generated_videos policies ──
CREATE POLICY "admin_all_generated_videos"
  ON generated_videos FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "teacher_manage_own_generated_videos"
  ON generated_videos FOR ALL
  USING (is_active_user() AND created_by = auth.uid())
  WITH CHECK (is_active_user() AND created_by = auth.uid());

CREATE POLICY "teacher_read_approved_class_videos"
  ON generated_videos FOR SELECT
  USING (
    is_active_user()
    AND status = 'approved'
    AND class_id IS NOT NULL
    AND teacher_has_class_access(class_id)
  );

-- ── ai_usage_log policies ──
CREATE POLICY "admin_all_ai_usage"
  ON ai_usage_log FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "teacher_read_own_usage"
  ON ai_usage_log FOR SELECT
  USING (is_active_user() AND user_id = auth.uid());

CREATE POLICY "teacher_insert_own_usage"
  ON ai_usage_log FOR INSERT
  WITH CHECK (is_active_user() AND user_id = auth.uid());

-- ── ai_rate_limits policies ──
CREATE POLICY "admin_manage_ai_rate_limits"
  ON ai_rate_limits FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "everyone_read_ai_rate_limits"
  ON ai_rate_limits FOR SELECT
  USING (is_active_user());

-- ── 8. STORAGE BUCKET FOR GENERATED VIDEOS & CAPTIONS ─────────
-- Creates a private bucket named 'learning_media'.
-- Media is accessed via short-lived signed URLs generated by the app/Edge Function.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'learning_media',
  'learning_media',
  false,                              -- Private bucket (requires signed URLs)
  52428800,                           -- 50 MB max per file
  ARRAY['video/mp4', 'text/vtt', 'text/plain', 'image/png', 'image/jpeg']
)
ON CONFLICT (id) DO NOTHING;

-- Storage policies on storage.objects
CREATE POLICY "admin_all_learning_media"
  ON storage.objects FOR ALL
  USING (bucket_id = 'learning_media' AND is_admin())
  WITH CHECK (bucket_id = 'learning_media' AND is_admin());

CREATE POLICY "teacher_read_learning_media"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'learning_media' AND is_active_user());

CREATE POLICY "teacher_insert_learning_media"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'learning_media'
    AND is_active_user()
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
