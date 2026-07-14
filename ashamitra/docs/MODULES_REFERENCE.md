# ASHAMitra — Modules, Backend Logic & Rules Reference

> Generated reference for the clinical decision engine, the on-device pipeline, and the backend API.
> Engine: `asha_cdss_engine_v2` **v2.6.0-guideline-aligned** (aligned to WB NHM Safe Motherhood Book 2024 + Mother & Child Protection Card 2018).
> Source of truth: [`assets/data/asha_engine.json`](../assets/data/asha_engine.json), [`lib/core/services/`](../lib/core/services/), [`backend/server.js`](../backend/server.js).

> **Detailed companion docs:** [MODULES.md](MODULES.md) — every module's full rules · [PIPELINE.md](PIPELINE.md) — the 11 decision steps · [SIGNOFF_RULES.md](SIGNOFF_RULES.md) — the 64 sign-off-pending rules. *(This file is the high-level overview + backend summary.)*

---

## 1. System Overview

ASHAMitra turns an ASHA worker's spoken/typed answers + measured vitals into a **triage band** — `GREEN` / `YELLOW` / `RED` — plus a referral, action card, and follow-up. Two cooperating parts:

- **On-device decision engine** (Dart, fully offline): a deterministic 11-layer pipeline driven by `asha_engine.json`.
- **Backend** (Node/Express + MongoDB): auth, patient records, MCH schedule + reminders, triage reports, AI chat/voice (Gemini→Groq), TTS/STT, OCR, admin.

### Bands

| Band | Meaning | Referral | Ambulance |
|------|---------|----------|-----------|
| 🟢 GREEN | Home care, routine follow-up | None | — |
| 🟡 YELLOW | Refer to PHC within 24 h | PHC within 24 h | optional |
| 🔴 RED | Refer FRU/SNCU/DH immediately | FRU / SNCU / DH | **108** |

### Core invariants
- **Evaluation order:** `hard_stop → combination_rules → numeric_rules → risk_score`.
- **RED is locked** — once any RED-tier rule fires, no later layer can downgrade it. The pipeline can only **escalate**, never de-escalate.
- **`fallback_band: GREEN`** — when no rule fires (no danger signs), the result is GREEN.
- **Conservative on missing data** — a missing RED-tier vital pushes GREEN→YELLOW and YELLOW→RED.
- **Deterministic + auditable** — every layer records a trace; a SHA-256 protocol hash guards the rule file.

