# AshaMitra — Full Project Structure

A complete, file-by-file map of the AshaMitra project: the **Flutter app** and the
**Node/Express backend**. This is a structural reference — for the clinical vision and
sign-off material, see [`README.md`](README.md).

> **Tagline (from `pubspec.yaml`):** *ASHA Mitra — Voice AI for Safer Care*
> **App id:** `com.example.asha_mitra` · **Version:** `1.0.0+1` · **Min Android API:** 23

---

## 1. Two repositories, one workspace

The project on disk lives under `…/tanmoy/ashamitra/` and contains **two separate git
repos plus one stale duplicate**:

```
tanmoy/ashamitra/                         ← APP repo root  → github.com/TANMOYDAS1234/AshaMitra
├── ashamitra/                            ← Flutter app (this folder = "Flutter root")
│   ├── lib/  android/  assets/  test/  pubspec.yaml  …
│   └── backend/                          ← DEPLOYED backend, OWN repo → ASHAmitra-backend (Render)
└── backend/                              ← ⚠ STALE DUPLICATE, tracked by the app repo, NOT deployed
```

| Location | Git repo | Deployed? | Notes |
|---|---|---|---|
| `ashamitra/` (Flutter root) | `AshaMitra.git` | Built to APK | The mobile app |
| `ashamitra/backend/` | `ASHAmitra-backend.git` | ✅ Render | **Edit + push this** for backend changes |
| `backend/` (outer) | part of `AshaMitra.git` | ❌ No | Out-of-date copy; safe to delete |

The app talks to the deployed backend over HTTPS. The base URL is hardcoded in two spots:
[`lib/core/constants/api_constants.dart`](lib/core/constants/api_constants.dart) and
[`lib/core/services/api_service.dart`](lib/core/services/api_service.dart).

---

## 2. Tech stack

**App:** Flutter (Dart ≥ 3.0), GetX (state, routing, i18n), `speech_to_text` + `record`
(STT), `flutter_tts` + `audioplayers` (TTS playback), `sqflite` (local trace DB),
`shared_preferences` (key-value), `http`/`dio`, `flutter_map` + `geolocator` (referral map),
`pdf` (report export), `permission_handler`, `connectivity_plus`, `google_fonts`.

**Backend:** Node.js + Express, Mongoose → MongoDB Atlas, `jsonwebtoken` (auth),
`googleapis` (Google Cloud Text-to-Speech), `cors`, `dotenv`. LLM via **Groq** (Llama 3.3)
and **Gemini** (`gemini-2.5-flash`). STT fallback via **Groq Whisper**. Hosted on **Render**.

---

## 3. Flutter root (`ashamitra/`)

```
pubspec.yaml          # Dependencies, asset registration, launcher-icon config, Kotlin pins
README.md             # Clinical vision / sign-off spec (kept as-is)
PROJECT_STRUCTURE.md  # ← this file
android/              # Android Gradle project (see §8)
assets/               # Bundled data, fonts, guideline PDFs, cached voices, images (see §7)
lib/                  # All Dart source (see §4–§6)
test/                 # Unit / widget tests (see §9)
```

### Entry points

| File | Purpose |
|---|---|
| [`lib/main.dart`](lib/main.dart) | Default app entry. Boots GetX, services, `ServerHeartbeat`, runs `App`. |
| [`lib/main_dev.dart`](lib/main_dev.dart) | Dev flavour entry (`flutter run -t lib/main_dev.dart`). |
| [`lib/main_prod.dart`](lib/main_prod.dart) | Prod flavour entry. |

---

## 4. `lib/app/` — application shell

| File | Purpose |
|---|---|
| [`app.dart`](lib/app/app.dart) | Root `GetMaterialApp`: theme, translations, `fallbackLocale`, initial route. |
| [`app_binding.dart`](lib/app/app_binding.dart) | GetX dependency bindings (controllers/services injected at startup). |
| [`routes.dart`](lib/app/routes.dart) | `AppRoutes` route names + `GetPage` route table. |

---

## 5. `lib/core/` — cross-cutting infrastructure

