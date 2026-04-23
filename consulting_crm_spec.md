# DanielLab Consulting CRM — Technical Spec for Codex

## Overview

Build a new internal web app: **DanielLab 고등부 Consulting CRM**.

This is a **separate Netlify app** that shares the same Supabase backend as the existing SAT CRM (`daniellabsat` repo). It is for internal use only — no student-facing views. Users are admins (Daniel, Kevin, Jr. Consultant).

---

## Stack

Exactly match the existing `daniellabsat` repo conventions:

- **Vanilla HTML + CSS + JavaScript** — no framework, no build step
- **Supabase JS v2** via CDN: `https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2`
- **Fonts**: DM Sans + DM Serif Display via Google Fonts
- **Auth**: Supabase email/password (same `admins` table as SAT CRM)
- **Config**: `config.js` with `CONFIG.SUPABASE_URL` and `CONFIG.SUPABASE_KEY`
- **Netlify deploy**: static, `netlify.toml` injects env vars into `config.js`
- **Session**: `sessionStorage` for `dl_admin_name`, `dl_admin_role`
- **AI**: Google Gemini API (`gemini-2.0-flash`) — key stored in `CONFIG.GEMINI_KEY`

## CSS Design System

Copy these exact CSS variables from the SAT CRM:

```css
:root {
  --bg:        #f5f4f2;
  --surface:   #ffffff;
  --border:    #e2e0dc;
  --accent:    #c8102e;
  --accent-dim:#a30d25;
  --text:      #111111;
  --muted:     #888888;
  --good:      #2a7a4f;
  --warn:      #cc6600;
  --radius:    10px;
  --sans:      'DM Sans', sans-serif;
  --serif:     'DM Serif Display', serif;
}
```

---

## Supabase Schema (New Tables)

All tables are prefixed `consulting_`. Full SQL in `consulting_migration.sql`.

### `consulting_students`
| Column | Type | Notes |
|---|---|---|
| id | uuid PK | |
| name_ko | text | Korean name |
| name_en | text | English name |
| grade_year | text | e.g. 'Rising Junior' |
| school_current | text | |
| school_next | text | Transfer school if applicable |
| school_next_date | text | e.g. 'Fall 2026' |
| narrative | text | Core narrative |
| spike | text | Primary spike |
| target_major | text | |
| target_schools | text | |
| status | text | active / hold / inactive / graduated |
| notes | text | Internal notes |
| consultant_id | uuid FK → teachers | |
| sat_student_id | uuid FK → students | Optional link to SAT CRM |
| parent_name | text | |
| parent_kakao | text | |
| parent_contact | text | |
| preferred_contact | text | kakao / phone / email |

### `consulting_activities`
| Column | Type | Notes |
|---|---|---|
| id | uuid PK | |
| student_id | uuid FK → consulting_students | |
| name | text | Activity name |
| category | text | competition / program / research / internship / volunteer / project / other |
| description | text | |
| timing | text | e.g. '26년 여름' |
| deadline | date | |
| deadline_note | text | |
| status | text | planned / in_progress / submitted / completed / rejected / waitlisted / accepted / cancelled |
| result | text | Award name, acceptance, etc. |
| result_date | date | |
| url | text | |
| cost_note | text | |
| internal_note | text | |
| assigned_to | text | Kevin / Jr. Consultant / etc. |

### `consulting_notes`
| Column | Type | Notes |
|---|---|---|
| id | uuid PK | |
| student_id | uuid FK → consulting_students | |
| note_type | text | meeting / strategy / parent_comms / internal / ai_summary |
| author | text | Kevin / Daniel |
| title | text | |
| content | text | |
| contact_method | text | kakao / phone / email (for parent_comms type) |

### `consulting_action_items`
| Column | Type | Notes |
|---|---|---|
| id | uuid PK | |
| student_id | uuid FK → consulting_students | |
| title | text | |
| description | text | |
| owner | text | Kevin / Daniel / Jr. Consultant / Student |
| due_date | date | |
| priority | text | urgent / high / normal / low |
| completed | boolean | |
| completed_at | timestamptz | |
| completed_by | text | |

