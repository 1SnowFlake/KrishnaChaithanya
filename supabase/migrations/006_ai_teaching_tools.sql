-- ============================================================
-- School Attendance App – Migration 006: AI Teaching Tools
-- Run this in your Supabase SQL Editor.
-- Adds tables, indexes, and RLS policies for:
--   1. AI Content Library (Lesson Plans, Worksheets, Quizzes)
--   2. AI Usage & Provider Fallback Audit Log
--   3. Teacher Quotas & Global Daily Caps
-- ============================================================

-- ── 1. AI CONTENT TABLE ──────────────────────────────────────
-- Stores generated & teacher-edited Lesson Plans, Worksheets, and Quizzes.
CREATE TABLE IF NOT EXISTS ai_content (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type           TEXT NOT NULL CHECK (type IN ('lesson_plan', 'worksheet', 'quiz')),
  title          TEXT NOT NULL,
  subject        TEXT NOT NULL,
  grade          TEXT NOT NULL,
  language       TEXT NOT NULL DEFAULT 'en',
  learner_needs  TEXT[] NOT NULL DEFAULT '{}',
  content        JSONB NOT NULL,                   -- Complete structured JSON
  class_id       UUID REFERENCES classes(id) ON DELETE SET NULL,
  created_by     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  is_shared      BOOLEAN NOT NULL DEFAULT false,   -- Shared with all teachers by Admin
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Fast lookup indexes
CREATE INDEX IF NOT EXISTS idx_ai_content_created_by ON ai_content(created_by);
CREATE INDEX IF NOT EXISTS idx_ai_content_type       ON ai_content(type);
CREATE INDEX IF NOT EXISTS idx_ai_content_class_id   ON ai_content(class_id);
CREATE INDEX IF NOT EXISTS idx_ai_content_is_shared  ON ai_content(is_shared);
CREATE INDEX IF NOT EXISTS idx_ai_content_subject    ON ai_content(subject);
CREATE INDEX IF NOT EXISTS idx_ai_content_created_at ON ai_content(created_at DESC);

-- ── 2. AI USAGE AUDIT LOG ────────────────────────────────────
-- Records every AI generation, which free provider answered, tokens, and status.
CREATE TABLE IF NOT EXISTS ai_usage_log (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  feature          TEXT NOT NULL,                  -- 'lesson_plan', 'worksheet', 'quiz'
  provider         TEXT NOT NULL,                  -- 'groq', 'gemini', 'openrouter'
  status           TEXT NOT NULL DEFAULT 'success',-- 'success', 'rate_limited', 'fallback', 'failed'
  tokens_estimate  INTEGER NOT NULL DEFAULT 0,
  request_metadata JSONB,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Safely add columns if ai_usage_log already existed from prior migrations
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'ai_usage_log' AND column_name = 'provider') THEN
    ALTER TABLE ai_usage_log ADD COLUMN provider TEXT NOT NULL DEFAULT 'groq';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'ai_usage_log' AND column_name = 'status') THEN
    ALTER TABLE ai_usage_log ADD COLUMN status TEXT NOT NULL DEFAULT 'success';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'ai_usage_log' AND column_name = 'tokens_estimate') THEN
    ALTER TABLE ai_usage_log ADD COLUMN tokens_estimate INTEGER NOT NULL DEFAULT 0;
  END IF;
  -- Remove restrictive check on feature if one existed previously
  ALTER TABLE ai_usage_log DROP CONSTRAINT IF EXISTS ai_usage_log_feature_check;
END $$;

CREATE INDEX IF NOT EXISTS idx_ai_usage_log_user_date ON ai_usage_log(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_usage_log_feature   ON ai_usage_log(feature);
CREATE INDEX IF NOT EXISTS idx_ai_usage_log_provider  ON ai_usage_log(provider);

-- ── 3. AI QUOTAS & GLOBAL DAILY CAPS ─────────────────────────
CREATE TABLE IF NOT EXISTS ai_teaching_quotas (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  per_teacher_daily_limit  INTEGER NOT NULL DEFAULT 20,   -- Max generations per teacher/day
  global_daily_cap         INTEGER NOT NULL DEFAULT 200,  -- Max generations across whole school/day
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed single singleton row
INSERT INTO ai_teaching_quotas (per_teacher_daily_limit, global_daily_cap)
SELECT 20, 200
WHERE NOT EXISTS (SELECT 1 FROM ai_teaching_quotas);

-- ── 4. ROW LEVEL SECURITY (RLS) POLICIES ─────────────────────

ALTER TABLE ai_content          ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_usage_log        ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_teaching_quotas  ENABLE ROW LEVEL SECURITY;

-- ── ai_content Policies ──

-- Admin: full access to all teaching content
CREATE POLICY "admin_all_ai_content"
  ON ai_content FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- Teachers: read their own content OR items shared by admin
CREATE POLICY "teacher_read_ai_content"
  ON ai_content FOR SELECT
  USING (
    is_active_user()
    AND (
      created_by = auth.uid()
      OR is_shared = true
    )
  );

-- Teachers: insert only their own content
CREATE POLICY "teacher_insert_ai_content"
  ON ai_content FOR INSERT
  WITH CHECK (
    is_active_user()
    AND created_by = auth.uid()
  );

-- Teachers: update only their own content (cannot unshare or edit another teacher's item)
CREATE POLICY "teacher_update_ai_content"
  ON ai_content FOR UPDATE
  USING (
    is_active_user()
    AND created_by = auth.uid()
  )
  WITH CHECK (
    is_active_user()
    AND created_by = auth.uid()
  );

-- Teachers: delete only their own content
CREATE POLICY "teacher_delete_ai_content"
  ON ai_content FOR DELETE
  USING (
    is_active_user()
    AND created_by = auth.uid()
  );

-- ── ai_usage_log Policies ──

-- Admin: full visibility of usage log across all teachers
CREATE POLICY "admin_all_ai_usage_log"
  ON ai_usage_log FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- Teachers: read only their own usage history (transparency)
CREATE POLICY "teacher_read_own_ai_usage"
  ON ai_usage_log FOR SELECT
  USING (
    is_active_user()
    AND user_id = auth.uid()
  );

-- Note: Clients cannot INSERT/UPDATE/DELETE ai_usage_log.
-- Edge Functions use the service_role key to record usage server-side.

-- ── ai_teaching_quotas Policies ──

-- Admin: full CRUD on quotas
CREATE POLICY "admin_manage_ai_quotas"
  ON ai_teaching_quotas FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- Teachers: read quota limits
CREATE POLICY "everyone_read_ai_quotas"
  ON ai_teaching_quotas FOR SELECT
  USING (is_active_user());
