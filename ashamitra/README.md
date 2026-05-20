# AshaМітра — Unified ASHA Clinical Decision Support System

**System ID:** `asha_cdss` · **Version:** `1.0.0`  
**Audience:** AIIH&PH Kolkata clinical reviewers · West Bengal Health Department Secretariat · Engineering team  
**Platform:** Flutter (Android-first, offline-capable)

---

## What it does

AshaМітра puts a deterministic clinical decision engine in the hands of ASHA workers. The worker speaks in Bengali (or Hindi); the app listens, identifies the beneficiary and situation, runs the appropriate clinical protocol, and emits a triage band — **Green / Yellow / Red** — with a Bengali action card and a complete, auditable decision trace.

Four functions, in order:

1. **Listen** — on-device ASR (IndicWhisper INT8) transcribes speech; IndicBERT NER tags spans onto a closed clinical ontology.
2. **Route** — the module router selects which of five clinical modules applies to this beneficiary right now.
3. **Triage** — the selected module runs its deterministic decision tree; the global emergency engine re-sweeps after every state update.
4. **Act** — the system emits a triage band, a referral level, a Bengali action card, and a full decision trace stored in encrypted local SQLite.

No LLM is in the diagnostic path. Same inputs always produce the same outputs.

---

## Clinical modules

| Module ID | Population | Protocol basis |
|---|---|---|
| `newborn_0_28d` | Newborn 0–28 days | HBNC + IMNCI |
| `child_2m_5y` | Child 2 months–5 years | IMNCI + HBYC |
| `anc` | Pregnant woman | MCP + PMSMA |
| `delivery_pnc` | Postpartum woman 0–42 days | SBA + PPH + PNC |
| `immunisation` | Any age 0–16 y + pregnant women | UIP national schedule |

Each module is a pure function: closed-ontology symptom payload in → triage band + action card out. The global emergency engine holds all RED hard-stop rules in a single signed registry; modules reference rules by ID and never redefine them.

---

## Architecture

```
Voice (Bengali/Hindi)
        ↓
L1  IndicWhisper on-device ASR
        ↓
L2  IndicBERT NER → closed ontology codes
        ↓
L3  Module router  (beneficiary role · visit context · symptom prefixes)
        ↓
L4  Clinical module  (newborn | child | ANC | delivery+PNC | immunisation)
        ↓  ← global emergency engine re-sweeps every state update
L5  Global emergency rule engine  (severity 1–5 · RED hard-stop)
        ↓
L6  Worst-band selector · referral matrix · Bengali action card
        ↓
L7  SQLCipher encrypted local storage · decision trace · protocol hash
        ↓
L8  Background sync  (ANMOL · RCH portal · eSanjeevani · MDSR hooks)
```

Cross-cutting: mother–baby linkage · ANC→delivery→PNC continuity · MDSR audit hooks.

---

## Repository layout

```
lib/
├── app/                        # GetX app shell, routes
├── core/
│   ├── constants/              # API and app constants
│   ├── services/               # Storage, connectivity, case detection, Gemini triage
│   ├── theme/                  # Colors, typography, spacing
│   └── utils/                  # Date helpers, validators, permissions
└── features/
    ├── auth/                   # OTP login
    ├── emergency/              # Emergency screen + card
    ├── home/                   # Dashboard
    ├── onboarding/             # Splash, welcome, language selection
    ├── patients/               # Beneficiary registry (add, list, profile)
    ├── profile/                # ASHA profile
    ├── reports/                # Visit reports
    └── triage/
        ├── controller/         # Triage state (GetX)
        ├── data/
        │   ├── models/         # TriageCaseModel, QuestionModel, CaseEnvelope
        │   └── repositories/
        └── presentation/
            └── screens/
                ├── select_case_screen.dart     # Manual or voice case selection
                ├── case_confirm_screen.dart    # Detected case + confidence badge
                ├── voice_triage_screen.dart    # Voice Q&A loop
                ├── dynamic_triage_screen.dart  # Tap-based Q&A fallback
                └── triage_result_screen.dart   # Band + action card

assets/
├── data/triage_cases.json      # All 5 modules: questions, keywords, scoring
├── guidelines/                 # MoHFW source PDFs (IMNCI, HBNC, MCP, SBA, UIP…)
└── images/
```

---

## Case detection — hybrid approach

When the ASHA speaks a free-form situation description, the app detects the correct module using a two-stage pipeline:

| Stage | Method | Latency | Works offline |
|---|---|---|---|
| 1 | Rule-based keyword matching (Bengali + Hindi) | < 100 ms | ✅ |
| 2 | Gemini 1.5 Flash (fallback if confidence < 80 %) | 2–3 s | ❌ |

The ASHA always sees a confirmation screen with the detected case and confidence badge before questions begin. She can override the detection with a single tap.

See [`DYNAMIC_CASE_DETECTION.md`](DYNAMIC_CASE_DETECTION.md) for full details.

---

## Voice speech-to-text

| Mode | Engine | Condition |
|---|---|---|
| Online | Google STT (`bn_IN` → `hi_IN` → `en_IN`) | Internet available |
| Offline | Whisper Tiny on-device | No internet |

The app switches automatically. Keyword matching handles multilingual yes/no/maybe answers across Bengali, Hindi, and English.