---

## Pages & File Structure

```
index.html                    → Landing / portal selector
consulting_login.html         → Admin login (reuse SAT CRM pattern exactly)
consulting_dashboard.html     → Main dashboard
consulting_student.html       → Individual student profile page
consulting_intake.html        → Add new consulting student form
config.js                     → CONFIG object (Supabase + Gemini keys)
config.example.js             → Template (no real keys)
netlify.toml                  → Build command injects env vars
styles.css                    → Shared styles
```

---

## Page Specs

### `consulting_login.html`
- Clone `daniellab_admin_login.html` exactly
- Change title to "DanielLab · Consulting CRM"
- On success → redirect to `consulting_dashboard.html`
- Same `admins` table check

---

### `consulting_dashboard.html`

**Layout**: Sidebar nav + main content area

**Sidebar**:
- Logo: "The**Daniel**Lab · 고등부"
- Nav links: Dashboard, Students, Action Items, Notes
- Logged-in admin name + logout

**Dashboard (home view)**:

Three summary cards at top:
- Total active students (count)
- Urgent action items (count of priority='urgent' AND completed=false)
- Upcoming deadlines (count of activities with deadline within 14 days)

**Student roster table** below cards:
Columns: 이름 | School | Grade | Narrative/Spike | Status | Upcoming deadline | Actions

- Status badge: green=active, orange=hold, gray=inactive
- Click row → navigate to `consulting_student.html?id={student_id}`
- Filter bar: by status, by grade_year
- Sort by name or upcoming deadline

**Action Items panel** (right side or tab):
- List of all incomplete action items across all students
- Grouped by: 🔴 Urgent → 🟡 High → ⚪ Normal
- Each item: student name, task title, owner, due date, checkbox to complete
- Completing an item updates `completed=true`, `completed_at=now()`, `completed_by=sessionStorage.dl_admin_name`

---

### `consulting_student.html`

Full student profile. URL param: `?id={uuid}`

**Header section**:
- Name (Ko + En), school, grade year, status badge
- If `school_next` exists: show "→ {school_next} ({school_next_date})"
- Edit button (inline edit mode)

**Tabs**:

#### Tab 1 — Profile
- Narrative (full text)
- Spike / Focus
- Target major + schools
- Parent contact info
- SAT CRM link (if `sat_student_id` exists, show link to SAT CRM student page)
- Assigned consultant

#### Tab 2 — Activities
- Table of all `consulting_activities` for this student
- Columns: Activity | Category | Timing | Deadline | Status | Result | Assigned To | Actions
- Status badge color coding:
  - planned → gray
  - in_progress → blue
  - submitted → yellow
  - completed/accepted → green
  - rejected → red
  - waitlisted → orange
- Add activity button → inline form or modal
- Edit / delete per row
- Sort by deadline (ascending)

#### Tab 3 — Notes
- Chronological list of all `consulting_notes`
- Note type badge (meeting / strategy / parent_comms / internal / ai_summary)
- Add note button → textarea + type selector + author (pre-filled from session)
- Delete note

#### Tab 4 — Action Items
- List of this student's action items
- Add item button
- Complete checkbox per item
- Priority color coding

#### Tab 5 — AI Assistant (Gemini)
Three buttons:

**① Summarize Student Profile**
```
Prompt: "You are an expert college admissions consultant. Based on the following student data, write a concise 2-3 paragraph summary of this student's profile, strengths, narrative, and current status. Be specific and actionable. Student data: {JSON of student + activities + recent notes}"
```

**② Suggest Next EC Activities**
```
Prompt: "You are an expert college admissions consultant specializing in boarding school students. Based on this student's profile, narrative, spike, current activities, and grade year, suggest 3-5 specific extracurricular activities, competitions, or programs they should pursue next. For each suggestion, explain why it fits their profile. Student data: {JSON}"
```