### Engine totals (v2.6.0)
7 modules · 68 questions · 42 hard-stop rules · 19 combination rules · 24 yellow rules · 42 numeric rules · **64 rules flagged `clinical_sign_off_pending`** (see §6). *(Full question text in [§7 appendix](#7-appendix--all-questions-every-module).)*

---

## 2. Clinical Modules

Each module has: `questions`, `hard_stop_rules` (any one → RED), `combination_rules` (AND of answers → RED/YELLOW), `numeric_rules` (vital thresholds), `yellow_rules` (single sign → YELLOW), and a `risk_engine` (weighted score → band). All modules use score thresholds **GREEN 0–2 · YELLOW 3–5 · RED 6+** unless noted.

### 2.1 Newborn (0–28 days) — `newborn`
PSBI-focused. 14 questions; **every danger sign is a hard-stop RED**.

**Questions:** n1 can't breastfeed · n2 fever · n3 fast/difficult breathing · n4 umbilical infection · n5 lethargy · n6 yellow/blue skin · n7 convulsions · n8 hypothermia (cold to touch) · n9 skin pustules/ear pus · n10 bulging fontanelle · n11 no stool 24 h / no urine 48 h · n12 diarrhoea · n13 eye infection · n14 congenital defect.

**Hard-stop → RED:** NB-001…NB-008, NB-010…NB-014 (each single sign). **Yellow:** NB-Y-001 (n14 congenital defect → PHC/DH).

**Combination → RED:** fever+breathing (NB-COMB-001), jaundice+poor-feeding=kernicterus (NB-COMB-002), lethargy+breathing=sepsis (NB-COMB-003), umbilical+fever (NB-COMB-004), not-feeding+fever=PSBI (NB-COMB-005).

**Numeric rules:**
| Rule | Vital | Threshold | Band |
|---|---|---|---|
| NB-VITAL-001 | SpO₂ | < 90 | RED |
| NB-VITAL-002 | resp rate | ≥ 60 | RED |
| NB-VITAL-003 | temp °C | ≥ 37.5 | RED |
| NB-VITAL-004 | weight kg | < 1.5 | RED (VLBW) |
| NB-VITAL-005 | temp °C | < 35.5 | RED (hypothermia) |
| NB-VITAL-006 | heart rate | > 180 | RED |
| NB-VITAL-007 | weight kg | 1.8–2.5 | YELLOW (LBW) |
| NB-VITAL-008 | weight kg | < 1.8 | RED (HBNC) |
| NB-VITAL-009 | temp °C | 35.5–36.4 | YELLOW (cold stress) |

**Score weights:** n1 3, n2 2, n3 3, n4 2, n5 3, n6 2, n7 3, n8 3, n9 2, n10 3.

### 2.2 Child (2 months–5 years) — `child`
IMNCI-aligned. 13 questions.

**Questions:** c1 fever >5 d · c2 cough/breathing · c3 diarrhoea/vomiting · c4 refusing to eat · c5 dehydration signs · c6 low weight · c7 convulsions · c8 lethargy/unconscious · c9 vomits everything · c10 stiff neck/severe headache w/ fever · c11 blood in stool · c12 pallor · c13 chest indrawing/stridor.

**Hard-stop → RED:** CH-001 (fever>5d), CH-004 (refuses feed), CH-005 (severe dehydration), CH-007 (convulsions), CH-008 (lethargy/unconscious), CH-009 (vomits everything), CH-010 (meningitis signs), CH-013 (chest indrawing/stridor).
**Combination → RED:** breathing+dehydration (001), fever>5d+cough (002), diarrhoea+refusal (003), diarrhoea+dehydration=Plan C (004).
**Yellow:** CH-002 cough, CH-003 diarrhoea, CH-006 low weight, CH-011 dysentery, CH-012 pallor.

**Numeric rules:**
| Rule | Vital | Threshold | Band |
|---|---|---|---|
| CH-VITAL-001 | SpO₂ | < 90 | RED |
| CH-VITAL-002 | MUAC cm | < 11.5 (SAM) | RED |
| CH-VITAL-003 | MUAC cm | 11.5–12.5 (MAM) | YELLOW |
| CH-VITAL-004 | resp rate | ≥ 50 (2 mo–1 y) | RED |
| CH-VITAL-005a | temp °C | ≥ 40 | RED |
| CH-VITAL-005b | temp °C | 39–40 | YELLOW |
| CH-VITAL-006 | WFA z-score | < −3 | RED |
| CH-VITAL-006b | WFA z-score | −3 to −2 | YELLOW |
| CH-VITAL-007 | resp rate | ≥ 40 (1–5 y) | YELLOW |
| CH-VITAL-008 | SpO₂ | 90–94 | YELLOW |

**Score weights:** c1 3, c2 2, c3 2, c4 3, c5 3, c6 2, c7 3, c8 3, c9 3, c10 3, c11 2, c12 2, c13 4.

### 2.3 Pregnancy / ANC — `pregnancy` (female only)
14 questions.

**Questions:** p1 high BP · p2 swelling · p3 bleeding/abdominal pain · p4 reduced fetal movement · p5 missed ANC 3+ mo · p6 blurred vision · p7 convulsion · p8 severe anaemia signs · p9 fever · p9r fever w/ rigors · p10 PROM/leaking · p11 headache · p11d severe/persistent headache · p12 dizziness.

**Hard-stop → RED:** ANC-001 (high BP), ANC-003 (APH bleeding), ANC-004 (reduced fetal movement), ANC-006 (blurred vision), ANC-007 (convulsion/eclampsia), ANC-008 (severe anaemia), ANC-009R (fever w/ rigors), ANC-010 (PROM).
**Combination → RED:** BP+oedema (001), blurred+oedema (002), bleeding+reduced-movement (003), BP+blurred (004), headache+severe-headache (005), headache+oedema (006).
**Yellow:** ANC-002 oedema, ANC-005 missed ANC, ANC-009 fever, ANC-011 headache, ANC-012 dizziness.

**Numeric rules:** systolic ≥140 RED (001), diastolic ≥90 RED (002), Hb <7 RED (003) / 7–10 YELLOW (004), systolic ≥160 RED (005), urine protein ≥2+ RED (006), fundal-height >4 wk diff YELLOW (007), gest. age <37 wk + labour RED (008), labour >12 h RED (009), leaking >12 h RED (010), TSH >10 RED (011) / 2.5–10 YELLOW (012), OGTT 2-h ≥140 YELLOW GDM (013), FHR <120 RED (014) / >160 RED (015).

**Score weights:** p1 4, p2 2, p3 4, p4 3, p5 1, p6 3, p7 4, p8 3, p9 3, p9r 4, p10 3, p11 2, p11d 2, p12 1.

### 2.4 Postpartum (0–42 days) — `delivery_pnc` (female only)
11 questions.

**Questions:** pp1 excessive bleeding/foul discharge · pp2 fever/chills · pp3 breast pain/swelling · pp4 abdominal pain/suture problem · pp5 burning urination · pp6 weakness/dizziness · pp6s fainting/collapse · pp7 convulsion · pp8 difficulty breathing · pp9 postpartum depression signs · pp10 incontinence.

**Hard-stop → RED:** PNC-001 (PPH/sepsis), PNC-006S (collapse/concealed bleed), PNC-007 (eclampsia), PNC-008 (breathing difficulty), PNC-009 (incontinence/fistula).
**Combination → RED:** bleeding+fever=sepsis (001), abdominal-pain+fever=peritonitis (002), bleeding+weakness=shock (003), breast-pain+fever=abscess (004).
**Yellow:** PNC-002 fever, PNC-003 mastitis, PNC-004 wound, PNC-005 UTI, PNC-006 anaemia, PNC-009 (pp9) depression screen.

**Numeric rules:** temp ≥38 RED (001), Hb <7 RED (002) / 7–10 YELLOW (003), systolic ≥140 RED (004), HR >110 YELLOW (005), ≥2 pads/30 min RED (006), >5 pads/day RED (007), temp ≥38.9 RED (008).

**Score weights:** pp1 4, pp2 2, pp3 1, pp4 2, pp5 1, pp6 2, pp7 4, pp8 3, pp9 1, pp6s 4.

### 2.5 Immunisation — `immunisation` (UIP schedule)
No hard-stops; all findings are YELLOW (catch-up). Questions im1 age · im2 missed vaccine · im3 days overdue · im4 currently ill · im5 booster missed · im6 prior AEFI.
**Yellow:** IMM-001 missed primary, IMM-002 specific vaccine gap, IMM-003 booster, IMM-004 ill (defer), IMM-005 >3 mo overdue, IMM-006 prior AEFI (MO before next dose). **Score:** im4/im5/im6 = 1 each; thresholds GREEN 0 / YELLOW 1+. Full UIP schedule (birth → 16 y) embedded in the module.

### 2.6 Child Development Screening (2 mo–3 y) — `development`
MCP-card milestones. d1 age band · d2 any danger sign present. **Yellow:** DEV-001 (d2 → DEIC/health-centre developmental assessment). Score d2 = 3; thresholds GREEN 0 / YELLOW 1+. Milestone danger-sign lists per age band (2–3 mo … 3 y) embedded.

### 2.7 Emergency — `emergency` (global hard-stop sweep)
Cross-cutting; **any sign → RED, ≤30 min to FRU/DH**. e1 bleeding · e2 convulsion/unconscious · e3 severe breathing difficulty · e4 unresponsive · e5 snakebite/animal bite · e6 poison/overdose · e7 shock · e8 major trauma/burn. Rules EM-001…EM-009. Score 4 each; thresholds GREEN 0 / RED 1+. **Also re-run against every other module's answers as a safety cross-sweep (pipeline Layer 9).**

---

## 3. On-Device Decision Pipeline (11 layers)
Orchestrated by [`rule_executor.dart`](../lib/core/services/rule_executor.dart). Runs in order; a blocking error in layers 1–5 halts with `band: UNKNOWN` (`pipelineBlocked`).

| # | Layer | Job |
|---|-------|-----|
| 1 | **Input Validator** | Validates moduleId/answers/vitals types. Blocks on empty module, bad types, negative vitals. |
| 2 | **Contradiction Checker** | Flags impossible answers (warn) and impossible vitals (block): SpO₂>100, temp>45, RR>120, sys>300, dia≥sys. |
| 3 | **Age/Module Validator** | Age bounds per module (newborn 0–28 d, child 61 d–5 y, immunisation 0–16 y); pregnancy/PNC require female. |
| 4 | **Required Vital Checker** | Lists missing RED-tier vitals per module (non-blocking) → feeds conservative escalation in L8. |
| 5 | **Protocol Hash Verify** | SHA-256 of `asha_engine.json`; mismatch within a session halts (tamper guard). |
| 6 | **Rule Engine** | The 4-stage evaluator (hard-stop → combination → numeric → yellow). Sets `redLock`, `provisionalBand`, triggered rules, risk score. Yellow stage skipped once RED-locked. *Graded answers:* "mild"/"unsure" force at least YELLOW. |
| 7 | **Severity Scoring** | Weighted score = answer weights + vital penalties (highest penalty per vital). Advisory band feeds L8; never downgrades RED. |
| 8 | **Adaptive Risk** | Escalates on demographics (newborn <7 d, LBW, infant <3 mo, pregnancy age <18/>35), history (prior RED, HRP flag, ≥2 missed ANC, RED <48 h ago), missing RED-tier vitals, and score band. Codes ADAPT_D/H/V/S_*. Never downgrades RED. |
| 9 | **Safety Escalation** | 5 final checks: sign-off-pending flag, **emergency cross-sweep**, RED-lock floor enforcement, referral sanity default, GREEN-with-danger-signs → YELLOW. |
| 10 | **Referral Decision** | Facility + urgency + max delay per band (RED 30 min, YELLOW 24 h), transport advisory (108), travel-time est. (30 km/h), follow-up (RED-refused 4 h, YELLOW 24 h). |
| 11 | **Explainable Output** | Assembles `DecisionOutput`: band, action card (bn/en), referral, suspected conditions, danger signs, severity, adjustments, safety flags, full trace + protocol hash. |

**Severity vital penalties (L7):** SpO₂ <90 +4 / <95 +2 · RR >60 +3 / >50 +2 · temp >40 +3 / >38.5 +2 / >37.5 +1 · sys ≥160 +4 / ≥140 +2 · dia ≥110 +3 / ≥90 +2 · Hb <7 +4 / <10 +2 · MUAC <11.5 +4 / <12.5 +2.

### Supporting services
- **`vitals_extractor.dart`** — parses BP, temp (auto °F→°C if >45), MUAC, SpO₂, weight, RR, Hb from free speech; Bengali-digit normalisation; immediate spoken danger alerts.
- **`offline_brain.dart`** — picks the next most-urgent question (hard-stop 100 > combination 60 > yellow 30 > base 10, +60 if it would complete a RED combo) and fires combination/single-sign alerts; finishes at 3+ confirmed danger signs.

---

## 4. Backend API (`backend/server.js`)
Express + Mongoose (MongoDB Atlas). `auth` = JWT bearer; `adminOnly` = admin role.

**Collections:** User · Patient · Report (soft-delete) · Notification · AiCache · ScheduleEvent · Referral.

| Module | Key routes |
|--------|-----------|
| **Health** | `GET /health` (build marker, provider order, key count) |
| **Auth & profile** | `POST /api/auth/send-otp`, `POST /api/auth/verify-otp` (30-day JWT), `PUT /api/auth/profile`, `PUT /api/users/:id` |
| **Patients** | `GET/POST /api/patients`, `GET/PUT/DELETE /api/patients/:id` — offline-first sync (idempotent by `clientId`/`rchId`, optimistic `version`, 409 on conflict); creates schedule on save |
| **Schedule / MCH** | `GET /api/schedule/due`, `GET /api/schedule`, `PATCH /api/schedule/:id`, `POST /api/schedule/:id/remind` — ANC (4 visits from LMP), vaccines (UIP from DOB), HBNC (newborn d3–42), HBYC (child 3–15 mo). Hourly reminder scan: T-3/T-1/overdue, SMS + WhatsApp, dedup, recipient = mother |
| **Reports** | `POST /api/reports` (RED → worker "call 108" + all admins; YELLOW → worker), `GET/DELETE /api/reports/:id`, `PATCH /api/reports/:id/restore`, `PATCH /api/reports/repoint`, `PATCH /api/reports/:id/attach-patient` |
| **Notifications** | `GET /api/notifications`, `PATCH /:id/read`, `PATCH /read-all`, `DELETE /:id` |
| **AI / triage** | `POST /api/chat`, `POST /api/chat-with-voice`, `POST /api/detect-case` → shared `callGemini` (Gemini **2.5-flash** primary key + rotation/benching 15 min, Groq llama-3.3-70b fallback, SHA-1 `AiCache`). Distinguishes `AI_QUOTA` vs `AI_FAIL` |
| **Voice** | `POST /api/tts` (Google Cloud bn-IN/hi-IN, tones, acronym→script rewriting, SSML pauses), `GET /api/voice-preview`, `POST /api/transcribe` (Groq Whisper, bn/hi auto-detect + Devanagari-Bengali fix) |
| **OCR** | `POST /api/ocr/aadhaar` — Secure-QR first, Tesseract fallback; returns masked Aadhaar; image discarded |
| **Directions** | `GET /api/directions` — Google route polyline for referral transport |
| **Admin** | workers CRUD + activate/deactivate, reports (filtered + deleted audit + restore + permanent), `GET /api/admin/stats`, `GET /api/admin/locations`, per-worker patients/reports/profile |

**Key env:** `MONGO_URI`, `JWT_SECRET`, `GEMINI_API_KEY(_2/_3)`, `GEMINI_MODEL`, `GROQ_API_KEY`, `GOOGLE_TTS_API_KEY`, `GOOGLE_DIRECTIONS_API_KEY`, `SMS_*`, `WHATSAPP_*`, `USE_REAL_OTP`.

---

## 5. Triage data flow (end to end)
1. ASHA speaks → STT (device or `/api/transcribe`) → `VitalsExtractor` pulls vitals.
2. `offline_brain` picks next question; conversation handled by `GeminiConversationService` (online) or rules (offline).
3. Answers + vitals → `RuleExecutor.execute()` → 11 layers → `DecisionOutput` (band + referral + action card).
4. Result saved via `POST /api/reports` → band-based notifications.
5. Patient registration (`POST /api/patients`) auto-generates the MCH schedule; the reminder engine nudges the mother before each due date.

---

## 6. Sign-off-pending rules (clinical validation needed)
**64 rules** carry `clinical_sign_off_pending: true` — they are live in the engine but flagged as **draft, awaiting clinician sign-off** (newer guideline additions or proxy thresholds). They still fire normally; the flag surfaces as a `SAFETY_A_001` advisory note in the output. Full list:

**Newborn (12):** NB-008, NB-010, NB-011, NB-COMB-002, NB-COMB-003, NB-COMB-004, NB-COMB-005, NB-VITAL-005, NB-VITAL-006, NB-VITAL-007, NB-VITAL-008, NB-VITAL-009.

**Child (16):** CH-004, CH-009, CH-010, CH-013, CH-COMB-002, CH-COMB-003, CH-COMB-004, CH-VITAL-004, CH-VITAL-005a, CH-VITAL-005b, CH-VITAL-006, CH-VITAL-006b, CH-VITAL-007, CH-VITAL-008, CH-011, CH-012.

**Pregnancy (21):** ANC-008, ANC-010, ANC-009R, ANC-COMB-003, ANC-COMB-004, ANC-COMB-005, ANC-COMB-006, ANC-VITAL-005, ANC-VITAL-006, ANC-VITAL-007, ANC-VITAL-008, ANC-VITAL-009, ANC-VITAL-010, ANC-VITAL-011, ANC-VITAL-012, ANC-VITAL-013, ANC-VITAL-014, ANC-VITAL-015, ANC-011, ANC-012, ANC-009.

**Postpartum (10):** PNC-001, PNC-006S, PNC-COMB-003, PNC-COMB-004, PNC-VITAL-004, PNC-VITAL-005, PNC-VITAL-006, PNC-VITAL-007, PNC-VITAL-008, PNC-009 (pp9).

**Immunisation (1):** IMM-006.

**Emergency (4):** EM-006, EM-007, EM-008, EM-009.

> Note: `PNC-001` (PPH hard-stop) being sign-off-pending is worth a clinician's attention — it's a core RED rule still flagged draft.

---

## 7. Appendix — All questions (every module)

Full text of every question the app can ask (68 total), grouped by module. Auto-generated from `asha_engine.json` v2.6.0-guideline-aligned.

### 🍼 Newborn Checkup (0–28 days) — `newborn` (14)
*নবজাতক চেকআপ (০-২৮ দিন)*

| ID | Question (English) | প্রশ্ন (বাংলা) |
|---|---|---|
| `n1` | Is the baby unable to breastfeed? | শিশু বুকের দুধ খেতে পারছে না? |
| `n2` | Does the baby have fever? | শিশুর শরীরে জ্বর আছে? |
| `n3` | Is breathing fast or difficult? | শ্বাস-প্রশ্বাস দ্রুত বা কষ্টকর? |
| `n4` | Is the navel red, swollen, or has pus? | নাভি লাল, ফোলা বা পুঁজ আছে? |
| `n5` | Is the baby lethargic or not moving? | শিশু অনেক কম নড়ছে বা নিস্তেজ? |
| `n6` | Does the skin look yellow or bluish? | ত্বক হলুদ বা নীলাভ দেখাচ্ছে? |
| `n7` | Has the baby had convulsions or abnormal movements? | শিশুর খিঁচুনি বা অস্বাভাবিক নড়াচড়া হয়েছে? |
| `n8` | Is the baby cold to touch / colder than normal (hypothermia)? | শিশুর শরীর ঠান্ডা লাগছে বা স্বাভাবিকের চেয়ে কম গরম? |
| `n9` | Many skin pustules / pus-filled blisters, or pus draining from ear? | ত্বকে অনেক ফুসকুড়ি/পুঁজভরা ফোস্কা, বা কান থেকে পুঁজ পড়ছে? |
| `n10` | Is the soft spot on the head (fontanelle) bulging? | মাথার নরম অংশ (তালু) ফুলে উঁচু হয়ে আছে? |
| `n11` | Has the baby NOT passed stool in the first 24 h, or NOT passed urine in the first 48 h? | শিশু কি প্রথম ২৪ ঘণ্টায় একবারও মলত্যাগ বা ৪৮ ঘণ্টায় মূত্রত্যাগ করেনি? |
| `n12` | Does the baby have loose stools / diarrhoea? | শিশুর পাতলা পায়খানা (ডায়রিয়া) হচ্ছে? |
| `n13` | Are the baby's eyes red, swollen, or draining pus? | শিশুর চোখ লাল, ফোলা বা চোখ থেকে পুঁজ পড়ছে? |
| `n14` | Does the baby have a visible congenital defect (e.g. cleft lip/palate, abnormal limb)? | শিশুর কোনো অঙ্গের জন্মগত ত্রুটি (যেমন ঠোঁট/তালু ফাটা, অস্বাভাবিক অঙ্গ) আছে? |

### 🧒 Child Health Check (2 months–5 years) — `child` (13)
*শিশু স্বাস্থ্য যাচাই (২ মাস–৫ বছর)*

| ID | Question (English) | প্রশ্ন (বাংলা) |
|---|---|---|
| `c1` | Has fever lasted more than 5 days? | পাঁচ দিনের বেশি জ্বর চলছে? |
| `c2` | Is there cough or breathing difficulty? | কাশি বা শ্বাসকষ্ট আছে? |
| `c3` | Is there diarrhoea or repeated vomiting? | ডায়রিয়া বা বারবার বমি হচ্ছে? |
| `c4` | Is the child completely refusing to eat? | শিশু খেতে একদম অস্বীকার করছে? |
| `c5` | Signs of dehydration — sunken eyes, dry lips? | পানিশূন্যতার লক্ষণ (চোখ গর্তে, ঠোঁট শুকনো)? |
| `c6` | Is weight much less than expected for age? | ওজন বয়সের তুলনায় অনেক কম? |
| `c7` | Has the child had convulsions or fits? | শিশুর খিঁচুনি হয়েছে বা হচ্ছে? |
| `c8` | Is the child abnormally sleepy, lethargic, or unconscious? | শিশু অস্বাভাবিকভাবে ঘুমন্ত, নিস্তেজ বা অজ্ঞান? |
| `c9` | Does the child vomit everything? | যা-ই খাচ্ছে সব বমি করে ফেলছে? |
| `c10` | Stiff neck, light sensitivity, or severe headache with fever? | ঘাড় শক্ত, আলোয় কষ্ট, বা জ্বরসহ প্রচণ্ড মাথাব্যথা? |
| `c11` | Is there blood in the stool (dysentery)? | পায়খানার সাথে রক্ত যাচ্ছে? |
| `c12` | Are the palms or inner eyelids very pale (anaemia)? | হাতের তালু বা চোখের পাতা খুব ফ্যাকাশে? |
| `c13` | Lower chest indrawing, or stridor at rest? | বুকের নিচের অংশ ভেতরে ঢুকে যাচ্ছে, বা বিশ্রামেও শ্বাসের শব্দ (stridor)? |

### 🤰 Pregnant Mother Checkup (ANC) — `pregnancy` (14)
*গর্ভবতী মায়ের চেকআপ*

| ID | Question (English) | প্রশ্ন (বাংলা) |
|---|---|---|
| `p1` | Is blood pressure high? | রক্তচাপ বেশি? |
| `p2` | Is there swelling of legs or face? | পা বা মুখ ফুলে যাচ্ছে? |
| `p3` | Is there bleeding or severe abdominal pain? | রক্তপাত বা তীব্র পেট ব্যথা? |
| `p4` | Has the baby's movement reduced? | শিশুর নড়াচড়া কমে গেছে? |
| `p5` | Has ANC checkup been missed for 3+ months? | তিন মাসের বেশি ANC চেকআপ বাদ গেছে? |
| `p6` | Is there blurred vision? | চোখে ঝাপসা দেখছেন? |
| `p7` | Has there been a convulsion or fit during pregnancy? | গর্ভাবস্থায় খিঁচুনি বা ফিট হয়েছে? |
| `p8` | Very pale, weak, or breathless on slight exertion (severe anaemia)? | খুব ফ্যাকাশে, দুর্বল, বা সামান্য পরিশ্রমেই হাঁপিয়ে যাচ্ছেন? |
| `p9` | Fever, especially with chills/rigors? | জ্বর, বিশেষ করে কাঁপুনি দিয়ে জ্বর আসছে? |
| `p10` | Sudden gush or continuous leaking of fluid (PROM)? | যোনিপথে হঠাৎ জল ভেঙেছে বা ক্রমাগত জল ঝরছে? |
| `p11` | Is there a headache? | মাথা ব্যথা হচ্ছে? |
| `p11d` | Is the headache very severe, lasting >2 days, or worsening? | মাথা ব্যথা কি খুব তীব্র, ২ দিনের বেশি, বা বাড়ছে? |
| `p12` | Is there dizziness or weakness? | মাথা ঘোরা বা দুর্বল লাগছে? |
| `p9r` | Fever WITH chills or rigors? | জ্বরের সাথে কাঁপুনি বা শীত-শীত ভাব আছে? |

### 🤱 Postpartum Checkup (0–42 days) — `delivery_pnc` (11)
*প্রসব-পরবর্তী চেকআপ (০-৪২ দিন)*

| ID | Question (English) | প্রশ্ন (বাংলা) |
|---|---|---|
| `pp1` | Is there excessive bleeding or foul-smelling discharge? | অতিরিক্ত রক্তপাত বা দুর্গন্ধযুক্ত স্রাব? |
| `pp2` | Is there fever or chills? | জ্বর বা ঠান্ডা লাগছে? |
| `pp3` | Is there breast pain, swelling, or red marks? | স্তনে ব্যথা, ফোলা বা লাল দাগ? |
| `pp4` | Is there severe abdominal pain or suture problem? | পেটে তীব্র ব্যথা বা সেলাইয়ে সমস্যা? |
| `pp5` | Is there burning or difficulty urinating? | প্রস্রাবে জ্বালা বা কষ্ট হচ্ছে? |
| `pp6` | Is there extreme weakness or dizziness? | খুব দুর্বল বা মাথা ঘোরা হচ্ছে? |
| `pp7` | Has there been a convulsion or fit after delivery? | প্রসবের পর খিঁচুনি বা ফিট হয়েছে? |
| `pp8` | Is there difficulty breathing? | শ্বাস নিতে কষ্ট হচ্ছে? |
| `pp9` | Persistent low mood, crying, sleep/appetite loss, or no interest in the baby? | মন খুব খারাপ, কান্না, ঘুম/খাওয়া কমে যাওয়া, বা বাচ্চার প্রতি আগ্রহ নেই? |
| `pp6s` | Fainting / collapsing, or unable to stand (severe weakness)? | মাথা ঘুরে পড়ে যাচ্ছেন, নাকি দাঁড়াতেও পারছেন না (তীব্র দুর্বলতা)? |
| `pp10` | Unable to control urine or stool (incontinence)? | প্রস্রাব বা পায়খানা ধরে রাখতে পারছেন না (অসংযম)? |

### 💉 Immunization — UIP National Schedule — `immunisation` (6)
*টিকা মিস / ইমিউনাইজেশন*

| ID | Question (English) | প্রশ্ন (বাংলা) |
|---|---|---|
| `im1` | What is the child's age in months? | শিশুর বয়স কত মাস? |
| `im2` | Which vaccine was missed? | কোন টিকা মিস হয়েছে? |
| `im3` | How many days ago was the vaccine due? | কতদিন আগে টিকা দেওয়ার কথা ছিল? |
| `im4` | Does the child have any illness now? | শিশুর কি কোনো অসুস্থতা আছে এখন? |
| `im5` | Has the booster dose been missed for child aged 1–5 years? | ১-৫ বছর বয়সী শিশুর বুস্টার ডোজ মিস হয়েছে? |
| `im6` | Was there a severe reaction after a previous vaccine dose (AEFI)? | আগের টিকার পর কি গুরুতর প্রতিক্রিয়া হয়েছিল? |

### 👶 Child Development Screening (2 months–3 years) — `development` (2)
*শিশু বিকাশ যাচাই (২ মাস–৩ বছর)*

| ID | Question (English) | প্রশ্ন (বাংলা) |
|---|---|---|
| `d1` | Which age band is the child in? | শিশুর বয়স কোন ধাপে? |
| `d2` | Is ANY ONE of the danger signs listed for this age present? (check the list below) | এই বয়সের জন্য তালিকাভুক্ত কোনো একটি বিপদচিহ্ন কি দেখা যাচ্ছে? (নিচের তালিকা দেখে নিন) |

### 🚨 Emergency — Global Hard-Stop Engine — `emergency` (8)
*জরুরি অবস্থা যাচাই*

| ID | Question (English) | প্রশ্ন (বাংলা) |
|---|---|---|
| `e1` | Is there excessive bleeding? | অতিরিক্ত রক্তপাত হচ্ছে? |
| `e2` | Has there been convulsion or loss of consciousness? | খিঁচুনি বা অজ্ঞান হয়েছে? |
| `e3` | Is there severe difficulty breathing? | শ্বাস নিতে খুব কষ্ট হচ্ছে? |
| `e4` | Is the patient unresponsive or unconscious? | রোগী সাড়া দিচ্ছে না বা জ্ঞান নেই? |
| `e5` | Snakebite, venomous sting, or animal bite? | সাপে কামড়েছে, বিষাক্ত পোকা বা পশুর কামড়? |
| `e6` | Poison, pesticide, or overdose ingested? | বিষ/কীটনাশক/অতিরিক্ত ওষুধ খেয়েছে বা খাওয়ানো হয়েছে? |
| `e7` | Cold clammy skin, very weak pulse, extreme listlessness (shock)? | ঠান্ডা-ঘামে ভেজা, খুব দুর্বল নাড়ি, অত্যন্ত নিস্তেজ (শকের লক্ষণ)? |
| `e8` | Major injury, bleeding from a large wound, or severe burn? | গুরুতর আঘাত, বড় ক্ষত থেকে রক্তপাত, বা মারাত্মক পোড়া? |
