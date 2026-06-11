# AshaMitra — Triage Flows & Rules (all 7 cases)

How the triage feature works end-to-end, and the exact clinical rules each of the
7 cases uses. Rule data is sourced from [`assets/data/asha_engine.json`](assets/data/asha_engine.json)
(`asha_cdss_engine_v2`, v2.4.0-draft); questions from
[`gemini_conversation_service.dart`](lib/core/services/gemini_conversation_service.dart).

> **Important:** the LLM (Gemini) only *converses* and *extracts answers*. The
> **band (Green/Yellow/Red) is decided by the deterministic rule engine**, never
> by the LLM. Same answers → same band, every time.

---

## 1. The 7 cases → 6 engine modules

The worker picks one of **7 cases**; `infant` and `child` share one engine module,
so there are **6 rule modules**.

| Case (worker picks) | Engine module | Title | Protocol basis |
|---|---|---|---|
| 🤰 Pregnancy | `pregnancy` | গর্ভবতী মায়ের চেকআপ | MCP card · PMSMA |
| 🩺 Postpartum | `delivery_pnc` | প্রসব-পরবর্তী চেকআপ (0–42 d) | SBA · PPH · PNC |
| 👶 Newborn | `newborn` | নবজাতক চেকআপ (0–28 d) | IMNCI · HBNC |
| 🍼 Infant | `child` | (1–12 mo, uses child module) | IMNCI · HBYC |
| 🧒 Child | `child` | শিশু স্বাস্থ্য (2 mo–5 y) | IMNCI · HBYC |
| 💉 Immunization | `immunisation` | টিকা / ইমিউনাইজেশন | UIP (national schedule) |
| 🚨 Emergency | `emergency` | জরুরি অবস্থা যাচাই | Emergency / 108 |

---

## 2. End-to-end flow

```
Home → Triage
   │
   ▼
[SelectCaseScreen]  ── speak the situation (STT bn_IN)  ──►  CaseDetectionService
   │  (or tap one of the 7 case tiles)                        (keywords + Gemini)
   │                                                                │
   │                                                   [CaseConfirmScreen]
   │                                                   detected case + confidence badge
   ▼                                                                │
[VoiceTriageScreen]  ◄───────────────────────────────────────────────┘
   │   hold-to-talk conversation (worker presses orb, speaks, releases)
   │
   ├─ ONLINE  → GeminiConversationService.respond()
   │     • acknowledges what the worker said
   │     • asks the unanswered danger-sign question MOST RELEVANT to the input
   │     • extracts answers (extracted_answers) + reports asked_question_id
   │     • returns risk_level (display only) + spoken_response (+TTS audio)
   │     • loop-guarded (re-ask ≥3× → mark answered); max 10 turns
   │
   └─ OFFLINE → OfflineBrain + RuleExecutor + CLUP pipeline
         • deterministic next-question selection
         • keyword emergency check (108) + immediate-action engine
   │
   │   (spoken vitals — "BP ১৪০/৯০", "জ্বর ১০২" — parsed by VitalsExtractor →
   │    instant danger alerts, stored as temperature_c / systolic_bp / spo2 …)
   ▼
Finish when:  2+ RED danger signs · all questions covered · or turn limit
   │   → _submitAnswers (answers + vitals + Q&A pairs)
   ▼
[TriageResultScreen]
   • RuleExecutor.execute(module, answers, vitals) → DecisionOutput
   • effective band = WORSE of (engine band, conversational risk) — never downgrades RED
   • shows: band card · "কেন এই সিদ্ধান্ত?" (danger signs + protocol) ·
            referral map · decision trace (audit)
   • auto-saves: DecisionTrace + MDSR hook + report → Atlas (if logged in)
```

---

## 3. The deterministic rule engine

**Evaluation order** (`engine_rules.evaluation_order`):
```
hard_stop  →  combination_rules  →  numeric_rules  →  risk_score
```
- **`red_lock_enabled: true`** — once a RED fires, nothing can downgrade it.
- **`fallback_band: GREEN`** — if no rule fires, the case is Green.
- Answers are **graded** (`AnswerCodes`: yes / no / severe / mild / unsure);
  `AnswerCodes.isAffirmative()` decides whether a danger-sign question counts as
  "yes" for a rule. "unsure" never silently passes as safe.

**Rule categories per module:**
| Category | Fires | Meaning |
|---|---|---|
| `hard_stop_rules` | a single danger-sign question = yes | instant **RED** |
| `combination_rules` | two specific signs both = yes | **RED** (combo escalation) |
| `numeric_rules` | a measured vital crosses a threshold | **RED** or **YELLOW** |
| `yellow_rules` | a moderate sign = yes | **YELLOW** |
| `risk_engine` | weighted score of remaining signs | band by score, else GREEN |

