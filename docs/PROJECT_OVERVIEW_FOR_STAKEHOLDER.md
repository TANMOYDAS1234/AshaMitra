# AshaMitra — Stakeholder Briefing

**Voice-first clinical decision support for ASHA (community health) workers in West Bengal.**

> Built by: Tanmoy Das | Document date: 2026-05-31 | Status: Pilot-ready (Android), iOS pending

---

## 1. The Problem

India has **over a million ASHA workers** serving as the front line of rural primary health care. They visit pregnant mothers, newborns, and children in remote villages — often in areas with no doctor for 20+ km, weak mobile signal, and printed protocol books that are bulky, language-mixed (English + Hindi), and easy to misapply under stress.

The cost of getting a referral decision wrong is high:
- A missed danger sign in a newborn can become sepsis within hours.
- A skipped escalation in pre-eclampsia can become eclampsia within a day.
- Postpartum haemorrhage has a survival window measured in **minutes**.

ASHA workers know the protocols — what they need is a fast, hands-free, vernacular tool that **walks them through a structured triage in their own language** and produces an audit-quality record automatically.

---

## 2. What AshaMitra Is

A voice-driven Flutter mobile app + cloud backend that lets an ASHA worker:

1. **Speak in Bengali** (or Hindi / English) about a patient's situation.
2. The app **identifies the case type automatically** (pregnancy, newborn, child, etc.) and walks the worker through a structured set of clinical questions.
3. A rule engine classifies the case as **🔴 RED (refer immediately) / 🟡 YELLOW (refer within 24 h) / 🟢 GREEN (home care)**.
4. The decision, the reasoning, the danger signs detected, and the referral instructions are all **saved as a permanent triage record**, both locally and on a central admin dashboard.

Everything works **offline** — the rule engine, the questions, the local DB, and the report generation are all on-device. The cloud is only used for syncing, voice-to-text, AI-powered conversational follow-up, and the admin dashboard.

---

## 3. Cases Covered (7 Modules)

| # | Module | Protocol Reference | Questions | Hard-Stop Rules |
|---|---|---|---|---|
| 1 | 👶 **Newborn** (0–28 days) | HBNC + IMNCI | 7 | 6 PSBI hard-stops (feeding refusal, fever, fast breathing, navel infection, lethargy, jaundice/cyanosis) |
| 2 | 👶 **Infant** (1–12 months) | IMNCI + HBYC | 6 | 4 hard-stops (feeding stop, prolonged fever, breathing difficulty, severe dehydration) |
| 3 | 🧒 **Child** (1–5 years) | IMNCI + HBYC | 6 | 2 hard-stops (fever >5 days, severe dehydration) + SAM/MAM screening |
| 4 | 🤰 **Pregnancy** (ANC) | MCP + PMSMA | 7 | 4 hard-stops (pre-eclampsia, APH, reduced fetal movement, eclampsia prodrome) |
| 5 | 🤱 **Postpartum** (PNC) | SBA + PPH + PNC | 6 | 1 PPH hard-stop + 5 escalation rules (mastitis, wound infection, UTI, anaemia) |
| 6 | 💉 **Immunization** | UIP National Schedule | 5 | Catch-up logic for BCG/OPV/Penta/Measles/MMR + AEFI flagging |
| 7 | 🚨 **Emergency** | Global Emergency Rule Engine | 5 | 5 hard-stops (haemorrhage, convulsion, respiratory distress, unconsciousness) + band-lock invariant |

**Total: 42 clinical decision rules. Every RED hard-stop triggers a Bengali action card + an MDSR (Maternal Death Surveillance and Response) hook where applicable.**

Source documents these rules were built from are in `/docs`:
- HBNC, HBYC, IMNCI, PMSMA, MDSR national guidelines (PDFs)
- Postpartum haemorrhage management, hypothyroidism in pregnancy, gestational diabetes, deworming, calcium supplementation guidelines
- National Immunization Schedule
- Revised India MCP Card (28-05-2018)

---

## 4. What the Worker Actually Sees