### `core/constants/`
| File | Purpose |
|---|---|
| [`api_constants.dart`](lib/core/constants/api_constants.dart) | `baseUrl` of the backend (used by TTS/STT/chat services). |
| [`app_config.dart`](lib/core/constants/app_config.dart) | Build/flavour config flags. |
| [`app_constants.dart`](lib/core/constants/app_constants.dart) | App-wide constant values (keys, defaults). |

### `core/services/` — main services
| File | Purpose |
|---|---|
| [`api_service.dart`](lib/core/services/api_service.dart) | Central REST client: auth/OTP, patients, reports, chat-with-voice, admin endpoints. |
| [`ai_response_cache.dart`](lib/core/services/ai_response_cache.dart) | Caches LLM responses to cut latency/cost on repeats. |
| [`case_detection_service.dart`](lib/core/services/case_detection_service.dart) | Detects the clinical module from free speech (rule-based + backend `/detect-case`). |
| [`clinical_engine_service.dart`](lib/core/services/clinical_engine_service.dart) | Runs the deterministic clinical decision engine (loads `clinical_decision_engine.json`). |
| [`connectivity_service.dart`](lib/core/services/connectivity_service.dart) | Online/offline detection (drives the hybrid paths). |
| [`decision_trace_service.dart`](lib/core/services/decision_trace_service.dart) | Builds the auditable decision trace for each case. |
| [`gemini_conversation_service.dart`](lib/core/services/gemini_conversation_service.dart) | Online LLM triage conversation; extracts `spoken_response` from backend `/chat`. |
| [`gemini_triage_service.dart`](lib/core/services/gemini_triage_service.dart) | Gemini-backed triage helper logic. |
| [`groq_stt_service.dart`](lib/core/services/groq_stt_service.dart) | Records audio and sends to backend `/transcribe` (Groq Whisper) — STT fallback. |
| [`immediate_action_engine.dart`](lib/core/services/immediate_action_engine.dart) | Computes immediate next actions for the worker. |
| [`language_controller.dart`](lib/core/services/language_controller.dart) | Active locale (bn/hi/en) management and switching. |
| [`local_storage_service.dart`](lib/core/services/local_storage_service.dart) | `shared_preferences` wrapper for app state/session. |
| [`mdsr_hook_service.dart`](lib/core/services/mdsr_hook_service.dart) | Maternal Death Surveillance & Response audit hooks. |
| [`mongo_service.dart`](lib/core/services/mongo_service.dart) | Mongo-related client helpers. |
| [`navigation_service.dart`](lib/core/services/navigation_service.dart) | Centralised GetX navigation helpers. |
| [`offline_brain.dart`](lib/core/services/offline_brain.dart) | Offline reasoning engine for triage when there's no internet. |
| [`rule_executor.dart`](lib/core/services/rule_executor.dart) | Executes clinical rules locally (offline path). |
| [`server_heartbeat.dart`](lib/core/services/server_heartbeat.dart) | Periodically pings backend `/health` to avoid cold starts. |
| [`symptom_mapper.dart`](lib/core/services/symptom_mapper.dart) | Maps spoken symptoms onto the closed clinical ontology. |
| [`trace_database.dart`](lib/core/services/trace_database.dart) | `sqflite` database for persisted decision traces. |
| [`tts_prewarm_service.dart`](lib/core/services/tts_prewarm_service.dart) | Pre-warms TTS so the first utterance isn't slow. |
| [`tts_service.dart`](lib/core/services/tts_service.dart) | On-device TTS via `flutter_tts`. |
| [`vapi_tts_service.dart`](lib/core/services/vapi_tts_service.dart) | Cloud TTS via backend `/tts` (Google Wavenet) + playback. |
| [`vitals_extractor.dart`](lib/core/services/vitals_extractor.dart) | Extracts vital signs (temp, weight, BP, etc.) from speech. |