**Bands → action / referral:**
| Band | Action (bn) | Referral |
|---|---|---|
| 🟢 GREEN | বাড়িতে যত্ন নিন। রুটিন ফলো-আপ | None |
| 🟡 YELLOW | ২৪ ঘণ্টার মধ্যে PHC-তে রেফার | PHC within 24 h (recheck 24 h) |
| 🔴 RED | এখনই ১০৮ কল করুন; FRU/SNCU/DH | FRU / SNCU / DH immediately (recheck 4 h if refused) |

---

## 4. Per-case questions & rules

Each section lists the **questions** (id → what it checks) and the **rules** that
use them. `q→RED` means "this question = yes triggers RED."

### 🤰 Pregnancy — `pregnancy` (MCP · PMSMA) — 14 questions
**Questions:** p1 high BP · p2 leg/face swelling · p3 bleeding/severe abdo pain ·
p4 reduced fetal movement · p5 missed ANC · p6 blurred vision · p7 convulsion
(eclampsia) · p8 severe pallor/breathless · p9 fever · p9r fever with rigors ·
p10 leaking liquor (PROM) · p11 headache · p11d severe/>2-day headache · p12 dizziness

| Category | Rules |
|---|---|
| Hard-stop → RED | ANC-001 (p1) · ANC-003 (p3) · ANC-004 (p4) · ANC-006 (p6) · ANC-007 (p7) · ANC-008 (p8) · ANC-010 (p10) · ANC-009R (p9r) |
| Combination → RED | ANC-COMB-001 (p1+p2) · -002 (p6+p2) · -003 (p3+p4) · -004 (p1+p6) · -005 (p11+p11d) · -006 (p11+p2) |
| Yellow | ANC-002 (p2) · ANC-005 (p5) · ANC-011 (p11) · ANC-012 (p12) · ANC-009 (p9) |
| Numeric | RED: SBP≥140 (V-001), DBP≥90 (V-002), Hb<7 (V-003), SBP≥160 (V-005), proteinuria≥2+ (V-006), GA<37w (V-008), labour>12h (V-009), PROM>12h (V-010), TSH>10 (V-011), FHR<120 (V-014), FHR>160 (V-015) · YELLOW: Hb 7–10 (V-004), fundal-height diff>4 (V-007), TSH 2.5–10 (V-012), OGTT-2h≥140 GDM (V-013) |

### 🩺 Postpartum — `delivery_pnc` (SBA · PPH · PNC) — 10 questions
**Questions:** pp1 heavy bleeding/foul discharge · pp2 fever/chills · pp3 breast
pain/swelling · pp4 severe abdo pain/suture problem · pp5 burning urination ·
pp6 weak/dizzy · pp6s severe dizziness/collapse · pp7 convulsion (PP eclampsia) ·
pp8 difficulty breathing · pp9 low mood/anhedonia (depression)

| Category | Rules |
|---|---|
| Hard-stop → RED | PNC-001 (pp1) · PNC-007 (pp7) · PNC-008 (pp8) · PNC-006S (pp6s) |
| Combination → RED | PNC-COMB-001 (pp1+pp2) · -002 (pp4+pp2) · -003 (pp1+pp6) · -004 (pp3+pp2) |
| Yellow | PNC-002 (pp2) · PNC-003 (pp3) · PNC-004 (pp4) · PNC-005 (pp5) · PNC-006 (pp6) · PNC-009 (pp9) |
| Numeric | RED: temp≥38 (V-001), Hb<7 (V-002), SBP≥140 (V-004), pads-soaked≥2/30min PPH (V-006), pads>5/day (V-007), temp≥38.9 sepsis (V-008) · YELLOW: Hb 7–10 (V-003), HR>110 (V-005) |

### 👶 Newborn — `newborn` (IMNCI · HBNC, 0–28 d) — 10 questions
**Questions:** n1 unable to breastfeed · n2 fever · n3 fast/difficult breathing ·
n4 umbilical redness/pus · n5 lethargy/less movement · n6 yellow/blue skin ·
n7 convulsion/abnormal movement · n8 cold body (hypothermia) · n9 skin pustules/ear
discharge · n10 bulging fontanelle

> Newborn is the strictest module — **every danger sign is a hard-stop RED.**

| Category | Rules |
|---|---|
| Hard-stop → RED | NB-001 (n1) · NB-002 (n2) · NB-003 (n3) · NB-004 (n4) · NB-005 (n5) · NB-006 (n6) · NB-007 (n7) · NB-008 (n8) · NB-010 (n9) · NB-011 (n10) |
| Combination → RED | NB-COMB-001 (n2+n3) · -002 (n6+n1) · -003 (n5+n3) · -004 (n4+n2) · -005 (n1+n2) |
| Numeric | RED: SpO2<90 (V-001), RR≥60 (V-002), temp≥37.5 (V-003), weight<1.5kg (V-004), temp<35.5 (V-005), HR>180 (V-006), weight<1.8kg (V-008) · YELLOW: weight 1.8–2.5kg (V-007), temp 35.5–36.4 cold-stress (V-009) |