See [`VOICE_STT_IMPLEMENTATION.md`](VOICE_STT_IMPLEMENTATION.md) for full details.

---

## Triage bands and referral levels

| Band | Meaning | Referral |
|---|---|---|
| 🟢 Green | No danger signs | Home care · routine follow-up |
| 🟡 Yellow | Moderate risk / treatable at PHC | PHC within 24 h · follow-up in 2 days |
| 🔴 Red | Emergency / hard-stop fired | FRU / SNCU / DH immediately (≤ 30–60 min) |

A hard-stop fire always overrides a score-derived Green or Yellow. There is no path that can downgrade a fired Red.

---

## Key design guarantees

- **Deterministic.** No hidden state, no randomness in the clinical path. Same inputs → same outputs, byte-for-byte.
- **Single emergency registry.** All RED hard-stop rules live in one signed registry. Cross-module contradictions are structurally impossible.
- **Re-sweep invariant.** The global emergency engine re-checks every rule after every state update during a question flow.
- **No LLM in diagnosis.** ASR transcribes; NER tags spans into a closed ontology. The clinical engine sees only structured data.
- **Voice navigates; taps commit.** Safety-relevant data entry (recording a vaccine, confirming a referral, capturing a measurement) always requires a deliberate confirm tap.
- **Auditable trace.** Every case envelope contains a complete ordered trace with timestamps, rule evaluations, and hard-stop checks (including non-fires). An MDSR audit can reproduce the ASHA's decision flow exactly.
- **Signed protocol bundles.** The engine refuses unsigned protocol or registry updates.
- **Offline-first.** Full triage works with no internet. Sync to ANMOL / RCH / eSanjeevani happens in the background when connectivity is available.

---

## Local storage

Encrypted SQLite via SQLCipher (AES-256, key from device TEE). Append-only writes; corrections create versioned rows.

Core tables: `beneficiary` · `clinical_case` · `decision_trace` · `visit` · `vaccine_event` · `reminder` · `protocol_bundle` · `audio_blob` · `sync_queue`.

Mother and baby are separate beneficiary rows linked via `linked_to`. Linked cases (e.g. mother + newborn triaged in the same visit) share a `linked_cases` JSON array in each case envelope and drive a single consolidated action card.

---

## Getting started

### Prerequisites

- Flutter ≥ 3.x, Dart ≥ 3.0
- Android SDK (min API 23)
- Microphone permission granted on device

### Run

```bash
flutter pub get
flutter run                     # debug, default flavour
flutter run -t lib/main_dev.dart   # dev flavour
flutter run -t lib/main_prod.dart  # prod flavour
```

### Build release APK

```bash
flutter build apk --release
```

---

## Implementation roadmap

| Phase | Scope | Duration |
|---|---|---|
| 0 | Voice + ASR + NER + ontology v1 (Bengali) | 8 weeks |
| 1 | Newborn module + emergency engine + offline storage + ANMOL sync | 12 weeks |
| 2 | ANC module + PMSMA flagging + mother–baby linkage | 8 weeks |
| 3 | Child IMNCI/HBYC + UIP scheduler + reminders | 10 weeks |
| 4 | Delivery & PNC module + PPH + MDSR hooks | 8 weeks |
| 5 | Hindi support + multi-district rollout + dashboards | ongoing |
| 6 | Adolescent (Td 10/16 yr, RKSK) | future |

Pilot district sequence: Murshidabad → Birbhum → state-wide via NHM.

---

## Companion documents

| Document | Contents |
|---|---|
| `asha_voice_triage_architecture.md` | System architecture v0.1 |
| `newborn_imnci_engine.md` | Newborn module v1.0.0 |
| `anc_risk_engine.md` | Pregnancy module v1.0.0 |
| `uip_immunisation_engine.md` | Immunisation module v1.0.0 |
| `emergency_rule_engine.md` | Global emergency engine v1.0.0 |
| `DYNAMIC_CASE_DETECTION.md` | Case detection implementation |
| `VOICE_STT_IMPLEMENTATION.md` | STT implementation |

---

## Open items for clinical sign-off (AIIH&PH / Secretariat)

1. PSBI threshold — confirm any-1-sign rule (newborn module §3.1)
2. HRP score weights and dimension caps — OB-GYN faculty workshop
3. PPH proxy — "≥ 2 pads soaked in 30 min" acceptable for ASHA scope?
4. DVT / oliguria severity tiers — currently severity 3; confirm vs 4
5. MgSO4 / misoprostol pre-referral — ASHA scope vs ANM scope
6. Languages for v1 — Bengali + Hindi confirmed; Santali planned for v2
7. Voice ↔ tap data-entry split — confirm clinically defensible
8. Protocol bundle sign-off process — dual sign-off (AIIH&PH + state MH division)
9. MDSR integration depth — fields, consent, trigger conditions
10. Sync intervals — daily vs weekly per district connectivity reality
11. Data residency — SQLCipher + TEE-bound key acceptable per state IT policy
12. App branding — WB Health & Family Welfare badge vs pilot-mode badge

---

*v1.0.0 — integration spine for the unified ASHA CDSS. Authored from IMNCI, HBNC, HBYC, MCP, PMSMA, SBA, PPH, MDSR, UIP source documents (MoHFW). For clinical sign-off prior to AIIH&PH Kolkata review and West Bengal Health Department Secretariat engagement.*