**③ Draft Parent KakaoTalk Update**
```
Prompt: "You are writing on behalf of DanielLab 고등부, a college consulting firm in Korea. Write a warm, professional KakaoTalk message in Korean to the parents of {student_name}. The message should update them on their child's recent progress and upcoming plans. Keep it concise (3-4 short paragraphs). Base it on: {recent notes + upcoming deadlines + recent activity results}"
```

All Gemini calls:
- Model: `gemini-2.0-flash`
- Endpoint: `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={CONFIG.GEMINI_KEY}`
- Show loading spinner while generating
- Display result in a read-only textarea the user can copy
- Add "Save as Note" button → saves as `note_type='ai_summary'`

---

### `consulting_intake.html`

Form to add a new consulting student.

Fields:
- 이름 (Korean) — required
- 이름 (English)
- Grade Year — dropdown: Rising Freshman / Sophomore / Junior / Senior
- Current School — required
- School Next (optional)
- School Next Date (optional)
- Narrative
- Spike / Focus
- Target Major
- Target Schools
- Status — dropdown (default: active)
- Parent Name
- Parent KakaoTalk ID
- Parent Contact (phone)
- Preferred Contact Method — dropdown
- Assigned Consultant — dropdown populated from `teachers` table
- SAT CRM Link — optional UUID input
- Internal Notes

On submit → INSERT into `consulting_students` → redirect to student profile page

---

## config.js Structure

```javascript
const CONFIG = {
  SUPABASE_URL: 'https://xhblmqhyumsnmaxfxxgg.supabase.co',
  SUPABASE_KEY: '',   // Supabase anon key
  ADMIN_PIN:    '',   // Not used in consulting CRM but keep for compatibility
  GEMINI_KEY:   '',   // Google Gemini API key
};
```

## netlify.toml

```toml
[build]
  publish = "."
  command = "echo \"const CONFIG = { SUPABASE_URL: '$SUPABASE_URL', SUPABASE_KEY: '$SUPABASE_KEY', ADMIN_PIN: '$ADMIN_PIN', GEMINI_KEY: '$GEMINI_KEY' };\" > config.js"
```

---

## Auth Pattern (copy exactly from SAT CRM)

```javascript
// Init Supabase
const { createClient } = window.supabase;
const client = createClient(CONFIG.SUPABASE_URL, CONFIG.SUPABASE_KEY);

// Login
const { data, error } = await client.auth.signInWithPassword({ email, password });

// Check admin table
const res = await fetch(
  `${CONFIG.SUPABASE_URL}/rest/v1/admins?id=eq.${data.user.id}&select=name,role`,
  { headers: { 'apikey': CONFIG.SUPABASE_KEY, 'Authorization': `Bearer ${data.session.access_token}` } }
);
const admins = await res.json();

// Store session
sessionStorage.setItem('dl_admin_name', admins[0].name);
sessionStorage.setItem('dl_admin_role', admins[0].role);
```

## Auth Guard (add to every page except login)

```javascript
// At top of every page script
function requireAuth() {
  const name = sessionStorage.getItem('dl_admin_name');
  if (!name) window.location.href = 'consulting_login.html';
}
requireAuth();
```

---

## Supabase Query Pattern

Use REST API directly (same pattern as SAT CRM — no Supabase JS client for queries):

```javascript
async function fetchStudents() {
  const { data: session } = await client.auth.getSession();
  const token = session.session.access_token;

  const res = await fetch(
    `${CONFIG.SUPABASE_URL}/rest/v1/consulting_students?status=eq.active&order=name_ko.asc`,
    {
      headers: {
        'apikey': CONFIG.SUPABASE_KEY,
        'Authorization': `Bearer ${token}`,
      }
    }
  );
  return await res.json();
}
```

---

## UI Component Patterns (match SAT CRM exactly)

### Status Badge
```html
<span class="badge badge-active">Active</span>
<span class="badge badge-hold">Hold</span>
```
```css
.badge { padding: 3px 10px; border-radius: 20px; font-size: 0.72rem; font-weight: 600; }
.badge-active  { background: #e8f5ee; color: #2a7a4f; }
.badge-hold    { background: #fff4e5; color: #cc6600; }
.badge-inactive{ background: #f0f0f0; color: #888; }
```

