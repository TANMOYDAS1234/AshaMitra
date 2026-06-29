# AshaMitra — App Workflow & UI/UX Guide

> Purpose: a single map of **how the app flows**, screen by screen, so UI/UX can be
> improved deliberately. Bengali-first app for **West Bengal ASHA workers**.
> Stack: Flutter + GetX (client) · Node/Express + MongoDB Atlas (VPS backend).
> Last updated: 2026-06-29.

---

## 1. Who uses it & the golden rule

**Primary user:** an ASHA worker — community health worker, mid/low digital
literacy, mostly on a budget Android phone, often **offline** in the field,
reads **Bengali**, works fast between home visits.

**Design golden rule:** *the worker should be able to do her whole day by
glancing at the phone and tapping — never by typing what the app already knows.*
Every screen is judged against: **fewer taps, less typing, Bengali-clear,
works offline, forgiving of mistakes.**

Field finding (validated): the #1 unmet need is **register/report
auto-generation** — stop the "double-double" hand-copying. Auto-seed and
pre-fill wherever data already exists.

---

## 2. Navigation architecture

### Bottom navigation (5 tabs)
| Tab | Route | Screen | Purpose |
|-----|-------|--------|---------|
| হোম (Home) | `/home` | `HomeScreen` | Day's worklist + entry points |
| রোগী (Patients) | `/patients` | `PatientListScreen` | All registered patients |
| 🎤 (center, raised) | `/assistant` | `AssistantScreen` | Voice-first AI assistant |
| রিপোর্ট (Reports) | `/reports` | `ReportsScreen` | Saved triage reports |
| প্রোফাইল (Profile) | `/profile` | `ProfileScreen` | Worker profile/settings |

Routes are GetX `GetPage`s in [`lib/app/routes.dart`](../lib/app/routes.dart).
Transition vocabulary: `fadeIn` (180ms, peer tabs), `rightToLeftWithFade`
(260ms, forward steps), `downToUp` (320ms, emergency/modals), `zoom` (280ms,
triage/voice entry).

### Home screen layout (top → bottom)
1. **Greeting header** — "হ্যালো, \<name\>" + notification bell.
2. **বকেয়া টিকা ও ANC** hero banner → `/schedule/due` (due/overdue worklist).
   Count = **unique patients** with a due/overdue item (within 14 days).
3. **রেজিস্টার ও নথি** — compact 2×2 tile group:
   - রেজিস্টার তৈরি → `/registers`
   - রেফারেল ও ট্র্যাকিং → `/referrals` (open-count badge)
   - যোগ্য দম্পতি (পরিবার পরিকল্পনা) → `/eligible-couples`
   - জন্ম ও মৃত্যু নথি → `/vital-events`
4. **আজকের স্বাস্থ্য কার্যক্রম** — clinical case-card grid (the triage cases):
   গর্ভবতী / প্রসব-পরবর্তী / নবজাতক / শিশু / টিকা / শিশু বিকাশ / জরুরি, etc.

Source: [`lib/features/home/presentation/screens/home_screen.dart`](../lib/features/home/presentation/screens/home_screen.dart)

---

## 3. Feature map (where each thing lives)

| Feature | Folder | Key screens |
|---------|--------|-------------|
| Onboarding/Auth | `features/onboarding`, `features/auth` | splash, welcome, language, login, OTP |
| Home | `features/home` | HomeScreen, PatientContextSheet |
| Patients | `features/patients` | list, add/edit, **profile** |
| Triage | `features/triage` | select case, confirm, voice, dynamic Q&A, result |
| Schedule/Checkups | `features/schedule` | **due list**, **visit (MCP-card form)** |
| Registers | `features/registers` | register generator (PDF/CSV) |
| Referrals | `features/referrals` | list, form (Form 3), detail (outcome) |
| Eligible couples | `features/eligible_couples` | list (+auto-seed), form |
| Vital events | `features/vital_events` | list (+auto-seed), form |
| Reports | `features/reports` | saved triage reports |
| Assistant | `features/assistant` | voice/chat AI |
| Emergency | `features/emergency` | emergency + nearby facilities |
| Admin | `features/admin` | ASHA management (supervisor) |

---

## 4. Core workflows (step by step)

### A. Register a patient
`Home → case card → PatientContextSheet → "নতুন রোগী যোগ করুন"` (or Patients tab → +)
→ `AddPatientScreen` (case pre-selected). Captures the full MCP-card superset
(identity, Aadhaar, RCH/MCTS, blood group, LMP/EDD or DOB, parity G-P-L-A,
high-risk, photo). On save → optionally **"Save & Start Checkup."**
- **Schedule auto-generates** from LMP (ANC/PNC), DOB (vaccine/HBNC/HBYC), or
  delivery date — no manual scheduling.