### `core/services/clup/` — conversational understanding pipeline
| File | Purpose |
|---|---|
| [`clup_pipeline.dart`](lib/core/services/clup/clup_pipeline.dart) | Orchestrates the CLUP stages end-to-end. |
| [`intent_detector.dart`](lib/core/services/clup/intent_detector.dart) | Classifies the worker's conversational intent. |
| [`situation_extractor.dart`](lib/core/services/clup/situation_extractor.dart) | Pulls the clinical situation/entities from the utterance. |
| [`clinical_relevance_filter.dart`](lib/core/services/clup/clinical_relevance_filter.dart) | Drops non-clinical noise before reasoning. |
| [`clarification_engine.dart`](lib/core/services/clup/clarification_engine.dart) | Decides when/what to ask back to disambiguate. |
| [`engine_grounded_qa.dart`](lib/core/services/clup/engine_grounded_qa.dart) | Answers grounded strictly in the clinical engine output. |

### `core/services/layers/` — clinical safety layers
| File | Purpose |
|---|---|
| [`rule_engine.dart`](lib/core/services/layers/rule_engine.dart) | Core deterministic rule evaluation. |
| [`severity_scoring_engine.dart`](lib/core/services/layers/severity_scoring_engine.dart) | Severity 1–5 scoring. |
| [`adaptive_risk_engine.dart`](lib/core/services/layers/adaptive_risk_engine.dart) | Adjusts risk from accumulated signals. |
| [`safety_escalation_layer.dart`](lib/core/services/layers/safety_escalation_layer.dart) | Forces escalation on RED hard-stops. |
| [`referral_decision_engine.dart`](lib/core/services/layers/referral_decision_engine.dart) | Maps band → referral level/facility. |
| [`contradiction_checker.dart`](lib/core/services/layers/contradiction_checker.dart) | Catches contradictory inputs/conclusions. |
| [`input_validator.dart`](lib/core/services/layers/input_validator.dart) | Validates structured inputs before reasoning. |
| [`required_vital_checker.dart`](lib/core/services/layers/required_vital_checker.dart) | Ensures mandatory vitals are present. |
| [`age_module_validator.dart`](lib/core/services/layers/age_module_validator.dart) | Confirms age fits the selected module. |
| [`explainable_output.dart`](lib/core/services/layers/explainable_output.dart) | Builds the human-readable explanation/trace. |
| [`protocol_hash_verifier.dart`](lib/core/services/layers/protocol_hash_verifier.dart) | Verifies protocol/registry integrity by hash. |

### `core/theme/`
| File | Purpose |
|---|---|
| [`app_colors.dart`](lib/core/theme/app_colors.dart) | Colour palette. |
| [`app_text_styles.dart`](lib/core/theme/app_text_styles.dart) | Typography scale. |
| [`app_gradients.dart`](lib/core/theme/app_gradients.dart) | Background/brand gradients. |
| [`app_spacing.dart`](lib/core/theme/app_spacing.dart) | Spacing tokens. |
| [`app_radius.dart`](lib/core/theme/app_radius.dart) | Corner-radius tokens. |
| [`app_shadows.dart`](lib/core/theme/app_shadows.dart) | Elevation/shadow tokens. |

### `core/utils/`
| File | Purpose |
|---|---|
| [`date_helper.dart`](lib/core/utils/date_helper.dart) | Date formatting/parsing helpers. |
| [`logger.dart`](lib/core/utils/logger.dart) | Lightweight logging utility. |
| [`pdf_helper.dart`](lib/core/utils/pdf_helper.dart) | Builds/exports report PDFs (loads Hind Siliguri fonts). |
| [`permissions.dart`](lib/core/utils/permissions.dart) | Runtime permission requests (mic, location, storage). |
| [`validators.dart`](lib/core/utils/validators.dart) | Form/field validators. |

---

## 6. `lib/features/` — feature modules

Each feature follows a **controller / data / presentation** layering (GetX controllers,
datasources + models + repositories, then screens + widgets).

### `features/admin/` — admin console
```
controller/admin_controller.dart                 # Admin state & actions
presentation/screens/
  admin_shell.dart                               # Tabbed shell host
  admin_dashboard_screen.dart                    # Dashboard landing
  admin_overview_tab.dart                         # KPIs/overview tab
  admin_workers_tab.dart                          # ASHA workers tab
  admin_reports_tab.dart                          # Reports tab
  admin_settings_tab.dart                         # Settings tab
  admin_asha_list_screen.dart                     # List of ASHA workers
  admin_add_asha_screen.dart                      # Create/register an ASHA
  admin_reports_screen.dart                       # All reports view
  admin_report_detail.dart                        # Single report detail
  admin_deleted_reports_screen.dart               # Soft-deleted reports (restore/purge)
  admin_profile_screen.dart                       # Admin profile
```