### Worker app — 4 main screens
1. **Home / Today's Tasks** — large coloured tiles for each module; urgent cases pinned at top; one-tap "Add Patient" inline if it's a new patient.
2. **Voice Triage** — circular orb that pulses while listening; chat-bubble transcript; spoken AI replies in worker's chosen language; results card with 🔴/🟡/🟢 band, reason, next step, and referral level (PHC / FRU / SNCU / DH).
3. **Patients** — searchable list, sortable by district/block; full per-patient history.
4. **Reports** — every triage session as a card; filterable by band + time + sort order; one-tap PDF export; swipe-to-delete with undo + offline queue.

### Admin dashboard
- All workers, all reports, all patients in one view.
- Drill down by worker / district / block / case type / risk band.
- Soft-delete + restore + permanent erase for governance.
- Analytics: RED/YELLOW/GREEN distribution, top danger signs, average risk per worker, cases-per-day trends.
- PDF export with worker breakdown table + case breakdown table + session details.

### Voice assistant
Always-on conversational helper that answers ASHA clinical questions ("জ্বর কত হলে বিপদ?" / "When is fever a danger sign?") using the same rule engine that powers triage — so the answer matches the protocol the worker is being asked to follow.

---

## 5. Tech Stack

### Frontend (Mobile)
- **Flutter 3.41.6** — single codebase, Android-ready today, iOS-buildable.
- **GetX** for state, routing, and translations.
- **speech_to_text** + **audioplayers** for voice in/out (low-latency, works offline for STT in some Android builds).
- **shared_preferences** for local storage of patients, reports, and offline-queued operations.
- **pdf** + **OpenFile** for on-device report generation in three languages.

### Backend (Cloud, on Render)
- **Node.js + Express** REST API.
- **MongoDB Atlas** (free tier) for patients / reports / users / cases.
- **JWT** auth, bcrypt-hashed passwords.
- **Google Gemini 2.0 Flash** for natural-language responses (conversational AI + situation summarisation). Multiple API keys rotated automatically when one hits its daily quota.
- **Google Cloud Text-to-Speech** (Wavenet-A, Bengali) for authentic Indian Bengali voice — much warmer than the default robotic TTS.

### Why this stack
- **Free / very cheap to run** during pilot — Render free tier, MongoDB Atlas free tier, Gemini free quota.
- **Cross-platform** — same Dart code compiles for Android and iOS.
- **Offline-first** — the entire rule engine, all 42 rules, every question, and the local DB live on the device. Internet is a "nice to have" for sync, not a hard requirement to triage.

---

## 6. Architecture (One-Page View)

```
┌─────────────────────────────────────────────────────────────┐
│  ASHA worker's phone (Android — iOS pending)                │
│  ──────────────────────────────────────────────────────────  │
│                                                              │
│   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│   │ Voice Triage │  │  Rule Engine │  │ Local Storage │      │
│   │  (STT + TTS) │──│ (42 rules,   │──│ (SharedPrefs, │      │
│   │              │  │  on-device)  │  │  offline     │      │
│   └──────┬───────┘  └──────┬───────┘  │  queue)      │      │
│          │                 │           └──────┬───────┘      │
│          │       Reports + Patients           │              │
│          ▼                                    ▼              │
│   ┌─────────────────────────────────────────────────────┐   │
│   │           Sync layer (auto-retry, conflict-safe)     │   │
│   └─────────────────────┬───────────────────────────────┘   │
│                         │ HTTPS                              │
└─────────────────────────┼──────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Render.com — Node/Express backend                          │
│  ──────────────────────────────────────────────────────────  │
│                                                              │
│   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌─────────┐  │
│   │  REST    │   │  Auth    │   │  Sync    │   │ Admin   │  │
│   │  /api/*  │──│ (JWT)    │──│ /reports │──│ panel   │  │
│   └──────────┘   └──────────┘   └──────────┘   └─────────┘  │
│        │              │              │             │         │
│        ▼              ▼              ▼             ▼         │
│   ┌──────────────────────────────────────────────────────┐  │
│   │              MongoDB Atlas (free tier)                │  │
│   └──────────────────────────────────────────────────────┘  │
│                                                              │
│   External AI services (proxied through backend so the      │
│   API keys never ship in the APK):                          │
│   ┌──────────────┐   ┌──────────────────────┐               │
│   │ Google Gemini│   │ Google Cloud TTS    │               │
│   │ (chat / NLU) │   │ (Bengali Wavenet-A) │               │
│   └──────────────┘   └──────────────────────┘               │
└─────────────────────────────────────────────────────────────┘
```

