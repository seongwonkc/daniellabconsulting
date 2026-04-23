-- ============================================================
-- DanielLab Consulting CRM — Supabase Migration
-- Run this in your Supabase SQL editor
-- Project: xhblmqhyumsnmaxfxxgg
-- ============================================================

-- ── 1. CONSULTING STUDENTS ───────────────────────────────────
-- Core student profile for the consulting track.
-- sat_student_id links to existing public.students if applicable.

CREATE TABLE public.consulting_students (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at          TIMESTAMPTZ DEFAULT now(),

  -- Identity
  name_ko             TEXT NOT NULL,               -- Korean name (e.g. 오준환)
  name_en             TEXT,                        -- English name (e.g. Patrick Kim)
  grade_year          TEXT,                        -- e.g. 'Rising Junior', 'Rising Senior'

  -- School
  school_current      TEXT,                        -- Current school
  school_next         TEXT,                        -- Transferring to (if applicable)
  school_next_date    TEXT,                        -- e.g. 'Fall 2026'

  -- Consulting profile
  narrative           TEXT,                        -- Core narrative / positioning
  spike               TEXT,                        -- Primary spike / focus area
  target_major        TEXT,
  target_schools      TEXT,                        -- JSON array as text or comma-separated

  -- Status
  status              TEXT DEFAULT 'active'
                        CHECK (status IN ('active', 'hold', 'inactive', 'graduated')),
  notes               TEXT,                        -- Free-form internal notes

  -- Assigned consultant
  consultant_id       UUID REFERENCES public.teachers(id),

  -- Link to SAT CRM if student is in both tracks
  sat_student_id      UUID REFERENCES public.students(id),

  -- Parent contact
  parent_name         TEXT,
  parent_kakao        TEXT,
  parent_contact      TEXT,
  preferred_contact   TEXT DEFAULT 'kakao'
                        CHECK (preferred_contact IN ('kakao', 'phone', 'email'))
);

-- ── 2. CONSULTING ACTIVITIES ─────────────────────────────────
-- EC activities, competitions, programs per student.
-- Mirrors the EC checklist spreadsheet structure.

CREATE TABLE public.consulting_activities (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at          TIMESTAMPTZ DEFAULT now(),
  student_id          UUID NOT NULL REFERENCES public.consulting_students(id) ON DELETE CASCADE,

  -- Activity details
  name                TEXT NOT NULL,               -- e.g. 'Iowa Young Writers Studio'
  category            TEXT                         -- 'competition' | 'program' | 'research' | 'internship' | 'volunteer' | 'project' | 'other'
                        CHECK (category IN ('competition','program','research','internship','volunteer','project','other')),
  description         TEXT,

  -- Timeline
  timing              TEXT,                        -- e.g. '26년 여름'
  deadline            DATE,                        -- Specific deadline if known
  deadline_note       TEXT,                        -- e.g. 'Rolling admission'

  -- Status
  status              TEXT DEFAULT 'planned'
                        CHECK (status IN ('planned','in_progress','submitted','completed','rejected','waitlisted','accepted','cancelled')),

  -- Results
  result              TEXT,                        -- e.g. 'Gold Key', 'Writing Style Award'
  result_date         DATE,

  -- Meta
  url                 TEXT,
  cost_note           TEXT,
  internal_note       TEXT,
  assigned_to         TEXT                         -- e.g. 'Kevin', 'Jr. Consultant', '성원쌤'
);

-- ── 3. CONSULTING NOTES ──────────────────────────────────────
-- Meeting notes, strategy updates, parent comms log per student.

CREATE TABLE public.consulting_notes (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at          TIMESTAMPTZ DEFAULT now(),
  student_id          UUID NOT NULL REFERENCES public.consulting_students(id) ON DELETE CASCADE,

  -- Note metadata
  note_type           TEXT DEFAULT 'meeting'
                        CHECK (note_type IN ('meeting','strategy','parent_comms','internal','ai_summary')),
  author              TEXT,                        -- e.g. 'Kevin', 'Daniel'
  title               TEXT,

  -- Content
  content             TEXT NOT NULL,

  -- For parent comms log
  contact_method      TEXT                         -- 'kakao' | 'phone' | 'email'
                        CHECK (contact_method IN ('kakao','phone','email') OR contact_method IS NULL)
);

-- ── 4. CONSULTING ACTION ITEMS ───────────────────────────────
-- Pending tasks per student with owner + due date.
-- Powers the weekly rhythm checklist.

CREATE TABLE public.consulting_action_items (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at          TIMESTAMPTZ DEFAULT now(),
  student_id          UUID NOT NULL REFERENCES public.consulting_students(id) ON DELETE CASCADE,

  -- Task
  title               TEXT NOT NULL,
  description         TEXT,
  owner               TEXT,                        -- 'Kevin' | 'Daniel' | 'Jr. Consultant' | 'Student'
  due_date            DATE,
  priority            TEXT DEFAULT 'normal'
                        CHECK (priority IN ('urgent','high','normal','low')),

  -- Status
  completed           BOOLEAN DEFAULT false,
  completed_at        TIMESTAMPTZ,
  completed_by        TEXT
);

-- ── 5. INDEXES ───────────────────────────────────────────────

CREATE INDEX idx_consulting_activities_student   ON public.consulting_activities(student_id);
CREATE INDEX idx_consulting_activities_status    ON public.consulting_activities(status);
CREATE INDEX idx_consulting_activities_deadline  ON public.consulting_activities(deadline);
CREATE INDEX idx_consulting_notes_student        ON public.consulting_notes(student_id);
CREATE INDEX idx_consulting_notes_type           ON public.consulting_notes(note_type);
CREATE INDEX idx_consulting_action_items_student ON public.consulting_action_items(student_id);
CREATE INDEX idx_consulting_action_items_done    ON public.consulting_action_items(completed);
CREATE INDEX idx_consulting_action_items_due     ON public.consulting_action_items(due_date);

-- ── 6. RLS POLICIES ──────────────────────────────────────────
-- Admins (from public.admins) can read/write all consulting data.
-- No student-facing access — this is internal only.

ALTER TABLE public.consulting_students    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consulting_activities  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consulting_notes       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consulting_action_items ENABLE ROW LEVEL SECURITY;

-- Allow authenticated admins full access
CREATE POLICY "admins_all_consulting_students"
  ON public.consulting_students
  FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.admins WHERE id = auth.uid())
  );

CREATE POLICY "admins_all_consulting_activities"
  ON public.consulting_activities
  FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.admins WHERE id = auth.uid())
  );

CREATE POLICY "admins_all_consulting_notes"
  ON public.consulting_notes
  FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.admins WHERE id = auth.uid())
  );

CREATE POLICY "admins_all_consulting_action_items"
  ON public.consulting_action_items
  FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.admins WHERE id = auth.uid())
  );

-- ── 7. COMMENTS ──────────────────────────────────────────────

COMMENT ON TABLE public.consulting_students     IS 'DanielLab 고등부 consulting track students';
COMMENT ON TABLE public.consulting_activities   IS 'EC activities, competitions, programs per consulting student';
COMMENT ON TABLE public.consulting_notes        IS 'Meeting notes, strategy updates, parent comms log';
COMMENT ON TABLE public.consulting_action_items IS 'Pending tasks per student — powers weekly checklist';