### `features/assistant/` — voice assistant
```
presentation/screens/assistant_screen.dart        # Hold-to-talk assistant UI
services/assistant_chat_service.dart               # /chat-with-voice client; extracts spoken_text
services/intent_classifier.dart                    # Rule-based intent classification
services/intent_dispatcher.dart                    # Maps intent → in-app action (108 dialer, nav…)
services/voice_triage_engine.dart                  # In-assistant triage engine glue
```

### `features/auth/` — phone/OTP login
```
controller/auth_controller.dart                    # Login/OTP/resend state
data/datasources/auth_local_ds.dart               # Local session persistence
data/datasources/auth_remote_ds.dart              # send-otp / verify-otp / profile calls
data/models/user_model.dart                        # User/session model
data/repositories/auth_repository.dart            # Auth repo abstraction
presentation/screens/login_screen.dart            # Phone entry
presentation/screens/otp_screen.dart              # OTP entry + pilot OTP banner + resend
presentation/widgets/auth_form.dart               # Shared auth form widget
```

### `features/emergency/`
```
presentation/screens/emergency_screen.dart         # Emergency info / facility / map
presentation/widgets/emergency_card.dart           # Emergency action card
```

### `features/home/` — dashboard
```
presentation/screens/home_screen.dart              # Main dashboard
presentation/widgets/dashboard_card.dart           # Tile/card
presentation/widgets/greeting_header.dart          # Greeting/header
presentation/widgets/patient_context_sheet.dart    # Active-patient context sheet
```

### `features/notifications/`
```
controller/notification_controller.dart            # Notification state
data/notification_model.dart                       # Notification model
```

### `features/onboarding/`
```
presentation/screens/splash_screen.dart            # Splash
presentation/screens/welcome_screen.dart           # Welcome
presentation/screens/language_screen.dart          # Language selection (bn/hi/en)
presentation/widgets/onboarding_card.dart          # Onboarding slide card
```

### `features/patients/` — beneficiary registry
```
controller/patient_controller.dart                 # Patient list/CRUD state
data/datasources/patient_local_ds.dart            # Local cache
data/datasources/patient_remote_ds.dart           # /patients API
data/models/patient_model.dart                     # Patient model
data/repositories/patient_repository.dart         # Repo abstraction
presentation/screens/add_patient_screen.dart       # Add patient
presentation/screens/patient_list_screen.dart      # List patients
presentation/screens/patient_profile_screen.dart   # Patient detail/profile
presentation/widgets/patient_card.dart             # Patient list card
```

### `features/profile/`
```
presentation/screens/profile_screen.dart           # ASHA profile
presentation/widgets/profile_header.dart           # Profile header
```

### `features/reports/`
```
presentation/screens/reports_screen.dart           # Visit reports list/export
```

### `features/triage/` — core triage flow
```
controller/triage_controller.dart                  # Triage session state
data/datasources/triage_local_ds.dart             # Local triage cache
data/datasources/triage_remote_ds.dart            # Triage API
data/models/triage_case_model.dart                # Case definition model
data/models/question_model.dart                    # Question model
data/models/triage_model.dart                      # Triage result/session model
data/repositories/triage_repository.dart          # Repo abstraction
presentation/screens/select_case_screen.dart       # Manual/voice case selection
presentation/screens/case_confirm_screen.dart      # Detected case + confidence badge
presentation/screens/voice_triage_screen.dart      # Voice Q&A loop (hold-to-talk, hybrid)
presentation/screens/dynamic_triage_screen.dart    # Tap-based Q&A fallback
presentation/screens/triage_result_screen.dart     # Band + action card
presentation/widgets/mic_button.dart               # Mic control
presentation/widgets/question_card.dart            # Question display
presentation/widgets/triage_option_card.dart       # Answer option card
presentation/widgets/triage_result_card.dart       # Result card
presentation/widgets/voice_orb.dart                # Animated voice/listening orb
```

---