### 🍼🧒 Infant & Child — `child` (IMNCI · HBYC, 2 mo–5 y) — 13 questions
**Questions:** c1 fever >5 days · c2 cough/breathing difficulty · c3 diarrhoea/vomiting ·
c4 stopped feeding · c5 sunken eyes/dry lips · c6 very low weight · c7 convulsion ·
c8 lethargic/unconscious · c9 vomits everything · c10 neck stiffness/severe headache
(meningitis) · c11 blood in stool (dysentery) · c12 pallor (anaemia) · c13 chest
indrawing/stridor (severe pneumonia)

| Category | Rules |
|---|---|
| Hard-stop → RED | CH-001 (c1) · CH-004 (c4) · CH-005 (c5) · CH-007 (c7) · CH-008 (c8) · CH-009 (c9) · CH-010 (c10) · CH-013 (c13) |
| Combination → RED | CH-COMB-001 (c2+c5) · -002 (c1+c2) · -003 (c3+c4) · -004 (c3+c5) |
| Yellow | CH-002 (c2) · CH-003 (c3) · CH-006 (c6) · CH-011 (c11) · CH-012 (c12) |
| Numeric | RED: SpO2<90 (V-001), MUAC<11.5 (V-002), RR≥50 (V-004), temp≥40 (V-005a), WAZ<-3 (V-006) · YELLOW: MUAC 11.5–12.5 (V-003), temp 39–40 (V-005b), RR≥40 older (V-007), SpO2 90–94 (V-008) |

### 💉 Immunization — `immunisation` (UIP) — 6 questions
**Questions:** im1 age 0–12 mo · im2 missed vaccine · im3 overdue >3 mo · im4 currently
ill · im5 booster overdue · im6 prior severe reaction (AEFI)

> No hard-stops / no RED — immunization is **counselling/scheduling (all YELLOW)**.

| Category | Rules |
|---|---|
| Yellow | IMM-001 (im1 ∈ 0–6/6–12 mo) · IMM-002 (im2 ∈ BCG-OPV/DPT-Penta/Measles-MR) · IMM-003 (im5 booster) · IMM-004 (im4 ill) · IMM-005 (im3 >3 mo) · IMM-006 (im6 AEFI) |

### 🚨 Emergency — `emergency` (108) — 8 questions
**Questions:** e1 excessive bleeding · e2 convulsion/unconscious · e3 breathing
stopped/severe distress · e4 unresponsive · e5 snake/animal bite · e6 poison/pesticide
ingestion · e7 shock (cold-clammy, weak pulse) · e8 major injury/bleeding/burn

> Every question is a **hard-stop RED → call 108 immediately.**

| Category | Rules |
|---|---|
| Hard-stop → RED | EM-001 (e1) · EM-002 (e2) · EM-003 (e3) · EM-004 (e4) · EM-006 (e5) · EM-007 (e6) · EM-008 (e7) · EM-009 (e8) |

---

## 5. How a result is produced & saved

1. **`RuleExecutor.execute(moduleId, answers, vitals)`** runs the 4-stage pipeline
   above and returns a `DecisionOutput`: `band`, `actionBn/En`, `referral`,
   `dangerSigns`, `suspectedConditions`, `riskScore`, `triggeredRules`, `trace`,
   `protocolHash`.
2. **Effective band = worse of** the engine band and the conversational `risk_level`
   — a fired RED is never downgraded (`red_lock`).
3. **TriageResultScreen** shows the band card, the plain-Bengali
   **"কেন এই সিদ্ধান্ত?"** panel (matched danger signs + protocol basis), the
   **referral map** (real GPS/OSRM distance for Yellow/Red), and the collapsible
   **decision trace** (every rule evaluated, fired or not — for audit).
4. **Auto-save:** `DecisionTraceService.write()` (audit trace + protocol hash) →
   `MdsrHookService.evaluateAndEnqueue()` (maternal-death surveillance) →
   `PatientController.saveReport()` (uploads to Atlas when logged in; otherwise
   queued locally and synced on next login).

---

## 6. Online vs offline — same engine, two front doors

| | Online | Offline |
|---|---|---|
| Conversation | **Gemini** (`/chat-with-voice`) — natural, relevance-driven questions | OfflineBrain + CLUP — deterministic question order |
| Answer extraction | Gemini `extracted_answers` + local yes/no capture | local situation extractor + yes/no |
| Emergency catch | within the LLM turn | CLUP keyword scan (108) + immediate-action engine |
| **Band decision** | **same `RuleExecutor`** on the collected answers | **same `RuleExecutor`** |

The triage tries Gemini first (like the assistant); the offline rules only run on a
genuine network failure. **Either way the final band comes from the same
deterministic engine** — so the clinical outcome is identical online or offline.

---

*Generated from the live engine data (`asha_engine.json` v2.4.0-draft) and the
triage code. The draft rules are pending clinical sign-off — see
`docs/AshaMitra_SignOff_Checklist.md`.*