### B. Do a checkup (the core daily loop)
Two entry points:
- **Due-driven:** `Home → বকেয়া banner → DueListScreen` → tap a due patient.
- **Patient-driven:** `Home → case card → PatientContextSheet → "চলমান রোগী
  নির্বাচন করুন"` → picker (shows each patient's **due status** + a
  **🔔 মনে করান** remind pill) → tap a patient.

Either way → `CheckupLauncher.start()` opens **`VisitScreen`** = the structured
MCP-card visit form for the **next pending** event of that patient.
- Per-module bodies: ANC (BP/Hb/weight/GA/urine/USG/HIV/syphilis/danger
  flags), PNC, HBNC (mother + newborn), HBYC (weight + MUAC SAM/MAM), vaccine.
- Helpers: **mic dictation** on key fields, **validators** on every field,
  **trend flags** (Hb↓ / no weight gain / high BP), **"গত বার"** reference card
  (shows scheduled date + actual recorded date), per-module illustration.
- Completion writes a `record` to the schedule event → flows into the timeline,
  registers, and PDFs. **There is no one-tap "done"** — every completion goes
  through the form so data is captured.

### C. Reminders (avoid missed visits)
From the **DueListScreen** or the **checkup picker**, tap **মনে করান** →
Call / WhatsApp / SMS with a prefilled Bengali message → logged to backend
(`lastRemindedAt`, channel). Shared flow:
[`features/schedule/services/reminder_service.dart`](../lib/features/schedule/services/reminder_service.dart).
Backend also runs an **automatic** reminder cron (T-3 / T-1 / overdue,
SMS+WhatsApp, env-gated).

### D. Referral (Form 3 + outcome)
`Patient profile → রেফারেল → নতুন রেফারেল` (prefilled) OR Home tile.
Create slip → print **Form 3 PDF** → mark **reached** → **record outcome**
(admitted / treated / referred up / death). Status: pending → reached →
completed. Open referrals badged on Home + listed on the patient profile.

### E. Registers (kill double-writing)
`Home → রেজিস্টার তৈরি → RegistersScreen`. Two modes:
- **মাসিক বকেয়া** (monthly due-list work plan): ANC / টিকা / HBNC / HBYC.
- **পূর্ণ রেজিস্টার** (notebook substitute): Maternal, Immunization,
  **Eligible-couple**, **Birth-death**, ASHA Diary.
Output: **PDF (A4 landscape)** or **CSV (UTF-8 BOM, Excel-Bengali)**, with the
ASHA/block/district/facility header. Offline-capable (caches last payload).

### F. Family planning (eligible couples)
`Home → যোগ্য দম্পতি`. **Auto-seeds** suggestions from the registry (women
15–49 with a couple signal: pregnancy / spouse name / ≥1 child — never a
Child-type record). Worker confirms → adds FP method + next follow-up + Aadhaar.

### G. Birth & death (CRS)
`Home → জন্ম ও মৃত্যু নথি`. **Auto-seeds** birth suggestions (every Newborn
registration + pregnancy with a delivery date). Worker adds the CRS reg number.
Deaths are entered manually (cause, maternal/infant flags).

### H. Patient profile (the hub)
`Patients tab → tap patient` → `PatientProfileScreen`:
- চেকআপ শুরু করুন (start checkup), মা ও শিশুর রিপোর্ট (full PDF),
  গর্ভ-ইতিহাস (all pregnancies).
- **চেকআপ টাইমলাইন** (done + upcoming; each done row has a ⤓ per-checkup PDF).
- **রেফারেল** section.
- Last assessment (triage danger flags).

---

## 5. Data & sync architecture (constraints UX must respect)

- **Offline-first.** Every write lands locally first, then syncs. A row carries
  `syncState` (pendingCreate/pendingUpdate/synced), a `clientId` idempotency
  key, and a `version` for optimistic concurrency. UX must **never block on the
  network** — show "saved on phone, will sync" rather than spinners that hang.
- **Generic store:** eligible-couple + vital-event reuse
  [`core/services/synced_store.dart`](../lib/core/services/synced_store.dart);
  referrals/patients have their own controllers with the same contract.
- **Schedule engine (backend):** ANC/PNC/vaccine/HBNC/HBYC/PNC events generated
  from LMP/DOB/deliveryDate. Dates are guideline-driven; completed visits store
  the real `doneDate`/`completedAt`.
- **Date display rule (decided):** completed visits show the **scheduled date**
  as headline **+ the actual recorded date** ("সম্পন্ন DD/MM"); upcoming show
  the due date. Keep this consistent across timeline, PDF, and "গত বার".

---

## 6. UX observations & known rough edges (from field/testing)

1. **Test data has minors** (e.g., 16-yo pregnancy, 15-yo child) — surface
   **age-based clinical flags** (child pregnancy = high-risk) rather than
   hiding them.
2. **Counts must match their labels** — "X জন রোগীর" must count *patients*, not
   events. Audit every count/badge for this.