## 6b. `lib/localization/` — i18n
| File | Purpose |
|---|---|
| [`app_translations.dart`](lib/localization/app_translations.dart) | GetX `Translations` map loader. |
| [`bn.json`](lib/localization/bn.json) | Bengali strings (primary). |
| [`hi.json`](lib/localization/hi.json) | Hindi strings. |
| [`en.json`](lib/localization/en.json) | English strings. |

## 6c. `lib/shared/` — reusable UI

### `shared/components/`
| File | Purpose |
|---|---|
| [`app_header.dart`](lib/shared/components/app_header.dart) | Shared screen header. |
| [`bottom_nav.dart`](lib/shared/components/bottom_nav.dart) | Bottom navigation bar. |
| [`custom_appbar.dart`](lib/shared/components/custom_appbar.dart) | Custom app bar. |

### `shared/widgets/`
| File | Purpose |
|---|---|
| [`app_button.dart`](lib/shared/widgets/app_button.dart) | Primary button. |
| [`app_input.dart`](lib/shared/widgets/app_input.dart) | Text input. |
| [`app_loader.dart`](lib/shared/widgets/app_loader.dart) | Loading indicator. |
| [`count_up.dart`](lib/shared/widgets/count_up.dart) | Animated number counter. |
| [`emergency_button.dart`](lib/shared/widgets/emergency_button.dart) | Emergency action button. |
| [`empty_state.dart`](lib/shared/widgets/empty_state.dart) | Empty-list placeholder. |
| [`glass_card.dart`](lib/shared/widgets/glass_card.dart) | Frosted-glass card. |
| [`gradient_background.dart`](lib/shared/widgets/gradient_background.dart) | Gradient background. |
| [`mic_button.dart`](lib/shared/widgets/mic_button.dart) | Shared mic button. |
| [`patient_card.dart`](lib/shared/widgets/patient_card.dart) | Shared patient card. |
| [`risk_badge.dart`](lib/shared/widgets/risk_badge.dart) | Green/Yellow/Red badge. |
| [`skeleton.dart`](lib/shared/widgets/skeleton.dart) | Shimmer skeleton loader. |
| [`triage_result_card.dart`](lib/shared/widgets/triage_result_card.dart) | Shared result card. |
| [`user_avatar.dart`](lib/shared/widgets/user_avatar.dart) | User avatar. |
| [`voice_orb.dart`](lib/shared/widgets/voice_orb.dart) | Shared voice orb. |
| [`referral_map/referral_map_widget.dart`](lib/shared/widgets/referral_map/referral_map_widget.dart) | `flutter_map` referral facility map (uses `/directions`). |

> Note: a few widgets appear both under `shared/widgets/` and inside `features/triage/…`
> (e.g. `mic_button`, `voice_orb`, `triage_result_card`, `patient_card`) — duplicates worth
> consolidating later.

---

## 7. `assets/` — bundled resources

| Path | Contents |
|---|---|
| `assets/images/ashalogo.png` | App logo / launcher-icon source. |
| `assets/fonts/HindSiliguri-Regular.ttf`, `-Bold.ttf` | Bengali-capable font (UI + PDF export). |
| `assets/data/` | Engine/seed JSON (see below). |
| `assets/guidelines/` | ~24 MoHFW source PDFs (IMNCI, HBNC, HBYC, MCP, PMSMA, SBA, PPH, PNC, immunisation schedule, GDM, hypothyroidism, calcium, deworming, MDSR…). Reference material. |
| `assets/voices/` | **201 pre-generated TTS `.mp3` files** (content-hashed filenames) + `manifest.json`. Bundled audio so common phrases play instantly offline. |

### `assets/data/`
| File | Purpose |
|---|---|
| `asha_engine.json` | ASHA engine config/content. |
| `clinical_decision_engine.json` | Deterministic decision engine (rules/protocols). |
| `triage_cases.json` | All clinical modules: questions, keywords, scoring. |
| `decision_output.json` | Sample/expected decision output. |
| `patient_case.json` | Sample patient case payload. |

---