---

## 7. What Makes AshaMitra Stand Out

1. **Offline-first triage.** Most "health-tech" apps need a connection. Ours runs every clinical rule and every question entirely on the worker's phone. No signal = still triages, still records, syncs when the signal returns.
2. **Bengali Wavenet voice.** Not robotic Bengali — actual Indian Bengali with conversational rhythm. ASHA workers stop fighting the app and start trusting it.
3. **Audit-grade decision trace.** Every RED band stores the rule that fired, the question that triggered it, the timestamp, the worker, and the patient. If a referral was missed, the trace shows why — protected by a system invariant (`EM-005`) that locks a fired RED band so no later "no" answer can downgrade it.
4. **Hard-stop semantics built in.** The PSBI / PPH / pre-eclampsia / eclampsia / APH hard-stops aren't suggestions — once fired, the band is permanent and the worker sees a Bengali action card with the FRU / SNCU / DH referral level. This matches WHO guidance for the rural setting.
5. **Three-tier offline resilience for the data layer.** Reports queue → upload retry → sync → admin dashboard. Deletes likewise queue when offline and flush on the next sync, so the worker is never lied to about whether the server received the action.
6. **PDF export in the worker's chosen language.** Bengali, Hindi, or English. Includes the worker's name, district, and block on the cover. Layered fallbacks (isolate → UI-thread → minimal Helvetica) guarantee a PDF lands even on cheap devices.
7. **AI quota safety net.** Multiple Gemini API keys rotated automatically when one hits its daily limit. Backend marks dead keys for 24 h and serves an `AI_QUOTA` code so the app shows a friendly "AI is rate-limited, switching to offline mode" message instead of breaking.
8. **Multi-language UI throughout.** 280+ translation keys covering worker chrome, admin chrome, every snackbar, every error, every PDF heading — toggleable in profile.

---

## 8. Production-Readiness Scorecard (Honest)

| Area | State | Notes |
|---|---|---|
| Core triage flow | ✅ Working | All 7 modules, 42 rules, hard-stops, band lock — all live and tested. |
| Voice (TTS + STT) | ✅ Working | Bengali Wavenet-A; STT works in 3 languages; mic permission now requested explicitly to handle Xiaomi/Vivo quirks. |
| Offline mode | ✅ Working | Rule engine, questions, local DB, offline-queued patients & reports. |
| Sync | ✅ Working | Auto-retry on cold-start, conflict-safe merge, server marked authoritative. |
| Admin dashboard | ✅ Working | Workers, reports, soft-delete, restore, permanent erase, PDF export with breakdowns. |
| Report delete + undo | ✅ Working (after recent fix) | Now queues offline deletes; never lies to the worker; clear status snackbars. |
| Report PDF (worker) | ✅ Working (after recent fix) | Worker info on cover, translated band labels, live stage text in dialog, 4-layer fallback. |
| Multi-language | ✅ Working | 280+ keys across worker + admin + PDF in Bengali / Hindi / English. |
| Authentication | ✅ Working | JWT, bcrypt hash, restoreSession on startup. |
| Keep-warm for Render free tier | ✅ Working | UptimeRobot + GitHub Actions cron pings `/health` every 10 min. |
| Gemini key rotation | ✅ Working | Backend auto-discovers `GEMINI_API_KEY_*` env vars; parks dead keys 24 h. |
| Hardcoded API key in client | ⚠️ **MUST FIX BEFORE PILOT** | Case-detection service ships a Gemini key in the APK. Needs to be moved server-side. |
| iOS build | 🟡 Source-ready, not built | Requires Mac + Apple Developer account ($99/yr) + Xcode + signing. |
| Crash reporting | 🟡 Not wired | Recommend Sentry (free tier) before scale-up beyond ~50 workers. |
| HTTPS pinning | 🟡 Not done | Anyone on the worker's WiFi could MITM the Render endpoint. Pin certificate in production. |
| Secure storage for JWT | 🟡 Currently SharedPreferences | Replace with `flutter_secure_storage` before production. |
| Clinical sign-off on rules | 🟡 1 item pending | PPH proxy "≥ 2 pads in 30 min" needs clinical sign-off (open item in `triage_cases.json:386`). |