3. **Two checkup entry points** (due list vs case-card picker) can confuse —
   the picker now shows due status, but consider unifying the mental model.
4. **Bengali numerals vs Latin** are mixed in places (45 vs ৪৫). Pick one and
   apply app-wide.
5. **Large APK (~199 MB)** — the Gemini-generated illustrations are heavy;
   consider compressing/Lottie/SVG to speed installs on field phones.
6. **Long Bengali labels truncate** in tiles/headers (e.g. "যোগ্য দম্পতি
   (পরিবার পরিকল্পনা)") — needs 2-line handling everywhere.

---

## 7. Prioritized UI/UX improvement backlog

### P0 — clarity & trust (do first)
- [ ] **Consistent number system** (Bengali ৪৫ everywhere, or Latin everywhere).
- [ ] **Empty/loading/error states** audit — every list & form needs a friendly
      Bengali empty state, a skeleton/spinner, and an offline note.
- [ ] **Sync status chip** visible per record (📶 phone-only / ✓ Atlas) so the
      worker trusts what's saved.
- [ ] **Danger/high-risk visual language** unified (red band + icon) across
      triage, profile, registers, ANC.
- [ ] **Tap targets ≥ 48dp**, generous spacing — field use, often one-handed.

### P1 — speed (fewer taps/typing)
- [ ] **Voice input on every text field** (extend the mic pattern app-wide).
- [ ] **Smart defaults & carry-forward** (HIV/syphilis once per pregnancy; last
      village; auto-units).
- [ ] **One-screen checkup** where possible — reduce scrolling; sticky save bar.
- [ ] **Search + filters** on the patient list (village, case, due-status, risk).
- [ ] **Quick actions** on each patient row (checkup / remind / call).

### P2 — delight & comprehension
- [ ] **Iconography + illustrations** per module (already started) — keep light.
- [ ] **Progress/▮ trimester & growth charts** (visual, not just numbers).
- [ ] **Today summary card** ("৩ ANC, ২ টিকা, ১ রেফারেল আজ") on Home.
- [ ] **Onboarding coachmarks** for first-time workers.
- [ ] **Dark/large-text mode** for outdoor readability & older eyes.

### P3 — workflow completeness
- [ ] Wire FP `followUpDate` into the **reminder engine**.
- [ ] **Death auto-suggest** when a patient is marked deceased.
- [ ] **Stock/supplies register** (if scope expands).
- [ ] **Supervisor dashboard** polish (admin).

---

## 8. Design system (use these tokens)

- Colors: [`core/theme/app_colors.dart`](../lib/core/theme/app_colors.dart)
  — `primary` indigo `#4F46E5`, `accent` amber `#D97706`, `safeGreen`,
  `warningYellow`, `emergencyRed`, `purple`, `sky`; text `onBackground`
  (`#1E1B4B`) / `textSecondary` (`#6B7280`); `surface` white, `background`
  `#F7F8FF`, `cardBorder` `#E0E7FF`.
- Type: [`core/theme/app_text_styles.dart`](../lib/core/theme/app_text_styles.dart)
  (HindSiliguri Bengali font) — `h2/h3`, `label/labelLg`, `body/bodySm`,
  `caption`.
- Radius/shadow/gradient: `core/theme/app_radius.dart`, `app_shadows.dart`,
  `app_gradients.dart`.
- Shared widgets: `shared/widgets/` — `AppButton`, `AppInput`, `AppHeader`,
  `PatientPhoto`, `RiskBadge`, `ModuleArt` (vector module illustrations).

**Rule for new UI:** compose from these tokens/widgets — don't hand-roll
colors, paddings, or buttons. Match the surrounding screen's density & idiom.

---

## 9. Backend reference (for data-driven UI)

Base: `https://ashamitra-backend.flintdeorient.in` · health: `/health`
(check the `build` marker after deploys).

| Domain | Endpoints |
|--------|-----------|
| Patients | `/api/patients` (CRUD, clientId dedup, version) |
| Schedule | `/api/schedule`, `/api/schedule/due?days=`, `/api/schedule/all`, `logReminder` |
| Referrals | `/api/referrals` (CRUD + outcome) |
| Eligible couples | `/api/eligible-couples` (CRUD) |
| Vital events | `/api/vital-events` (CRUD) |
| Reports | `/api/reports` |
| AI / STT | Gemini chat, Groq Whisper proxy, OCR |

Deploy (VPS): `cd /var/www/ASHAmitra-backend && git pull origin main && pm2
restart ashamitra-api && curl -s .../health`.

---

## 10. How to use this doc for UI/UX work

1. Pick a workflow from §4 and walk it on a device.
2. Score each screen against the golden rule (§1) and the rough edges (§6).
3. Pull an item from the backlog (§7); implement with §8 tokens.
4. Keep the offline-first constraints (§5) intact.
5. Update this file when a flow changes.