## 8. `android/` — Android project (key files)
| File | Purpose |
|---|---|
| `android/build.gradle` | Top-level Gradle config (⚠ machine-local edits — local-maven). |
| `android/app/build.gradle` | App module Gradle: `applicationId com.example.asha_mitra`, SDK levels (⚠ machine-local edits). |
| `android/app/src/main/AndroidManifest.xml` | Permissions, `<queries>` for RecognitionService/dialer, app config. |
| `android/app/src/main/kotlin/com/example/asha_mitra/MainActivity.kt` | Flutter host activity. |

> The `android/local-maven/` tree and `build.gradle` tweaks are **machine-local** (offline
> Maven mirror to dodge SSL-inspection PKIX errors) and are intentionally **not** part of the
> canonical project — don't commit them.

---

## 9. `test/`
| File | Purpose |
|---|---|
| [`test/intent_classifier_ambulance_test.dart`](test/intent_classifier_ambulance_test.dart) | Unit test: "call ambulance" intent classification. |
| [`test/widget_test.dart`](test/widget_test.dart) | Default Flutter widget smoke test. |

---

## 10. `backend/` — deployed Node/Express API

> Separate git repo (`ASHAmitra-backend.git`), deployed on Render. Stateless — all data in
> MongoDB Atlas.

| File | Purpose |
|---|---|
| `server.js` | **The whole API** — Express app, all routes, Mongoose models, Groq/Gemini calls, Google TTS, OTP/JWT auth. |
| `package.json` | Deps (`express`, `mongoose`, `googleapis`, `jsonwebtoken`, `cors`, `dotenv`) + `start`/`dev` scripts. |
| `package-lock.json` | Locked dependency tree. |
| `.env.example` | Template of required env vars (copy to `.env`, never commit `.env`). |
| `.gitignore` | Ignores `.env`, `node_modules/`, generated audio. |
| `seed-admin.js` | One-off script to seed an admin user. |
| `generate-bundled-voices.js` | Pre-generates the `assets/voices/*.mp3` via Google TTS. |
| `list-voices.js` | Lists available Google TTS voices. |
| `test-api.js` | Manual API smoke test. |
| `test-db.js` | Manual Mongo connectivity test. |
| `test-tts.js` | Manual TTS test. |

### Backend HTTP endpoints (served under `/api`, plus `/health`)
| Endpoint | Purpose |
|---|---|
| `GET /health` | Liveness + deploy build marker (used by `ServerHeartbeat`). |
| `POST /api/auth/send-otp` · `verify-otp` · `GET /api/auth/profile` | Phone/OTP auth + JWT. |
| `GET/POST/PUT/DELETE /api/patients[/:id]` | Beneficiary registry CRUD. |
| `… /api/reports[/:id]` (+ `attach-patient`, `repoint`, `restore`) | Visit reports. |
| `POST /api/chat-with-voice` | LLM reply + TTS audio (assistant; field `spoken_text`). |
| `POST /api/chat` | LLM triage conversation (field `spoken_response`). |
| `POST /api/detect-case` | Clinical module detection from free text. |
| `POST /api/transcribe` | Groq Whisper STT (audio → text). |
| `POST /api/tts` · `POST /api/voice-preview` | Google Cloud TTS synthesis / voice preview. |
| `GET /api/directions` | Routing for the referral map. |
| `… /api/admin/workers`, `/api/admin/reports/*` | Admin: manage ASHAs, moderate/restore/purge reports. |

### Required environment variables (`backend/.env`)
```
MONGO_URI=…            # MongoDB Atlas connection string
JWT_SECRET=…           # Auth token signing
GEMINI_API_KEY=…       # Paid Gemini key
GEMINI_MODEL=gemini-2.5-flash
GROQ_API_KEY=…         # Groq (Llama + Whisper)
PORT=3000
# Google Cloud TTS service-account credentials (path or inline JSON)
```

---

## 11. Run & build

### App
```bash
flutter pub get
flutter run                          # default flavour
flutter run -t lib/main_dev.dart     # dev
flutter build apk --release          # release APK
```

### Backend
```bash
cd backend
npm install
cp .env.example .env                 # then fill in secrets
npm run dev                          # nodemon (local)
npm start                            # node server.js (prod)
```

---

*Structural reference generated from the tracked file tree of both repos. For clinical
intent, modules, triage bands, and sign-off items, see [`README.md`](README.md).*