**Current pilot-readiness: 7/10. After the 3 ⚠️ items above are fixed, it's 9/10 — ready for a 20–50-worker district pilot.**

---

## 9. Roadmap (Suggested)

### Now → 2 weeks: Pre-pilot hardening
1. Move Gemini key off client → backend proxy.
2. Replace SharedPreferences with secure storage for JWT.
3. Wire Sentry for crash reporting.
4. Get the PPH rule clinically signed off.
5. iOS build (requires hardware + Apple Dev account).

### 1–3 months: Pilot (20–50 ASHA workers, 1 block)
- Bi-weekly feedback cycles with workers.
- Admin reviews referral rates by band.
- Compare against MDSR baseline.
- Iterate on Bengali phrasing based on what workers actually say.

### 3–6 months: District scale (500+ workers)
- ANM and CHO admin tier (separate dashboard).
- Integration with ANMOL (govt MCH tracker).
- WhatsApp referral notifications.
- Offline-first audio caching for cold-start TTS.
- Vernacular HBNC home-visit reminder schedule (day 1, 3, 7, 14, 28).

### 6–12 months: State scale + clinical research
- 3-state pilot expansion.
- Outcome study: referral rates and missed-danger-sign rates pre- vs post-deployment.
- Publishable observational data on impact at the catchment level.
- Government RFP positioning (NHM, MoHFW).

---

## 10. Security & Privacy

- **No patient PII leaves the device unencrypted.** TLS in transit.
- **Backend stores patient name, age, vitals, and triage decisions.** No biometric data, no Aadhaar.
- **JWT tokens** are in memory + SharedPreferences (will move to secure storage).
- **Soft-delete first, permanent-delete only by admin.** Every deletion is recoverable for 30 days (configurable).
- **AI calls are proxied through the backend.** AI vendors never see the patient name; the backend strips PII before sending the situation text.
- **No third-party analytics.** No tracking SDKs.
- **Open question:** do we need DPDPA (Digital Personal Data Protection Act, 2023) consent flow before pilot? Recommendation: yes — short Bengali consent screen at first login.

---

## 11. Cost To Operate (Pilot Scale: ~50 workers, ~30 triages/worker/month)

| Item | Tier | Monthly Cost |
|---|---|---|
| Render backend (free tier) | Free | ₹0 |
| MongoDB Atlas (free tier, 512 MB) | Free | ₹0 |
| Google Gemini API | Free quota | ₹0 (within 1500 req/day) |
| Google Cloud TTS | Pay-per-character | ~₹400 (50 workers × 30 sessions × ~200 chars) |
| UptimeRobot keep-warm | Free | ₹0 |
| Domain + SSL | Optional | ~₹100 |
| **Total** | | **~₹500/month** |

**For 500 workers at district scale:** ~₹4,000/month (still well within typical NHM block budget). Render Pro tier (~₹1,700/month) eliminates cold-start; MongoDB Atlas Shared tier (~₹750) gives more headroom.

---

## 12. iOS / iPhone Availability — Honest Answer

**An Android APK cannot be installed on an iPhone.** Android and iOS are fundamentally incompatible package formats. The Flutter source code IS cross-platform, but to ship an iOS build the project requires:

1. **A Mac with Xcode installed.** Cannot be done on Windows.
2. **An Apple Developer Program account** — US$99/year.
3. **iOS-specific configuration**: signing certificate, provisioning profile, Info.plist permissions for microphone / location.
4. **Distribution**: either TestFlight (Apple's beta channel, ~24 h review) or sideload via Mac.

**Realistic options to demonstrate the app today:**
| Option | Effort | Best for |
|---|---|---|
| Screen-record the Android app + share video | Lowest | Quick walkthrough |
| Hand an Android device with the APK installed | Low | Live demo |
| Build a Flutter Web preview at a private URL | Medium | iPhone-Safari viewing (read-only, no voice) |
| Full iOS TestFlight build | High (needs Mac + ₹8k/year) | If iPhone install is mandatory |

**Recommendation:** Use an Android device for the initial demo OR a 3-minute screen recording (see §13 below). The full iOS build is worth investing in ONLY after pilot validation — the cost should not be incurred prematurely.

---

## 13. Demo Video — How to Record One

A 3-minute screen recording is the fastest way to share AshaMitra remotely. Here are two approaches:

### Option A: Direct Android recording (zero install)
1. On the Android phone with AshaMitra installed, swipe down from top → tap "Screen Record".
2. Tap "Start" → run through the demo.
3. Stop, then share the video file.

### Option B: Computer-side recording (cleaner output, can edit)
1. Install **scrcpy** on your computer (free, mirrors the phone to PC).
2. Install **OBS Studio** (free screen recorder).
3. Plug phone → run `scrcpy` → it opens a window showing the phone screen.
4. In OBS, capture the scrcpy window → click "Start Recording".

### Suggested demo script (3 min total)
1. **0:00 — Open app, show Home tab.** "These are the cases an ASHA worker handles."
2. **0:15 — Tap '🤰 Pregnancy', spell out a real-sounding situation:** "৩২ সপ্তাহের গর্ভবতী, মাথা ব্যথা, পা ফোলা, রক্তচাপ ১৫০ বাই ১০০"
3. **0:45 — Watch the orb pulse, the AI ask follow-up questions in Bengali, classify as RED.**
4. **1:30 — Show the result card:** band, reason, next step, referral level.
5. **1:45 — Go to Reports tab.** Show the new card. Tap PDF, watch the dialog stages, open the PDF.
6. **2:15 — Switch language to English in Profile.** Show the same screen now in English.
7. **2:30 — Go to admin panel** (separate web URL or app section). Show the dashboard with the report you just generated, the worker breakdown, the case breakdown.
8. **3:00 — End on the slogan card.**

---

## 14. Additional Collateral — Recommended Next Steps

The following supplementary materials are recommended for a full stakeholder package:

- **One-slide elevator pitch** (PowerPoint, 60-second read).
- **A 2-page printed leaflet** for the District Health Officer — same content as this doc but in Bengali + English with screenshots.
- **A short clinical-validation memo** signed by a CHO confirming the 42 rules match HBNC/IMNCI/PMSMA national guidance.
- **A pilot MoU template** — what the District commits to (50 ASHA workers, 3-month observation period), what AshaMitra commits to (free deployment + weekly support).
- **A success-metrics dashboard** — define KPIs upfront (referral-rate change, time-to-decision, % triages completed offline, worker NPS).
- **An RFP-ready response template** so when NHM or MoHFW asks "what can your platform do" you can answer in 24 hours.

---

## 15. Open Questions for Decision

For discussion at the next planning meeting:

1. **Pilot district + block?** (Determines deployment scale and which CHO to engage.)
2. **Funding source?** (Self-funded pilot? CSR? NHM small grant? Pre-seed?)
3. **iOS — do we need it now or can pilot run Android-only?** (Saves ~₹8k/year + a Mac if Android-only.)
4. **Clinical Champion?** (Need a CHO or BMOH to formally sign off on the 42 rules.)
5. **Data sharing with state?** (Can we send aggregated weekly stats to the District Health Officer? Requires DPDPA compliance.)
6. **Liability framing.** (App is decision *support*, never replaces clinical judgement. Need this in worker training + onboarding.)

---

## 16. Executive Summary

> AshaMitra is a Bengali voice-driven clinical decision support app for ASHA workers, covering 7 high-impact modules with 42 evidence-based clinical rules drawn from HBNC, IMNCI, PMSMA, and the National Immunization Schedule. The mobile app runs offline-first; the cloud backend syncs records and powers an admin dashboard. The core triage flow is production-ready today on Android. iOS requires Mac + Apple Developer account; iPhone install is not free or fast. Three small security items (move Gemini key off client, secure-storage for JWT, Sentry crash reporting) need ~2 weeks of work before a real 50-worker pilot. Pilot operating cost: under ₹500/month. The opportunity: India has 1 million+ ASHA workers — every one is a potential user.

---

*Document maintained by the build team. Source: `/d:/AshaMitra-main`.*