### Priority Badge
```css
.priority-urgent { color: #c8102e; font-weight: 700; }
.priority-high   { color: #cc6600; }
.priority-normal { color: #888; }
```

### Card
```css
.card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 24px;
}
```

### Button
```css
.btn-primary {
  background: var(--accent);
  color: #fff;
  border: none;
  border-radius: 8px;
  padding: 10px 18px;
  font-family: var(--sans);
  font-size: 0.9rem;
  font-weight: 600;
  cursor: pointer;
}
.btn-primary:hover { background: var(--accent-dim); }
.btn-ghost {
  background: transparent;
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 9px 18px;
  font-family: var(--sans);
  font-size: 0.9rem;
  cursor: pointer;
}
```

---

## Footer (copy exactly)

```html
<footer style="text-align:center;padding:32px 24px 16px;font-size:0.72rem;color:#aaa;letter-spacing:0.04em;">
  Developed by Kevin Choi &nbsp;·&nbsp; Powered by SENECA AI
</footer>
```

---

## Notes for Codex

- Keep everything in vanilla JS — no React, no Vue, no bundler
- One HTML file per page — inline `<style>` and `<script>` tags are fine
- All Supabase queries use the REST API fetch pattern, NOT the Supabase JS client methods (for consistency with existing codebase)
- Korean text is fine in UI — this app is used by Korean-speaking staff
- Mobile responsiveness is nice-to-have, not required — primary use is desktop
- No unit tests needed
- Gemini API calls happen client-side (key is in config.js which is gitignored)
- Start with `consulting_login.html` + `consulting_dashboard.html` + `consulting_student.html` — these are the three most important pages

---

## Consultants Table (Added)

A separate `consultants` table replaces the `teachers` FK on `consulting_students`. Do NOT use `public.teachers` for consultant assignment — that table is SAT-specific.

### `consultants`
| Column | Type | Notes |
|---|---|---|
| id | uuid PK | |
| name | text | Display name |
| name_ko | text | Korean name |
| role | text | principal / senior_consultant / junior_consultant / media_manager |
| email | text | |
| phone | text | |
| kakao_id | text | |
| active | boolean | |
| auth_user_id | uuid FK → auth.users | Links to Supabase login if applicable |

**Seeded with:** Daniel (principal), Kevin / 최성원 (senior_consultant), 류시은 (junior_consultant)

### Usage in UI
- `consulting_intake.html`: Assigned Consultant dropdown → populate from `consultants` table WHERE `active=true`
- `consulting_student.html`: Show consultant name + role in profile header
- `consulting_dashboard.html`: Optional filter by assigned consultant

---

## Licensing Architecture Note

This codebase is owned by the developer (Kevin Choi) and licensed to clients. Design accordingly:

- **No hardcoded client names** — use `CONFIG.BRAND_NAME` and `CONFIG.BRAND_SUBTITLE` for all branding
- **`config.js` drives everything** — URL, keys, brand name, admin PIN
- **Repo stays portable** — any consulting firm should be able to deploy with their own Supabase project and config
- **Footer**: "Developed by Kevin Choi · Powered by SENECA AI" — keep this on all pages, it's the developer signature

### Add to `config.js`:
```javascript
const CONFIG = {
  SUPABASE_URL:     '',
  SUPABASE_KEY:     '',
  GEMINI_KEY:       '',
  ADMIN_PIN:        '',
  BRAND_NAME:       'DanielLab',        // Client-configurable
  BRAND_SUBTITLE:   '고등부',           // Client-configurable
  BRAND_LOCATION:   'Seoul · Boston',   // Client-configurable
};
```

### Replace all hardcoded "DanielLab" references in HTML with:
```javascript
document.title = CONFIG.BRAND_NAME + ' · Consulting CRM';
document.querySelector('.logo-name').textContent = CONFIG.BRAND_NAME;
```